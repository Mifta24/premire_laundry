import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/order_model.dart';
import '../models/address_model.dart';
import '../models/voucher_model.dart';
import '../models/loyalty_model.dart';

class CustomerProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  List<OrderModel> _orders = [];
  List<AddressModel> _addresses = [];
  List<VoucherModel> _vouchers = [];
  LoyaltyModel? _loyaltyPoints;
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  List<AddressModel> get addresses => _addresses;
  List<VoucherModel> get vouchers => _vouchers;
  LoyaltyModel? get loyaltyPoints => _loyaltyPoints;
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

  Future<void> loadOrders(String userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*), payments(*)')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      _orders = (data as List)
          .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
          .toList();
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
          .order('is_default', ascending: false);
      _addresses = (data as List)
          .map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
          .toList();
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
      _vouchers = (data as List)
          .map((v) => VoucherModel.fromJson(v as Map<String, dynamic>))
          .toList();
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

  String _generateOrderCode() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
    return 'PL-$datePart-$random';
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
      final orderCode = _generateOrderCode();

      await _supabase.from('orders').insert({
        'id': orderId,
        'order_code': orderCode,
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
      });

      if (items.isNotEmpty) {
        final itemsToInsert = items
            .map((item) => {
                  ...item,
                  'order_id': orderId,
                  'id': _uuid.v4(),
                })
            .toList();
        await _supabase.from('order_items').insert(itemsToInsert);
      }

      // Mark voucher as used if applicable
      if (voucherCode != null && voucherCode.isNotEmpty) {
        await _supabase
            .from('vouchers')
            .update({'status': 'used', 'used_order_id': orderId}).eq(
                'code', voucherCode);
      }

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
          .update({'status': 'cancelled'}).eq('id', orderId);
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
      String orderId, String paymentId, File imageFile) async {
    _setLoading(true);
    _setError(null);
    try {
      final fileName = 'proof_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from('payment-proofs')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));

      final publicUrl = _supabase.storage
          .from('payment-proofs')
          .getPublicUrl(fileName);

      await _supabase.from('payments').update({
        'payment_proof_url': publicUrl,
        'status': 'waiting_verification',
      }).eq('id', paymentId);

      await _supabase
          .from('orders')
          .update({'payment_status': 'waiting_verification'}).eq('id', orderId);

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
            .update({'is_default': false}).eq('user_id', userId);
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
      await _supabase.from('addresses').delete().eq('id', addressId);
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
          .update({'is_default': false}).eq('user_id', userId);
      await _supabase
          .from('addresses')
          .update({'is_default': true}).eq('id', addressId);
      await loadAddresses(userId);
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
}
