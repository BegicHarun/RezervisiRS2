import "dart:async";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/core.dart";
import "../services/api_service.dart";

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider(this._api) {
    _api.client.onUnauthorized = () => unawaited(_clearSession());
  }

  bool _hasDesktopRole(UserDto user) =>
      user.roles.contains("Administrator") || user.roles.contains("Frizer");

  UserDto? _user;
  String? _token;
  bool _loading = false;

  UserDto? get user => _user;
  bool get isLoggedIn => _token != null;
  bool get loading => _loading;

  static const _tokenKey = "desktop_auth_token";

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return;
    _token = token;
    _api.client.setToken(token);
    try {
      final user = await _api.getProfile();
      if (!_hasDesktopRole(user)) {
        await logout();
        return;
      }
      _user = user;
      notifyListeners();
    } catch (_) {
      await _clearSession();
    }
  }

  Future<void> login(String username, String password) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.login(username, password);
      // Desktop je za admina i frizera - klijent nema pristup.
      if (!_hasDesktopRole(res.user)) {
        throw Exception("Ovaj nalog nema pristup desktop aplikaciji.");
      }
      _token = res.token;
      _user = res.user;
      _api.client.setToken(res.token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, res.token);
      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_token == null) return;
    await _api.logout();
    await _clearSession();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _api.client.setToken(null);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
