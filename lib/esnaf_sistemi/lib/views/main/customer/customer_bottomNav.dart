import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Sayfa importlarını kontrol et Aziz!
import 'home.dart';
import 'favorites.dart';
import '../store/store.dart';
import '../../../../../profil/profile.dart';
import 'package:pazarcik_portal/main.dart'; // 🔥 Ana portal sayfası (PazarcikAnaEkran) için gerekli

const Color trendyolOrange = Color(0xfff27a1a);

class CustomerBottomNav extends StatefulWidget {
  static const routeName = '/customer-home';
  final VoidCallback? onReturnToPortal;
  const CustomerBottomNav({Key? key, this.onReturnToPortal}) : super(key: key);

  @override
  State<CustomerBottomNav> createState() => _CustomerBottomNavState();
}

class _CustomerBottomNavState extends State<CustomerBottomNav> {
  int currentPageIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(), // 0: Lezzetler
    const FavoriteScreen(), // 1: Favoriler
    const SizedBox(), // 2: Logo Boşluğu (İşlem onTap içinde yapılır)
    const StoreScreen(), // 3: Restoranlar
    const ProfileScreen(), // 4: Profil
  ];

  void selectPage(int index) {
    if (index == 2) {
      // 🔥 PORTAL ANA EKRANINA DÖNÜŞ MANTIĞI 🔥
      if (widget.onReturnToPortal != null) {
        widget.onReturnToPortal!();
        return;
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PazarcikAnaEkran()),
        (route) => false,
      );
      return;
    }

    setState(() {
      currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // S24 ve diğer cihazlar için durum çubuğu ayarı
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS Background Gray
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Colors.white,
        activeColor: trendyolOrange,
        color: Colors.grey.shade500,
        initialActiveIndex: currentPageIndex,
        elevation: 15,
        height: 65, // Modern görünüm için biraz yükselttik
        top: -25, // Orta butonun çıkıntısı
        curveSize: 85,
        style: TabStyle.fixedCircle, // Orta butonu daire içine alır
        items: [
          const TabItem(icon: Icons.fastfood_rounded, title: 'Lezzet'),
          const TabItem(icon: Icons.favorite_rounded, title: 'Favori'),

          // 🔥 MERKEZDEKİ MODERN ANA SAYFA BUTONU 🔥
          TabItem(
            icon: Container(
              decoration: BoxDecoration(
                color: trendyolOrange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: trendyolOrange.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            title: 'Ana Sayfa',
          ),

          const TabItem(icon: Icons.storefront_rounded, title: 'Esnaf'),
          const TabItem(icon: Icons.person_rounded, title: 'Profil'),
        ],
        onTap: selectPage,
      ),
      // Gövde kısmında sayfalar arası geçiş
      body: _pages[currentPageIndex],
    );
  }
}
