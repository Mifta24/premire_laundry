import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/app_button.dart';

class QrisPage extends StatefulWidget {
  final String orderId;
  const QrisPage({super.key, required this.orderId});

  @override
  State<QrisPage> createState() => _QrisPageState();
}

class _QrisPageState extends State<QrisPage> {
  String? _qrisImageUrl;
  String? _paymentId;
  File? _proofImage;
  bool _isLoading = false;
  bool _uploaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Get QRIS image URL from settings
      final setting = await supabase
          .from('settings')
          .select('value')
          .eq('key', 'qris_image_url')
          .maybeSingle();
      if (setting != null) {
        _qrisImageUrl = setting['value'] as String?;
      }

      // Get payment record for this order
      final paymentData = await supabase
          .from('payments')
          .select('id')
          .eq('order_id', widget.orderId)
          .eq('method', 'manual_qris')
          .maybeSingle();
      if (paymentData != null) {
        _paymentId = paymentData['id'] as String?;
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  Future<void> _upload() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih foto bukti pembayaran terlebih dahulu')),
      );
      return;
    }
    if (_paymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pembayaran tidak ditemukan')),
      );
      return;
    }

    final provider = context.read<CustomerProvider>();
    final ok = await provider.uploadPaymentProof(
        widget.orderId, _paymentId!, _proofImage!);

    if (!mounted) return;
    if (ok) {
      setState(() => _uploaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bukti pembayaran berhasil dikirim!'),
            backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Gagal mengunggah bukti'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran QRIS'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_uploaded) ...[
                    const SizedBox(height: 20),
                    const Icon(Icons.check_circle,
                        size: 80, color: AppColors.success),
                    const SizedBox(height: 16),
                    const Text(
                      'Bukti Pembayaran Terkirim',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pembayaran Anda sedang diverifikasi oleh admin.\nHarap tunggu konfirmasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      onPressed: () => context.go('/customer/home'),
                      label: 'Kembali ke Beranda',
                    ),
                  ] else ...[
                    const Text(
                      'Scan QR Code di bawah ini',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Setelah membayar, upload bukti pembayaran',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _qrisImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _qrisImageUrl!,
                                width: 240,
                                height: 240,
                                fit: BoxFit.contain,
                                placeholder: (ctx, url) => const SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (ctx, url, err) => const SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Icon(Icons.qr_code,
                                      size: 120, color: Colors.grey),
                                ),
                              )
                            : const SizedBox(
                                width: 240,
                                height: 240,
                                child: Icon(Icons.qr_code,
                                    size: 120, color: Colors.grey),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Petunjuk Pembayaran:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('1. Buka aplikasi mobile banking atau e-wallet Anda'),
                          Text('2. Pilih fitur Scan QR / QRIS'),
                          Text('3. Scan QR Code di atas'),
                          Text('4. Konfirmasi pembayaran'),
                          Text('5. Screenshot bukti pembayaran'),
                          Text('6. Upload bukti di bawah ini'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Upload Bukti Pembayaran',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              style: BorderStyle.solid),
                        ),
                        child: _proofImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_proofImage!,
                                    fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('Ketuk untuk memilih foto',
                                      style: TextStyle(
                                          color: Colors.grey[600])),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      onPressed: _upload,
                      label: 'Kirim Bukti Pembayaran',
                      isLoading: provider.isLoading,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
