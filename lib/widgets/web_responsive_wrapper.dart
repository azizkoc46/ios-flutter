// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web ve geniş ekranlarda mobil görünümü ideal boyutlarda ortalayan,
/// şık masaüstü yan panelleri ve arka planı sağlayan responsive kabuk.
class WebResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const WebResponsiveWrapper({
    Key? key,
    required this.child,
    required this.isDark,
  }) : super(key: key);

  static const String androidStoreUrl =
      "https://play.google.com/store/apps/details?id=com.pp.pazarckportal.pazarckportal";
  static const String iosStoreUrl =
      "https://apps.apple.com/app/id6779951979";

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Mobil ve tablet boyutlarında (<= 768px) tam ekran göster
        if (screenWidth <= 768) {
          return child;
        }

        // Masaüstü ekranlarda ideal mobil uygulama genişliği (620px)
        const double appMaxWidth = 620.0;
        final double contentWidth =
            screenWidth > appMaxWidth ? appMaxWidth : screenWidth;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF070A10)
              : const Color(0xFFE2E8F0),
          body: Stack(
            children: [
              // 🌌 Masaüstü Dekoratif Arka Plan (Zengin Gradyan)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF070A10),
                              const Color(0xFF0B132B),
                              const Color(0xFF0D1B2A),
                              const Color(0xFF050811),
                            ]
                          : [
                              const Color(0xFFE2E8F0),
                              const Color(0xFFEDF2F7),
                              const Color(0xFFE2E8F0),
                              const Color(0xFFCBD5E1),
                            ],
                    ),
                  ),
                ),
              ),

              // 🖥️ Masaüstü Sol Bilgilendirme Paneli (Geniş ekranlarda >= 1120px)
              if (screenWidth >= 1120)
                Positioned(
                  left: ((screenWidth - contentWidth) / 2 - 320)
                      .clamp(20.0, 120.0),
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildDesktopLeftPanel(isDark),
                    ),
                  ),
                ),

              // 🖥️ Masaüstü Sağ Bilgilendirme Paneli (Geniş ekranlarda >= 1380px)
              if (screenWidth >= 1380)
                Positioned(
                  right: ((screenWidth - contentWidth) / 2 - 320)
                      .clamp(20.0, 120.0),
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildDesktopRightPanel(isDark),
                    ),
                  ),
                ),

              // 📱 Merkez Mobil Uygulama Çerçevesi
              Center(
                child: Container(
                  width: contentWidth,
                  height: screenHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF121212)
                        : const Color(0xFFF8F9FA),
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 36,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(contentWidth, screenHeight),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopLeftPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111726).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo & Başlık
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0056D2), Color(0xFF00A2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  CupertinoIcons.placemark_fill,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pazarcık Portal",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      "Masaüstü & Web Sürümü",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Kahramanmaraş Pazarcık'ın en güncel ilanları, vefat duyuruları, nöbetçi eczaneleri ve yerel esnaf rehberi.",
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildFeaturePill("🏷️ Sahibinden & İkinci El İlanları", isDark),
          _buildFeaturePill("💊 Günlük Nöbetçi Eczaneler", isDark),
          _buildFeaturePill("📢 Vefat & Resmi İlanlar", isDark),
          _buildFeaturePill("🏢 Pazarcık Esnaf Rehberi", isDark),
          _buildFeaturePill("💼 İş İlanları & Kariyer", isDark),
          _buildFeaturePill("⚡ Canlı Deprem Verileri", isDark),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            "Mobil Uygulamayı İndirin:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          // Google Play Butonu
          _buildStoreButton(
            icon: Icons.android,
            title: "Google Play",
            subtitle: "Android için İndir",
            url: androidStoreUrl,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // App Store Butonu
          _buildStoreButton(
            icon: Icons.apple,
            title: "App Store",
            subtitle: "iPhone için İndir",
            url: iosStoreUrl,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRightPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111726).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                color: Colors.amber.shade600,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                "Pazarcık Portal Deneyimi",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Masaüstü ve tabletler için optimize edilmiş portal görünümü sayesinde ilan fotoğraflarını büyütebilir, yerel hizmetlere saniyeler içinde erişebilirsiniz.",
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Color(0xFF0056D2),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Bildirimleri anında almak ve ilan paylaşmak için mobil uygulamamızı kullanabilirsiniz.",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              "© Pazarcık Portal • Bizim Memleketimiz",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
