import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Wraps [AuthService] and exposes the current auth state / user so
/// screens can react to login/logout without prop-drilling.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? lastError;

  /// Set by the app root to send the user back to the login screen when the
  /// session can no longer be refreshed.
  VoidCallback? onForcedLogout;

  AuthProvider() {
    ApiClient.onSessionExpired = _handleSessionExpired;
  }

  void _handleSessionExpired() {
    // During bootstrap (status unknown) the start screen routes by itself.
    if (status != AuthStatus.authenticated) return;
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
    onForcedLogout?.call();
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Called on app start to decide whether to route to Home or
  /// Onboarding, based on stored tokens (and best-effort /me/ refresh).
  Future<void> bootstrap() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      currentUser = await _authService.me();
      status = AuthStatus.authenticated;
    } catch (_) {
      // ApiClient already tried to refresh the access token; if /me/ still
      // fails the session is gone (or the server is unreachable) — treat as
      // logged out.
      await TokenStorage.clear();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    lastError = null;
    try {
      currentUser = await _authService.login(email: email, password: password);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    lastError = null;
    try {
      currentUser = await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    lastError = null;
    try {
      await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }
}
