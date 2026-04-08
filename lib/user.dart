import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String searchQuery = '';
  String filterType = 'all';
  final TextEditingController searchController = TextEditingController();

  // --- КРАСИВЫЙ ИНПУТ ДЛЯ ДИАЛОГОВ ---
  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  void _addUser(BuildContext context, String collection) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(collection == 'users' ? 'Новый клиент' : collection == 'couriers' ? 'Новый курьер' : 'Новый админ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'ФИО', Icons.person_outline),
              _buildDialogField(emailController, 'Email', Icons.email_outlined),
              _buildDialogField(phoneController, 'Телефон', Icons.phone_outlined),
              if (collection == 'users') _buildDialogField(roleController, 'Роль (необязательно)', Icons.shield_outlined),
              if (collection != 'users') _buildDialogField(passwordController, 'Пароль', Icons.lock_outline, isPassword: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final data = {
                'name': nameController.text,
                'email': emailController.text,
                'phone': phoneController.text,
                'createdAt': Timestamp.now(),
              };
              if (collection == 'users') data['role'] = roleController.text.isNotEmpty ? roleController.text : 'user';
              else if (collection == 'couriers') { data['password'] = passwordController.text; data['active'] = true; data['role'] = 'courier'; }
              else if (collection == 'admins') { data['password'] = passwordController.text; data['role'] = 'admin'; data['active'] = true; }
              FirebaseFirestore.instance.collection(collection).add(data);
              Navigator.pop(context);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String collection, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Вы уверены, что хотите удалить этого пользователя?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (confirm) {
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
    }
  }

  void _editUser(BuildContext context, String collection, String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final emailController = TextEditingController(text: data['email']);
    final phoneController = TextEditingController(text: data['phone']);
    final roleController = TextEditingController(text: data['role'] ?? '');
    final passwordController = TextEditingController(text: data['password'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Редактирование',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'Имя', Icons.person_outline),
              _buildDialogField(emailController, 'Email', Icons.email_outlined),
              _buildDialogField(phoneController, 'Телефон', Icons.phone_outlined),
              if (collection == 'users')
                _buildDialogField(roleController, 'Роль', Icons.shield_outlined),
              if (collection != 'users')
                _buildDialogField(passwordController, 'Пароль', Icons.lock_outline),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final updatedData = {
                'name': nameController.text,
                'email': emailController.text,
                'phone': phoneController.text,
              };
              if (collection == 'users') {
                updatedData['role'] = roleController.text.isNotEmpty ? roleController.text : 'user';
              }
              if (collection != 'users') {
                updatedData['password'] = passwordController.text;
              }

              await FirebaseFirestore.instance.collection(collection).doc(docId).update(updatedData);

              if (!context.mounted) return;
              Navigator.pop(context);

              // Маленькое подтверждение для админа
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Данные успешно обновлены'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getAllUsersStream() {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final couriersStream = FirebaseFirestore.instance.collection('couriers').snapshots();
    final adminsStream = FirebaseFirestore.instance.collection('admins').snapshots();
    return Rx.combineLatest3(usersStream, couriersStream, adminsStream, (QuerySnapshot u, QuerySnapshot c, QuerySnapshot a) {
      final users = u.docs.map((doc) => (doc.data() as Map<String, dynamic>)..['type']='user'..['docId']=doc.id).toList();
      final couriers = c.docs.map((doc) => (doc.data() as Map<String, dynamic>)..['type']='courier'..['docId']=doc.id).toList();
      final admins = a.docs.map((doc) => (doc.data() as Map<String, dynamic>)..['type']='admin'..['docId']=doc.id).toList();
      return [...users, ...couriers, ...admins];
    });
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allUsers) {
    return allUsers.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? user['type'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(searchQuery.toLowerCase()) || email.contains(searchQuery.toLowerCase());
      final matchesFilter = filterType == 'all' || (filterType == 'user' && user['type'] == 'user') || (filterType == 'courier' && user['type'] == 'courier') || (filterType == 'admin' && user['type'] == 'admin');
      return matchesSearch && matchesFilter;
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        // --- ВОТ ЭТА СТРОКА ДЕЛАЕТ КНОПКУ НАЗАД БЕЛОЙ ---
        iconTheme: const IconThemeData(color: Colors.white),
        // -----------------------------------------------
        title: const Text(
            'Управление штатом',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
              onPressed: () {
                // ... твой код вызова BottomSheet
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Твой поиск и фильтры...
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени или почте...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'Все'),
                      _filterChip('user', 'Клиенты'),
                      _filterChip('courier', 'Курьеры'),
                      _filterChip('admin', 'Админы'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final users = _applyFilter(snapshot.data ?? []);
                if (users.isEmpty) return const Center(child: Text('Никого не нашли...'));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final String type = user['type'];
                    return _buildUserCard(user, type);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTypeBtn(BuildContext ctx, String label, IconData icon, Color color, String col) {
    return InkWell(
      onTap: () { Navigator.pop(ctx); _addUser(context, col); },
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 30, child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    bool selected = filterType == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (v) => setState(() => filterType = id),

        // Цвет текста: Белый на синем фоне (когда нажат), Темный на сером (когда нет)
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF1E293B),
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),

        // Цвет фона когда кнопка нажата
        selectedColor: const Color(0xFF3B82F6), // Яркий современный синий

        // Цвет фона когда кнопка НЕ нажата
        backgroundColor: Colors.white.withOpacity(0.9),

        // Убираем галочку
        showCheckmark: false,

        // Делаем аккуратные скругленные углы
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Colors.transparent : Colors.white.withOpacity(0.3),
          ),
        ),

        // Небольшая тень для объема, когда кнопка не нажата
        elevation: selected ? 4 : 0,
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, String type) {
    Color color = type == 'admin' ? Colors.red : type == 'courier' ? Colors.orange : Colors.blue;
    IconData icon = type == 'admin' ? Icons.admin_panel_settings : type == 'courier' ? Icons.delivery_dining : Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(user['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user['email'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            Text(user['phone'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(type.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(child: const ListTile(leading: Icon(Icons.edit), title: Text('Изменить')), onTap: () => Future.delayed(Duration.zero, () => _editUser(context, '${type}s', user['docId'], user))),
            PopupMenuItem(child: const ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Удалить', style: TextStyle(color: Colors.red))), onTap: () => Future.delayed(Duration.zero, () => _deleteUser('${type}s', user['docId']))),
          ],
        ),
      ),
    );
  }
}
