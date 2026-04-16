import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'model_user.dart';
import 'api_client.dart';
import 'services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool       _loading         = false;
  String?    _error;
  bool       _mfaRequired     = false;
  String?    _mfaToken;
  bool       _needsOnboarding = false;

  UserModel? get user          => _user;
  bool get isLoading           => _loading;
  String? get error            => _error;
  bool get isAuthenticated     => _user != null;
  bool get mfaRequired         => _mfaRequired;
  String? get mfaToken         => _mfaToken;
  bool get needsOnboarding     => _needsOnboarding;

  void _set({bool? loading, String? error}) {
    if (loading != null) _loading = loading;
    _error = error;
    notifyListeners();
  }

  // ── Google Sign-In ──────────────────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _set(loading: true, error: null);
    try {
      String? idToken;

      if (kIsWeb) {
        // En web: signInWithPopup con Firebase Auth
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        // Forzar refresh=true para obtener un token fresco y válido
        idToken = await userCredential.user?.getIdToken(true);
      } else {
        // En móvil: flujo normal con google_sign_in
        final googleUser = await GoogleSignIn(
          clientId: '695071672432-5ol425us56ibi85tfmhjkavouc5cm3us.apps.googleusercontent.com',
          scopes: ['email'],
        ).signIn();
        if (googleUser == null) { _set(loading: false); return false; }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken:     googleAuth.idToken,
        );
        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
        idToken = await userCred.user?.getIdToken(true);
      }

      if (idToken == null) {
        _set(loading: false, error: 'No se pudo obtener el token de autenticación.');
        return false;
      }

      final data = await AuthService.loginWithGoogle(idToken);

      if (data['status'] == 200) {
        if (data['mfa_required'] == true) {
          _mfaRequired = true;
          _mfaToken    = data['mfa_token'];
          _set(loading: false);
          return true;
        }
        _user            = UserModel.fromApi(data['user']);
        _needsOnboarding = !(_user?.perfilCompleto ?? false);
        _set(loading: false);
        return true;
      }

      // Mostrar el error real del backend
      final errorMsg = data['error'] ?? data['detail'] ?? 'Error al iniciar sesión.';
      _set(loading: false, error: errorMsg.toString());
      return false;

    } on ApiException catch (e) {
      _set(loading: false, error: e.message);
      return false;
    } catch (e) {
      _set(loading: false, error: 'Error: ${e.toString()}');
      return false;
    }
  }

  // ── Verificar MFA ───────────────────────────────────────────────
  Future<bool> verificarMfa(String codigo) async {
    if (_mfaToken == null) return false;
    _set(loading: true, error: null);
    try {
      final data = await ApiClient.post('/api/v1/auth/mfa/verify/', body: {
        'mfa_token': _mfaToken,
        'codigo':    codigo,
      });
      _mfaRequired     = false;
      _mfaToken        = null;
      _user            = UserModel.fromApi(data['user']);
      _needsOnboarding = !(_user?.perfilCompleto ?? false);
      _set(loading: false);
      return true;
    } on ApiException catch (e) {
      _set(loading: false, error: e.message);
      return false;
    }
  }

  // ── Restaurar sesión ────────────────────────────────────────────
  Future<void> tryRestoreSession() async {
    final token = await AuthService.getAccessToken();
    if (token == null) return;
    try {
      final data = await ApiClient.get('/api/v1/auth/me/');
      _user            = UserModel.fromApi(data);
      _needsOnboarding = !(_user?.perfilCompleto ?? false);
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await AuthService.logout();
    } catch (_) {}
  }

  // ── Logout ──────────────────────────────────────────────────────
  Future<void> logout() async {
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    if (!kIsWeb) {
      try { await GoogleSignIn().signOut(); } catch (_) {}
    }
    await AuthService.logout();
    _user            = null;
    _needsOnboarding = false;
    _mfaRequired     = false;
    _mfaToken        = null;
    notifyListeners();
  }

  void onboardingCompleted(UserModel updated) {
    _user            = updated;
    _needsOnboarding = false;
    notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }

  // ── Login con Email/Contraseña ──────────────────────────────────
  Future<bool> loginWithEmail(String email, String password) async {
    _set(loading: true, error: null);
    try {
      final data = await AuthService.loginWithEmail(email, password);
      if ((data['status'] == 200) && data['access'] != null) {
        if (data['mfa_required'] == true) {
          _mfaRequired = true;
          _mfaToken    = data['mfa_token'];
          _set(loading: false);
          return true;
        }
        _user            = UserModel.fromApi(data['user']);
        _needsOnboarding = !(_user?.perfilCompleto ?? false);
        _set(loading: false);
        return true;
      }
      final msg = data['error'] ?? data['detail'] ?? 'Credenciales incorrectas.';
      _set(loading: false, error: msg.toString());
      return false;
    } on ApiException catch (e) {
      _set(loading: false, error: e.message);
      return false;
    } catch (e) {
      _set(loading: false, error: 'Error de conexión.');
      return false;
    }
  }

  // ── Registro con Email/Contraseña ───────────────────────────────
  Future<bool> registerWithEmail(
      String email, String password, String nombre) async {
    _set(loading: true, error: null);
    try {
      final data = await AuthService.register(email, password, nombre);
      final status = data['status'] as int;
      if ((status == 200 || status == 201) && data['access'] != null) {
        _user            = UserModel.fromApi(data['user']);
        _needsOnboarding = true;
        _set(loading: false);
        return true;
      }
      final msg = data['error'] ?? data['detail'] ??
          (data['email'] is List ? (data['email'] as List).first : null) ??
          'Error al crear la cuenta.';
      _set(loading: false, error: msg.toString());
      return false;
    } on ApiException catch (e) {
      _set(loading: false, error: e.message);
      return false;
    } catch (e) {
      _set(loading: false, error: 'Error de conexión.');
      return false;
    }
  }

  // ── Recuperación por SMS/Email ──────────────────────────────────
  Future<bool> requestPasswordReset(String email) async {
    _set(loading: true, error: null);
    try {
      final data = await AuthService.requestPasswordReset(email);
      _set(loading: false);
      if (data['status'] == 200) return true;
      final msg = data['error'] ?? data['detail'] ??
          'No se pudo enviar el código de recuperación.';
      _set(error: msg.toString());
      return false;
    } on ApiException catch (e) {
      _set(loading: false, error: e.message);
      return false;
    } catch (_) {
      _set(loading: false, error: 'Error de conexión.');
      return false;
    }
  }

  Future<bool> confirmPasswordReset(
      String email, String code, String newPassword) async {
    _set(loading: true, error: null);
    try {
      final data =
          await AuthService.confirmPasswordReset(email, code, newPassword);
      _set(loading: false);
      if (data['status'] == 200) return true;
      final msg = data['error'] ?? data['detail'] ?? 'Código inválido.';
      _set(error: msg.toString());
      return false;
    } on ApiException catch (e) {
      _set(loading: false, error: e.message);
      return false;
    } catch (_) {
      _set(loading: false, error: 'Error de conexión.');
      return false;
    }
  }
}
