import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class CourierService {
  static final CourierService _instance = CourierService._internal();
  factory CourierService() => _instance;
  CourierService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Aktif kurye konum takip abonelikleri: orderId -> StreamSubscription<Position>
  final Map<String, StreamSubscription<Position>> _locationSubscriptions = {};

  /// Telefon numarasını temizler ve standartlaştırır (örn: 05551234567)
  static String normalizePhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('90') && clean.length == 12) {
      clean = '0${clean.substring(2)}';
    } else if (clean.length == 10 && clean.startsWith('5')) {
      clean = '0$clean';
    }
    return clean;
  }

  /// Restoran sahibinin yeni kurye eklemesi
  Future<String> addCourier({
    required String sellerId,
    required String storeName,
    required String name,
    required String phone,
    String vehicleType = 'Motosiklet',
  }) async {
    final cleanPhone = normalizePhone(phone);
    if (cleanPhone.length < 10) {
      throw Exception('Lütfen geçerli bir telefon numarası giriniz (örn: 05xx xxx xx xx).');
    }

    final docRef = await _firestore.collection('couriers').add({
      'sellerId': sellerId,
      'storeName': storeName,
      'name': name.trim(),
      'phone': cleanPhone,
      'rawPhone': phone.trim(),
      'vehicleType': vehicleType,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Kurye durumunu (aktif/pasif) değiştir
  Future<void> toggleCourierActive(String courierId, bool currentStatus) async {
    await _firestore.collection('couriers').doc(courierId).update({
      'isActive': !currentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Kuryeyi sil
  Future<void> deleteCourier(String courierId) async {
    await _firestore.collection('couriers').doc(courierId).delete();
  }

  /// Telefon numarasına göre kurye kaydı sorgula (aktif olanlar)
  Future<Map<String, dynamic>?> findCourierByPhone(String rawPhone) async {
    final cleanPhone = normalizePhone(rawPhone);
    if (cleanPhone.isEmpty) return null;

    final query = await _firestore
        .collection('couriers')
        .where('phone', isEqualTo: cleanPhone)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    return data;
  }

  /// Kurye için zorunlu konum iznini kontrol et ve al
  Future<bool> checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Kurye "Yola Çıktım" dediğinde canlı konum takibini başlat
  Future<void> startLiveLocationTracking({
    required String orderId,
    required String courierName,
    required String courierPhone,
  }) async {
    final hasPermission = await checkAndRequestLocationPermission();
    if (!hasPermission) {
      throw Exception('Siparişi yola çıkarabilmek için cihazınızın konum iznini açmanız zorunludur.');
    }

    // Varsa önceki takibi kapat
    await stopLiveLocationTracking(orderId, removeLocation: false);

    // İlk anlık konumu hemen al ve yaz
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Yolda',
        'courierName': courierName,
        'courierPhone': normalizePhone(courierPhone),
        'courierLocation': {
          'latitude': initialPosition.latitude,
          'longitude': initialPosition.longitude,
          'heading': initialPosition.heading,
          'speed': initialPosition.speed,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'onTheWayAt': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('İlk konum alma uyarısı: $e');
    }

    // Konum akışını başlat (her 10 metrede veya 10 saniyede bir güncelle)
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    final sub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((position) async {
      try {
        await _firestore.collection('orders').doc(orderId).update({
          'courierLocation': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'heading': position.heading,
            'speed': position.speed,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      } catch (e) {
        debugPrint('Canlı konum güncelleme hatası: $e');
      }
    }, onError: (err) {
      debugPrint('Konum dinleme hatası: $err');
    });

    _locationSubscriptions[orderId] = sub;
  }

  /// Kurye "Kapıya Geldim" bildirimini gönderir
  Future<void> markCourierAtDoor({
    required String orderId,
    required String customerId,
    required String storeName,
  }) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Kapıda',
      'atDoorAt': FieldValue.serverTimestamp(),
      'lastUpdate': FieldValue.serverTimestamp(),
    });

    await notifyCustomer(
      customerId: customerId,
      orderId: orderId,
      title: '🔔 Kuryeniz Kapıda!',
      message: '$storeName siparişiniz adresinize ulaştı. Kurye kapınızda, lütfen teslim alınız.',
      type: 'courier_at_door',
    );
  }

  /// Kurye "Teslim Edildi" dediğinde takibi durdur ve kuryenin konumunu siparişten SİL (güvenlik & gizlilik)
  Future<void> markOrderDelivered({
    required String orderId,
    required String customerId,
    required String storeName,
  }) async {
    // 1. Canlı konum dinleyicisini kapat ve siparişten konumu SİL
    await stopLiveLocationTracking(orderId, removeLocation: true);

    // 2. Siparişi Teslim Edildi yap
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'Teslim Edildi',
      'deliveredAt': FieldValue.serverTimestamp(),
      'lastUpdate': FieldValue.serverTimestamp(),
      'courierLocation': FieldValue.delete(), // Müşteri artık kuryeyi asla göremez!
    });

    // 3. Müşteriye bildirim gönder
    await notifyCustomer(
      customerId: customerId,
      orderId: orderId,
      title: '✅ Siparişiniz Teslim Edildi',
      message: '$storeName siparişiniz başarıyla teslim edilmiştir. Afiyet olsun!',
      type: 'order_delivered',
    );
  }

  /// Canlı konum aboneliğini durdur
  Future<void> stopLiveLocationTracking(String orderId, {bool removeLocation = false}) async {
    if (_locationSubscriptions.containsKey(orderId)) {
      await _locationSubscriptions[orderId]?.cancel();
      _locationSubscriptions.remove(orderId);
    }

    if (removeLocation) {
      try {
        await _firestore.collection('orders').doc(orderId).update({
          'courierLocation': FieldValue.delete(),
        });
      } catch (_) {}
    }
  }

  /// Müşteriye in-app ve push bildirim gönder
  Future<void> notifyCustomer({
    required String customerId,
    required String orderId,
    required String title,
    required String message,
    required String type,
  }) async {
    if (customerId.isEmpty) return;

    try {
      // 1. In-app Bildirim
      await _firestore.collection('notifications').add({
        'to': customerId,
        'title': title,
        'message': message,
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type,
        'orderId': orderId,
        'targetType': 'order_tracking',
        'targetId': orderId,
      });

      // 2. Push Kuyruğu (Cloud Function tetikler)
      await _firestore.collection('customer_order_push_requests').add({
        'customerId': customerId,
        'title': title,
        'body': message,
        'orderId': orderId,
        'type': type,
        'targetType': 'order_tracking',
        'targetId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'statusText': 'queued',
      });
    } catch (e) {
      debugPrint('Müşteri bildirim hatası: $e');
    }
  }
}
