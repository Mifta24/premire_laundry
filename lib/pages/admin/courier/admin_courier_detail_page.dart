import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/courier_task_model.dart';
import '../../../models/profile_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/status_badge.dart';

class AdminCourierDetailPage extends StatefulWidget {
  final String courierId;
  const AdminCourierDetailPage({super.key, required this.courierId});

  @override
  State<AdminCourierDetailPage> createState() => _AdminCourierDetailPageState();
}

class _AdminCourierDetailPageState extends State<AdminCourierDetailPage> {
  List<CourierTaskModel> _history = [];
  bool _isLoadingHistory = true;
  bool _isSavingStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AdminProvider>();
    if (provider.couriers.isEmpty) await provider.loadCouriers();
    final history = await provider.getCourierTaskHistory(widget.courierId);
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoadingHistory = false;
    });
  }

  ProfileModel? _findCourier(AdminProvider provider) {
    for (final c in provider.couriers) {
      if (c.userId == widget.courierId) return c;
    }
    return null;
  }

  Future<void> _toggleStatus(bool value) async {
    setState(() => _isSavingStatus = true);
    final ok = await context
        .read<AdminProvider>()
        .updateCourierAvailability(widget.courierId, value);
    if (!mounted) return;
    setState(() => _isSavingStatus = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gagal memperbarui status kurir'),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _showEditSheet(ProfileModel courier) {
    final nameController = TextEditingController(text: courier.name);
    final phoneController = TextEditingController(text: courier.phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final adminProvider = context.watch<AdminProvider>();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Data Kurir',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: const Icon(Icons.person_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'No. HP',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  isLoading: adminProvider.isLoading,
                  label: 'Simpan',
                  onPressed: () async {
                    final ok = await adminProvider.updateCourierProfile(
                      widget.courierId,
                      nameController.text.trim(),
                      phoneController.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data kurir berhasil diperbarui'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                              adminProvider.error ?? 'Gagal memperbarui data kurir'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final courier = _findCourier(provider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Kurir'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: courier == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person,
                                size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(courier.name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showEditSheet(courier),
                                      child: const Text(
                                        'Edit',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (courier.phone.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.phone,
                                            size: 13, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(courier.phone,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Kurir',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      activeThumbColor: AppColors.success,
                      secondary: Icon(
                        courier.isAvailable
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        color: courier.isAvailable ? AppColors.success : Colors.grey,
                      ),
                      title: const Text('Aktif Menerima Tugas',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        courier.isAvailable
                            ? 'Kurir bisa ditugaskan pesanan baru'
                            : 'Kurir tidak menerima tugas baru',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: courier.isAvailable,
                      onChanged: _isSavingStatus ? null : _toggleStatus,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Riwayat Tugas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isLoadingHistory)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Belum ada tugas',
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                    )
                  else
                    ..._history.map((task) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(
                              task.taskType == 'pickup'
                                  ? Icons.shopping_bag_outlined
                                  : Icons.local_shipping_outlined,
                              color: task.taskType == 'pickup'
                                  ? AppColors.warning
                                  : AppColors.primary,
                            ),
                            title: Text(task.orderCode ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              task.assignedAt != null
                                  ? formatTanggalIndo(task.assignedAt!)
                                  : '-',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: StatusBadge(status: task.status),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
