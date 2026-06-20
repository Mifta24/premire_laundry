import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/admin_provider.dart';

class AdminCourierListPage extends StatefulWidget {
  const AdminCourierListPage({super.key});

  @override
  State<AdminCourierListPage> createState() => _AdminCourierListPageState();
}

class _AdminCourierListPageState extends State<AdminCourierListPage> {
  bool _showSearch = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    var couriers = provider.couriers;

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      couriers = couriers
          .where((c) =>
              c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q))
          .toList();
    }

    if (provider.isLoading && provider.couriers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              if (_showSearch)
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau no. HP kurir',
                      prefixIcon: const Icon(Icons.search),
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                )
              else
                const Spacer(),
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search,
                    color: Colors.grey),
                onPressed: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _query = '';
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.couriers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delivery_dining_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Belum ada kurir terdaftar',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : couriers.isEmpty
                  ? Center(
                      child: Text('Tidak ditemukan',
                          style: TextStyle(color: Colors.grey[600])),
                    )
                  : RefreshIndicator(
                      onRefresh: () => Future.wait([
                        provider.loadCouriers(),
                        provider.loadActiveCourierTasks(),
                      ]),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: couriers.length,
                        itemBuilder: (context, i) {
                          final courier = couriers[i];
                          final activeTasks =
                              provider.activeTaskCountFor(courier.userId);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  context.push('/admin/courier/${courier.userId}'),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          AppColors.primary.withValues(alpha: 0.1),
                                      backgroundImage: courier.avatarUrl != null
                                          ? CachedNetworkImageProvider(
                                              courier.avatarUrl!)
                                          : null,
                                      child: courier.avatarUrl == null
                                          ? const Icon(Icons.person,
                                              color: AppColors.primary)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(courier.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          if (courier.phone.isNotEmpty)
                                            Text(courier.phone,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600])),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$activeTasks tugas aktif',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (courier.isAvailable
                                                ? AppColors.success
                                                : Colors.grey)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        courier.isAvailable ? 'Aktif' : 'Tidak Aktif',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: courier.isAvailable
                                              ? AppColors.success
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
