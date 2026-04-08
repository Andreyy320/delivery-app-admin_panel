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
  String filterStatus = 'all';
  final TextEditingController searchController = TextEditingController();

  // --- МЕТОД ПЕРЕВОДА ДЛЯ UI ---
  String _translateStatus(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    switch (s) {
      case 'new': return 'Новый';
      case 'pending': return 'В ожидании';
      case 'accepted':
      case 'принято': return 'Принято';
      case 'inprogress':
      case 'впроцессе': return 'В процессе';
      case 'ready':
      case 'готовквыдаче': return 'Готов';
      case 'delivered':
      case 'delivery':
      case 'доставлено': return 'Доставлено';
      case 'cancelled':
      case 'canceled':
      case 'отменено': return 'Отменено';
      case 'preparing': return 'Подготовка';
      default: return status;
    }
  }

  Stream<List<Map<String, dynamic>>> _getAllOrdersStream() async* {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final ordersList = <Map<String, dynamic>>[];
    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final userName = userData['name'] ?? '-';
      final userPhone = userData['phone'] ?? '-';
      final ordersSnapshot = await userDoc.reference.collection('orders').get();
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
    ordersList.sort((a, b) {
      final aTime = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(2000);
      final bTime = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(2000);
      return bTime.compareTo(aTime);
    });
    yield ordersList;
  }

  // --- ИСПРАВЛЕННАЯ ЛОГИКА ФИЛЬТРАЦИИ ---
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allOrders) {
    return allOrders.where((order) {
      final name = (order['clientName'] ?? '').toString().toLowerCase();
      // Очищаем статус из БД для корректного сравнения
      final statusFromDb = (order['status'] ?? '').toString().toLowerCase().replaceAll('_', '').trim();

      final matchesSearch = name.contains(searchQuery.toLowerCase());

      // Сравниваем статус из БД с ID выбранной кнопки
      bool matchesStatus = filterStatus == 'all';
      if (!matchesStatus) {
        if (filterStatus == 'pending') {
          matchesStatus = (statusFromDb == 'pending' || statusFromDb == 'new' || statusFromDb == 'принято');
        } else if (filterStatus == 'completed') {
          matchesStatus = (statusFromDb == 'completed' || statusFromDb == 'delivered' || statusFromDb == 'доставлено' || statusFromDb == 'ready');
        } else if (filterStatus == 'cancelled') {
          matchesStatus = (statusFromDb == 'cancelled' || statusFromDb == 'canceled' || statusFromDb == 'отменено');
        }
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    if (s == 'completed' || s == 'delivered' || s == 'доставлено' || s == 'ready') return Colors.green;
    if (s == 'cancelled' || s == 'canceled' || s == 'отменено') return Colors.red;
    if (s == 'pending' || s == 'new' || s == 'принято') return Colors.orange;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('УПРАВЛЕНИЕ ЗАКАЗАМИ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.search, color: Colors.white60),
                    hintText: 'Поиск по имени клиента...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                const SizedBox(height: 12),
                _buildStatusChips(),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                }
                final filteredOrders = _applyFilter(snapshot.data ?? []);

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Заказов не найдено', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) => _buildOrderCard(filteredOrders[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ПОЛНОСТЬЮ ПЕРЕРАБОТАННЫЕ ФИЛЬТРЫ ДЛЯ МАКСИМАЛЬНОЙ ВИДИМОСТИ ---
  Widget _buildStatusChips() {
    final statuses = [
      {'id': 'all', 'label': 'Все'},
      {'id': 'pending', 'label': 'Ожидание'},
      {'id': 'completed', 'label': 'Готово'},
      {'id': 'cancelled', 'label': 'Отмена'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((s) {
          bool isSelected = filterStatus == s['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                s['label']!,
                style: TextStyle(
                  // Активный текст — белый, неактивный — светло-серый (почти белый)
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (v) => setState(() => filterStatus = s['id']!),

              // Цвет фона нажатой кнопки
              selectedColor: Colors.blueAccent[700],

              // Цвет фона неактивной кнопки (делаем темнее, чтобы белый текст выделялся)
              backgroundColor: const Color(0xFF1E293B),

              showCheckmark: false,
              elevation: isSelected ? 4 : 0,

              // Добавляем рамку для неактивных кнопок, чтобы их было видно
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.blueAccent : Colors.white24,
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
    final status = order['status'] ?? '-';
    final color = _statusColor(status);
    final total = order['total'] ?? 0;
    final createdAt = order['createdAt'] is Timestamp ? (order['createdAt'] as Timestamp).toDate() : null;
    final items = (order['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.shopping_bag_outlined, color: color),
        ),
        title: Text(order['clientName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(_translateStatus(status).toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        trailing: Text('${total.toInt()} ₽',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.phone_android, 'Телефон:', order['clientPhone']),
                if (createdAt != null)
                  _infoRow(Icons.calendar_today, 'Дата:', DateFormat('dd.MM.yyyy HH:mm').format(createdAt)),
                if (order['paymentMethod'] != null)
                  _infoRow(Icons.payment, 'Оплата:', order['paymentMethod']),
                const Divider(height: 24),
                const Text('СОСТАВ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item['name']} x${item['quantity']}', style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
                      Text('${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toInt()} ₽',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                )).toList(),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ИТОГО:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${total.toInt()} ₽', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}