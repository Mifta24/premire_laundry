import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'status_badge.dart';

class OrderTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const OrderTimeline({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(history.length, (i) {
        final h = history[i];
        final isFirst = i == 0;
        final isLast = i == history.length - 1;
        final dt = DateTime.tryParse(h['created_at'] as String? ?? '');
        final color = StatusBadge.colorFor(h['status'] as String? ?? '');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? color : color.withValues(alpha: 0.3),
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 48,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          StatusBadge.labelFor(h['status'] as String? ?? ''),
                          style: TextStyle(
                            fontWeight:
                                isFirst ? FontWeight.bold : FontWeight.w600,
                            color: isFirst ? AppColors.primary : Colors.black87,
                          ),
                        ),
                        if (dt != null)
                          Text(
                            '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    if ((h['note'] as String?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        h['note'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
