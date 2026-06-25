import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  static const _faqs = [
    (
      q: 'Bagaimana cara membuat pesanan?',
      a: 'Tekan tombol "+" di Beranda, pilih jenis layanan (Kiloan/Satuan), tentukan alamat pengantaran, lalu tekan "Buat Pesanan". Untuk laundry kiloan, tagihan dihitung setelah pakaian ditimbang di toko.',
    ),
    (
      q: 'Metode pembayaran apa yang tersedia?',
      a: 'Tersedia QRIS Manual (scan QRIS lalu upload bukti pembayaran) dan Xendit (transfer bank, e-wallet, kartu kredit).',
    ),
    (
      q: 'Bagaimana cara melacak status pesanan saya?',
      a: 'Buka tab "Pesanan", lalu pilih pesanan yang ingin dilihat untuk melihat detail dan riwayat status secara real-time, mulai dari penjemputan hingga pesanan selesai.',
    ),
    (
      q: 'Apakah pesanan bisa dibatalkan?',
      a: 'Pesanan dapat dibatalkan selama statusnya masih "Dibuat" dan belum dibayar. Setelah kurir ditugaskan atau pembayaran diterima, pesanan tidak dapat dibatalkan secara mandiri — silakan hubungi admin.',
    ),
    (
      q: 'Bagaimana cara kerja poin loyalty?',
      a: 'Setiap pesanan yang selesai menambah 1 poin loyalty. Setelah terkumpul 10 poin, Anda akan mendapatkan voucher gratis 1x cuci yang bisa digunakan untuk pesanan berikutnya (ongkir tetap dibayar).',
    ),
    (
      q: 'Bagaimana cara menggunakan voucher?',
      a: 'Masukkan kode voucher saat checkout atau sebelum pembayaran. Untuk laundry kiloan, gunakan voucher setelah admin menimbang pakaian dan total layanan tersedia.',
    ),
    (
      q: 'Bagaimana jika bukti pembayaran QRIS saya ditolak?',
      a: 'Anda dapat mengunggah ulang bukti pembayaran yang valid melalui halaman detail pesanan. Admin akan memverifikasi ulang setelah bukti baru diterima.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bantuan & FAQ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pertanyaan yang Sering Diajukan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        _faqs[i].q,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      iconColor: AppColors.primary,
                      collapsedIconColor: Colors.grey,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.topLeft,
                      children: [
                        Text(
                          _faqs[i].a,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.support_agent, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Masih butuh bantuan?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Hubungi admin Premier Laundry melalui toko untuk pertanyaan lain seputar pesanan atau akun Anda.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
