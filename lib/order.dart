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
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);
  static const _green = Color(0xFF3FA66B);
  static const _red = Color(0xFFD64545);

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

  String _group(String status) {
    final s = status.toLowerCase().replaceAll('_', '').trim();
    if (s == 'cancelled' || s == 'canceled') return 'cancelled';
    if (s == 'delivered' || s == 'completed' || s == 'ready') return 'completed';
    return 'pending';
  }

  Color _statusColor(String status) {
    switch (_group(status)) {
      case 'completed':
        return _green;
      case 'cancelled':
        return _red;
      default:
        return _accent;
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

  int _count(String id) {
    if (id == 'all') return _orders.length;
    return _orders.where((o) => _group((o['status'] ?? '').toString()) == id).length;
  }

  // ---------- ЭКРАН ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _squareButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _line),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: _ink, size: 21),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _squareButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Назад',
                onTap: () => Navigator.maybePop(context),
              ),
              const Spacer(),
              _squareButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Обновить',
                onTap: () => _load(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Заказы',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            style: const TextStyle(fontSize: 15, color: _ink),
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Клиент, телефон или заведение',
              hintStyle: const TextStyle(color: _muted),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                onPressed: () {
                  searchController.clear();
                  setState(() => searchQuery = '');
                },
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: _border(_line),
              enabledBorder: _border(_line),
              focusedBorder: _border(_ink, 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusChips(),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

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
          final id = t['id']!;
          final isSel = filterStatus == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => filterStatus = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSel ? _ink : _line,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? _ink : _muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_count(id)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSel ? _muted : _line,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _ink, strokeWidth: 2.5));
    }
    if (_error != null && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: _muted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 15)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(),
                child: const Text('Повторить',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    final data = _applyFilter(_orders);
    return RefreshIndicator(
      color: _ink,
      onRefresh: () => _load(spinner: false),
      child: data.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.receipt_long_outlined, size: 40, color: _muted),
          SizedBox(height: 12),
          Center(
            child: Text('Заказов не найдено',
                style: TextStyle(color: _muted, fontSize: 15)),
          ),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: data.length,
        itemBuilder: (context, index) => _buildOrderCard(data[index]),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _translateStatus(status),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'new').toString();
    final items = _itemsOf(order['items']);

    final num productsTotal = order['items_price'] != null
        ? _n(order['items_price'])
        : items.fold<num>(
        0,
            (s, i) =>
        s + _n(i['price']) * (_n(i['quantity']) == 0 ? 1 : _n(i['quantity'])));
    final num deliveryFee = _n(order['delivery_price']);
    final num totalCheck =
    order['total_price'] != null ? _n(order['total_price']) : productsTotal + deliveryFee;

    final created = DateTime.tryParse('${order['created_at']}')?.toLocal();
    final shortId = '№${order['id']}';
    final comment = (order['comment'] ?? '').toString().trim();
    final address = (order['client_address'] ?? '').toString().trim();
    final payment = (order['payment_method'] ?? '').toString();
    final shop = (order['restaurant_name'] ?? '').toString();

    final meta = [
      shortId,
      if (created != null) DateFormat('dd.MM HH:mm').format(created),
      if (shop.isNotEmpty) shop,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _bg,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: EdgeInsets.zero,
          iconColor: _muted,
          collapsedIconColor: _muted,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  (order['client_name'] ?? 'Клиент').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${totalCheck.toInt()} Руб',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 8),
                _statusPill(status),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.phone_outlined, 'Телефон',
                      (order['client_phone'] ?? '-').toString()),
                  if (address.isNotEmpty)
                    _infoRow(Icons.location_on_outlined, 'Адрес', address),
                  if (payment.isNotEmpty)
                    _infoRow(Icons.payments_outlined, 'Оплата', _translatePayment(payment)),
                  if (comment.isNotEmpty)
                    _infoRow(Icons.chat_bubble_outline_rounded, 'Комментарий', comment),
                  const SizedBox(height: 14),
                  const Text(
                    'Состав заказа',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final qty = _n(item['quantity']) == 0 ? 1 : _n(item['quantity']);
                    final tags = _itemTags(item);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: const BoxConstraints(minWidth: 30),
                            padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$qty×',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _ink),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['name']}',
                                    style: const TextStyle(fontSize: 14, color: _ink)),
                                if (tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(tags,
                                        style: const TextStyle(
                                            fontSize: 12, color: _muted)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${(_n(item['price']) * qty).toInt()} Руб',
                              style: const TextStyle(fontSize: 14, color: _ink)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 12),
                  _sumRow('Товары', '${productsTotal.toInt()} Руб'),
                  const SizedBox(height: 6),
                  _sumRow('Доставка', '${deliveryFee.toInt()} Руб'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                      Text('${totalCheck.toInt()} Руб',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _muted)),
        Text(value, style: const TextStyle(fontSize: 14, color: _ink)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}