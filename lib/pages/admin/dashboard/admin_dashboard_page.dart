import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/status_badge.dart';

class AdminDashboardPage extends StatefulWidget {
  final void Function(int index) onNavigateTab;
  const AdminDashboardPage({super.key, required this.onNavigateTab});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _period = 'today';

  final _periodLabels = const {
    'today': 'Hari ini',
    'week': '7 Hari',
    'month': '30 Hari',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final orders = provider.allOrders;
    final now = DateTime.now();
    final periodDays = _period == 'today' ? 1 : (_period == 'week' ? 7 : 30);
    final cutoff = DateTime.now().subtract(Duration(days: periodDays));

    final ordersInPeriod = _period == 'today'
        ? orders.where((o) =>
            o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.createdAt.day == now.day)
        : orders.where((o) => o.createdAt.isAfter(cutoff));

    final totalOrders = ordersInPeriod.length;
    final pendingPayments = provider.pendingPayments.length;
    final totalCouriers = provider.couriers.length;
    final activeCouriers =
        provider.couriers.where((c) => c.isAvailable).length;
    final completedInPeriod =
        ordersInPeriod.where((o) => o.status == 'completed').length;

    final newOrders = orders.where((o) => o.status == 'created').length;
    final needsAssign =
        orders.where((o) => o.status == 'waiting_pickup').length;
    final inProgress = orders
        .where((o) =>
            o.status != 'completed' &&
            o.status != 'cancelled' &&
            o.status != 'created')
        .length;

    final recentOrders = [...orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      onRefresh: () => context.read<AdminProvider>().loadAllOrders(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<String>(
              value: _period,
              underline: const SizedBox.shrink(),
              items: _periodLabels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _period = v ?? 'today'),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('Total Pesanan', '$totalOrders',
                  Icons.receipt_long, AppColors.primary),
              _statCard('Menunggu Pembayaran', '$pendingPayments',
                  Icons.payment, AppColors.warning),
              _statCard('Kurir Aktif', '$activeCouriers / $totalCouriers',
                  Icons.delivery_dining, AppColors.secondary),
              _statCard('Selesai (${_periodLabels[_period]})',
                  '$completedInPeriod', Icons.check_circle, AppColors.success),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Manajemen Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _managementRow('Pesanan Baru', newOrders,
                    () => widget.onNavigateTab(1)),
                const Divider(height: 1),
                _managementRow('Perlu Assign Kurir', needsAssign,
                    () => widget.onNavigateTab(1)),
                const Divider(height: 1),
                _managementRow('Sedang Diproses', inProgress,
                    () => widget.onNavigateTab(1)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pesanan Terbaru',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => widget.onNavigateTab(1),
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          if (recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada pesanan')),
            )
          else
            ...recentOrders.take(5).map((order) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(order.orderCode,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(order.customerName ?? '-'),
                    trailing: StatusBadge(status: order.status),
                    onTap: () => context.push('/admin/order/${order.id}'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _managementRow(String label, int count, VoidCallback onTap) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}
