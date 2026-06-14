class LoyaltyModel {
  final String id;
  final String userId;
  final int totalCompletedOrders;
  final int currentCycleCount;
  final int totalVouchersEarned;

  LoyaltyModel({
    required this.id,
    required this.userId,
    required this.totalCompletedOrders,
    required this.currentCycleCount,
    required this.totalVouchersEarned,
  });

  factory LoyaltyModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      totalCompletedOrders: json['total_completed_orders'] as int? ?? 0,
      currentCycleCount: json['current_cycle_count'] as int? ?? 0,
      totalVouchersEarned: json['total_vouchers_earned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_completed_orders': totalCompletedOrders,
      'current_cycle_count': currentCycleCount,
      'total_vouchers_earned': totalVouchersEarned,
    };
  }
}
