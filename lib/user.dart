import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class UsersScreen extends StatefulWidget {
  final String currentAdminName;

  const UsersScreen({super.key, required this.currentAdminName});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String searchQuery = '';
  String filterType = 'all';
  final TextEditingController searchController = TextEditingController();

  // --- МЕТОД ДЛЯ ЗАПИСИ В ЖУРНАЛ (ЛОГИ) ---
  Future<void> _logAction(String action, String target) async {
    await FirebaseFirestore.instance.collection('admin_logs').add({
      'adminName': widget.currentAdminName,
      'action': action,
      'target': target,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- ПОЛЯ ДЛЯ ДИАЛОГОВ ---
  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  String _getCollectionName(String type) {
    if (type.endsWith('s')) return type;
    return '${type}s';
  }

  void _addUser(BuildContext context, String collection) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController();
    final passwordController = TextEditingController();
    final loginController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(collection == 'users' ? 'Новый клиент' : collection == 'couriers' ? 'Новый курьер' : 'Новый админ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'ФИО / Имя', Icons.person_outline),
              _buildDialogField(emailController, 'Email', Icons.email_outlined),
              if (collection == 'users' || collection == 'couriers')
                _buildDialogField(phoneController, 'Телефон', Icons.phone_outlined, hint: '77712345'),
              if (collection != 'users')
                _buildDialogField(loginController, 'Логин (для входа)', Icons.badge_outlined),
              _buildDialogField(passwordController, 'Пароль', Icons.lock_outline, isPassword: true),
              if (collection == 'users')
                _buildDialogField(roleController, 'Роль (по умолчанию: user)', Icons.shield_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              final String name = nameController.text.trim();
              final String password = passwordController.text.trim(); // ОБЫЧНЫЙ ТЕКСТ

              final data = {
                'name': name,
                'email': emailController.text.trim(),
                'password': password, // БЕЗ ХЕШИРОВАНИЯ
                'createdAt': FieldValue.serverTimestamp(),
              };

              if (collection == 'users' || collection == 'couriers') {
                String phone = phoneController.text.trim();
                data['phone'] = phone.startsWith('+') ? phone : '+373$phone';
              }

              if (collection == 'users') {
                data['role'] = roleController.text.isNotEmpty ? roleController.text.trim() : 'user';
              } else {
                data['login'] = loginController.text.trim();
                data['active'] = true;
                data['role'] = collection == 'couriers' ? 'courier' : 'admin';
              }

              await FirebaseFirestore.instance.collection(collection).add(data);
              await _logAction('Создал $collection', name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _editUser(BuildContext context, String collection, String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final emailController = TextEditingController(text: data['email']);
    final phoneController = TextEditingController(text: data['phone'] ?? '');
    final loginController = TextEditingController(text: data['login'] ?? '');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Редактирование', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'Имя', Icons.person_outline),
              _buildDialogField(emailController, 'Email', Icons.email_outlined),
              if (collection == 'users' || collection == 'couriers')
                _buildDialogField(phoneController, 'Телефон', Icons.phone_outlined),
              if (collection != 'users')
                _buildDialogField(loginController, 'Логин', Icons.badge_outlined),
              _buildDialogField(
                  passwordController,
                  'Новый пароль',
                  Icons.lock_outline,
                  isPassword: true,
                  hint: 'Оставьте пустым, чтобы не менять'
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              final String newName = nameController.text.trim();
              final String newPassword = passwordController.text.trim();

              final updatedData = {
                'name': newName,
                'email': emailController.text.trim(),
              };

              if (newPassword.isNotEmpty) {
                updatedData['password'] = newPassword; // ПРОСТО ТЕКСТ
              }

              if (collection == 'users' || collection == 'couriers') {
                String phone = phoneController.text.trim();
                updatedData['phone'] = phone.startsWith('+') ? phone : '+373$phone';
              }

              if (collection != 'users') {
                updatedData['login'] = loginController.text.trim();
              }

              await FirebaseFirestore.instance.collection(collection).doc(docId).update(updatedData);
              await _logAction('Обновил $collection', newName);

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String collection, String docId) async {
    final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
    final String name = doc.data()?['name'] ?? 'ID: $docId';

    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Вы уверены, что хотите удалить пользователя?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      await _logAction('Удалил из $collection', name);
    }
  }

  Stream<List<Map<String, dynamic>>> _getAllUsersStream() {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final couriersStream = FirebaseFirestore.instance.collection('couriers').snapshots();
    final adminsStream = FirebaseFirestore.instance.collection('admins').snapshots();

    return Rx.combineLatest3(usersStream, couriersStream, adminsStream,
            (QuerySnapshot u, QuerySnapshot c, QuerySnapshot a) {
          final users = u.docs.map((doc) => (doc.data() as Map<String, dynamic>)..['type']='user'..['docId']=doc.id).toList();
          final couriers = c.docs.map((doc) => (doc.data() as Map<String, dynamic>)..['type']='courier'..['docId']=doc.id).toList();
          final admins = a.docs.map((doc) => (doc.data() as Map<String, dynamic>)..['type']='admin'..['docId']=doc.id).toList();
          return [...users, ...couriers, ...admins];
        });
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> allUsers) {
    return allUsers.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(searchQuery.toLowerCase()) || phone.contains(searchQuery.toLowerCase());
      final matchesFilter = filterType == 'all' || filterType == user['type'];
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Кого добавить?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _addTypeBtn(ctx, 'Клиент', Icons.person_add, Colors.blue, 'users'),
                _addTypeBtn(ctx, 'Курьер', Icons.delivery_dining, Colors.orange, 'couriers'),
                _addTypeBtn(ctx, 'Админ', Icons.admin_panel_settings, Colors.red, 'admins'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Управление штатом', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            Text('Админ: ${widget.currentAdminName}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white), onPressed: _showAddUserSheet)],
      ),
      body: Column(
        children: [
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
                    hintText: 'Поиск...',
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
                  itemBuilder: (context, index) => _buildUserCard(users[index], users[index]['type']),
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
      child: Column(children: [CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 30, child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w500))]),
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
        labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold),
        selectedColor: const Color(0xFF3B82F6),
        backgroundColor: Colors.white.withOpacity(0.9),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, String type) {
    Color color = type == 'admin' ? Colors.red : type == 'courier' ? Colors.orange : Colors.blue;
    IconData icon = type == 'admin' ? Icons.admin_panel_settings : type == 'courier' ? Icons.delivery_dining : Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(user['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user['login'] != null) Text('Логин: ${user['login']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(user['email'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            if (user['phone'] != null) Text(user['phone'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(type.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(child: const ListTile(leading: Icon(Icons.edit), title: Text('Изменить')), onTap: () => Future.delayed(Duration.zero, () => _editUser(context, _getCollectionName(type), user['docId'], user))),
            PopupMenuItem(child: const ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Удалить', style: TextStyle(color: Colors.red))), onTap: () => Future.delayed(Duration.zero, () => _deleteUser(_getCollectionName(type), user['docId']))),
          ],
        ),
      ),
    );
  }
}