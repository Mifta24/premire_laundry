import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/voucher_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';

class VoucherListPage extends StatefulWidget {
  const VoucherListPage({super.key});

  @override
  State<VoucherListPage> createState() => _VoucherListPageState();
}

class _VoucherListPageState extends State<VoucherListPage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await Future.wait([
        context.read<CustomerProvider>().loadVouchers(userId),
        context.read<CustomerProvider>().loadLoyalty(userId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final active = provider.vouchers
        .where((v) => v.status == 'active')
        .toList();
    final riwayat = provider.vouchers
        .where((v) => v.status == 'used' || v.status == 'expired')
        .toList();
    final loyaltyPoints = provider.loyaltyPoints?.totalCompletedOrders ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Loyalty banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.lightBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Poin Loyalty Anda',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$loyaltyPoints',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, color: Colors.amber, size: 22),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kumpulkan 10 order selesai untuk mendapatkan voucher gratis 1x cuci',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.card_giftcard, color: Colors.white, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabs
          Row(
            children: [
              _tabButton('Voucher Aktif', 0),
              const SizedBox(width: 20),
              _tabButton('Riwayat Voucher', 1),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (provider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_tab == 0)
            if (active.isEmpty)
              _emptyState('Belum ada voucher aktif')
            else
              ...active.map((v) => _voucherCard(v, isActive: true))
          else if (riwayat.isEmpty)
            _emptyState('Belum ada riwayat voucher')
          else
            ...riwayat.map((v) => _voucherCard(v, isActive: false)),

          if (_tab == 0 && active.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Masukkan kode voucher saat checkout atau sebelum pembayaran untuk memakai diskon.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 90,
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.card_giftcard, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  ({String title, String desc, Color color, String pct}) _voucherInfo(
    VoucherModel v,
  ) {
    if (v.type == 'free_laundry') {
      return (
        title: 'Voucher Gratis 1x Cuci',
        desc: 'Berlaku untuk semua layanan laundry (kecuali ongkir)',
        color: AppColors.accentPurple,
        pct: '100%',
      );
    }
    final pct = v.discountPercent?.toStringAsFixed(0) ?? '0';
    return (
      title: 'Diskon $pct% Semua Layanan',
      desc: 'Diskon $pct% untuk pesanan laundry Anda',
      color: AppColors.warning,
      pct: '$pct%',
    );
  }

  Widget _voucherCard(VoucherModel v, {required bool isActive}) {
    final info = _voucherInfo(v);
    final color = isActive ? info.color : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isActive ? Colors.white : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    info.pct,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    v.type == 'free_laundry' ? 'GRATIS' : 'DISKON',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          info.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.accentPurple.withValues(alpha: 0.12)
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? AppColors.accentPurple
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.desc,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (v.expiredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Berlaku sampai ${formatTanggalSingkat(v.expiredAt!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  if (isActive) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1,
                        minHeight: 5,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sisa 1 dari 1x pakai',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
