import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/order_timeline.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  OrderModel? _order;
  List<Map<String, dynamic>> _statusHistory = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  String _displayOrderStatus(OrderModel order) {
    if (order.status == 'waiting_payment' &&
        order.paymentStatus == 'waiting_verification') {
      return 'waiting_verification';
    }
    return order.status;
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) => _loadOrder(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_status_histories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (_) => _loadOrder(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (_) => _loadOrder(),
        )
        .subscribe();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('orders')
          .select('*, order_items(*), payments(*)')
          .eq('id', widget.orderId)
          .single();
      final history = await supabase
          .from('order_status_histories')
          .select()
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: false);

      setState(() {
        _order = OrderModel.fromJson(data);
        _statusHistory = (history as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context.read<CustomerProvider>().cancelOrder(
      widget.orderId,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil dibatalkan'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadOrder();
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
    final canPay =
        order.paymentStatus == 'pending' &&
        (order.status == 'waiting_payment' ||
            (order.status == 'created' && order.orderType == 'satuan'));
    final canCancel =
        order.status == 'created' && order.paymentStatus == 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrder),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrder,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order info card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.orderCode,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order.orderType == 'kiloan'
                                      ? 'Laundry Kiloan'
                                      : order.orderType == 'satuan'
                                          ? 'Laundry Satuan'
                                          : 'Laundry Campuran',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatTanggalIndo(order.createdAt),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: _displayOrderStatus(order)),
                        ],
                      ),
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const Divider(height: 24),
                        _infoRow('Catatan', order.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Items
              if (order.orderItems.isNotEmpty) ...[
                const Text(
                  'Item Pesanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: order.orderItems.map((item) {
                      return ListTile(
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
                ),
                const SizedBox(height: 12),
              ],

              // Payment summary
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
                        'Ringkasan Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20),
                      _summaryRow('Subtotal', formatRupiah(order.subtotal)),
                      _summaryRow('Ongkir', formatRupiah(order.deliveryFee)),
                      if (order.discountAmount > 0)
                        _summaryRow(
                          'Diskon',
                          '- ${formatRupiah(order.discountAmount)}',
                        ),
                      const Divider(),
                      _summaryRow(
                        'Total',
                        formatRupiah(order.totalAmount),
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Status Pembayaran: '),
                          StatusBadge(status: order.paymentStatus),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Status history
              if (_statusHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Riwayat Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: OrderTimeline(history: _statusHistory),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              if (canPay)
                AppButton(
                  onPressed: () =>
                      context.push('/customer/payment/${order.id}'),
                  label: 'Bayar Sekarang',
                  color: AppColors.success,
                ),
              if (canCancel) ...[
                if (canPay) const SizedBox(height: 12),
                AppButton(
                  onPressed: _cancelOrder,
                  label: 'Batalkan Pesanan',
                  isOutlined: true,
                  color: AppColors.error,
                ),
              ],
              if (canPay || canCancel) const SizedBox(height: 12),
              AppButton(
                onPressed: () => _showHelpDialog(order.orderCode),
                label: 'Butuh Bantuan?',
                isOutlined: true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(String orderCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Butuh Bantuan?'),
        content: Text(
          'Hubungi admin Premier Laundry melalui toko untuk bantuan terkait pesanan $orderCode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
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
