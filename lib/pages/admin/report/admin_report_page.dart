import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/revenue_report_pdf.dart';
import '../../../providers/admin_provider.dart';

enum _ReportPeriod { day, week, month }

class AdminReportPage extends StatefulWidget {
  const AdminReportPage({super.key});

  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  _ReportPeriod _selectedPeriod = _ReportPeriod.day;
  bool _isPrinting = false;

  DateTime _periodStart(_ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case _ReportPeriod.day:
        return today;
      case _ReportPeriod.week:
        return today.subtract(const Duration(days: 6));
      case _ReportPeriod.month:
        return DateTime(now.year, now.month, 1);
    }
  }

  String _periodLabel(_ReportPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case _ReportPeriod.day:
        return 'Hari Ini (${formatTanggalSingkat(now)})';
      case _ReportPeriod.week:
        return '${formatTanggalSingkat(_periodStart(period))} - ${formatTanggalSingkat(now)}';
      case _ReportPeriod.month:
        return 'Bulan Ini (${formatBulanTahun(now)})';
    }
  }

  Future<void> _printReport() async {
    setState(() => _isPrinting = true);
    try {
      final provider = context.read<AdminProvider>();
      final payments = provider.paidPaymentsSince(_periodStart(_selectedPeriod));
      final bytes = await buildRevenueReportPdf(
        periodLabel: _periodLabel(_selectedPeriod),
        payments: payments,
        orders: provider.allOrders,
      );
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _load() async {
    final provider = context.read<AdminProvider>();
    await Future.wait([
      provider.loadPaidPayments(),
      provider.loadPendingPayments(),
      if (provider.allOrders.isEmpty) provider.loadAllOrders(),
    ]);
  }

  Future<void> _validate(String paymentId, bool isValid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isValid ? 'Validasi Pembayaran' : 'Tolak Pembayaran'),
        content: Text(
          isValid
              ? 'Konfirmasi pembayaran ini sebagai valid?'
              : 'Tolak pembayaran ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isValid ? 'Validasi' : 'Tolak',
              style: TextStyle(
                color: isValid ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final provider = context.read<AdminProvider>();
    final ok = await provider.validatePayment(paymentId, isValid);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isValid ? 'Pembayaran berhasil divalidasi' : 'Pembayaran ditolak',
          ),
          backgroundColor: isValid ? AppColors.success : AppColors.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Operasi gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final orderCompletedCount = provider.allOrders
        .where((o) => o.status == 'completed')
        .length;
    final periodPayments = provider.paidPaymentsSince(
      _periodStart(_selectedPeriod),
    );
    final periodRevenue = periodPayments.fold<double>(
      0,
      (sum, p) => sum + p.amount,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _statCard(
                'Pendapatan Hari Ini',
                formatRupiah(provider.todayRevenue),
                AppColors.primary,
              ),
              _statCard(
                'Pendapatan Bulan Ini',
                formatRupiah(provider.monthRevenue),
                AppColors.secondary,
              ),
              _statCard(
                'Order Selesai',
                '$orderCompletedCount',
                AppColors.success,
              ),
              _statCard(
                'Payment Pending',
                '${provider.pendingPayments.length}',
                AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Laporan Pendapatan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Hari Ini'),
                        selected: _selectedPeriod == _ReportPeriod.day,
                        onSelected: (_) =>
                            setState(() => _selectedPeriod = _ReportPeriod.day),
                      ),
                      ChoiceChip(
                        label: const Text('1 Minggu'),
                        selected: _selectedPeriod == _ReportPeriod.week,
                        onSelected: (_) => setState(
                          () => _selectedPeriod = _ReportPeriod.week,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('1 Bulan'),
                        selected: _selectedPeriod == _ReportPeriod.month,
                        onSelected: (_) => setState(
                          () => _selectedPeriod = _ReportPeriod.month,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _periodLabel(_selectedPeriod),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(periodRevenue),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${periodPayments.length} transaksi',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPrinting ? null : _printReport,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(
                        _isPrinting ? 'Menyiapkan PDF...' : 'Cetak PDF',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tren Pendapatan (7 Hari Terakhir)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 140,
                child: _RevenueChart(data: provider.last7DaysRevenue),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Verifikasi Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (provider.pendingPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Tidak ada pembayaran menunggu verifikasi',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...provider.pendingPayments.map((payment) {
              final order = provider.allOrders
                  .where((o) => o.id == payment.orderId)
                  .firstOrNull;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: payment.paymentProofUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: payment.paymentProofUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.receipt,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order?.customerName ?? 'Pelanggan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  order?.orderCode ??
                                      payment.orderId
                                          .substring(0, 8)
                                          .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  payment.method == 'manual_qris'
                                      ? 'QRIS Manual'
                                      : payment.method == 'xendit'
                                      ? 'Xendit'
                                      : payment.method,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(payment.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                context.push('/admin/payment/${payment.id}'),
                            child: const Text('Lihat Bukti'),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () => _validate(payment.id, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text('Tolak'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _validate(payment.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            child: const Text('Valid'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<double> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.every((v) => v == 0)) {
      return Center(
        child: Text(
          'Belum ada data pendapatan',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      );
    }
    return _InteractiveRevenueChart(data: data);
  }
}

class _InteractiveRevenueChart extends StatefulWidget {
  final List<double> data;
  const _InteractiveRevenueChart({required this.data});

  @override
  State<_InteractiveRevenueChart> createState() =>
      _InteractiveRevenueChartState();
}

class _InteractiveRevenueChartState extends State<_InteractiveRevenueChart> {
  int _selectedIndex = 6;

  DateTime _dateForIndex(int index) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: 6 - index));
  }

  void _selectPoint(Offset localPosition, double width) {
    if (widget.data.length <= 1 || width <= 0) return;
    final stepX = width / (widget.data.length - 1);
    final index = (localPosition.dx / stepX).round().clamp(
      0,
      widget.data.length - 1,
    );
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final selectedAmount = widget.data[_selectedIndex];
    final selectedDate = _dateForIndex(_selectedIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatTanggalSingkat(selectedDate)}: ${formatRupiah(selectedAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _selectPoint(details.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    _selectPoint(details.localPosition, constraints.maxWidth),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _RevenueChartPainter(
                    widget.data,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<double> data;
  final int selectedIndex;

  _RevenueChartPainter(this.data, {required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    final stepX = size.width / (data.length - 1);

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = AppColors.primary;
    final selectedDotPaint = Paint()..color = AppColors.secondary;
    final selectedRingPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final guidePaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final points = List.generate(data.length, (i) {
      final x = i * stepX;
      final y = size.height - (data[i] / safeMax) * (size.height - 16) - 8;
      return Offset(x, y);
    });

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == selectedIndex) {
        canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), guidePaint);
        canvas.drawCircle(p, 8, selectedRingPaint);
        canvas.drawCircle(p, 5, selectedDotPaint);
      } else {
        canvas.drawCircle(p, 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
}
