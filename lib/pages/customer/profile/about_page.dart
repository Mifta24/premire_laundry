import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/app_logo.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _features = [
    (
      icon: Icons.shield_outlined,
      title: 'Aman & Terpercaya',
      desc: 'Data dan transaksi Anda 100% aman.',
    ),
    (
      icon: Icons.access_time_outlined,
      title: 'Cepat & Tepat Waktu',
      desc: 'Jemput dan antar sesuai waktu yang dijanjikan.',
    ),
    (
      icon: Icons.checkroom_outlined,
      title: 'Bersih & Berkualitas',
      desc: 'Standar kebersihan terbaik untuk setiap pakaian.',
    ),
    (
      icon: Icons.support_agent_outlined,
      title: 'Customer Support',
      desc: 'Kami siap membantu Anda kapan saja.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tentang Premier Laundry'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const AppLogoWithText(logoSize: 84),
            const SizedBox(height: 24),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Versi 1.0.0',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Premier Laundry adalah layanan laundry kiloan dan satuan dengan sistem jemput-antar, dilengkapi pelacakan status pesanan secara real-time dan program loyalty untuk pelanggan setia.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mengapa Memilih Kami',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
            ),
            const SizedBox(height: 8),
            ..._features.map(
              (f) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(f.icon, color: AppColors.primary),
                  ),
                  title: Text(f.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(f.desc,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '© 2026 Premier Laundry. All rights reserved.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
