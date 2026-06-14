import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import 'order/admin_order_list_page.dart';
import 'payment/admin_payment_list_page.dart';
import 'settings/admin_settings_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    context.read<AdminProvider>().unsubscribeFromRealtime();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final provider = context.read<AdminProvider>();
    provider.subscribeToRealtime();
    await Future.wait([
      provider.loadAllOrders(),
      provider.loadPendingPayments(),
      provider.loadServices(),
      provider.loadCouriers(),
      provider.loadDeliveryFees(),
    ]);
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    context.go('/login');
  }

  final List<String> _titles = [
    'Pesanan',
    'Pembayaran',
    'Layanan',
    'Ongkir',
    'Pengaturan',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final pendingCount = provider.pendingPayments.length;

    final pages = [
      const AdminOrderListPage(),
      const AdminPaymentListPage(),
      const _AdminServicesTab(),
      const _AdminDeliveryFeesTab(),
      const AdminSettingsPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.payment_outlined),
                if (pendingCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.error,
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.payment),
            label: 'Pembayaran',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_laundry_service_outlined),
            activeIcon: Icon(Icons.local_laundry_service),
            label: 'Layanan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining_outlined),
            activeIcon: Icon(Icons.delivery_dining),
            label: 'Ongkir',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

// These tabs push to the standalone pages (which have their own Scaffold/AppBar)
// rather than embedding them directly, avoiding nested-Scaffold issues.
class _AdminServicesTab extends StatelessWidget {
  const _AdminServicesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_laundry_service,
              size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Kelola Layanan Laundry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/admin/services'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka Halaman Layanan'),
          ),
        ],
      ),
    );
  }
}

class _AdminDeliveryFeesTab extends StatelessWidget {
  const _AdminDeliveryFeesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delivery_dining,
              size: 64, color: AppColors.secondary),
          const SizedBox(height: 16),
          const Text('Kelola Ongkos Kirim',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/admin/delivery-fees'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka Halaman Ongkir'),
          ),
        ],
      ),
    );
  }
}
