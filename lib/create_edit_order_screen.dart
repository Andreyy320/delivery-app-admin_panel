import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class AdminStatisticsScreen extends StatefulWidget {
  final String currentAdminName;

  const AdminStatisticsScreen({super.key, required this.currentAdminName});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  bool loading = true;
  String? error;

  int totalOrders = 0;
  int cancelledOrders = 0;
  double totalSum = 0.0;
  double totalDeliverySum = 0.0;
  double totalProductsSum = 0.0;

  // по заведениям + отдельная строка для индивидуальных доставок
  Map<String, Map<String, dynamic>> restaurantStats = {};

  Map<String, Map<String, dynamic>> typeStats = {};

  static const String kIndividual = 'Индивидуальная доставка';

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _resetStats() {
    totalOrders = 0;
    cancelledOrders = 0;
    totalSum = 0.0;
    totalDeliverySum = 0.0;
    totalProductsSum = 0.0;
    restaurantStats = {};
    typeStats = {
      'Из заведений': {'count': 0, 'sum': 0.0},
      'Индивидуальные': {'count': 0, 'sum': 0.0},
    };
  }

  String _translateStatus(String? key) {
    if (key == null) return 'Новый';
    final s = key.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();
    switch (s) {
      case 'delivered':
      case 'completed':
        return 'Доставлено';
      case 'cancelled':
      case 'canceled':
        return 'Отменено';
      case 'inprogress':
      case 'delivery':
        return 'В пути';
      case 'preparing':
        return 'Готовится';
      case 'ready':
        return 'Готов';
      case 'actionrequired':
      case 'zamena':
        return 'Замена';
      default:
        return 'Новый';
    }
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  Map<String, dynamic> _bucket(String name) {
    return restaurantStats.putIfAbsent(
        name, () => {'count': 0, 'prodSum': 0.0, 'delivSum': 0.0, 'statuses': <String, int>{}});
  }

  Future<void> _calculateStats() async {
    setState(() {
      loading = true;
      error = null;
    });
    _resetStats();

    try {
      final r = await http
          .get(Uri.parse('${Api.baseUrl}/api/admin/stats'), headers: Api.headers)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        String msg = 'Ошибка сервера (${r.statusCode})';
        try {
          final b = jsonDecode(r.body);
          if (b is Map && b['error'] != null) msg = b['error'].toString();
        } catch (_) {}
        throw Exception(msg);
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;

      // --- заказы из заведений ---
      for (final raw in (body['orders'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(raw as Map);
        final name = (row['name'] ?? 'Прочее').toString();
        final status = _translateStatus(row['status']?.toString());
        final cnt = _n(row['cnt']).toInt();
        final items = _n(row['items_sum']).toDouble();
        final deliv = _n(row['delivery_sum']).toDouble();

        final b = _bucket(name);
        (b['statuses'] as Map<String, int>)[status] =
            ((b['statuses'] as Map<String, int>)[status] ?? 0) + cnt;

        if (status == 'Отменено') {
          cancelledOrders += cnt; // отменённые в деньги не входят
          continue;
        }
        b['count'] += cnt;
        b['prodSum'] += items;
        b['delivSum'] += deliv;

        totalOrders += cnt;
        totalProductsSum += items;
        totalDeliverySum += deliv;
        totalSum += items + deliv;
        typeStats['Из заведений']!['count'] += cnt;
        typeStats['Из заведений']!['sum'] += deliv;
      }

      // --- индивидуальные доставки ---
      for (final raw in (body['individual'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(raw as Map);
        final status = _translateStatus(row['status']?.toString());
        final cnt = _n(row['cnt']).toInt();
        final sum = _n(row['sum']).toDouble();

        final b = _bucket(kIndividual);
        (b['statuses'] as Map<String, int>)[status] =
            ((b['statuses'] as Map<String, int>)[status] ?? 0) + cnt;

        if (status == 'Отменено') {
          cancelledOrders += cnt;
          continue;
        }
        b['count'] += cnt;
        b['delivSum'] += sum;

        totalOrders += cnt;
        totalDeliverySum += sum;
        totalSum += sum;
        typeStats['Индивидуальные']!['count'] += cnt;
        typeStats['Индивидуальные']!['sum'] += sum;
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final sortedRestaurants = restaurantStats.entries.toList()
      ..sort((a, b) => ((b.value['prodSum'] + b.value['delivSum']) as double)
          .compareTo((a.value['prodSum'] + a.value['delivSum']) as double));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('ФИНАНСОВАЯ АНАЛИТИКА',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
              onPressed: _calculateStats,
              icon: const Icon(Icons.refresh, color: Colors.white))
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            TextButton(onPressed: _calculateStats, child: const Text('Повторить')),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _calculateStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildMainMoneyBlock(),
            const SizedBox(height: 20),
            const Text('Доход от доставки по типам',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildTypeGrid(),
            const SizedBox(height: 24),
            const Text('Детализация',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (sortedRestaurants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Данных пока нет')),
              ),
            ...sortedRestaurants.map((e) => _buildRestaurantCard(e.key, e.value)),
          ],
        ),
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
              _moneyCircle('Отменено', cancelledOrders.toDouble(), Colors.red, isMoney: false),
            ],
          ),
          const Divider(height: 40),
          _moneyRow('За товары', totalProductsSum, Colors.orange),
          const SizedBox(height: 12),
          _moneyRow('Доход от доставки', totalDeliverySum, Colors.teal),
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
      children: typeStats.entries
          .map((e) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
        BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(e.key,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text('${(e.value['sum'] as double).toInt()} Руб',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${e.value['count']} зак.',
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
          ],
        ),
      ))
          .toList(),
    );
  }

  Widget _buildRestaurantCard(String name, Map<String, dynamic> data) {
    final double total = data['prodSum'] + data['delivSum'];
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
                if (name != kIndividual) ...[
                  _moneyRow('Товары', data['prodSum'], Colors.orange),
                  const SizedBox(height: 8),
                ],
                _moneyRow('Доставка', data['delivSum'], Colors.teal),
                const Divider(),
                Wrap(
                  spacing: 6,
                  children: (data['statuses'] as Map<String, int>)
                      .entries
                      .map((s) => Chip(
                    label: Text('${s.key}: ${s.value}',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.blueGrey.withOpacity(0.05),
                  ))
                      .toList(),
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
            Text(label,
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
        Text('${amount.toInt()} Руб', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}