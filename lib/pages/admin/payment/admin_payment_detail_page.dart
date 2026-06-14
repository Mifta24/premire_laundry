import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/payment_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/status_badge.dart';

class AdminPaymentDetailPage extends StatefulWidget {
  final String paymentId;
  const AdminPaymentDetailPage({super.key, required this.paymentId});

  @override
  State<AdminPaymentDetailPage> createState() =>
      _AdminPaymentDetailPageState();
}

class _AdminPaymentDetailPageState extends State<AdminPaymentDetailPage> {
  PaymentModel? _payment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final payment =
        await context.read<AdminProvider>().getPaymentById(widget.paymentId);
    setState(() {
      _payment = payment;
      _isLoading = false;
    });
  }

  Future<void> _validate(bool isValid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isValid ? 'Validasi Pembayaran' : 'Tolak Pembayaran'),
        content: Text(isValid
            ? 'Konfirmasi pembayaran ini sebagai valid?'
            : 'Tolak pembayaran ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isValid ? 'Validasi' : 'Tolak',
              style: TextStyle(
                  color: isValid ? AppColors.success : AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<AdminProvider>();
    final ok = await provider.validatePayment(widget.paymentId, isValid);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isValid ? 'Pembayaran berhasil divalidasi' : 'Pembayaran ditolak'),
          backgroundColor: isValid ? AppColors.success : AppColors.error,
        ),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Operasi gagal'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pembayaran'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_payment == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pembayaran'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Pembayaran tidak ditemukan')),
      );
    }

    final p = _payment!;
    final provider = context.watch<AdminProvider>();
    final isPending = p.status == 'waiting_verification';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pembayaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi Pembayaran',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const Divider(height: 16),
                    _row('Order ID',
                        p.orderId.substring(0, 8).toUpperCase()),
                    _row('Metode',
                        p.method == 'manual_qris'
                            ? 'QRIS Manual'
                            : p.method == 'manual_transfer'
                                ? 'Transfer Manual'
                                : p.method),
                    _row('Jumlah', formatRupiah(p.amount), bold: true),
                    Row(
                      children: [
                        const SizedBox(
                            width: 110,
                            child: Text('Status',
                                style: TextStyle(color: Colors.grey))),
                        StatusBadge(status: p.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (p.paymentProofUrl != null) ...[
              const Text('Bukti Pembayaran',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: p.paymentProofUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (ctx, url) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (ctx, url, err) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 64, color: Colors.grey)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed: () => _validate(false),
                      label: 'Tolak',
                      isOutlined: true,
                      color: AppColors.error,
                      isLoading: provider.isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      onPressed: () => _validate(true),
                      label: 'Validasi',
                      color: AppColors.success,
                      isLoading: provider.isLoading,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.status == 'paid'
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      p.status == 'paid'
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: p.status == 'paid'
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      p.status == 'paid'
                          ? 'Pembayaran telah divalidasi'
                          : 'Pembayaran telah ditolak',
                      style: TextStyle(
                        color: p.status == 'paid'
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
          ),
        ],
      ),
    );
  }
}
