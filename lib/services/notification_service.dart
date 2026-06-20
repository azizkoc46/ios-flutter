import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pazarcik_portal/services/earthquake_page.dart';
import 'package:pazarcik_portal/views/bildirimkutusuanasayfa.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/seller/dashboard_screens/orders.dart'; // Sayfanın bulunduğu gerçek dosya yolu

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? navigatorKey;

  // --- KANALLAR ---
  // 🔥 Genel bildirimler
  static const AndroidNotificationChannel mainChannel =
      AndroidNotificationChannel(
    'pazarcik_main_channel_v5',
    'Genel Bildirimler',
    description: 'Haber, duyuru ve genel mesajlar.',
    importance: Importance.max,
    playSound: true,
  );

  // 🔥 ESNAF SİPARİŞ KANALI (v5 OLARAK TERTEMİZ BAŞLIYOR)
  static const AndroidNotificationChannel sellerOrderChannel =
      AndroidNotificationChannel(
    'seller_order_channel_v5',
    'Mağaza Sipariş Uyarıları',
    description: 'Yeni sipariş geldiğinde çalan kanal.',
    importance: Importance.max, // En yüksek öncelik
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel customerOrderChannel =
      AndroidNotificationChannel(
    'customer_order_channel_v5',
    'Sipariş Durum Güncellemeleri',
    importance: Importance.max,
    playSound: true,
  );

  static const AndroidNotificationChannel namazChannel =
      AndroidNotificationChannel(
    'namaz_vakti_channel_v4',
    'Namaz Vakti Hatırlatıcı',
    importance: Importance.max,
    playSound: true,
  );

  static const AndroidNotificationChannel earthquakeChannel =
      AndroidNotificationChannel(
    'earthquake_alert_channel_v1',
    'Deprem Bilgilendirmeleri',
    description: 'Bölgesel deprem bilgilendirme bildirimleri.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;

    if (!kIsWeb) {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }

    // 1. Bildirim İzinleri (Hem Android hem iOS için ses izni istenir)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Foreground Ayarları (Uygulama açıkken tepeden sesli düşmesi için)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Android Kanallarını Sisteme Kaydet
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(mainChannel);
    await androidPlugin?.createNotificationChannel(sellerOrderChannel);
    await androidPlugin?.createNotificationChannel(customerOrderChannel);
    await androidPlugin?.createNotificationChannel(namazChannel);
    await androidPlugin?.createNotificationChannel(earthquakeChannel);

    // 4. Local Notifications Başlatma
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) =>
          _handleNotificationClick(details.payload),
    );

    // 5. Token İşlemleri
    _saveToken();
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateTokenInFirestore);
    await FirebaseMessaging.instance.subscribeToTopic("all_users");
    await FirebaseMessaging.instance.subscribeToTopic("pazarcik_duyuru");

    // 6. Dinleyiciler
    FirebaseMessaging.onMessage.listen(_showNotification);
    FirebaseMessaging.onMessageOpenedApp
        .listen((msg) => _handleNotificationClick(jsonEncode(msg.data)));

    // 7. Kapalıyken Tıklanma
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1),
          () => _handleNotificationClick(jsonEncode(initialMessage.data)));
    }
  }

  // --- UYGULAMA AÇIKKEN (FOREGROUND) BİLDİRİM GÖSTERİMİ ---
  void _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    if (notification == null && data.isEmpty) return;

    String type = data['type'] ?? 'default';
    AndroidNotificationChannel targetChannel = mainChannel;

    if (type == 'new_order' || type == 'order') {
      targetChannel = sellerOrderChannel;
      debugPrint("Esnafa yeni sipariş bildirimi tetiklendi.");
    } else if (type == 'order_status' || type == 'order_update') {
      targetChannel = customerOrderChannel;
    } else if (type == 'namaz') {
      targetChannel = namazChannel;
    } else if (type == 'earthquake') {
      targetChannel = earthquakeChannel;
    }

    BigPictureStyleInformation? bigPictureStyle;
    if (data['image'] != null && data['image'].toString().isNotEmpty) {
      try {
        final String imagePath = await _downloadAndSaveFile(
            data['image'], 'img_${DateTime.now().millisecond}.jpg');
        bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          contentTitle: notification?.title ?? data['title'],
          summaryText: notification?.body ?? data['body'],
        );
      } catch (e) {
        debugPrint("Resim hatası: $e");
      }
    }

    _localNotifications.show(
      DateTime.now().millisecond,
      notification?.title ?? data['title'],
      notification?.body ?? data['body'],
      NotificationDetails(
        android: AndroidNotificationDetails(
          targetChannel.id,
          targetChannel.name,
          channelDescription: targetChannel.description,
          importance: Importance.max, // ZORUNLU: Açılır pencere için
          priority: Priority.max, // ZORUNLU: Açılır pencere için
          styleInformation: bigPictureStyle,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF0056D2),
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

// --- TIKLAMA YÖNETİMİ ---
  Future<void> _handleNotificationClick(String? payload) async {
    if (payload == null) return;
    Map<String, dynamic> data = jsonDecode(payload);
    String type = data['type'] ?? '';

    final externalUrl = (data['linkUrl'] ?? data['url'] ?? '').toString();
    if (externalUrl.isNotEmpty) {
      final uri = Uri.parse(externalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final notificationId = (data['notificationId'] ?? '').toString();
    if (notificationId.isNotEmpty) {
      await _markAppNotificationAsRead(notificationId);
    }

    // Navigator durumunu kontrol ediyoruz
    if (navigatorKey?.currentState == null) return;
    final navigator = navigatorKey!.currentState!;

    if (type == 'complaint_reply') {
      showSimpleDetail(
          data['title'] ?? "Yanıt", data['message'] ?? "Mesajınız var.");
    } else if (type == 'poll') {
      _showPollDialog(
          data['question'] ?? "Anket",
          List<String>.from(jsonDecode(data['options'] ?? '[]')),
          data['pollId'] ?? "0");
    } else if (type == 'Anket' || type == 'Duyuru') {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const BildirimKutusuAnaSayfa(),
        ),
      );
    }
    // 🔥 ROTA OLMADAN DOĞRUDAN SAYFAYI AÇAN YENİ KISIM
    else if (type == 'new_order' || type == 'order') {
      navigator.push(
        MaterialPageRoute(
          builder: (context) =>
              const OrdersScreen(), // Esnafın sipariş sayfa sınıfı
        ),
      );
    } else if (type == 'order_status' || type == 'order_update') {
      if (navigatorKey?.currentContext != null) {
        Navigator.pushNamed(navigatorKey!.currentContext!, '/my-orders');
      }
    } else if (type == 'earthquake') {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const EarthquakePage(),
        ),
      );
    } else if (data['route'] != null && navigatorKey?.currentContext != null) {
      Navigator.pushNamed(navigatorKey!.currentContext!, data['route']);
    }
  }

  Future<void> _markAppNotificationAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('app_notifications')
        .doc(notificationId)
        .collection('reads')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'userName': user.displayName ?? user.email ?? 'Kullanıcı',
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- ANKET DİYALOGU ---
  void _showPollDialog(String question, List<String> options, String pollId) {
    if (navigatorKey?.currentContext == null) return;
    showCupertinoDialog(
      context: navigatorKey!.currentContext!,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("📊 Görüşünüz"),
        content: Column(
          children: [
            const SizedBox(height: 10),
            Text(question),
            const SizedBox(height: 15),
            ...options.map((opt) => CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Text(opt),
                  onPressed: () async {
                    Navigator.pop(context);
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('polls')
                          .doc(pollId)
                          .collection('votes')
                          .add({
                        'uid': user.uid,
                        'choice': opt,
                        'date': FieldValue.serverTimestamp(),
                      });
                      showSimpleDetail("Teşekkürler", "Oyunuz kaydedildi.");
                    }
                  },
                )),
          ],
        ),
        actions: [
          CupertinoDialogAction(
              child: const Text("Kapat"),
              onPressed: () => Navigator.pop(context))
        ],
      ),
    );
  }

  // --- TOPIC / HABER ABONELİK ---
  Future<void> updateSubscription(String kategori, String secilenSiklik) async {
    final tumTopicler = [
      "gundem_aninda",
      "gundem_saatlik",
      "gundem_gunluk",
      "maras_aninda",
      "maras_saatlik",
      "maras_gunluk",
      "pazarcik_aninda",
      "pazarcik_saatlik",
      "pazarcik_gunluk"
    ];

    for (var topic in tumTopicler) {
      if (topic.startsWith(kategori)) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    }

    if (secilenSiklik.isNotEmpty) {
      String yeniTopic = kategori + secilenSiklik;
      await FirebaseMessaging.instance.subscribeToTopic(yeniTopic);
      debugPrint("Yeni Abonelik: $yeniTopic");
    }
  }

  // --- TOKEN YÖNETİMİ ---
  Future<void> _saveToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _updateTokenInFirestore(token);
    } catch (e) {
      debugPrint("FCM token alma hatası: $e");
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // KRITIK DUZELTME:
    // _ensureGuestSession() (main.dart) uygulama acilisinda otomatik
    // olarak anonim bir oturum aciyor. Bu fonksiyon o anonim kullanici
    // icin de tetikleniyordu ve customers/{uid} dokumani henuz mevcut
    // olmadigindan set(merge:true) cagrisi Firestore tarafindan bir
    // "create" islemi olarak degerlendiriliyordu. Guvenlik kurallarindaki
    // create sarti ise 'role' alaninin string olmasini istiyor (admin
    // olamayacak sekilde), ama burada sadece fcmToken/lastActive
    // gonderiliyordu. Sonuc: PERMISSION_DENIED, ve bu hata yakalanmadigi
    // icin uygulama acilisi tamamen patliyordu.
    // Anonim kullanicinin zaten kendi customers belgesi olmayacagi icin
    // (gercek hesaba gecince zaten yeni token kaydedilecek) bu kullanici
    // turunde islemi tamamen atliyoruz.
    if (user.isAnonymous) {
      debugPrint("Anonim kullanıcı için FCM token kaydı atlandı.");
      return;
    }

    try {
      await FirebaseMessaging.instance.subscribeToTopic("customer_${user.uid}");

      final userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      // Doküman henüz oluşmamışsa (örn. kayıt akışı henüz tamamlanmadan
      // token güncellemesi tetiklendiyse) burada da yazmayı atlıyoruz;
      // aksi halde aynı PERMISSION_DENIED senaryosuna düşeriz.
      if (!userDoc.exists) {
        debugPrint(
            "customers/${user.uid} henüz oluşmamış, FCM token kaydı atlandı.");
        return;
      }

      final role = (userDoc.data()?['role'] ?? '').toString();
      if (role == 'satici' || role == 'seller' || role == 'kurumsal_satici') {
        await FirebaseMessaging.instance.subscribeToTopic("seller_${user.uid}");
        await FirebaseFirestore.instance
            .collection('sellers')
            .doc(user.uid)
            .set({
          'sellerNotificationEnabled': true,
          'fcmToken': token,
        }, SetOptions(merge: true));
      }

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .set({
        'fcmToken': token,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Bu islem arka planda calisiyor; basarisiz olsa bile uygulama
      // acilisini ya da kullanici akisini bloklamamali.
      debugPrint("FCM token Firestore güncelleme hatası: $e");
    }
  }

  // --- ESNAF BİLDİRİMİNİ KALICI OLARAK AÇ ---
  Future<void> subscribeAsSeller(String sellerId) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic("seller_$sellerId");

      // 🔥 DÜZELTME: Esnaf bilgisi 'customers' değil 'sellers' koleksiyonundadır!
      await FirebaseFirestore.instance.collection('sellers').doc(sellerId).set(
          {
            'sellerNotificationEnabled': true,
          },
          SetOptions(
              merge:
                  true)); // Belge yoksa oluşturması için set(merge:true) kullanıldı

      debugPrint(
          "🚀 Esnaf cihazı kalıcı olarak seller_$sellerId konusuna abone oldu.");
    } catch (e) {
      debugPrint("Abonelik hatası: $e");
    }
  }

  // --- ESNAF BİLDİRİMİNİ KALICI OLARAK KAPAT ---
  Future<void> unsubscribeAsSeller(String sellerId) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic("seller_$sellerId");

      // 🔥 DÜZELTME: Esnaf bilgisi 'customers' değil 'sellers' koleksiyonundadır!
      await FirebaseFirestore.instance.collection('sellers').doc(sellerId).set({
        'sellerNotificationEnabled': false,
      }, SetOptions(merge: true));

      debugPrint("🛑 Esnaf cihazı seller_$sellerId konusundan ayrıldı.");
    } catch (e) {
      debugPrint("Abonelikten çıkma hatası: $e");
    }
  }

  // --- NAMAZ VAKTİ BİLDİRİMİ ---
  Future<void> showNamazAlert(String vakitAdi) async {
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        namazChannel.id,
        namazChannel.name,
        channelDescription: namazChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF0056D2),
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );

    await _localNotifications.show(
      999,
      "🕌 Ezan Vakti: $vakitAdi",
      "Pazarcık için $vakitAdi vakti geldi. Rabbim kabul etsin.",
      platformChannelSpecifics,
      payload: jsonEncode({'type': 'namaz', 'vakit': vakitAdi}),
    );
  }

  Future<void> schedulePrayerAlerts(Map<String, String> prayerTimes) async {
    if (kIsWeb) return;

    await cancelPrayerAlerts();
    final entries = prayerTimes.entries
        .where((entry) => entry.key != 'Güneş')
        .toList(growable: false);

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(entry.value);
      if (match == null) continue;

      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final now = tz.TZDateTime.now(tz.local);
      var scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        7100 + index,
        'Ezan Vakti: ${entry.key}',
        'Pazarcık için ${entry.key} vakti geldi.',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            namazChannel.id,
            namazChannel.name,
            channelDescription: namazChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({'type': 'namaz', 'vakit': entry.key}),
      );
    }
  }

  Future<void> cancelPrayerAlerts() async {
    if (kIsWeb) return;
    for (var index = 0; index < 6; index++) {
      await _localNotifications.cancel(7100 + index);
    }
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final response = await http.get(Uri.parse(url));
    await File(filePath).writeAsBytes(response.bodyBytes);
    return filePath;
  }

  void showSimpleDetail(String title, String body) {
    if (navigatorKey?.currentContext == null) return;
    showCupertinoDialog(
      context: navigatorKey!.currentContext!,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(
              child: const Text("Tamam"),
              onPressed: () => Navigator.pop(context))
        ],
      ),
    );
  }
}
