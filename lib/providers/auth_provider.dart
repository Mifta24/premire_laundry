import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/error_message_formatter.dart';
import '../core/services/notification_service.dart';
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
    _isLoading = true; // silent — no notifyListeners until state is ready
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _currentUser = session.user;
        await loadProfile();
      }
    } catch (e) {
      _error = friendlyErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
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
        await NotificationService().saveTokenToSupabase(_currentUser!.id);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(friendlyAuthErrorMessage(e.message));
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
        await NotificationService().saveTokenToSupabase(_currentUser!.id);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(friendlyAuthErrorMessage(e.message));
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
      if (_currentUser != null) {
        await NotificationService().deactivateToken(_currentUser!.id);
      }
      await _supabase.auth.signOut();
      _currentUser = null;
      _profile = null;
      notifyListeners();
    } catch (e) {
      _setError(friendlyErrorMessage(e));
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
      _setError(friendlyErrorMessage(e));
    }
  }

  @override
  String toString() =>
      'AuthProvider(isAuthenticated: $isAuthenticated, role: ${_profile?.role}, isLoading: $_isLoading, error: $_error)';

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
      _setError(friendlyErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAvailability(bool isAvailable) async {
    if (_currentUser == null) return false;
    try {
      await _supabase
          .from('profiles')
          .update({'is_available': isAvailable})
          .eq('user_id', _currentUser!.id);
      if (_profile != null) {
        _profile = _profile!.copyWith(isAvailable: isAvailable);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(friendlyErrorMessage(e));
      return false;
    }
  }

  Future<bool> updateAvatar(String url) async {
    if (_currentUser == null) return false;
    try {
      await _supabase
          .from('profiles')
          .update({'avatar_url': url})
          .eq('user_id', _currentUser!.id);
      if (_profile != null) {
        _profile = _profile!.copyWith(avatarUrl: url);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(friendlyErrorMessage(e));
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'premierlaundry://reset-password',
      );
      return true;
    } on AuthException catch (e) {
      _setError(friendlyAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan. Silakan coba lagi.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateRecoveredPassword(String newPassword) async {
    _setLoading(true);
    _setError(null);
    try {
      if (_supabase.auth.currentSession == null) {
        _setError('Link reset password tidak valid atau sudah kedaluwarsa.');
        return false;
      }

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      await _supabase.auth.signOut();
      _currentUser = null;
      _profile = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _setError(friendlyAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan. Silakan coba lagi.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final email = _currentUser?.email;
      if (email == null) {
        _setError('Sesi tidak valid');
        return false;
      }
      // Verifikasi password saat ini sebelum mengganti.
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      _setError(friendlyAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan. Silakan coba lagi.');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
