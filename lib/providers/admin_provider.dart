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
  bool get isLoading => _isLoading;
  String? get error => _error;

  double revenueWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _paidPayments
        .where((p) => p.paidAt != null && p.paidAt!.isAfter(cutoff))
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  double get todayRevenue {
    final now = DateTime.now();
    return _paidPayments
        .where((p) =>
            p.paidAt != null &&
            p.paidAt!.year == now.year &&
            p.paidAt!.month == now.month &&
            p.paidAt!.day == now.day)
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  double get monthRevenue {
    final now = DateTime.now();
    return _paidPayments
        .where((p) =>
            p.paidAt != null &&
            p.paidAt!.year == now.year &&
            p.paidAt!.month == now.month)
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  /// Total pendapatan per hari untuk 7 hari terakhir (index 0 = 6 hari lalu, index 6 = hari ini).
  List<double> get last7DaysRevenue {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    return days.map((day) {
      return _paidPayments
          .where((p) =>
              p.paidAt != null &&
              p.paidAt!.year == day.year &&
              p.paidAt!.month == day.month &&
              p.paidAt!.day == day.day)
          .fold<double>(0, (sum, p) => sum + p.amount);
    }).toList();
  }

  int activeTaskCountFor(String courierId) {
    return _activeCourierTasks
        .where((t) =>
            t.courierId == courierId &&
            t.status != 'picked_up' &&
            t.status != 'delivered' &&
            t.status != 'completed' &&
            t.status != 'cancelled')
        .length;
  }

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item,
    ];
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
          .gte('paid_at', cutoff.toIso8601String())
          .order('paid_at', ascending: false);
      _paidPayments = _uniqueBy(
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
        (service) => service.id,
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
        (fee) => fee.id,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
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

      await loadPendingPayments();
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
      // Get service price
      final serviceData = await _supabase
          .from('laundry_services')
          .select('price')
          .eq('id', serviceId)
          .single();
      final pricePerKg = (serviceData['price'] as num).toDouble();
      final subtotal = weightKg * pricePerKg;

      // Update or insert order item
      final existingItems = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId)
          .eq('service_id', serviceId);

      if ((existingItems as List).isNotEmpty) {
        await _supabase
            .from('order_items')
            .update({
              'weight_kg': weightKg,
              'price': pricePerKg,
              'subtotal': subtotal,
              'quantity': 1,
            })
            .eq('order_id', orderId)
            .eq('service_id', serviceId);
      } else {
        final serviceInfo = await _supabase
            .from('laundry_services')
            .select()
            .eq('id', serviceId)
            .single();
        await _supabase.from('order_items').insert({
          'id': _uuid.v4(),
          'order_id': orderId,
          'service_id': serviceId,
          'service_name': serviceInfo['name'],
          'service_type': 'kiloan',
          'quantity': 1,
          'weight_kg': weightKg,
          'price': pricePerKg,
          'subtotal': subtotal,
        });
      }

      // Recalculate order total
      final orderData = await _supabase
          .from('orders')
          .select('delivery_fee, discount_amount')
          .eq('id', orderId)
          .single();
      final deliveryFee = (orderData['delivery_fee'] as num).toDouble();
      final discount = (orderData['discount_amount'] as num).toDouble();
      final total = subtotal + deliveryFee - discount;

      await _supabase
          .from('orders')
          .update({
            'subtotal': subtotal,
            'total_amount': total,
            'status': 'waiting_payment',
            'payment_status': 'pending',
          })
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
    double maxKm,
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
    double maxKm,
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
