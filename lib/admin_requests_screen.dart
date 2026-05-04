import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRequestsScreen extends StatelessWidget {
  final String currentAdminName; // Добавили имя админа для логирования

  const AdminRequestsScreen({super.key, required this.currentAdminName});

  // Внутренний метод для записи в коллекцию admin_logs
  Future<void> _logAction(String action, String target) async {
    await FirebaseFirestore.instance.collection('admin_logs').add({
      'adminName': currentAdminName,
      'action': action,
      'target': target,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            const Text(
              'РАССМОТРЕНИЕ ЗАЯВОК',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: Colors.white),
            ),
            Text('Админ: $currentAdminName',
                style: const TextStyle(color: Colors.white60, fontSize: 9)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('business_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('failed-precondition') ||
                snapshot.error.toString().contains('index')) {
              return _buildEmergencyStream();
            }
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return _buildListView(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildEmergencyStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('business_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          return _buildListView(snapshot.data!.docs);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildEmptyState();
      },
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        var doc = docs[index];
        var data = doc.data() as Map<String, dynamic>;
        return _buildRequestCard(context, data, doc.id);
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> data, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(15),
            image: data['logoUrl'] != null && data['logoUrl'].toString().isNotEmpty
                ? DecorationImage(
                image: NetworkImage(data['logoUrl']), fit: BoxFit.cover)
                : null,
          ),
          child: data['logoUrl'] == null || data['logoUrl'].toString().isEmpty
              ? const Icon(Icons.storefront, color: Color(0xFF64748B))
              : null,
        ),
        title: Text(
          data['businessName'] ?? 'Без названия',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            data['address'] ?? 'Адрес не указан',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Color(0xFFCBD5E1)),
        onTap: () => _showDetails(context, data, docId),
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10))
                        ],
                        image: data['logoUrl'] != null
                            ? DecorationImage(image: NetworkImage(data['logoUrl']), fit: BoxFit.cover)
                            : null,
                      ),
                      child: data['logoUrl'] == null ? const Icon(Icons.store, size: 50) : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    data['businessName'] ?? 'Заявка',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 32),
                  _detailItem(Icons.alternate_email_rounded, "Email",
                      data['contactEmail'] ?? 'Не указан'),
                  _detailItem(Icons.phone_android_rounded, "Телефон",
                      data['phone'] ?? 'Не указан'),
                  _detailItem(Icons.map_rounded, "Адрес", data['address'] ?? 'Не указан'),

                  if (data['lat'] != null && data['lng'] != null)
                    _detailItem(Icons.location_on_rounded, "Координаты",
                        "${data['lat']}, ${data['lng']}"),

                  _detailItem(Icons.access_time_filled_rounded, "Время работы",
                      data['time'] ?? 'Не указано'),
                  _detailItem(Icons.category_rounded, "Категория",
                      data['categoryKey'] ?? 'Не указана'),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton("ОТКЛОНИТЬ", Colors.redAccent, true, () {
                          _handleStatus(context, docId, 'rejected', data);
                        }),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _actionButton("ОДОБРИТЬ", const Color(0xFF0F172A), true, () {
                          _showCredentialsDialog(context, docId, data);
                        }),
                      ),
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

  void _showCredentialsDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final TextEditingController loginController = TextEditingController();
    final TextEditingController passwordController = TextEditingController(text: "123456");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Выдача доступа", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: loginController,
              decoration: const InputDecoration(
                labelText: "Логин (login)",
                hintText: "Например: buket_md",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Пароль (password)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("ОТМЕНА")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
            onPressed: () {
              if (loginController.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                _handleStatus(
                    context,
                    docId,
                    'approved',
                    data,
                    login: loginController.text,
                    pass: passwordController.text
                );
              }
            },
            child: const Text("СОХРАНИТЬ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: const Color(0xFF475569), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String title, Color color, bool isTextWhite, VoidCallback onTap) {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(title,
            style: TextStyle(
                color: isTextWhite ? Colors.white : color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("Очередь пуста",
              style: TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text("Новые заявки появятся автоматически",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text("Ошибка связи с Firebase",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _handleStatus(BuildContext context, String docId, String status, Map<String, dynamic> data, {String? login, String? pass}) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      String businessName = data['businessName'] ?? 'ID: $docId';

      DocumentReference requestRef = FirebaseFirestore.instance
          .collection('business_requests')
          .doc(docId);

      if (status == 'approved') {
        DocumentReference categoryRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(docId);

        batch.set(categoryRef, {
          'category': data['categoryKey'] ?? '',
          'login': login ?? '',
          'logoUrl': data['logoUrl'] ?? '',
          'name': data['businessName'] ?? '',
          'password': pass ?? '',
          'phone': data['phone'] ?? '',
          'time': data['time'] ?? '',
          'shopId': docId,
          'address': data['address'] ?? '',
          'lat': data['lat'],
          'lng': data['lng'],
        });

        batch.update(requestRef, {
          'status': 'approved',
          'shopId': docId,
        });
      } else {
        batch.update(requestRef, {'status': status});
      }

      // ПУШИМ В ЛОГИ ПЕРЕД КОММИТОМ
      await _logAction(
          status == 'approved' ? 'Одобрил заявку' : 'Отклонил заявку',
          businessName
      );

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Заведение успешно создано!' : 'Заявка отклонена'),
            backgroundColor: status == 'approved' ? const Color(0xFF0F172A) : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }
}
