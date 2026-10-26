import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'disabled'
  String _selectedCategoryKey = 'all';

  List<Map<String, dynamic>> _shops = [];
  bool _loading = true;
  String? _error;

  // Словарь переводов
  final Map<String, String> _translations = {
    'restaurant': 'Ресторан',
    'product': 'Продуктовый магазин',
    'svetok': 'Цветочный магазин',
    'electronika': 'Магазин электроники и техники',
    'apteka': 'Аптека',
    'odejda': 'Магазин одежды',
    'stroimaterial': 'Строй магазины',
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
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final keysList = _translations.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          'УПРАВЛЕНИЕ ЗАВЕДЕНИЯМИ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию заведения...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusChip('Все статусы', 'all'),
                    const SizedBox(width: 8),
                    _buildStatusChip('Активные', 'active'),
                    const SizedBox(width: 8),
                    _buildStatusChip('Отключенные', 'disabled'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Фильтр по типам:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _buildCategoryChip('Все типы', 'all')),
                    const SizedBox(width: 6),
                    if (keysList.isNotEmpty) Expanded(child: _buildCategoryChip(_translations[keysList[0]]!, keysList[0])),
                    const SizedBox(width: 6),
                    if (keysList.length > 1) Expanded(child: _buildCategoryChip(_translations[keysList[1]]!, keysList[1])),
                    const SizedBox(width: 6),
                    if (keysList.length > 2) Expanded(child: _buildCategoryChip(_translations[keysList[2]]!, keysList[2])),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (keysList.length > 3) Expanded(child: _buildCategoryChip(_translations[keysList[3]]!, keysList[3])) else const Spacer(),
                    const SizedBox(width: 6),
                    if (keysList.length > 4) Expanded(child: _buildCategoryChip(_translations[keysList[4]]!, keysList[4])) else const Spacer(),
                    const SizedBox(width: 6),
                    if (keysList.length > 5) Expanded(child: _buildCategoryChip(_translations[keysList[5]]!, keysList[5])) else const Spacer(),
                    const SizedBox(width: 6),
                    if (keysList.length > 6) Expanded(child: _buildCategoryChip(_translations[keysList[6]]!, keysList[6])) else const Spacer(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _shops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ошибка загрузки: $_error', textAlign: TextAlign.center),
            TextButton(onPressed: () => _load(), child: const Text('Повторить')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: _buildShopsList(_shops),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategoryKey == value;
    return InkWell(
      onTap: () => setState(() => _selectedCategoryKey = value),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade800 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  Widget _buildShopsList(List<Map<String, dynamic>> shops) {
    final filtered = shops.where((data) {
      final name = (data['name'] ?? 'Без названия').toString().toLowerCase();
      final bool isActive = data['is_active'] == true;
      final rawCategory = (data['category'] ?? '').toString().toLowerCase().trim();

      if (_filterStatus == 'active' && !isActive) return false;
      if (_filterStatus == 'disabled' && isActive) return false;
      if (_selectedCategoryKey != 'all' && rawCategory != _selectedCategoryKey) return false;
      return name.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text('Заведения не найдены',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final data = filtered[index];
        final shopName = (data['name'] ?? 'Заведение без имени').toString();
        final rawCategory = (data['category'] ?? 'general').toString();
        final translatedCategory = _translateCategory(rawCategory);
        final bool isActive = data['is_active'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Icon(
                Icons.storefront_rounded,
                color: isActive ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              shopName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Тип: $translatedCategory',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Статус: Работает в системе' : 'Статус: Отключен от сервиса',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            trailing: Switch.adaptive(
              value: isActive,
              activeColor: Colors.green,
              onChanged: (bool value) => _toggle(data, value),
            ),
          ),
        );
      },
    );
  }
}