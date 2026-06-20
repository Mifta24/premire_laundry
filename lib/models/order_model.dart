import 'order_item_model.dart';
import 'payment_model.dart';

class OrderModel {
  final String id;
  final String orderCode;
  final String customerId;
  final String? addressId;
  final String orderType;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double totalAmount;
  final double? estimatedDistanceKm;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItemModel> orderItems;
  final PaymentModel? payment;
  final String? customerName;
  final String? customerPhone;
  final String? addressText;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.customerId,
    this.addressId,
    required this.orderType,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.totalAmount,
    this.estimatedDistanceKm,
    this.notes,
    required this.createdAt,
    this.orderItems = const [],
    this.payment,
    this.customerName,
    this.customerPhone,
    this.addressText,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> items = [];
    if (json['order_items'] != null) {
      items = (json['order_items'] as List)
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    PaymentModel? payment;
    if (json['payments'] != null) {
      final paymentData = json['payments'];
      if (paymentData is List && paymentData.isNotEmpty) {
        payment = PaymentModel.fromJson(paymentData[0] as Map<String, dynamic>);
      } else if (paymentData is Map) {
        payment = PaymentModel.fromJson(paymentData as Map<String, dynamic>);
      }
    }

    return OrderModel(
      id: json['id'] as String,
      orderCode: json['order_code'] as String? ?? '',
      customerId: json['customer_id'] as String,
      addressId: json['address_id'] as String?,
      orderType: json['order_type'] as String? ?? 'kiloan',
      status: json['status'] as String? ?? 'created',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      estimatedDistanceKm: json['estimated_distance_km'] != null
          ? (json['estimated_distance_km'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      orderItems: items,
      payment: payment,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      addressText: json['address_text'] as String? ??
          (json['addresses'] is Map
              ? (json['addresses'] as Map)['address_text'] as String?
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_code': orderCode,
      'customer_id': customerId,
      'address_id': addressId,
      'order_type': orderType,
      'status': status,
      'payment_status': paymentStatus,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'estimated_distance_km': estimatedDistanceKm,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
