import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminShopsScreen extends StatefulWidget {
  final String currentAdminName;

  const AdminShopsScreen({
    super.key,
    required this.currentAdminName,
  });

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'disabled'
  String _selectedCategoryKey = 'all'; // Фильтр по конкретному типу заведения

  // Словарь переводов
  final Map<String, String> _translations = {
    'restaurant': 'Ресторан',
    'product': 'Продуктовый магазин',
    'svetok': 'Цветочный магазин',
    'electronika': 'Магазин электроники и техники',
    'apteka': 'Аптека',
    'odejda': 'Магазин одежды',
    'stroimaterial': 'Строй магазины',
  };

  // Функция для перевода английских системных типов в читаемый русский
  String _translateCategory(String rawCategory) {
    final lowerKey = rawCategory.toLowerCase().trim();
    return _translations[lowerKey] ?? (rawCategory.isNotEmpty
        ? rawCategory[0].toUpperCase() + rawCategory.substring(1)
        : 'Категория');
  }

  @override
  Widget build(BuildContext context) {
    // Превращаем ключи в список для удобного разделения по рядам
    final keysList = _translations.keys.toList();
    // Первые 4 штуки (включая 'all' как отдельный элемент или делим пополам)
    // Сделаем так: первый ряд — «Все типы» + 3 категории, второй ряд — оставшиеся 4

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'УПРАВЛЕНИЕ МАГАЗИНАМИ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Панель поиска и фильтрации
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию заведения...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),

                // Фильтры по статусу (Активные / Отключенные)
                Row(
                  children: [
                    _buildStatusChip('Все статусы', 'all'),
                    const SizedBox(width: 8),
                    _buildStatusChip('Активные', 'active'),
                    const SizedBox(width: 8),
                    _buildStatusChip('Отключенные', 'disabled'),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'Фильтр по типам:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),

                // 1-й ряд фильтров (4 штуки)
                Row(
                  children: [
                    Expanded(child: _buildCategoryChip('Все типы', 'all')),
                    const SizedBox(width: 6),
                    if (keysList.isNotEmpty) Expanded(child: _buildCategoryChip(_translations[keysList[0]]!, keysList[0])),
                    const SizedBox(width: 6),
                    if (keysList.length > 1) Expanded(child: _buildCategoryChip(_translations[keysList[1]]!, keysList[1])),
                    const SizedBox(width: 6),
                    if (keysList.length > 2) Expanded(child: _buildCategoryChip(_translations[keysList[2]]!, keysList[2])),
                  ],
                ),
                const SizedBox(height: 6),
                // 2-й ряд фильтров (оставшиеся категории)
                Row(
                  children: [
                    if (keysList.length > 3) Expanded(child: _buildCategoryChip(_translations[keysList[3]]!, keysList[3])) else const Spacer(),
                    const SizedBox(width: 6),
                    if (keysList.length > 4) Expanded(child: _buildCategoryChip(_translations[keysList[4]]!, keysList[4])) else const Spacer(),
                    const SizedBox(width: 6),
                    if (keysList.length > 5) Expanded(child: _buildCategoryChip(_translations[keysList[5]]!, keysList[5])) else const Spacer(),
                    const SizedBox(width: 6),
                    if (keysList.length > 6) Expanded(child: _buildCategoryChip(_translations[keysList[6]]!, keysList[6])) else const Spacer(),
                  ],
                ),
              ],
            ),
          ),

          // Список заведений из коллекции /categories в Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _buildShopsList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategoryKey == value;
    return InkWell(
      onTap: () => setState(() => _selectedCategoryKey = value),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade800 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  Widget _buildShopsList(List<QueryDocumentSnapshot> docs) {
    // Фильтрация по поиску, статусу и конкретному типу
    final filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? data['title'] ?? 'Без названия').toString().toLowerCase();

      // Поле активности
      final bool isActive = data['isActive'] ?? data['isOnline'] ?? true;

      // Сырая категория из БД
      final rawCategory = (data['category'] ?? data['type'] ?? '').toString().toLowerCase().trim();

      // Проверка текста поиска
      final matchesSearch = name.contains(_searchQuery);

      // Проверка фильтра статуса
      if (_filterStatus == 'active' && !isActive) return false;
      if (_filterStatus == 'disabled' && isActive) return false;

      // Проверка фильтра по типу заведения
      if (_selectedCategoryKey != 'all' && rawCategory != _selectedCategoryKey) {
        return false;
      }

      return matchesSearch;
    }).toList();

    if (filteredDocs.isEmpty) {
      return const Center(
        child: Text(
          'Заведения не найдены',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;

        final shopName = data['name'] ?? data['title'] ?? 'Заведение без имени';

        // Получаем сырые данные категории и переводим их через метод
        final rawCategory = data['category'] ?? data['type'] ?? 'general';
        final translatedCategory = _translateCategory(rawCategory.toString());

        final bool isActive = data['isActive'] ?? data['isOnline'] ?? true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Icon(
                Icons.storefront_rounded,
                color: isActive ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              shopName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Тип: $translatedCategory', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Статус: Работает в системе' : 'Статус: Отключен от сервиса',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            trailing: Switch.adaptive(
              value: isActive,
              activeColor: Colors.green,
              onChanged: (bool value) async {
                // Моментальное обновление в Firestore по пути /categories/{docId}
                await doc.reference.update({
                  'isActive': value,
                  'isOnline': value,
                });
              },
            ),
          ),
        );
      },
    );
  }
}