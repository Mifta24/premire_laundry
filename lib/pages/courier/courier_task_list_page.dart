import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/courier_task_model.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/courier_task_card.dart';

class CourierTaskListPage extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const CourierTaskListPage({super.key, required this.onRefresh});

  @override
  State<CourierTaskListPage> createState() => _CourierTaskListPageState();
}

class _CourierTaskListPageState extends State<CourierTaskListPage> {
  String _filter = 'semua';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourierProvider>();

    List<CourierTaskModel> tasks;
    switch (_filter) {
      case 'jemput':
        tasks = provider.pickupTasks;
        break;
      case 'antar':
        tasks = provider.deliveryTasks;
        break;
      default:
        tasks = [...provider.pickupTasks, ...provider.deliveryTasks];
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _filterPill('Semua', 'semua'),
              const SizedBox(width: 8),
              _filterPill('Jemput', 'jemput'),
              const SizedBox(width: 8),
              _filterPill('Antar', 'antar'),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Tidak ada tugas saat ini',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: widget.onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (context, i) =>
                            CourierTaskCard(task: tasks[i]),
                      ),
                    ),
        ),
      ],
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
