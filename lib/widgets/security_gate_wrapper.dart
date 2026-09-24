// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/auth/auth.dart';
import 'package:pazarcik_portal/auth/phone_otp_page.dart';
import 'package:pazarcik_portal/services/system_settings_service.dart';


/// Admin paneli güvenlik kurallarına (Anonim engeli ve zorunlu telefon doğrulaması)
/// göre kullanıcının erişimini denetleyen sarmalayıcı (Gatekeeper).
class SecurityGateWrapper extends StatefulWidget {
  final Widget child;

  const SecurityGateWrapper({super.key, required this.child});

  @override
  State<SecurityGateWrapper> createState() => _SecurityGateWrapperState();
}

class _SecurityGateWrapperState extends State<SecurityGateWrapper> {
  final SystemSettingsService _settings = SystemSettingsService.instance;
  StreamSubscription<User?>? _authSubscription;
  bool _phoneVerified = true;
  bool _isChecking = true;
  // OTP tamamlandıktan sonra Firestore yazma işlemine zaman tanımak için
  // authStateChanges'ı debounce ediyoruz.
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsOrAuthChanged);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      // linkWithCredential sonrası auth event gelir ama Firestore henüz
      // yazılmamış olabilir → 1.5 saniye debounce uygula.
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        _checkStatus();
      });
    });
    _checkStatus();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsOrAuthChanged);
    _authSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSettingsOrAuthChanged() {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (_settings.requirePhoneVerification &&
        user != null &&
        !user.isAnonymous) {
      // Kontrol sırasında loading göster (tekrar doğrulama ekranına
      // düşmeyi önler).
      if (mounted) setState(() => _isChecking = true);
      final verified = await _settings.isUserPhoneVerified(user);
      if (mounted) {
        setState(() {
          _phoneVerified = verified;
          _isChecking = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _phoneVerified = true;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Kural: Kayıtsız/Anonim kullanıcı engeli aktif ve kullanıcı oturum açmamış veya anonimse
    if (_settings.blockAnonymousUsers && (user == null || user.isAnonymous)) {
      return _buildAnonymousBlockedScreen(isDark);
    }

    // 2. Kural: Telefon doğrulaması zorunlu ve kullanıcı doğrulamamışsa
    if (_settings.requirePhoneVerification &&
        user != null &&
        !user.isAnonymous &&
        !_phoneVerified &&
        !_isChecking) {
      return _buildPhoneVerificationRequiredScreen(isDark, user);
    }

    // Kurallar geçildi veya kapalı
    return widget.child;
  }

  Widget _buildAnonymousBlockedScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.lock_shield_fill,
                  color: Color(0xFF6366F1),
                  size: 46,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Giriş Yapmanız Gerekiyor',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pazarcık Portal topluluğuna erişebilmek ve işlem yapabilmek için lütfen hesabınıza giriş yapın veya yeni bir hesap oluşturun.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Auth()),
                    );
                  },
                  icon: const Icon(CupertinoIcons.person_badge_plus),
                  label: Text(
                    'Giriş Yap / Kayıt Ol',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneVerificationRequiredScreen(bool isDark, User user) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Color(0xFF10B981),
                  size: 46,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Telefon Doğrulaması Zorunlu',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Topluluk güvenliği ve gerçek kullanıcı teyidi için hesabınızın telefon numarasını doğrulamanız gerekmektedir.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PhoneOtpPage(verifyOnly: true),
                      ),
                    );
                    // Sadece başarılı doğrulama sonrası durumu yenile.
                    // Debounce timer'ı iptal et, anında kontrol et
                    // (Firestore yazımı _applyCredential içinde beklendi).
                    if (res == true && mounted) {
                      _debounceTimer?.cancel();
                      _checkStatus();
                    }
                  },
                  icon: const Icon(CupertinoIcons.checkmark_shield_fill),
                  label: Text(
                    'Şimdi Telefonumu Doğrula',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) _checkStatus();
                },
                child: Text(
                  'Farklı Hesapla Giriş Yap',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
