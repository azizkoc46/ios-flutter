import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// SAYFA İMPORTLARI
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/customer/customer_bottomNav.dart'; // Yemek sipariş sistemi
import 'package:pazarcik_portal/business/BusinessDirectoryPage.dart'; // İşletmeler rehberi
import 'package:pazarcik_portal/kamu/public_directory_page.dart';
import 'package:pazarcik_portal/profil/profile.dart'; // Kullanıcı profil sayfası
import 'package:pazarcik_portal/views/pharmacy_screen.dart';
import 'package:pazarcik_portal/sahibinden/ads_main_page.dart';
import 'package:pazarcik_portal/news_page.dart';
import 'package:pazarcik_portal/isilani/job_listing_page.dart';
import 'package:pazarcik_portal/grup/grup_ana_ekran.dart';

class HomeButtonModel {
  final String title;
  final IconData icon;
  final Color color;
  final String? url;
  final Widget? destination;

  HomeButtonModel({
    required this.title,
    required this.icon,
    required this.color,
    this.url,
    this.destination,
  });
}

// ==========================================================================
// 1. HİZMETLER & KATEGORİ IZGARASI BUTONLARI (Görseller 1 & 2)
// ==========================================================================
final List<HomeButtonModel> mainActionButtons = [
  HomeButtonModel(
    title: "Haberler",
    icon: CupertinoIcons.mic_fill,
    color: const Color(0xFF007AFF),
    destination: const NewsPage(),
  ),
  HomeButtonModel(
    title: "Etkinlikler",
    icon: CupertinoIcons.sparkles,
    color: const Color(0xFF5856D6),
    destination: null, // Custom modal / section
  ),
  HomeButtonModel(
    title: "Yeme & İçme",
    icon: CupertinoIcons.flame_fill,
    color: const Color(0xFFFF9500),
    destination: const CustomerBottomNav(),
  ),
  HomeButtonModel(
    title: "Emlak & Araç",
    icon: CupertinoIcons.building_2_fill,
    color: const Color(0xFFFFCC00),
    destination: const AdsMainPage(),
  ),
  HomeButtonModel(
    title: "İkinci El",
    icon: CupertinoIcons.bag_fill,
    color: const Color(0xFFFF2D55),
    destination: const AdsMainPage(),
  ),
  HomeButtonModel(
    title: "İndirimler",
    icon: CupertinoIcons.percent,
    color: const Color(0xFFFF9500),
    destination: const BusinessDirectoryPage(),
  ),
  HomeButtonModel(
    title: "Gezilecek Yerler",
    icon: CupertinoIcons.map_pin_ellipse,
    color: const Color(0xFF34C759),
    destination: const PublicDirectoryPage(),
  ),
  HomeButtonModel(
    title: "İş İlanları",
    icon: CupertinoIcons.briefcase_fill,
    color: const Color(0xFF5856D6),
    destination: const JobListingPage(),
  ),
  HomeButtonModel(
    title: "Nöbetçi Eczane",
    icon: CupertinoIcons.bandage_fill,
    color: const Color(0xFFFF3B30),
    destination: const PharmacyScreen(),
  ),
];

// ==========================================================================
// 2. YENİ 5'Lİ ALT MENÜ (Görseller 1, 2, 3, 4, 5, 6)
// ==========================================================================
final List<HomeButtonModel> bottomNavItems = [
  HomeButtonModel(
    title: "Ana Sayfa",
    icon: CupertinoIcons.house_fill,
    color: const Color(0xFF007AFF),
    destination: null,
  ),
  HomeButtonModel(
    title: "Yemek",
    icon: CupertinoIcons.flame_fill,
    color: const Color(0xFFFF9500),
    destination: const CustomerBottomNav(),
  ),
  HomeButtonModel(
    title: "Meydan",
    icon: CupertinoIcons.square_stack_3d_up_fill,
    color: const Color(0xFFFF5E62),
    destination: const GrupAnaEkran(),
  ),
  HomeButtonModel(
    title: "İşletmeler",
    icon: CupertinoIcons.building_2_fill,
    color: const Color(0xFF007AFF),
    destination: const BusinessDirectoryPage(),
  ),
  HomeButtonModel(
    title: "Hesabım",
    icon: CupertinoIcons.person_crop_circle_fill,
    color: const Color(0xFF34C759),
    destination: const ProfileScreen(),
  ),
];

class HomeBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const HomeBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141F) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(bottomNavItems.length, (index) {
              final item = bottomNavItems[index];
              final isSelected = selectedIndex == index;
              final activeColor = item.color;
              final inactiveColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 12 : 0,
                          vertical: isSelected ? 3 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withOpacity(0.14) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

