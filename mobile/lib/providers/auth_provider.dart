import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/user.dart";
import "../services/api_service.dart";

/// Drzi stanje prijave: token + trenutni korisnik.
/// Token se cuva u SharedPreferences da prijava preživi restart aplikacije.
class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider(this._api);

  UserDto? _user;
  String? _token;
  bool _loading = false;

  UserDto? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get loading => _loading;

  static const _tokenKey = "auth_token";

  /// Poziva se na startu - vraca token iz memorije ako postoji.
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
      // Token istekao ili nevazeci - odjavi.
      await logout();
    }
  }

  Future<void> login(String username, String password) async {
    _setLoading(true);
    try {
      final res = await _api.login(username, password);
      await _applyAuth(res);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(Map<String, dynamic> body) async {
    _setLoading(true);
    try {
      final res = await _api.register(body);
      await _applyAuth(res);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    // Prvo javi serveru da invalidira token (uputa 5). Ako poziv padne (npr. token
    // vec istekao), svejedno nastavi sa lokalnim ciscenjem.
    try {
      if (_token != null) await _api.logout();
    } catch (_) {
      // ignorisi - lokalnu odjavu ionako radimo ispod
    }
    _token = null;
    _user = null;
    _api.client.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  /// Osvjezi podatke trenutnog korisnika sa servera (nakon izmjene profila).
  Future<void> refreshUser() async {
    _user = await _api.getProfile();
    notifyListeners();
  }

  Future<void> _applyAuth(AuthResponse res) async {
    _token = res.token;
    _user = res.user;
    _api.client.setToken(res.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, res.token);
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
