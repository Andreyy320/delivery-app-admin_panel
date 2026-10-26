import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin.dart';
import 'api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);

  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final login = loginController.text.trim();
    final password = passwordController.text.trim();

    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите логин и пароль');
      return;
    }

    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
        Uri.parse('${Api.baseUrl}/api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': login, 'password': password}),
      )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        final admin = body['admin'] as Map<String, dynamic>;
        final adminName = (admin['name'] ?? login).toString();
        await Api.saveSession(body['token'] as String, adminName);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminHome(adminName: adminName)),
        );
      } else {
        setState(() => _error = body['error']?.toString() ?? 'Доступ запрещён');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Нет связи с сервером');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Вход',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Панель управления доставкой',
                      style: TextStyle(fontSize: 16, color: _muted),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: loginController,
                      enabled: !loading,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      style: const TextStyle(fontSize: 16, color: _ink),
                      decoration: _decoration('Логин'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      focusNode: _passwordFocus,
                      enabled: !loading,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => loading ? null : _login(),
                      style: const TextStyle(fontSize: 16, color: _ink),
                      decoration: _decoration(
                        'Пароль',
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _muted,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                        padding: const EdgeInsets.only(top: 14, left: 2),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFD64545),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          disabledBackgroundColor: _accent.withAlpha(130),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                            : const Text(
                          'Войти',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(_line),
      enabledBorder: border(_line),
      disabledBorder: border(_line),
      focusedBorder: border(_ink, 1.5),
    );
  }
}