import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/admin_provider.dart';

class AdminPaymentListPage extends StatefulWidget {
  const AdminPaymentListPage({super.key});

  @override
  State<AdminPaymentListPage> createState() => _AdminPaymentListPageState();
}

class _AdminPaymentListPageState extends State<AdminPaymentListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<AdminProvider>().loadPendingPayments();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.pendingPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Tidak ada pembayaran menunggu verifikasi',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.pendingPayments.length,
        itemBuilder: (context, i) {
          final payment = provider.pendingPayments[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => context.push('/admin/payment/${payment.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Proof thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: payment.paymentProofUrl != null
                          ? CachedNetworkImage(
                              imageUrl: payment.paymentProofUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(
                                width: 64,
                                height: 64,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image,
                                    color: Colors.grey),
                              ),
                              errorWidget: (ctx, url, err) => Container(
                                width: 64,
                                height: 64,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: Colors.grey[200],
                              child: const Icon(Icons.receipt,
                                  color: Colors.grey, size: 32),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.orderId.substring(0, 8).toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatRupiah(payment.amount),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Menunggu Verifikasi',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
