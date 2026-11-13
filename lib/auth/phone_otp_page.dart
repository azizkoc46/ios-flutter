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

class CountryItem {
  final String name;
  final String dialCode;
  final String flag;
  final String code;
  final String example;

  const CountryItem({
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.code,
    required this.example,
  });
}

const List<CountryItem> kSupportedCountries = [
  CountryItem(name: 'Türkiye', dialCode: '+90', flag: '🇹🇷', code: 'TR', example: '5xx xxx xx xx'),
  CountryItem(name: 'Almanya', dialCode: '+49', flag: '🇩🇪', code: 'DE', example: '151 23456789'),
  CountryItem(name: 'Fransa', dialCode: '+33', flag: '🇫🇷', code: 'FR', example: '6 12 34 56 78'),
  CountryItem(name: 'Hollanda', dialCode: '+31', flag: '🇳🇱', code: 'NL', example: '6 12345678'),
  CountryItem(name: 'Avusturya', dialCode: '+43', flag: '🇦🇹', code: 'AT', example: '664 1234567'),
  CountryItem(name: 'İsviçre', dialCode: '+41', flag: '🇨🇭', code: 'CH', example: '79 123 45 67'),
  CountryItem(name: 'Belçika', dialCode: '+32', flag: '🇧🇪', code: 'BE', example: '470 12 34 56'),
  CountryItem(name: 'Birleşik Krallık', dialCode: '+44', flag: '🇬🇧', code: 'GB', example: '7911 123456'),
  CountryItem(name: 'İsveç', dialCode: '+46', flag: '🇸🇪', code: 'SE', example: '70 123 45 67'),
  CountryItem(name: 'Danimarka', dialCode: '+45', flag: '🇩🇰', code: 'DK', example: '20 12 34 56'),
  CountryItem(name: 'Norveç', dialCode: '+47', flag: '🇳🇴', code: 'NO', example: '412 34 567'),
  CountryItem(name: 'Finlandiya', dialCode: '+358', flag: '🇫🇮', code: 'FI', example: '40 1234567'),
  CountryItem(name: 'İtalya', dialCode: '+39', flag: '🇮🇹', code: 'IT', example: '320 123 4567'),
  CountryItem(name: 'İspanya', dialCode: '+34', flag: '🇪🇸', code: 'ES', example: '612 34 56 78'),
  CountryItem(name: 'Portekiz', dialCode: '+351', flag: '🇵🇹', code: 'PT', example: '912 345 678'),
  CountryItem(name: 'Yunanistan', dialCode: '+30', flag: '🇬🇷', code: 'GR', example: '69 1234 5678'),
  CountryItem(name: 'Bulgaristan', dialCode: '+359', flag: '🇧🇬', code: 'BG', example: '87 123 4567'),
  CountryItem(name: 'Romanya', dialCode: '+40', flag: '🇷🇴', code: 'RO', example: '712 345 678'),
  CountryItem(name: 'Polonya', dialCode: '+48', flag: '🇵🇱', code: 'PL', example: '512 345 678'),
  CountryItem(name: 'Çekya', dialCode: '+420', flag: '🇨🇿', code: 'CZ', example: '601 123 456'),
  CountryItem(name: 'Macaristan', dialCode: '+36', flag: '🇭🇺', code: 'HU', example: '20 123 4567'),
  CountryItem(name: 'İrlanda', dialCode: '+353', flag: '🇮🇪', code: 'IE', example: '85 123 4567'),
  CountryItem(name: 'Amerika Birleşik Devletleri', dialCode: '+1', flag: '🇺🇸', code: 'US', example: '202 555 0123'),
  CountryItem(name: 'Kanada', dialCode: '+1', flag: '🇨🇦', code: 'CA', example: '416 555 0123'),
  CountryItem(name: 'Avustralya', dialCode: '+61', flag: '🇦🇺', code: 'AU', example: '412 345 678'),
  CountryItem(name: 'Yeni Zelanda', dialCode: '+64', flag: '🇳🇿', code: 'NZ', example: '21 123 4567'),
  CountryItem(name: 'Azerbaycan', dialCode: '+994', flag: '🇦🇿', code: 'AZ', example: '50 123 45 67'),
  CountryItem(name: 'KKTC', dialCode: '+90', flag: '🇨🇾', code: 'CY', example: '533 123 45 67'),
  CountryItem(name: 'Rusya', dialCode: '+7', flag: '🇷🇺', code: 'RU', example: '912 345 67 89'),
  CountryItem(name: 'Kazakistan', dialCode: '+7', flag: '🇰🇿', code: 'KZ', example: '701 123 45 67'),
  CountryItem(name: 'Özbekistan', dialCode: '+998', flag: '🇺🇿', code: 'UZ', example: '90 123 45 67'),
  CountryItem(name: 'Türkmenistan', dialCode: '+993', flag: '🇹🇲', code: 'TM', example: '65 12 34 56'),
  CountryItem(name: 'Kırgızistan', dialCode: '+996', flag: '🇰🇬', code: 'KG', example: '555 12 34 56'),
  CountryItem(name: 'Gürcistan', dialCode: '+995', flag: '🇬🇪', code: 'GE', example: '555 12 34 56'),
  CountryItem(name: 'Ukrayna', dialCode: '+380', flag: '🇺🇦', code: 'UA', example: '50 123 4567'),
  CountryItem(name: 'Suudi Arabistan', dialCode: '+966', flag: '🇸🇦', code: 'SA', example: '50 123 4567'),
  CountryItem(name: 'Birleşik Arap Emirlikleri', dialCode: '+971', flag: '🇦🇪', code: 'AE', example: '50 123 4567'),
  CountryItem(name: 'Katar', dialCode: '+974', flag: '🇶🇦', code: 'QA', example: '3312 3456'),
  CountryItem(name: 'Kuveyt', dialCode: '+965', flag: '🇰🇼', code: 'KW', example: '9123 4567'),
  CountryItem(name: 'Bahreyn', dialCode: '+973', flag: '🇧🇭', code: 'BH', example: '3600 1234'),
  CountryItem(name: 'Umman', dialCode: '+968', flag: '🇴🇲', code: 'OM', example: '9123 4567'),
  CountryItem(name: 'Irak', dialCode: '+964', flag: '🇮🇶', code: 'IQ', example: '750 123 4567'),
  CountryItem(name: 'Suriye', dialCode: '+963', flag: '🇸🇾', code: 'SY', example: '933 123 456'),
  CountryItem(name: 'Ürdün', dialCode: '+962', flag: '🇯🇴', code: 'JO', example: '7 9012 3456'),
  CountryItem(name: 'Lübnan', dialCode: '+961', flag: '🇱🇧', code: 'LB', example: '70 123 456'),
  CountryItem(name: 'Mısır', dialCode: '+20', flag: '🇪🇬', code: 'EG', example: '100 123 4567'),
  CountryItem(name: 'Fas', dialCode: '+212', flag: '🇲🇦', code: 'MA', example: '612 345678'),
  CountryItem(name: 'Cezayir', dialCode: '+213', flag: '🇩🇿', code: 'DZ', example: '551 23 45 67'),
  CountryItem(name: 'Tunus', dialCode: '+216', flag: '🇹🇳', code: 'TN', example: '20 123 456'),
  CountryItem(name: 'Japonya', dialCode: '+81', flag: '🇯🇵', code: 'JP', example: '90 1234 5678'),
  CountryItem(name: 'Güney Kore', dialCode: '+82', flag: '🇰🇷', code: 'KR', example: '10 1234 5678'),
  CountryItem(name: 'Çin', dialCode: '+86', flag: '🇨🇳', code: 'CN', example: '138 0000 0000'),
  CountryItem(name: 'Hindistan', dialCode: '+91', flag: '🇮🇳', code: 'IN', example: '98765 43210'),
  CountryItem(name: 'Pakistan', dialCode: '+92', flag: '🇵🇰', code: 'PK', example: '300 1234567'),
  CountryItem(name: 'Brezilya', dialCode: '+55', flag: '🇧🇷', code: 'BR', example: '11 91234 5678'),
  CountryItem(name: 'Meksika', dialCode: '+52', flag: '🇲🇽', code: 'MX', example: '55 1234 5678'),
  CountryItem(name: 'Güney Afrika', dialCode: '+27', flag: '🇿🇦', code: 'ZA', example: '82 123 4567'),
];

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
  CountryItem _selectedCountry = kSupportedCountries.first;

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
  bool _hasAttemptedSend = false;
  int _reportCooldownSeconds = 0;
  Timer? _reportCooldownTimer;

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
              (data?['phone'] ?? data?['phoneNumber'] ?? user.phoneNumber ?? '')
                  .toString()
                  .trim();
          setState(() {
            if (_nameCtrl.text.trim().isEmpty && existingName.isNotEmpty) {
              _nameCtrl.text = existingName;
            }
            if (_phoneCtrl.text.trim().isEmpty && existingPhone.isNotEmpty) {
              _parseAndSetExistingPhone(existingPhone);
            }
          });
        }).catchError((_) {});
      }
    } catch (_) {}
  }

  void _parseAndSetExistingPhone(String raw) {
    var clean = raw.trim();
    if (clean.isEmpty) return;
    if (clean.startsWith('00')) {
      clean = '+${clean.substring(2)}';
    }
    if (clean.startsWith('+')) {
      // Dial code ile eşleşen ülkeyi bul (en uzun eşleşme)
      CountryItem? bestMatch;
      for (final c in kSupportedCountries) {
        if (clean.startsWith(c.dialCode)) {
          if (bestMatch == null || c.dialCode.length > bestMatch.dialCode.length) {
            bestMatch = c;
          }
        }
      }
      if (bestMatch != null) {
        _selectedCountry = bestMatch;
        _phoneCtrl.text = clean.substring(bestMatch.dialCode.length).replaceAll(RegExp(r'\D'), '');
        return;
      }
    }
    // Türkiye varsayımı
    _selectedCountry = kSupportedCountries.first;
    var digits = clean.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) digits = digits.substring(2);
    if (digits.length == 10 && !digits.startsWith('0')) digits = '0$digits';
    _phoneCtrl.text = digits;
  }

  void _onPhoneChanged(String val) {
    final trimmed = val.trim();
    if (trimmed.startsWith('+')) {
      // Kullanıcı doğrudan uluslararası kod yapıştırdıysa (+49, +33 vb.)
      CountryItem? match;
      for (final c in kSupportedCountries) {
        if (trimmed.startsWith(c.dialCode)) {
          if (match == null || c.dialCode.length > match.dialCode.length) {
            match = c;
          }
        }
      }
      if (match != null) {
        final found = match;
        setState(() {
          _selectedCountry = found;
          final national = trimmed.substring(found.dialCode.length).replaceAll(RegExp(r'\D'), '');
          _phoneCtrl.text = national;
          _phoneCtrl.selection = TextSelection.fromPosition(TextPosition(offset: national.length));
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final n in _otpNodes) n.dispose();
    _countdownTimer?.cancel();
    _smsFallbackTimer?.cancel();
    _reportCooldownTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  /// Numarayı tam E.164 standardına dönüştürür (+<ülke_kodu><numara>)
  String _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final dialDigits = _selectedCountry.dialCode.replaceAll(RegExp(r'\D'), '');

    if (_selectedCountry.dialCode == '+90') {
      if (digits.startsWith('90') && digits.length == 12) return '+$digits';
      if (digits.startsWith('0') && digits.length == 11) {
        return '+9${digits}';
      }
      if (digits.length == 10) return '+90$digits';
      return '+90$digits';
    } else {
      // Diğer ülkeler (başında ülke kodu zaten varsa veya 0 ile başlıyorsa temizle)
      if (digits.startsWith(dialDigits)) {
        return '+$digits';
      }
      var national = digits;
      if (national.startsWith('0')) {
        national = national.substring(1);
      }
      return '+${dialDigits}$national';
    }
  }

  bool _isValidPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;

    if (_selectedCountry.dialCode == '+90') {
      final normalized = digits.startsWith('0')
          ? digits.substring(1)
          : digits.startsWith('90')
              ? digits.substring(2)
              : digits;
      return RegExp(r'^5[0-9]{9}$').hasMatch(normalized);
    } else {
      // Uluslararası: yerel numara en az 5, en fazla 14 basamak; toplam 7-15 hane
      final dialDigits = _selectedCountry.dialCode.replaceAll(RegExp(r'\D'), '');
      final cleanLocal = digits.startsWith('0') ? digits.substring(1) : digits;
      final totalLen = digits.startsWith(dialDigits)
          ? digits.length
          : dialDigits.length + cleanLocal.length;
      return totalLen >= 7 && totalLen <= 15;
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(
        selected: _selectedCountry,
        onSelected: (country) {
          setState(() {
            _selectedCountry = country;
          });
        },
      ),
    );
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

  void _startReportCooldown() {
    _reportCooldownSeconds = 60;
    if (mounted) setState(() {});
    _reportCooldownTimer?.cancel();
    _reportCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_reportCooldownSeconds <= 0) {
        t.cancel();
      } else {
        setState(() => _reportCooldownSeconds--);
      }
    });
  }

  bool get _canReportIssue {
    if (_errorMsg != null && _errorMsg!.trim().isNotEmpty) return true;
    return _hasAttemptedSend && _reportCooldownSeconds <= 0;
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
    if (!_isValidPhone(raw)) {
      if (_selectedCountry.dialCode == '+90') {
        _setError('Geçerli bir Türkiye cep telefonu numarası girin.\n(Örn: 05xx xxx xx xx)');
      } else {
        _setError('Geçerli bir ${_selectedCountry.name} cep telefonu girin.\n(Örn: ${_selectedCountry.example})');
      }
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
      _hasAttemptedSend = true;
    });
    _startReportCooldown();

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
      final formattedPhone = phone.isNotEmpty ? _toE164(phone) : (user?.phoneNumber ?? '');
      final docRef = await FirebaseFirestore.instance.collection('phone_verification_requests').add({
        'uid': uid,
        'email': email,
        'fullName': cleanName.isNotEmpty ? cleanName : (user?.displayName ?? 'İsimsiz Kullanıcı'),
        'phoneNumber': formattedPhone,
        'country': '${_selectedCountry.flag} ${_selectedCountry.name} (${_selectedCountry.dialCode})',
        'status': 'pending',
        'issueReason': noteCtrl.text.trim(),
        'errorDetails': _errorMsg ?? '',
        'device': kIsWeb ? 'Web' : defaultTargetPlatform.toString(),
        'submittedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('admin_notifications_log').add({
        'title': '🚨 Tel Doğrulama Sorunu: ${cleanName.isNotEmpty ? cleanName : formattedPhone}',
        'body': '${email.isNotEmpty ? email + " • " : ""}$formattedPhone (${_selectedCountry.flag} ${_selectedCountry.name}) kullanıcısı SMS kodu alamadığını bildirdi. Yönetimden manuel onaylayabilirsiniz.',
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
          'SMS ile 6 haneli doğrulama kodu göndereceğiz.\nTürkiye, Almanya, Fransa ve tüm dünya operatörleri desteklenir.',
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
        // Tel input (Ülke kodu seçimi + numara)
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
              InkWell(
                onTap: _showCountryPicker,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                        right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountry.flag,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(_selectedCountry.dialCode,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down,
                          size: 18, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+]')),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  onChanged: _onPhoneChanged,
                  onSubmitted: (_) => _sending ? null : _sendCode(),
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: _selectedCountry.example,
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
        if (_hasAttemptedSend || (_errorMsg != null && _errorMsg!.isNotEmpty)) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: _canReportIssue ? _reportVerificationIssue : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                disabledForegroundColor: Colors.black38,
                side: BorderSide(
                  color: _canReportIssue
                      ? const Color(0xFFFCA5A5)
                      : Colors.black12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                _canReportIssue
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.clock,
                size: 16,
              ),
              label: Text(
                _canReportIssue
                    ? 'SMS Gelmiyor mu? / Yöneticiye Bildir'
                    : 'SMS Bekleniyor... ($_reportCooldownSeconds sn)',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Adım 2: OTP Girişi ───────────────────────────────────────────────────

  Widget _buildOtpStep() {
    final phone = _toE164(_phoneCtrl.text.trim());
    final display = _selectedCountry.dialCode == '+90'
        ? phone.replaceFirst('+90', '0')
        : '${_selectedCountry.flag} $phone';

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
                  onPressed: _canReportIssue ? _reportVerificationIssue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.black45,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    _canReportIssue
                        ? CupertinoIcons.paperplane_fill
                        : CupertinoIcons.clock_fill,
                    size: 15,
                  ),
                  label: Text(
                    _canReportIssue
                        ? 'Yöneticiye Bildir (Manuel Onay İste)'
                        : 'SMS Gelmezse Bildir ($_reportCooldownSeconds sn)',
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

// ── Ülke ve Alan Kodu Seçici Modal ──────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final CountryItem selected;
  final ValueChanged<CountryItem> onSelected;

  const _CountryPickerSheet({
    Key? key,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lowerFilter = _filter.trim().toLowerCase();
    final filtered = kSupportedCountries.where((c) {
      if (lowerFilter.isEmpty) return true;
      final cleanDial = c.dialCode.replaceAll('+', '').toLowerCase();
      return c.name.toLowerCase().contains(lowerFilter) ||
          c.code.toLowerCase().contains(lowerFilter) ||
          c.dialCode.contains(lowerFilter) ||
          cleanDial.contains(lowerFilter);
    }).toList();

    final popularCountries = kSupportedCountries.where((c) {
      return ['TR', 'DE', 'FR', 'NL', 'AT', 'CH', 'BE', 'GB', 'US', 'AZ'].contains(c.code);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ülke & Alan Kodu Seçin',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tüm ülkelerden SMS ile kayıt ve giriş desteklenir',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _filter = val),
                decoration: InputDecoration(
                  hintText: 'Ülke adı veya kodu arayın (örn. Almanya, +49)...',
                  hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search, color: Colors.black45, size: 20),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel, size: 18, color: Colors.black38),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_filter.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SIK KULLANILAN ÜLKELER',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.black45,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: popularCountries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final c = popularCountries[i];
                  final isSel = c.dialCode == widget.selected.dialCode &&
                      c.code == widget.selected.code;
                  return InkWell(
                    onTap: () {
                      widget.onSelected(c);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF6366F1).withOpacity(0.12) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(c.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            '${c.name} (${c.dialCode})',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? const Color(0xFF6366F1) : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
          ],
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public_off, size: 40, color: Colors.black26),
                          const SizedBox(height: 12),
                          Text(
                            '"$_filter" için ülke bulunamadı.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Özel bir alan kodu ile devam etmek için aşağıya tıklayın.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              final dial = _filter.startsWith('+') ? _filter : '+$_filter';
                              final customCountry = CountryItem(
                                name: 'Özel Ülke ($dial)',
                                dialCode: dial,
                                flag: '🌐',
                                code: 'XX',
                                example: 'Telefon numarası',
                              );
                              widget.onSelected(customCountry);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              '${_filter.startsWith('+') ? _filter : "+$_filter"} Kodunu Kullan',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final isSel = item.dialCode == widget.selected.dialCode &&
                          item.code == widget.selected.code;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? const Color(0xFF6366F1) : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Örnek: ${item.example}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.black38,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.dialCode,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        onTap: () {
                          widget.onSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
