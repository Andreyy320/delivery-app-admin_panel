import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static const String baseUrl = 'http://194.156.66.100:3100';
  static String? token;
  static String? adminName;

  static const _kToken = 'admin_token';
  static const _kName = 'admin_name';

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // Прочитать сохранённый вход при запуске приложения
  static Future<void> loadSession() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    adminName = p.getString(_kName);
  }

  // Запомнить вход после успешного логина
  static Future<void> saveSession(String newToken, String name) async {
    token = newToken;
    adminName = name;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, newToken);
    await p.setString(_kName, name);
  }

  // Выход или просроченный токен
  static Future<void> clearSession() async {
    token = null;
    adminName = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kName);
  }
}