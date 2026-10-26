import 'package:flutter/material.dart';
import 'Ypravlenie_zavedeniem.dart';
import 'user.dart';
import 'create_edit_order_screen.dart';
import 'order.dart';
import 'Login_Screen.dart';
import 'admin_requests_screen.dart';
import 'admin_logs_screen.dart';
import 'api.dart';

class AdminHome extends StatelessWidget {
  final String adminName;

  const AdminHome({
    super.key,
    required this.adminName,
  });

  static const _bg = Color(0xFFF5F5F3);
  static const _ink = Color(0xFF16181D);
  static const _muted = Color(0xFF7B808A);
  static const _line = Color(0xFFE2E3E6);
  static const _accent = Color(0xFFF26B1D);

  @override
  Widget build(BuildContext context) {
    final orders = _Section('Заказы', 'Все заказы, статусы и детали',
        Icons.receipt_long_rounded, const OrdersAdminScreen());
    final requests = _Section('Заявки', 'Новые партнёры', Icons.inbox_rounded,
        AdminRequestsScreen(currentAdminName: adminName));
    final shops = _Section('Заведения', 'Вкл / выкл', Icons.storefront_rounded,
        AdminShopsScreen(currentAdminName: adminName));
    final clients = _Section('Клиенты', '', Icons.people_alt_rounded,
        UsersScreen(currentAdminName: adminName));
    final stats = _Section('Аналитика', '', Icons.insights_rounded,
        AdminStatisticsScreen(currentAdminName: adminName));
    final logs = _Section('Журнал', '', Icons.history_rounded,
        const AdminLogsScreen());

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Здравствуйте,',
                                style: TextStyle(fontSize: 15, color: _muted)),
                            const SizedBox(height: 2),
                            Text(
                              adminName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _line),
                        ),
                        child: IconButton(
                          tooltip: 'Выйти',
                          icon: const Icon(Icons.logout_rounded,
                              color: _ink, size: 21),
                          onPressed: () async {
                            await Api.clearSession();
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Главная плитка
                  _tile(context, orders, height: 150, titleSize: 26),
                  const SizedBox(height: 10),

                  // Две средние
                  Row(
                    children: [
                      Expanded(
                          child: _tile(context, requests,
                              height: 128, titleSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _tile(context, shops,
                              height: 128, titleSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Три маленькие
                  Row(
                    children: [
                      Expanded(
                          child: _tile(context, clients,
                              height: 104, titleSize: 14, small: true)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _tile(context, stats,
                              height: 104, titleSize: 14, small: true)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _tile(context, logs,
                              height: 104, titleSize: 14, small: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context,
      _Section s, {
        required double height,
        required double titleSize,
        bool dark = false,
        bool small = false,
      }) {
    final Color fg = dark ? Colors.white : _ink;
    final Color sub = dark ? Colors.white70 : _muted;

    return Material(
      color: dark ? _accent : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(small ? 18 : 22),
        side: dark ? BorderSide.none : const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => s.page),
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.all(small ? 14 : 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: small ? 38 : 44,
                      height: small ? 38 : 44,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withAlpha(50) : _bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        s.icon,
                        color: dark ? Colors.white : _ink,
                        size: small ? 20 : 24,
                      ),
                    ),
                    const Spacer(),
                    if (!small)
                      Icon(Icons.arrow_outward_rounded, color: sub, size: 22),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    if (!small && s.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        s.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: sub),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;

  const _Section(this.title, this.subtitle, this.icon, this.page);
}