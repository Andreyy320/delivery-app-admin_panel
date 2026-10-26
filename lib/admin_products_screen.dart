import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class AdminProductsScreen extends StatefulWidget {
  final dynamic shopId;
  final String shopName;

  const AdminProductsScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);
  static const _green = Color(0xFF3FA66B);
  static const _red = Color(0xFFD64545);

  String _searchQuery = '';
  String _filter = 'all'; // all | visible | hidden
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          .get(
          Uri.parse('${Api.baseUrl}/api/admin/shops/${widget.shopId}/products'),
          headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(_errText(r));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (body['products'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _products = list;
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

  Future<void> _toggle(Map<String, dynamic> p, bool value) async {
    final old = p['is_available'] != false;
    setState(() => p['is_available'] = value); // сразу показываем
    try {
      final r = await http
          .patch(Uri.parse('${Api.baseUrl}/api/admin/products/${p['id']}'),
          headers: Api.headers, body: jsonEncode({'is_available': value}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(_errText(r));
    } catch (e) {
      if (!mounted) return;
      setState(() => p['is_available'] = old); // откат
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Удалить товар?',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        content: Text(
          '«${(p['title'] ?? 'Товар').toString()}» будет удалён из меню без возможности восстановления. Если нужно только убрать из показа, лучше скрыть.',
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
    if (!ok) return;

    try {
      final r = await http
          .delete(Uri.parse('${Api.baseUrl}/api/admin/products/${p['id']}'),
          headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(_errText(r));
      if (!mounted) return;
      setState(() => _products.removeWhere((x) => x['id'] == p['id']));
      _snack('Товар удалён');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
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

  // ---------- ХЕЛПЕРЫ ----------
  bool _isVisible(Map<String, dynamic> p) => p['is_available'] != false;

  num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

  String _money(dynamic v) {
    final n = _num(v);
    if (n == null) return '—';
    final s = n == n.toInt() ? n.toInt().toString() : n.toStringAsFixed(2);
    return '${s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}\u00A0')} Руб';
  }

  int _count(String id) {
    if (id == 'all') return _products.length;
    if (id == 'visible') return _products.where(_isVisible).length;
    return _products.where((p) => !_isVisible(p)).length;
  }

  List<Map<String, dynamic>> _filtered() {
    final q = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      if (_filter == 'visible' && !_isVisible(p)) return false;
      if (_filter == 'hidden' && _isVisible(p)) return false;
      if (q.isEmpty) return true;
      return (p['title'] ?? '').toString().toLowerCase().contains(q) ||
          (p['category'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      labelStyle: const TextStyle(color: _muted),
      floatingLabelStyle: const TextStyle(color: _ink),
      hintStyle: const TextStyle(color: _muted, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: b(_line),
      enabledBorder: b(_line),
      disabledBorder: b(_line),
      focusedBorder: b(_ink, 1.5),
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
        ? widget.shopName
        : '${widget.shopName} · ${_products.length} товаров';

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
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Меню',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, color: _muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 15, color: _ink),
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Название или категория',
              hintStyle: const TextStyle(color: _muted),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
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
      {'id': 'visible', 'name': 'В наличии'},
      {'id': 'hidden', 'name': 'Скрытые'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final id = t['id']!;
          final isSel = _filter == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = id),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _ink, strokeWidth: 2.5));
    }
    if (_error != null && _products.isEmpty) {
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

    final data = _filtered();
    return RefreshIndicator(
      color: _ink,
      onRefresh: () => _load(spinner: false),
      child: data.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.inventory_2_outlined, size: 40, color: _muted),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _products.isEmpty ? 'В меню пока нет товаров' : 'Ничего не найдено',
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: data.length,
        itemBuilder: (context, i) => _buildProductCard(data[i]),
      ),
    );
  }

  Widget _thumb(String url, double size) {
    const icon = Icon(Icons.inventory_2_outlined, color: _muted, size: 24);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        color: _bg,
        child: url.isEmpty
            ? icon
            : Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => icon,
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final title = (p['title'] ?? 'Без названия').toString();
    final category = (p['category'] ?? '').toString().trim();
    final weight = (p['weight'] ?? '').toString().trim();
    final image = (p['image_url'] ?? '').toString();
    final visible = _isVisible(p);

    final meta = [
      if (category.isNotEmpty) category,
      if (weight.isNotEmpty && weight != 'null') weight,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showEditSheet(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              children: [
                Opacity(opacity: visible ? 1 : 0.45, child: _thumb(image, 56)),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: visible ? 1 : 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _money(p['price']),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _ink),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: visible ? _green : _red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              visible ? 'В наличии' : 'Скрыт',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Switch(
                  value: visible,
                  onChanged: (v) => _toggle(p, v),
                  activeColor: Colors.white,
                  activeTrackColor: _ink,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: _line,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- ПРАВКА ТОВАРА ----------
  void _showEditSheet(Map<String, dynamic> p) {
    String s(dynamic v) => v == null ? '' : v.toString().trim();

    final priceNum = _num(p['price']);
    final titleC = TextEditingController(text: s(p['title']));
    final priceC = TextEditingController(
        text: priceNum == null
            ? ''
            : (priceNum == priceNum.toInt()
            ? priceNum.toInt().toString()
            : priceNum.toString()));
    final categoryC = TextEditingController(text: s(p['category']));
    final descC = TextEditingController(text: s(p['description']));

    bool saving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> submit() async {
            final title = titleC.text.trim();
            if (title.isEmpty) {
              setSheet(() => formError = 'Введите название товара');
              return;
            }
            final price = double.tryParse(priceC.text.trim().replaceAll(',', '.'));
            if (price == null || price < 0) {
              setSheet(() => formError = 'Цена: введите число');
              return;
            }

            // отправляем только то, что реально изменилось
            final body = <String, dynamic>{};
            if (title != s(p['title'])) body['title'] = title;
            if (price != priceNum) body['price'] = price;
            if (categoryC.text.trim() != s(p['category'])) {
              body['category'] = categoryC.text.trim();
            }
            if (descC.text.trim() != s(p['description'])) {
              body['description'] = descC.text.trim();
            }

            if (body.isEmpty) {
              Navigator.pop(sheetCtx);
              return;
            }

            setSheet(() {
              saving = true;
              formError = null;
            });

            try {
              final r = await http
                  .patch(Uri.parse('${Api.baseUrl}/api/admin/products/${p['id']}'),
                  headers: Api.headers, body: jsonEncode(body))
                  .timeout(const Duration(seconds: 15));
              if (r.statusCode != 200) throw Exception(_errText(r));
              if (!mounted) return;
              setState(() => p.addAll(body));
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              _snack('Сохранено');
            } catch (e) {
              if (sheetCtx.mounted) {
                setSheet(() {
                  saving = false;
                  formError = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }
          }

          void clearError() {
            if (formError != null) setSheet(() => formError = null);
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _thumb(s(p['image_url']), 64),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Изменить товар',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: _ink),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: titleC,
                              enabled: !saving,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => clearError(),
                              decoration: _fieldDecoration('Название'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: priceC,
                                    enabled: !saving,
                                    keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true),
                                    onChanged: (_) => clearError(),
                                    decoration: _fieldDecoration('Цена'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: categoryC,
                                    enabled: !saving,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => clearError(),
                                    decoration: _fieldDecoration('Категория'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descC,
                              enabled: !saving,
                              minLines: 3,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              onChanged: (_) => clearError(),
                              decoration: _fieldDecoration('Описание'),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              child: formError == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                padding: const EdgeInsets.only(top: 14, left: 2),
                                child: Text(
                                  formError!,
                                  style: const TextStyle(
                                      fontSize: 13, color: _red, height: 1.3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () {
                                  Navigator.pop(sheetCtx);
                                  _delete(p);
                                },
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: _red, size: 20),
                                label: const Text('Удалить товар',
                                    style: TextStyle(
                                        color: _red, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed: saving ? null : () => Navigator.pop(sheetCtx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ink,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: _line),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Отмена',
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
                                onPressed: saving ? null : submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  disabledBackgroundColor: _accent.withAlpha(130),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: saving
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                                    : const Text('Сохранить',
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
        },
      ),
    );
  }
}