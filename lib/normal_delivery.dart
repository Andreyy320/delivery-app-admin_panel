import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart'; // Для объединения потоков

class AllCourierOrdersScreen extends StatefulWidget {
  const AllCourierOrdersScreen({super.key});

  @override
  State<AllCourierOrdersScreen> createState() => _AllCourierOrdersScreenState();
}

class _AllCourierOrdersScreenState extends State<AllCourierOrdersScreen> {
  String filterStatus = 'all'; // all / current / completed / delivered
  String filterType = 'all'; // all / normal / delivery / city / mejCity

  // --- Получаем все заказы в реальном времени ---
  Stream<List<Map<String, dynamic>>> _getAllOrdersRealtime() {
    // Поток заказов пользователей
    final userOrdersStream = FirebaseFirestore.instance.collection('users').snapshots()
        .asyncMap((usersSnapshot) async {
      List<Map<String, dynamic>> userOrders = [];
      for (var userDoc in usersSnapshot.docs) {
        final ordersSnapshot = await userDoc.reference.collection('orders').get();
        for (var orderDoc in ordersSnapshot.docs) {
          final data = orderDoc.data();
          data['userId'] = userDoc.id;
          data['type'] = 'normal';
          userOrders.add(data);
        }
      }
      return userOrders;
    });

    // Поток истории курьеров
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

    // Объединяем оба потока и сортируем
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

  // --- Фильтр по статусу и типу ---
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      final status = (order['status'] ?? '').toLowerCase();
      final type = (order['type'] ?? '').toLowerCase();

      final matchesStatus = filterStatus == 'all' ||
          (filterStatus == 'current' && (status == 'accepted' || status == 'in_progress')) ||
          (filterStatus == 'completed' && status == 'cancelled') ||
          (filterStatus == 'delivered' && status == 'delivered');

      final matchesType = filterType == 'all' || filterType == type;

      return matchesStatus && matchesType;
    }).toList();
  }

  // --- Цвет статуса ---
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'in_progress':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // --- Считаем сумму заказа ---
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
      appBar: AppBar(title: const Text('Все заказы курьеров')),
      body: Column(
        children: [
          // --- Фильтр по статусу ---
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButton<String>(
              value: filterStatus,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все статусы')),
                DropdownMenuItem(value: 'current', child: Text('Текущие')),
                DropdownMenuItem(value: 'delivered', child: Text('Доставленные')),
                DropdownMenuItem(value: 'completed', child: Text('Отменённые')),
              ],
              onChanged: (value) => setState(() => filterStatus = value!),
            ),
          ),

          // --- Фильтр по типу ---
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButton<String>(
              value: filterType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все типы')),
                DropdownMenuItem(value: 'normal', child: Text('Обычная')),
                DropdownMenuItem(value: 'delivery', child: Text('Срочная')),
                DropdownMenuItem(value: 'city', child: Text('Городская')),
                DropdownMenuItem(value: 'mejcity', child: Text('Межгород')),
              ],
              onChanged: (value) => setState(() => filterType = value!),
            ),
          ),

          // --- Список заказов ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllOrdersRealtime(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filteredOrders = _applyFilters(snapshot.data!);
                if (filteredOrders.isEmpty) return const Center(child: Text('Заказов нет'));

                return ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final status = order['status'] ?? '-';
                    final type = order['type'] ?? '-';
                    final clientName = order['clientName'] ?? order['userId'] ?? '-';
                    final totalPrice = getOrderPrice(order);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.local_shipping, color: _statusColor(status)),
                        title: Text('Клиент: $clientName'),
                        subtitle: Text('Статус: $status, Тип: $type, Сумма: $totalPrice ₽'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailsScreen(order: order),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Детали заказа -----------------
class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final createdAt = order['createdAt'] is Timestamp
        ? (order['createdAt'] as Timestamp).toDate()
        : null;
    final deliveredAt = order['deliveredAt'] is Timestamp
        ? (order['deliveredAt'] as Timestamp).toDate()
        : null;

    final items = order['items'] as List<dynamic>? ?? [];

    double totalPrice = 0;
    if (order['totalPrice'] != null) totalPrice = (order['totalPrice'] as num).toDouble();
    else if (order['totalCost'] != null) totalPrice = (order['totalCost'] as num).toDouble();
    else if (order['total'] != null) totalPrice = (order['total'] as num).toDouble();
    else if (items.isNotEmpty) {
      for (var item in items) {
        totalPrice += (item['price'] ?? 0) * (item['quantity'] ?? 1);
      }
    }

    final status = order['status'] ?? '-';
    final type = order['type'] ?? '-';

    // --- Адреса для всех типов ---
    String addressPickup = 'Не указано';
    String addressDropoff = 'Не указано';

    switch (type) {
      case 'normal':
        final deliveryLocation = order['deliveryLocation'] as Map<String, dynamic>? ?? {};
        if (deliveryLocation.isNotEmpty) {
          addressDropoff = '${deliveryLocation['lat'] ?? '-'}, ${deliveryLocation['lng'] ?? '-'}';
        }
        break;

      case 'city':
      case 'mejCity':
        if ((order['fromAddress'] ?? '').toString().isNotEmpty) {
          addressPickup = order['fromAddress'];
        }
        if ((order['toAddress'] ?? '').toString().isNotEmpty) {
          addressDropoff = order['toAddress'];
        }
        break;

      default:
        final pickup = order['pickup'] as Map<String, dynamic>? ?? {};
        final dropoff = order['dropoff'] as Map<String, dynamic>? ?? {};
        if (pickup.isNotEmpty) {
          addressPickup = '${pickup['lat'] ?? '-'}, ${pickup['lng'] ?? '-'}';
        }
        if (dropoff.isNotEmpty) {
          addressDropoff = '${dropoff['lat'] ?? '-'}, ${dropoff['lng'] ?? '-'}';
        }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Детали заказа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Клиент: ${order['clientName'] ?? '-'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Телефон: ${order['clientPhone'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Статус: $status'),
            Text('Тип: $type'),
            if (createdAt != null) Text('Создан: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}'),
            if (deliveredAt != null) Text('Доставлен: ${DateFormat('yyyy-MM-dd HH:mm').format(deliveredAt)}'),
            const SizedBox(height: 16),

            // Адреса
            Text('Адрес забора: $addressPickup'),
            Text('Адрес доставки: $addressDropoff'),
            if (order['dateTime'] != null) Text('Время доставки: ${order['dateTime']}'),
            const SizedBox(height: 16),

            Text('Сумма: $totalPrice ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Товары
            if (items.isNotEmpty) ...[
              const Text('Товары:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (var item in items)
                Text('- ${item['name'] ?? '-'} x${item['quantity'] ?? 1} (${item['price'] ?? 0} ₽)'),
            ],

            // Опции
            if (order['options'] != null && (order['options'] as List).isNotEmpty)
              Text('Опции: ${(order['options'] as List).join(', ')}'),

            // Комментарий
            if ((order['comment'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Комментарий: ${order['comment']}'),
              ),
          ],
        ),
      ),
    );
  }
}
