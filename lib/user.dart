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
  String filterType = 'all'; // all / user / courier / admin
  final TextEditingController searchController = TextEditingController();

  // ---------------- Добавление ----------------
  void _addUser(BuildContext context, String collection) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(collection == 'users'
            ? 'Добавить пользователя'
            : collection == 'couriers'
            ? 'Добавить курьера'
            : 'Добавить администратора'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Телефон')),
              if (collection == 'users') TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Роль')),
              if (collection != 'users') TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Пароль')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final data = {
                'name': nameController.text,
                'email': emailController.text,
                'phone': phoneController.text,
                'createdAt': Timestamp.now(),
              };

              if (collection == 'users') {
                data['role'] = roleController.text.isNotEmpty ? roleController.text : 'user';
              } else if (collection == 'couriers') {
                data['password'] = passwordController.text;
                data['active'] = true;
                data['role'] = 'courier';
              } else if (collection == 'admins') {
                data['password'] = passwordController.text;
                data['role'] = 'admin';
                data['active'] = true;
              }

              FirebaseFirestore.instance.collection(collection).add(data);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(collection == 'users'
                        ? 'Пользователь добавлен'
                        : collection == 'couriers'
                        ? 'Курьер добавлен'
                        : 'Админ добавлен')),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  // ---------------- Удаление ----------------
  void _deleteUser(String collection, String docId) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(collection == 'users'
              ? 'Пользователь удален'
              : collection == 'couriers'
              ? 'Курьер удален'
              : 'Админ удален')),
    );
  }

  // ---------------- Редактирование ----------------
  void _editUser(BuildContext context, String collection, String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final emailController = TextEditingController(text: data['email']);
    final phoneController = TextEditingController(text: data['phone']);
    final roleController = TextEditingController(text: data['role'] ?? '');
    final passwordController = TextEditingController(text: data['password'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(collection == 'users'
            ? 'Редактировать пользователя'
            : collection == 'couriers'
            ? 'Редактировать курьера'
            : 'Редактировать администратора'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Телефон')),
              if (collection == 'users') TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Роль')),
              if (collection != 'users') TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Пароль')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final updatedData = {
                'name': nameController.text,
                'email': emailController.text,
                'phone': phoneController.text,
              };
              if (collection == 'users') updatedData['role'] = roleController.text.isNotEmpty ? roleController.text : 'user';
              if (collection != 'users') updatedData['password'] = passwordController.text;

              FirebaseFirestore.instance.collection(collection).doc(docId).update(updatedData);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(collection == 'users'
                        ? 'Пользователь обновлен'
                        : collection == 'couriers'
                        ? 'Курьер обновлен'
                        : 'Админ обновлен')),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // ---------------- Объединённый Stream через Rx ----------------
  Stream<List<Map<String, dynamic>>> _getAllUsersStream() {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final couriersStream = FirebaseFirestore.instance.collection('couriers').snapshots();
    final adminsStream = FirebaseFirestore.instance.collection('admins').snapshots();

    return Rx.combineLatest3(
      usersStream,
      couriersStream,
      adminsStream,
          (QuerySnapshot usersSnapshot, QuerySnapshot couriersSnapshot, QuerySnapshot adminsSnapshot) {
        final users = usersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['type'] = 'user';
          data['docId'] = doc.id;
          if (!data.containsKey('role')) data['role'] = 'user';
          return data;
        }).toList();

        final couriers = couriersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['type'] = 'courier';
          data['docId'] = doc.id;
          if (!data.containsKey('role')) data['role'] = 'courier';
          return data;
        }).toList();

        final admins = adminsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['type'] = 'admin';
          data['docId'] = doc.id;
          if (!data.containsKey('role')) data['role'] = 'admin';
          return data;
        }).toList();

        return [...users, ...couriers, ...admins];
      },
    );
  }

  // ---------------- Фильтрация и поиск ----------------
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allUsers) {
    return allUsers.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();

      final matchesSearch = name.contains(searchQuery.toLowerCase()) || email.contains(searchQuery.toLowerCase());

      final matchesFilter = filterType == 'all' ||
          (filterType == 'user' && role != 'courier' && role != 'admin') ||
          (filterType == 'courier' && role == 'courier') ||
          (filterType == 'admin' && role == 'admin');

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи и курьеры'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Добавить'),
                  content: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _addUser(context, 'users'),
                        child: const Text('Пользователь'),
                      ),
                      ElevatedButton(
                        onPressed: () => _addUser(context, 'couriers'),
                        child: const Text('Курьер'),
                      ),
                      ElevatedButton(
                        onPressed: () => _addUser(context, 'admins'),
                        child: const Text('Админ'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по имени или email',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),

          // Фильтр
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: filterType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                DropdownMenuItem(value: 'user', child: Text('Клиенты')),
                DropdownMenuItem(value: 'courier', child: Text('Курьеры')),
                DropdownMenuItem(value: 'admin', child: Text('Админы')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => filterType = value);
              },
            ),
          ),

          // Список
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final allUsers = snapshot.data ?? [];
                final filteredUsers = _applyFilter(allUsers);

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('Пользователей нет'));
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isCourier = user['type'] == 'courier';
                    final isAdmin = user['type'] == 'admin';
                    final roleText = user['role'] ?? (isCourier ? 'courier' : isAdmin ? 'admin' : '-');

                    String createdAtText = '';
                    if (user['createdAt'] != null && user['createdAt'] is Timestamp) {
                      createdAtText = DateFormat('yyyy-MM-dd HH:mm').format((user['createdAt'] as Timestamp).toDate());
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(isCourier
                            ? Icons.delivery_dining
                            : isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.person),
                        title: Text(user['name'] ?? '-'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: ${user['email'] ?? '-'}'),
                            Text('Телефон: ${user['phone'] ?? '-'}'),
                            Text('Роль: $roleText'),
                            if (isCourier || isAdmin) Text('Активен: ${user['active'] == true ? 'Да' : 'Нет'}'),
                            if (!isCourier && !isAdmin && user['createdAt'] != null) Text('Создан: $createdAtText'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editUser(
                                  context,
                                  isCourier
                                      ? 'couriers'
                                      : isAdmin
                                      ? 'admins'
                                      : 'users',
                                  user['docId'],
                                  user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteUser(
                                  isCourier
                                      ? 'couriers'
                                      : isAdmin
                                      ? 'admins'
                                      : 'users',
                                  user['docId']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
