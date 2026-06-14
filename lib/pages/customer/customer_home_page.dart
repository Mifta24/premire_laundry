import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/order_card.dart';
import 'order/order_history_page.dart';
import 'voucher/voucher_list_page.dart';
import 'profile/customer_profile_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    context.read<CustomerProvider>().unsubscribeFromRealtime();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      final provider = context.read<CustomerProvider>();
      provider.subscribeToRealtime(userId);
      await provider.loadOrders(userId);
    }
  }

  final List<String> _titles = ['Beranda', 'Pesanan', 'Voucher', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;

    final pages = [
      _buildHomeDashboard(context, profile?.name ?? 'Pelanggan'),
      const OrderHistoryPage(),
      const VoucherListPage(),
      const CustomerProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.location_on_outlined),
              onPressed: () => context.push('/customer/address'),
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
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Pesanan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard_outlined),
              activeIcon: Icon(Icons.card_giftcard),
              label: 'Voucher'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard(BuildContext context, String name) {
    final provider = context.watch<CustomerProvider>();
    final activeOrder = provider.orders
        .where((o) =>
            o.status != 'completed' &&
            o.status != 'cancelled')
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header greeting
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, $name!',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Apa yang bisa kami bantu hari ini?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _quickActionCard(
                      icon: Icons.scale,
                      label: 'Order Kiloan',
                      color: AppColors.primary,
                      onTap: () => context.push(
                          '/customer/order/create?type=kiloan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _quickActionCard(
                      icon: Icons.checkroom,
                      label: 'Order Satuan',
                      color: AppColors.secondary,
                      onTap: () => context.push(
                          '/customer/order/create?type=satuan'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Active orders
            if (activeOrder.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pesanan Aktif',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 1),
                      child: const Text('Lihat Semua'),
                    ),
                  ],
                ),
              ),
              ...activeOrder.take(3).map((order) => OrderCard(
                    order: order,
                    onTap: () =>
                        context.push('/customer/order/${order.id}'),
                  )),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.local_laundry_service,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Belum ada pesanan aktif',
                              style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          const Text('Buat pesanan pertama Anda sekarang!',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
