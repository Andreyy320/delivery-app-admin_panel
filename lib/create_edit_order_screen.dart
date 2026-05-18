import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStatisticsScreen extends StatefulWidget {
  final String currentAdminName;

  const AdminStatisticsScreen({super.key, required this.currentAdminName});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  bool loading = true;

  int totalOrders = 0;
  double totalSum = 0.0;
  double totalDeliverySum = 0.0;
  double totalProductsSum = 0.0;

  Map<String, Map<String, dynamic>> restaurantStats = {};

  Map<String, Map<String, dynamic>> typeStats = {
    'Обычная': {'count': 0, 'sum': 0.0},
    'Срочная': {'count': 0, 'sum': 0.0},
    'Город': {'count': 0, 'sum': 0.0},
    'Межгород': {'count': 0, 'sum': 0.0},
  };

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _resetStats() {
    totalOrders = 0;
    totalSum = 0.0;
    totalDeliverySum = 0.0;
    totalProductsSum = 0.0;
    restaurantStats = {};
    typeStats = {
      'Обычная': {'count': 0, 'sum': 0.0},
      'Срочная': {'count': 0, 'sum': 0.0},
      'Город': {'count': 0, 'sum': 0.0},
      'Межгород': {'count': 0, 'sum': 0.0},
    };
  }

  String _translateStatus(String? key) {
    if (key == null) return 'Новый';
    final s = key.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();
    switch (s) {
      case 'delivered':
      case 'доставлено': return 'Доставлено';
      case 'cancelled':
      case 'canceled':
      case 'отменено': return 'Отменено';
      case 'inprogress':
      case 'preparing':
      case 'впроцессе': return 'Готовится';
      default: return 'Новый';
    }
  }

  Future<void> _calculateStats() async {
    setState(() => loading = true);
    _resetStats();

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        await Future.wait([
          _processCollection(userDoc.reference, 'orders', 'Обычная'),
          _processCollection(userDoc.reference, 'delivery_orders', 'Срочная'),
          _processCollection(userDoc.reference, 'cityOrders', 'Город'),
          _processCollection(userDoc.reference, 'mejCityOrders', 'Межгород'),
        ]);
      }
    } catch (e) {
      debugPrint("Ошибка статистики: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _processCollection(DocumentReference userRef, String colPath, String label) async {
    final snap = await userRef.collection(colPath).get();

    for (var doc in snap.docs) {
      final data = doc.data();
      double orderTotal = 0.0;
      double deliveryPrice = 0.0;

      // --- ЛОГИКА РАСЧЕТА ПОЛЯ ЦЕНЫ ---
      if (label == 'Срочная') {
        // Твои поля из БД: totalCost и roadPrice
        orderTotal = (data['totalCost'] ?? 0).toDouble();
        deliveryPrice = (data['roadPrice'] ?? data['deliveryPrice'] ?? 0).toDouble();
      } else if (label == 'Город' || label == 'Межгород') {
        double base = (data['basePrice'] ?? 0).toDouble();
        double route = (data['routePrice'] ?? 0).toDouble();
        orderTotal = base + route;
        deliveryPrice = orderTotal;
      } else {
        // Обычные заказы
        orderTotal = (data['totalPrice'] ?? data['total'] ?? 0).toDouble();
        deliveryPrice = (data['deliveryPrice'] ?? 0).toDouble();
      }

      double productPrice = orderTotal - deliveryPrice;
      if (productPrice < 0) productPrice = 0;

      // Накопление итогов
      totalOrders++;
      totalSum += orderTotal;
      totalDeliverySum += deliveryPrice;
      totalProductsSum += productPrice;

      typeStats[label]!['count'] += 1;
      typeStats[label]!['sum'] += deliveryPrice;

      String restName = data['restaurantName'] ?? data['shopName'] ??
          (label == 'Срочная' ? 'Экспресс-доставка' :
          label == 'Город' || label == 'Межгород' ? 'Грузоперевозки' : 'Прочее');

      if (!restaurantStats.containsKey(restName)) {
        restaurantStats[restName] = {
          'count': 0,
          'prodSum': 0.0,
          'delivSum': 0.0,
          'statuses': <String, int>{},
        };
      }

      var r = restaurantStats[restName]!;
      r['count'] += 1;
      r['prodSum'] += productPrice;
      r['delivSum'] += deliveryPrice;

      String status = _translateStatus(data['status']?.toString());
      r['statuses'][status] = (r['statuses'][status] ?? 0) + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('ФИНАНСОВАЯ АНАЛИТИКА', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [IconButton(onPressed: _calculateStats, icon: const Icon(Icons.refresh, color: Colors.white))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainMoneyBlock(),
          const SizedBox(height: 20),
          const Text('Заработок курьеров по типам', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildTypeGrid(),
          const SizedBox(height: 24),
          const Text('Детализация по заведениям', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...restaurantStats.entries.map((e) => _buildRestaurantCard(e.key, e.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildMainMoneyBlock() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _moneyCircle('Оборот', totalSum, Colors.blue),
              _moneyCircle('Заказы', totalOrders.toDouble(), Colors.purple, isMoney: false),
            ],
          ),
          const Divider(height: 40),
          _moneyRow('За товары', totalProductsSum, Colors.orange),
          const SizedBox(height: 12),
          _moneyRow('Доход курьеров', totalDeliverySum, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildTypeGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2,
      children: typeStats.entries.map((e) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(e.key, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text('${e.value['sum'].toInt()} Руб', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${e.value['count']} зак.', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildRestaurantCard(String name, Map<String, dynamic> data) {
    double total = data['prodSum'] + data['delivSum'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${total.toInt()} Руб | ${data['count']} заказов'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _moneyRow('Товары', data['prodSum'], Colors.orange),
                const SizedBox(height: 8),
                _moneyRow('Доставка', data['delivSum'], Colors.teal),
                const Divider(),
                Wrap(
                  spacing: 6,
                  children: (data['statuses'] as Map<String, int>).entries.map((s) =>
                      Chip(
                        label: Text('${s.key}: ${s.value}', style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.blueGrey.withOpacity(0.05),
                      )
                  ).toList(),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _moneyCircle(String label, double val, Color color, {bool isMoney = true}) {
    return Column(
      children: [
        Text(isMoney ? '${val.toInt()} Руб' : val.toInt().toString(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _moneyRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
        Text('${amount.toInt()} Руб', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}