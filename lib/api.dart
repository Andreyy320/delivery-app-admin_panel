import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Api {
  static const String baseUrl = 'http://194.156.66.100:3100';
  static String? token;
  static String? adminName;

  static const _kToken = 'admin_token';
  static const _kName = 'admin_name';
  static const _s = FlutterSecureStorage();

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<void> loadSession() async {
    token = await _s.read(key: _kToken);
    adminName = await _s.read(key: _kName);
  }

  static Future<void> saveSession(String newToken, String name) async {
    token = newToken;
    adminName = name;
    await _s.write(key: _kToken, value: newToken);
    await _s.write(key: _kName, value: name);
  }

  // Отзывает токен на сервере, потом стирает локально
  static Future<void> logout() async {
    try {
      await http
          .post(Uri.parse('$baseUrl/api/admin/logout'), headers: headers)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await clearSession();
  }

  static Future<void> clearSession() async {
    token = null;
    adminName = null;
    await _s.delete(key: _kToken);
    await _s.delete(key: _kName);
  }
}