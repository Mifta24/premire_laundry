class AddressModel {
  final String id;
  final String userId;
  final String label;
  final String addressText;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.addressText,
    this.latitude,
    this.longitude,
    this.notes,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String? ?? '',
      addressText: json['address_text'] as String? ?? '',
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'address_text': addressText,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? userId,
    String? label,
    String? addressText,
    double? latitude,
    double? longitude,
    String? notes,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      addressText: addressText ?? this.addressText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
