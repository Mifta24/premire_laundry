import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/courier_task_model.dart';

class CourierProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  static const _taskSelect =
      '*, orders(order_code, notes, customer_id, address_id, addresses(address_text, latitude, longitude))';

  List<CourierTaskModel> _pickupTasks = [];
  List<CourierTaskModel> _deliveryTasks = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _subscribedCourierId;

  List<CourierTaskModel> get pickupTasks => _pickupTasks;
  List<CourierTaskModel> get deliveryTasks => _deliveryTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    final Map<String, String> customerNames = {};
    if (customerIds.isNotEmpty) {
      final profiles = await _supabase
          .from('profiles')
          .select('user_id, name')
          .inFilter('user_id', customerIds);
      for (final p in profiles as List<dynamic>) {
        final uid = p['user_id'] as String?;
        final name = p['name'] as String?;
        if (uid != null && name != null) customerNames[uid] = name;
      }
    }

    // Inject profile names into the order map before parsing
    return data.map((t) {
      final raw = Map<String, dynamic>.from(t as Map<String, dynamic>);
      final order = raw['orders'] as Map<String, dynamic>?;
      if (order != null) {
        final customerId = order['customer_id'] as String?;
        if (customerId != null && customerNames.containsKey(customerId)) {
          final orderCopy = Map<String, dynamic>.from(order);
          orderCopy['profiles'] = {'name': customerNames[customerId]};
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

      if (orderStatus != null) {
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
