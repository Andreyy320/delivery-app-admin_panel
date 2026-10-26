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
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);
  static const _red = Color(0xFFD64545);

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
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: error ? _red : _ink,
      content: Text(text),
    ));
  }

  // ---------- ХЕЛПЕРЫ ----------
  String _normPhone(String raw) {
    final p = raw.trim();
    if (p.isEmpty) return '';
    return p.startsWith('+') ? p : '+373$p';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  int _count(String id) {
    if (id == 'all') return _all.length;
    return _all.where((u) => u['type'] == id).length;
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

  // ---------- СТИЛИ ----------
  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );

  Widget _dialogField(
      TextEditingController controller,
      String label, {
        bool isPassword = false,
        String? hint,
        TextInputType? keyboard,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        autocorrect: false,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 15, color: _ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _muted),
          floatingLabelStyle: const TextStyle(color: _ink),
          hintStyle: const TextStyle(color: _muted, fontSize: 13),
          filled: true,
          fillColor: _bg,
          border: _border(_line),
          enabledBorder: _border(_line),
          focusedBorder: _border(_ink, 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _cancelButton(BuildContext dctx, [String text = 'Отмена']) {
    return TextButton(
      onPressed: () => Navigator.pop(dctx),
      child: Text(text,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
    );
  }

  AlertDialog _dialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
      content: content,
      actions: actions,
    );
  }

  // ---------- ДЕЙСТВИЯ ----------
  void _addUser(BuildContext context, String type) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController();
    final passwordController = TextEditingController();
    final loginController = TextEditingController();

    showDialog(
      context: context,
      builder: (dctx) => _dialog(
        title: type == 'user' ? 'Новый клиент' : 'Новый админ',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, 'ФИО / Имя'),
              _dialogField(emailController, 'Email', keyboard: TextInputType.emailAddress),
              if (type == 'user')
                _dialogField(phoneController, 'Телефон',
                    hint: '77712345', keyboard: TextInputType.phone),
              if (type == 'admin') _dialogField(loginController, 'Логин (для входа)'),
              _dialogField(passwordController, 'Пароль', isPassword: true),
              if (type == 'user')
                _dialogField(roleController, 'Роль', hint: 'По умолчанию: client'),
            ],
          ),
        ),
        actions: [
          _cancelButton(dctx),
          _primaryButton('Добавить', () async {
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
          }),
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
      builder: (dctx) => _dialog(
        title: 'Редактирование',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, 'Имя'),
              _dialogField(emailController, 'Email', keyboard: TextInputType.emailAddress),
              if (type == 'user')
                _dialogField(phoneController, 'Телефон', keyboard: TextInputType.phone),
              if (type == 'admin') _dialogField(loginController, 'Логин'),
              _dialogField(passwordController, 'Новый пароль',
                  isPassword: true, hint: 'Оставьте пустым, чтобы не менять'),
            ],
          ),
        ),
        actions: [
          _cancelButton(dctx),
          _primaryButton('Сохранить', () async {
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
          }),
        ],
      ),
    );
  }

  void _deleteUser(String type, Map<String, dynamic> user) async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => _dialog(
        title: 'Удалить пользователя?',
        content: Text(
          '${(user['name'] ?? 'Пользователь').toString()} будет удалён без возможности восстановления.',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Удалить',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
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

  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _line, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Кого добавить?',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 16),
              _addTile(ctx, 'Клиент', 'Покупатель в приложении',
                  Icons.person_add_alt_1_rounded, 'user'),
              const SizedBox(height: 10),
              _addTile(ctx, 'Админ', 'Доступ к этой панели',
                  Icons.admin_panel_settings_outlined, 'admin'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addTile(
      BuildContext ctx, String title, String subtitle, IconData icon, String type) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _addUser(context, type);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _ink, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 13, color: _muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- ЭКРАН ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _squareButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool filled = false,
  }) {
    return Material(
      color: filled ? _ink : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: filled ? BorderSide.none : const BorderSide(color: _line),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: filled ? Colors.white : _ink, size: 21),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHeader() {
    final subtitle = _loading
        ? 'Клиенты и администраторы'
        : 'Клиентов: ${_count('user')} · Админов: ${_count('admin')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _squareButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Назад',
                onTap: () => Navigator.maybePop(context),
              ),
              const Spacer(),
              _squareButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Обновить',
                onTap: () => _load(),
              ),
              const SizedBox(width: 8),
              _squareButton(
                icon: Icons.add_rounded,
                tooltip: 'Добавить',
                onTap: _showAddUserSheet,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Пользователи',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 15, color: _muted)),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            style: const TextStyle(fontSize: 15, color: _ink),
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Имя или телефон',
              hintStyle: const TextStyle(color: _muted),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                onPressed: () {
                  searchController.clear();
                  setState(() => searchQuery = '');
                },
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: _border(_line),
              enabledBorder: _border(_line),
              focusedBorder: _border(_ink, 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _buildChips(),
        ],
      ),
    );
  }

  Widget _buildChips() {
    final types = [
      {'id': 'all', 'name': 'Все'},
      {'id': 'user', 'name': 'Клиенты'},
      {'id': 'admin', 'name': 'Админы'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final id = t['id']!;
          final isSel = filterType == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => filterType = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSel ? _ink : _line,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? _ink : _muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_count(id)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSel ? _muted : _line,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _ink, strokeWidth: 2.5));
    }
    if (_error != null && _all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: _muted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 15)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(),
                child: const Text('Повторить',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    final users = _applyFilter(_all);
    return RefreshIndicator(
      color: _ink,
      onRefresh: () => _load(spinner: false),
      child: users.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.people_outline_rounded, size: 40, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text('Никого не нашли',
                style: TextStyle(color: _muted, fontSize: 15)),
          ),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: users.length,
        itemBuilder: (context, index) =>
            _buildUserCard(users[index], users[index]['type'].toString()),
      ),
    );
  }

  Widget _rolePill(String type) {
    final isAdmin = type == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? _ink : _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAdmin ? 'Админ' : 'Клиент',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAdmin ? Colors.white : _muted,
        ),
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, String type) {
    final name = (user['name'] ?? '-').toString();
    final email = (user['email'] ?? '').toString().trim();
    final phone = (user['phone'] ?? '').toString().trim();
    final login = (user['login'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _initials(name),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _rolePill(type),
                  ],
                ),
                const SizedBox(height: 3),
                if (login.isNotEmpty) _metaLine(Icons.badge_outlined, login),
                if (email.isNotEmpty) _metaLine(Icons.mail_outline_rounded, email),
                if (phone.isNotEmpty) _metaLine(Icons.phone_outlined, phone),
              ],
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded, color: _muted),
            color: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _line),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => Future.delayed(
                    Duration.zero, () => _editUser(this.context, type, user)),
                child: const Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: _ink),
                    SizedBox(width: 12),
                    Text('Изменить', style: TextStyle(color: _ink)),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () =>
                    Future.delayed(Duration.zero, () => _deleteUser(type, user)),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: _red),
                    SizedBox(width: 12),
                    Text('Удалить', style: TextStyle(color: _red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}