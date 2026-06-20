import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/status_badge.dart';

class AdminOrderListPage extends StatefulWidget {
  const AdminOrderListPage({super.key});

  @override
  State<AdminOrderListPage> createState() => _AdminOrderListPageState();
}

class _AdminOrderListPageState extends State<AdminOrderListPage> {
  String _filter = 'semua';
  bool _showSearch = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    var filtered = provider.allOrders.where((o) {
      switch (_filter) {
        case 'baru':
          return o.status == 'created';
        case 'diproses':
          return o.status != 'created' &&
              o.status != 'completed' &&
              o.status != 'cancelled';
        case 'selesai':
          return o.status == 'completed';
        default:
          return true;
      }
    }).toList();

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((o) =>
              o.orderCode.toLowerCase().contains(q) ||
              (o.customerName ?? '').toLowerCase().contains(q))
          .toList();
    }

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari kode pesanan atau nama pelanggan',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _showSearch = false;
                    _query = '';
                  }),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _filterPill('Semua', 'semua'),
              const SizedBox(width: 8),
              _filterPill('Baru', 'baru'),
              const SizedBox(width: 8),
              _filterPill('Diproses', 'diproses'),
              const SizedBox(width: 8),
              _filterPill('Selesai', 'selesai'),
              if (!_showSearch) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.grey),
                  onPressed: () => setState(() => _showSearch = true),
                ),
              ],
            ],
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
                    itemBuilder: (context, i) =>
                        _AdminOrderCard(order: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterPill(String label, String key) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  const _AdminOrderCard({required this.order});

  String _serviceLabel() {
    switch (order.orderType) {
      case 'kiloan':
        return 'Laundry Kiloan';
      case 'satuan':
        return 'Laundry Satuan';
      default:
        return 'Laundry Campuran';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => context.push('/admin/order/${order.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.orderCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  StatusBadge(status: order.status, fontSize: 10),
                ],
              ),
              const SizedBox(height: 6),
              Text(order.customerName ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.local_laundry_service_outlined,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(_serviceLabel(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              if (order.addressText != null && order.addressText!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.addressText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTanggalIndo(order.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text(
                    (order.totalAmount) > 0
                        ? formatRupiah(order.totalAmount)
                        : 'Belum dihitung',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
