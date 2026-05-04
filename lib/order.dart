import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
      case 'доставлено': return 'Доставлено';
      case 'cancelled':
      case 'отменено': return 'Отменено';
      default: return status;
    }
  }

  // --- УЛУЧШЕННЫЙ ПОТОК ЗАКАЗОВ (REAL-TIME) ---
  Stream<List<Map<String, dynamic>>> _getAllOrdersStream() {
    // Слушаем всех пользователей
    return FirebaseFirestore.instance.collection('users').snapshots().transform(
      StreamTransformer.fromHandlers(
        handleData: (usersSnapshot, sink) async {
          List<Map<String, dynamic>> allOrders = [];

          for (var userDoc in usersSnapshot.docs) {
            final userData = userDoc.data();
            final userName = userData['name'] ?? 'Без имени';
            final userPhone = userData['phone'] ?? '-';

            // Получаем снимки заказов (get здесь заменен на логику обработки во внешнем стриме для простоты,
            // но для полной реактивности заказов лучше оставить подписку)
            final ordersSnapshot = await userDoc.reference.collection('orders').get();

            for (var orderDoc in ordersSnapshot.docs) {
              final orderData = orderDoc.data();

              orderData['orderId'] = orderDoc.id;
              orderData['userId'] = userDoc.id;
              orderData['clientName'] ??= userName;
              orderData['clientPhone'] ??= userPhone;

              if (orderData['total'] == null) {
                final items = (orderData['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                double total = 0;
                for (var item in items) {
                  total += (item['price'] ?? 0) * (item['quantity'] ?? 1);
                }
                orderData['total'] = total;
              }
              allOrders.add(orderData);
            }
          }

          allOrders.sort((a, b) {
            final aTime = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(2000);
            final bTime = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(2000);
            return bTime.compareTo(aTime);
          });

          sink.add(allOrders);
        },
      ),
    );
  }

  // --- ЛОГИКА НАЗНАЧЕНИЯ КУРЬЕРА ---
  Future<void> _assignCourier(String userId, String orderId, String cId, String cName, String cPhone) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .update({
        'courierId': cId,
        'courierName': cName,
        'courierPhone': cPhone,
        'status': 'accepted',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Курьер $cName успешно назначен!')),
        );
      }
    } catch (e) {
      debugPrint('Ошибка назначения курьера: $e');
    }
  }

  // --- ДИАЛОГ ВЫБОРА КУРЬЕРА ---
  void _showAssignCourierDialog(String userId, String orderId) {
    if (userId.isEmpty || orderId.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбор курьера'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('couriers')
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Text('Нет активных курьеров');

              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final c = docs[index].data() as Map<String, dynamic>;
                  final name = c['name'] ?? 'Без имени';
                  final phone = c['phone'] ?? '-';

                  return ListTile(
                    leading: const Icon(Icons.delivery_dining, color: Colors.orange),
                    title: Text(name),
                    subtitle: Text(phone),
                    onTap: () {
                      Navigator.pop(context);
                      _assignCourier(userId, orderId, docs[index].id, name, phone);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    if (s == 'completed' || s == 'delivered' || s == 'ready') return Colors.green;
    if (s == 'cancelled' || s == 'canceled' || s == 'отменено') return Colors.red;
    if (s == 'pending' || s == 'new' || s == 'accepted' || s == 'принято') return Colors.orange;
    return Colors.blueGrey;
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allOrders) {
    return allOrders.where((order) {
      final name = (order['clientName'] ?? '').toString().toLowerCase();
      final statusFromDb = (order['status'] ?? '').toString().toLowerCase().replaceAll('_', '').trim();
      final matchesSearch = name.contains(searchQuery.toLowerCase());

      bool matchesStatus = filterStatus == 'all';
      if (!matchesStatus) {
        if (filterStatus == 'pending') {
          matchesStatus = (statusFromDb == 'pending' || statusFromDb == 'new' || statusFromDb == 'accepted' || statusFromDb == 'принято' || statusFromDb == 'inprogress');
        } else if (filterStatus == 'completed') {
          matchesStatus = (statusFromDb == 'completed' || statusFromDb == 'delivered' || statusFromDb == 'ready');
        } else if (filterStatus == 'cancelled') {
          matchesStatus = (statusFromDb == 'cancelled' || statusFromDb == 'canceled' || statusFromDb == 'отменено');
        }
      }
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('ЗАКАЗЫ (АДМИН)', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Поиск клиента...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                _buildStatusChips(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final data = _applyFilter(snapshot.data ?? []);
                if (data.isEmpty) return const Center(child: Text('Заказов не найдено'));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  itemBuilder: (context, index) => _buildOrderCard(data[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    final types = [
      {'id': 'all', 'name': 'Все'},
      {'id': 'pending', 'name': 'Активные'},
      {'id': 'completed', 'name': 'Выполнены'},
      {'id': 'cancelled', 'name': 'Отмена'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSel = filterStatus == t['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t['name']!, style: TextStyle(color: isSel ? Colors.white : Colors.white70)),
              selected: isSel,
              selectedColor: Colors.blueAccent,
              backgroundColor: const Color(0xFF1E293B),
              onSelected: (v) => setState(() => filterStatus = t['id']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'new').toString();
    final color = _statusColor(status);

    final String? courierId = order['courierId'];
    // Приоритет: Имя -> Телефон -> Заглушка
    final String courierDisplay = order['courierName'] ?? order['courierPhone'] ?? 'НЕ НАЗНАЧЕН';

    final userId = order['userId'] ?? '';
    final orderId = order['orderId'] ?? '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(order['clientName'] ?? 'Клиент', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_translateStatus(status), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.phone, 'Клиент:', order['clientPhone'] ?? '-'),
                _infoRow(Icons.delivery_dining, 'Курьер:', courierDisplay),
                const Divider(),
                ...(order['items'] as List? ?? []).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item['name']} x${item['quantity']}'),
                      Text('${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toInt()} ₽'),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ИТОГО:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${(order['total'] ?? 0).toInt()} ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                if ((courierId == null || courierId == 'courierId' || courierId.isEmpty) &&
                    status != 'delivered' && status != 'cancelled')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAssignCourierDialog(userId, orderId),
                        icon: const Icon(Icons.person_add),
                        label: const Text('НАЗНАЧИТЬ КУРЬЕРА'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 5),
        Text('$label $value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}