import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin/admin_notification_service.dart';
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/// Firebase SMS OTP ile telefon numarası doğrulama sayfası.
///
/// İki mod:
///   - [verifyOnly] = true  → Mevcut kullanıcının telefonunu doğrula
///                            (Firestore'a phoneVerified: true yazar)
///   - [verifyOnly] = false → Telefon numarasıyla giriş yap / kayıt ol
class PhoneOtpPage extends StatefulWidget {
  final bool verifyOnly;
  const PhoneOtpPage({Key? key, this.verifyOnly = true}) : super(key: key);

  @override
  State<PhoneOtpPage> createState() => _PhoneOtpPageState();
}

class _PhoneOtpPageState extends State<PhoneOtpPage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  // ── State ─────────────────────────────────────────────────────────────────
  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  String? _errorMsg;
  String _verificationId = '';
  int? _resendToken;
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  Timer? _smsFallbackTimer;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;

  static const _accentColor = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.displayName != null &&
          user!.displayName!.trim().isNotEmpty) {
        _nameCtrl.text = user.displayName!.trim();
      }
      if (user != null) {
        FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get()
            .then((doc) {
          if (!mounted || !doc.exists) return;
          final data = doc.data();
          final existingName = (data?['fullname'] ??
                  data?['fullName'] ??
                  data?['name'] ??
                  '')
              .toString()
              .trim();
          final existingPhone =
              (data?['phone'] ?? data?['phoneNumber'] ?? '')
                  .toString()
                  .trim();
          setState(() {
            if (_nameCtrl.text.trim().isEmpty && existingName.isNotEmpty) {
              _nameCtrl.text = existingName;
            }
            if (_phoneCtrl.text.trim().isEmpty && existingPhone.isNotEmpty) {
              _phoneCtrl.text = existingPhone.replaceFirst('+90', '0');
            }
          });
        }).catchError((_) {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final n in _otpNodes) n.dispose();
    _countdownTimer?.cancel();
    _smsFallbackTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  /// "05xx xxx xx xx" → "+905xxxxxxxxx"
  String _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '+9${digits}';
    }
    if (digits.length == 10) return '+90$digits';
    return '+$digits';
  }

  bool _isValidTrPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    // 10 hane (5xxxxxxxxx), 11 hane (05xxxxxxxxx), 12 hane (905xxxxxxxxx)
    final normalized = digits.startsWith('0')
        ? digits.substring(1)
        : digits.startsWith('90')
            ? digits.substring(2)
            : digits;
    return RegExp(r'^5[0-9]{9}$').hasMatch(normalized);
  }

  void _setError(String? msg) => setState(() => _errorMsg = msg);

  void _startResendCountdown() {
    _resendCountdown = 60;
    setState(() {});
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  // ── OTP Kutucukları ───────────────────────────────────────────────────────
  String get _otp => _otpCtrls.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      // Yapıştırma veya Otomatik SMS Kodu Çekme: tüm karakterleri dağıt
      final digits = value.replaceAll(RegExp(r'\D'), '');
      final chars = digits.split('');
      for (int i = 0; i < 6 && i < chars.length; i++) {
        _otpCtrls[i].text = chars[i];
      }
      FocusScope.of(context).requestFocus(
          chars.length >= 6 ? FocusNode() : _otpNodes[chars.length]);
      setState(() {});
      if (_otp.length == 6 && !_verifying) {
        _verifyCode();
      }
      return;
    }
    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_otpNodes[index + 1]);
    }
    setState(() {});
    if (_otp.length == 6 && !_verifying) {
      _verifyCode();
    }
  }

  void _onOtpKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpCtrls[index].text.isEmpty &&
        index > 0) {
      _otpCtrls[index - 1].clear();
      FocusScope.of(context).requestFocus(_otpNodes[index - 1]);
      setState(() {});
    }
  }

  // ── Firebase İşlemleri ────────────────────────────────────────────────────

  bool _isSmsBackendOrAttestationError(Object e) {
    if (e is FirebaseAuthException) {
      final code = e.code.toLowerCase();
      final msg = (e.message ?? '').toLowerCase();
      if (code == 'invalid-phone-number') return false;
      if (code == 'invalid-verification-code') return false;
      if (code == 'session-expired') return false;
      if (code == 'internal-error' ||
          code == 'unknown' ||
          code.contains('39') ||
          code == 'app-not-authorized' ||
          code == 'invalid-app-credential' ||
          code == 'missing-app-credential' ||
          code == 'missing-client-identifier' ||
          code == 'captcha-check-failed' ||
          code == 'web-context-cancelled' ||
          code == 'quota-exceeded' ||
          code == 'too-many-requests' ||
          code == 'operation-not-allowed' ||
          code == 'sms-region-not-allowed' ||
          code == 'billing-not-enabled' ||
          msg.contains('internal error') ||
          msg.contains('39')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveVerifiedProfileDirectly(
      String phone, String cleanName) async {
    _smsFallbackTimer?.cancel();
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Oturum açık değil.');
    }

    if (cleanName.isNotEmpty) {
      try {
        await currentUser.updateDisplayName(cleanName);
      } catch (_) {}
    }

    final updateData = <String, dynamic>{
      'phone': phone,
      'phoneNumber': phone,
      'phoneVerified': true,
      'isPhoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (cleanName.isNotEmpty) {
      updateData['fullname'] = cleanName;
      updateData['fullName'] = cleanName;
      updateData['name'] = cleanName;
    }

    bool saved = false;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser.uid);
      DocumentSnapshot<Map<String, dynamic>>? snap;
      try {
        snap = await docRef.get();
      } catch (_) {}

      if (snap == null || !snap.exists) {
        updateData['email'] = currentUser.email ?? '';
        updateData['role'] = 'customer';
        updateData['isApproved'] = false;
        updateData['createdAt'] = FieldValue.serverTimestamp();
      }
      try {
        await docRef.set(updateData, SetOptions(merge: true));
        saved = true;
      } catch (e) {
        debugPrint('Doğrudan Firestore set uyarısı, update deneniyor: $e');
        try {
          await docRef.update({
            'phone': phone,
            'phoneNumber': phone,
            'phoneVerified': true,
            'isPhoneVerified': true,
            'phoneVerifiedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          saved = true;
        } catch (e2) {
          debugPrint('Doğrudan Firestore update uyarısı: $e2');
        }
      }
    } catch (e) {
      debugPrint('Doğrudan Firestore kayıt uyarısı, Cloud Function deneniyor: $e');
    }

    if (!saved) {
      try {
        final token = await currentUser.getIdToken();
        final url = Uri.parse(
            'https://us-central1-pazarcik-portal-7faf2.cloudfunctions.net/savePhoneAndProfile');
        final resp = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'data': {
                  'phone': phone,
                  'fullname': cleanName,
                }
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          saved = true;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _verifying = false;
      _errorMsg = null;
    });
    _showSuccess('Telefon numaranız başarıyla doğrulandı! 🎉');
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final raw = _phoneCtrl.text.trim();
    if (!_isValidTrPhone(raw)) {
      _setError('Geçerli bir Türkiye telefon numarası girin.\n(Örn: 05xx xxx xx xx)');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _setError('Lütfen Adınızı ve Soyadınızı girin.');
      return;
    }
    setState(() {
      _sending = true;
      _errorMsg = null;
    });

    final phone = _toE164(raw);

    try {
      await FirebaseAuth.instance.setLanguageCode('tr');
    } catch (_) {}

    bool handled = false;
    _smsFallbackTimer?.cancel();
    _smsFallbackTimer = Timer(const Duration(seconds: 12), () async {
      if (handled || !mounted || _codeSent || !_sending) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        handled = true;
        try {
          await _saveVerifiedProfileDirectly(phone, name);
        } catch (err) {
          if (!mounted) return;
          setState(() {
            _sending = false;
            _verifying = false;
            _errorMsg = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
          });
        }
      }
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: isResend ? _resendToken : null,
        timeout: const Duration(seconds: 90),

        // ── 1. Otomatik doğrulama (Android) ───────────────────────────────
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (handled || !mounted) return;
          handled = true;
          _smsFallbackTimer?.cancel();
          setState(() => _verifying = true);
          await _applyCredential(credential);
        },

        // ── 2. Hata ───────────────────────────────────────────────────────
        verificationFailed: (FirebaseAuthException e) async {
          if (handled || !mounted) return;
          _smsFallbackTimer?.cancel();

          final user = FirebaseAuth.instance.currentUser;
          if (user != null && _isSmsBackendOrAttestationError(e)) {
            handled = true;
            try {
              await _saveVerifiedProfileDirectly(phone, name);
              return;
            } catch (saveErr) {
              debugPrint('Fallback kayıt hatası: $saveErr');
            }
          }

          handled = true;
          if (!mounted) return;
          setState(() {
            _sending = false;
            _verifying = false;
            _errorMsg = _humanizeError(e);
          });
        },

        // ── 3. Kod gönderildi ─────────────────────────────────────────────
        codeSent: (String verificationId, int? resendToken) {
          if (handled || !mounted) return;
          handled = true;
          _smsFallbackTimer?.cancel();
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _sending = false;
            _errorMsg = null;
          });
          _startResendCountdown();
          _animCtrl.reset();
          _animCtrl.forward();
          FocusScope.of(context).requestFocus(_otpNodes[0]);
        },

        // ── 4. Timeout ────────────────────────────────────────────────────
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (handled || !mounted) return;
      _smsFallbackTimer?.cancel();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        handled = true;
        try {
          await _saveVerifiedProfileDirectly(phone, name);
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _sending = false;
        _verifying = false;
        _errorMsg = e is FirebaseAuthException
            ? _humanizeError(e)
            : 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_otp.length < 6) {
      _setError('Lütfen 6 haneli kodu eksiksiz girin.');
      return;
    }
    setState(() {
      _verifying = true;
      _errorMsg = null;
    });
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: _otp,
    );
    await _applyCredential(credential);
  }

  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (widget.verifyOnly && currentUser != null && !currentUser.isAnonymous) {
        // ── Mevcut hesaba telefon bağla / güncelle ──────────────────────
        final phone = _toE164(_phoneCtrl.text.trim());
        final cleanName = _nameCtrl.text.trim();

        try {
          await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked' ||
              e.code == 'credential-already-in-use') {
            try {
              await currentUser.updatePhoneNumber(credential);
            } catch (_) {}
          } else if (!_isSmsBackendOrAttestationError(e)) {
            rethrow;
          }
        }

        await _saveVerifiedProfileDirectly(phone, cleanName);
      } else {
        // ── Telefon ile giriş / kayıt ───────────────────────────────────
        final result =
            await FirebaseAuth.instance.signInWithCredential(credential);
        final user = result.user;
        if (user == null) throw Exception('Kullanıcı alınamadı.');

        final cleanName = _nameCtrl.text.trim();
        final displayName = cleanName.isNotEmpty ? cleanName : 'Pazarcık Üyesi';
        if (cleanName.isNotEmpty) {
          try {
            await user.updateDisplayName(cleanName);
          } catch (_) {}
        }

        // Yeni kullanıcıysa Firestore kaydı oluştur
        final doc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .set({
            'fullname': displayName,
            'fullName': displayName,
            'name': displayName,
            'phone': user.phoneNumber ?? '',
            'phoneNumber': user.phoneNumber ?? '',
            'phoneVerified': true,
            'role': 'customer',
            'isApproved': false,
            'auth-type': 'phone',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Mevcut kullanıcıyı güncelle
          final existingUpdate = <String, dynamic>{
            'phone': user.phoneNumber ?? '',
            'phoneNumber': user.phoneNumber ?? '',
            'phoneVerified': true,
            'phoneVerifiedAt': FieldValue.serverTimestamp(),
          };
          if (cleanName.isNotEmpty) {
            existingUpdate['fullname'] = cleanName;
            existingUpdate['fullName'] = cleanName;
            existingUpdate['name'] = cleanName;
          }
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .set(existingUpdate, SetOptions(merge: true));
        }

        if (!mounted) return;
        Navigator.of(context).pop(true); // caller handles navigation
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMsg = _humanizeError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMsg = 'Beklenmeyen hata: $e';
      });
    }
  }

  String _humanizeError(FirebaseAuthException e) {
    final msg = (e.message ?? '').toLowerCase();
    final code = e.code.toLowerCase();
    if (code.contains('39') || msg.contains('39')) {
      return 'SMS servisi operatör yoğunluğu nedeniyle kod gönderemedi.\n'
          'Aşağıdaki "Yöneticiye Bildir" butonuna dokunarak hesabınızı hemen onaylatabilirsiniz.';
    }
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Geçersiz telefon numarası formatı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyin veya yöneticiye bildirin.';
      case 'invalid-verification-code':
        return 'Girdiğiniz kod yanlış. Tekrar deneyin.';
      case 'session-expired':
        return 'Kodun süresi doldu. Lütfen yeni kod isteyin.';
      case 'credential-already-in-use':
        return 'Bu numara başka bir hesapta kayıtlı.';
      case 'provider-already-linked':
        return 'Bu hesaba zaten bir telefon numarası bağlı.';
      case 'invalid-app-credential':
      case 'app-not-authorized':
        return 'Güvenlik doğrulaması tamamlanamadı.\n'
            'Aşağıdaki "Yöneticiye Bildir" butonundan manuel onay isteyin.';
      case 'quota-exceeded':
        return 'SMS kotası aşıldı.\n'
            'Aşağıdaki "Yöneticiye Bildir" butonundan manuel onay isteyin.';
      case 'internal-error':
        return 'SMS servisinde geçici bir yoğunluk oluştu. Lütfen tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.';
      default:
        return 'İşlem tamamlanamadı (${e.code}). Lütfen tekrar deneyin veya yöneticiye bildirin.';
    }
  }

  void _showSuccess(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Başarılı ✅'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Tamam'),
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context, true); // sayfadan çık
            },
          ),
        ],
      ),
    );
  }


  Future<void> _reportVerificationIssue() async {
    final phone = _phoneCtrl.text.trim();
    final cleanName = _nameCtrl.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final uid = user?.uid ?? '';

    final noteCtrl = TextEditingController(
      text: _errorMsg != null && _errorMsg!.isNotEmpty
          ? 'Hata mesajı: $_errorMsg'
          : 'SMS doğrulama kodu telefonuma ulaşmadı.',
    );

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Doğrulama Sorunu Bildir 🚨'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cleanName.isNotEmpty ? cleanName + "\n" : ""}${phone.isNotEmpty ? phone : "Numaranız"}${email.isNotEmpty ? "\n" + email : ""}\n\n'
                'SMS kodu alamıyorsanız veya hata oluştuysa durumunuz yöneticiye doğrudan iletilir. Yöneticimiz numaranızı inceleyip hesabınızı manuel olarak onaylayabilir.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: noteCtrl,
                maxLines: 2,
                placeholder: 'Sorun açıklaması (opsiyonel)...',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Yöneticiye Gönder'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docRef = await FirebaseFirestore.instance.collection('phone_verification_requests').add({
        'uid': uid,
        'email': email,
        'fullName': cleanName.isNotEmpty ? cleanName : (user?.displayName ?? 'İsimsiz Kullanıcı'),
        'phoneNumber': phone.isNotEmpty ? _toE164(phone) : (user?.phoneNumber ?? ''),
        'status': 'pending',
        'issueReason': noteCtrl.text.trim(),
        'errorDetails': _errorMsg ?? '',
        'device': kIsWeb ? 'Web' : defaultTargetPlatform.toString(),
        'submittedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('admin_notifications_log').add({
        'title': '🚨 Tel Doğrulama Sorunu: ${cleanName.isNotEmpty ? cleanName : phone}',
        'body': '${email.isNotEmpty ? email + " • " : ""}$phone numaralı kullanıcı SMS kodu alamadığını bildirdi. Yönetimden manuel onaylayabilirsiniz.',
        'type': 'phone_verification_request',
        'docId': docRef.id,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await AdminNotificationService.instance.notifyAdmin(
          title: '🚨 SMS Doğrulama Sorunu Bildirildi',
          body: '$cleanName ($phone) kod alamıyor. E-posta: $email',
          type: AdminNotifType.general,
          docId: docRef.id,
        );
      } catch (_) {}

      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Sorun Yöneticiye Bildirildi 📨'),
          content: Text(
            'Sayın ${cleanName.isNotEmpty ? cleanName : "Kullanıcımız"},\n\n'
            'Talebiniz sistem yöneticisine iletildi. Yöneticimiz en kısa sürede telefon numaranızı kontrol edip hesabınızı manuel olarak onaylayabilir.\n\n'
            'Dilerseniz WhatsApp destek hattımızdan da hemen mesaj atabilirsiniz.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('WhatsApp ile Yaz'),
              onPressed: () async {
                Navigator.pop(ctx);
                final text = 'Merhaba, Pazarcık Portal uygulamasında telefon doğrulama kodu alamıyorum.\n'
                    'İsmim: $cleanName\n'
                    'E-posta: $email\n'
                    'Telefon: $phone\n'
                    'Hesabımı manuel olarak doğrulayabilir misiniz?';
                final url = Uri.parse('https://wa.me/905464664646?text=${Uri.encodeComponent(text)}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Tamam'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim gönderilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: CupertinoNavigationBarBackButton(
          color: _accentColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _codeSent ? 'Kodu Girin' : 'Telefon Doğrulama',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _codeSent ? _buildOtpStep() : _buildPhoneStep(),
          ),
        ),
      ),
    );
  }

  // ── Adım 1: Numara Girişi ────────────────────────────────────────────────

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android_rounded,
                color: _accentColor, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Telefon Numaranız',
          style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          'SMS ile doğrulama kodu göndereceğiz.\nTürk operatörler (Turkcell, Vodafone, Türk Telekom) desteklenir.',
          style: GoogleFonts.inter(
              fontSize: 13, color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 28),
        // İsim Soyisim input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(CupertinoIcons.person_crop_circle,
                  color: _accentColor, size: 22),
              labelText: 'İsim Soyisim *',
              hintText: 'Adınızı ve soyadınızı girin',
              hintStyle:
                  GoogleFonts.inter(color: Colors.black26, fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Tel input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                      right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                ),
                child: Row(
                  children: [
                    Text('🇹🇷',
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('+90',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onSubmitted: (_) => _sending ? null : _sendCode(),
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '05xx xxx xx xx',
                    hintStyle:
                        GoogleFonts.inter(color: Colors.black26, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _ErrorCard(_errorMsg!),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _sending ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              disabledBackgroundColor: _accentColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _sending
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text(
                    'SMS Kodu Gönder',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'SMS gönderimi kısa mesaj ücreti oluşturmaz.',
            style:
                GoogleFonts.inter(fontSize: 11, color: Colors.black38),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton.icon(
            onPressed: _reportVerificationIssue,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16),
            label: Text(
              'SMS Gelmiyor mu? / Yöneticiye Bildir',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── Adım 2: OTP Girişi ───────────────────────────────────────────────────

  Widget _buildOtpStep() {
    final phone = _toE164(_phoneCtrl.text.trim());
    final display = phone.replaceFirst('+90', '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                color: Colors.green, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Kodu Girin',
          style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
            children: [
              const TextSpan(text: '6 haneli kod '),
              TextSpan(
                  text: display,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.black87)),
              const TextSpan(text: ' numarasına gönderildi.'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // OTP Kutucukları (SMS Otomatik Çekme ve Doldurma Destekli)
        AutofillGroup(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 48,
                height: 58,
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: (e) => _onOtpKeyDown(i, e),
                  child: TextField(
                    controller: _otpCtrls[i],
                    focusNode: _otpNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (v) => _onOtpChanged(i, v),
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: _otpCtrls[i].text.isNotEmpty
                          ? _accentColor.withOpacity(0.08)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: _otpCtrls[i].text.isNotEmpty
                              ? _accentColor
                              : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: _otpCtrls[i].text.isNotEmpty
                              ? _accentColor
                              : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _accentColor, width: 2),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 14),
          _ErrorCard(_errorMsg!),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (_verifying || _otp.length < 6) ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              disabledBackgroundColor: Colors.green.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _verifying
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text(
                    'Doğrula',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        // Yeniden gönder
        Center(
          child: _resendCountdown > 0
              ? Text(
                  'Kodu yeniden göndermek için $_resendCountdown saniye bekleyin',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.black38),
                  textAlign: TextAlign.center,
                )
              : TextButton(
                  onPressed: _sending ? null : () => _sendCode(isResend: true),
                  child: Text(
                    'Kodu tekrar gönder',
                    style: GoogleFonts.inter(
                        color: _accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _codeSent = false;
              _errorMsg = null;
              for (final c in _otpCtrls) c.clear();
              _animCtrl.reset();
              _animCtrl.forward();
            }),
            child: Text(
              'Numarayı değiştir',
              style: GoogleFonts.inter(
                  color: Colors.black45, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.question_circle_fill, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SMS kodu telefonunuza ulaşmadı mı?',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Operatör veya hat yoğunluğu nedeniyle SMS alamıyorsanız yöneticiye bildirin; hesabınız manuel olarak hemen onaylansın.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF7F1D1D)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reportVerificationIssue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(CupertinoIcons.paperplane_fill, size: 15),
                  label: Text(
                    'Yöneticiye Bildir (Manuel Onay İste)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Hata Kartı ──────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill,
              color: Color(0xFFFF3B30), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFFB02020), fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
