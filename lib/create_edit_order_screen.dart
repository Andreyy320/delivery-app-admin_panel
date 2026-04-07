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

  Future<void> _calculateStats() async {
    int totalOrders = 0;
    double totalSum = 0.0;
    Map<String, int> statusCounts = {};
    Map<String, int> typeCounts = {};

    // --- Заказы пользователей ---
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    for (var userDoc in usersSnapshot.docs) {
      final ordersSnapshot = await userDoc.reference.collection('orders').get();
      for (var orderDoc in ordersSnapshot.docs) {
        final order = orderDoc.data();
        totalOrders++;

        // Цена
        final price = (order['totalPrice'] ??
            order['totalCost'] ??
            order['total'] ??
            0) as num;
        totalSum += price.toDouble();

        // Статус
        final status = (order['status'] ?? 'Неизвестно').toString();
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        // Тип
        final type = (order['type'] ?? 'Неизвестно').toString();
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
    }

    // --- История курьеров ---
    final couriersSnapshot =
    await FirebaseFirestore.instance.collection('couriers').get();
    for (var courierDoc in couriersSnapshot.docs) {
      final historySnapshot = await courierDoc.reference.collection('history').get();
      for (var orderDoc in historySnapshot.docs) {
        final order = orderDoc.data();
        totalOrders++;

        final price = (order['totalPrice'] ??
            order['totalCost'] ??
            order['total'] ??
            0) as num;
        totalSum += price.toDouble();

        final status = (order['status'] ?? 'Неизвестно').toString();
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final type = (order['type'] ?? 'Неизвестно').toString();
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
    }

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

  Widget _buildCard(String title, List<String> lines) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 8),
            ...lines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(line, style: const TextStyle(fontSize: 16)),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика заказов')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            _buildCard('Общая информация', [
              'Всего заказов: ${stats['totalOrders']}',
              'Общая сумма: ${(stats['totalSum'] as double).toStringAsFixed(2)} ₽',
            ]),
            _buildCard('Статусы заказов',
                (stats['statusCounts'] as Map<String, int>)
                    .entries
                    .map((e) {
                  String russianStatus;
                  switch (e.key.toLowerCase()) {
                    case 'accepted':
                      russianStatus = 'Принят';
                      break;
                    case 'in_progress':
                      russianStatus = 'В пути';
                      break;
                    case 'delivered':
                      russianStatus = 'Доставлен';
                      break;
                    case 'cancelled':
                      russianStatus = 'Отменён';
                      break;
                    default:
                      russianStatus = e.key;
                  }
                  return '- $russianStatus: ${e.value}';
                }).toList()),
            _buildCard('Типы заказов',
                (stats['typeCounts'] as Map<String, int>)
                    .entries
                    .map((e) {
                  String russianType;
                  switch (e.key.toLowerCase()) {
                    case 'normal':
                      russianType = 'Обычная доставка';
                      break;
                    case 'delivery':
                      russianType = 'Срочная доставка';
                      break;
                    case 'city':
                      russianType = 'Городская доставка';
                      break;
                    case 'mejcity':
                      russianType = 'Межгород';
                      break;
                    default:
                      russianType = e.key;
                  }
                  return '- $russianType: ${e.value}';
                }).toList()),
          ],
        ),
      ),
    );
  }
}
