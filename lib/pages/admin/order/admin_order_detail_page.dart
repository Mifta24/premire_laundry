import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/courier_task_model.dart';
import '../../../models/laundry_service_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/status_badge.dart';

const _stepIcons = [
  Icons.shopping_bag_outlined,
  Icons.local_laundry_service_outlined,
  Icons.iron_outlined,
  Icons.inventory_2_outlined,
  Icons.check_circle_outline,
];
const _stepLabels = [
  'Jemput',
  'Dicuci',
  'Disetrika',
  'Siap Diantar',
  'Selesai',
];

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
      // Mulai 'picked_up', laundry sudah di tangan kurir/toko, jadi
      // pembatalan sederhana (ubah status) tidak lagi ditawarkan —
      // butuh alur retur terpisah kalau memang perlu dibatalkan.
      case 'picked_up':
        return ['received_by_store'];
      case 'received_by_store':
        if (order.orderType == 'kiloan') return ['waiting_weight_input'];
        return ['washing'];
      case 'waiting_weight_input':
        return ['waiting_payment'];
      case 'waiting_payment':
        if (order.paymentStatus == 'paid') return ['paid'];
        // Untuk pesanan satuan, tahap ini terjadi sebelum laundry
        // dijemput (bayar dulu, baru dijemput) sehingga masih aman
        // dibatalkan. Untuk kiloan, tahap ini terjadi setelah laundry
        // dijemput, jadi tidak ditawarkan cancel.
        if (order.orderType == 'satuan') return ['cancelled'];
        return const [];
      case 'paid':
        if (order.orderType == 'satuan') return const [];
        return ['washing'];
      case 'washing':
        return ['ironing'];
      case 'ironing':
        return ['ready_to_deliver'];
      case 'ready_to_deliver':
        return const [];
      case 'out_for_delivery':
        return const [];
      default:
        return const [];
    }
  }

  int _milestoneIndex(String status) {
    switch (status) {
      case 'created':
      case 'waiting_pickup':
        return 0;
      case 'picked_up':
      case 'received_by_store':
      case 'waiting_weight_input':
      case 'waiting_payment':
      case 'paid':
      case 'washing':
        return 1;
      case 'ironing':
        return 2;
      case 'ready_to_deliver':
      case 'out_for_delivery':
        return 3;
      case 'completed':
        return 4;
      default:
        return 0;
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
    if (((order.status == 'paid' && order.orderType == 'satuan') ||
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
    if (order.status == 'created') {
      return 'Ubah status pesanan ke "Menunggu Jemput" sebelum menugaskan kurir';
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
    final kiloanItem = order?.orderItems
        .where((item) => item.serviceType == 'kiloan')
        .firstOrNull;

    setState(() {
      _order = order;
      _statusHistory = history;
      _courierTasks = courierTasks;
      _selectedServiceId = kiloanItem?.serviceId.isNotEmpty == true
          ? kiloanItem!.serviceId
          : _selectedServiceId;
      if (kiloanItem?.weightKg != null) {
        _weightController.text = kiloanItem!.weightKg!.toString();
      }
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
    if (((order.status == 'paid' && order.orderType == 'satuan') ||
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

  void _showUpdateStatusSheet(List<String> nextStatuses, bool isLoading) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perbarui Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(status);
                    },
                    label: StatusBadge.labelFor(status),
                    isLoading: isLoading,
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
    );
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

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
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
    final cancelled = order.status == 'cancelled';
    final milestone = _milestoneIndex(order.status);
    final canValidatePayment = order.payment?.status == 'waiting_verification';

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderCode),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderCode,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTanggalIndo(order.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status stepper
            if (cancelled)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pesanan ini telah dibatalkan.',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Pesanan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(_stepIcons.length * 2 - 1, (i) {
                          if (i.isOdd) {
                            final lineDone = (i ~/ 2) < milestone;
                            return Expanded(
                              child: Container(
                                height: 2,
                                color: lineDone
                                    ? AppColors.primary
                                    : Colors.grey[300],
                              ),
                            );
                          }
                          final step = i ~/ 2;
                          final done = step <= milestone;
                          return Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? AppColors.primary
                                      : Colors.grey[200],
                                ),
                                child: Icon(
                                  _stepIcons[step],
                                  size: 14,
                                  color: done ? Colors.white : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _stepLabels[step],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: done
                                      ? AppColors.primary
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Informasi Pelanggan
            _sectionCard('Informasi Pelanggan', [
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.customerName ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (order.customerPhone != null &&
                      order.customerPhone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.success),
                      onPressed: () => _callCustomer(order.customerPhone!),
                    ),
                ],
              ),
            ]),
            const SizedBox(height: 12),

            if (order.addressText != null && order.addressText!.isNotEmpty) ...[
              _sectionCard('Alamat Jemput', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(order.addressText!)),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
            ],

            // Items
            if (order.orderItems.isNotEmpty) ...[
              _sectionCard(
                'Layanan',
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
              const SizedBox(height: 12),
            ],

            if (order.notes != null && order.notes!.isNotEmpty) ...[
              _sectionCard('Catatan Pakaian', [Text(order.notes!)]),
              const SizedBox(height: 12),
            ],

            // Payment summary
            _sectionCard('Ringkasan Biaya', [
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
                      const SizedBox(height: 4),
                      Text(
                        selectedServiceId == null
                            ? 'Pilih layanan kiloan untuk order lama, lalu input berat.'
                            : 'Layanan sudah dipilih customer. Admin cukup input berat.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('service_${selectedServiceId ?? ''}'),
                        initialValue: selectedServiceId,
                        hint: const Text('Pilih Layanan Kiloan'),
                        decoration: InputDecoration(
                          labelText: 'Layanan Kiloan',
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
                      'Assign Kurir',
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
                        label: 'Assign Kurir',
                        isLoading: provider.isLoading,
                      ),
                    ],
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
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                onPressed: () =>
                    _showUpdateStatusSheet(nextStatuses, provider.isLoading),
                label: 'Update Status',
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                onPressed: canValidatePayment
                    ? () => context.push('/admin/payment/${order.payment!.id}')
                    : null,
                label: 'Validasi Pembayaran',
              ),
            ),
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
