import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class AdminRequestsScreen extends StatefulWidget {
  final String currentAdminName;

  const AdminRequestsScreen({super.key, required this.currentAdminName});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- СЕРВЕР ----------
  String _errText(http.Response r) {
    String msg = 'Ошибка сервера (${r.statusCode})';
    try {
      final b = jsonDecode(r.body);
      if (b is Map && b['error'] != null) msg = b['error'].toString();
    } catch (_) {}
    return msg;
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) setState(() => _loading = true);
    try {
      final r = await http
          .get(Uri.parse('${Api.baseUrl}/api/admin/requests'), headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(_errText(r));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (body['requests'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // Возвращает null при успехе или текст ошибки
  Future<String?> _post(String path, [Map<String, dynamic>? body]) async {
    try {
      final r = await http
          .post(Uri.parse('${Api.baseUrl}$path'),
          headers: Api.headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return _errText(r);
      return null;
    } catch (e) {
      return 'Нет связи с сервером: $e';
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF0F172A),
    ));
  }

  String _randomPassword() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ---------- ЭКРАН ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            const Text(
              'РАССМОТРЕНИЕ ЗАЯВОК',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: Colors.white),
            ),
            Text('Админ: ${widget.currentAdminName}',
                style: const TextStyle(color: Colors.white60, fontSize: 9)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => _load()),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
    }
    if (_error != null && _requests.isEmpty) return _buildErrorState(_error!);
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: _requests.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          _buildEmptyState(),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _buildRequestCard(context, _requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> data) {
    final logo = (data['logo_url'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(15),
            image: logo.isNotEmpty
                ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                : null,
          ),
          child: logo.isEmpty ? const Icon(Icons.storefront, color: Color(0xFF64748B)) : null,
        ),
        title: Text(
          (data['name'] ?? 'Без названия').toString(),
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            (data['phone'] ?? 'Телефон не указан').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
        onTap: () => _showDetails(context, data),
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final logo = (data['logo_url'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10))
                        ],
                        image: logo.isNotEmpty
                            ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                            : null,
                      ),
                      child: logo.isEmpty ? const Icon(Icons.store, size: 50) : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    (data['name'] ?? 'Заявка').toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 32),
                  _detailItem(Icons.alternate_email_rounded, 'Контакт (логин по умолчанию)',
                      (data['login'] ?? 'Не указан').toString()),
                  _detailItem(Icons.phone_android_rounded, 'Телефон',
                      (data['phone'] ?? 'Не указан').toString()),
                  if (data['lat'] != null && data['lng'] != null)
                    _detailItem(Icons.location_on_rounded, 'Координаты',
                        '${(data['lat'] as num).toStringAsFixed(5)}, ${(data['lng'] as num).toStringAsFixed(5)}'),
                  _detailItem(Icons.access_time_filled_rounded, 'Время работы',
                      (data['time'] ?? 'Не указано').toString()),
                  _detailItem(Icons.category_rounded, 'Категория',
                      (data['category'] ?? 'Не указана').toString()),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton('ОТКЛОНИТЬ', Colors.redAccent, () async {
                          Navigator.pop(sheetCtx);
                          await _reject(data);
                        }),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _actionButton('ОДОБРИТЬ', const Color(0xFF0F172A), () {
                          Navigator.pop(sheetCtx);
                          _showCredentialsDialog(data);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Отклонить заявку?'),
        content: const Text('Заявка будет удалена. Заведение сможет подать новую.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Нет')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Отклонить', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ??
        false;
    if (!ok) return;
    final err = await _post('/api/admin/requests/${data['id']}/reject');
    if (err != null) {
      _snack(err, error: true);
    } else {
      _snack('Заявка отклонена', error: true);
      _load(spinner: false);
    }
  }

  void _showCredentialsDialog(Map<String, dynamic> data) {
    final loginController = TextEditingController(text: (data['login'] ?? '').toString());
    final passwordController = TextEditingController(text: _randomPassword());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выдача доступа', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: loginController,
              decoration: const InputDecoration(
                labelText: 'Логин (login)',
                hintText: 'Например: buket_md',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Пароль (password)',
                helperText: 'Запишите его: потом он не показывается',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('ОТМЕНА')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
            onPressed: () async {
              final login = loginController.text.trim();
              final pass = passwordController.text.trim();
              if (login.isEmpty || pass.isEmpty) {
                _snack('Заполните логин и пароль', error: true);
                return;
              }
              final err = await _post('/api/admin/requests/${data['id']}/approve',
                  {'login': login, 'password': pass});
              if (err != null) {
                _snack(err, error: true); // диалог остаётся открытым
                return;
              }
              if (dctx.mounted) Navigator.pop(dctx);
              _snack('Заведение создано! Логин: $login, пароль: $pass');
              _load(spinner: false);
            },
            child: const Text('СОХРАНИТЬ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: const Color(0xFF475569), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String title, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('Очередь пуста',
              style: TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Потяните вниз или нажмите обновить', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Ошибка связи с сервером',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            TextButton(onPressed: () => _load(), child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}