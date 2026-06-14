import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/laundry_service_model.dart';
import '../../../providers/admin_provider.dart';

class ManageServicesPage extends StatefulWidget {
  const ManageServicesPage({super.key});

  @override
  State<ManageServicesPage> createState() => _ManageServicesPageState();
}

class _ManageServicesPageState extends State<ManageServicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<AdminProvider>().loadServices();
  }

  void _showDialog({LaundryServiceModel? service}) {
    final nameController =
        TextEditingController(text: service?.name ?? '');
    final priceController =
        TextEditingController(text: service?.price.toString() ?? '');
    final unitController =
        TextEditingController(text: service?.unit ?? '');
    String selectedType = service?.serviceType ?? 'kiloan';
    bool isActive = service?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(service == null ? 'Tambah Layanan' : 'Edit Layanan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Layanan',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Tipe',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'kiloan', child: Text('Kiloan')),
                    DropdownMenuItem(value: 'satuan', child: Text('Satuan')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedType = v ?? 'kiloan'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Harga',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: InputDecoration(
                    labelText: 'Satuan',
                    hintText: 'kg / pcs / item',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (service != null) ...[
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
                final price = double.tryParse(priceController.text) ?? 0;
                final unit = unitController.text.trim();
                if (name.isEmpty || price <= 0 || unit.isEmpty) return;

                Navigator.pop(ctx);
                final provider = context.read<AdminProvider>();
                bool ok;
                if (service == null) {
                  ok = await provider.addService(
                      name, selectedType, price, unit);
                } else {
                  ok = await provider.updateService(
                      service.id, name, selectedType, price, unit, isActive);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? (service == null
                            ? 'Layanan berhasil ditambahkan'
                            : 'Layanan berhasil diperbarui')
                        : 'Gagal menyimpan layanan'),
                    backgroundColor:
                        ok ? AppColors.success : AppColors.error,
                  ),
                );
              },
              child: Text(service == null ? 'Tambah' : 'Simpan',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Layanan'),
        content: const Text('Hapus layanan ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context.read<AdminProvider>().deleteService(serviceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Layanan dihapus' : 'Gagal menghapus'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Layanan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.services.isEmpty
              ? Center(
                  child: Text('Belum ada layanan',
                      style: TextStyle(color: Colors.grey[600])),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: provider.services.length,
                    itemBuilder: (context, i) {
                      final svc = provider.services[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (svc.serviceType == 'kiloan'
                                    ? AppColors.primary
                                    : AppColors.secondary)
                                .withValues(alpha: 0.15),
                            child: Icon(
                              svc.serviceType == 'kiloan'
                                  ? Icons.scale
                                  : Icons.checkroom,
                              color: svc.serviceType == 'kiloan'
                                  ? AppColors.primary
                                  : AppColors.secondary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(svc.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              if (!svc.isActive)
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
                              '${formatRupiah(svc.price)} / ${svc.unit} · ${svc.serviceType == 'kiloan' ? 'Kiloan' : 'Satuan'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: AppColors.primary),
                                onPressed: () => _showDialog(service: svc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: AppColors.error),
                                onPressed: () => _delete(svc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
