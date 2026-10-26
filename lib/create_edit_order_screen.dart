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
  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);

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

  // 1250000 -> "1 250 000"
  String _fmt(num v) {
    final s = v.toInt().toString();
    return s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}\u00A0');
  }

  Map<String, dynamic> _bucket(String name) {
    return restaurantStats.putIfAbsent(
        name,
            () => {
          'count': 0,
          'prodSum': 0.0,
          'delivSum': 0.0,
          'statuses': <String, int>{}
        });
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
    final subtitle = loading || error != null
        ? 'Финансы и заказы'
        : 'Всего заказов: $totalOrders';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                onTap: _calculateStats,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Аналитика',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 15, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: _ink, strokeWidth: 2.5));
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: _muted),
              const SizedBox(height: 12),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 15)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _calculateStats,
                child: const Text('Повторить',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = restaurantStats.entries.toList()
      ..sort((a, b) => ((b.value['prodSum'] + b.value['delivSum']) as double)
          .compareTo((a.value['prodSum'] + a.value['delivSum']) as double));

    final double maxTotal = sorted.isEmpty
        ? 0
        : (sorted.first.value['prodSum'] + sorted.first.value['delivSum'])
    as double;

    return RefreshIndicator(
      color: _ink,
      onRefresh: _calculateStats,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _miniStat(
                      'Заказы', '$totalOrders', Icons.receipt_long_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _miniStat(
                      'Отменено', '$cancelledOrders', Icons.block_rounded)),
            ],
          ),
          const SizedBox(height: 28),
          _sectionTitle('Доход от доставки'),
          const SizedBox(height: 10),
          _buildTypeRow(),
          const SizedBox(height: 28),
          _sectionTitle('По заведениям'),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Данных пока нет',
                    style: TextStyle(color: _muted, fontSize: 15)),
              ),
            ),
          ...sorted.map((e) => _buildRestaurantCard(e.key, e.value, maxTotal)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _line),
  );

  // ---------- ГЛАВНАЯ КАРТОЧКА ----------
  Widget _buildHeroCard() {
    final prod = totalProductsSum;
    final deliv = totalDeliverySum;
    final sum = prod + deliv;
    final prodFlex = sum == 0 ? 1 : (prod / sum * 1000).round().clamp(1, 999);
    final delivFlex = sum == 0 ? 1 : (deliv / sum * 1000).round().clamp(1, 999);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Оборот',
              style: TextStyle(fontSize: 14, color: _muted)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_fmt(totalSum)} Руб',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: sum == 0
                  ? Container(color: _bg)
                  : Row(
                children: [
                  Expanded(
                      flex: prodFlex, child: Container(color: _ink)),
                  const SizedBox(width: 2),
                  Expanded(
                      flex: delivFlex, child: Container(color: _accent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _legendRow('За товары', prod, _ink),
          const SizedBox(height: 10),
          _legendRow('Доход от доставки', deliv, _accent),
        ],
      ),
    );
  }

  Widget _legendRow(String label, double amount, Color dot) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: _muted)),
        ),
        Text(
          '${_fmt(amount)} Руб',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _ink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink)),
                Text(label,
                    style: const TextStyle(fontSize: 13, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- ТИПЫ ----------
  Widget _buildTypeRow() {
    final entries = typeStats.entries.toList();
    return Row(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _typeTile(entries[i].key, entries[i].value)),
        ],
      ],
    );
  }

  Widget _typeTile(String title, Map<String, dynamic> v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_fmt(v['sum'] as double)} Руб',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
            ),
          ),
          const SizedBox(height: 4),
          Text('${v['count']} зак.',
              style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }

  // ---------- ЗАВЕДЕНИЯ ----------
  Widget _buildRestaurantCard(
      String name, Map<String, dynamic> data, double maxTotal) {
    final double total = data['prodSum'] + data['delivSum'];
    final double share = maxTotal == 0 ? 0 : (total / maxTotal).clamp(0.0, 1.0);
    final statuses = data['statuses'] as Map<String, int>;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmt(total)} Руб',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${data['count']} заказов',
                    style: const TextStyle(fontSize: 13, color: _muted)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    backgroundColor: _bg,
                    valueColor: const AlwaysStoppedAnimation(_ink),
                  ),
                ),
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
                  if (name != kIndividual) ...[
                    _kv('Товары', '${_fmt(data['prodSum'])} Руб'),
                    const SizedBox(height: 8),
                  ],
                  _kv('Доставка', '${_fmt(data['delivSum'])} Руб'),
                  if (statuses.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: statuses.entries
                          .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${s.key}: ${s.value}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink),
                        ),
                      ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _muted)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
      ],
    );
  }
}