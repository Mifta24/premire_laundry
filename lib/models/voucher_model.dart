class VoucherModel {
  final String id;
  final String? userId;
  final String code;
  final String type;
  final double? discountPercent;
  final String status;
  final DateTime? expiredAt;
  final String? usedOrderId;

  VoucherModel({
    required this.id,
    this.userId,
    required this.code,
    required this.type,
    this.discountPercent,
    required this.status,
    this.expiredAt,
    this.usedOrderId,
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
      status: json['status'] as String? ?? 'active',
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      usedOrderId: json['used_order_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'code': code,
      'type': type,
      'discount_percent': discountPercent,
      'status': status,
      'expired_at': expiredAt?.toIso8601String(),
      'used_order_id': usedOrderId,
    };
  }
}
