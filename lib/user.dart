import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class UsersScreen extends StatefulWidget {
  final String currentAdminName;

  const UsersScreen({super.key, required this.currentAdminName});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String searchQuery = '';
  String filterType = 'all';
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ---------- СЕРВЕР ----------
  Never _fail(http.Response r) {
    String msg = 'Ошибка сервера (${r.statusCode})';
    try {
      final b = jsonDecode(r.body);
      if (b is Map && b['error'] != null) msg = b['error'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load({bool spinner = true}) async {
    if (spinner) setState(() => _loading = true);
    try {
      final r = await http
          .get(Uri.parse('${Api.baseUrl}/api/admin/people'), headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) _fail(r);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (body['people'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('${Api.baseUrl}$path');
    final enc = body == null ? null : jsonEncode(body);
    http.Response r;
    switch (method) {
      case 'POST':
        r = await http.post(uri, headers: Api.headers, body: enc);
        break;
      case 'PATCH':
        r = await http.patch(uri, headers: Api.headers, body: enc);
        break;
      default:
        r = await http.delete(uri, headers: Api.headers);
    }
    if (r.statusCode != 200 && r.statusCode != 201) _fail(r);
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF0F172A),
    ));
  }

  // ---------- ПОЛЯ ДЛЯ ДИАЛОГОВ ----------
  Widget _buildDialogField(TextEditingController controller, String label, IconData icon,
      {bool isPassword = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  // Телефон: если не начинается с «+», добавляем код страны
  String _normPhone(String raw) {
    final p = raw.trim();
    if (p.isEmpty) return '';
    return p.startsWith('+') ? p : '+373$p';
  }

  // type: user | admin
  void _addUser(BuildContext context, String type) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController();
    final passwordController = TextEditingController();
    final loginController = TextEditingController();

    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(type == 'user' ? 'Новый клиент' : 'Новый админ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'ФИО / Имя', Icons.person_outline),
              _buildDialogField(emailController, 'Email', Icons.email_outlined),
              if (type == 'user')
                _buildDialogField(phoneController, 'Телефон', Icons.phone_outlined, hint: '77712345'),
              if (type == 'admin')
                _buildDialogField(loginController, 'Логин (для входа)', Icons.badge_outlined),
              _buildDialogField(passwordController, 'Пароль', Icons.lock_outline, isPassword: true),
              if (type == 'user')
                _buildDialogField(roleController, 'Роль (по умолчанию: client)', Icons.shield_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final body = <String, dynamic>{
                'type': type,
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
                'password': passwordController.text.trim(),
              };
              if (type == 'user') {
                body['phone'] = _normPhone(phoneController.text);
                final role = roleController.text.trim();
                if (role.isNotEmpty) body['role'] = role;
              } else {
                body['login'] = loginController.text.trim();
              }
              try {
                await _send('POST', '/api/admin/people', body);
                if (dctx.mounted) Navigator.pop(dctx);
                _snack('Добавлено');
                _load(spinner: false);
              } catch (e) {
                _snack(_clean(e), error: true); // диалог остаётся открытым
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _editUser(BuildContext context, String type, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: (data['name'] ?? '').toString());
    final emailController = TextEditingController(text: (data['email'] ?? '').toString());
    final phoneController = TextEditingController(text: (data['phone'] ?? '').toString());
    final loginController = TextEditingController(text: (data['login'] ?? '').toString());
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Редактирование', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'Имя', Icons.person_outline),
              _buildDialogField(emailController, 'Email', Icons.email_outlined),
              if (type == 'user')
                _buildDialogField(phoneController, 'Телефон', Icons.phone_outlined),
              if (type == 'admin')
                _buildDialogField(loginController, 'Логин', Icons.badge_outlined),
              _buildDialogField(passwordController, 'Новый пароль', Icons.lock_outline,
                  isPassword: true, hint: 'Оставьте пустым, чтобы не менять'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              final body = <String, dynamic>{
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
              };
              final newPassword = passwordController.text.trim();
              if (newPassword.isNotEmpty) body['password'] = newPassword;
              if (type == 'user') body['phone'] = _normPhone(phoneController.text);
              if (type == 'admin') body['login'] = loginController.text.trim();

              try {
                await _send('PATCH', '/api/admin/people/$type/${data['id']}', body);
                if (dctx.mounted) Navigator.pop(dctx);
                _snack('Сохранено');
                _load(spinner: false);
              } catch (e) {
                _snack(_clean(e), error: true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String type, Map<String, dynamic> user) async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Вы уверены, что хотите удалить пользователя?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;
    try {
      await _send('DELETE', '/api/admin/people/$type/${user['id']}');
      _snack('Удалено');
      _load(spinner: false);
    } catch (e) {
      _snack(_clean(e), error: true);
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allUsers) {
    final q = searchQuery.toLowerCase();
    return allUsers.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(q) || phone.contains(q);
      final matchesFilter = filterType == 'all' || filterType == user['type'];
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Кого добавить?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _addTypeBtn(ctx, 'Клиент', Icons.person_add, Colors.blue, 'user'),
                _addTypeBtn(ctx, 'Админ', Icons.admin_panel_settings, Colors.red, 'admin'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Управление штатом',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            Text('Админ: ${widget.currentAdminName}',
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => _load()),
          IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
              onPressed: _showAddUserSheet),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Поиск...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'Все'),
                      _filterChip('user', 'Клиенты'),
                      _filterChip('admin', 'Админы'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: () => _load(), child: const Text('Повторить')),
          ],
        ),
      );
    }
    final users = _applyFilter(_all);
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: users.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Никого не нашли...')),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        itemBuilder: (context, index) =>
            _buildUserCard(users[index], users[index]['type'].toString()),
      ),
    );
  }

  Widget _addTypeBtn(BuildContext ctx, String label, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _addUser(context, type);
      },
      child: Column(children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 30, child: Icon(icon, color: color)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500))
      ]),
    );
  }

  Widget _filterChip(String id, String label) {
    bool selected = filterType == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (v) => setState(() => filterType = id),
        labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold),
        selectedColor: const Color(0xFF3B82F6),
        backgroundColor: Colors.white.withOpacity(0.9),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, String type) {
    final Color color = type == 'admin' ? Colors.red : Colors.blue;
    final IconData icon = type == 'admin' ? Icons.admin_panel_settings : Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text((user['name'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user['login'] != null)
              Text('Логин: ${user['login']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text((user['email'] ?? '-').toString(),
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            if (user['phone'] != null)
              Text(user['phone'].toString(), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(type.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
                child: const ListTile(leading: Icon(Icons.edit), title: Text('Изменить')),
                onTap: () => Future.delayed(Duration.zero, () => _editUser(this.context, type, user))),
            PopupMenuItem(
                child: const ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Удалить', style: TextStyle(color: Colors.red))),
                onTap: () => Future.delayed(Duration.zero, () => _deleteUser(type, user))),
          ],
        ),
      ),
    );
  }
}