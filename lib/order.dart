import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api.dart';

class OrdersAdminScreen extends StatefulWidget {
  const OrdersAdminScreen({super.key});

  @override
  State<OrdersAdminScreen> createState() => _OrdersAdminScreenState();
}

class _OrdersAdminScreenState extends State<OrdersAdminScreen> {
  String searchQuery = '';
  String filterStatus = 'all';
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ---------- СЕРВЕР ----------
  Future<void> _load({bool spinner = true}) async {
    if (spinner) setState(() => _loading = true);
    try {
      final r = await http
          .get(Uri.parse('${Api.baseUrl}/api/admin/orders'), headers: Api.headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        String msg = 'Ошибка сервера (${r.statusCode})';
        try {
          final b = jsonDecode(r.body);
          if (b is Map && b['error'] != null) msg = b['error'].toString();
        } catch (_) {}
        throw Exception(msg);
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (body['orders'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ---------- ХЕЛПЕРЫ ----------
  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  List<Map<String, dynamic>> _itemsOf(dynamic raw) {
    dynamic v = raw;
    if (v is String) {
      try {
        v = jsonDecode(v);
      } catch (_) {}
    }
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // Размер и добавки позиции одной строкой
  String _itemTags(Map<String, dynamic> item) {
    final tags = <String>[];
    final size = (item['size'] ?? '').toString().trim();
    if (size.isNotEmpty && size != 'null') tags.add(size);
    final mods = item['modifiers'];
    if (mods is List) {
      for (final m in mods) {
        final n = (m is Map ? m['name'] : m)?.toString().trim() ?? '';
        if (n.isNotEmpty) tags.add(n);
      }
    }
    return tags.join(', ');
  }

  String _translateStatus(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    switch (s) {
      case 'new':
        return 'Новый';
      case 'pending':
        return 'В ожидании';
      case 'accepted':
        return 'Принято';
      case 'preparing':
        return 'Готовится';
      case 'actionrequired':
        return 'Ждёт ответа клиента';
      case 'zamena':
        return 'Замена принята';
      case 'inprogress':
      case 'delivery':
        return 'В пути';
      case 'ready':
        return 'Готов';
      case 'delivered':
        return 'Доставлено';
      case 'cancelled':
      case 'canceled':
        return 'Отменено';
      default:
        return status;
    }
  }

  // группа статуса для фильтра
  String _group(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    if (s == 'cancelled' || s == 'canceled') return 'cancelled';
    if (s == 'delivered' || s == 'completed' || s == 'ready') return 'completed';
    return 'pending';
  }

  Color _statusColor(String status) {
    switch (_group(status)) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _translatePayment(String m) {
    switch (m.toLowerCase()) {
      case 'cash':
        return 'Наличные';
      case 'online':
        return 'Онлайн';
      case 'card':
        return 'Картой';
      case 'qr':
        return 'QR';
      default:
        return m;
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> all) {
    final q = searchQuery.toLowerCase();
    return all.where((o) {
      final name = (o['client_name'] ?? '').toString().toLowerCase();
      final phone = (o['client_phone'] ?? '').toString().toLowerCase();
      final shop = (o['restaurant_name'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(q) || phone.contains(q) || shop.contains(q);
      final matchesStatus =
          filterStatus == 'all' || _group((o['status'] ?? '').toString()) == filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ---------- ЭКРАН ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('ЗАКАЗЫ (АДМИН)', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => _load()),
        ],
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
                    hintText: 'Поиск: клиент, телефон, заведение...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                _buildStatusChips(),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: () => _load(), child: const Text('Повторить')),
          ],
        ),
      );
    }
    final data = _applyFilter(_orders);
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: data.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Заказов не найдено')),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: data.length,
        itemBuilder: (context, index) => _buildOrderCard(data[index]),
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
              label: Text(t['name']!,
                  style: TextStyle(color: isSel ? Colors.white : Colors.white70)),
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
    final items = _itemsOf(order['items']);

    final num productsTotal = order['items_price'] != null
        ? _n(order['items_price'])
        : items.fold<num>(0, (s, i) => s + _n(i['price']) * (_n(i['quantity']) == 0 ? 1 : _n(i['quantity'])));
    final num deliveryFee = _n(order['delivery_price']);
    final num totalCheck =
    order['total_price'] != null ? _n(order['total_price']) : productsTotal + deliveryFee;

    final created = DateTime.tryParse('${order['created_at']}')?.toLocal();
    final shortId = '№${order['id']}';
    final comment = (order['comment'] ?? '').toString().trim();
    final address = (order['client_address'] ?? '').toString().trim();
    final payment = (order['payment_method'] ?? '').toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text((order['client_name'] ?? 'Клиент').toString(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${_translateStatus(status)} · $shortId'
              '${created != null ? ' · ${DateFormat('dd.MM HH:mm').format(created)}' : ''}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.phone, 'Клиент:', (order['client_phone'] ?? '-').toString()),
                _infoRow(Icons.storefront_rounded, 'Заведение:',
                    (order['restaurant_name'] ?? '-').toString()),
                if (address.isNotEmpty) _infoRow(Icons.location_on_outlined, 'Адрес:', address),
                if (payment.isNotEmpty)
                  _infoRow(Icons.payments_outlined, 'Оплата:', _translatePayment(payment)),
                if (comment.isNotEmpty) _infoRow(Icons.chat_bubble_outline, 'Комментарий:', comment),
                const Divider(),
                const Text('ТОВАРЫ:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 5),
                ...items.map((item) {
                  final qty = _n(item['quantity']) == 0 ? 1 : _n(item['quantity']);
                  final tags = _itemTags(item);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['name']} x$qty', style: const TextStyle(fontSize: 13)),
                              if (tags.isNotEmpty)
                                Text(tags,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF7C3AED),
                                        fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text('${(_n(item['price']) * qty).toInt()} Руб',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Сумма товаров:',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                    Text('${productsTotal.toInt()} Руб', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Доставка:',
                        style: TextStyle(
                            fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                    Text('${deliveryFee.toInt()} Руб',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ОБЩИЙ ЧЕК:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${totalCheck.toInt()} Руб',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A))),
                  ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}