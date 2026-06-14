class PaymentModel {
  final String id;
  final String orderId;
  final String customerId;
  final String method;
  final String? provider;
  final double amount;
  final String status;
  final String? paymentProofUrl;
  final String? providerReference;
  final String? paymentUrl;
  final DateTime? paidAt;

  PaymentModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.method,
    this.provider,
    required this.amount,
    required this.status,
    this.paymentProofUrl,
    this.providerReference,
    this.paymentUrl,
    this.paidAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      customerId: json['customer_id'] as String,
      method: json['method'] as String? ?? 'manual_qris',
      provider: json['provider'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      paymentProofUrl: json['payment_proof_url'] as String?,
      providerReference: json['provider_reference'] as String?,
      paymentUrl: json['payment_url'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'customer_id': customerId,
      'method': method,
      'provider': provider,
      'amount': amount,
      'status': status,
      'payment_proof_url': paymentProofUrl,
      'provider_reference': providerReference,
      'payment_url': paymentUrl,
      'paid_at': paidAt?.toIso8601String(),
    };
  }
}
