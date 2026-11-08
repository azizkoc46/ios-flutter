import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin/admin_notification_service.dart';

/// Paket Süre Seçenekleri
enum AdPeriod {
  oneMonth,
  threeMonths,
  sixMonths,
  twelveMonths,
}

extension AdPeriodExtension on AdPeriod {
  String get label {
    switch (this) {
      case AdPeriod.oneMonth:
        return '1 Aylık';
      case AdPeriod.threeMonths:
        return '3 Aylık';
      case AdPeriod.sixMonths:
        return '6 Aylık';
      case AdPeriod.twelveMonths:
        return '1 Yıllık';
    }
  }

  int get months {
    switch (this) {
      case AdPeriod.oneMonth:
        return 1;
      case AdPeriod.threeMonths:
        return 3;
      case AdPeriod.sixMonths:
        return 6;
      case AdPeriod.twelveMonths:
        return 12;
    }
  }

  int get defaultDiscountPercent {
    switch (this) {
      case AdPeriod.oneMonth:
        return 0;
      case AdPeriod.threeMonths:
        return 15; // %15 indirim
      case AdPeriod.sixMonths:
        return 25; // %25 indirim
      case AdPeriod.twelveMonths:
        return 35; // %35 indirim
    }
  }

  String? get badge {
    switch (this) {
      case AdPeriod.oneMonth:
        return null;
      case AdPeriod.threeMonths:
        return '%15 Tasarruf';
      case AdPeriod.sixMonths:
        return '%25 İndirimli';
      case AdPeriod.twelveMonths:
        return 'En Avantajlı 👑';
    }
  }
}

/// Esnaf Reklam Paketi Modeli
class AdPackageModel {
  final String id;
  final String name;
  final String subtitle;
  final String badge;
  final bool isPopular;
  final double baseMonthlyPrice;
  final int dailyStories;
  final int weeklyPosts;
  final int pushNotifications;
  final bool appStoriesVisible;
  final bool splashBannerDiscount;
  final bool instagramPinDiscount;
  final List<String> perks;
  final String recommendedFor;

  const AdPackageModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.isPopular,
    required this.baseMonthlyPrice,
    required this.dailyStories,
    required this.weeklyPosts,
    required this.pushNotifications,
    required this.appStoriesVisible,
    required this.splashBannerDiscount,
    required this.instagramPinDiscount,
    required this.perks,
    required this.recommendedFor,
  });

  double getMonthlyPrice(int discountPercent) {
    if (discountPercent <= 0) return baseMonthlyPrice;
    final discounted = baseMonthlyPrice * (100 - discountPercent) / 100.0;
    return (discounted / 10).round() * 10.0; // düzgün yuvarlama
  }

  double getTotalPrice(AdPeriod period, int discountPercent) {
    return getMonthlyPrice(discountPercent) * period.months;
  }

  factory AdPackageModel.fromMap(String id, Map<String, dynamic> map, AdPackageModel fallback) {
    return AdPackageModel(
      id: id,
      name: map['name'] ?? fallback.name,
      subtitle: map['subtitle'] ?? fallback.subtitle,
      badge: map['badge'] ?? fallback.badge,
      isPopular: map['isPopular'] ?? fallback.isPopular,
      baseMonthlyPrice: (map['baseMonthlyPrice'] as num?)?.toDouble() ?? fallback.baseMonthlyPrice,
      dailyStories: (map['dailyStories'] as num?)?.toInt() ?? fallback.dailyStories,
      weeklyPosts: (map['weeklyPosts'] as num?)?.toInt() ?? fallback.weeklyPosts,
      pushNotifications: (map['pushNotifications'] as num?)?.toInt() ?? fallback.pushNotifications,
      appStoriesVisible: map['appStoriesVisible'] ?? fallback.appStoriesVisible,
      splashBannerDiscount: map['splashBannerDiscount'] ?? fallback.splashBannerDiscount,
      instagramPinDiscount: map['instagramPinDiscount'] ?? fallback.instagramPinDiscount,
      perks: (map['perks'] as List?)?.map((e) => e.toString()).toList() ?? fallback.perks,
      recommendedFor: map['recommendedFor'] ?? fallback.recommendedFor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subtitle': subtitle,
      'badge': badge,
      'isPopular': isPopular,
      'baseMonthlyPrice': baseMonthlyPrice,
      'dailyStories': dailyStories,
      'weeklyPosts': weeklyPosts,
      'pushNotifications': pushNotifications,
      'appStoriesVisible': appStoriesVisible,
      'splashBannerDiscount': splashBannerDiscount,
      'instagramPinDiscount': instagramPinDiscount,
      'perks': perks,
      'recommendedFor': recommendedFor,
    };
  }
}

/// Tekil / Modüler Reklam Hizmeti
class SingleServiceModel {
  final String id;
  final String title;
  final String unit;
  final double price;
  final String iconName;
  final String badge;
  final String description;
  final String highlight;

  const SingleServiceModel({
    required this.id,
    required this.title,
    required this.unit,
    required this.price,
    required this.iconName,
    required this.badge,
    required this.description,
    required this.highlight,
  });

  factory SingleServiceModel.fromMap(String id, Map<String, dynamic> map, SingleServiceModel fallback) {
    return SingleServiceModel(
      id: id,
      title: map['title'] ?? fallback.title,
      unit: map['unit'] ?? fallback.unit,
      price: (map['price'] as num?)?.toDouble() ?? fallback.price,
      iconName: map['iconName'] ?? fallback.iconName,
      badge: map['badge'] ?? fallback.badge,
      description: map['description'] ?? fallback.description,
      highlight: map['highlight'] ?? fallback.highlight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'unit': unit,
      'price': price,
      'iconName': iconName,
      'badge': badge,
      'description': description,
      'highlight': highlight,
    };
  }
}

/// Genel Reklam ve Paket Yapılandırma Modeli
class AdConfigModel {
  final String whatsappPhone;
  final String supportPhone;
  final String instagramUsername;
  final Map<int, int> periodDiscounts;
  final List<AdPackageModel> packages;
  final List<SingleServiceModel> singleServices;
  final String policyTitle;
  final String policyText;

  const AdConfigModel({
    required this.whatsappPhone,
    required this.supportPhone,
    required this.instagramUsername,
    required this.periodDiscounts,
    required this.packages,
    required this.singleServices,
    required this.policyTitle,
    required this.policyText,
  });

  int getDiscount(AdPeriod period) {
    return periodDiscounts[period.months] ?? period.defaultDiscountPercent;
  }
}

/// Firebase ile canlı senkronize çalışan Esnaf Reklam Servisi
class MerchantAdService {
  MerchantAdService._();
  static final instance = MerchantAdService._();

  static const String _collectionName = 'app_settings';
  static const String _docName = 'advertising_packages';

  // ── Standart Optimize Edilmiş Varsayılan Paketler ──
  static const List<AdPackageModel> defaultPackages = [
    AdPackageModel(
      id: 'starter',
      name: 'Başlangıç Paketi',
      subtitle: 'Küçük ve orta ölçekli esnaflar için düzenli ve ekonomik yerel görünürlük.',
      badge: 'ESNAF DOSTU',
      isPopular: false,
      baseMonthlyPrice: 1950.0,
      dailyStories: 1,
      weeklyPosts: 1,
      pushNotifications: 1,
      appStoriesVisible: true,
      splashBannerDiscount: false,
      instagramPinDiscount: false,
      perks: [
        'Pazarcık Portal Instagram’da Günde 1 Hikaye (Ayda 30 Hikaye)',
        'Haftalık 1 Adet Sabit Akış Gönderisi (Ayda 4 Gönderi)',
        'Mobil Uygulama & Web "Hikayeler Vitrini"nde 1 Ay Sabit Görünüm',
        '1 Adet Toplu Kampanya / Fırsat Bildirimi (Tüm kullanıcılara duyuru)',
        'İşletme Rehberinde "Öne Çıkan Esnaf" Etiketi',
        'Google & Portal Arama Sonuçlarında Öncelikli İndeks',
      ],
      recommendedFor: 'Butikler, kafeler, kuaförler ve yeni açılan yerel işletmeler',
    ),
    AdPackageModel(
      id: 'growth',
      name: 'Büyüme & Orta Paket',
      subtitle: 'Müşteri kitlesini hızla büyütmek ve Pazarcık genelinde marka bilinirliği sağlamak isteyen esnaflar.',
      badge: 'EN ÇOK TERCİH EDİLEN 🔥',
      isPopular: true,
      baseMonthlyPrice: 2950.0,
      dailyStories: 2,
      weeklyPosts: 3,
      pushNotifications: 2,
      appStoriesVisible: true,
      splashBannerDiscount: false,
      instagramPinDiscount: true,
      perks: [
        'Pazarcık Portal Instagram’da Günde 2 Hikaye (Ayda 60 Hikaye)',
        'Haftalık 3 Adet Akış Gönderisi / Reels (Ayda 12 Gönderi)',
        'Mobil Uygulama & Web Hikaye Vitrininde Üst Sırada 1 Ay Kesintisiz Yayın',
        '2 Adet Toplu Özel Fırsat & Kampanya Bildirimi (Doğrudan cebe duyuru)',
        'Instagram "Öne Çıkanlar" Sabitleme ve Etiketleme Avantajı',
        'İşletme Rehberinde Doğrulanmış Rozet (Yeşil Onay Rozeti)',
        'Sosyal Medya Görsel & Metin Düzenleme Desteği',
      ],
      recommendedFor: 'Restoranlar, mobilyacılar, marketler, oto servisleri ve aktif satış yapan esnaflar',
    ),
    AdPackageModel(
      id: 'premium',
      name: 'VIP Prestij Paketi',
      subtitle: 'Maksimum satış hacmi, açılış indirimi ve ilçenin en prestijli markası olmak isteyen işletmeler.',
      badge: 'VIP PRESTİJ 👑',
      isPopular: false,
      baseMonthlyPrice: 4950.0,
      dailyStories: 3,
      weeklyPosts: 5,
      pushNotifications: 3,
      appStoriesVisible: true,
      splashBannerDiscount: true,
      instagramPinDiscount: true,
      perks: [
        'Pazarcık Portal Instagram’da Günde 3 Hikaye (Ayda 90 Hikaye)',
        'Haftalık 5 Adet Gönderi & Profesyonel Reels Video Paylaşımı',
        'Mobil & Web Hikaye Vitrininde En Başta Sabit Konumlandırma',
        '3 Adet Toplu Özel Fırsat / İndirim Bildirimi (Duyuru formatında)',
        'Mobil Uygulama Açılış / Karşılama Ekranında %50 İndirim Fırsatı',
        'Instagram Profilinde Başa Tutturma (Sabit Gönderi) %50 İndirimli',
        'Özel Esnaf Tanıtım Röportajı & Reels Video Çekim Desteği',
        'VIP Destek Hattı ve Anlık Kampanya Güncelleme Önceliği',
      ],
      recommendedFor: 'Büyük mağazalar, inşaat/emlak firmaları, düğün salonları ve kurumsal işletmeler',
    ),
  ];

  // ── Standart Tekil / Modüler Reklam Hizmetleri ──
  static const List<SingleServiceModel> defaultSingleServices = [
    SingleServiceModel(
      id: 'ig_story',
      title: 'Instagram Hikaye Paylaşımı',
      unit: 'Günlük / 1 Hikaye',
      price: 100.0,
      iconName: 'instagram',
      badge: 'HIZLI DÖNÜŞ',
      description: 'Pazarcık Portal resmi Instagram hesabında 24 saat boyunca hikayeniz paylaşılır, bağlantı ve konum eklenir.',
      highlight: 'Anlık duyuru, günlük menü ve indirimler için ideal.',
    ),
    SingleServiceModel(
      id: 'ig_post',
      title: 'Instagram Gönderi / Reels Paylaşımı',
      unit: 'Gönderi Başına',
      price: 150.0,
      iconName: 'photo_camera',
      badge: 'KALICI ERİŞİM',
      description: 'Profil akışımızda kalıcı olarak yayınlanır, detaylı açıklama, iletişim butonları ve etiketlerle desteklenir.',
      highlight: 'Kalıcı vitrin ve keşfete düşen yerel görünürlük.',
    ),
    SingleServiceModel(
      id: 'app_story',
      title: 'Portal Mobil & Web Hikaye Vitrini',
      unit: 'Günlük Sabitleme',
      price: 100.0,
      iconName: 'smartphone',
      badge: 'YÜKSEK ETKİLEŞİM',
      description: 'Pazarcık Portal mobil uygulaması ve web sitesi ana sayfasındaki Hikayeler bandında işletmeniz sergilenir.',
      highlight: 'Uygulamayı açan tüm hemşehrilerimizin ilk gördüğü alan.',
    ),
    SingleServiceModel(
      id: 'ig_pin',
      title: 'Instagram Başa Tutturma (Sabitleme)',
      unit: 'Günlük',
      price: 300.0,
      iconName: 'push_pin',
      badge: 'EN TEPEDE VİTRİN',
      description: 'Resmi Instagram profilimizin en üstündeki 3 gönderi alanında işletmeniz sabitlenerek ilk sırada tutulur.',
      highlight: 'Sayfayı ziyaret eden herkesin doğrudan dikkatini çeker.',
    ),
    SingleServiceModel(
      id: 'push_notification',
      title: 'Toplu Kampanya & Fırsat Bildirimi',
      unit: '1 Seferlik Gönderim',
      price: 500.0,
      iconName: 'notifications_active',
      badge: 'DOĞRUDAN CEBE ULAŞIM',
      description: 'Tüm kayıtlı Pazarcık Portal kullanıcılarına özel fırsat duyurusu şeklinde push bildirimi gönderilir.',
      highlight: 'Spam değildir; "X Mağazasında %20 indirim başladı" duyuru tarzındadır.',
    ),
    SingleServiceModel(
      id: 'app_splash',
      title: 'Mobil Uygulama Açılış / Karşılama Ekranı',
      unit: 'Aylık Sponsorluk',
      price: 2000.0,
      iconName: 'star',
      badge: 'MAKSİMUM PRESTİJ',
      description: 'Uygulama her açıldığında kullanıcıyı şık bir karşılama kartıyla selamlar; tek tıkla işletmenize yönlendirir.',
      highlight: 'İlçede ay boyunca on binlerce kez garanti gösterim.',
    ),
  ];

  /// Firebase Firestore'dan yapılandırmayı gerçek zamanlı akış ile dinler
  Stream<AdConfigModel> streamConfig() {
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .doc(_docName)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return _buildDefaultConfig();
      }

      final data = snap.data()!;
      final whatsapp = (data['whatsappPhone'] ?? data['whatsapp'] ?? '0546 466 4646').toString();
      final support = (data['supportPhone'] ?? data['phone'] ?? '0546 466 4646').toString();
      final igUser = (data['instagramUsername'] ?? 'pazarcikportal').toString();

      // İndirim oranları
      final discountsMap = <int, int>{};
      final rawDiscounts = data['periodDiscounts'] as Map<String, dynamic>?;
      if (rawDiscounts != null) {
        rawDiscounts.forEach((key, val) {
          final m = int.tryParse(key);
          final d = (val as num?)?.toInt();
          if (m != null && d != null) discountsMap[m] = d;
        });
      }
      if (discountsMap.isEmpty) {
        discountsMap[1] = 0;
        discountsMap[3] = 15;
        discountsMap[6] = 25;
        discountsMap[12] = 35;
      }

      // Paketler
      final packages = <AdPackageModel>[];
      final rawPackages = data['packages'] as Map<String, dynamic>?;
      for (final defPkg in defaultPackages) {
        if (rawPackages != null && rawPackages.containsKey(defPkg.id)) {
          final map = Map<String, dynamic>.from(rawPackages[defPkg.id] as Map);
          packages.add(AdPackageModel.fromMap(defPkg.id, map, defPkg));
        } else {
          packages.add(defPkg);
        }
      }

      // Tekil Hizmetler
      final singleServices = <SingleServiceModel>[];
      final rawSingles = data['singleServices'] as Map<String, dynamic>?;
      for (final defSvc in defaultSingleServices) {
        if (rawSingles != null && rawSingles.containsKey(defSvc.id)) {
          final map = Map<String, dynamic>.from(rawSingles[defSvc.id] as Map);
          singleServices.add(SingleServiceModel.fromMap(defSvc.id, map, defSvc));
        } else {
          singleServices.add(defSvc);
        }
      }

      final policyTitle = (data['policyTitle'] ?? 'Adil, Şeffaf ve İnsanları Sıkmayan Reklam Politikamız').toString();
      final policyText = (data['policyText'] ?? _defaultPolicyText).toString();

      return AdConfigModel(
        whatsappPhone: whatsapp,
        supportPhone: support,
        instagramUsername: igUser,
        periodDiscounts: discountsMap,
        packages: packages,
        singleServices: singleServices,
        policyTitle: policyTitle,
        policyText: policyText,
      );
    });
  }

  AdConfigModel _buildDefaultConfig() {
    return const AdConfigModel(
      whatsappPhone: '0546 466 4646',
      supportPhone: '0546 466 4646',
      instagramUsername: 'pazarcikportal',
      periodDiscounts: {1: 0, 3: 15, 6: 25, 12: 35},
      packages: defaultPackages,
      singleServices: defaultSingleServices,
      policyTitle: 'Adil, Şeffaf ve İnsanları Sıkmayan Reklam Politikamız',
      policyText: _defaultPolicyText,
    );
  }

  static const String _defaultPolicyText =
      'Pazarcık Portal olarak esnafımızın büyümesini desteklerken, hemşehrilerimizin kullanıcı deneyimini her zaman en üst seviyede tutuyoruz.\n\n'
      '• Bildirimler asla rahatsız edici spam reklam içermez; doğrudan fayda ve kazanç sağlayan indirim, kampanya veya yeni açılış duyurusu formatında iletilir.\n'
      '• Günlük hikaye ve gönderi kotaları dengeli tutularak takipçilerin ilgisinin diri kalması sağlanır.\n'
      '• Tüm tanıtımlar şeffaf, ölçülebilir ve yerel ekonomiyi canlandırma odaklıdır.';

  /// Firestore'daki reklam paketleri şablonunu ilk defa doldurur (veya admin için günceller)
  Future<void> initializeDefaultConfigInFirestore() async {
    try {
      final docRef = FirebaseFirestore.instance.collection(_collectionName).doc(_docName);
      final snap = await docRef.get();
      if (!snap.exists) {
        final Map<String, dynamic> packagesMap = {};
        for (var p in defaultPackages) {
          packagesMap[p.id] = p.toMap();
        }

        final Map<String, dynamic> singleMap = {};
        for (var s in defaultSingleServices) {
          singleMap[s.id] = s.toMap();
        }

        await docRef.set({
          'whatsappPhone': '0546 466 4646',
          'supportPhone': '0546 466 4646',
          'instagramUsername': 'pazarcikportal',
          'periodDiscounts': {'1': 0, '3': 15, '6': 25, '12': 35},
          'packages': packagesMap,
          'singleServices': singleMap,
          'policyTitle': 'Adil, Şeffaf ve İnsanları Sıkmayan Reklam Politikamız',
          'policyText': _defaultPolicyText,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[MerchantAdService] Firestore init uyarısı: $e');
    }
  }

  /// Reklam paketi veya tekil hizmet başvurusunu Firestore'a kaydeder ve admin'e bildirim iletir
  Future<void> submitAdRequest({
    required String businessName,
    required String contactName,
    required String phone,
    required String requestType, // 'package' veya 'single'
    required String itemName,
    required String periodLabel,
    required double totalPrice,
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final docData = {
      'userId': user?.uid ?? '',
      'userEmail': user?.email ?? '',
      'businessName': businessName.trim(),
      'contactName': contactName.trim(),
      'phone': phone.trim(),
      'requestType': requestType,
      'itemName': itemName,
      'periodLabel': periodLabel,
      'totalPrice': totalPrice,
      'note': note?.trim() ?? '',
      'status': 'pending', // pending, contacted, approved, rejected
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await FirebaseFirestore.instance.collection('ad_package_requests').add(docData);

    // Yöneticiye anında bildirim kuyruğu
    try {
      await AdminNotificationService.instance.notifyAdmin(
        title: '🚀 Yeni Reklam Paketi Başvurusu',
        body: '$businessName ($contactName), $itemName ($periodLabel) için başvurdu.',
        type: 'ad_package_request',
        docId: docRef.id,
        extra: {
          'phone': phone.trim(),
          'business': businessName.trim(),
          'price': '${totalPrice.toInt()} ₺',
        },
      );
    } catch (_) {}
  }

  /// WhatsApp ile doğrudan iletişime geçirir
  Future<void> openWhatsApp({
    required BuildContext context,
    required String whatsappNumber,
    required String message,
  }) async {
    final clean = whatsappNumber.replaceAll(RegExp(r'\D'), '');
    final phone = clean.startsWith('90')
        ? clean
        : clean.startsWith('0')
            ? '9${clean}'
            : '90$clean';

    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phone?text=$encoded');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp açılamadı. Lütfen $whatsappNumber numarasını arayın veya kaydedin.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
