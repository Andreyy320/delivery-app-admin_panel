import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllCourierOrdersScreen extends StatefulWidget {
  const AllCourierOrdersScreen({super.key});

  @override
  State<AllCourierOrdersScreen> createState() => _AllCourierOrdersScreenState();
}

class _AllCourierOrdersScreenState extends State<AllCourierOrdersScreen> {
  final MapController _mapController = MapController();

  // Поток для получения курьеров в реальном времени из Firestore
  Stream<List<Map<String, dynamic>>> _getCouriersRealtime() {
    return FirebaseFirestore.instance.collection('couriers').snapshots().map((snapshot) {
      debugPrint('🔥 Firestore: получено документов в коллекции couriers: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Сохраняем ID документа
        return data;
      }).toList();
    });
  }

  // Всплывающая плашка при клике на курьера
  void _showCourierBottomSheet(BuildContext context, Map<String, dynamic> courier) {
    final name = courier['name'] ?? 'Без имени';
    final callsign = courier['callsign'] ?? '-';
    final phone = courier['phone'] ?? '-';
    final district = courier['currentDistrict'] ?? 'Не указан';
    final isActive = courier['active'] == true;
    final isOnDuty = courier['isOnDuty'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOnDuty && isActive) ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (isOnDuty && isActive) ? 'НА СМЕНЕ' : 'НЕ В СЕТИ',
                      style: TextStyle(
                        color: (isOnDuty && isActive) ? Colors.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text('Позывной: $callsign', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                ],
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              Text('Район: $district', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              Text('Телефон: $phone', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getCouriersRealtime(),
        builder: (context, snapshot) {
          // Собираем маркеры курьеров из базы данных
          final List<Marker> markers = [];

          if (snapshot.hasData) {
            for (var courier in snapshot.data!) {
              final name = courier['name'] ?? 'Без имени';
              final latVal = courier['latitude'];
              final lonVal = courier['longitude'];

              debugPrint('📍 Курьер "$name": latitude = $latVal, longitude = $lonVal');

              // Проверяем, есть ли валидные координаты у курьера
              if (latVal != null && lonVal != null) {
                final double lat = (latVal as num).toDouble();
                final double lon = (lonVal as num).toDouble();
                final bool isOnDuty = courier['isOnDuty'] == true;
                final bool active = courier['active'] == true;

                // Цвет маркера: зеленый если на смене, серый если отключен
                final Color markerColor = (isOnDuty && active) ? Colors.green : Colors.grey;

                markers.add(
                  Marker(
                    point: LatLng(lat, lon),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showCourierBottomSheet(context, courier),
                      child: Container(
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                debugPrint('⚠️ Пропущен курьер "$name", так как координаты null!');
              }
            }
          }

          debugPrint('🎯 Итого добавлено маркеров на карту: ${markers.length}');

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(46.8403, 29.6433), // Тирасполь
                  initialZoom: 13.0,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                    maxZoom: 19,
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              // Небольшая плашка сверху с количеством курьеров на карте
              Positioned(
                top: 50,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: Text(
                    'Курьеров на карте: ${markers.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}