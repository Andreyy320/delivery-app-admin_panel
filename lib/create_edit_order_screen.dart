import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  bool loading = true;
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  String _translateStatus(String key) {
    // Чистим ключ от лишних символов и пробелов
    final normalized = key.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();

    switch (normalized) {
      case 'new':
        return 'Новый';
      case 'accepted':
      case 'принято':
        return 'Принято';
      case 'inprogress':
      case 'preparing':
      case 'впути':
      case 'впроцессе':
        return 'В процессе';
      case 'delivered':
      case 'delivery': // Поймали Delivery из твоего скриншота
      case 'доставлено':
        return 'Доставлено';
      case 'canceled':
      case 'cancelled':
      case 'отменено':
        return 'Отменено';
      case 'ready':
      case 'готовквыдаче':
        return 'Готов к выдаче';
      default:
        return key.length > 0 ? key[0].toUpperCase() + key.substring(1) : 'Неизвестно';
    }
  }

  String _translateType(String key) {
    final normalized = key.toLowerCase().trim();

    switch (normalized) {
      case 'orders':
        return 'Обычная';
      case 'delivery':
        return 'Курьерская';
      case 'city':
      case 'погороду':
        return 'По городу';
      case 'mejcity':
      case 'intercity': // Поймали intercity из твоего скриншота
      case 'межгород':
        return 'Межгород';
      case 'express':
        return 'Экспресс';
      default:
        return key.length > 0 ? key[0].toUpperCase() + key.substring(1) : 'Обычная';
    }
  }

  // --- ЛОГИКА СБОРА ДАННЫХ ---
  Future<void> _calculateStats() async {
    int totalOrders = 0;
    double totalSum = 0.0;
    Map<String, int> statusCounts = {};
    Map<String, int> typeCounts = {};

    try {
      // 1. Сбор заказов из коллекции пользователей
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        final ordersSnapshot = await userDoc.reference.collection('orders').get();
        for (var orderDoc in ordersSnapshot.docs) {
          _processOrder(orderDoc.data(), statusCounts, typeCounts);
          totalOrders++;
          totalSum += _parsePrice(orderDoc.data());
        }
      }

      // 2. Сбор заказов из истории курьеров
      final couriersSnapshot = await FirebaseFirestore.instance.collection('couriers').get();
      for (var courierDoc in couriersSnapshot.docs) {
        final historySnapshot = await courierDoc.reference.collection('history').get();
        for (var orderDoc in historySnapshot.docs) {
          _processOrder(orderDoc.data(), statusCounts, typeCounts);
          totalOrders++;
          totalSum += _parsePrice(orderDoc.data());
        }
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    if (mounted) {
      setState(() {
        stats = {
          'totalOrders': totalOrders,
          'totalSum': totalSum,
          'statusCounts': statusCounts,
          'typeCounts': typeCounts,
        };
        loading = false;
      });
    }
  }

  void _processOrder(Map<String, dynamic> data, Map<String, int> sMap, Map<String, int> tMap) {
    // Получаем переведенные названия сразу, чтобы в Мапе они считались как один ключ
    final status = _translateStatus((data['status'] ?? 'Неизвестно').toString());
    final type = _translateType((data['type'] ?? 'Обычная').toString());

    sMap[status] = (sMap[status] ?? 0) + 1;
    tMap[type] = (tMap[type] ?? 0) + 1;
  }

  double _parsePrice(Map<String, dynamic> data) {
    final price = (data['totalPrice'] ?? data['totalCost'] ?? data['total'] ?? 0) as num;
    return price.toDouble();
  }

  // --- UI КОМПОНЕНТЫ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('АНАЛИТИКА',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : RefreshIndicator(
        onRefresh: _calculateStats,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Общие показатели',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoTile(
                  label: 'Заказов',
                  value: stats['totalOrders'].toString(),
                  icon: Icons.shopping_basket_rounded,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 16),
                _buildInfoTile(
                  label: 'Выручка',
                  value: '${(stats['totalSum'] as double).toInt()} ₽',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Статусы выполнения'),
            _buildDetailedCard(
              data: (stats['statusCounts'] as Map<String, int>),
              accentColor: Colors.orange,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Распределение по типам'),
            _buildDetailedCard(
              data: (stats['typeCounts'] as Map<String, int>),
              accentColor: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
    );
  }

  Widget _buildInfoTile({required String label, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 18,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedCard({required Map<String, int> data, required Color accentColor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: data.entries.map((e) {
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Icon(Icons.circle, size: 10, color: accentColor.withOpacity(0.6)),
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
              ),
              if (e.key != data.keys.last)
                Divider(height: 1, color: Colors.grey[100], indent: 20, endIndent: 20),
            ],
          );
        }).toList(),
      ),
    );
  }
}