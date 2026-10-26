import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin.dart';
import 'api.dart';
import 'Login_Screen.dart';

// Доверие к SSL-сертификату сервера карт (порт 1443)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => host == 'map.99993.ru';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await Api.loadSession(); // достаём сохранённый токен
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const AuthGate(),
    );
  }
}

// Решает при запуске: показать вход или сразу админку
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<_GateResult> _check;

  @override
  void initState() {
    super.initState();
    _check = _verify();
  }

  Future<_GateResult> _verify() async {
    if (Api.token == null) return _GateResult.login;
    try {
      final r = await http
          .get(Uri.parse('${Api.baseUrl}/api/admin/me'), headers: Api.headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final admin = body['admin'] as Map<String, dynamic>;
        Api.adminName = (admin['name'] ?? Api.adminName ?? 'Admin').toString();
        return _GateResult.home;
      }
      if (r.statusCode == 401 || r.statusCode == 403) {
        await Api.clearSession(); // токен просрочен или недействителен
        return _GateResult.login;
      }
      return _GateResult.offline;
    } catch (_) {
      return _GateResult.offline; // нет связи: токен не трогаем
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateResult>(
      future: _check,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        switch (snap.data!) {
          case _GateResult.home:
            return AdminHome(adminName: Api.adminName ?? 'Admin');
          case _GateResult.login:
            return const LoginScreen();
          case _GateResult.offline:
            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text('Нет связи с сервером',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _check = _verify()),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

enum _GateResult { home, login, offline }