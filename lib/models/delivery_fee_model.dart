class DeliveryFeeModel {
  final String id;
  final String name;
  final double minDistanceKm;
  final double maxDistanceKm;
  final double fee;
  final bool isActive;

  DeliveryFeeModel({
    required this.id,
    required this.name,
    required this.minDistanceKm,
    required this.maxDistanceKm,
    required this.fee,
    required this.isActive,
  });

  factory DeliveryFeeModel.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      minDistanceKm: (json['min_distance_km'] as num?)?.toDouble() ?? 0.0,
      maxDistanceKm: (json['max_distance_km'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'min_distance_km': minDistanceKm,
      'max_distance_km': maxDistanceKm,
      'fee': fee,
      'is_active': isActive,
    };
  }
}
