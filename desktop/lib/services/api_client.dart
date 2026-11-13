import "dart:convert";
import "dart:typed_data";
import "package:http/http.dart" as http;
import "config.dart";

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String> errors;
  ApiException(this.statusCode, this.message, [this.errors = const []]);
  @override
  String toString() => message;
}

class ApiClient {
  String? _token;
  void Function()? onUnauthorized;
  void setToken(String? t) => _token = t;
  String? get token => _token;

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        if (_token != null) "Authorization": "Bearer $_token",
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse("${AppConfig.baseUrl}$path");
    if (query == null) return base;
    final qp = <String, String>{};
    query.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    return base.replace(queryParameters: {...base.queryParameters, ...qp});
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      _handle(await http
          .get(_uri(path, query), headers: _headers)
          .timeout(const Duration(seconds: 15)));

  Future<dynamic> post(String path, {Object? body}) async => _handle(await http
      .post(_uri(path),
          headers: _headers, body: body == null ? null : jsonEncode(body))
      .timeout(const Duration(seconds: 15)));

  Future<dynamic> put(String path, {Object? body}) async => _handle(await http
      .put(_uri(path),
          headers: _headers, body: body == null ? null : jsonEncode(body))
      .timeout(const Duration(seconds: 15)));

  Future<void> delete(String path) async => _handle(await http
      .delete(_uri(path), headers: _headers)
      .timeout(const Duration(seconds: 15)));

  /// Za PDF izvjestaje - vraca sirove bajtove.
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    final res = await http
        .get(_uri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    _handle(res);
    throw StateError("PDF odgovor nije dostupan.");
  }

  dynamic _handle(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    dynamic parsed;
    if (res.body.isNotEmpty) {
      try {
        parsed = jsonDecode(res.body);
      } catch (_) {
        parsed = null;
      }
    }
    if (ok) return parsed;

    if (res.statusCode == 401 && _token != null) onUnauthorized?.call();
    String message = "Doslo je do greske (${res.statusCode}).";
    List<String> errors = [];
    if (parsed is Map) {
      if (parsed["message"] != null) message = parsed["message"].toString();
      if (parsed["errors"] is List) {
        errors = (parsed["errors"] as List).map((e) => e.toString()).toList();
      } else if (parsed["errors"] is Map) {
        errors = (parsed["errors"] as Map)
            .values
            .expand((value) => value is List ? value : [value])
            .map((value) => value.toString())
            .toList();
      }
    }
    if (errors.isNotEmpty) message = errors.join("\n");
    throw ApiException(res.statusCode, message, errors);
  }
}
