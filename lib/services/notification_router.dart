import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/sahibinden/ad_detail_page.dart';
import 'package:pazarcik_portal/sahibinden/ads_main_page.dart';
import 'package:pazarcik_portal/sahibinden/add_ad_page.dart';
import 'package:pazarcik_portal/business/BusinessDetailPage.dart';
import 'package:pazarcik_portal/business/BusinessDirectoryPage.dart';
import 'package:pazarcik_portal/business/business_add_page.dart';
import 'package:pazarcik_portal/isilani/job_detail_page.dart';
import 'package:pazarcik_portal/isilani/job_listing_page.dart';
import 'package:pazarcik_portal/isilani/add_job_page.dart';
import 'package:pazarcik_portal/sahibinden/seller_store_page.dart';
import 'package:pazarcik_portal/dernek_sistemi/views/pazarcik_meydan_screen.dart';
import 'package:pazarcik_portal/grup/grup_ana_ekran.dart';
import 'package:pazarcik_portal/news_page.dart';
import 'package:pazarcik_portal/views/pharmacy_screen.dart';
import 'package:pazarcik_portal/views/cekgonder.dart';
import 'package:pazarcik_portal/services/earthquake_page.dart';
import 'package:pazarcik_portal/views/bildirimkutusuanasayfa.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/seller/dashboard_screens/orders.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/customer/my_orders_screen.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/customer/order_tracking_screen.dart';
import 'package:pazarcik_portal/profil/profile.dart';
import 'package:pazarcik_portal/widgets/interactive_poll_dialog.dart';
import 'package:pazarcik_portal/ilanveduyuru/ilan_duyurular_page.dart';
import 'package:pazarcik_portal/widgets/cek_gonder_reply_dialog.dart';

class NotificationRouter {
  /// Bildirimin tıklanabilir bir hedefi (sayfa veya link) olup olmadığını kontrol eder.
  static bool hasAction(Map<String, dynamic> data) {
    final targetType = (data['targetType'] ?? '').toString().trim();
    final linkUrl = (data['linkUrl'] ?? data['url'] ?? '').toString().trim();
    final type = (data['type'] ?? '').toString().trim();
    final orderId = (data['orderId'] ?? '').toString().trim();

    if (linkUrl.isNotEmpty) return true;
    if (orderId.isNotEmpty) return true;
    if (targetType.isNotEmpty && targetType != 'none') return true;
    if (type == 'cek_gonder_reply' ||
        type == 'cek_gonder' ||
        targetType == 'cek_gonder') {
      return true;
    }
    if (type == 'news' ||
        type == 'haber' ||
        type == 'earthquake' ||
        type == 'new_order' ||
        type == 'order' ||
        type == 'order_status' ||
        type == 'order_update' ||
        type == 'courier_at_door' ||
        type == 'order_delivered' ||
        targetType == 'order_tracking' ||
        type == 'Anket') {
      return true;
    }
    return false;
  }

  /// Bildirim tipine göre kullanıcıya gösterilecek aksiyon butonu metni
  static String getActionLabel(Map<String, dynamic> data) {
    final targetType = (data['targetType'] ?? '').toString().trim();
    final linkUrl =
        (data['linkUrl'] ?? data['url'] ?? '').toString().trim().toLowerCase();
    final type = (data['type'] ?? '').toString().trim();

    // Özel link kontrolü
    if (linkUrl.contains('instagram.com') || linkUrl.startsWith('@')) {
      return "Instagram'da Aç";
    }
    if (linkUrl.contains('facebook.com') || linkUrl.contains('fb.com')) {
      return "Facebook'ta Aç";
    }
    if (linkUrl.contains('youtube.com') || linkUrl.contains('youtu.be')) {
      return "YouTube'da Aç";
    }

    switch (targetType) {
      case 'url':
        return 'Bağlantıyı Aç';
      case 'meydan':
        return 'Meydan\'a Git';
      case 'meydan_post':
        return 'Meydan Gönderisine Git';
      case 'jobs':
      case 'job_listing':
        return 'İş İlanlarına Git';
      case 'add_job':
      case 'job_add':
        return 'İş İlanı Ver';
      case 'job':
        return 'İş İlanını İncele';
      case 'classified_ads':
      case 'ads':
        return 'İlanlara Göz At';
      case 'add_ad':
        return 'İlan Ver';
      case 'ad':
        return 'İlanı Görüntüle';
      case 'businesses':
      case 'business_directory':
        return 'Esnaf Rehberini Gör';
      case 'add_business':
        return 'İşletme Ekle';
      case 'business':
        return 'İşletmeyi Gör';
      case 'pharmacy':
      case 'eczane':
        return 'Nöbetçi Eczaneleri Gör';
      case 'cek_gonder':
        return 'Çek Gönder\'e Git';
      case 'seller':
      case 'food_store':
        return 'Mağazayı Ziyaret Et';
      case 'food_orders':
        return 'Siparişlere Git';
      case 'announcement':
      case 'announcements':
        return 'Bülteni Görüntüle';
      case 'group':
        return 'Gruba Git';
      case 'group_poll':
        return 'Grup Anketine Katıl';
      case 'news':
        return 'Haberi Oku';
      case 'profile':
        return 'Profile Git';
      case 'notifications':
        return 'Bildirimlere Git';
    }

    if (linkUrl.isNotEmpty) return 'Bağlantıyı Aç';

    if (type == 'cek_gonder_reply' || targetType == 'cek_gonder') {
      return 'Yanıtı ve Detayı Gör';
    }
    if (type == 'announcement' ||
        type == 'Duyuru' ||
        type == 'Etkinlik' ||
        type == 'Acil' ||
        type == 'Cenaze') {
      return 'Bülteni Gör';
    }
    if (type == 'news' || type == 'haber') return 'Haberi Oku';
    if (type == 'earthquake') return 'Deprem Bilgisini Gör';
    if (type == 'new_order' || type == 'order') return 'Siparişlere Git';
    if (type == 'order_status' ||
        type == 'order_update' ||
        type == 'courier_at_door' ||
        type == 'order_delivered' ||
        targetType == 'order_tracking' ||
        (data['orderId'] != null && data['orderId'].toString().isNotEmpty)) {
      return 'Siparişi Canlı Takip Et 🛵';
    }
    if (type == 'Anket') return 'Ankete Katıl';

    return 'Detayları Gör';
  }

  /// Bildirim tipine göre aksiyon butonu ikonu
  static IconData getActionIcon(Map<String, dynamic> data) {
    final targetType = (data['targetType'] ?? '').toString().trim();
    final linkUrl =
        (data['linkUrl'] ?? data['url'] ?? '').toString().trim().toLowerCase();
    final type = (data['type'] ?? '').toString().trim();

    if (linkUrl.contains('instagram.com') || linkUrl.startsWith('@')) {
      return Icons.camera_alt_outlined;
    }
    if (linkUrl.contains('facebook.com') || linkUrl.contains('fb.com')) {
      return Icons.facebook;
    }
    if (linkUrl.contains('youtube.com') || linkUrl.contains('youtu.be')) {
      return Icons.play_circle_outline;
    }

    switch (targetType) {
      case 'url':
        return CupertinoIcons.globe;
      case 'meydan':
      case 'meydan_post':
        return Icons.forum_outlined;
      case 'jobs':
      case 'job_listing':
      case 'add_job':
      case 'job_add':
      case 'job':
        return Icons.work_outline;
      case 'classified_ads':
      case 'ads':
      case 'add_ad':
      case 'ad':
        return Icons.shopping_bag_outlined;
      case 'businesses':
      case 'business_directory':
      case 'add_business':
      case 'business':
        return Icons.storefront_outlined;
      case 'pharmacy':
      case 'eczane':
        return CupertinoIcons.bandage_fill;
      case 'cek_gonder':
        return CupertinoIcons.camera_fill;
      case 'seller':
      case 'food_store':
      case 'food_orders':
        return Icons.restaurant_menu;
      case 'announcement':
      case 'announcements':
        return CupertinoIcons.sparkles;
      case 'group':
        return Icons.groups_outlined;
      case 'group_poll':
        return Icons.poll_outlined;
      case 'news':
        return Icons.newspaper;
      case 'profile':
        return Icons.person_outline;
      case 'notifications':
        return CupertinoIcons.bell_fill;
    }

    if (linkUrl.isNotEmpty) return CupertinoIcons.globe;

    if (type == 'cek_gonder_reply' || targetType == 'cek_gonder') {
      return Icons.mark_chat_read_outlined;
    }
    if (type == 'announcement' ||
        type == 'Duyuru' ||
        type == 'Etkinlik' ||
        type == 'Acil' ||
        type == 'Cenaze') {
      return CupertinoIcons.sparkles;
    }

    if (type == 'news' || type == 'haber') return Icons.newspaper;
    if (type == 'earthquake') return Icons.waves;
    if (type == 'new_order' || type == 'order') return Icons.receipt_long;
    if (type == 'order_status' ||
        type == 'order_update' ||
        type == 'courier_at_door' ||
        type == 'order_delivered' ||
        targetType == 'order_tracking' ||
        (data['orderId'] != null && data['orderId'].toString().isNotEmpty)) {
      return CupertinoIcons.map_pin_ellipse;
    }
    if (type == 'Anket') return Icons.poll_outlined;

    return CupertinoIcons.arrow_right_circle;
  }

  /// Harici web linklerini, Instagram veya Facebook gibi uygulamaları açar.
  static Future<void> openExternalOrSocialUrl(String urlString) async {
    String cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return;

    if (cleanUrl.startsWith('@')) {
      final username = cleanUrl.replaceFirst('@', '');
      cleanUrl = 'https://instagram.com/$username';
    } else if (!cleanUrl.startsWith('http://') &&
        !cleanUrl.startsWith('https://') &&
        !cleanUrl.startsWith('instagram://') &&
        !cleanUrl.startsWith('fb://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) return;

    // 1. Instagram bağlantısı ise: Doğrudan cihazdaki Instagram uygulamasını dene
    if (cleanUrl.toLowerCase().contains('instagram.com')) {
      try {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final first = segments.first;
          if (first != 'p' &&
              first != 'reel' &&
              first != 'stories' &&
              first != 'tv') {
            final nativeAppUri =
                Uri.parse('instagram://user?username=$first');
            if (await canLaunchUrl(nativeAppUri)) {
              await launchUrl(nativeAppUri,
                  mode: LaunchMode.externalNonBrowserApplication);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint("Instagram native açma denemesi: $e");
      }
    }

    // 2. Facebook bağlantısı ise: Doğrudan cihazdaki Facebook uygulamasını dene
    if (cleanUrl.toLowerCase().contains('facebook.com') ||
        cleanUrl.toLowerCase().contains('fb.com')) {
      try {
        final fbAppUri = Uri.parse('fb://facewebmodal/f?href=$cleanUrl');
        if (await canLaunchUrl(fbAppUri)) {
          await launchUrl(fbAppUri,
              mode: LaunchMode.externalNonBrowserApplication);
          return;
        }
      } catch (e) {
        debugPrint("Facebook native açma denemesi: $e");
      }
    }

    // 3. Standart Harici Tarayıcı (Chrome, Safari vb.)
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Harici tarayıcı açma hatası: $e");
    }
  }

  /// Kullanıcıyı bildirimin ilgili içeriğine (uygulama sayfaları veya harici/sosyal linke) yönlendirir.
  static Future<void> navigateToTarget(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final targetType = (data['targetType'] ?? '').toString().trim();
    final targetId =
        (data['targetId'] ?? data['docId'] ?? '').toString().trim();
    final linkUrl = (data['linkUrl'] ?? data['url'] ?? '').toString().trim();
    final type = (data['type'] ?? '').toString().trim();

    // ── 1. ÖNCELİK: Web / Sosyal Medya Linki ──
    // Eğer hedef tipi 'url' ise veya bir linkUrl girilmiş ve belirli bir sayfa hedefi seçilmemişse
    if (targetType == 'url' ||
        (linkUrl.isNotEmpty && (targetType.isEmpty || targetType == 'none'))) {
      await openExternalOrSocialUrl(linkUrl);
      return;
    }

    // ── 2. MEYDAN SAYFASI VE GÖNDERİLERİ ──
    if (targetType == 'meydan') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PazarcikMeydanScreen()),
      );
      return;
    }

    if (targetType == 'meydan_post') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PazarcikMeydanScreen()),
      );
      return;
    }

    // ── 3. İŞ İLANLARI SAYFALARI ──
    if (targetType == 'jobs' || targetType == 'job_listing') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JobListingPage()),
      );
      return;
    }

    if (targetType == 'add_job' || targetType == 'job_add') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddJobPage()),
      );
      return;
    }

    // Belirli İş İlanı Detayı
    if (targetType == 'job' ||
        targetType == 'job_posting' ||
        targetType == 'is_ilani') {
      if (targetId.isNotEmpty) {
        try {
          var doc = await FirebaseFirestore.instance
              .collection('job_postings')
              .doc(targetId)
              .get();
          if (!doc.exists) {
            doc = await FirebaseFirestore.instance
                .collection('job_ads')
                .doc(targetId)
                .get();
          }

          if (doc.exists && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    JobDetailPage(job: doc.data()!, docId: targetId),
              ),
            );
            return;
          }
        } catch (e) {
          debugPrint("İş ilanı yönlendirme hatası: $e");
        }
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JobListingPage()),
        );
        return;
      }
    }

    // ── 4. SAHİBİNDEN / SERİ İLANLAR ──
    if (targetType == 'classified_ads' || targetType == 'ads') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdsMainPage()),
      );
      return;
    }

    if (targetType == 'add_ad') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddAdPage()),
      );
      return;
    }

    if (targetType == 'ad' && targetId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('classified_ads')
            .doc(targetId)
            .get();
        if (doc.exists && context.mounted) {
          final adData = Map<String, dynamic>.from(doc.data()!);
          adData['docId'] = doc.id;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdDetailPage(ad: adData)),
          );
          return;
        }
      } catch (e) {
        debugPrint("İlan yönlendirme hatası: $e");
      }
    }

    // ── 5. İŞLETME & ESNAF REHBERİ ──
    if (targetType == 'businesses' || targetType == 'business_directory') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessDirectoryPage()),
      );
      return;
    }

    if (targetType == 'add_business') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessAddPage()),
      );
      return;
    }

    if (targetType == 'business' && targetId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(targetId)
            .get();
        if (doc.exists && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BusinessDetailPage(doc: doc)),
          );
          return;
        }
      } catch (e) {
        debugPrint("İşletme yönlendirme hatası: $e");
      }
    }

    // ── 6. MAĞAZA / YEMEK ESNAFI ──
    if ((targetType == 'seller' || targetType == 'food_store') &&
        targetId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerStorePage(sellerId: targetId),
        ),
      );
      return;
    }

    if (targetType == 'food_orders') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
      return;
    }

    if (targetType == 'order_tracking') {
      final orderId =
          (data['orderId'] ?? data['targetId'] ?? targetId).toString();
      if (orderId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
      );
      return;
    }

    // ── 7. NÖBETÇİ ECZANELER ──
    if (targetType == 'pharmacy' || targetType == 'eczane') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PharmacyScreen()),
      );
      return;
    }

    // ── 8. ÇEK GÖNDER ──
    if (targetType == 'cek_gonder') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CekGonderPage()),
      );
      return;
    }

    if (type == 'cek_gonder_reply') {
      final effectiveDocId =
          (data['docId'] ?? data['targetId'] ?? '').toString();
      CekGonderReplyDialog.show(context,
          data: data, docId: effectiveDocId.isNotEmpty ? effectiveDocId : null);
      return;
    }

    // ── 9. GRUPLAR ──
    if (targetType == 'group' || targetType == 'group_poll') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GrupAnaEkran()),
      );
      return;
    }

    // ── 10. PROFİL ──
    if (targetType == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    // ── 11. ANKET BİLDİRİMİ ──
    if (type == 'Anket' && data['pollOptions'] != null) {
      final options = List<String>.from(data['pollOptions'] ?? []);
      final question =
          (data['targetLabel'] ?? data['title'] ?? 'Anket').toString();
      final pollId =
          (data['notificationId'] ?? data['docId'] ?? '').toString();
      if (options.isNotEmpty && pollId.isNotEmpty) {
        InteractivePollDialog.show(
          context,
          question: question,
          options: options,
          pollId: pollId,
        );
        return;
      }
    }

    // ── 12. HABERLER ──
    if (targetType == 'news' || type == 'news' || type == 'haber') {
      if (linkUrl.isNotEmpty) {
        await openExternalOrSocialUrl(linkUrl);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewsPage()),
      );
      return;
    }

    // ── 13. BÜLTEN & DUYURULAR ──
    if (targetType == 'announcements' ||
        targetType == 'announcement' ||
        type == 'announcement' ||
        type == 'Duyuru' ||
        type == 'Etkinlik' ||
        type == 'Acil' ||
        type == 'Cenaze') {
      // Eğer bir linkUrl varsa ve hedefsiz duyuru ise, linke gitmesi daha önceliklidir!
      if (linkUrl.isNotEmpty) {
        await openExternalOrSocialUrl(linkUrl);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IlanDuyurularPage()),
      );
      return;
    }

    // ── 14. DİĞER LİNK VE TİPLER ──
    if (linkUrl.isNotEmpty) {
      await openExternalOrSocialUrl(linkUrl);
      return;
    }

    if (type == 'new_order' || type == 'order') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
      return;
    }

    if (type == 'order_status' ||
        type == 'order_update' ||
        type == 'courier_at_door' ||
        type == 'order_delivered' ||
        targetType == 'order_tracking') {
      final orderId = (data['orderId'] ?? data['targetId'] ?? '').toString();
      if (orderId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
      );
      return;
    }

    if (type == 'earthquake') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EarthquakePage()),
      );
      return;
    }

    // Varsayılan: Bildirim Kutusu
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BildirimKutusuAnaSayfa()),
    );
  }
}
