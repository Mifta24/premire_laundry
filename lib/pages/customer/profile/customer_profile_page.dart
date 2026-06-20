import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/change_password_sheet.dart';
import '../../../widgets/edit_profile_sheet.dart';
import '../../../widgets/editable_avatar.dart';

class CustomerProfilePage extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const CustomerProfilePage({super.key, this.onNavigateTab});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  bool? _notificationsEnabled;
  bool _isSavingNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      final provider = context.read<CustomerProvider>();
      await Future.wait([
        provider.loadLoyalty(userId),
        if (provider.orders.isEmpty) provider.loadOrders(userId),
        _loadNotificationPref(userId),
      ]);
    }
  }

  Future<void> _loadNotificationPref(String userId) async {
    final enabled = await NotificationService().isNotificationsEnabled(userId);
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
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
    final customerProvider = context.watch<CustomerProvider>();
    final profile = authProvider.profile;
    final loyaltyPoints = customerProvider.loyaltyPoints?.totalCompletedOrders ?? 0;
    final totalOrders = customerProvider.orders.length;
    final completedOrders =
        customerProvider.orders.where((o) => o.status == 'completed').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile card
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
                              child: Text(
                                profile?.name ?? '-',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
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
                                Text(
                                  profile.phone,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
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
                          child: Text(
                            profile?.role == 'customer'
                                ? 'Customer'
                                : (profile?.role ?? '-'),
                            style: const TextStyle(
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

          // Stats row
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(child: _statColumn('$totalOrders', 'Total Order')),
                  const SizedBox(height: 36, child: VerticalDivider()),
                  Expanded(child: _statColumn('$completedOrders', 'Selesai')),
                  const SizedBox(height: 36, child: VerticalDivider()),
                  Expanded(
                    child: _statColumn('$loyaltyPoints', 'Poin Loyalty',
                        icon: Icons.star, iconColor: Colors.amber),
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
              title: const Text('Notifikasi',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Dapatkan notifikasi status pesanan & pembayaran',
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
              'Menu Akun',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _menuTile(Icons.location_on_outlined, 'Alamat Saya',
                    () => context.push('/customer/address')),
                const Divider(height: 1),
                _menuTile(Icons.card_giftcard_outlined, 'Voucher Saya',
                    () => widget.onNavigateTab?.call(2)),
                const Divider(height: 1),
                _menuTile(Icons.receipt_long_outlined, 'Riwayat Transaksi',
                    () => widget.onNavigateTab?.call(1)),
                const Divider(height: 1),
                _menuTile(Icons.lock_outline, 'Ubah Password',
                    () => showChangePasswordSheet(context)),
                const Divider(height: 1),
                _menuTile(Icons.help_outline, 'Bantuan & FAQ',
                    () => context.push('/customer/help')),
                const Divider(height: 1),
                _menuTile(Icons.info_outline, 'Tentang Premier Laundry',
                    () => context.push('/customer/about')),
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

  Widget _statColumn(String value, String label,
      {IconData? icon, Color? iconColor}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: iconColor),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback? onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
