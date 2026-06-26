import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'premier_laundry_channel',
    'Premier Laundry',
    description: 'Notifikasi status laundry dan pembayaran',
    importance: Importance.high,
  );

  // Callback saat notifikasi di-tap (untuk navigasi)
  Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    await _setupLocalNotifications();
    await _requestPermission();
    await _createAndroidChannel();
    _setupForegroundHandler();
    _setupNotificationOpenHandler();
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        onNotificationTap?.call(details.payload);
      },
    );
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM Permission: ${settings.authorizationStatus}');
  }

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _setupForegroundHandler() {
    // Tampilkan notifikasi lokal saat app di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'Premier Laundry',
        body: notification.body ?? '',
        payload: message.data['orderId'],
      );
    });
  }

  void _setupNotificationOpenHandler() {
    // App dibuka dari background notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap?.call(message.data['orderId']);
    });
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: AppColors.primary,
    );
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  // Ambil FCM token dan simpan ke tabel user_devices
  Future<void> saveTokenToSupabase(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final supabase = Supabase.instance.client;

      // Selalu upsert is_active: true, termasuk saat baris sudah ada tapi
      // sempat dinonaktifkan (mis. logout sebelumnya). Token FCM biasanya
      // stabil antar login, jadi tanpa ini baris yang sudah ada akan
      // permanen is_active: false dan push tidak akan pernah terkirim lagi
      // ke device tersebut.
      await supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'is_active': true,
      }, onConflict: 'user_id,fcm_token');

      // Pantau refresh token
      _messaging.onTokenRefresh.listen((newToken) async {
        await supabase.from('user_devices').upsert({
          'user_id': userId,
          'fcm_token': newToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'is_active': true,
        }, onConflict: 'user_id,fcm_token');
      });

      debugPrint('FCM token saved: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Nonaktifkan token saat logout
  Future<void> deactivateToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('user_devices')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('fcm_token', token);
    } catch (e) {
      debugPrint('Error deactivating FCM token: $e');
    }
  }

  // Cek notifikasi yang membuka app saat app terminated
  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }

  // Panggil edge function send-notification: insert ke tabel notifications
  // (in-app) + kirim push FCM kalau device user aktif. Dipakai dari provider
  // mana pun yang perlu memberi tahu user lain (admin/customer/courier)
  // setelah sebuah aksi terjadi. Gagal kirim notif tidak boleh menggagalkan
  // aksi utama, jadi error di sini cukup di-log.
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // Status aktif/nonaktif notifikasi untuk device ini (berdasarkan token saat ini)
  Future<bool> isNotificationsEnabled(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return true;
      final row = await Supabase.instance.client
          .from('user_devices')
          .select('is_active')
          .eq('user_id', userId)
          .eq('fcm_token', token)
          .maybeSingle();
      return row?['is_active'] as bool? ?? true;
    } catch (e) {
      debugPrint('Error reading notification preference: $e');
      return true;
    }
  }

  // Aktif/nonaktifkan notifikasi push untuk device ini.
  // Mengubah is_active pada user_devices, dipakai send-notification edge
  // function untuk menyaring device tujuan.
  Future<void> setNotificationsEnabled(String userId, bool enabled) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'is_active': enabled,
      }, onConflict: 'user_id,fcm_token');
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
    }
  }
}
