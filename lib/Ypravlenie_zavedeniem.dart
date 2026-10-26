import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_products_screen.dart';
import 'api.dart';

class AdminShopsScreen extends StatefulWidget {
  final String currentAdminName;

  const AdminShopsScreen({
    super.key,
    required this.currentAdminName,
  });

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _green = Color(0xFF3FA66B);
  static const _red = Color(0xFFD64545);
  static const _accent = Color(0xFFF26B1D);

  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'disabled'
  String _selectedCategoryKey = 'all';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _shops = [];
  bool _loading = true;
  String? _error;

  // Полные названия (для карточек)
  final Map<String, String> _translations = {
    'restaurant': 'Ресторан',
    'product': 'Продуктовый магазин',
    'svetok': 'Цветочный магазин',
    'electronika': 'Магазин электроники и техники',
    'apteka': 'Аптека',
    'odejda': 'Магазин одежды',
    'stroimaterial': 'Строй магазины',
  };

  // Короткие названия (для фильтров)
  final Map<String, String> _shortLabels = {
    'restaurant': 'Рестораны',
    'product': 'Продукты',
    'svetok': 'Цветы',
    'electronika': 'Электроника',
    'apteka': 'Аптеки',
    'odejda': 'Одежда',
    'stroimaterial': 'Стройматериалы',
  };

  String _translateCategory(String rawCategory) {
    final lowerKey = rawCategory.toLowerCase().trim();
    return _translations[lowerKey] ??
        (rawCategory.isNotEmpty
            ? rawCategory[0].toUpperCase() + rawCategory.substring(1)
            : 'Категория');
  }

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
          .get(Uri.parse('${Api.baseUrl}/api/admin/shops'), headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(_errText(r));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (body['shops'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _shops = list;
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

  Future<void> _toggle(Map<String, dynamic> shop, bool value) async {
    final old = shop['is_active'] == true;
    setState(() => shop['is_active'] = value); // сразу показываем
    try {
      final r = await http
          .patch(Uri.parse('${Api.baseUrl}/api/admin/shops/${shop['id']}/active'),
          headers: Api.headers, body: jsonEncode({'is_active': value}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(_errText(r));
    } catch (e) {
      if (!mounted) return;
      setState(() => shop['is_active'] = old); // откат
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _red,
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }


  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: _ink,
      content: Text(text),
    ));
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
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

  void _showEditSheet(Map<String, dynamic> shop) {
    String s(dynamic v) => v == null ? '' : v.toString().trim();

    final nameC = TextEditingController(text: s(shop['name']));
    final phoneC = TextEditingController(text: s(shop['phone']));
    final timeC = TextEditingController(text: s(shop['time']));
    final latC = TextEditingController(text: s(shop['lat']));
    final lngC = TextEditingController(text: s(shop['lng']));

    final currentCat = s(shop['category']).toLowerCase();
    final catKeys = [..._translations.keys];
    if (currentCat.isNotEmpty && !catKeys.contains(currentCat)) {
      catKeys.add(currentCat); // тип, которого нет в словаре, не теряем
    }
    String? category = currentCat.isEmpty ? null : currentCat;

    bool saving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> submit() async {
            final name = nameC.text.trim();
            if (name.isEmpty) {
              setSheet(() => formError = 'Введите название заведения');
              return;
            }

            double? lat, lng;
            final latT = latC.text.trim().replaceAll(',', '.');
            final lngT = lngC.text.trim().replaceAll(',', '.');
            if (latT.isNotEmpty || lngT.isNotEmpty) {
              lat = double.tryParse(latT);
              lng = double.tryParse(lngT);
              if (lat == null || lng == null) {
                setSheet(() =>
                formError = 'Координаты: введите два числа, широту и долготу');
                return;
              }
            }

            // отправляем только то, что реально изменилось
            final body = <String, dynamic>{};
            if (name != s(shop['name'])) body['name'] = name;
            if (phoneC.text.trim() != s(shop['phone'])) {
              body['phone'] = phoneC.text.trim();
            }
            if (timeC.text.trim() != s(shop['time'])) {
              body['time'] = timeC.text.trim();
            }
            if (category != null && category != currentCat) {
              body['category'] = category;
            }
            if (lat != null && lng != null) {
              final oldLat = double.tryParse(s(shop['lat']));
              final oldLng = double.tryParse(s(shop['lng']));
              if (lat != oldLat || lng != oldLng) {
                body['lat'] = lat;
                body['lng'] = lng;
              }
            }

            if (body.isEmpty) {
              Navigator.pop(sheetCtx); // менять нечего
              return;
            }

            setSheet(() {
              saving = true;
              formError = null;
            });

            try {
              final r = await http
                  .patch(Uri.parse('${Api.baseUrl}/api/admin/shops/${shop['id']}'),
                  headers: Api.headers, body: jsonEncode(body))
                  .timeout(const Duration(seconds: 15));
              if (r.statusCode != 200) throw Exception(_errText(r));
              if (!mounted) return;
              setState(() => shop.addAll(body));
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
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.9,
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
                            const Text(
                              'Изменить заведение',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: _ink),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: nameC,
                              enabled: !saving,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => clearError(),
                              decoration: _fieldDecoration('Название'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: phoneC,
                              enabled: !saving,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => clearError(),
                              decoration: _fieldDecoration('Телефон'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: category,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: _muted),
                              style: const TextStyle(fontSize: 16, color: _ink),
                              decoration: _fieldDecoration('Тип заведения'),
                              items: catKeys
                                  .map((k) => DropdownMenuItem(
                                value: k,
                                child: Text(_translateCategory(k),
                                    overflow: TextOverflow.ellipsis),
                              ))
                                  .toList(),
                              onChanged: saving
                                  ? null
                                  : (v) => setSheet(() {
                                category = v;
                                formError = null;
                              }),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: timeC,
                              enabled: !saving,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => clearError(),
                              decoration: _fieldDecoration('Время работы',
                                  hint: 'Например: 09:00 - 22:00'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: latC,
                                    enabled: !saving,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true, signed: true),
                                    onChanged: (_) => clearError(),
                                    decoration: _fieldDecoration('Широта'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: lngC,
                                    enabled: !saving,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true, signed: true),
                                    onChanged: (_) => clearError(),
                                    decoration: _fieldDecoration('Долгота'),
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              child: formError == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                padding:
                                const EdgeInsets.only(top: 14, left: 2),
                                child: Text(
                                  formError!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: _red,
                                      height: 1.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed:
                                saving ? null : () => Navigator.pop(sheetCtx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ink,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: _line),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Отмена',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
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
  // ---------- ХЕЛПЕРЫ ----------
  int get _activeCount => _shops.where((s) => s['is_active'] == true).length;

  int _statusCount(String id) {
    if (id == 'all') return _shops.length;
    if (id == 'active') return _activeCount;
    return _shops.length - _activeCount;
  }

  List<Map<String, dynamic>> _filtered() {
    return _shops.where((data) {
      final name = (data['name'] ?? 'Без названия').toString().toLowerCase();
      final bool isActive = data['is_active'] == true;
      final rawCategory = (data['category'] ?? '').toString().toLowerCase().trim();

      if (_filterStatus == 'active' && !isActive) return false;
      if (_filterStatus == 'disabled' && isActive) return false;
      if (_selectedCategoryKey != 'all' && rawCategory != _selectedCategoryKey) {
        return false;
      }
      return name.contains(_searchQuery);
    }).toList();
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

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  Widget _buildHeader() {
    final subtitle = _loading
        ? 'Управление заведениями'
        : 'Работают: $_activeCount из ${_shops.length}';

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
            'Заведения',
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
            controller: _searchController,
            style: const TextStyle(fontSize: 15, color: _ink),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Поиск по названию',
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
          _buildStatusChips(),
          const SizedBox(height: 8),
          _buildCategoryChips(),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    final types = [
      {'id': 'all', 'name': 'Все'},
      {'id': 'active', 'name': 'Активные'},
      {'id': 'disabled', 'name': 'Отключённые'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final id = t['id']!;
          final isSel = _filterStatus == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterStatus = id),
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
                      '${_statusCount(id)}',
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

  Widget _buildCategoryChips() {
    final entries = <MapEntry<String, String>>[
      const MapEntry('all', 'Все типы'),
      ..._translations.keys.map(
            (k) => MapEntry(k, _shortLabels[k] ?? _translations[k]!),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: entries.map((e) {
          final isSel = _selectedCategoryKey == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategoryKey = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSel ? _ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : _muted,
                  ),
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
    if (_error != null && _shops.isEmpty) {
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
    return RefreshIndicator(
      color: _ink,
      onRefresh: () => _load(spinner: false),
      child: _buildShopsList(_filtered()),
    );
  }

  Widget _buildShopsList(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.storefront_outlined, size: 40, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text('Заведения не найдены',
                style: TextStyle(color: _muted, fontSize: 15)),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildShopCard(filtered[index]),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> data) {
    final shopName = (data['name'] ?? 'Заведение без имени').toString();
    final rawCategory = (data['category'] ?? 'general').toString();
    final category = _translateCategory(rawCategory);
    final bool isActive = data['is_active'] == true;

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
          onTap: () => _showEditSheet(data),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Opacity(
                  opacity: isActive ? 1 : 0.5,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: _ink, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Opacity(
                    opacity: isActive ? 1 : 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isActive ? _green : _red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActive ? 'Работает' : 'Отключено',
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
                IconButton(
                  tooltip: 'Меню',
                  icon: const Icon(Icons.menu_book_outlined, color: _ink),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminProductsScreen(
                        shopId: data['id'],
                        shopName: shopName,
                      ),
                    ),
                  ),
                ),

                Switch(
                  value: isActive,
                  onChanged: (bool value) => _toggle(data, value),
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
}