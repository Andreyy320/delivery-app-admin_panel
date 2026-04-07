import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrdersAdminScreen extends StatefulWidget {
  const OrdersAdminScreen({super.key});

  @override
  State<OrdersAdminScreen> createState() => _OrdersAdminScreenState();
}

class _OrdersAdminScreenState extends State<OrdersAdminScreen> {
  String searchQuery = '';
  String filterStatus = 'all'; // all / pending / completed / cancelled

  final TextEditingController searchController = TextEditingController();

  // ---------------- Получаем все заказы всех пользователей ----------------
  Stream<List<Map<String, dynamic>>> _getAllOrdersStream() async* {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

    final ordersList = <Map<String, dynamic>>[];

    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final userName = userData['name'] ?? '-';
      final userPhone = userData['phone'] ?? '-';

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('orders')
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        orderData['clientName'] = userName;
        orderData['clientPhone'] = userPhone;
        orderData['userId'] = userDoc.id;
        orderData['orderId'] = orderDoc.id;

        final items = (orderData['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        if (!orderData.containsKey('total')) {
          double total = 0;
          for (var item in items) {
            total += (item['price'] ?? 0) * (item['quantity'] ?? 1);
          }
          orderData['total'] = total;
        }

        ordersList.add(orderData);
      }
    }

    // Сортировка по дате создания (новые сверху)
    ordersList.sort((a, b) {
      final aTime = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(2000);
      final bTime = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(2000);
      return bTime.compareTo(aTime);
    });

    yield ordersList;
  }

  // ---------------- Фильтрация ----------------
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allOrders) {
    return allOrders.where((order) {
      final name = (order['clientName'] ?? '').toString().toLowerCase();
      final status = (order['status'] ?? '').toString().toLowerCase();

      final matchesSearch = name.contains(searchQuery.toLowerCase());
      final matchesStatus = filterStatus == 'all' || filterStatus == status;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ---------------- Цвет статуса ----------------
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админка: Заказы'),
      ),
      body: Column(
        children: [
          // ---------------- Поиск ----------------
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по имени клиента',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),

          // ---------------- Фильтр по статусу ----------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: filterStatus,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все статусы')),
                DropdownMenuItem(value: 'pending', child: Text('В ожидании')),
                DropdownMenuItem(value: 'completed', child: Text('Выполнено')),
                DropdownMenuItem(value: 'cancelled', child: Text('Отменено')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => filterStatus = value);
              },
            ),
          ),

          // ---------------- Список заказов ----------------
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final allOrders = snapshot.data ?? [];
                final filteredOrders = _applyFilter(allOrders);

                if (filteredOrders.isEmpty) {
                  return const Center(child: Text('Заказов нет'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];

                      final createdAt = order['createdAt'] is Timestamp
                          ? (order['createdAt'] as Timestamp).toDate()
                          : null;

                      final items = (order['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

                      final total = order['total'] ?? 0;
                      final status = order['status'] ?? '-';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          leading: Icon(Icons.shopping_cart, color: _statusColor(status)),
                          title: Text('Клиент: ${order['clientName']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Телефон: ${order['clientPhone']}'),
                              Text('Статус: $status', style: TextStyle(color: _statusColor(status))),
                              if (createdAt != null)
                                Text('Создан: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}'),
                              if (order['paymentMethod'] != null)
                                Text('Оплата: ${order['paymentMethod']}'),
                            ],
                          ),
                          children: [
                            ...items.map<Widget>((item) {
                              final i = Map<String, dynamic>.from(item);
                              final itemTotal = (i['price'] ?? 0) * (i['quantity'] ?? 1);
                              return ListTile(
                                title: Text(i['name'] ?? '-'),
                                subtitle: Text('Количество: ${i['quantity'] ?? 0}'),
                                trailing: Text('$itemTotal \$'),
                              );
                            }).toList(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                              child: Text(
                                'Итого: $total \$',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
