import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/address_model.dart';
import '../../../models/laundry_service_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/app_button.dart';

class CreateOrderPage extends StatefulWidget {
  final String orderType;
  const CreateOrderPage({super.key, required this.orderType});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  int _step = 0;
  final _notesController = TextEditingController();
  final _voucherController = TextEditingController();

  List<LaundryServiceModel> _services = [];
  final Map<String, int> _selectedQuantities = {};
  AddressModel? _selectedAddress;
  List<AddressModel> _addresses = [];
  List<Map<String, dynamic>> _deliveryFees = [];
  double _deliveryFee = 0;
  double _subtotal = 0;
  bool _isLoading = false;

  // Store location (from settings, defaults here)
  double _storeLat = -6.200000;
  double _storeLng = 106.816666;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = context.read<AuthProvider>().currentUser?.id;

      // Load services if satuan
      if (widget.orderType == 'satuan') {
        final servicesData = await supabase
            .from('laundry_services')
            .select()
            .eq('service_type', 'satuan')
            .eq('is_active', true);
        _services = (servicesData as List<dynamic>)
            .map((s) => LaundryServiceModel.fromJson(s as Map<String, dynamic>))
            .toList();
      }

      // Load addresses
      if (userId != null) {
        final addrData = await supabase
            .from('addresses')
            .select()
            .eq('user_id', userId)
            .order('is_default', ascending: false);
        _addresses = (addrData as List<dynamic>)
            .map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
            .toList();
        if (_addresses.isNotEmpty) {
          _selectedAddress = _addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => _addresses.first,
          );
        }
      }

      // Load delivery fees
      final feesData = await supabase
          .from('delivery_fees')
          .select()
          .eq('is_active', true)
          .order('min_distance_km');
      _deliveryFees = (feesData as List<dynamic>).cast<Map<String, dynamic>>();

      // Load store location from settings
      try {
        final latSetting = await supabase
            .from('settings')
            .select('value')
            .eq('key', 'store_latitude')
            .maybeSingle();
        final lngSetting = await supabase
            .from('settings')
            .select('value')
            .eq('key', 'store_longitude')
            .maybeSingle();
        if (latSetting != null) {
          _storeLat = double.tryParse(latSetting['value'] as String) ?? _storeLat;
        }
        if (lngSetting != null) {
          _storeLng = double.tryParse(lngSetting['value'] as String) ?? _storeLng;
        }
      } catch (_) {}

      _updateDeliveryFee();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  void _updateDeliveryFee() {
    if (_selectedAddress == null ||
        _selectedAddress!.latitude == null ||
        _selectedAddress!.longitude == null) {
      _deliveryFee = 0;
      return;
    }
    final dist = _haversineDistance(
      _storeLat,
      _storeLng,
      _selectedAddress!.latitude!,
      _selectedAddress!.longitude!,
    );
    double fee = 0;
    for (final f in _deliveryFees) {
      final min = (f['min_distance_km'] as num).toDouble();
      final max = (f['max_distance_km'] as num).toDouble();
      if (dist >= min && dist <= max) {
        fee = (f['fee'] as num).toDouble();
        break;
      }
    }
    setState(() => _deliveryFee = fee);
  }

  void _updateSubtotal() {
    double sub = 0;
    for (final svc in _services) {
      final qty = _selectedQuantities[svc.id] ?? 0;
      sub += svc.price * qty;
    }
    setState(() => _subtotal = sub);
  }

  double get _total => _subtotal + _deliveryFee;

  List<Map<String, dynamic>> get _orderItems {
    if (widget.orderType == 'kiloan') return [];
    return _services
        .where((s) => (_selectedQuantities[s.id] ?? 0) > 0)
        .map((s) => {
              'service_id': s.id,
              'service_name': s.name,
              'service_type': s.serviceType,
              'quantity': _selectedQuantities[s.id] ?? 0,
              'price': s.price,
              'subtotal': s.price * (_selectedQuantities[s.id] ?? 0),
            })
        .toList();
  }

  Future<void> _submitOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih alamat pengiriman terlebih dahulu')),
      );
      return;
    }
    if (widget.orderType == 'satuan' && _orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu layanan')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final provider = context.read<CustomerProvider>();

    double? distKm;
    if (_selectedAddress!.latitude != null && _selectedAddress!.longitude != null) {
      distKm = _haversineDistance(
        _storeLat, _storeLng,
        _selectedAddress!.latitude!, _selectedAddress!.longitude!,
      );
    }

    final orderId = await provider.createOrder(
      customerId: userId,
      orderType: widget.orderType,
      items: _orderItems,
      addressId: _selectedAddress!.id,
      notes: _notesController.text.trim(),
      deliveryFee: _deliveryFee,
      subtotal: _subtotal,
      total: _total,
      voucherCode: _voucherController.text.trim().isNotEmpty
          ? _voucherController.text.trim()
          : null,
      estimatedDistanceKm: distKm,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (orderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil dibuat!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/customer/order/$orderId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Gagal membuat pesanan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderType == 'kiloan'
            ? 'Order Kiloan'
            : 'Order Satuan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: IndexedStack(
                    index: _step,
                    children: [
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                    ],
                  ),
                ),
                _buildNavigationButtons(),
              ],
            ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepChip(0, 'Detail'),
          _stepDivider(),
          _stepChip(1, 'Alamat'),
          _stepDivider(),
          _stepChip(2, 'Ringkasan'),
        ],
      ),
    );
  }

  Widget _stepChip(int index, String label) {
    final isActive = _step == index;
    final isDone = _step > index;
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: isDone
              ? AppColors.success
              : isActive
                  ? AppColors.primary
                  : Colors.grey[300],
          child: isDone
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : Colors.grey)),
      ],
    );
  }

  Widget _stepDivider() {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
      color: Colors.grey[300],
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.orderType == 'satuan') ...[
            const Text('Pilih Layanan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_services.isEmpty)
              const Center(child: Text('Tidak ada layanan tersedia'))
            else
              ..._services.map((svc) {
                final qty = _selectedQuantities[svc.id] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    title: Text(svc.name),
                    subtitle: Text(
                        '${formatRupiah(svc.price)} / ${svc.unit}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: AppColors.primary,
                          onPressed: qty > 0
                              ? () {
                                  setState(() {
                                    _selectedQuantities[svc.id] = qty - 1;
                                  });
                                  _updateSubtotal();
                                }
                              : null,
                        ),
                        Text('$qty',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.primary,
                          onPressed: () {
                            setState(() {
                              _selectedQuantities[svc.id] = qty + 1;
                            });
                            _updateSubtotal();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
          if (widget.orderType == 'kiloan')
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Berat pakaian akan ditimbang di toko. Total pembayaran akan dihitung setelah penimbangan.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: Pisahkan pakaian anak-anak',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pilih Alamat',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () async {
                  await context.push('/customer/address/add');
                  _loadData();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_addresses.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('Belum ada alamat. Tambahkan alamat baru.'),
                ),
              ),
            )
          else
            ..._addresses.map((addr) {
              final isSelected = _selectedAddress?.id == addr.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                  title: Row(
                    children: [
                      Text(addr.label,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (addr.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Utama',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(addr.addressText,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedAddress = addr);
                    _updateDeliveryFee();
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow('Tipe',
                      widget.orderType == 'kiloan' ? 'Kiloan' : 'Satuan'),
                  if (_selectedAddress != null) ...[
                    _summaryRow('Alamat', _selectedAddress!.addressText),
                  ],
                  if (_notesController.text.isNotEmpty)
                    _summaryRow('Catatan', _notesController.text),
                ],
              ),
            ),
          ),
          if (widget.orderType == 'satuan' && _orderItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Item',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: _orderItems
                    .map((item) => ListTile(
                          title: Text(item['service_name'] as String),
                          subtitle:
                              Text('${item['quantity']} pcs'),
                          trailing:
                              Text(formatRupiah(item['subtotal'] as num)),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (widget.orderType == 'kiloan')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Subtotal dihitung setelah penimbangan',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  _amountRow('Subtotal',
                      widget.orderType == 'kiloan'
                          ? 'Belum dihitung'
                          : formatRupiah(_subtotal)),
                  _amountRow('Ongkir', formatRupiah(_deliveryFee)),
                  const Divider(),
                  _amountRow(
                    'Total',
                    widget.orderType == 'kiloan'
                        ? formatRupiah(_deliveryFee)
                        : formatRupiah(_total),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _voucherController,
            decoration: InputDecoration(
              labelText: 'Kode Voucher (opsional)',
              prefixIcon: const Icon(Icons.card_giftcard),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14,
                  color: bold ? AppColors.primary : null)),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          if (_step > 0) ...[
            Expanded(
              child: AppButton(
                onPressed: () => setState(() => _step--),
                label: 'Kembali',
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AppButton(
              onPressed: _step < 2
                  ? () => setState(() => _step++)
                  : _submitOrder,
              label: _step < 2 ? 'Lanjut' : 'Buat Pesanan',
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }
}
