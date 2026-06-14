import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/courier_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  CourierTaskModel? _task;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    setState(() => _isLoading = true);
    final task =
        await context.read<CourierProvider>().getTaskById(widget.taskId);
    setState(() {
      _task = task;
      _isLoading = false;
    });
  }

  Future<void> _openMaps() async {
    if (_task?.addressLatitude == null || _task?.addressLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat alamat tidak tersedia')),
      );
      return;
    }
    final lat = _task!.addressLatitude!;
    final lng = _task!.addressLongitude!;

    // Try Google Maps first, fallback to OpenStreetMap
    final gmUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(gmUrl)) {
      await launchUrl(gmUrl, mode: LaunchMode.externalApplication);
    } else {
      final osmUrl =
          Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng');
      if (await canLaunchUrl(osmUrl)) {
        await launchUrl(osmUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_task == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perbarui Status'),
        content: Text(
            'Ubah status menjadi "${StatusBadge.labelFor(newStatus)}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<CourierProvider>();
    final ok = await provider.updateTaskStatus(
      widget.taskId,
      newStatus,
      _task!.taskType,
      _task!.orderId,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Status berhasil diperbarui'),
            backgroundColor: AppColors.success),
      );
      await _loadTask();
      if (!mounted) return;

      // Reload courier tasks
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        await provider.loadTasks(userId);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Gagal memperbarui status'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tugas'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tugas'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Tugas tidak ditemukan')),
      );
    }

    final task = _task!;
    final provider = context.watch<CourierProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTask),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task info card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.orderCode ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        StatusBadge(status: task.status),
                      ],
                    ),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.local_shipping,
                      'Tipe Tugas',
                      task.taskType == 'pickup'
                          ? 'Penjemputan'
                          : 'Pengantaran',
                    ),
                    _infoRow(
                        Icons.person, 'Pelanggan', task.customerName ?? '-'),
                    _infoRow(Icons.location_on, 'Alamat',
                        task.addressText ?? '-'),
                    if (task.customerNotes != null &&
                        task.customerNotes!.isNotEmpty)
                      _infoRow(
                          Icons.notes, 'Catatan', task.customerNotes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Open maps button
            AppButton(
              onPressed: _openMaps,
              label: 'Buka Maps / Navigasi',
              color: AppColors.secondary,
            ),

            const SizedBox(height: 24),
            const Text('Perbarui Status',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Status action buttons
            if (task.status == 'assigned')
              AppButton(
                onPressed: () => _updateStatus('on_the_way'),
                label: 'Mulai Menuju Lokasi',
                isLoading: provider.isLoading,
              ),

            if (task.status == 'on_the_way' && task.taskType == 'pickup')
              AppButton(
                onPressed: () => _updateStatus('picked_up'),
                label: 'Pakaian Sudah Diambil',
                isLoading: provider.isLoading,
                color: AppColors.success,
              ),

            if (task.status == 'on_the_way' && task.taskType == 'delivery')
              AppButton(
                onPressed: () => _updateStatus('delivered'),
                label: 'Pakaian Sudah Diterima Pelanggan',
                isLoading: provider.isLoading,
                color: AppColors.success,
              ),

            if (task.status == 'picked_up' || task.status == 'delivered')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tugas ini telah selesai',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
