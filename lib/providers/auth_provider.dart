import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();

  User? _user;
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  // Analysis limit helpers
  bool get canPerformAnalysis => _profile?.canPerformAnalysis ?? false;
  int get remainingAnalyses => _profile?.remainingAnalyses ?? 0;
  String get subscriptionTier => _profile?.subscriptionTier ?? 'free';

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await _loadProfile();
      } else {
        _profile = null;
      }
      _isLoading = false;
      notifyListeners();
    });

    final session = _supabase.auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      await _loadProfile();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await _supabaseService.getProfile();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

      if (response.user != null) {
        _user = response.user;
        await _loadProfile();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Registrierung fehlgeschlagen';
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _error = _translateAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _user = response.user;
        await _loadProfile();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Anmeldung fehlgeschlagen';
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _error = _translateAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      // Always clear local state, even if network request fails
      _user = null;
      _profile = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _error = null;
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _error = _translateAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
    notifyListeners();
  }

  Future<bool> updateDisplayName(String newName) async {
    try {
      _error = null;
      await _supabaseService.updateProfile(displayName: newName);
      await _loadProfile();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Name konnte nicht aktualisiert werden';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    try {
      _error = null;
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _error = _translateAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _translateAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Ungueltige E-Mail oder Passwort';
    }
    if (message.contains('Email not confirmed')) {
      return 'Bitte bestaetigen Sie Ihre E-Mail-Adresse';
    }
    if (message.contains('User already registered')) {
      return 'Diese E-Mail-Adresse ist bereits registriert';
    }
    if (message.contains('Password should be at least')) {
      return 'Das Passwort muss mindestens 6 Zeichen lang sein';
    }
    if (message.contains('Invalid email')) {
      return 'Bitte geben Sie eine gueltige E-Mail-Adresse ein';
    }
    return message;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
