import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Admin paneli üzerinden yönetilen genel güvenlik ve sistem ayarları servisi.
class SystemSettingsService extends ChangeNotifier {
  static final SystemSettingsService instance = SystemSettingsService._internal();

  SystemSettingsService._internal();

  bool _requirePhoneVerification = false;
  bool _blockAnonymousUsers = false;
  bool _initialized = false;
  StreamSubscription<DocumentSnapshot>? _subscription;

  bool get requirePhoneVerification => _requirePhoneVerification;
  bool get blockAnonymousUsers => _blockAnonymousUsers;
  bool get isInitialized => _initialized;

  /// Servisi başlatır ve gerçek zamanlı olarak ayar değişikliklerini dinler.
  void init() {
    if (_initialized) return;
    _initialized = true;

    try {
      _subscription = FirebaseFirestore.instance
          .collection('app_settings')
          .doc('general')
          .snapshots()
          .listen(
        (doc) {
          if (doc.exists) {
            final data = doc.data();
            _requirePhoneVerification =
                data?['requirePhoneVerification'] == true;
            _blockAnonymousUsers = data?['blockAnonymousUsers'] == true;
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('SystemSettingsService dinleme hatası: $e');
        },
      );
    } catch (e) {
      debugPrint('SystemSettingsService init hatası: $e');
    }
  }

  /// Belirli bir kullanıcının telefonunun doğrulanıp doğrulanmadığını kontrol eder.
  Future<bool> isUserPhoneVerified([User? user]) async {
    final targetUser = user ?? FirebaseAuth.instance.currentUser;
    if (targetUser == null || targetUser.isAnonymous) return false;

    // Firebase Auth üzerinde doğrudan doğrulanmış telefon varsa
    if (targetUser.phoneNumber != null && targetUser.phoneNumber!.isNotEmpty) {
      return true;
    }

    try {
      // Önce customers koleksiyonuna bak
      final custDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(targetUser.uid)
          .get();

      if (custDoc.exists &&
          (custDoc.data()?['phoneVerified'] == true ||
              custDoc.data()?['isPhoneVerified'] == true)) {
        return true;
      }

      // users koleksiyonuna da bak (yedek)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUser.uid)
          .get();

      if (userDoc.exists &&
          (userDoc.data()?['phoneVerified'] == true ||
              userDoc.data()?['isPhoneVerified'] == true)) {
        return true;
      }
    } catch (e) {
      debugPrint('Telefon doğrulama durumu kontrol hatası: $e');
    }

    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
