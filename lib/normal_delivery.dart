import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class AllCourierOrdersScreen extends StatefulWidget {
  const AllCourierOrdersScreen({super.key});

  @override
  State<AllCourierOrdersScreen> createState() => _AllCourierOrdersScreenState();
}

class _AllCourierOrdersScreenState extends State<AllCourierOrdersScreen> {
  String filterStatus = 'all';
  String filterType = 'all';

  // --- ОБЩИЕ МЕТОДЫ ПЕРЕВОДА ---
  String _translateStatus(String status) {
    final s = status.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (s == 'accepted' || s == 'принято') return 'Принят';
    if (s == 'inprogress' || s == 'впути') return 'В пути';
    if (s == 'delivered' || s == 'delivery' || s == 'доставлено') return 'Доставлен';
    if (s == 'cancelled' || s == 'отменено') return 'Отменен';
    if (s == 'ready' || s=='READY') return 'Готов';
    return status;
  }

  String _translateType(String type) {
    final t = type.toLowerCase();
    if (t == 'normal') return 'Обычная';
    if (t == 'delivery') return 'Срочная';
    if (t == 'city') return 'Город';
    if (t == 'mejcity' || t == 'intercity') return 'Межгород';
    return type;
  }

  // --- ЛОГИКА ПОТОКОВ ---
  Stream<List<Map<String, dynamic>>> _getAllOrdersRealtime() {
    final userOrdersStream = FirebaseFirestore.instance.collection('users').snapshots()
        .asyncMap((usersSnapshot) async {
      List<Map<String, dynamic>> userOrders = [];
      for (var userDoc in usersSnapshot.docs) {
        final ordersSnapshot = await userDoc.reference.collection('orders').get();
        for (var orderDoc in ordersSnapshot.docs) {
          final data = orderDoc.data();
          data['userId'] = userDoc.id;
          if (data['type'] == null) data['type'] = 'normal';
          userOrders.add(data);
        }
      }
      return userOrders;
    });

    final courierOrdersStream = FirebaseFirestore.instance.collection('couriers').snapshots()
        .asyncMap((couriersSnapshot) async {
      List<Map<String, dynamic>> courierOrders = [];
      for (var courierDoc in couriersSnapshot.docs) {
        final historySnapshot = await courierDoc.reference.collection('history').get();
        for (var orderDoc in historySnapshot.docs) {
          final data = orderDoc.data();
          data['courierId'] = courierDoc.id;
          courierOrders.add(data);
        }
      }
      return courierOrders;
    });

    return Rx.combineLatest2(userOrdersStream, courierOrdersStream, (a, b) {
      final allOrders = [...a, ...b];
      allOrders.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(2000);
        final bTime = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return allOrders;
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      final status = (order['status'] ?? '').toLowerCase().replaceAll('_', '');
      final type = (order['type'] ?? '').toLowerCase();

      final matchesStatus = filterStatus == 'all' ||
          (filterStatus == 'current' && (status == 'accepted' || status == 'inprogress')) ||
          (filterStatus == 'completed' && status == 'cancelled') ||
          (filterStatus == 'delivered' && (status == 'delivered' || status == 'delivery'));

      final matchesType = filterType == 'all' || filterType == type;
      return matchesStatus && matchesType;
    }).toList();
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', '');
    if (s == 'accepted' || s == 'inprogress') return Colors.orange;
    if (s == 'delivered' || s == 'delivery') return Colors.green;
    if (s == 'cancelled') return Colors.red;
    return Colors.blueGrey;
  }

  double getOrderPrice(Map<String, dynamic> order) {
    if (order['totalPrice'] != null) return (order['totalPrice'] as num).toDouble();
    if (order['totalCost'] != null) return (order['totalCost'] as num).toDouble();
    if (order['total'] != null) return (order['total'] as num).toDouble();
    if (order['items'] != null) {
      final items = order['items'] as List<dynamic>;
      double sum = 0;
      for (var item in items) {
        sum += (item['price'] ?? 0) * (item['quantity'] ?? 1);
      }
      return sum;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('ЖУРНАЛ ЗАКАЗОВ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _buildFilterChips('status'),
                const SizedBox(height: 4),
                _buildFilterChips('type'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllOrdersRealtime(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                }
                final filteredOrders = _applyFilters(snapshot.data ?? []);
                if (filteredOrders.isEmpty) {
                  return const Center(child: Text('Заказов не найдено', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) => _buildOrderCard(filteredOrders[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(String category) {
    bool isStatus = category == 'status';
    List<Map<String, String>> items = isStatus ? [
      {'id': 'all', 'label': 'Все'},
      {'id': 'current', 'label': 'Текущие'},
      {'id': 'delivered', 'label': 'Доставлены'},
      {'id': 'completed', 'label': 'Отмена'},
    ] : [
      {'id': 'all', 'label': 'Все типы'},
      {'id': 'normal', 'label': 'Обычная'},
      {'id': 'delivery', 'label': 'Срочная'},
      {'id': 'city', 'label': 'Город'},
      {'id': 'mejcity', 'label': 'Межгород'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((item) {
          bool selected = isStatus ? filterStatus == item['id'] : filterType == item['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: ChoiceChip(
              // Текст теперь всегда яркий и читаемый
              label: Text(
                item['label']!,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: selected,
              onSelected: (v) => setState(() => isStatus ? filterStatus = item['id']! : filterType = item['id']!),

              // Активная кнопка — насыщенный синий
              selectedColor: Colors.blueAccent[700],

              // Неактивная кнопка — глубокий темный (чтобы не сливалось с фоном шапки)
              backgroundColor: const Color(0xFF1E293B),

              showCheckmark: false,
              elevation: selected ? 4 : 0,

              // Четкая рамка, чтобы кнопки были визуально отделены
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected ? Colors.blueAccent : Colors.white24,
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? '-').toString();
    final type = (order['type'] ?? 'normal').toString();
    final price = getOrderPrice(order);
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.local_shipping_outlined, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['clientName'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text('${_translateType(type)} • ${price.toInt()} ₽', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_translateStatus(status).toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderDetailsScreen({super.key, required this.order});

  // Локальные методы перевода для деталей
  String _ruStatus(String s) {
    final status = s.toLowerCase().replaceAll('_', '');
    if (status == 'accepted') return 'ПРИНЯТ';
    if (status == 'READY') return 'ГОТОВ';
    if (status == 'inprogress') return 'В ПУТИ';
    if (status == 'delivered' || status == 'delivery') return 'ДОСТАВЛЕН';
    if (status == 'canceled') return 'ОТМЕНЕН';
    return s.toUpperCase();
  }

  String _ruType(String t) {
    final type = t.toLowerCase();
    if (type == 'normal') return 'Обычная доставка';
    if (type == 'delivery') return 'Срочный вызов';
    if (type == 'city') return 'По городу';
    if (type == 'mejcity' || type == 'intercity') return 'Межгород';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List<dynamic>? ?? [];
    double total = 0;
    if (order['totalPrice'] != null) total = (order['totalPrice'] as num).toDouble();
    else if (order['totalCost'] != null) total = (order['totalCost'] as num).toDouble();
    else { for (var i in items) total += (i['price'] ?? 0) * (i['quantity'] ?? 1); }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('ДЕТАЛИ ЗАКАЗА', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(children: [
            _row('Клиент', order['clientName'] ?? '—', isBold: true),
            _row('Телефон', order['clientPhone'] ?? '—'),
            _row('Статус', _ruStatus(order['status'] ?? '-'), color: Colors.blueAccent),
            _row('Тип', _ruType(order['type'] ?? 'normal')),
          ]),
          const SizedBox(height: 16),
          _card(title: 'МАРШРУТ', children: [
            _row('Откуда', order['fromAddress'] ?? 'По GPS'),
            _row('Куда', order['toAddress'] ?? 'По GPS'),
          ]),
          const SizedBox(height: 16),
          _card(title: 'ОПЛАТА', children: [
            _row('Итого', '${total.toInt()} ₽', isBold: true, color: Colors.green),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _card(title: 'СОСТАВ', children: [
              for (var i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${i['name']} x${i['quantity']}', style: const TextStyle(fontSize: 14)),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _card({String? title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? const Color(0xFF1E293B),
            fontSize: 14,
          ))),
        ],
      ),
    );
  }
}