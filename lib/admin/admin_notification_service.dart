// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AdminNotificationService {
  AdminNotificationService._();
  static final instance = AdminNotificationService._();

  static const String _adminsCollection = 'admin_tokens';

  Future<void> registerAdminToken(String adminUid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      try {
        await messaging.subscribeToTopic('portal_admins');
      } catch (e) {
        print('[AdminNotif] Topic aboneligi atlandi: $e');
      }

      final token = await messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection(_adminsCollection)
          .doc(adminUid)
          .set({
        'token': token,
        'uid': adminUid,
        'platform': 'mobile',
        'topics': ['portal_admins'],
        'enabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection(_adminsCollection)
            .doc(adminUid)
            .set({
          'token': newToken,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      print('[AdminNotif] Token kaydedildi.');
    } catch (e) {
      print('[AdminNotif] Token kayit hatasi: $e');
    }
  }

  Future<void> notifyAdmin({
    required String title,
    required String body,
    String type = 'general',
    String? docId,
    Map<String, String>? extra,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_notification_requests')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'docId': docId ?? '',
        'extra': extra ?? <String, String>{},
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('[AdminNotif] Admin bildirimi kuyruga alindi.');
    } catch (e) {
      print('[AdminNotif] Bildirim kuyrugu hatasi: $e');
    }
  }
}

class AdminNotifType {
  static const String complaint = 'complaint';
  static const String cekGonder = 'cek_gonder';
  static const String businessApply = 'business_apply';
  static const String announcement = 'announcement';
  static const String classifiedAd = 'classified_ad';
  static const String storeOrder = 'store_order';
  static const String comment = 'comment';
  static const String corporateApply = 'corporate_apply';
  static const String userRegister = 'user_register';
  static const String ownershipClaim = 'ownership_claim';
  static const String general = 'general';

  static String emoji(String type) {
    switch (type) {
      case complaint:
        return '!';
      case cekGonder:
        return 'C';
      case businessApply:
        return 'B';
      case announcement:
        return 'A';
      case classifiedAd:
        return 'I';
      case storeOrder:
        return 'S';
      case comment:
        return 'Y';
      case corporateApply:
        return 'K';
      case userRegister:
        return 'U';
      case ownershipClaim:
        return 'S';
      default:
        return 'N';
    }
  }
}
