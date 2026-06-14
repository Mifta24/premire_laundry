import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';
import '../models/laundry_service_model.dart';
import '../models/profile_model.dart';
import '../models/delivery_fee_model.dart';

class AdminProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  List<OrderModel> _allOrders = [];
  List<PaymentModel> _pendingPayments = [];
  List<LaundryServiceModel> _services = [];
  List<ProfileModel> _couriers = [];
  List<DeliveryFeeModel> _deliveryFees = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _channel;

  List<OrderModel> get allOrders => _allOrders;
  List<PaymentModel> get pendingPayments => _pendingPayments;
  List<LaundryServiceModel> get services => _services;
  List<ProfileModel> get couriers => _couriers;
  List<DeliveryFeeModel> get deliveryFees => _deliveryFees;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
          .select('*, order_items(*), payments(*)')
          .order('created_at', ascending: false);
      _allOrders = (data as List<dynamic>)
          .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
          .toList();
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
      _pendingPayments = (data as List<dynamic>)
          .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
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
      _services = (data as List<dynamic>)
          .map((s) => LaundryServiceModel.fromJson(s as Map<String, dynamic>))
          .toList();
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
      _couriers = (data as List<dynamic>)
          .map((c) => ProfileModel.fromJson(c as Map<String, dynamic>))
          .toList();
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
      _deliveryFees = (data as List<dynamic>)
          .map((f) => DeliveryFeeModel.fromJson(f as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateOrderStatus(
      String orderId, String status, String? note) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase
          .from('orders')
          .update({'status': status}).eq('id', orderId);

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
      String orderId, String courierId, String taskType) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('courier_tasks').insert({
        'id': _uuid.v4(),
        'order_id': orderId,
        'courier_id': courierId,
        'task_type': taskType,
        'status': 'assigned',
        'assigned_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> validatePayment(String paymentId, bool isValid) async {
    _setLoading(true);
    _setError(null);
    try {
      final newStatus = isValid ? 'paid' : 'rejected';
      final updateData = <String, dynamic>{'status': newStatus};
      if (isValid) {
        updateData['paid_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('payments')
          .update(updateData)
          .eq('id', paymentId);

      // Also update the order payment_status and order status
      final paymentData = await _supabase
          .from('payments')
          .select('order_id')
          .eq('id', paymentId)
          .single();
      final orderId = paymentData['order_id'] as String;

      if (isValid) {
        await _supabase.from('orders').update({
          'payment_status': 'paid',
          'status': 'paid',
        }).eq('id', orderId);
      } else {
        await _supabase.from('orders').update({
          'payment_status': 'rejected',
        }).eq('id', orderId);
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
      String orderId, double weightKg, String serviceId) async {
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
        await _supabase.from('order_items').update({
          'weight_kg': weightKg,
          'price': pricePerKg,
          'subtotal': subtotal,
          'quantity': 1,
        }).eq('order_id', orderId).eq('service_id', serviceId);
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

      await _supabase.from('orders').update({
        'subtotal': subtotal,
        'total_amount': total,
        'status': 'waiting_payment',
        'payment_status': 'pending',
      }).eq('id', orderId);

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
      String name, String type, double price, String unit) async {
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

  Future<bool> updateService(String serviceId, String name, String type,
      double price, String unit, bool isActive) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('laundry_services').update({
        'name': name,
        'service_type': type,
        'price': price,
        'unit': unit,
        'is_active': isActive,
      }).eq('id', serviceId);
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
      await _supabase
          .from('laundry_services')
          .delete()
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

  Future<bool> addDeliveryFee(
      String name, double minKm, double maxKm, double fee) async {
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

  Future<bool> updateDeliveryFee(String feeId, String name, double minKm,
      double maxKm, double fee, bool isActive) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.from('delivery_fees').update({
        'name': name,
        'min_distance_km': minKm,
        'max_distance_km': maxKm,
        'fee': fee,
        'is_active': isActive,
      }).eq('id', feeId);
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
          .select('*, order_items(*), payments(*)')
          .eq('id', orderId)
          .single();
      return OrderModel.fromJson(data);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getOrderStatusHistory(
      String orderId) async {
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
          callback: (_) => loadPendingPayments(),
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
