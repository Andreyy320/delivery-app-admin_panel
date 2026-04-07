import 'package:flutter/material.dart';
import 'package:admin_panel/user.dart';
import 'create_edit_order_screen.dart';
import 'normal_delivery.dart';
import 'order.dart';
import 'login_screen.dart'; // <- импорт экрана логина

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Widget _buildCard(BuildContext context, String title, IconData icon, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Container(
          height: 280,
          width: 280,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () {
              // Возврат на экран логина и удаление AdminHome из стека
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Верхний ряд
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCard(context, 'Управление пользователями', Icons.person, const UsersScreen()),
                _buildCard(context, 'Просмотр заказов', Icons.list_alt, const OrdersAdminScreen()),
              ],
            ),
            const SizedBox(height: 20),
            // Нижний ряд
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCard(context, 'Все заказы курьеров', Icons.local_shipping, const AllCourierOrdersScreen()),
                _buildCard(context, 'Статистика заказов', Icons.bar_chart, const AdminStatisticsScreen()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
