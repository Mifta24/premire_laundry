import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/courier_task_card.dart';

class CourierDashboardPage extends StatelessWidget {
  final void Function(int index) onNavigateTab;
  final Future<void> Function() onRefresh;

  const CourierDashboardPage({
    super.key,
    required this.onNavigateTab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final provider = context.watch<CourierProvider>();

    final preview = [...provider.pickupTasks, ...provider.deliveryTasks]
        .where((t) => t.status != 'picked_up' && t.status != 'delivered')
        .take(3)
        .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, ${profile?.name ?? 'Kurir'} 👋',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              'Semangat mengantar hari ini!',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _statCard('Jemput Hari Ini', '${provider.activePickupCount}',
                      Icons.shopping_bag_outlined, AppColors.warning),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard('Antar Hari Ini', '${provider.activeDeliveryCount}',
                      Icons.local_shipping_outlined, AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard('Selesai', '${provider.completedTodayCount}',
                      Icons.check_circle_outline, AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tugas Mendatang',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => onNavigateTab(1),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (preview.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.task_alt_outlined,
                          size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Tidak ada tugas saat ini',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              ...preview.map((t) => CourierTaskCard(task: t)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
