import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String? normalizeTurkishMobile(String input) {
  var digits = input.replaceAll(RegExp(r'[\s()+.\-]'), '');
  if (digits.startsWith('0090')) digits = digits.substring(4);
  if (digits.startsWith('90') && digits.length == 12) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  return RegExp(r'^5\d{9}$').hasMatch(digits) ? '+90$digits' : null;
}

String phoneVerificationError(Object error) {
  final code = error is FirebaseException ? error.code : 'unexpected-error';
  final native39 = error is FirebaseException &&
      RegExp(r'error[ -]?code\s*:\s*-?39\b', caseSensitive: false)
          .hasMatch('${error.code} ${error.message ?? ''}');
  if (native39) {
    return 'SMS hizmeti isteği kabul etmedi. Bu hata tek başına çok fazla deneme yaptığınız anlamına gelmez. Destek ile iletişime geçin.\nHata kodu: $code / 39';
  }
  final message = switch (code) {
    'invalid-phone-number' =>
      'Geçerli bir Türkiye cep telefonu numarası girin.',
    'invalid-verification-code' =>
      'Kod hatalı. SMS içindeki 6 haneli kodu tekrar girin.',
    'session-expired' ||
    'invalid-verification-id' =>
      'Kodun süresi doldu. Yeni bir kod isteyin.',
    'too-many-requests' =>
      'Çok fazla deneme yapıldı. Bir süre bekleyip tekrar deneyin.',
    'quota-exceeded' ||
    'billing-not-enabled' =>
      'SMS hizmetinin kullanım sınırına ulaşıldı. Destek ile iletişime geçin.',
    'operation-not-allowed' ||
    'sms-region-not-allowed' =>
      'Bu numara için SMS gönderimi etkin değil. Destek ile iletişime geçin.',
    'app-not-authorized' ||
    'invalid-app-credential' ||
    'missing-app-credential' ||
    'missing-client-identifier' =>
      'Uygulamanın güvenlik doğrulaması tamamlanamadı. Uygulamayı güncelleyip tekrar deneyin.',
    'captcha-check-failed' ||
    'web-context-cancelled' =>
      'Güvenlik kontrolü tamamlanmadı. Tekrar deneyin.',
    'unauthorized-domain' =>
      'Bu adres üzerinden SMS gönderilemiyor. Destek ile iletişime geçin.',
    'network-request-failed' =>
      'İnternet bağlantınızı kontrol edip tekrar deneyin.',
    'request-timeout' =>
      'SMS isteği yanıt vermedi. Bağlantınızı kontrol edip tekrar deneyin.',
    'credential-already-in-use' ||
    'account-exists-with-different-credential' =>
      'Bu numara başka bir hesaba bağlı. O hesapla giriş yapın veya destek ile iletişime geçin.',
    'requires-recent-login' =>
      'Güvenlik için yeniden giriş yapıp telefonunuzu doğrulayın.',
    'user-changed' ||
    'user-not-found' =>
      'Oturumunuz değişti. Yeniden giriş yapın.',
    'permission-denied' =>
      'Telefon doğrulandı ancak profil kaydedilemedi. Kaydetmeyi yeniden deneyin.',
    _ =>
      'Doğrulama tamamlanamadı. Tekrar deneyin; sürerse hata kodunu destek ile paylaşın.',
  };
  return '$message\nHata kodu: $code';
}

abstract class PhoneVerificationGateway {
  Future<void> send({
    required String phone,
    required int? resendToken,
    required void Function(String, int?) codeSent,
    required void Function(PhoneAuthCredential) completed,
    required void Function(Object) failed,
  });
  Future<void> verify(PhoneAuthCredential credential, String phone);
  Future<void> save(String phone, [String? fullname]);
}

class FirebasePhoneVerificationGateway implements PhoneVerificationGateway {
  FirebasePhoneVerificationGateway(
      {FirebaseAuth? auth, FirebaseFirestore? store})
      : _auth = auth ?? FirebaseAuth.instance,
        _store = store ?? FirebaseFirestore.instance {
    _uid = _auth.currentUser?.uid;
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _store;
  late final String? _uid;

  User _user() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != _uid) {
      throw FirebaseAuthException(code: 'user-changed');
    }
    return user;
  }

  @override
  Future<void> send({
    required String phone,
    required int? resendToken,
    required void Function(String, int?) codeSent,
    required void Function(PhoneAuthCredential) completed,
    required void Function(Object) failed,
  }) async {
    _user();
    await _auth.setLanguageCode('tr');
    // The installed FlutterFire web SDK also implements verifyPhoneNumber.
    // Verification never signs out or unlinks the existing account.
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: kIsWeb ? null : resendToken,
      verificationCompleted: completed,
      verificationFailed: failed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<void> verify(PhoneAuthCredential credential, String phone) async {
    final user = _user();
    if (user.providerData.any((p) => p.providerId == 'phone')) {
      await user.updatePhoneNumber(credential);
    } else {
      await user.linkWithCredential(credential);
    }
    await _user().reload();
    if (_user().phoneNumber != phone) {
      throw FirebaseAuthException(code: 'phone-number-mismatch');
    }
  }

  @override
  Future<void> save(String phone, [String? fullname]) async {
    final user = _user();
    await user.reload();
    if (_user().phoneNumber != phone) {
      throw FirebaseAuthException(code: 'phone-number-mismatch');
    }
    // Refresh the phone_number claim before any rules-protected profile write.
    await _user().getIdToken(true);

    final cleanName = fullname?.trim();

    // 1. Firebase Auth displayName güncelle
    if (cleanName != null && cleanName.isNotEmpty) {
      try {
        await user.updateDisplayName(cleanName);
      } catch (e) {
        debugPrint('DisplayName güncelleme hatası: $e');
      }
    }

    // 2. Firestore'a doğrudan yazmayı dene
    try {
      final docRef = _store.collection('customers').doc(user.uid);
      DocumentSnapshot<Map<String, dynamic>>? snap;
      try {
        snap = await docRef.get();
      } catch (_) {}

      final data = <String, dynamic>{
        'phone': phone,
        'phoneNumber': phone,
        'phoneVerified': true,
        'isPhoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (cleanName != null && cleanName.isNotEmpty) {
        data['fullname'] = cleanName;
        data['fullName'] = cleanName;
        data['name'] = cleanName;
      }
      if (snap == null || !snap.exists) {
        data['email'] = user.email ?? '';
        data['role'] = 'customer';
        data['isApproved'] = false;
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await docRef.set(data, SetOptions(merge: true));
      return;
    } catch (e) {
      debugPrint('Firestore doğrudan kayıt hatası: $e. Cloud Function deneniyor...');
    }

    // 3. Fallback: Cloud Function HTTP çağrısı (Admin SDK ile permission-denied imkansız hale gelir)
    try {
      final token = await user.getIdToken();
      final url = Uri.parse(
          'https://us-central1-pazarcik-portal-7faf2.cloudfunctions.net/savePhoneAndProfile');
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'data': {
            'phone': phone,
            'fullname': cleanName ?? '',
          }
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return;
      } else {
        throw Exception('Cloud Function hata döndürdü: ${resp.body}');
      }
    } catch (cfError) {
      debugPrint('Cloud Function da başarısız: $cfError');
      rethrow;
    }
  }
}

class PhoneVerificationController extends ChangeNotifier {
  PhoneVerificationController(
      {required this.gateway,
      required this.phone,
      DateTime Function()? now,
      this.requestTimeout = const Duration(seconds: 120)})
      : _now = now ?? DateTime.now {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  final PhoneVerificationGateway gateway;
  final String phone;
  final DateTime Function() _now;
  final Duration requestTimeout;
  static const cooldown = Duration(seconds: 90);
  // Prevent closing/reopening the screen from resetting the resend limit.
  static final Map<String, DateTime> _sentAt = {};
  Timer? _ticker;
  Timer? _watchdog;
  bool _disposed = false;
  int _request = 0;
  String? _verificationId;
  int? _resendToken;
  bool sending = false;
  bool verifying = false;
  bool verified = false;
  bool done = false;
  String? error;
  bool get hasCode => _verificationId != null;
  int get secondsRemaining {
    final sent = _sentAt[phone];
    if (sent == null) return 0;
    return (cooldown.inSeconds - _now().difference(sent).inSeconds)
        .clamp(0, 90);
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _active(int request) => !_disposed && request == _request && !done;

  Future<void> send() async {
    if (_disposed || sending || verifying || verified || secondsRemaining > 0)
      return;
    if (normalizeTurkishMobile(phone) != phone) {
      error = phoneVerificationError(
          FirebaseAuthException(code: 'invalid-phone-number'));
      _emit();
      return;
    }
    final request = ++_request;
    sending = true;
    error = null;
    _emit();
    void fail(Object e) {
      if (!_active(request) || verified) return;
      _watchdog?.cancel();
      sending = false;
      error = phoneVerificationError(e);
      // Do not label an opaque backend error as a rate limit or log OTP/phone.
      debugPrint(
          'Phone verification/send: ${e is FirebaseException ? e.code : e.runtimeType}');
      _emit();
    }

    _watchdog?.cancel();
    _watchdog = Timer(requestTimeout, () {
      fail(FirebaseAuthException(code: 'request-timeout'));
      if (_request == request) _request++;
    });
    try {
      await gateway.send(
        phone: phone,
        resendToken: _resendToken,
        codeSent: (id, token) {
          if (!_active(request) || verified) return;
          _watchdog?.cancel();
          _verificationId = id;
          _resendToken = token;
          _sentAt[phone] = _now();
          sending = false;
          _ticker?.cancel();
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
          _emit();
        },
        completed: (credential) {
          if (_active(request)) unawaited(_complete(credential));
        },
        failed: fail,
      );
    } catch (e) {
      fail(e);
    }
  }

  Future<void> submit(String code, [String? fullname]) async {
    if (_disposed || sending || verifying || done) return;
    if (verified) {
      await _complete(null, fullname: fullname);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code) || _verificationId == null) {
      error = 'SMS içindeki 6 haneli kodu girin.';
      _emit();
      return;
    }
    await _complete(
        PhoneAuthProvider.credential(
            verificationId: _verificationId!, smsCode: code),
        fullname: fullname);
  }

  Future<void> _complete(PhoneAuthCredential? credential,
      {String? fullname}) async {
    if (_disposed || verifying || done) return;
    verifying = true;
    sending = false;
    error = null;
    _watchdog?.cancel();
    _emit();
    try {
      if (!verified) {
        await gateway.verify(credential!, phone);
        verified = true;
      }
      if (_disposed) return;
      await gateway
          .save(phone, fullname)
          .timeout(const Duration(seconds: 20));
      done = true;
      _ticker?.cancel();
    } catch (e) {
      error = verified
          ? 'Telefon doğrulandı ancak profil kaydedilemedi. SMS istemeden yeniden kaydetmeyi deneyin.\nHata kodu: ${e is FirebaseException ? e.code : 'profile-save-failed'}'
          : phoneVerificationError(e);
      debugPrint(
          'Phone verification/${verified ? 'save' : 'verify'}: ${e is FirebaseException ? e.code : e.runtimeType}');
    } finally {
      verifying = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _ticker?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}
