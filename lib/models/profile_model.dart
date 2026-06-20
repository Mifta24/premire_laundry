class ProfileModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String role;
  final bool isAvailable;
  final String? avatarUrl;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    this.isAvailable = true,
    this.avatarUrl,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      isAvailable: json['is_available'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'role': role,
      'is_available': isAvailable,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? role,
    bool? isAvailable,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isAvailable: isAvailable ?? this.isAvailable,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
