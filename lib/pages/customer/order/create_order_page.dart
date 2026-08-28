import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/address_model.dart';
import '../../../models/laundry_service_model.dart';
import '../../../models/voucher_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/app_button.dart';

class CreateOrderPage extends StatefulWidget {
  final String orderType;
  final bool lockType;
  const CreateOrderPage({
    super.key,
    required this.orderType,
    this.lockType = false,
  });

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  late String _orderType;
  String _paymentMethod = 'qris';
  final _notesController = TextEditingController();
  final _voucherController = TextEditingController();

  List<LaundryServiceModel> _services = [];
  String? _selectedKiloanServiceId;
  final Map<String, int> _selectedQuantities = {};
  AddressModel? _selectedAddress;
  List<AddressModel> _addresses = [];
  List<Map<String, dynamic>> _deliveryFees = [];
  double _deliveryFee = 0;
  double? _estimatedDistanceKm;
  double _subtotal = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  VoucherModel? _appliedVoucher;
  bool _isValidatingVoucher = false;

  // Store location (from settings, defaults here)
  double _storeLat = -6.200000;
  double _storeLng = 106.816666;

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item,
    ];
  }

  String _servicePickerKey(LaundryServiceModel service) {
    return [
      service.serviceType.trim().toLowerCase(),
      service.name.trim().toLowerCase(),
      service.unit.trim().toLowerCase(),
      service.price.toStringAsFixed(2),
    ].join('|');
  }

  String _deliveryFeeKey(Map<String, dynamic> fee) {
    final minKm = (fee['min_distance_km'] as num?)?.toDouble() ?? 0;
    final maxKm = (fee['max_distance_km'] as num?)?.toDouble();
    final feeAmount = (fee['fee'] as num?)?.toDouble() ?? 0;
    return [
      (fee['name'] as String? ?? '').trim().toLowerCase(),
      minKm.toStringAsFixed(2),
      maxKm?.toStringAsFixed(2) ?? 'open',
      feeAmount.toStringAsFixed(2),
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    _orderType = widget.orderType;
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

      final servicesData = await supabase
          .from('laundry_services')
          .select()
          .eq('is_active', true)
          .order('service_type')
          .order('name');
      _services = _uniqueBy(
        (servicesData as List<dynamic>).map(
          (s) => LaundryServiceModel.fromJson(s as Map<String, dynamic>),
        ),
        _servicePickerKey,
      );

      // Load addresses
      if (userId != null) {
        final addrData = await supabase
            .from('addresses')
            .select()
            .eq('user_id', userId)
            .isFilter('deleted_at', null)
            .order('is_default', ascending: false);
        _addresses = _uniqueBy(
          (addrData as List<dynamic>).map(
            (a) => AddressModel.fromJson(a as Map<String, dynamic>),
          ),
          (address) => address.id,
        );
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
      _deliveryFees = _uniqueBy(
        (feesData as List<dynamic>).cast<Map<String, dynamic>>(),
        _deliveryFeeKey,
      );

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
          _storeLat =
              double.tryParse(latSetting['value'] as String) ?? _storeLat;
        }
        if (lngSetting != null) {
          _storeLng =
              double.tryParse(lngSetting['value'] as String) ?? _storeLng;
        }
      } catch (_) {}

      _updateDeliveryFee();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  void _updateDeliveryFee() {
    if (_selectedAddress == null ||
        _selectedAddress!.latitude == null ||
        _selectedAddress!.longitude == null) {
      setState(() {
        _deliveryFee = 0;
        _estimatedDistanceKm = null;
      });
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
      final min = (f['min_distance_km'] as num?)?.toDouble() ?? 0;
      final max = (f['max_distance_km'] as num?)?.toDouble() ?? double.infinity;
      if (dist >= min && dist <= max) {
        final ratePerKm = (f['fee'] as num?)?.toDouble() ?? 0;
        final chargeableKm = dist <= 0 ? 0 : dist.ceilToDouble();
        fee = ratePerKm * chargeableKm * 2;
        break;
      }
    }
    setState(() {
      _deliveryFee = fee;
      _estimatedDistanceKm = dist;
    });
  }

  void _updateSubtotal() {
    if (_orderType == 'kiloan') {
      setState(() => _subtotal = 0);
      return;
    }
    double sub = 0;
    for (final svc in _satuanServices) {
      final qty = _selectedQuantities[svc.id] ?? 0;
      sub += svc.price * qty;
    }
    setState(() => _subtotal = sub);
  }

  double get _discountAmount {
    if (_appliedVoucher == null) return 0;
    final percent = _appliedVoucher!.discountPercent ?? 0;
    final rawDiscount = _subtotal * (percent / 100);
    final cappedBySubtotal = rawDiscount > _subtotal ? _subtotal : rawDiscount;
    final maxDiscount = _appliedVoucher!.maxDiscount;
    if (maxDiscount != null &&
        maxDiscount > 0 &&
        cappedBySubtotal > maxDiscount) {
      return maxDiscount;
    }
    return cappedBySubtotal;
  }

  double get _total => _subtotal - _discountAmount + _deliveryFee;

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;
    if (_subtotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher bisa dipakai setelah total layanan tersedia'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final provider = context.read<CustomerProvider>();

    setState(() => _isValidatingVoucher = true);
    final voucher = await provider.validateVoucher(userId: userId, code: code);
    if (!mounted) return;
    setState(() {
      _isValidatingVoucher = false;
      _appliedVoucher = voucher;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          voucher != null
              ? 'Voucher berhasil diterapkan'
              : provider.error ?? 'Voucher tidak valid',
        ),
        backgroundColor: voucher != null ? AppColors.success : AppColors.error,
      ),
    );
  }

  List<Map<String, dynamic>> get _orderItems {
    if (_orderType == 'kiloan') {
      final service = _selectedKiloanService;
      if (service == null) return [];
      return [
        {
          'service_id': service.id,
          'service_name': service.name,
          'service_type': service.serviceType,
          'quantity': 1,
          'price': service.price,
          'subtotal': 0,
        },
      ];
    }
    return _satuanServices
        .where((s) => (_selectedQuantities[s.id] ?? 0) > 0)
        .map(
          (s) => {
            'service_id': s.id,
            'service_name': s.name,
            'service_type': s.serviceType,
            'quantity': _selectedQuantities[s.id] ?? 0,
            'price': s.price,
            'subtotal': s.price * (_selectedQuantities[s.id] ?? 0),
          },
        )
        .toList();
  }

  List<LaundryServiceModel> get _kiloanServices =>
      _services.where((s) => s.serviceType == 'kiloan').toList();

  List<LaundryServiceModel> get _satuanServices =>
      _services.where((s) => s.serviceType == 'satuan').toList();

  LaundryServiceModel? get _selectedKiloanService {
    final serviceId = _selectedKiloanServiceId;
    if (serviceId == null) return null;
    for (final service in _kiloanServices) {
      if (service.id == serviceId) return service;
    }
    return null;
  }

  String _kiloanDurationText(String serviceName) {
    final lowerName = serviceName.toLowerCase();
    if (lowerName.startsWith('reguler')) return 'Max 3 hari';
    if (lowerName.startsWith('express')) return 'Masuk hari ini, besok selesai';
    if (lowerName.startsWith('kilat')) return 'Masuk pagi, sore selesai';
    return 'Ditimbang di toko';
  }

  Future<void> _pickAddress() async {
    final picked = await showModalBottomSheet<AddressModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Alamat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await context.push('/customer/address/add');
                      _loadData();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _addresses.isEmpty
                    ? const Center(
                        child: Text('Belum ada alamat. Tambahkan alamat baru.'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _addresses.length,
                        itemBuilder: (context, i) {
                          final addr = _addresses[i];
                          final isSelected = _selectedAddress?.id == addr.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.location_on,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey,
                              ),
                              title: Text(
                                addr.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                addr.addressText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(ctx, addr),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() => _selectedAddress = picked);
      _updateDeliveryFee();
    }
  }

  Future<void> _submitOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih alamat pengiriman terlebih dahulu'),
        ),
      );
      return;
    }
    if (_orderType == 'satuan' && _orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu layanan')),
      );
      return;
    }
    if (_orderType == 'kiloan' && _selectedKiloanService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih layanan kiloan terlebih dahulu')),
      );
      return;
    }
    if (_voucherController.text.trim().isNotEmpty && _appliedVoucher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tekan "Terapkan" untuk memvalidasi voucher, atau hapus kodenya',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id ?? '';
    final provider = context.read<CustomerProvider>();

    double? distKm;
    if (_selectedAddress!.latitude != null &&
        _selectedAddress!.longitude != null) {
      distKm = _haversineDistance(
        _storeLat,
        _storeLng,
        _selectedAddress!.latitude!,
        _selectedAddress!.longitude!,
      );
    }

    final orderId = await provider.createOrder(
      customerId: userId,
      orderType: _orderType,
      items: _orderItems,
      addressId: _selectedAddress!.id,
      notes: _notesController.text.trim(),
      deliveryFee: _deliveryFee,
      subtotal: _subtotal,
      total: _total,
      voucherCode: _appliedVoucher?.code,
      discountAmount: _appliedVoucher != null ? _discountAmount : null,
      estimatedDistanceKm: distKm,
    );

    if (!mounted) return;

    if (orderId == null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Gagal membuat pesanan'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_orderType == 'kiloan') {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil dibuat!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pushReplacement('/customer/order/$orderId');
      return;
    }

    // Satuan: price is known upfront, proceed straight to payment.
    if (_paymentMethod == 'qris') {
      final paymentId = await provider.createPayment(
        orderId: orderId,
        customerId: userId,
        method: 'manual_qris',
        amount: _total,
      );
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      if (paymentId != null) {
        context.pushReplacement('/customer/payment/qris/$orderId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Gagal membuat pembayaran'),
            backgroundColor: AppColors.error,
          ),
        );
        context.pushReplacement('/customer/order/$orderId');
      }
      return;
    }

    // Xendit
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-xendit-invoice',
        body: {
          'orderId': orderId,
          'amount': _total,
          'customerName': authProvider.profile?.name ?? 'Customer',
          'customerEmail': authProvider.currentUser?.email ?? '',
        },
      );
      final paymentUrl = response.data?['invoiceUrl'] as String?;
      if (paymentUrl != null) {
        final uri = Uri.parse(paymentUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka halaman pembayaran: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        context.pushReplacement('/customer/order/$orderId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buat Pesanan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.lockType) ...[
                    _buildTypeToggle(),
                    const SizedBox(height: 16),
                  ],
                  _sectionTitle('Pilih Layanan'),
                  const SizedBox(height: 8),
                  _buildServiceSection(),
                  const SizedBox(height: 16),
                  _sectionTitle('Alamat Pengantaran'),
                  const SizedBox(height: 8),
                  _buildAddressTile(),
                  const SizedBox(height: 16),
                  _sectionTitle('Catatan Pakaian'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Hindari pemutih, pakaian bayi, dll.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEstimasiOngkir(),
                  if (_orderType == 'satuan') ...[
                    const SizedBox(height: 16),
                    _sectionTitle('Metode Pembayaran'),
                    const SizedBox(height: 8),
                    _paymentOption(
                      value: 'qris',
                      icon: Icons.qr_code,
                      title: 'QRIS Manual',
                      subtitle: 'Bayar via QRIS dari semua e-wallet',
                    ),
                    const SizedBox(height: 8),
                    _paymentOption(
                      value: 'xendit',
                      icon: Icons.payment,
                      title: 'Xendit',
                      subtitle: 'Pembayaran aman via Xendit',
                    ),
                    const SizedBox(height: 16),
                    _buildSummary(),
                  ],
                  if (_orderType == 'satuan') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _voucherController,
                      onChanged: (_) {
                        if (_appliedVoucher != null) {
                          setState(() => _appliedVoucher = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Kode Voucher (opsional)',
                        prefixIcon: const Icon(Icons.card_giftcard),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _isValidatingVoucher
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : TextButton(
                                  onPressed: _applyVoucher,
                                  child: const Text('Terapkan'),
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (_appliedVoucher != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Diskon ${formatRupiah(_discountAmount)} diterapkan',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    onPressed: _submitOrder,
                    label: 'Buat Pesanan',
                    isLoading: _isSubmitting,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dengan membuat pesanan, Anda menyetujui Syarat & Ketentuan kami.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _typeButton('kiloan', 'Laundry Kiloan', Icons.scale)),
          const SizedBox(width: 4),
          Expanded(
            child: _typeButton('satuan', 'Laundry Satuan', Icons.checkroom),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String type, String label, IconData icon) {
    final isSelected = _orderType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _orderType = type;
          _appliedVoucher = null;
          _voucherController.clear();
        });
        _updateSubtotal();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection() {
    if (_orderType == 'kiloan') {
      final services = _kiloanServices;
      if (services.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Tidak ada layanan kiloan tersedia')),
          ),
        );
      }
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pilih paket kiloan sekarang. Admin nanti hanya input berat setelah pakaian ditimbang.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            ...services.map((svc) {
              final isSelected = _selectedKiloanServiceId == svc.id;
              return ListTile(
                selected: isSelected,
                leading: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.local_laundry_service_outlined,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                title: Text(
                  svc.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${formatRupiah(svc.price)} / ${svc.unit} • ${_kiloanDurationText(svc.name)}',
                ),
                onTap: () => setState(() => _selectedKiloanServiceId = svc.id),
              );
            }),
          ],
        ),
      );
    }

    final services = _satuanServices;
    if (services.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Tidak ada layanan tersedia')),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: services.map((svc) {
          final qty = _selectedQuantities[svc.id] ?? 0;
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.checkroom, color: AppColors.primary),
            ),
            title: Text(svc.name),
            subtitle: Text('${formatRupiah(svc.price)} / ${svc.unit}'),
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
                Text(
                  '$qty',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddressTile() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: AppColors.primary),
        title: Text(
          _selectedAddress?.label ?? 'Pilih alamat',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _selectedAddress?.addressText ?? 'Belum ada alamat terpilih',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: _pickAddress,
      ),
    );
  }

  Widget _buildEstimasiOngkir() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.delivery_dining, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Biaya Jemput & Antar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _estimatedDistanceKm == null
                        ? 'Pilih alamat dengan titik lokasi'
                        : 'Jarak ${_estimatedDistanceKm!.toStringAsFixed(1)} km x pulang-pergi',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Text(
              formatRupiah(_deliveryFee),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _paymentMethod == value;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _paymentMethod,
        onChanged: (v) => setState(() => _paymentMethod = v!),
        activeColor: AppColors.primary,
        title: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _amountRow('Subtotal', formatRupiah(_subtotal)),
            _amountRow('Biaya Jemput & Antar', formatRupiah(_deliveryFee)),
            if (_appliedVoucher != null)
              _amountRow('Diskon', '- ${formatRupiah(_discountAmount)}'),
            const Divider(),
            _amountRow('Total', formatRupiah(_total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
              color: bold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
