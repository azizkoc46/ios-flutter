// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Kullanıcılara kişisel Firestore bildirimi ve FCM Push Bildirimi gönderen servis.
class UserNotificationService {
  UserNotificationService._();
  static final instance = UserNotificationService._();

  /// Belirli bir kullanıcıya bildirim gönderir:
  /// 1. `notifications` koleksiyonuna in-app bildirim kaydı ekler (Bildirim Kutusu için).
  /// 2. `user_notification_requests` kuyruğuna ekler (Cloud Function tetikleyicisi için güvenli push bildirimi).
  Future<void> sendNotificationToUser({
    required String targetUid,
    required String title,
    required String body,
    String type = 'general',
    String? docId,
    Map<String, dynamic>? extraData,
  }) async {
    if (targetUid.isEmpty || targetUid == 'anonymous') {
      debugPrint('[UserNotification] Hedef kullanıcı geçersiz (anonim veya boş).');
      return;
    }

    final Map<String, dynamic> mergedData = {
      'type': type,
      'docId': docId ?? '',
      'targetId': docId ?? '',
      'targetType': 'cek_gonder',
      if (extraData != null) ...extraData,
    };

    try {
      // 1. In-app Bildirim Kutusu (notifications koleksiyonu)
      await FirebaseFirestore.instance.collection('notifications').add({
        'to': targetUid,
        'from': 'admin',
        'title': title,
        'body': body,
        'message': body,
        'type': type,
        'targetType': mergedData['targetType'] ?? 'cek_gonder',
        'targetId': docId ?? '',
        'docId': docId ?? '',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'time': FieldValue.serverTimestamp(),
        ...mergedData,
      });
      debugPrint('[UserNotification] notifications koleksiyonuna eklendi.');
    } catch (e) {
      debugPrint('[UserNotification] In-app bildirim kaydetme hatası: $e');
    }

    try {
      // 2. Cloud Function tetikleme kuyruğu
      await FirebaseFirestore.instance.collection('user_notification_requests').add({
        'targetUid': targetUid,
        'title': title,
        'body': body,
        'type': type,
        'docId': docId ?? '',
        'data': mergedData.map((k, v) => MapEntry(k, v.toString())),
        'status': 'queued',
        'requestedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserNotification] user_notification_requests kuyruğuna eklendi.');
    } catch (e) {
      debugPrint('[UserNotification] Kuyruk ekleme hatası: $e');
    }
  }
}
