import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class AdminRequestsScreen extends StatefulWidget {
  final String currentAdminName;

  const AdminRequestsScreen({super.key, required this.currentAdminName});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);
  static const _red = Color(0xFFD64545);

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
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: error ? _red : _ink,
      content: Text(text),
    ));
  }

  String _randomPassword() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Скопировано');
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
                Expanded(child: _buildBody()),
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
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _line),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: _ink, size: 21),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHeader() {
    final subtitle = _loading
        ? 'Новые партнёры'
        : _requests.isEmpty
        ? 'Новых заявок нет'
        : 'Ждут решения: ${_requests.length}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Заявки',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 15, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _ink, strokeWidth: 2.5));
    }
    if (_error != null && _requests.isEmpty) return _buildErrorState(_error!);
    return RefreshIndicator(
      color: _ink,
      onRefresh: () => _load(spinner: false),
      child: _requests.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          _buildEmptyState(),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: _requests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(context, _requests[index]),
      ),
    );
  }

  Widget _logoBox(String logo, double size, double radius, {double iconSize = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(radius),
        image: logo.isNotEmpty
            ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
            : null,
      ),
      child: logo.isEmpty
          ? Icon(Icons.storefront_rounded, color: _muted, size: iconSize)
          : null,
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> data) {
    final logo = (data['logo_url'] ?? '').toString();
    final phone = (data['phone'] ?? 'Телефон не указан').toString();
    final category = (data['category'] ?? '').toString().trim();
    final sub = [phone, if (category.isNotEmpty) category].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context, data),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _logoBox(logo, 52, 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['name'] ?? 'Без названия').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _coords(Map<String, dynamic> data) {
    final lat = num.tryParse('${data['lat']}');
    final lng = num.tryParse('${data['lng']}');
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final logo = (data['logo_url'] ?? '').toString();
    final coords = _coords(data);

    final rows = <Widget>[
      _detailRow(Icons.alternate_email_rounded, 'Контакт',
          (data['login'] ?? 'Не указан').toString()),
      _detailRow(Icons.phone_outlined, 'Телефон',
          (data['phone'] ?? 'Не указан').toString()),
      if (coords.isNotEmpty)
        _detailRow(Icons.location_on_outlined, 'Координаты', coords),
      _detailRow(Icons.access_time_rounded, 'Время работы',
          (data['time'] ?? 'Не указано').toString()),
      _detailRow(Icons.category_outlined, 'Категория',
          (data['category'] ?? 'Не указана').toString()),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _line, borderRadius: BorderRadius.circular(10)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  children: [
                    Center(child: _logoBox(logo, 96, 26, iconSize: 40)),
                    const SizedBox(height: 18),
                    Text(
                      (data['name'] ?? 'Заявка').toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < rows.length; i++) ...[
                            rows[i],
                            if (i != rows.length - 1)
                              const Divider(height: 1, color: _line),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            await _reject(data);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: const BorderSide(color: _line),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Отклонить',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _showCredentialsDialog(data);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Одобрить',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- ДИАЛОГИ ----------
  InputDecoration _fieldDecoration(String label, {String? helper, Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      helperText: helper,
      labelStyle: const TextStyle(color: _muted),
      floatingLabelStyle: const TextStyle(color: _ink),
      suffixIcon: suffix,
      filled: true,
      fillColor: _bg,
      border: border(_line),
      enabledBorder: border(_line),
      focusedBorder: border(_ink, 1.5),
    );
  }

  Future<void> _reject(Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Отклонить заявку?',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        content: const Text(
          'Заявка будет удалена. Заведение сможет подать новую.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Нет',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Отклонить',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ??
        false;
    if (!ok) return;
    final err = await _post('/api/admin/requests/${data['id']}/reject');
    if (err != null) {
      _snack(err, error: true);
    } else {
      _snack('Заявка отклонена');
      _load(spinner: false);
    }
  }

  void _showCredentialsDialog(Map<String, dynamic> data) {
    final loginController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscure = true;
    bool saving = false;
    String? formError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialog) {
          Future<void> submit() async {
            final login = loginController.text.trim();
            final pass = passwordController.text.trim();

            if (login.isEmpty || pass.isEmpty) {
              setDialog(() => formError = 'Заполните логин и пароль');
              return;
            }
            if (pass.length < 6) {
              setDialog(() => formError = 'Пароль слишком короткий (минимум 6 символов)');
              return;
            }

            setDialog(() {
              saving = true;
              formError = null;
            });

            final err = await _post('/api/admin/requests/${data['id']}/approve',
                {'login': login, 'password': pass});

            if (err != null) {
              if (dctx.mounted) {
                setDialog(() {
                  saving = false;
                  formError = err; // ошибка показывается в самом окне
                });
              }
              return;
            }

            if (dctx.mounted) Navigator.pop(dctx);
            _showAccessIssued(login, pass);
            _load(spinner: false);
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('Выдача доступа',
                style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: loginController,
                    enabled: !saving,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (formError != null) setDialog(() => formError = null);
                    },
                    decoration: _fieldDecoration('Логин'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    enabled: !saving,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (formError != null) setDialog(() => formError = null);
                    },
                    onSubmitted: (_) => saving ? null : submit(),
                    decoration: _fieldDecoration(
                      'Пароль',
                      suffix: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _muted,
                          size: 20,
                        ),
                        onPressed: () => setDialog(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: formError == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                      padding: const EdgeInsets.only(top: 12, left: 2),
                      child: Text(
                        formError!,
                        style: const TextStyle(
                            fontSize: 13, color: _red, height: 1.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text(
                      'После сохранения пароль не показывается, передайте его заведению заранее.',
                      style: TextStyle(fontSize: 12, color: _muted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dctx),
                child: const Text('Отмена',
                    style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: _accent.withAlpha(130),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Сохранить',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }



  void _showAccessIssued(String login, String pass) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Доступ выдан',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Передайте данные заведению. Пароль больше не покажется.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 16),
            _copyRow('Логин', login),
            const SizedBox(height: 10),
            _copyRow('Пароль', pass),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Готово',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: _muted, size: 20),
            onPressed: () => _copy(value),
          ),
        ],
      ),
    );
  }

  // ---------- ПУСТО / ОШИБКА ----------
  Widget _buildEmptyState() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: _muted),
        SizedBox(height: 14),
        Text('Очередь пуста',
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.w700, fontSize: 18)),
        SizedBox(height: 6),
        Text('Потяните вниз, чтобы обновить',
            style: TextStyle(color: _muted, fontSize: 14)),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _muted),
            const SizedBox(height: 14),
            const Text('Нет связи с сервером',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 17, color: _ink)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted)),
            const SizedBox(height: 8),
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
}