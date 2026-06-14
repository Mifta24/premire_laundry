import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/voucher_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';

class VoucherListPage extends StatefulWidget {
  const VoucherListPage({super.key});

  @override
  State<VoucherListPage> createState() => _VoucherListPageState();
}

class _VoucherListPageState extends State<VoucherListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<CustomerProvider>().loadVouchers(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final active = provider.vouchers.where((v) => v.status == 'active').toList();
    final used = provider.vouchers
        .where((v) => v.status == 'used' || v.status == 'expired')
        .toList();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Belum ada voucher',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Selesaikan 10 pesanan untuk mendapat voucher gratis!',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active.isNotEmpty) ...[
            const Text('Voucher Aktif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...active.map((v) => _voucherCard(v, isActive: true)),
            const SizedBox(height: 16),
          ],
          if (used.isNotEmpty) ...[
            const Text('Voucher Terpakai / Kadaluarsa',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            ...used.map((v) => _voucherCard(v, isActive: false)),
          ],
        ],
      ),
    );
  }

  Widget _voucherCard(VoucherModel v, {required bool isActive}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isActive ? Colors.white : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.secondary.withValues(alpha: 0.15)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.card_giftcard,
                color: isActive ? AppColors.secondary : Colors.grey,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.code,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.primary : Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v.type == 'free_laundry'
                        ? 'Gratis Laundry Kiloan'
                        : v.discountPercent != null
                            ? 'Diskon ${v.discountPercent!.toStringAsFixed(0)}%'
                            : 'Voucher',
                    style: TextStyle(
                        color: isActive
                            ? AppColors.secondary
                            : Colors.grey[500],
                        fontWeight: FontWeight.w500),
                  ),
                  if (v.expiredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Berlaku hingga: ${v.expiredAt!.day}/${v.expiredAt!.month}/${v.expiredAt!.year}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isActive ? Colors.grey[600] : Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.success.withValues(alpha: 0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive
                    ? 'Aktif'
                    : v.status == 'used'
                        ? 'Terpakai'
                        : 'Kadaluarsa',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.success : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
