import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? _currentUser;
  ProfileModel? _profile;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    _setLoading(true);
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _currentUser = session.user;
        await loadProfile();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _currentUser = response.user;
      if (_currentUser != null) {
        await loadProfile();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan. Silakan coba lagi.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'phone': phone, 'role': 'customer'},
      );
      _currentUser = response.user;
      if (_currentUser != null) {
        await loadProfile();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan. Silakan coba lagi.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _profile = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProfile() async {
    try {
      if (_currentUser == null) return;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', _currentUser!.id)
          .single();
      _profile = ProfileModel.fromJson(data);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> updateProfile(String name, String phone) async {
    _setLoading(true);
    _setError(null);
    try {
      if (_currentUser == null) return false;
      await _supabase
          .from('profiles')
          .update({'name': name, 'phone': phone})
          .eq('user_id', _currentUser!.id);
      await loadProfile();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
