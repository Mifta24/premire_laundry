import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/courier_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/app_button.dart';

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
    final task = await context.read<CourierProvider>().getTaskById(widget.taskId);
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

  String _normalizePhoneForWhatsApp(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (!digits.startsWith('62')) {
      digits = '62$digits';
    }
    return digits;
  }

  Future<void> _callCustomer() async {
    final phone = _task?.customerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor telepon customer tidak tersedia')),
      );
      return;
    }
    final waPhone = _normalizePhoneForWhatsApp(phone);
    final appUri = Uri.parse('whatsapp://send?phone=$waPhone');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }

    final webUri = Uri.parse('https://wa.me/$waPhone');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp tidak terpasang di perangkat ini')),
      );
    }
  }

  void _copyAddress() {
    if (_task?.addressText == null) return;
    Clipboard.setData(ClipboardData(text: _task!.addressText!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alamat disalin')),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_task == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perbarui Status'),
        content: Text('Ubah status menjadi "${_statusLabel(newStatus)}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'on_the_way':
        return 'Menuju Lokasi';
      case 'picked_up':
        return 'Pakaian Diambil';
      case 'delivered':
        return 'Pakaian Diterima Customer';
      default:
        return status;
    }
  }

  String _serviceLabel(String? type) {
    switch (type) {
      case 'kiloan':
        return 'Laundry Kiloan – Reguler';
      case 'satuan':
        return 'Laundry Satuan';
      default:
        return 'Laundry Campuran';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tugas'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tugas'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
        body: const Center(child: Text('Tugas tidak ditemukan')),
      );
    }

    final task = _task!;
    final isPickup = task.taskType == 'pickup';
    final typeColor = isPickup ? AppColors.warning : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
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
            // Header
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(task.orderCode ?? '-',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isPickup ? 'Jemput' : 'Antar',
                            style: TextStyle(
                                color: typeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (task.assignedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dijadwalkan: ${formatTanggalIndo(task.assignedAt!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () =>
                          context.push('/courier/task/${task.id}/status'),
                      child: const Row(
                        children: [
                          Text('Lihat Status Perjalanan',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Informasi Customer
            _sectionCard(
              title: 'Informasi Customer',
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(task.customerName ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  if (task.customerPhone != null && task.customerPhone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.chat, color: AppColors.success),
                      onPressed: _callCustomer,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Alamat
            _sectionCard(
              title: isPickup ? 'Alamat Jemput' : 'Alamat Antar',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(task.addressText ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      TextButton.icon(
                        onPressed: _copyAddress,
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Salin', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (task.addressNotes != null && task.addressNotes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Patokan: ${task.addressNotes}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Detail Layanan
            _sectionCard(
              title: 'Detail Layanan',
              child: Row(
                children: [
                  Expanded(
                    child: Text(_serviceLabel(task.orderType),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    (task.totalAmount ?? 0) > 0
                        ? formatRupiah(task.totalAmount!)
                        : 'Belum dihitung',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            if (task.customerNotes != null && task.customerNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Catatan Pakaian',
                child: Text(task.customerNotes!,
                    style: const TextStyle(fontSize: 13)),
              ),
            ],

            const SizedBox(height: 12),

            if (task.assignedAt != null)
              _sectionCard(
                title: isPickup ? 'Waktu Jemput' : 'Waktu Antar',
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(formatTanggalSingkat(task.assignedAt!)),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(formatJamSaja(task.assignedAt!)),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Lokasi di Maps
            if (task.addressLatitude != null && task.addressLongitude != null)
              _sectionCard(
                title: 'Lokasi di Maps',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 140,
                    child: IgnorePointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter:
                              LatLng(task.addressLatitude!, task.addressLongitude!),
                          initialZoom: 15,
                          interactionOptions:
                              const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.premier.laundry',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                    task.addressLatitude!, task.addressLongitude!),
                                width: 36,
                                height: 36,
                                child: const Icon(Icons.location_pin,
                                    color: AppColors.error, size: 36),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Hubungi Customer / Buka Maps
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _callCustomer,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Hubungi Customer'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Buka Maps'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (task.status == 'assigned')
              AppButton(
                onPressed: () => _updateStatus('on_the_way'),
                label: 'Mulai Menuju Lokasi',
                color: AppColors.primary,
              ),
            if (task.status == 'on_the_way' && isPickup)
              AppButton(
                onPressed: () => _updateStatus('picked_up'),
                label: 'Pakaian Diambil',
                color: AppColors.success,
              ),
            if (task.status == 'on_the_way' && !isPickup)
              AppButton(
                onPressed: () => _updateStatus('delivered'),
                label: 'Pakaian Diterima Customer',
                color: AppColors.success,
              ),
            if (task.status == 'picked_up' || task.status == 'delivered')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tugas ini telah selesai',
                        style: TextStyle(
                            color: AppColors.success, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
