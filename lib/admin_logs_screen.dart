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
  String filterAction = 'Все';
  String searchQuery = '';

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (act.contains('удал') || act.contains('отклон') || act.contains('убрал') || act.contains('отключ')) {
      return 'delete';
    }
    if (act.contains('добав') || act.contains('создал') || act.contains('одобрил') || act.contains('включ')) {
      return 'create';
    }
    if (act.contains('измен') || act.contains('обновил') || act.contains('редакт')) {
      return 'edit';
    }
    return 'info';
  }

  Map<String, dynamic> _getLogStyle(String action) {
    switch (_kind(action)) {
      case 'delete':
        return {'color': Colors.redAccent, 'icon': Icons.delete_sweep_rounded};
      case 'create':
        return {'color': Colors.green, 'icon': Icons.add_circle_outline_rounded};
      case 'edit':
        return {'color': Colors.orangeAccent, 'icon': Icons.edit_document};
      default:
        return {'color': Colors.blueAccent, 'icon': Icons.history_rounded};
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

  List<Map<String, dynamic>> _applyFilter() {
    final q = searchQuery.trim().toLowerCase();
    return _logs.where((log) {
      final action = (log['action'] ?? '').toString();
      if (filterAction != 'Все') {
        final kind = _kind(action);
        final want = {'Создание': 'create', 'Изменение': 'edit', 'Удаление': 'delete'}[filterAction];
        if (kind != want) return false;
      }
      if (q.isEmpty) return true;
      return action.toLowerCase().contains(q) ||
          (log['target'] ?? '').toString().toLowerCase().contains(q) ||
          _adminOf(log).toLowerCase().contains(q);
    }).toList();
  }

  // ---------- ЭКРАН ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('ЖУРНАЛ СОБЫТИЙ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => _load()),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: () => _load(), child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    final logs = _applyFilter();
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: logs.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Center(child: Text('Событий не найдено', style: TextStyle(color: Colors.grey))),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (context, index) => _buildLogCard(logs[index]),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск: действие, объект, админ...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Все', 'Создание', 'Изменение', 'Удаление'].map((filter) {
                final isSelected = filterAction == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) => setState(() => filterAction = filter),
                    selectedColor: Colors.blueAccent,
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.blueAccent,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: const BorderSide(color: Colors.blueAccent, width: 1),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = (log['action'] ?? 'Действие').toString();
    final date = _dateOf(log);
    final style = _getLogStyle(action);
    final Color color = style['color'] as Color;
    final hasDetails = log['oldValue'] != null || log['newValue'] != null;
    final target = (log['target'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(style['icon'] as IconData, color: color, size: 20),
        ),
        title: Text(
          action,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          '${_adminOf(log)}${date != null ? ' • ${DateFormat('dd.MM HH:mm').format(date)}' : ''}'
              '${target.isNotEmpty ? '\n$target' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _logDetailRow('Админ:', _adminOf(log)),
                _logDetailRow('Объект:', target.isEmpty ? '—' : target),
                if (date != null)
                  _logDetailRow('Дата:', DateFormat('dd.MM.yyyy, HH:mm').format(date)),
                if (hasDetails) ...[
                  const SizedBox(height: 16),
                  const Text('ИЗМЕНЕНИЯ:',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  _buildComparisonBox(log['oldValue']?.toString() ?? 'нет данных',
                      log['newValue']?.toString() ?? 'нет данных'),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildComparisonBox(String oldV, String newV) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text('Было: $oldV', style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.grey),
          ),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Стало: $newV',
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}