import 'package:flutter/material.dart';

// SAYFA İMPORTLARI (Dosya yollarını klasör yapına göre kontrol et)
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/customer/customer_bottomNav.dart'; // Yemek sipariş sistemi
import 'package:pazarcik_portal/dernek_sistemi/views/pazarcik_meydan_screen.dart'; // Meydan/Forum sayfası
import 'package:pazarcik_portal/business/BusinessDirectoryPage.dart'; // İşletmeler rehberi
import 'package:pazarcik_portal/kamu/public_directory_page.dart';
import 'package:pazarcik_portal/profil/profile.dart'; // Kullanıcı profil sayfası
import 'package:pazarcik_portal/views/pharmacy_screen.dart';
import 'package:pazarcik_portal/sahibinden/ads_main_page.dart';
import 'package:pazarcik_portal/news_page.dart';
import 'package:pazarcik_portal/isilani/job_listing_page.dart';
import 'package:pazarcik_portal/grup/grup_ana_ekran.dart';

class HomeButtonModel {
  final String title; // Butonun altında yazacak olan isim
  final IconData icon; // Butonun içerisinde görünecek simge (ikon)
  final Color color; // Butonun veya ikonun temadaki ana rengi
  final String?
      url; // Eğer tıklandığında internet sitesi açılacaksa buraya link yazılır
  final Widget?
      destination; // Eğer uygulama içinde başka bir sayfaya gidecekse buraya sayfa ismi yazılır

  HomeButtonModel({
    required this.title,
    required this.icon,
    required this.color,
    this.url,
    this.destination,
  });
}

// ==========================================================================
// 1. ÜSTTEKİ 8'Lİ GRID BUTONLARI (Ana Sayfa Hızlı Erişim)
// ==========================================================================
final List<HomeButtonModel> mainActionButtons = [
  HomeButtonModel(
    title: "Yemek",
    icon: Icons.fastfood_rounded,
    color: Colors.deepOrange,
    destination: const CustomerBottomNav(),
  ),
  HomeButtonModel(
    title: "Meydan",
    icon: Icons.forum_rounded,
    color: Colors.cyan,
    destination: const PazarcikMeydanScreen(),
  ),
  HomeButtonModel(
    title: "Eczane",
    icon: Icons.local_pharmacy_rounded,
    color: Colors.teal,
    destination: const PharmacyScreen(),
  ),
  HomeButtonModel(
    title: "İşletmeler",
    icon: Icons.store_mall_directory_rounded,
    color: Colors.blue,
    destination: const BusinessDirectoryPage(),
  ),
  HomeButtonModel(
    title: "Haberler",
    icon: Icons.newspaper_rounded,
    color: Colors.red,
    destination: const NewsPage(),
  ),
  HomeButtonModel(
    title: "Grup", // Başlığı değiştirdik
    icon: Icons.groups_rounded, // Sosyal grup ikonu verdik
    color: const Color(0xFF0056D2), // Facebook/Portal mavisi yaptık
    destination:
        const GrupAnaEkran(), // 🔥 Buraya az önce yazdığımız sayfayı bağlıyoruz
  ),
  HomeButtonModel(
    title: "İş İlanı",
    icon: Icons.work_outline_rounded,
    color: Colors.green,
    destination: const JobListingPage(),
  ),
  HomeButtonModel(
    title: "Sahibinden",
    icon: Icons.storefront_rounded,
    color: const Color(0xFFFFE800), // O meşhur sarı tonu
    destination: const AdsMainPage(),
  ),
];

// Not: "Şehir Rehberi" butonları (cityGuideButtons) yerine "Taksi Çağır" afişi
// eklendiği için o liste dosyadan temizlenmiştir.

// ==========================================================================
// 2. ALTAKİ 3'LÜ MENÜ (Kamu, Taksi, İlanlar)
// ==========================================================================
final List<HomeButtonModel> cityGuideButtons = [
  HomeButtonModel(
    title: "Kamu & Devlet",
    icon: Icons.account_balance_rounded,
    color: const Color(0xFFD32F2F),
    destination: const PublicDirectoryPage(), // Belediye, Kaymakamlık vb.
  ),
  HomeButtonModel(
    title: "Taksi Çağır", // 🔥 Şehir Rehberi yerine Taksi geldi
    icon: Icons.local_taxi_rounded,
    color: const Color(0xFFFBC02D), // Taksi Sarısı
    url: "",
  ),
  HomeButtonModel(
    title: "İlanlar & Duyurular",
    icon: Icons.campaign_rounded,
    color: const Color(0xFFFF2D55),
    url: "", // Resmi duyurular
  ),
];
// ==========================================================================
final List<HomeButtonModel> bottomNavItems = [
  HomeButtonModel(
    title: "Ana Sayfa",
    icon: Icons.home_filled,
    color: Colors.blueAccent,
    destination: null, // Ana sayfada olduğumuz için null kalıyor
  ),
  HomeButtonModel(
    title: "Yemek",
    icon: Icons.fastfood_rounded,
    color: Colors.orange,
    destination: const CustomerBottomNav(),
  ),
  HomeButtonModel(
    title: "İşletmeler",
    icon: Icons.storefront_rounded,
    color: Colors.blue,
    destination: const BusinessDirectoryPage(),
  ),
  HomeButtonModel(
    title: "Profil",
    icon: Icons.person_rounded,
    color: Colors.green,
    destination: const ProfileScreen(),
  ),
];
