import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';

class PaymentPage extends StatefulWidget {
  final String orderId;
  const PaymentPage({super.key, required this.orderId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  OrderModel? _order;
  bool _isLoading = true;
  final _voucherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*), payments(*)')
          .eq('id', widget.orderId)
          .single();
      setState(() {
        _order = OrderModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payWithQris() async {
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final provider = context.read<CustomerProvider>();

    final paymentId = await provider.createPayment(
      orderId: widget.orderId,
      customerId: userId,
      method: 'manual_qris',
      amount: _order?.totalAmount ?? 0,
    );

    if (!mounted) return;
    if (paymentId != null) {
      context.push('/customer/payment/qris/${widget.orderId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Gagal membuat pembayaran'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _payWithXendit() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final response = await Supabase.instance.client.functions.invoke(
        'create-xendit-invoice',
        body: {
          'orderId': widget.orderId,
          'amount': _order?.totalAmount ?? 0,
          'customerName': auth.profile?.name ?? 'Customer',
          'customerEmail': auth.currentUser?.email ?? '',
        },
      );

      final paymentUrl = response.data?['invoiceUrl'] as String?;
      if (paymentUrl != null) {
        final uri = Uri.parse(paymentUrl);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal membuka halaman pembayaran: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Pesanan tidak ditemukan')),
      );
    }

    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order!.orderCode,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Pembayaran',
                            style: TextStyle(fontSize: 15)),
                        Text(
                          formatRupiah(_order!.totalAmount),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Pilih Metode Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _paymentMethodCard(
              icon: Icons.qr_code,
              title: 'QRIS Manual',
              subtitle: 'Scan QRIS dan upload bukti pembayaran',
              onTap: _payWithQris,
              isLoading: provider.isLoading,
            ),
            const SizedBox(height: 10),
            _paymentMethodCard(
              icon: Icons.payment,
              title: 'Xendit',
              subtitle: 'Bayar via transfer bank, e-wallet, kartu kredit',
              onTap: _payWithXendit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _voucherController,
              decoration: InputDecoration(
                labelText: 'Kode Voucher (opsional)',
                prefixIcon: const Icon(Icons.card_giftcard),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: TextButton(
                  onPressed: () {},
                  child: const Text('Pakai'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: isLoading ? null : onTap,
      ),
    );
  }
}
