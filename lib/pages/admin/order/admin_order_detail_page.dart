import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/courier_task_model.dart';
import '../../../models/laundry_service_model.dart';
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
  List<CourierTaskModel> _courierTasks = [];
  bool _isLoading = true;

  final _weightController = TextEditingController();
  String? _selectedCourierId;
  String? _selectedServiceId;
  String _selectedTaskType = 'pickup';

  List<String> _nextStatusesFor(OrderModel order) {
    switch (order.status) {
      case 'created':
        return [
          order.orderType == 'satuan' ? 'waiting_payment' : 'waiting_pickup',
          'cancelled',
        ];
      case 'waiting_pickup':
        return ['cancelled'];
      case 'picked_up':
        return ['received_by_store', 'cancelled'];
      case 'received_by_store':
        if (order.orderType == 'kiloan') return ['waiting_weight_input'];
        return ['washing', 'cancelled'];
      case 'waiting_weight_input':
        return ['waiting_payment', 'cancelled'];
      case 'waiting_payment':
        if (order.paymentStatus == 'paid') return ['paid'];
        return ['cancelled'];
      case 'paid':
        if (order.orderType == 'satuan') return ['cancelled'];
        return ['washing', 'cancelled'];
      case 'washing':
        return ['ironing', 'cancelled'];
      case 'ironing':
        return ['ready_to_deliver', 'cancelled'];
      case 'ready_to_deliver':
        return ['cancelled'];
      case 'out_for_delivery':
        return const [];
      default:
        return const [];
    }
  }

  bool _hasActiveTask(String taskType) {
    return _courierTasks.any(
      (task) =>
          task.taskType == taskType &&
          task.status != 'completed' &&
          task.status != 'cancelled',
    );
  }

  List<String> _availableTaskTypesFor(OrderModel order) {
    final types = <String>[];
    if (((order.status == 'created' && order.orderType != 'satuan') ||
            (order.status == 'paid' && order.orderType == 'satuan') ||
            order.status == 'waiting_pickup') &&
        !_hasActiveTask('pickup')) {
      types.add('pickup');
    }
    if (order.status == 'ready_to_deliver' && !_hasActiveTask('delivery')) {
      types.add('delivery');
    }
    return types;
  }

  String _courierAssignmentMessage(OrderModel order) {
    if (_hasActiveTask('pickup') || _hasActiveTask('delivery')) {
      return 'Tugas kurir untuk tahap ini sudah dibuat';
    }
    if (order.orderType == 'satuan' && order.status == 'created') {
      return 'Pesanan satuan harus dibayar sebelum dijemput';
    }
    return 'Tidak ada tugas kurir yang perlu dibuat pada tahap ini';
  }

  String _servicePickerKey(LaundryServiceModel service) {
    return [
      service.serviceType.trim().toLowerCase(),
      service.name.trim().toLowerCase(),
      service.unit.trim().toLowerCase(),
      service.price.toStringAsFixed(2),
    ].join('|');
  }

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item,
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<AdminProvider>();
    final order = await provider.getOrderById(widget.orderId);
    final history = await provider.getOrderStatusHistory(widget.orderId);
    final courierTasks = await provider.getCourierTasksByOrder(widget.orderId);
    if (provider.couriers.isEmpty) await provider.loadCouriers();
    if (provider.services.isEmpty) await provider.loadServices();

    final availableTaskTypes = order != null
        ? _availableTaskTypesForOrder(order, courierTasks)
        : const <String>[];

    setState(() {
      _order = order;
      _statusHistory = history;
      _courierTasks = courierTasks;
      _selectedTaskType = availableTaskTypes.isNotEmpty
          ? availableTaskTypes.first
          : _selectedTaskType;
      _isLoading = false;
    });
  }

  List<String> _availableTaskTypesForOrder(
    OrderModel order,
    List<CourierTaskModel> tasks,
  ) {
    bool hasActiveTask(String taskType) {
      return tasks.any(
        (task) =>
            task.taskType == taskType &&
            task.status != 'completed' &&
            task.status != 'cancelled',
      );
    }

    final types = <String>[];
    if (((order.status == 'created' && order.orderType != 'satuan') ||
            (order.status == 'paid' && order.orderType == 'satuan') ||
            order.status == 'waiting_pickup') &&
        !hasActiveTask('pickup')) {
      types.add('pickup');
    }
    if (order.status == 'ready_to_deliver' && !hasActiveTask('delivery')) {
      types.add('delivery');
    }
    return types;
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_order == null || newStatus == _order!.status) return;

    if (newStatus == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Batalkan Pesanan'),
          content: Text(
            'Ubah status ${_order!.orderCode} menjadi "${StatusBadge.labelFor(newStatus)}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Batalkan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final provider = context.read<AdminProvider>();
    final ok = await provider.updateOrderStatus(widget.orderId, newStatus);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Gagal memperbarui status'),
          backgroundColor: AppColors.error,
        ),
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
    final availableTaskTypes = _order != null
        ? _availableTaskTypesFor(_order!)
        : const <String>[];
    if (_order == null || availableTaskTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas kurir untuk tahap ini sudah ada')),
      );
      return;
    }
    final taskType = availableTaskTypes.contains(_selectedTaskType)
        ? _selectedTaskType
        : availableTaskTypes.first;
    final provider = context.read<AdminProvider>();
    final ok = await provider.assignCourier(
      widget.orderId,
      _selectedCourierId!,
      taskType,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kurir berhasil ditugaskan'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Gagal menugaskan kurir'),
          backgroundColor: AppColors.error,
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih layanan kiloan')));
      return;
    }
    final provider = context.read<AdminProvider>();
    final ok = await provider.updateOrderWeight(
      widget.orderId,
      weight,
      _selectedServiceId!,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berat berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Gagal memperbarui berat'),
          backgroundColor: AppColors.error,
        ),
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
    final kiloanServices = _uniqueBy(
      provider.services.where((s) => s.serviceType == 'kiloan' && s.isActive),
      _servicePickerKey,
    );
    final selectedServiceId =
        kiloanServices.any((service) => service.id == _selectedServiceId)
        ? _selectedServiceId
        : null;
    final selectedCourierId =
        provider.couriers.any((courier) => courier.userId == _selectedCourierId)
        ? _selectedCourierId
        : null;
    final nextStatuses = _nextStatusesFor(order);
    final availableTaskTypes = _availableTaskTypesFor(order);
    final canAssignCourier =
        availableTaskTypes.isNotEmpty && selectedCourierId != null;

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
              _row(
                'Tipe',
                order.orderType == 'kiloan'
                    ? 'Kiloan'
                    : order.orderType == 'satuan'
                    ? 'Satuan'
                    : 'Campuran',
              ),
              _row(
                'Tanggal',
                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
              ),
              if (order.notes != null && order.notes!.isNotEmpty)
                _row('Catatan', order.notes!),
              Row(
                children: [
                  const SizedBox(
                    width: 110,
                    child: Text('Status', style: TextStyle(color: Colors.grey)),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
            ]),

            // Items
            if (order.orderItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                'Item Pesanan',
                order.orderItems.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.serviceName),
                    subtitle: Text(
                      item.serviceType == 'kiloan'
                          ? '${item.weightKg ?? 0} kg'
                          : '${item.quantity} pcs',
                    ),
                    trailing: Text(
                      formatRupiah(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
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
                    child: Text(
                      'Status Bayar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Input Berat & Generate Invoice',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('service_${selectedServiceId ?? ''}'),
                        initialValue: selectedServiceId,
                        hint: const Text('Pilih Layanan Kiloan'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: kiloanServices
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${s.name} - ${formatRupiah(s.price)}/${s.unit}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedServiceId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Berat (kg)',
                          suffixText: 'kg',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tugaskan Kurir',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_courierTasks.isNotEmpty) ...[
                      ..._courierTasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.taskType == 'pickup'
                                      ? 'Penjemputan'
                                      : 'Pengantaran',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              StatusBadge(status: task.status),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                    ],
                    if (availableTaskTypes.isEmpty)
                      Text(
                        _courierAssignmentMessage(order),
                        style: const TextStyle(color: Colors.grey),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'task_${_selectedTaskType}_${availableTaskTypes.join('_')}',
                        ),
                        initialValue:
                            availableTaskTypes.contains(_selectedTaskType)
                            ? _selectedTaskType
                            : availableTaskTypes.first,
                        decoration: InputDecoration(
                          labelText: 'Tipe Tugas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: availableTaskTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type == 'pickup'
                                      ? 'Penjemputan'
                                      : 'Pengantaran',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () =>
                              _selectedTaskType = v ?? availableTaskTypes.first,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('courier_${selectedCourierId ?? ''}'),
                        initialValue: selectedCourierId,
                        hint: const Text('Pilih Kurir'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: provider.couriers
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.userId,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCourierId = v),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        onPressed: canAssignCourier ? _assignCourier : null,
                        label: 'Tugaskan Kurir',
                        isLoading: provider.isLoading,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Update status
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Perbarui Status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (nextStatuses.isEmpty)
                      const Text(
                        'Tidak ada status lanjutan',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ...nextStatuses.map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppButton(
                            onPressed: () => _updateStatus(status),
                            label: StatusBadge.labelFor(status),
                            isLoading: provider.isLoading,
                            color: status == 'cancelled'
                                ? AppColors.error
                                : AppColors.secondary,
                            isOutlined: status == 'cancelled',
                          ),
                        ),
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
                  final dt =
                      DateTime.tryParse(h['created_at'] as String? ?? '') ??
                      DateTime.now();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.history,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: StatusBadge(status: h['status'] as String? ?? ''),
                    subtitle:
                        h['note'] != null && (h['note'] as String).isNotEmpty
                        ? Text(
                            h['note'] as String,
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    trailing: Text(
                      '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
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
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
