class OrderItemModel {
  final String id;
  final String orderId;
  final String serviceId;
  final String serviceName;
  final String serviceType;
  final int quantity;
  final double? weightKg;
  final double price;
  final double subtotal;
  final String? notes;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.serviceId,
    required this.serviceName,
    required this.serviceType,
    required this.quantity,
    this.weightKg,
    required this.price,
    required this.subtotal,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      serviceId: json['service_id'] as String? ?? '',
      serviceName: json['service_name'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? 'kiloan',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      weightKg: json['weight_kg'] != null
          ? (json['weight_kg'] as num).toDouble()
          : null,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'service_id': serviceId,
      'service_name': serviceName,
      'service_type': serviceType,
      'quantity': quantity,
      'weight_kg': weightKg,
      'price': price,
      'subtotal': subtotal,
      'notes': notes,
    };
  }
}
