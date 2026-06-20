import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../core/constants/app_colors.dart';
import 'status_badge.dart';

const _milestoneIcons = [
  Icons.check,
  Icons.shopping_bag_outlined,
  Icons.local_laundry_service_outlined,
  Icons.checkroom_outlined,
  Icons.location_on_outlined,
];

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  String _displayStatus(OrderModel order) {
    if (order.status == 'waiting_payment' &&
        order.paymentStatus == 'waiting_verification') {
      return 'waiting_verification';
    }
    return order.status;
  }

  String _serviceLabel(String type) {
    switch (type) {
      case 'kiloan':
        return 'Laundry Kiloan';
      case 'satuan':
        return 'Laundry Satuan';
      default:
        return 'Laundry Campuran';
    }
  }

  int _milestoneIndex(String status) {
    switch (status) {
      case 'created':
      case 'waiting_pickup':
        return 0;
      case 'picked_up':
      case 'received_by_store':
      case 'waiting_weight_input':
      case 'waiting_payment':
      case 'paid':
        return 1;
      case 'washing':
      case 'ironing':
        return 2;
      case 'ready_to_deliver':
      case 'out_for_delivery':
        return 3;
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  String _caption(OrderModel order) {
    switch (order.status) {
      case 'created':
        return 'Menunggu konfirmasi pesanan';
      case 'waiting_pickup':
        return 'Menunggu penjemputan oleh kurir';
      case 'picked_up':
        return 'Pakaian sudah diambil kurir';
      case 'received_by_store':
        return 'Pakaian diterima toko';
      case 'waiting_weight_input':
        return 'Menunggu penimbangan';
      case 'waiting_payment':
        return 'Menunggu pembayaran';
      case 'paid':
        return 'Pembayaran diterima';
      case 'washing':
        return 'Pakaian sedang dicuci';
      case 'ironing':
        return 'Pakaian sedang disetrika';
      case 'ready_to_deliver':
        return 'Pakaian siap diantar';
      case 'out_for_delivery':
        return 'Pakaian sedang diantar';
      case 'completed':
        return 'Selesai pada ${formatTanggalSingkat(order.createdAt)}';
      case 'cancelled':
        return 'Pesanan dibatalkan';
      default:
        return '';
    }
  }

  Color _avatarColor(int milestone, bool cancelled) {
    if (cancelled) return AppColors.error;
    if (milestone == 4) return AppColors.success;
    return AppColors.primary;
  }

  IconData _avatarIcon(int milestone, bool cancelled) {
    if (cancelled) return Icons.cancel_outlined;
    if (milestone == 4) return Icons.check_circle;
    return _milestoneIcons[milestone];
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled';
    final milestone = _milestoneIndex(order.status);
    final color = _avatarColor(milestone, cancelled);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: _displayStatus(order), fontSize: 10),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_avatarIcon(milestone, cancelled), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _serviceLabel(order.orderType),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          formatTanggalIndo(order.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatRupiah(order.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (order.addressText != null &&
                  order.addressText!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  order.addressText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (!cancelled) ...[
                const SizedBox(height: 12),
                _stepper(milestone),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _caption(order),
                      style: TextStyle(
                        fontSize: 12,
                        color: cancelled ? AppColors.error : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper(int milestone) {
    return Row(
      children: List.generate(_milestoneIcons.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineDone = (i ~/ 2) < milestone;
          return Expanded(
            child: Container(
              height: 2,
              color: lineDone ? AppColors.primary : Colors.grey[300],
            ),
          );
        }
        final step = i ~/ 2;
        final done = step <= milestone;
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.primary : Colors.grey[200],
          ),
          child: Icon(
            _milestoneIcons[step],
            size: 12,
            color: done ? Colors.white : Colors.grey[500],
          ),
        );
      }),
    );
  }
}
