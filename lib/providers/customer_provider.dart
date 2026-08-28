import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/order_model.dart';
import '../models/address_model.dart';
import '../models/voucher_model.dart';
import '../models/loyalty_model.dart';
import '../core/services/notification_service.dart';

class CustomerProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  List<OrderModel> _orders = [];
  List<AddressModel> _addresses = [];
  List<VoucherModel> _vouchers = [];
  LoyaltyModel? _loyaltyPoints;
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _subscribedUserId;

  List<OrderModel> get orders => _orders;
  List<AddressModel> get addresses => _addresses;
  List<VoucherModel> get vouchers => _vouchers;
  LoyaltyModel? get loyaltyPoints => _loyaltyPoints;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item,
    ];
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  double _calculateVoucherDiscount({
    required double subtotal,
    required double? discountPercent,
    required double? maxDiscount,
  }) {
    final percent = discountPercent ?? 0;
    final rawDiscount = subtotal * (percent / 100);
    final cappedBySubtotal = rawDiscount > subtotal ? subtotal : rawDiscount;
    if (maxDiscount != null &&
        maxDiscount > 0 &&
        cappedBySubtotal > maxDiscount) {
      return maxDiscount;
    }
    return cappedBySubtotal;
  }

  Future<void> loadOrders(String userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*), payments(*), addresses(address_text)')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      _orders = _uniqueBy(
        (data as List).map(
          (o) => OrderModel.fromJson(o as Map<String, dynamic>),
        ),
        (order) => order.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAddresses(String userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('is_default', ascending: false);
      _addresses = _uniqueBy(
        (data as List).map(
          (a) => AddressModel.fromJson(a as Map<String, dynamic>),
        ),
        (address) => address.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadVouchers(String userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('vouchers')
          .select()
          .eq('user_id', userId)
          .order('status');
      _vouchers = _uniqueBy(
        (data as List).map(
          (v) => VoucherModel.fromJson(v as Map<String, dynamic>),
        ),
        (voucher) => voucher.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadLoyalty(String userId) async {
    try {
      final data = await _supabase
          .from('loyalty_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null) {
        _loyaltyPoints = LoyaltyModel.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Validasi voucher sebelum dipakai: harus milik user, masih 'active',
  // dan belum kedaluwarsa. Dipanggil saat user menekan "Terapkan" di
  // halaman buat pesanan, sebelum diskonnya dihitung & ditampilkan.
  Future<VoucherModel?> validateVoucher({
    required String userId,
    required String code,
  }) async {
    _setError(null);
    try {
      final data = await _supabase
          .from('vouchers')
          .select()
          .eq('code', code)
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) {
        _setError('Voucher tidak ditemukan atau bukan milik Anda');
        return null;
      }
      final voucher = VoucherModel.fromJson(data);
      if (voucher.status != 'active') {
        _setError('Voucher sudah digunakan atau tidak aktif');
        return null;
      }
      if (voucher.expiredAt != null &&
          voucher.expiredAt!.isBefore(DateTime.now())) {
        _setError('Voucher sudah kedaluwarsa');
        return null;
      }
      return voucher;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Beri tahu semua admin tiap kali ada order baru, supaya bisa segera
  // diproses. Tidak di-await oleh caller karena gagal kirim notif tidak
  // boleh menggagalkan pembuatan order.
  Future<void> _notifyAdminsNewOrder(String orderId, String orderCode) async {
    try {
      final admins = await _supabase
          .from('profiles')
          .select('user_id')
          .eq('role', 'admin');
      for (final admin in admins as List) {
        await NotificationService.sendToUser(
          userId: admin['user_id'] as String,
          title: 'Pesanan Baru',
          body: 'Pesanan $orderCode menunggu diproses.',
          data: {'orderId': orderId, 'type': 'new_order'},
        );
      }
    } catch (e) {
      debugPrint('Gagal mengirim notifikasi order baru ke admin: $e');
    }
  }

  Future<String?> createOrder({
    required String customerId,
    required String orderType,
    required List<Map<String, dynamic>> items,
    required String addressId,
    String? notes,
    required double deliveryFee,
    required double subtotal,
    required double total,
    String? voucherCode,
    double? discountAmount,
    double? estimatedDistanceKm,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final orderId = _uuid.v4();

      final inserted = await _supabase
          .from('orders')
          .insert({
            'id': orderId,
            'customer_id': customerId,
            'address_id': addressId,
            'order_type': orderType,
            'status': 'created',
            'payment_status': 'pending',
            'subtotal': subtotal,
            'delivery_fee': deliveryFee,
            'discount_amount': discountAmount ?? 0.0,
            'total_amount': total,
            'estimated_distance_km': estimatedDistanceKm,
            'notes': notes,
          })
          .select('order_code')
          .single();
      final orderCode = inserted['order_code'] as String;

      if (items.isNotEmpty) {
        final itemsToInsert = items
            .map((item) => {...item, 'order_id': orderId, 'id': _uuid.v4()})
            .toList();
        await _supabase.from('order_items').insert(itemsToInsert);
      }

      // Tandai voucher terpakai, tapi sekaligus jadi pengecekan ulang
      // (defense-in-depth) bahwa voucher itu memang milik customer ini,
      // masih 'active', dan belum kedaluwarsa — meski UI sudah validasi
      // lewat validateVoucher() sebelumnya. Kalau gagal (race condition,
      // voucher dipakai dari device lain, dll), batalkan order supaya
      // customer tidak terlanjur dibebani total tanpa diskon yang dijanjikan.
      if (voucherCode != null && voucherCode.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        final updated = await _supabase
            .from('vouchers')
            .update({
              'status': 'used',
              'used_order_id': orderId,
              'used_at': DateTime.now().toIso8601String(),
            })
            .eq('code', voucherCode)
            .eq('user_id', customerId)
            .eq('status', 'active')
            .or('expired_at.is.null,expired_at.gt.$now')
            .select();
        if ((updated as List).isEmpty) {
          await _supabase.from('order_items').delete().eq('order_id', orderId);
          await _supabase.from('orders').delete().eq('id', orderId);
          _setError('Voucher tidak valid, kedaluwarsa, atau sudah digunakan');
          return null;
        }
      }

      await _notifyAdminsNewOrder(orderId, orderCode);

      return orderId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        await loadOrders(_orders[idx].customerId);
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> uploadPaymentProof(
    String orderId,
    String paymentId,
    File imageFile,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User belum login');
      }

      final fileName =
          'proof_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$userId/$orderId/$fileName';
      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from('payment-proofs')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = _supabase.storage
          .from('payment-proofs')
          .getPublicUrl(filePath);

      await _supabase
          .from('payments')
          .update({
            'payment_proof_url': publicUrl,
            'status': 'waiting_verification',
          })
          .eq('id', paymentId);

      await _supabase
          .from('orders')
          .update({'payment_status': 'waiting_verification'})
          .eq('id', orderId);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addAddress({
    required String userId,
    required String label,
    required String addressText,
    required double lat,
    required double lng,
    String? notes,
    bool isDefault = false,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      if (isDefault) {
        await _supabase
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }
      await _supabase.from('addresses').insert({
        'id': _uuid.v4(),
        'user_id': userId,
        'label': label,
        'address_text': addressText,
        'latitude': lat,
        'longitude': lng,
        'notes': notes,
        'is_default': isDefault,
      });
      await loadAddresses(userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAddress(String addressId, String userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final deleted = await _supabase
          .from('addresses')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'is_default': false,
          })
          .eq('id', addressId)
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .select('id');
      if ((deleted as List<dynamic>).isEmpty) {
        throw Exception('Alamat tidak ditemukan atau sudah dihapus');
      }
      final remaining = await _supabase
          .from('addresses')
          .select('id, is_default')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('is_default', ascending: false)
          .order('created_at', ascending: true);
      final remainingAddresses = remaining as List<dynamic>;
      final hasDefault = remainingAddresses.any(
        (address) => (address as Map<String, dynamic>)['is_default'] == true,
      );
      if (!hasDefault && remainingAddresses.isNotEmpty) {
        final firstAddress = remainingAddresses.first as Map<String, dynamic>;
        await _supabase
            .from('addresses')
            .update({'is_default': true})
            .eq('id', firstAddress['id'] as String);
      }
      await loadAddresses(userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> setDefaultAddress(String addressId, String userId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId)
          .isFilter('deleted_at', null);
      await _supabase
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId)
          .eq('user_id', userId)
          .isFilter('deleted_at', null);
      await loadAddresses(userId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> applyVoucherToOrder({
    required String orderId,
    required String customerId,
    required String code,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      if (customerId.isEmpty) {
        throw Exception('User belum login');
      }

      final orderData = await _supabase
          .from('orders')
          .select(
            'id, customer_id, subtotal, delivery_fee, discount_amount, '
            'total_amount, status, payment_status',
          )
          .eq('id', orderId)
          .eq('customer_id', customerId)
          .single();

      if (orderData['payment_status'] != 'pending') {
        throw Exception('Voucher hanya bisa dipakai sebelum pembayaran dibuat');
      }
      if (orderData['status'] == 'cancelled' ||
          orderData['status'] == 'completed') {
        throw Exception('Voucher tidak bisa dipakai untuk pesanan ini');
      }

      final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0;
      final deliveryFee = (orderData['delivery_fee'] as num?)?.toDouble() ?? 0;
      final currentDiscount =
          (orderData['discount_amount'] as num?)?.toDouble() ?? 0;
      if (subtotal <= 0) {
        throw Exception('Voucher bisa dipakai setelah total layanan tersedia');
      }
      if (currentDiscount > 0) {
        throw Exception('Pesanan ini sudah memakai voucher');
      }

      final activePayments = await _supabase
          .from('payments')
          .select('id')
          .eq('order_id', orderId)
          .inFilter('status', ['pending', 'waiting_verification', 'paid'])
          .limit(1);
      if ((activePayments as List<dynamic>).isNotEmpty) {
        throw Exception('Voucher tidak bisa dipakai setelah pembayaran dibuat');
      }

      final voucherData = await _supabase
          .from('vouchers')
          .select()
          .eq('code', code)
          .eq('user_id', customerId)
          .maybeSingle();
      if (voucherData == null) {
        throw Exception('Voucher tidak ditemukan atau bukan milik Anda');
      }

      final voucher = VoucherModel.fromJson(voucherData);
      if (voucher.status != 'active') {
        throw Exception('Voucher sudah digunakan atau tidak aktif');
      }
      if (voucher.expiredAt != null &&
          voucher.expiredAt!.isBefore(DateTime.now())) {
        throw Exception('Voucher sudah kedaluwarsa');
      }

      final discount = _calculateVoucherDiscount(
        subtotal: subtotal,
        discountPercent: voucher.discountPercent,
        maxDiscount: voucher.maxDiscount,
      );
      if (discount <= 0) {
        throw Exception('Voucher tidak memberi diskon untuk pesanan ini');
      }

      final now = DateTime.now().toIso8601String();
      final updatedVoucher = await _supabase
          .from('vouchers')
          .update({'status': 'used', 'used_order_id': orderId, 'used_at': now})
          .eq('id', voucher.id)
          .eq('status', 'active')
          .or('expired_at.is.null,expired_at.gt.$now')
          .select('id');
      if ((updatedVoucher as List<dynamic>).isEmpty) {
        throw Exception(
          'Voucher tidak valid, kedaluwarsa, atau sudah digunakan',
        );
      }

      try {
        await _supabase
            .from('orders')
            .update({
              'discount_amount': discount,
              'total_amount': subtotal + deliveryFee - discount,
            })
            .eq('id', orderId)
            .eq('customer_id', customerId)
            .eq('payment_status', 'pending');
      } catch (e) {
        await _supabase
            .from('vouchers')
            .update({
              'status': 'active',
              'used_order_id': null,
              'used_at': null,
            })
            .eq('id', voucher.id)
            .eq('used_order_id', orderId);
        rethrow;
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createPayment({
    required String orderId,
    required String customerId,
    required String method,
    required double amount,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      if (customerId.isEmpty) {
        throw Exception('User belum login');
      }

      final existingPayment = await _supabase
          .from('payments')
          .select('id')
          .eq('order_id', orderId)
          .eq('customer_id', customerId)
          .eq('method', method)
          .inFilter('status', ['pending', 'waiting_verification'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingPayment != null) {
        return existingPayment['id'] as String?;
      }

      final paymentId = _uuid.v4();
      await _supabase.from('payments').insert({
        'id': paymentId,
        'order_id': orderId,
        'customer_id': customerId,
        'method': method,
        'amount': amount,
        'status': 'pending',
      });
      return paymentId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*), payments(*)')
          .eq('id', orderId)
          .single();
      return OrderModel.fromJson(data);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  void subscribeToRealtime(String userId) {
    if (_subscribedUserId == userId) return;
    _channel?.unsubscribe();
    _subscribedUserId = userId;
    _channel = _supabase
        .channel('customer_orders_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: userId,
          ),
          callback: (_) => loadOrders(userId),
        )
        .subscribe();
  }

  void unsubscribeFromRealtime() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribedUserId = null;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
