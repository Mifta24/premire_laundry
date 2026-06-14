class LaundryServiceModel {
  final String id;
  final String name;
  final String serviceType;
  final double price;
  final String unit;
  final bool isActive;

  LaundryServiceModel({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.price,
    required this.unit,
    required this.isActive,
  });

  factory LaundryServiceModel.fromJson(Map<String, dynamic> json) {
    return LaundryServiceModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? 'kiloan',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'service_type': serviceType,
      'price': price,
      'unit': unit,
      'is_active': isActive,
    };
  }

  LaundryServiceModel copyWith({
    String? id,
    String? name,
    String? serviceType,
    double? price,
    String? unit,
    bool? isActive,
  }) {
    return LaundryServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      serviceType: serviceType ?? this.serviceType,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
    );
  }
}
