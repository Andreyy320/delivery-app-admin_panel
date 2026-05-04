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
      case 'доставлено': return 'Доставлено';
      case 'cancelled':
      case 'отменено': return 'Отменено';
      default: return status;
    }
  }

  // --- ПОТОК ВСЕХ ЗАКАЗОВ ИЗ ВСЕХ ПОЛЬЗОВАТЕЛЕЙ ---
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
        orderData['userId'] = userDoc.id; // ID клиента для обновления
        orderData['orderId'] = orderDoc.id; // ID заказа для обновления

        if (!orderData.containsKey('total')) {
          final items = (orderData['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
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
        'status': 'accepted', // Меняем статус на Принято
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Курьер $cName назначен!')),
        );
        setState(() {}); // Обновляем список
      }
    } catch (e) {
      debugPrint('Ошибка назначения: $e');
    }
  }

  // --- ДИАЛОГ ВЫБОРА КУРЬЕРА ---
  void _showAssignCourierDialog(String userId, String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Назначить курьера принудительно'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('couriers')
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Text('Нет активных курьеров в сети');

              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final c = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.delivery_dining, color: Colors.white)),
                    title: Text(c['name'] ?? 'Курьер'),
                    subtitle: Text(c['phone'] ?? ''),
                    onTap: () {
                      Navigator.pop(context);
                      _assignCourier(userId, orderId, docs[index].id, c['name'], c['phone']);
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

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allOrders) {
    return allOrders.where((order) {
      final name = (order['clientName'] ?? '').toString().toLowerCase();
      final statusFromDb = (order['status'] ?? '').toString().toLowerCase().replaceAll('_', '').trim();
      final matchesSearch = name.contains(searchQuery.toLowerCase());

      bool matchesStatus = filterStatus == 'all';
      if (!matchesStatus) {
        if (filterStatus == 'pending') {
          matchesStatus = (statusFromDb == 'pending' || statusFromDb == 'new' || statusFromDb == 'accepted');
        } else if (filterStatus == 'completed') {
          matchesStatus = (statusFromDb == 'completed' || statusFromDb == 'delivered' || statusFromDb == 'ready');
        } else if (filterStatus == 'cancelled') {
          matchesStatus = (statusFromDb == 'cancelled' || statusFromDb == 'canceled' || statusFromDb == 'отменено');
        }
      }
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    if (s == 'completed' || s == 'delivered' || s == 'ready') return Colors.green;
    if (s == 'cancelled' || s == 'canceled' || s == 'отменено') return Colors.red;
    if (s == 'pending' || s == 'new' || s == 'accepted' || s == 'принято') return Colors.orange;
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
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
                    hintText: 'Поиск по клиенту...',
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
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final filteredOrders = _applyFilter(snapshot.data ?? []);
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

  Widget _buildStatusChips() {
    final statuses = [
      {'id': 'all', 'label': 'Все'},
      {'id': 'pending', 'label': 'Активные'},
      {'id': 'completed', 'label': 'Завершено'},
      {'id': 'cancelled', 'label': 'Отмена'},
    ];
    return Row(
      children: statuses.map((s) {
        bool isSelected = filterStatus == s['id'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(s['label']!, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
            selected: isSelected,
            onSelected: (v) => setState(() => filterStatus = s['id']!),
            selectedColor: Colors.blueAccent,
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? '-';
    final color = _statusColor(status);
    final total = order['total'] ?? 0;
    final items = (order['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final bool hasCourier = order['courierId'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.shopping_bag, color: color, size: 20)),
        title: Text(order['clientName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(_translateStatus(status).toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.phone, 'Клиент:', order['clientPhone']),
                if (hasCourier) _infoRow(Icons.delivery_dining, 'Курьер:', '${order['courierName']}'),
                const Divider(),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item['name']} x${item['quantity']}', style: const TextStyle(fontSize: 13)),
                      Text('${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toInt()} ₽'),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ИТОГО:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${total.toInt()} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),

                // КНОПКА НАЗНАЧЕНИЯ (показывается только если курьера нет и заказ активен)
                if (!hasCourier && (status == 'new' || status == 'pending' || status == 'принято'))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignCourierDialog(order['userId'], order['orderId']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      icon: const Icon(Icons.person_add),
                      label: const Text('НАЗНАЧИТЬ КУРЬЕРА'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label $value', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}