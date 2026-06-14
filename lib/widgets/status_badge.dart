import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  static String labelFor(String status) {
    const labels = {
      'created': 'Dibuat',
      'waiting_pickup': 'Menunggu Jemput',
      'picked_up': 'Pakaian Diambil',
      'received_by_store': 'Diterima Toko',
      'waiting_weight_input': 'Menunggu Input Berat',
      'waiting_payment': 'Menunggu Pembayaran',
      'paid': 'Pembayaran Valid',
      'washing': 'Sedang Dicuci',
      'ironing': 'Sedang Disetrika',
      'ready_to_deliver': 'Siap Diantar',
      'out_for_delivery': 'Sedang Diantar',
      'completed': 'Selesai',
      'cancelled': 'Dibatalkan',
      // Payment statuses
      'pending': 'Menunggu',
      'waiting_verification': 'Menunggu Verifikasi',
      'rejected': 'Ditolak',
      'failed': 'Gagal',
      'expired': 'Kadaluarsa',
      // Task statuses
      'assigned': 'Ditugaskan',
      'on_the_way': 'Dalam Perjalanan',
      'delivered': 'Terkirim',
    };
    return labels[status] ?? status;
  }

  static Color colorFor(String status) {
    switch (status) {
      case 'created':
        return AppColors.statusCreated;
      case 'waiting_pickup':
        return AppColors.statusWaitingPickup;
      case 'picked_up':
        return AppColors.statusPickedUp;
      case 'received_by_store':
        return AppColors.statusReceivedByStore;
      case 'waiting_weight_input':
        return AppColors.statusWaitingWeightInput;
      case 'waiting_payment':
        return AppColors.statusWaitingPayment;
      case 'paid':
        return AppColors.statusPaid;
      case 'washing':
        return AppColors.statusWashing;
      case 'ironing':
        return AppColors.statusIroning;
      case 'ready_to_deliver':
        return AppColors.statusReadyToDeliver;
      case 'out_for_delivery':
        return AppColors.statusOutForDelivery;
      case 'completed':
        return AppColors.statusCompleted;
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'pending':
        return Colors.grey;
      case 'waiting_verification':
        return Colors.orange;
      case 'rejected':
        return AppColors.error;
      case 'failed':
        return AppColors.error;
      case 'expired':
        return Colors.grey;
      case 'assigned':
        return Colors.blue;
      case 'on_the_way':
        return Colors.orange;
      case 'delivered':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final label = labelFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
