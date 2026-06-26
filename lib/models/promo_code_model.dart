class PromoCodeModel {
  final String id;
  final String code;
  final double discountPercent;
  final double? maxDiscount;
  final bool newUserOnly;
  final bool isActive;
  final DateTime? expiredAt;
  final DateTime? createdAt;

  PromoCodeModel({
    required this.id,
    required this.code,
    required this.discountPercent,
    this.maxDiscount,
    required this.newUserOnly,
    required this.isActive,
    this.expiredAt,
    this.createdAt,
  });

  factory PromoCodeModel.fromJson(Map<String, dynamic> json) {
    return PromoCodeModel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      discountPercent:
          (json['discount_percent'] as num?)?.toDouble() ?? 0,
      maxDiscount: json['max_discount'] != null
          ? (json['max_discount'] as num).toDouble()
          : null,
      newUserOnly: json['new_user_only'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_percent': discountPercent,
      'max_discount': maxDiscount,
      'new_user_only': newUserOnly,
      'is_active': isActive,
      'expired_at': expiredAt?.toIso8601String(),
    };
  }
}
