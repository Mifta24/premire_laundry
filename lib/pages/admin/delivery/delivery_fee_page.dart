import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/delivery_fee_model.dart';
import '../../../providers/admin_provider.dart';

class DeliveryFeePage extends StatefulWidget {
  const DeliveryFeePage({super.key});

  @override
  State<DeliveryFeePage> createState() => _DeliveryFeePageState();
}

class _DeliveryFeePageState extends State<DeliveryFeePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<AdminProvider>().loadDeliveryFees();
  }

  void _showDialog({DeliveryFeeModel? fee}) {
    final nameController = TextEditingController(text: fee?.name ?? '');
    final minController =
        TextEditingController(text: fee?.minDistanceKm.toString() ?? '');
    final maxController =
        TextEditingController(text: fee?.maxDistanceKm.toString() ?? '');
    final feeController =
        TextEditingController(text: fee?.fee.toString() ?? '');
    bool isActive = fee?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(fee == null ? 'Tambah Ongkir' : 'Edit Ongkir'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    hintText: 'Contoh: Dalam Kota',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Min (km)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Max (km)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Biaya',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (fee != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) =>
                        setDialogState(() => isActive = v),
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
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                final name = nameController.text.trim();
                final min = double.tryParse(minController.text) ?? 0;
                final max = double.tryParse(maxController.text) ?? 0;
                final feeVal = double.tryParse(feeController.text) ?? 0;
                if (name.isEmpty || max <= min || feeVal < 0) return;

                Navigator.pop(ctx);
                final provider = context.read<AdminProvider>();
                bool ok;
                if (fee == null) {
                  ok = await provider.addDeliveryFee(name, min, max, feeVal);
                } else {
                  ok = await provider.updateDeliveryFee(
                      fee.id, name, min, max, feeVal, isActive);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? (fee == null
                          ? 'Ongkir berhasil ditambahkan'
                          : 'Ongkir berhasil diperbarui')
                      : 'Gagal menyimpan ongkir'),
                  backgroundColor:
                      ok ? AppColors.success : AppColors.error,
                ));
              },
              child: Text(fee == null ? 'Tambah' : 'Simpan',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ongkos Kirim'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.deliveryFees.isEmpty
              ? Center(
                  child: Text('Belum ada ongkos kirim',
                      style: TextStyle(color: Colors.grey[600])),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: provider.deliveryFees.length,
                    itemBuilder: (context, i) {
                      final f = provider.deliveryFees[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.secondary.withValues(alpha: 0.15),
                            child: const Icon(Icons.delivery_dining,
                                color: AppColors.secondary),
                          ),
                          title: Row(
                            children: [
                              Text(f.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              if (!f.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Nonaktif',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                              '${f.minDistanceKm} - ${f.maxDistanceKm} km · ${formatRupiah(f.fee)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit,
                                color: AppColors.primary),
                            onPressed: () => _showDialog(fee: f),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
