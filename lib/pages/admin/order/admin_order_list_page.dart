import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/order_card.dart';

class AdminOrderListPage extends StatefulWidget {
  const AdminOrderListPage({super.key});

  @override
  State<AdminOrderListPage> createState() => _AdminOrderListPageState();
}

class _AdminOrderListPageState extends State<AdminOrderListPage> {
  String _selectedStatus = 'all';

  final List<Map<String, String>> _statusFilters = [
    {'key': 'all', 'label': 'Semua'},
    {'key': 'created', 'label': 'Dibuat'},
    {'key': 'waiting_pickup', 'label': 'Menunggu Jemput'},
    {'key': 'picked_up', 'label': 'Diambil'},
    {'key': 'received_by_store', 'label': 'Di Toko'},
    {'key': 'waiting_weight_input', 'label': 'Input Berat'},
    {'key': 'waiting_payment', 'label': 'Menunggu Bayar'},
    {'key': 'paid', 'label': 'Dibayar'},
    {'key': 'washing', 'label': 'Dicuci'},
    {'key': 'ironing', 'label': 'Disetrika'},
    {'key': 'ready_to_deliver', 'label': 'Siap Antar'},
    {'key': 'out_for_delivery', 'label': 'Diantar'},
    {'key': 'completed', 'label': 'Selesai'},
    {'key': 'cancelled', 'label': 'Dibatalkan'},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final filtered = _selectedStatus == 'all'
        ? provider.allOrders
        : provider.allOrders
            .where((o) => o.status == _selectedStatus)
            .toList();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Status filter chips
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _statusFilters.length,
            itemBuilder: (context, i) {
              final filter = _statusFilters[i];
              final isSelected = _selectedStatus == filter['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter['label']!),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedStatus = filter['key']!),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey[700],
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey[300]!,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Tidak ada pesanan',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadAllOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final order = filtered[i];
                      return OrderCard(
                        order: order,
                        onTap: () =>
                            context.push('/admin/order/${order.id}'),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
