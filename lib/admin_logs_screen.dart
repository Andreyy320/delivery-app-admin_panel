import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  String filterAction = 'Все';

  // Улучшенный маппинг стилей
  Map<String, dynamic> _getLogStyle(String action) {
    String act = action.toLowerCase();

    if (act.contains('удал') || act.contains('отклон') || act.contains('убрал')) {
      return {'color': Colors.redAccent, 'icon': Icons.delete_sweep_rounded, 'label': 'Удаление'};
    }
    if (act.contains('добав') || act.contains('создал') || act.contains('одобрил')) {
      return {'color': Colors.greenAccent[700], 'icon': Icons.add_circle_outline_rounded, 'label': 'Создание'};
    }
    if (act.contains('измен') || act.contains('обновил') || act.contains('редакт')) {
      return {'color': Colors.orangeAccent, 'icon': Icons.edit_document, 'label': 'Изменение'};
    }
    return {'color': Colors.blueAccent, 'icon': Icons.history_rounded, 'label': 'Инфо'};
  }

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
      ),
      body: Column(
        children: [
          // Панель фильтров
          _buildFilterBar(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admin_logs')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Ошибка загрузки'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allLogs = snapshot.data!.docs;

                // УМНАЯ ФИЛЬТРАЦИЯ
                final filteredLogs = allLogs.where((doc) {
                  if (filterAction == 'Все') return true;

                  String act = (doc['action'] ?? '').toString().toLowerCase();

                  if (filterAction == 'Создание') {
                    return act.contains('добав') || act.contains('создал');
                  }
                  if (filterAction == 'Удаление') {
                    return act.contains('удал') || act.contains('отклон');
                  }
                  if (filterAction == 'Изменение') {
                    return act.contains('измен') || act.contains('обновил') || act.contains('редакт');
                  }
                  return false;
                }).toList();

                if (filteredLogs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Событий не найдено', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    return _buildLogCard(filteredLogs[index].data() as Map<String, dynamic>);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFF0F172A),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Все', 'Создание', 'Изменение', 'Удаление'].map((filter) {
            bool isSelected = filterAction == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (val) => setState(() => filterAction = filter),

                // Цвет фона активного чипа (Синий)
                selectedColor: Colors.blueAccent,

                // Цвет фона неактивного чипа (Прозрачный или белый, как ты хотел)
                backgroundColor: Colors.transparent,

                // Настройка текста
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.blueAccent, // Белый если выбран, синий если нет
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),

                // Настройка рамки (Синяя обводка для неактивных)
                side: BorderSide(
                  color: Colors.blueAccent,
                  width: 1,
                ),

                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final DateTime date = (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final style = _getLogStyle(log['action'] ?? '');
    final bool hasDetails = log.containsKey('oldValue') || log.containsKey('newValue');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (style['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(style['icon'], color: style['color'], size: 20),
        ),
        title: Text(
          log['action'] ?? 'Действие',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          '${log['adminName'] ?? 'Система'} • ${DateFormat('HH:mm').format(date)}',
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
                _logDetailRow('Объект:', log['target'] ?? '—'),
                _logDetailRow('Дата:', DateFormat('dd.MM.yyyy, HH:mm').format(date)),

                if (hasDetails) ...[
                  const SizedBox(height: 16),
                  const Text('ИЗМЕНЕНИЯ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  _buildComparisonBox(log['oldValue']?.toString() ?? 'нет данных', log['newValue']?.toString() ?? 'нет данных'),
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
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
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
              Expanded(child: Text('Стало: $newV', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold))),
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