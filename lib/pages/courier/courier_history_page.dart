import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/courier_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/courier_task_card.dart';

class CourierHistoryPage extends StatefulWidget {
  const CourierHistoryPage({super.key});

  @override
  State<CourierHistoryPage> createState() => _CourierHistoryPageState();
}

class _CourierHistoryPageState extends State<CourierHistoryPage> {
  String _filter = 'semua';
  int _days = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<CourierProvider>().loadTaskHistory(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourierProvider>();
    final inRange = provider.historyWithinDays(_days);

    final filtered = inRange.where((t) {
      if (_filter == 'jemput') return t.taskType == 'pickup';
      if (_filter == 'antar') return t.taskType == 'delivery';
      return true;
    }).toList();

    final grouped = <String, List<CourierTaskModel>>{};
    for (final t in filtered) {
      final key = formatHariTanggal(t.completedAt!);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Tugas Selesai $_days Hari Terakhir',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${inRange.length}',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Jemput ${inRange.where((t) => t.taskType == 'pickup').length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Antar ${inRange.where((t) => t.taskType == 'delivery').length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _filterPill('Semua', 'semua'),
              const SizedBox(width: 8),
              _filterPill('Jemput', 'jemput'),
              const SizedBox(width: 8),
              _filterPill('Antar', 'antar'),
              const Spacer(),
              DropdownButton<int>(
                value: _days,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 Hari')),
                  DropdownMenuItem(value: 30, child: Text('30 Hari')),
                ],
                onChanged: (v) => setState(() => _days = v ?? 7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.isHistoryLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Belum ada riwayat tugas',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            ...grouped.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...entry.value.map(
                      (t) => CourierTaskCard(task: t, showDoneBadge: true),
                    ),
                    const SizedBox(height: 8),
                  ],
                )),
        ],
      ),
    );
  }

  Widget _filterPill(String label, String key) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
