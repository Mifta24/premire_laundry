import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../providers/notification_provider.dart';
import 'courier_account_page.dart';
import 'courier_dashboard_page.dart';
import 'courier_history_page.dart';
import 'courier_task_list_page.dart';

class CourierHomePage extends StatefulWidget {
  const CourierHomePage({super.key});

  @override
  State<CourierHomePage> createState() => _CourierHomePageState();
}

class _CourierHomePageState extends State<CourierHomePage> {
  int _currentIndex = 0;

  final List<String> _titles = ['Beranda', 'Tugas Saya', 'Riwayat Tugas', 'Akun Saya'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
  }

  @override
  void dispose() {
    context.read<CourierProvider>().unsubscribeFromRealtime();
    context.read<NotificationProvider>().unsubscribeFromRealtime();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      final provider = context.read<CourierProvider>();
      provider.subscribeToRealtime(userId);
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.subscribeToRealtime(userId);
      await Future.wait([
        provider.loadTasks(userId),
        notifProvider.loadNotifications(userId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    final pages = [
      CourierDashboardPage(
        onNavigateTab: (i) => setState(() => _currentIndex = i),
        onRefresh: _loadTasks,
      ),
      CourierTaskListPage(onRefresh: _loadTasks),
      const CourierHistoryPage(),
      CourierAccountPage(
        onNavigateTab: (i) => setState(() => _currentIndex = i),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.error,
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
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
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
