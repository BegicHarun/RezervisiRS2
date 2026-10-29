import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/core.dart";
import "../services/api_service.dart";

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider(this._api);

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
      _user = await _api.getProfile();
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.login(username, password);
      // Desktop je za admina i frizera - klijent nema pristup.
      if (!res.user.roles.contains("Administrator") &&
          !res.user.roles.contains("Frizer")) {
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
    _token = null;
    _user = null;
    _api.client.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
