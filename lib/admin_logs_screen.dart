import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);
  static const _green = Color(0xFF3FA66B);
  static const _red = Color(0xFFD64545);

  String filterAction = 'Все';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> _logs = [];
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
  Future<void> _load({bool spinner = true}) async {
    if (spinner) setState(() => _loading = true);
    try {
      final r = await http
          .get(Uri.parse('${Api.baseUrl}/api/admin/logs'), headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        String msg = 'Ошибка сервера (${r.statusCode})';
        try {
          final b = jsonDecode(r.body);
          if (b is Map && b['error'] != null) msg = b['error'].toString();
        } catch (_) {}
        throw Exception(msg);
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (body['logs'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _logs = list;
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

  // ---------- ХЕЛПЕРЫ ----------
  // Тип действия: create | delete | edit | info
  String _kind(String action) {
    final act = action.toLowerCase();
    if (act.contains('удал') ||
        act.contains('отклон') ||
        act.contains('убрал') ||
        act.contains('отключ')) {
      return 'delete';
    }
    if (act.contains('добав') ||
        act.contains('создал') ||
        act.contains('одобрил') ||
        act.contains('включ')) {
      return 'create';
    }
    if (act.contains('измен') ||
        act.contains('обновил') ||
        act.contains('редакт')) {
      return 'edit';
    }
    return 'info';
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'delete':
        return _red;
      case 'create':
        return _green;
      case 'edit':
        return _accent;
      default:
        return _muted;
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'delete':
        return 'Удаление';
      case 'create':
        return 'Создание';
      case 'edit':
        return 'Изменение';
      default:
        return 'Событие';
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'create':
        return Icons.add_rounded;
      case 'edit':
        return Icons.edit_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  // Сервер может отдать время в колонке created_at / timestamp / date
  DateTime? _dateOf(Map<String, dynamic> log) {
    for (final k in ['created_at', 'timestamp', 'date', 'time']) {
      final v = log[k];
      if (v == null) continue;
      final d = DateTime.tryParse(v.toString());
      if (d != null) return d.toLocal();
    }
    return null;
  }

  String _adminOf(Map<String, dynamic> log) =>
      (log['admin_name'] ?? log['adminName'] ?? 'Система').toString();

  static const _filterToKind = {
    'Создание': 'create',
    'Изменение': 'edit',
    'Удаление': 'delete',
  };

  int _count(String filter) {
    if (filter == 'Все') return _logs.length;
    final want = _filterToKind[filter];
    return _logs.where((l) => _kind((l['action'] ?? '').toString()) == want).length;
  }

  List<Map<String, dynamic>> _applyFilter() {
    final q = searchQuery.trim().toLowerCase();
    return _logs.where((log) {
      final action = (log['action'] ?? '').toString();
      if (filterAction != 'Все') {
        if (_kind(action) != _filterToKind[filterAction]) return false;
      }
      if (q.isEmpty) return true;
      return action.toLowerCase().contains(q) ||
          (log['target'] ?? '').toString().toLowerCase().contains(q) ||
          _adminOf(log).toLowerCase().contains(q);
    }).toList();
  }

  static const _months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  String _dayLabel(DateTime? d) {
    if (d == null) return 'Без даты';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    final base = '${d.day} ${_months[d.month - 1]}';
    return d.year == now.year ? base : '$base ${d.year}';
  }

  // Плоский список: строки-заголовки дней и записи
  List<Object> _buildItems(List<Map<String, dynamic>> logs) {
    final items = <Object>[];
    String? lastLabel;
    for (final log in logs) {
      final label = _dayLabel(_dateOf(log));
      if (label != lastLabel) {
        items.add(label);
        lastLabel = label;
      }
      items.add(log);
    }
    return items;
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
    final subtitle = _loading ? 'История действий админов' : 'Событий: ${_logs.length}';

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
            'Журнал',
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
              hintText: 'Действие, объект или админ',
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
    const filters = ['Все', 'Создание', 'Изменение', 'Удаление'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSel = filterAction == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => filterAction = f),
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
                      f,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? _ink : _muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_count(f)}',
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
    if (_error != null && _logs.isEmpty) {
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

    final logs = _applyFilter();
    final items = _buildItems(logs);

    return RefreshIndicator(
      color: _ink,
      onRefresh: () => _load(spinner: false),
      child: logs.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.history_toggle_off_rounded, size: 40, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text('Событий не найдено',
                style: TextStyle(color: _muted, fontSize: 15)),
          ),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is String) return _dayHeader(item, first: index == 0);
          return _buildLogCard(item as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _dayHeader(String label, {required bool first}) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 18, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
      ),
    );
  }

  Widget _kindPill(String kind) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _kindColor(kind), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _kindLabel(kind),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = (log['action'] ?? 'Действие').toString();
    final kind = _kind(action);
    final date = _dateOf(log);
    final hasDetails = log['oldValue'] != null || log['newValue'] != null;
    final target = (log['target'] ?? '').toString().trim();
    final time = date != null ? DateFormat('HH:mm').format(date) : '';
    final meta = [_adminOf(log), if (time.isNotEmpty) time].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _bg,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          childrenPadding: EdgeInsets.zero,
          iconColor: _muted,
          collapsedIconColor: _muted,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_kindIcon(kind), color: _ink, size: 22),
          ),
          title: Text(
            action,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (target.isNotEmpty)
                  Text(
                    target,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _ink),
                  ),
                const SizedBox(height: 2),
                Text(meta, style: const TextStyle(fontSize: 13, color: _muted)),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: _kindPill(kind)),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Админ', _adminOf(log)),
                  _detailRow('Объект', target.isEmpty ? '—' : target),
                  if (date != null)
                    _detailRow('Дата', DateFormat('dd.MM.yyyy, HH:mm').format(date)),
                  if (hasDetails) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Что изменилось',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    _buildComparison(
                      log['oldValue']?.toString() ?? 'нет данных',
                      log['newValue']?.toString() ?? 'нет данных',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(String oldV, String newV) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Было',
                  style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 3),
              Text(
                oldV,
                style: const TextStyle(
                  fontSize: 14,
                  color: _muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ink, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Стало',
                  style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 3),
              Text(
                newV,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}