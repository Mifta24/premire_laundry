import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/courier_task_model.dart';

class CourierProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<CourierTaskModel> _pickupTasks = [];
  List<CourierTaskModel> _deliveryTasks = [];
  bool _isLoading = false;
  String? _error;

  List<CourierTaskModel> get pickupTasks => _pickupTasks;
  List<CourierTaskModel> get deliveryTasks => _deliveryTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
          .select(
              '*, orders(order_code, notes, profiles(name), addresses(address_text, latitude, longitude))')
          .eq('courier_id', courierId)
          .not('status', 'in', '(completed,cancelled)')
          .order('assigned_at', ascending: false);

      final tasks = (data as List<dynamic>)
          .map((t) => CourierTaskModel.fromJson(t as Map<String, dynamic>))
          .toList();

      _pickupTasks = tasks.where((t) => t.taskType == 'pickup').toList();
      _deliveryTasks = tasks.where((t) => t.taskType == 'delivery').toList();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateTaskStatus(
      String taskId, String status, String taskType, String orderId) async {
    _setLoading(true);
    _setError(null);
    try {
      final updateData = <String, dynamic>{'status': status};
      if (status == 'completed' || status == 'delivered') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('courier_tasks')
          .update(updateData)
          .eq('id', taskId);

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
            .update({'status': orderStatus}).eq('id', orderId);

        await _supabase.from('order_status_histories').insert({
          'order_id': orderId,
          'status': orderStatus,
          'changed_by': _supabase.auth.currentUser?.id,
          'note': 'Diperbarui oleh kurir',
        });
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
          .select(
              '*, orders(order_code, notes, profiles(name), addresses(address_text, latitude, longitude))')
          .eq('id', taskId)
          .single();
      return CourierTaskModel.fromJson(data);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }
}
