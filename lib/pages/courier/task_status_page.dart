import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/courier_provider.dart';

class _Milestone {
  final String label;
  final String doneDesc;
  final String pendingDesc;
  final String? statusKey;
  final IconData icon;

  const _Milestone({
    required this.label,
    required this.doneDesc,
    required this.pendingDesc,
    required this.icon,
    this.statusKey,
  });
}

const _statusOrder = [
  'created',
  'waiting_pickup',
  'picked_up',
  'received_by_store',
  'waiting_weight_input',
  'waiting_payment',
  'paid',
  'washing',
  'ironing',
  'ready_to_deliver',
  'out_for_delivery',
  'completed',
];

const _milestones = [
  _Milestone(
    label: 'Ditugaskan',
    doneDesc: 'Tugas telah diberikan oleh sistem.',
    pendingDesc: 'Menunggu penugasan.',
    icon: Icons.check,
  ),
  _Milestone(
    label: 'Menuju Lokasi',
    doneDesc: 'Anda sedang menuju lokasi jemput.',
    pendingDesc: 'Akan aktif saat menuju lokasi jemput.',
    icon: Icons.directions_run,
    statusKey: 'waiting_pickup',
  ),
  _Milestone(
    label: 'Pakaian Diambil',
    doneDesc: 'Pakaian telah diambil dari customer.',
    pendingDesc: 'Konfirmasi saat pakaian telah diambil.',
    icon: Icons.shopping_bag_outlined,
    statusKey: 'picked_up',
  ),
  _Milestone(
    label: 'Diterima Toko',
    doneDesc: 'Pakaian telah diterima toko.',
    pendingDesc: 'Menunggu proses di toko.',
    icon: Icons.storefront_outlined,
    statusKey: 'received_by_store',
  ),
  _Milestone(
    label: 'Siap Diantar',
    doneDesc: 'Pakaian sudah siap untuk diantar.',
    pendingDesc: 'Menunggu proses selesai di toko.',
    icon: Icons.inventory_2_outlined,
    statusKey: 'ready_to_deliver',
  ),
  _Milestone(
    label: 'Menuju Lokasi Antar',
    doneDesc: 'Anda sedang menuju lokasi antar.',
    pendingDesc: 'Akan aktif saat pesanan siap diantar.',
    icon: Icons.directions_run,
    statusKey: 'out_for_delivery',
  ),
  _Milestone(
    label: 'Pakaian Diterima Customer',
    doneDesc: 'Pakaian telah diterima customer.',
    pendingDesc: 'Akan aktif saat telah diterima customer.',
    icon: Icons.flag_outlined,
    statusKey: 'completed',
  ),
];

class TaskStatusPage extends StatefulWidget {
  final String taskId;
  const TaskStatusPage({super.key, required this.taskId});

  @override
  State<TaskStatusPage> createState() => _TaskStatusPageState();
}

class _TaskStatusPageState extends State<TaskStatusPage> {
  bool _isLoading = true;
  String? _orderCode;
  String? _taskType;
  String _orderStatus = 'created';
  DateTime? _assignedAt;
  Map<String, DateTime> _historyTimestamps = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final task =
          await context.read<CourierProvider>().getTaskById(widget.taskId);
      if (task == null) {
        setState(() => _isLoading = false);
        return;
      }

      final order = await Supabase.instance.client
          .from('orders')
          .select('status')
          .eq('id', task.orderId)
          .single();

      final history = await Supabase.instance.client
          .from('order_status_histories')
          .select()
          .eq('order_id', task.orderId)
          .order('created_at', ascending: true);

      final timestamps = <String, DateTime>{};
      for (final h in history as List<dynamic>) {
        final status = h['status'] as String?;
        final createdAt = h['created_at'] as String?;
        if (status != null && createdAt != null && !timestamps.containsKey(status)) {
          timestamps[status] = DateTime.parse(createdAt);
        }
      }

      setState(() {
        _orderCode = task.orderCode;
        _taskType = task.taskType;
        _orderStatus = order['status'] as String? ?? 'created';
        _assignedAt = task.assignedAt;
        _historyTimestamps = timestamps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPickup = _taskType == 'pickup';
    final typeColor = isPickup ? AppColors.warning : AppColors.primary;
    final cancelled = _orderStatus == 'cancelled';
    final currentIndex = _statusOrder.indexOf(_orderStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Status Perjalanan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPickup ? 'JEMPUT' : 'ANTAR',
                          style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(_orderCode ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (cancelled)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: AppColors.error),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Pesanan ini telah dibatalkan.',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: List.generate(_milestones.length, (i) {
                        final m = _milestones[i];
                        final isLast = i == _milestones.length - 1;
                        final requiredIndex =
                            m.statusKey == null ? -1 : _statusOrder.indexOf(m.statusKey!);
                        final done = currentIndex >= requiredIndex;
                        final timestamp = i == 0
                            ? _assignedAt
                            : (m.statusKey != null
                                ? _historyTimestamps[m.statusKey]
                                : null);

                        return Column(
                          children: [
                            if (i == 4)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'ANTAR',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: done
                                            ? AppColors.primary
                                            : Colors.grey[200],
                                      ),
                                      child: Icon(
                                        done ? Icons.check : m.icon,
                                        size: 16,
                                        color: done ? Colors.white : Colors.grey[500],
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 44,
                                        color: done && currentIndex > requiredIndex
                                            ? AppColors.primary
                                            : Colors.grey[300],
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: done ? Colors.black87 : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          done ? m.doneDesc : m.pendingDesc,
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        if (timestamp != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            formatTanggalIndo(timestamp),
                                            style: TextStyle(
                                                fontSize: 11, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ),
    );
  }
}
