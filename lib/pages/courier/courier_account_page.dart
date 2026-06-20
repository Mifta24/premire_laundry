import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/edit_profile_sheet.dart';
import '../../widgets/editable_avatar.dart';

class CourierAccountPage extends StatefulWidget {
  final void Function(int index) onNavigateTab;

  const CourierAccountPage({super.key, required this.onNavigateTab});

  @override
  State<CourierAccountPage> createState() => _CourierAccountPageState();
}

class _CourierAccountPageState extends State<CourierAccountPage> {
  bool? _notificationsEnabled;
  bool _isSavingAvailability = false;
  bool _isSavingNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotificationPref());
  }

  Future<void> _loadNotificationPref() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final enabled = await NotificationService().isNotificationsEnabled(userId);
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isSavingAvailability = true);
    final ok = await context.read<AuthProvider>().updateAvailability(value);
    if (!mounted) return;
    setState(() => _isSavingAvailability = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gagal memperbarui status ketersediaan'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    setState(() {
      _isSavingNotifications = true;
      _notificationsEnabled = value;
    });
    await NotificationService().setNotificationsEnabled(userId, value);
    if (!mounted) return;
    setState(() => _isSavingNotifications = false);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;
    final courierProvider = context.watch<CourierProvider>();
    final isAvailable = profile?.isAvailable ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EditableAvatar(avatarUrl: profile?.avatarUrl, radius: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(profile?.name ?? '-',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            GestureDetector(
                              onTap: () => showEditProfileSheet(context),
                              child: const Text(
                                'Edit Profil',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authProvider.currentUser?.email ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (profile != null && profile.phone.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.phone, size: 13, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(profile.phone,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
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

          // Status ketersediaan
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              activeThumbColor: AppColors.success,
              secondary: Icon(
                isAvailable ? Icons.check_circle_outline : Icons.pause_circle_outline,
                color: isAvailable ? AppColors.success : Colors.grey,
              ),
              title: const Text('Aktif Menerima Tugas',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                isAvailable
                    ? 'Admin dapat menugaskan pesanan baru kepada Anda'
                    : 'Anda tidak akan menerima tugas baru',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: isAvailable,
              onChanged: _isSavingAvailability ? null : _toggleAvailability,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _statColumn(
                        '${courierProvider.completedThisWeekCount}',
                        'Selesai Minggu Ini'),
                  ),
                  const SizedBox(height: 36, child: VerticalDivider()),
                  Expanded(
                    child: _statColumn(
                        '${courierProvider.completedTodayCount}', 'Selesai Hari Ini'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pengaturan',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.notifications_outlined,
                  color: AppColors.primary),
              title: const Text('Notifikasi Tugas Baru',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Dapatkan notifikasi saat ada tugas jemput/antar baru',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: _notificationsEnabled ?? true,
              onChanged: _isSavingNotifications || _notificationsEnabled == null
                  ? null
                  : _toggleNotifications,
            ),
          ),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Menu',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _menuTile(Icons.history, 'Riwayat Tugas',
                    () => widget.onNavigateTab(2)),
                const Divider(height: 1),
                _menuTile(Icons.lock_outline, 'Ubah Password',
                    () => showChangePasswordSheet(context)),
                const Divider(height: 1),
                _menuTile(Icons.logout, 'Keluar', _signOut, color: AppColors.error),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
