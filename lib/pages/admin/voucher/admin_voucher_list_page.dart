import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/profile_model.dart';
import '../../../models/voucher_model.dart';
import '../../../providers/admin_provider.dart';

class AdminVoucherListPage extends StatefulWidget {
  const AdminVoucherListPage({super.key});

  @override
  State<AdminVoucherListPage> createState() => _AdminVoucherListPageState();
}

class _AdminVoucherListPageState extends State<AdminVoucherListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<AdminProvider>().loadVouchers();
  }

  Future<ProfileModel?> _pickCustomer(BuildContext context) async {
    final searchController = TextEditingController();
    List<ProfileModel> results = [];
    bool searching = false;

    return showDialog<ProfileModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pilih Customer'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Cari nama / no. telepon',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (q) async {
                    if (q.trim().isEmpty) {
                      setDialogState(() => results = []);
                      return;
                    }
                    setDialogState(() => searching = true);
                    final found = await context
                        .read<AdminProvider>()
                        .searchCustomers(q.trim());
                    setDialogState(() {
                      results = found;
                      searching = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Ketik untuk mencari customer',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (ctx, i) {
                        final customer = results[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(customer.name),
                          subtitle: Text(customer.phone),
                          onTap: () => Navigator.pop(ctx, customer),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDialog({VoucherModel? voucher}) {
    final codeController = TextEditingController(
      text: voucher?.code ??
          'PROMO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final discountController = TextEditingController(
      text: voucher?.discountPercent?.toStringAsFixed(0) ?? '100',
    );
    final maxDiscountController = TextEditingController(
      text: voucher?.maxDiscount?.toStringAsFixed(0) ?? '',
    );
    String selectedType = voucher?.type ?? 'discount';
    bool isActive = voucher == null || voucher.status == 'active';
    DateTime? expiredAt = voucher?.expiredAt;
    // Mode broadcast cuma relevan saat buat voucher baru: satu kode yang
    // sama dibagikan ke semua customer yang belum pernah order, masing-
    // masing dapat baris voucher miliknya sendiri.
    bool isBroadcast = false;
    ProfileModel? selectedCustomer = voucher != null
        ? ProfileModel(
            id: voucher.userId ?? '',
            userId: voucher.userId ?? '',
            name: voucher.customerName ?? 'Customer',
            phone: voucher.customerPhone ?? '',
            role: 'customer',
            createdAt: DateTime.now(),
          )
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(voucher == null ? 'Buat Voucher' : 'Edit Voucher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (voucher == null) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Customer Tertentu'),
                        icon: Icon(Icons.person, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Semua User Baru'),
                        icon: Icon(Icons.campaign, size: 16),
                      ),
                    ],
                    selected: {isBroadcast},
                    onSelectionChanged: (s) =>
                        setDialogState(() => isBroadcast = s.first),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isBroadcast)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Kode ini akan dibagikan ke semua customer yang belum '
                      'pernah order. Setiap customer dapat memakainya sekali; '
                      'customer baru lain yang belum kebagian tetap bisa '
                      'pakai kode yang sama nanti.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_search),
                    label: Text(
                      selectedCustomer == null
                          ? 'Pilih Customer'
                          : selectedCustomer!.name,
                    ),
                    onPressed: () async {
                      final picked = await _pickCustomer(ctx);
                      if (picked != null) {
                        setDialogState(() => selectedCustomer = picked);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Kode Voucher',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Tipe',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'discount',
                      child: Text('Diskon'),
                    ),
                    DropdownMenuItem(
                      value: 'free_laundry',
                      child: Text('Gratis 1x Cuci'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedType = v ?? 'discount'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Diskon (%)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxDiscountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Maks. Diskon (Rp, opsional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(
                    expiredAt == null
                        ? 'Tanpa tanggal kedaluwarsa'
                        : 'Berlaku sampai ${formatTanggalSingkat(expiredAt!)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expiredAt ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() => expiredAt = picked);
                    }
                  },
                ),
                if (voucher != null) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    title: const Text('Aktif'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                final code = codeController.text.trim().toUpperCase();
                final discount = double.tryParse(discountController.text);
                final maxDiscount = double.tryParse(
                  maxDiscountController.text,
                );
                if (code.isEmpty || (!isBroadcast && selectedCustomer == null)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isBroadcast
                            ? 'Kode voucher wajib diisi'
                            : 'Customer dan kode voucher wajib diisi',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final provider = context.read<AdminProvider>();
                bool ok;
                if (voucher == null && isBroadcast) {
                  ok = await provider.createBroadcastVoucherForNewCustomers(
                    code: code,
                    type: selectedType,
                    discountPercent: discount,
                    maxDiscount: maxDiscount,
                    expiredAt: expiredAt,
                  );
                } else if (voucher == null) {
                  ok = await provider.createVoucher(
                    userId: selectedCustomer!.userId,
                    code: code,
                    type: selectedType,
                    discountPercent: discount,
                    maxDiscount: maxDiscount,
                    expiredAt: expiredAt,
                  );
                } else {
                  ok = await provider.updateVoucher(
                    voucherId: voucher.id,
                    code: code,
                    type: selectedType,
                    discountPercent: discount,
                    maxDiscount: maxDiscount,
                    expiredAt: expiredAt,
                    status: isActive ? 'active' : 'cancelled',
                  );
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? (voucher == null
                              ? 'Voucher berhasil dibuat'
                              : 'Voucher berhasil diperbarui')
                          : provider.error ?? 'Gagal menyimpan voucher',
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              },
              child: Text(
                voucher == null ? 'Buat' : 'Simpan',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, Color color}) _statusBadge(VoucherModel v) {
    switch (v.status) {
      case 'active':
        return (label: 'Aktif', color: AppColors.success);
      case 'used':
        return (label: 'Terpakai', color: AppColors.primary);
      case 'expired':
        return (label: 'Kadaluarsa', color: AppColors.warning);
      default:
        return (label: 'Dibatalkan', color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Voucher'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVoucherDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.vouchers.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada voucher',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: provider.vouchers.length,
                    itemBuilder: (context, i) {
                      final v = provider.vouchers[i];
                      final badge = _statusBadge(v);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.accentPurple.withValues(alpha: 0.15),
                            child: Icon(
                              v.type == 'free_laundry'
                                  ? Icons.card_giftcard
                                  : Icons.local_offer,
                              color: AppColors.accentPurple,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  v.code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badge.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  badge.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badge.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(v.customerName ?? 'Customer tidak ditemukan'),
                              Text(
                                v.type == 'free_laundry'
                                    ? 'Gratis 1x Cuci'
                                    : 'Diskon ${v.discountPercent?.toStringAsFixed(0) ?? 0}%',
                              ),
                              if (v.expiredAt != null)
                                Text(
                                  'Berlaku sampai ${formatTanggalSingkat(v.expiredAt!)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showVoucherDialog(voucher: v),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
