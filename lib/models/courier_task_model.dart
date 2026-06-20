class CourierTaskModel {
  final String id;
  final String orderId;
  final String courierId;
  final String taskType;
  final String status;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final String? orderCode;
  final String? orderType;
  final double? totalAmount;
  final String? customerName;
  final String? customerPhone;
  final String? addressText;
  final String? addressNotes;
  final double? addressLatitude;
  final double? addressLongitude;
  final String? customerNotes;

  CourierTaskModel({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.taskType,
    required this.status,
    this.assignedAt,
    this.completedAt,
    this.orderCode,
    this.orderType,
    this.totalAmount,
    this.customerName,
    this.customerPhone,
    this.addressText,
    this.addressNotes,
    this.addressLatitude,
    this.addressLongitude,
    this.customerNotes,
  });

  factory CourierTaskModel.fromJson(Map<String, dynamic> json) {
    String? orderCode;
    String? orderType;
    double? totalAmount;
    String? customerName;
    String? customerPhone;
    String? addressText;
    String? addressNotes;
    double? addressLatitude;
    double? addressLongitude;
    String? customerNotes;

    if (json['orders'] != null) {
      final order = json['orders'] as Map<String, dynamic>;
      orderCode = order['order_code'] as String?;
      orderType = order['order_type'] as String?;
      totalAmount = order['total_amount'] != null
          ? (order['total_amount'] as num).toDouble()
          : null;
      customerNotes = order['notes'] as String?;

      if (order['profiles'] != null) {
        final profile = order['profiles'] as Map<String, dynamic>;
        customerName = profile['name'] as String?;
        customerPhone = profile['phone'] as String?;
      }

      if (order['addresses'] != null) {
        final address = order['addresses'] as Map<String, dynamic>;
        addressText = address['address_text'] as String?;
        addressNotes = address['notes'] as String?;
        addressLatitude = address['latitude'] != null
            ? (address['latitude'] as num).toDouble()
            : null;
        addressLongitude = address['longitude'] != null
            ? (address['longitude'] as num).toDouble()
            : null;
      }
    }

    return CourierTaskModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      courierId: json['courier_id'] as String,
      taskType: json['task_type'] as String? ?? 'pickup',
      status: json['status'] as String? ?? 'assigned',
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      orderCode: orderCode,
      orderType: orderType,
      totalAmount: totalAmount,
      customerName: customerName,
      customerPhone: customerPhone,
      addressText: addressText,
      addressNotes: addressNotes,
      addressLatitude: addressLatitude,
      addressLongitude: addressLongitude,
      customerNotes: customerNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'courier_id': courierId,
      'task_type': taskType,
      'status': status,
      'assigned_at': assignedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
