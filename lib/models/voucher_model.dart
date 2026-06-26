class VoucherModel {
  final String id;
  final String? userId;
  final String code;
  final String type;
  final double? discountPercent;
  final double? maxDiscount;
  final String status;
  final DateTime? expiredAt;
  final String? usedOrderId;
  final DateTime? createdAt;
  final String? customerName;
  final String? customerPhone;

  VoucherModel({
    required this.id,
    this.userId,
    required this.code,
    required this.type,
    this.discountPercent,
    this.maxDiscount,
    required this.status,
    this.expiredAt,
    this.usedOrderId,
    this.createdAt,
    this.customerName,
    this.customerPhone,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      code: json['code'] as String? ?? '',
      type: json['type'] as String? ?? 'free_laundry',
      discountPercent: json['discount_percent'] != null
          ? (json['discount_percent'] as num).toDouble()
          : null,
      maxDiscount: json['max_discount'] != null
          ? (json['max_discount'] as num).toDouble()
          : null,
      status: json['status'] as String? ?? 'active',
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      usedOrderId: json['used_order_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'code': code,
      'type': type,
      'discount_percent': discountPercent,
      'max_discount': maxDiscount,
      'status': status,
      'expired_at': expiredAt?.toIso8601String(),
      'used_order_id': usedOrderId,
    };
  }
}
