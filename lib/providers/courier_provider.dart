import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/courier_task_model.dart';

class CourierProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  static const _taskSelect =
      '*, orders(order_code, order_type, total_amount, notes, customer_id, address_id, addresses(address_text, notes, latitude, longitude))';

  List<CourierTaskModel> _pickupTasks = [];
  List<CourierTaskModel> _deliveryTasks = [];
  List<CourierTaskModel> _history = [];
  bool _isLoading = false;
  bool _isHistoryLoading = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _subscribedCourierId;

  List<CourierTaskModel> get pickupTasks => _pickupTasks;
  List<CourierTaskModel> get deliveryTasks => _deliveryTasks;
  List<CourierTaskModel> get history => _history;
  bool get isLoading => _isLoading;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get error => _error;

  int get activePickupCount =>
      _pickupTasks.where((t) => t.status != 'picked_up').length;
  int get activeDeliveryCount =>
      _deliveryTasks.where((t) => t.status != 'delivered').length;

  int get completedTodayCount {
    final now = DateTime.now();
    return _history.where((t) {
      final c = t.completedAt;
      return c != null &&
          c.year == now.year &&
          c.month == now.month &&
          c.day == now.day;
    }).length;
  }

  int get completedThisWeekCount => historyWithinDays(7).length;

  List<CourierTaskModel> historyWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _history.where((t) {
      final c = t.completedAt;
      return c != null && c.isAfter(cutoff);
    }).toList();
  }

  List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item,
    ];
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadTasks(String courierId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _supabase
          .from('courier_tasks')
          .select(_taskSelect)
          .eq('courier_id', courierId)
          .not('status', 'in', '(completed,cancelled)')
          .order('assigned_at', ascending: false);

      final tasks = await _buildTasksWithCustomerNames(data as List<dynamic>);
      final uniqueTasks = _uniqueBy(tasks, (task) => task.id);

      _pickupTasks = uniqueTasks.where((t) => t.taskType == 'pickup').toList();
      _deliveryTasks = uniqueTasks
          .where((t) => t.taskType == 'delivery')
          .toList();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTaskHistory(String courierId) async {
    _isHistoryLoading = true;
    notifyListeners();
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final data = await _supabase
          .from('courier_tasks')
          .select(_taskSelect)
          .eq('courier_id', courierId)
          .inFilter('status', ['picked_up', 'delivered'])
          .gte('completed_at', cutoff.toIso8601String())
          .order('completed_at', ascending: false);

      final tasks = await _buildTasksWithCustomerNames(data as List<dynamic>);
      _history = _uniqueBy(tasks, (task) => task.id);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<List<CourierTaskModel>> _buildTasksWithCustomerNames(
    List<dynamic> data,
  ) async {
    // Collect unique customer IDs from orders
    final customerIds = data
        .map((t) => (t['orders'] as Map<String, dynamic>?)?['customer_id'])
        .whereType<String>()
        .toSet()
        .toList();

    // Fetch profiles for those customer IDs
    final Map<String, Map<String, String?>> customerProfiles = {};
    if (customerIds.isNotEmpty) {
      final profiles = await _supabase
          .from('profiles')
          .select('user_id, name, phone')
          .inFilter('user_id', customerIds);
      for (final p in profiles as List<dynamic>) {
        final uid = p['user_id'] as String?;
        if (uid != null) {
          customerProfiles[uid] = {
            'name': p['name'] as String?,
            'phone': p['phone'] as String?,
          };
        }
      }
    }

    // Inject profile names into the order map before parsing
    return data.map((t) {
      final raw = Map<String, dynamic>.from(t as Map<String, dynamic>);
      final order = raw['orders'] as Map<String, dynamic>?;
      if (order != null) {
        final customerId = order['customer_id'] as String?;
        if (customerId != null && customerProfiles.containsKey(customerId)) {
          final orderCopy = Map<String, dynamic>.from(order);
          orderCopy['profiles'] = customerProfiles[customerId];
          raw['orders'] = orderCopy;
        }
      }
      return CourierTaskModel.fromJson(raw);
    }).toList();
  }

  void subscribeToRealtime(String courierId) {
    if (_subscribedCourierId == courierId) return;
    _channel?.unsubscribe();
    _subscribedCourierId = courierId;
    _channel = _supabase
        .channel('courier_tasks_$courierId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'courier_tasks',
          callback: (_) => loadTasks(courierId),
        )
        .subscribe();
  }

  void unsubscribeFromRealtime() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribedCourierId = null;
  }

  Future<bool> updateTaskStatus(
    String taskId,
    String status,
    String taskType,
    String orderId,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final order = await _supabase
          .from('orders')
          .select('status')
          .eq('id', orderId)
          .single();
      if (order['status'] == 'cancelled') {
        _setError('Pesanan ini sudah dibatalkan');
        return false;
      }

      final updateData = <String, dynamic>{'status': status};
      if (status == 'completed' || status == 'delivered') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('courier_tasks').update(updateData).eq('id', taskId);

      // Map task status to order status
      String? orderStatus;
      if (taskType == 'pickup') {
        if (status == 'on_the_way') {
          orderStatus = 'waiting_pickup';
        } else if (status == 'picked_up') {
          orderStatus = 'picked_up';
        }
      } else if (taskType == 'delivery') {
        if (status == 'on_the_way') {
          orderStatus = 'out_for_delivery';
        } else if (status == 'delivered') {
          orderStatus = 'completed';
        }
      }

      if (orderStatus == 'completed') {
        // Edge function ini juga menambah loyalty points & men-generate
        // voucher gratis tiap 10 order selesai, jadi delivery completion
        // harus lewat sini, bukan update status langsung.
        try {
          await _supabase.functions.invoke(
            'complete-order-generate-loyalty',
            body: {'orderId': orderId},
          );
        } catch (e) {
          // Tetap pindahkan status order meski pemrosesan loyalty gagal,
          // supaya order tidak nyangkut di status sebelumnya.
          await _supabase
              .from('orders')
              .update({'status': orderStatus})
              .eq('id', orderId);
        }
      } else if (orderStatus != null) {
        await _supabase
            .from('orders')
            .update({'status': orderStatus})
            .eq('id', orderId);
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<CourierTaskModel?> getTaskById(String taskId) async {
    try {
      final data = await _supabase
          .from('courier_tasks')
          .select(_taskSelect)
          .eq('id', taskId)
          .single();

      final tasks = await _buildTasksWithCustomerNames([data]);
      return tasks.isNotEmpty ? tasks.first : null;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
