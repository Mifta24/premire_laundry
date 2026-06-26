import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/supabase_keys.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';
import '../models/laundry_service_model.dart';
import '../models/profile_model.dart';
import '../models/delivery_fee_model.dart';
import '../models/courier_task_model.dart';
import '../models/voucher_model.dart';
import '../core/services/notification_service.dart';

class AdminProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  List<OrderModel> _allOrders = [];
  List<PaymentModel> _pendingPayments = [];
  List<PaymentModel> _paidPayments = [];
  List<LaundryServiceModel> _services = [];
  List<ProfileModel> _couriers = [];
  List<DeliveryFeeModel> _deliveryFees = [];
  List<CourierTaskModel> _activeCourierTasks = [];
  List<VoucherModel> _vouchers = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _channel;

  List<OrderModel> get allOrders => _allOrders;
  List<PaymentModel> get pendingPayments => _pendingPayments;
  List<PaymentModel> get paidPayments => _paidPayments;
  List<LaundryServiceModel> get services => _services;
  List<ProfileModel> get couriers => _couriers;
  List<DeliveryFeeModel> get deliveryFees => _deliveryFees;
  List<CourierTaskModel> get activeCourierTasks => _activeCourierTasks;
  List<VoucherModel> get vouchers => _vouchers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DateTime _paymentRevenueDate(PaymentModel payment) {
    return payment.paidAt ?? payment.createdAt;
  }

  double revenueWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _paidPayments
        .where((p) => _paymentRevenueDate(p).isAfter(cutoff))
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  double get todayRevenue {
    final now = DateTime.now();
    return _paidPayments
        .where((p) {
          final revenueDate = _paymentRevenueDate(p);
          return revenueDate.year == now.year &&
              revenueDate.month == now.month &&
              revenueDate.day == now.day;
        })
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  double get monthRevenue {
    final now = DateTime.now();
    return _paidPayments
        .where((p) {
          final revenueDate = _paymentRevenueDate(p);
          return revenueDate.year == now.year && revenueDate.month == now.month;
        })
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  /// Total pendapatan per hari untuk 7 hari terakhir (index 0 = 6 hari lalu, index 6 = hari ini).
  List<double> get last7DaysRevenue {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    return days.map((day) {
      return _paidPayments
          .where((p) {
            final revenueDate = _paymentRevenueDate(p);
            return revenueDate.year == day.year &&
                revenueDate.month == day.month &&
                revenueDate.day == day.day;
          })
          .fold<double>(0, (sum, p) => sum + p.amount);
    }).toList();
  }

  int activeTaskCountFor(String courierId) {
    return _activeCourierTasks
        .where(
          (t) =>
              t.courierId == courierId &&
              t.status != 'picked_up' &&
              t.status != 'delivered' &&
              t.status != 'completed' &&
              t.status != 'cancelled',
        )
        .length;
  }

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item,
    ];
  }

  String _serviceBusinessKey(LaundryServiceModel service) {
    return [
      service.serviceType.trim().toLowerCase(),
      service.name.trim().toLowerCase(),
      service.unit.trim().toLowerCase(),
      service.price.toStringAsFixed(2),
    ].join('|');
  }

  String _deliveryFeeBusinessKey(DeliveryFeeModel fee) {
    return [
      fee.name.trim().toLowerCase(),
      fee.minDistanceKm.toStringAsFixed(2),
      fee.maxDistanceKm?.toStringAsFixed(2) ?? 'open',
      fee.fee.toStringAsFixed(2),
    ].join('|');
  }

  Future<Map<String, Map<String, String?>>> _fetchCustomerProfiles(
    Iterable<String> customerIds,
  ) async {
    final ids = customerIds.toSet().toList();
    if (ids.isEmpty) return {};
    final data = await _supabase
        .from('profiles')
        .select('user_id, name, phone')
        .inFilter('user_id', ids);
    final result = <String, Map<String, String?>>{};
    for (final p in data as List<dynamic>) {
      final uid = p['user_id'] as String?;
      if (uid != null) {
        result[uid] = {
          'name': p['name'] as String?,
          'phone': p['phone'] as String?,
        };
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _enrichOrdersWithCustomer(
    List<dynamic> rawOrders,
  ) async {
    final customerIds = rawOrders
        .map((o) => (o as Map<String, dynamic>)['customer_id'] as String?)
        .whereType<String>();
    final profiles = await _fetchCustomerProfiles(customerIds);

    return rawOrders.map((o) {
      final row = Map<String, dynamic>.from(o as Map<String, dynamic>);
      final customerId = row['customer_id'] as String?;
      final profile = profiles[customerId];
      if (profile != null) {
        row['customer_name'] = profile['name'];
        row['customer_phone'] = profile['phone'];
      }
      return row;
    }).toList();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadAllOrders() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*), payments(*), addresses(address_text)')
          .order('created_at', ascending: false);
      final enriched = await _enrichOrdersWithCustomer(data as List<dynamic>);
      _allOrders = _uniqueBy(
        enriched.map((o) => OrderModel.fromJson(o)),
        (order) => order.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPendingPayments() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('payments')
          .select()
          .eq('status', 'waiting_verification')
          .order('created_at', ascending: false);
      _pendingPayments = _uniqueBy(
        (data as List<dynamic>).map(
          (p) => PaymentModel.fromJson(p as Map<String, dynamic>),
        ),
        (payment) => payment.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPaidPayments() async {
    _setLoading(true);
    _setError(null);
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 60));
      final data = await _supabase
          .from('payments')
          .select()
          .eq('status', 'paid')
          .or('paid_at.gte.${cutoff.toIso8601String()},paid_at.is.null')
          .order('created_at', ascending: false);
      final paidPayments =
          (data as List<dynamic>)
              .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
              .toList()
            ..sort(
              (a, b) =>
                  _paymentRevenueDate(b).compareTo(_paymentRevenueDate(a)),
            );
      _paidPayments = _uniqueBy(paidPayments, (payment) => payment.orderId);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadActiveCourierTasks() async {
    try {
      final data = await _supabase
          .from('courier_tasks')
          .select()
          .not('status', 'in', '(picked_up,delivered,completed,cancelled)');
      _activeCourierTasks = _uniqueBy(
        (data as List<dynamic>).map(
          (t) => CourierTaskModel.fromJson(t as Map<String, dynamic>),
        ),
        (task) => task.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadServices() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('laundry_services')
          .select()
          .order('name');
      _services = _uniqueBy(
        (data as List<dynamic>).map(
          (s) => LaundryServiceModel.fromJson(s as Map<String, dynamic>),
        ),
        _serviceBusinessKey,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCouriers() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'courier')
          .order('name');
      _couriers = _uniqueBy(
        (data as List<dynamic>).map(
          (c) => ProfileModel.fromJson(c as Map<String, dynamic>),
        ),
        (courier) => courier.userId,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDeliveryFees() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('delivery_fees')
          .select()
          .order('min_distance_km');
      _deliveryFees = _uniqueBy(
        (data as List<dynamic>).map(
          (f) => DeliveryFeeModel.fromJson(f as Map<String, dynamic>),
        ),
        _deliveryFeeBusinessKey,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadVouchers() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('vouchers')
          .select()
          .order('created_at', ascending: false);
      final rows = data as List<dynamic>;
      final userIds = rows
          .map((v) => (v as Map<String, dynamic>)['user_id'] as String?)
          .whereType<String>();
      final profiles = await _fetchCustomerProfiles(userIds);
      _vouchers = _uniqueBy(
        rows.map((v) {
          final row = Map<String, dynamic>.from(v as Map<String, dynamic>);
          final profile = profiles[row['user_id']];
          if (profile != null) {
            row['customer_name'] = profile['name'];
            row['customer_phone'] = profile['phone'];
          }
          return VoucherModel.fromJson(row);
        }),
        (voucher) => voucher.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<List<ProfileModel>> searchCustomers(String query) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'customer')
          .or('name.ilike.%$query%,phone.ilike.%$query%')
          .order('name')
          .limit(20);
      return (data as List<dynamic>)
          .map((p) => ProfileModel.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<bool> createVoucher({
    required String userId,
    required String code,
    required String type,
    double? discountPercent,
    double? maxDiscount,
    DateTime? expiredAt,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('vouchers').insert({
        'id': _uuid.v4(),
        'user_id': userId,
        'code': code,
        'type': type,
        'discount_percent': discountPercent,
        'max_discount': maxDiscount,
        'status': 'active',
        'expired_at': expiredAt?.toIso8601String(),
      });
      await loadVouchers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateVoucher({
    required String voucherId,
    required String code,
    required String type,
    double? discountPercent,
    double? maxDiscount,
    DateTime? expiredAt,
    required String status,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('vouchers')
          .update({
            'code': code,
            'type': type,
            'discount_percent': discountPercent,
            'max_discount': maxDiscount,
            'expired_at': expiredAt?.toIso8601String(),
            'status': status,
          })
          .eq('id', voucherId);
      await loadVouchers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Buat satu voucher dengan kode yang sama untuk setiap customer yang
  /// belum pernah order (non-cancelled) - dipakai untuk promo broadcast
  /// semacam "PREMIER20 buat user baru". Tiap customer dapat baris voucher
  /// miliknya sendiri, jadi begitu dipakai langsung 'used' untuk dia tapi
  /// customer baru lain yang belum kebagian tetap bisa pakai kode yang sama.
  Future<bool> createBroadcastVoucherForNewCustomers({
    required String code,
    required String type,
    double? discountPercent,
    double? maxDiscount,
    DateTime? expiredAt,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final customers = await _supabase
          .from('profiles')
          .select('user_id')
          .eq('role', 'customer');
      final customerIds = (customers as List<dynamic>)
          .map((c) => (c as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      final ordersData = await _supabase
          .from('orders')
          .select('customer_id')
          .neq('status', 'cancelled');
      final customersWithOrders = (ordersData as List<dynamic>)
          .map((o) => (o as Map<String, dynamic>)['customer_id'] as String)
          .toSet();

      final newCustomerIds = customerIds.difference(customersWithOrders);
      if (newCustomerIds.isEmpty) {
        _setError('Tidak ada user baru (belum pernah order) saat ini');
        return false;
      }

      await _supabase.from('vouchers').insert([
        for (final userId in newCustomerIds)
          {
            'id': _uuid.v4(),
            'user_id': userId,
            'code': code,
            'type': type,
            'discount_percent': discountPercent,
            'max_discount': maxDiscount,
            'status': 'active',
            'expired_at': expiredAt?.toIso8601String(),
          },
      ]);
      await loadVouchers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Pesan untuk customer tiap kali admin memajukan status order. Status yang
  // tidak ada di sini (mis. 'waiting_weight_input') tidak cukup penting
  // untuk customer sehingga tidak dikirim notif.
  static const Map<String, String> _statusMessages = {
    'waiting_payment': 'Pesanan Anda siap dibayar, silakan lakukan pembayaran.',
    'waiting_pickup': 'Pesanan Anda akan segera dijemput kurir.',
    'cancelled': 'Pesanan Anda telah dibatalkan.',
    'received_by_store': 'Laundry Anda sudah diterima di toko.',
    'washing': 'Laundry Anda sedang dicuci.',
    'ironing': 'Laundry Anda sedang disetrika.',
    'ready_to_deliver': 'Laundry Anda siap diantar.',
  };

  Future<void> _notifyCustomerOrderStatus(String orderId, String status) async {
    final message = _statusMessages[status];
    if (message == null) return;
    try {
      final order = await _supabase
          .from('orders')
          .select('customer_id, order_code')
          .eq('id', orderId)
          .single();
      await NotificationService.sendToUser(
        userId: order['customer_id'] as String,
        title: 'Pesanan ${order['order_code']}',
        body: message,
        data: {'orderId': orderId, 'type': 'order_status', 'status': status},
      );
    } catch (e) {
      debugPrint('Gagal mengirim notifikasi status order: $e');
    }
  }

  Future<void> _notifyCustomerPaymentValidated(
    String orderId,
    bool isValid,
  ) async {
    try {
      final order = await _supabase
          .from('orders')
          .select('customer_id, order_code')
          .eq('id', orderId)
          .single();
      await NotificationService.sendToUser(
        userId: order['customer_id'] as String,
        title: 'Pesanan ${order['order_code']}',
        body: isValid
            ? 'Pembayaran Anda telah dikonfirmasi. Laundry segera diproses!'
            : 'Pembayaran Anda ditolak. Silakan unggah ulang bukti pembayaran.',
        data: {
          'orderId': orderId,
          'type': isValid ? 'payment_success' : 'payment_rejected',
        },
      );
    } catch (e) {
      debugPrint('Gagal mengirim notifikasi validasi pembayaran: $e');
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId);

      await _notifyCustomerOrderStatus(orderId, status);
      await loadAllOrders();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateOrderNotes(String orderId, String notes) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('orders')
          .update({'notes': notes.trim().isEmpty ? null : notes.trim()})
          .eq('id', orderId);
      await loadAllOrders();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> assignCourier(
    String orderId,
    String courierId,
    String taskType,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final existingTasks = await _supabase
          .from('courier_tasks')
          .select()
          .eq('order_id', orderId)
          .eq('task_type', taskType)
          .not('status', 'in', '(completed,cancelled)');

      if ((existingTasks as List<dynamic>).isNotEmpty) {
        _setError('Tugas kurir untuk tipe ini sudah ada');
        return false;
      }

      await _supabase.from('courier_tasks').insert({
        'id': _uuid.v4(),
        'order_id': orderId,
        'courier_id': courierId,
        'task_type': taskType,
        'status': 'assigned',
        'assigned_at': DateTime.now().toIso8601String(),
      });

      if (taskType == 'pickup') {
        await _supabase
            .from('orders')
            .update({'status': 'waiting_pickup'})
            .eq('id', orderId);
        await _notifyCustomerOrderStatus(orderId, 'waiting_pickup');
      }

      await loadAllOrders();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<CourierTaskModel>> getCourierTasksByOrder(String orderId) async {
    try {
      final data = await _supabase
          .from('courier_tasks')
          .select()
          .eq('order_id', orderId)
          .order('assigned_at', ascending: false);
      return _uniqueBy(
        (data as List<dynamic>).map(
          (t) => CourierTaskModel.fromJson(t as Map<String, dynamic>),
        ),
        (task) => task.id,
      );
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<List<CourierTaskModel>> getCourierTaskHistory(String courierId) async {
    try {
      final data = await _supabase
          .from('courier_tasks')
          .select('*, orders(order_code, order_type)')
          .eq('courier_id', courierId)
          .order('assigned_at', ascending: false);
      return _uniqueBy(
        (data as List<dynamic>).map(
          (t) => CourierTaskModel.fromJson(t as Map<String, dynamic>),
        ),
        (task) => task.id,
      );
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<bool> updateCourierProfile(
    String courierUserId,
    String name,
    String phone,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('profiles')
          .update({'name': name, 'phone': phone})
          .eq('user_id', courierUserId);
      await loadCouriers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateCourierAvailability(
    String courierUserId,
    bool isAvailable,
  ) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_available': isAvailable})
          .eq('user_id', courierUserId);
      await loadCouriers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Buat akun kurir baru tanpa mengganggu sesi admin yang sedang login.
  /// Memakai SupabaseClient terpisah (anon key) khusus untuk signUp, karena
  /// signUp via client SDK otomatis mengautentikasi sesi tersebut sebagai
  /// user baru - kalau dipanggil lewat client global, admin akan ter-logout
  /// dan tergantikan sesi kurir baru.
  Future<bool> createCourierAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _setLoading(true);
    _setError(null);
    final tempClient = SupabaseClient(
      SupabaseKeys.supabaseUrl,
      SupabaseKeys.supabaseAnonKey,
    );
    try {
      final response = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'phone': phone, 'role': 'courier'},
      );
      if (response.user == null) {
        _setError('Gagal membuat akun kurir');
        return false;
      }
      await loadCouriers();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan. Silakan coba lagi.');
      return false;
    } finally {
      await tempClient.dispose();
      _setLoading(false);
    }
  }

  Future<bool> validatePayment(String paymentId, bool isValid) async {
    _setLoading(true);
    _setError(null);
    try {
      final paymentData = await _supabase
          .from('payments')
          .select('order_id, orders(status)')
          .eq('id', paymentId)
          .single();
      final orderId = paymentData['order_id'] as String;
      final orderStatus =
          (paymentData['orders'] as Map<String, dynamic>?)?['status'];
      if (orderStatus == 'cancelled') {
        _setError(
          'Pesanan ini sudah dibatalkan, validasi pembayaran tidak bisa dilakukan',
        );
        return false;
      }

      final newStatus = isValid ? 'paid' : 'rejected';
      final updateData = <String, dynamic>{'status': newStatus};
      if (isValid) {
        updateData['paid_at'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('payments').update(updateData).eq('id', paymentId);

      if (isValid) {
        await _supabase
            .from('orders')
            .update({'payment_status': 'paid', 'status': 'paid'})
            .eq('id', orderId);
      } else {
        await _supabase
            .from('orders')
            .update({'payment_status': 'rejected'})
            .eq('id', orderId);
      }

      await _notifyCustomerPaymentValidated(orderId, isValid);
      await loadPendingPayments();
      await loadPaidPayments();
      await loadAllOrders();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateOrderWeight(
    String orderId,
    double weightKg,
    String serviceId,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      // Get selected kiloan service price. Customer normally chooses this
      // during order creation; admin may still adjust it before invoice.
      final serviceData = await _supabase
          .from('laundry_services')
          .select('name, price')
          .eq('id', serviceId)
          .single();
      final serviceName = serviceData['name'] as String? ?? '';
      final pricePerKg = (serviceData['price'] as num).toDouble();
      final billableWeightKg = _billableLaundryWeight(weightKg);
      final subtotal = billableWeightKg * pricePerKg;

      // Update the kiloan order item chosen by customer, or create it for
      // older orders that were made before kiloan service selection existed.
      final existingItems = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId)
          .eq('service_type', 'kiloan')
          .limit(1);

      if ((existingItems as List).isNotEmpty) {
        final existingItem = existingItems.first;
        await _supabase
            .from('order_items')
            .update({
              'service_id': serviceId,
              'service_name': serviceName,
              'weight_kg': weightKg,
              'price': pricePerKg,
              'subtotal': subtotal,
              'quantity': 1,
            })
            .eq('id', existingItem['id'] as String);
      } else {
        await _supabase.from('order_items').insert({
          'id': _uuid.v4(),
          'order_id': orderId,
          'service_id': serviceId,
          'service_name': serviceName,
          'service_type': 'kiloan',
          'quantity': 1,
          'weight_kg': weightKg,
          'price': pricePerKg,
          'subtotal': subtotal,
        });
      }

      // Recalculate order total. Jika voucher sudah dipasang ke order kiloan
      // setelah timbang, hitung ulang diskonnya dari subtotal final.
      final orderData = await _supabase
          .from('orders')
          .select('delivery_fee, discount_amount')
          .eq('id', orderId)
          .single();
      final deliveryFee = (orderData['delivery_fee'] as num).toDouble();
      var discount = (orderData['discount_amount'] as num).toDouble();
      final voucherData = await _supabase
          .from('vouchers')
          .select('discount_percent, max_discount')
          .eq('used_order_id', orderId)
          .eq('status', 'used')
          .maybeSingle();
      if (voucherData != null) {
        final percent =
            (voucherData['discount_percent'] as num?)?.toDouble() ?? 0;
        final rawDiscount = subtotal * (percent / 100);
        discount = rawDiscount > subtotal ? subtotal : rawDiscount;
        final maxDiscount = (voucherData['max_discount'] as num?)?.toDouble();
        if (maxDiscount != null && maxDiscount > 0 && discount > maxDiscount) {
          discount = maxDiscount;
        }
      }
      final total = subtotal + deliveryFee - discount;

      await _supabase
          .from('orders')
          .update({
            'subtotal': subtotal,
            'discount_amount': discount,
            'total_amount': total,
            'status': 'waiting_payment',
            'payment_status': 'pending',
          })
          .eq('id', orderId);

      await _notifyCustomerOrderStatus(orderId, 'waiting_payment');
      await loadAllOrders();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  double _billableLaundryWeight(double actualWeightKg) {
    const minWeightKg = 1.0;
    final roundedWeightKg = (actualWeightKg * 2).ceil() / 2;
    return roundedWeightKg < minWeightKg
        ? minWeightKg
        : roundedWeightKg.toDouble();
  }

  Future<bool> addService(
    String name,
    String type,
    double price,
    String unit,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('laundry_services').insert({
        'id': _uuid.v4(),
        'name': name,
        'service_type': type,
        'price': price,
        'unit': unit,
        'is_active': true,
      });
      await loadServices();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateService(
    String serviceId,
    String name,
    String type,
    double price,
    String unit,
    bool isActive,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('laundry_services')
          .update({
            'name': name,
            'service_type': type,
            'price': price,
            'unit': unit,
            'is_active': isActive,
          })
          .eq('id', serviceId);
      await loadServices();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteService(String serviceId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('laundry_services').delete().eq('id', serviceId);
      await loadServices();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addDeliveryFee(
    String name,
    double minKm,
    double? maxKm,
    double fee,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('delivery_fees').insert({
        'id': _uuid.v4(),
        'name': name,
        'min_distance_km': minKm,
        'max_distance_km': maxKm,
        'fee': fee,
        'is_active': true,
      });
      await loadDeliveryFees();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateDeliveryFee(
    String feeId,
    String name,
    double minKm,
    double? maxKm,
    double fee,
    bool isActive,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('delivery_fees')
          .update({
            'name': name,
            'min_distance_km': minKm,
            'max_distance_km': maxKm,
            'fee': fee,
            'is_active': isActive,
          })
          .eq('id', feeId);
      await loadDeliveryFees();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*), payments(*), addresses(address_text)')
          .eq('id', orderId)
          .single();
      final enriched = await _enrichOrdersWithCustomer([data]);
      return OrderModel.fromJson(enriched.first);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getOrderStatusHistory(
    String orderId,
  ) async {
    try {
      final data = await _supabase
          .from('order_status_histories')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<PaymentModel?> getPaymentById(String paymentId) async {
    try {
      final data = await _supabase
          .from('payments')
          .select()
          .eq('id', paymentId)
          .single();
      return PaymentModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  void subscribeToRealtime() {
    if (_channel != null) return;
    _channel = _supabase
        .channel('admin_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => loadAllOrders(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          callback: (_) {
            loadPendingPayments();
            loadPaidPayments();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'courier_tasks',
          callback: (_) => loadActiveCourierTasks(),
        )
        .subscribe();
  }

  void unsubscribeFromRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
