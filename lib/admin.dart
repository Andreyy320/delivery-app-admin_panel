import 'package:flutter/material.dart';
import 'user.dart';
import 'create_edit_order_screen.dart';
import 'normal_delivery.dart';
import 'order.dart';
import 'login_screen.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Определяем ширину экрана, чтобы понять, сколько колонок рисовать
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Мягкий фон
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('COMMAND CENTER',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Панель управления',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              const Text('Обзор всей системы доставки',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
              const SizedBox(height: 24),

              // Используем GridView.count для четкой сетки
              GridView.count(
                shrinkWrap: true, // Важно, чтобы внутри SingleChildScrollView не было ошибок
                physics: const NeverScrollableScrollPhysics(), // Скроллит всё тело целиком
                crossAxisCount: crossAxisCount, // 2 для телефона, 4 для ПК
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85, // Соотношение сторон карточки (чуть вытянута вниз)
                children: [
                  _buildCard(context, 'Клиенты', Icons.people_alt_rounded, Colors.indigo, const UsersScreen(), 'Управление'),
                  _buildCard(context, 'Магазины', Icons.storefront_rounded, Colors.orange, const OrdersAdminScreen(), 'Заказы'),
                  _buildCard(context, 'Логистика', Icons.local_shipping_rounded, Colors.teal, const AllCourierOrdersScreen(), 'Курьеры'),
                  _buildCard(context, 'Аналитика', Icons.analytics_rounded, Colors.purple, const AdminStatisticsScreen(), 'Отчеты'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, Color color, Widget page, String label) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}