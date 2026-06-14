import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/status_badge.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;
  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  OrderModel? _order;
  List<Map<String, dynamic>> _statusHistory = [];
  bool _isLoading = true;

  final _weightController = TextEditingController();
  final _statusNoteController = TextEditingController();
  String? _selectedStatus;
  String? _selectedCourierId;
  String? _selectedServiceId;
  String _selectedTaskType = 'pickup';

  final List<String> _allStatuses = [
    'created',
    'waiting_pickup',
    'picked_up',
    'received_by_store',
    'waiting_weight_input',
    'waiting_payment',
    'paid',
    'washing',
    'ironing',
    'ready_to_deliver',
    'out_for_delivery',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _statusNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<AdminProvider>();
    final order = await provider.getOrderById(widget.orderId);
    final history = await provider.getOrderStatusHistory(widget.orderId);
    if (provider.couriers.isEmpty) await provider.loadCouriers();
    if (provider.services.isEmpty) await provider.loadServices();

    setState(() {
      _order = order;
      _statusHistory = history;
      _selectedStatus = order?.status;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null) return;
    final provider = context.read<AdminProvider>();
    final ok = await provider.updateOrderStatus(
        widget.orderId, _selectedStatus!, _statusNoteController.text.trim());
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Status berhasil diperbarui'),
            backgroundColor: AppColors.success),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Gagal memperbarui status'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _assignCourier() async {
    if (_selectedCourierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kurir terlebih dahulu')),
      );
      return;
    }
    final provider = context.read<AdminProvider>();
    final ok = await provider.assignCourier(
        widget.orderId, _selectedCourierId!, _selectedTaskType);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kurir berhasil ditugaskan'),
            backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Gagal menugaskan kurir'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _updateWeight() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan berat yang valid')),
      );
      return;
    }
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih layanan kiloan')),
      );
      return;
    }
    final provider = context.read<AdminProvider>();
    final ok = await provider.updateOrderWeight(
        widget.orderId, weight, _selectedServiceId!);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Berat berhasil diperbarui'),
            backgroundColor: AppColors.success),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Gagal memperbarui berat'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Pesanan tidak ditemukan')),
      );
    }

    final order = _order!;
    final provider = context.watch<AdminProvider>();
    final kiloanServices = provider.services
        .where((s) => s.serviceType == 'kiloan' && s.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderCode),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order info
            _sectionCard('Informasi Pesanan', [
              _row('Kode', order.orderCode),
              _row('Tipe',
                  order.orderType == 'kiloan' ? 'Kiloan' : order.orderType == 'satuan' ? 'Satuan' : 'Campuran'),
              _row('Tanggal',
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}'),
              if (order.notes != null && order.notes!.isNotEmpty)
                _row('Catatan', order.notes!),
              Row(
                children: [
                  const SizedBox(
                      width: 110,
                      child: Text('Status',
                          style: TextStyle(color: Colors.grey))),
                  StatusBadge(status: order.status),
                ],
              ),
            ]),

            // Items
            if (order.orderItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard('Item Pesanan',
                  order.orderItems.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.serviceName),
                      subtitle: Text(item.serviceType == 'kiloan'
                          ? '${item.weightKg ?? 0} kg'
                          : '${item.quantity} pcs'),
                      trailing: Text(formatRupiah(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList()),
            ],

            // Payment summary
            const SizedBox(height: 12),
            _sectionCard('Pembayaran', [
              _row('Subtotal', formatRupiah(order.subtotal)),
              _row('Ongkir', formatRupiah(order.deliveryFee)),
              if (order.discountAmount > 0)
                _row('Diskon', '- ${formatRupiah(order.discountAmount)}'),
              const Divider(),
              _row('Total', formatRupiah(order.totalAmount), bold: true),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(
                      width: 110,
                      child: Text('Status Bayar',
                          style: TextStyle(color: Colors.grey))),
                  StatusBadge(status: order.paymentStatus),
                ],
              ),
            ]),

            // Kiloan weight input
            if (order.orderType == 'kiloan' &&
                (order.status == 'received_by_store' ||
                    order.status == 'waiting_weight_input')) ...[
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Input Berat & Generate Invoice',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedServiceId,
                        hint: const Text('Pilih Layanan Kiloan'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: kiloanServices
                            .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                    '${s.name} - ${formatRupiah(s.price)}/${s.unit}')))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedServiceId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Berat (kg)',
                          suffixText: 'kg',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        onPressed: _updateWeight,
                        label: 'Simpan & Generate Invoice',
                        isLoading: provider.isLoading,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Assign courier
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tugaskan Kurir',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedTaskType,
                      decoration: InputDecoration(
                        labelText: 'Tipe Tugas',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'pickup', child: Text('Penjemputan')),
                        DropdownMenuItem(
                            value: 'delivery', child: Text('Pengantaran')),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedTaskType = v ?? 'pickup'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCourierId,
                      hint: const Text('Pilih Kurir'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: provider.couriers
                          .map((c) => DropdownMenuItem(
                              value: c.userId,
                              child: Text(c.name)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCourierId = v),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      onPressed: _assignCourier,
                      label: 'Tugaskan Kurir',
                      isLoading: provider.isLoading,
                    ),
                  ],
                ),
              ),
            ),

            // Update status
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Perbarui Status',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _allStatuses
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(StatusBadge.labelFor(s))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedStatus = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _statusNoteController,
                      decoration: InputDecoration(
                        labelText: 'Catatan (opsional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      onPressed: _updateStatus,
                      label: 'Perbarui Status',
                      isLoading: provider.isLoading,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ),

            // Status history
            if (_statusHistory.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                  'Riwayat Status',
                  _statusHistory.map((h) {
                    final dt = DateTime.tryParse(
                            h['created_at'] as String? ?? '') ??
                        DateTime.now();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history,
                          color: AppColors.primary, size: 20),
                      title: StatusBadge(
                          status: h['status'] as String? ?? ''),
                      subtitle: h['note'] != null &&
                              (h['note'] as String).isNotEmpty
                          ? Text(h['note'] as String,
                              style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: Text(
                        '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList()),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}
