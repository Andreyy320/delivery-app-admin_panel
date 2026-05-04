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

  // Ключ: Название заведения
  // Значение: {count: int, sum: double, statuses: {statusName: count}}
  Map<String, Map<String, dynamic>> restaurantStats = {};

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  // --- ВСПОМОГАТЕЛЬНЫЙ ПЕРЕВОД СТАТУСОВ ДЛЯ ГРУППИРОВКИ ---
  String _translateStatus(String key) {
    final s = key.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();
    switch (s) {
      case 'new': return 'Новый';
      case 'pending':
      case 'accepted':
      case 'принято': return 'Принято';
      case 'inprogress':
      case 'preparing':
      case 'впроцессе': return 'Готовится';
      case 'delivered':
      case 'доставлено': return 'Доставлено';
      case 'cancelled':
      case 'canceled':
      case 'отменено': return 'Отменено';
      case 'ready':
      case 'готовквыдаче': return 'Готов';
      case 'ontheway':
      case 'впути': return 'В пути';
      default: return key;
    }
  }

  // --- ЛОГИКА СБОРА ДАННЫХ ---
  Future<void> _calculateStats() async {
    setState(() => loading = true);

    int tempTotalOrders = 0;
    double tempTotalSum = 0.0;
    Map<String, Map<String, dynamic>> tempRestStats = {};

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final ordersSnapshot = await userDoc.reference.collection('orders').get();

        for (var orderDoc in ordersSnapshot.docs) {
          final data = orderDoc.data();
          double price = _parsePrice(data);
          String restName = data['restaurantName'] ?? data['shopName'] ?? 'Прочие товары';
          String rawStatus = (data['status'] ?? 'new').toString();
          String translatedStatus = _translateStatus(rawStatus);

          tempTotalOrders++;
          tempTotalSum += price;

          // Инициализируем ресторан, если его еще нет
          if (!tempRestStats.containsKey(restName)) {
            tempRestStats[restName] = {
              'count': 0,
              'sum': 0.0,
              'statuses': <String, int>{}, // Вложенная мапа для статусов
            };
          }

          tempRestStats[restName]!['count'] += 1;
          tempRestStats[restName]!['sum'] += price;

          // Считаем статусы внутри этого заведения
          Map<String, int> statMap = tempRestStats[restName]!['statuses'];
          statMap[translatedStatus] = (statMap[translatedStatus] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    if (mounted) {
      setState(() {
        totalOrders = tempTotalOrders;
        totalSum = tempTotalSum;
        restaurantStats = tempRestStats;
        loading = false;
      });
    }
  }

  double _parsePrice(Map<String, dynamic> data) {
    final price = (data['total'] ?? data['totalPrice'] ?? 0) as num;
    return price.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ДЕТАЛЬНАЯ АНАЛИТИКА',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2, fontSize: 14)),
            Text('Админ: ${widget.currentAdminName}',
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : RefreshIndicator(
        onRefresh: _calculateStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderStats(),
            const SizedBox(height: 24),
            const Text('Статистика по заведениям',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),

            if (restaurantStats.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('Данных пока нет'),
              ))
            else
              ...restaurantStats.entries.map((entry) => _buildExpandableRestaurantCard(entry.key, entry.value)).toList(),
          ],
        ),
      ),
    );
  }

  // --- КАРТОЧКА С РАСКРЫВАЮЩИМСЯ СПИСКОМ ---
  Widget _buildExpandableRestaurantCard(String name, Map<String, dynamic> data) {
    double sum = data['sum'];
    int count = data['count'];
    Map<String, int> statuses = data['statuses'];
    double percent = totalSum > 0 ? (sum / totalSum) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ExpansionTile(
        shape: const Border(), // Убираем стандартные границы при раскрытии
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('${sum.toInt()} ₽ | $count зак.', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                const Text('СТАТУСЫ ЗАКАЗОВ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                const SizedBox(height: 12),

                // Сетка со статусами
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statuses.entries.map((st) => _buildStatusBadge(st.key, st.value)).toList(),
                ),

                const SizedBox(height: 20),
                const Text('ДОЛЯ ОТ ОБЩЕЙ ВЫРУЧКИ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    backgroundColor: Colors.grey[100],
                    color: Colors.blueAccent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${percent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Виджет для отдельного статуса (например, "Доставлено: 5")
  Widget _buildStatusBadge(String status, int count) {
    Color color;
    switch (status) {
      case 'Доставлено': color = Colors.green; break;
      case 'Отменено': color = Colors.red; break;
      case 'Новый': color = Colors.orange; break;
      case 'Готовится': color = Colors.blue; break;
      case 'В пути': color = Colors.purple; break;
      default: color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(count.toString(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    return Row(
      children: [
        _buildInfoTile('Заказов', totalOrders.toString(), Icons.receipt, Colors.blueAccent),
        const SizedBox(width: 12),
        _buildInfoTile('Оборот', '${totalSum.toInt()} ₽', Icons.wallet, Colors.green),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}