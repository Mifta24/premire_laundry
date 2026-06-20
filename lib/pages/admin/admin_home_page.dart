import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';
import 'account/admin_account_page.dart';
import 'courier/admin_courier_list_page.dart';
import 'dashboard/admin_dashboard_page.dart';
import 'order/admin_order_list_page.dart';
import 'report/admin_report_page.dart';

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
      provider.loadPaidPayments(),
      provider.loadServices(),
      provider.loadCouriers(),
      provider.loadDeliveryFees(),
      provider.loadActiveCourierTasks(),
    ]);
  }

  final List<String> _titles = [
    'Dashboard',
    'Daftar Pesanan',
    'Kurir',
    'Laporan & Pembayaran',
    'Akun Saya',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final pendingCount = provider.pendingPayments.length;

    final pages = [
      AdminDashboardPage(
        onNavigateTab: (i) => setState(() => _currentIndex = i),
      ),
      const AdminOrderListPage(),
      const AdminCourierListPage(),
      const AdminReportPage(),
      const AdminAccountPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => context.push('/admin/courier/add'),
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining_outlined),
            activeIcon: Icon(Icons.delivery_dining),
            label: 'Kurir',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bar_chart_outlined),
                if (pendingCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.error,
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
