import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/courier_task_model.dart';

class CourierTaskCard extends StatelessWidget {
  final CourierTaskModel task;
  final bool showDoneBadge;

  const CourierTaskCard({
    super.key,
    required this.task,
    this.showDoneBadge = false,
  });

  bool get _isPickup => task.taskType == 'pickup';

  Color get _typeColor => _isPickup ? AppColors.warning : AppColors.primary;

  String get _typeLabel => _isPickup ? 'Jemput' : 'Antar';

  String _actionLabel() {
    if (task.status == 'assigned') return 'Menuju Lokasi';
    if (task.status == 'on_the_way' && _isPickup) return 'Pakaian Diambil';
    if (task.status == 'on_the_way' && !_isPickup) return 'Pakaian Diantar';
    return 'Lihat Detail';
  }

  Color _actionColor() {
    if (task.status == 'on_the_way') return AppColors.success;
    return AppColors.primary;
  }

  Future<void> _openMaps(BuildContext context) async {
    if (task.addressLatitude == null || task.addressLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat alamat tidak tersedia')),
      );
      return;
    }
    final lat = task.addressLatitude!;
    final lng = task.addressLongitude!;
    final gmUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(gmUrl)) {
      await launchUrl(gmUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => context.push('/courier/task/${task.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _typeLabel,
                      style: TextStyle(
                        color: _typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.orderCode ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (showDoneBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Selesai',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (task.assignedAt != null)
                    Text(
                      formatJamSaja(task.assignedAt!),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(task.customerName ?? '-',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.addressText ?? '-',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (!showDoneBadge) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMaps(context),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Rute'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            context.push('/courier/task/${task.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _actionColor(),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          _actionLabel(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (task.completedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${task.orderType == 'kiloan' ? 'Laundry Kiloan' : task.orderType == 'satuan' ? 'Laundry Satuan' : 'Laundry Campuran'} · Selesai ${formatTanggalIndo(task.completedAt!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
