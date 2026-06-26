import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/profile_model.dart';
import '../../../models/promo_code_model.dart';
import '../../../models/voucher_model.dart';
import '../../../providers/admin_provider.dart';

class AdminVoucherListPage extends StatefulWidget {
  const AdminVoucherListPage({super.key});

  @override
  State<AdminVoucherListPage> createState() => _AdminVoucherListPageState();
}

class _AdminVoucherListPageState extends State<AdminVoucherListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<AdminProvider>().loadVouchers(),
      context.read<AdminProvider>().loadPromoCodes(),
    ]);
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
                if (code.isEmpty || selectedCustomer == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Customer dan kode voucher wajib diisi'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final provider = context.read<AdminProvider>();
                bool ok;
                if (voucher == null) {
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
                          : 'Gagal menyimpan voucher',
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

  void _showPromoCodeDialog({PromoCodeModel? promo}) {
    final codeController = TextEditingController(
      text: promo?.code ?? 'PREMIER20',
    );
    final discountController = TextEditingController(
      text: promo?.discountPercent.toStringAsFixed(0) ?? '20',
    );
    final maxDiscountController = TextEditingController(
      text: promo?.maxDiscount?.toStringAsFixed(0) ?? '',
    );
    bool newUserOnly = promo?.newUserOnly ?? true;
    bool isActive = promo == null || promo.isActive;
    DateTime? expiredAt = promo?.expiredAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(promo == null ? 'Buat Promo Massal' : 'Edit Promo Massal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kode promo berlaku untuk banyak user sekaligus. Setiap '
                  'user hanya bisa memakainya sekali.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Kode Promo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
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
                SwitchListTile(
                  value: newUserOnly,
                  onChanged: (v) => setDialogState(() => newUserOnly = v),
                  title: const Text('Khusus User Baru'),
                  subtitle: const Text('Hanya user yang belum pernah order'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (promo != null)
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    title: const Text('Aktif'),
                    contentPadding: EdgeInsets.zero,
                  ),
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
                if (code.isEmpty || discount == null || discount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Kode dan diskon promo wajib diisi'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final provider = context.read<AdminProvider>();
                bool ok;
                if (promo == null) {
                  ok = await provider.createPromoCode(
                    code: code,
                    discountPercent: discount,
                    maxDiscount: maxDiscount,
                    newUserOnly: newUserOnly,
                    expiredAt: expiredAt,
                  );
                } else {
                  ok = await provider.updatePromoCode(
                    promoCodeId: promo.id,
                    code: code,
                    discountPercent: discount,
                    maxDiscount: maxDiscount,
                    newUserOnly: newUserOnly,
                    isActive: isActive,
                    expiredAt: expiredAt,
                  );
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? (promo == null
                              ? 'Promo berhasil dibuat'
                              : 'Promo berhasil diperbarui')
                          : 'Gagal menyimpan promo',
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              },
              child: Text(
                promo == null ? 'Buat' : 'Simpan',
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

  ({String label, Color color}) _promoStatusBadge(PromoCodeModel p) {
    if (!p.isActive) return (label: 'Nonaktif', color: AppColors.error);
    if (p.expiredAt != null && p.expiredAt!.isBefore(DateTime.now())) {
      return (label: 'Kadaluarsa', color: AppColors.warning);
    }
    return (label: 'Aktif', color: AppColors.success);
  }

  Widget _buildVoucherTab(AdminProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.vouchers.isEmpty) {
      return Center(
        child: Text('Belum ada voucher', style: TextStyle(color: Colors.grey[600])),
      );
    }
    return RefreshIndicator(
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
                backgroundColor: AppColors.accentPurple.withValues(alpha: 0.15),
                child: Icon(
                  v.type == 'free_laundry' ? Icons.card_giftcard : Icons.local_offer,
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }

  Widget _buildPromoTab(AdminProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.promoCodes.isEmpty) {
      return Center(
        child: Text('Belum ada promo massal', style: TextStyle(color: Colors.grey[600])),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: provider.promoCodes.length,
        itemBuilder: (context, i) {
          final p = provider.promoCodes[i];
          final badge = _promoStatusBadge(p);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.campaign, color: AppColors.primary),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  Text('Diskon ${p.discountPercent.toStringAsFixed(0)}%'),
                  Text(
                    p.newUserOnly
                        ? 'Khusus user baru · 1x per user'
                        : 'Semua user · 1x per user',
                  ),
                  if (p.expiredAt != null)
                    Text(
                      'Berlaku sampai ${formatTanggalSingkat(p.expiredAt!)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPromoCodeDialog(promo: p),
            ),
          );
        },
      ),
    );
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Voucher Pribadi'),
            Tab(text: 'Promo Massal'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tabController.index == 0
            ? () => _showVoucherDialog()
            : () => _showPromoCodeDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVoucherTab(provider),
          _buildPromoTab(provider),
        ],
      ),
    );
  }
}
