// ignore_for_file: deprecated_member_use

import 'package:barcode/barcode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

// 🔥 BİLDİRİM SERVİSİNİ İÇERİ AKTAR
import 'package:pazarcik_portal/services/notification_service.dart';

// Sayfa importlarını buraya eklediğinden emin ol
import 'dashboard_screens/account_balance.dart';
import 'dashboard_screens/manage_products.dart';
import 'dashboard_screens/orders.dart';
import 'dashboard_screens/statistics.dart';
import 'dashboard_screens/store_setup.dart';
import 'dashboard_screens/upload_product.dart';
import 'dashboard_screens/manage_extras.dart';
import 'dashboard_screens/notifications_screen.dart';
import '../../../masa_sistemi/table_system_screen.dart';

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  static const routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? "";

  // 🔥 Bildirim Durumu
  bool isNotificationEnabled = false;
  bool _notificationWarningShown = false;

  // Menü Listesi
  final List<Map<String, dynamic>> menuList = [
    {
      'title': 'Siparişler',
      'icon': CupertinoIcons.cube_box_fill,
      'color': trendyolOrange,
      'page': const OrdersScreen()
    },
    {
      'title': 'Ürün Yükle',
      'icon': CupertinoIcons.plus_app_fill,
      'color': const Color(0xFF34C759),
      'page': const UploadProduct()
    },
    {
      'title': 'Ayın İndirimli Menü',
      'icon': CupertinoIcons.tag_fill,
      'color': const Color(0xFFFF2D55),
      'page': const UploadProduct(monthlyDealMode: true)
    },
    {
      'title': 'Ürün Yönetimi',
      'icon': CupertinoIcons.doc_text_viewfinder,
      'color': const Color(0xFF007AFF),
      'page': const ManageProductsScreen()
    },
    {
      'title': 'Ekstralar',
      'icon': CupertinoIcons.sparkles,
      'color': const Color(0xFFFF9500),
      'page': const ManageExtrasScreen()
    },
    {
      'title': 'Kasa / Bakiye',
      'icon': CupertinoIcons.money_dollar_circle_fill,
      'color': const Color(0xFFAF52DE),
      'page': const AccountBalanceScreen()
    },
    {
      'title': 'İstatistik',
      'icon': CupertinoIcons.chart_bar_alt_fill,
      'color': const Color(0xFF5856D6),
      'page': const StatisticsScreen()
    },
    {
      'title': 'Mağaza Ayarı',
      'icon': CupertinoIcons.settings_solid,
      'color': const Color(0xFF8E8E93),
      'page': const StoreSetupScreen()
    },
    {
      'title': 'Masa Yönetimi',
      'icon': Icons.table_restaurant_rounded,
      'color': const Color(0xFF009688),
      'page': const TableSystemScreen()
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  // 🔥 Firestore'dan esnafın bildirim tercihini oku
  Future<void> _loadNotificationStatus() async {
    if (currentUserId.isEmpty) return;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(currentUserId)
          .get();
      var enabled = false;
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!.containsKey('sellerNotificationEnabled')) {
        enabled = doc.data()!['sellerNotificationEnabled'] == true;
        if (mounted) {
          setState(() {
            isNotificationEnabled = enabled;
          });
        }
      }
      if (!enabled) _showNotificationWarningOnce();
    } catch (e) {
      debugPrint("Bildirim durumu çekilemedi: $e");
      _showNotificationWarningOnce();
    }
  }

  void _showNotificationWarningOnce() {
    if (_notificationWarningShown || !mounted) return;
    _notificationWarningShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isNotificationEnabled) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Sipariş Bildirimleri Kapalı'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Yeni sipariş geldiğinde sesli uyarı almak için bildirimleri aktif etmelisiniz. Bildirim kapalı kalırsa siparişleri yalnızca panele girince görebilirsiniz.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Sonra'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Aktif Et'),
              onPressed: () {
                Navigator.pop(context);
                _toggleNotification(true);
              },
            ),
          ],
        ),
      );
    });
  }

  // 🔥 BİLDİRİM AÇMA/KAPATMA FONKSİYONU
  void _toggleNotification(bool value) async {
    try {
      if (value) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Bildirim izni kapalı. Telefon ayarlarından Pazarcık Portal bildirimlerini açın."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        // 1. Firebase Messaging Kalıcı Aboneliği
        await NotificationService().subscribeAsSeller(currentUserId);

        // 2. Veritabanına Kalıcı Kayıt
        await FirebaseFirestore.instance
            .collection('sellers')
            .doc(currentUserId)
            .set({
          'sellerNotificationEnabled': true,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Sipariş bildirimleri açıldı. 🔔"),
                backgroundColor: Colors.green),
          );
        }
      } else {
        // 1. Firebase Messaging Aboneliğinden Çık
        await NotificationService().unsubscribeAsSeller(currentUserId);

        // 2. Veritabanına Kalıcı Kayıt
        await FirebaseFirestore.instance
            .collection('sellers')
            .doc(currentUserId)
            .set({
          'sellerNotificationEnabled': false,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Sipariş bildirimleri kapatıldı. 🔕"),
                backgroundColor: Colors.redAccent),
          );
        }
      }
      if (mounted) {
        setState(() {
          isNotificationEnabled = value;
        });
      }
    } catch (e) {
      debugPrint("Bildirim ayarı değişirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bildirim ayarı değiştirilemedi: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String get _menuUrl =>
      'https://www.pazarcikportal.com/magaza?id=$currentUserId';

  String _pdfSafe(String value) {
    const replacements = {
      'ç': 'c',
      'Ç': 'C',
      'ğ': 'g',
      'Ğ': 'G',
      'ı': 'i',
      'İ': 'I',
      'ö': 'o',
      'Ö': 'O',
      'ş': 's',
      'Ş': 'S',
      'ü': 'u',
      'Ü': 'U',
    };
    var result = value;
    replacements.forEach((key, replacement) {
      result = result.replaceAll(key, replacement);
    });
    return result;
  }

  Future<Map<String, dynamic>> _loadStoreData() async {
    if (currentUserId.isEmpty) return {};
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(currentUserId)
        .get();
    return doc.data() ?? {};
  }

  Future<void> _shareQrMenuPdf() async {
    try {
      final storeData = await _loadStoreData();
      final storeName = (storeData['storeName'] ??
              storeData['businessName'] ??
              storeData['restaurantName'] ??
              storeData['fullname'] ??
              'Pazarcik Portal')
          .toString();
      final safeName = _pdfSafe(storeName);
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(28),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange, width: 2),
                borderRadius: pw.BorderRadius.circular(18),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    safeName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Pazarcik Portal QR Menu',
                    style: const pw.TextStyle(
                      color: PdfColors.grey700,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 28),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: _menuUrl,
                    width: 250,
                    height: 250,
                  ),
                  pw.SizedBox(height: 22),
                  pw.Text(
                    'Menuyu acmak icin telefon kamerasi ile okutun.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 10),
                  pw.UrlLink(
                    destination: _menuUrl,
                    child: pw.Text(
                      _menuUrl,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        color: PdfColors.blue,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Share.shareXFiles(
        [
          XFile.fromData(
            await pdf.save(),
            mimeType: 'application/pdf',
            name: 'pazarcik_portal_qr_menu_$currentUserId.pdf',
          ),
        ],
        text: 'Pazarcık Portal QR menü PDF',
      );
    } catch (e) {
      _showSnack('QR menü hazırlanamadı: $e', Colors.redAccent);
    }
  }

  void _shareQrLink() {
    Share.share('Pazarcık Portal menümü inceleyin:\n$_menuUrl');
  }

  Future<void> _copyQrLink() async {
    await Clipboard.setData(ClipboardData(text: _menuUrl));
    _showSnack('QR menü linki kopyalandı.', const Color(0xFF34C759));
  }

  Future<void> _shareQrMenuImage() async {
    try {
      final storeData = await _loadStoreData();
      final storeName = (storeData['storeName'] ??
              storeData['businessName'] ??
              storeData['restaurantName'] ??
              storeData['fullname'] ??
              'Pazarcık Portal')
          .toString();
      final safeName = _fileSafeName(storeName);
      final pngBytes = _buildQrPngBytes(_menuUrl);

      await Share.shareXFiles(
        [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: 'pazarcik_portal_qr_menu_$safeName.png',
          ),
        ],
        text: 'Pazarcık Portal QR menü kodu',
      );
    } catch (e) {
      _showSnack('QR görseli hazırlanamadı: $e', Colors.redAccent);
    }
  }

  String _fileSafeName(String value) {
    final cleaned = _pdfSafe(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? currentUserId : cleaned;
  }

  Uint8List _buildQrPngBytes(String data) {
    const imageSize = 1024;
    const quietZone = 96;
    const qrSize = imageSize - (quietZone * 2);
    final image = img.Image(width: imageSize, height: imageSize);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    final barcode = Barcode.qrCode();
    for (final element in barcode.make(
      data,
      width: qrSize.toDouble(),
      height: qrSize.toDouble(),
      drawText: false,
    )) {
      if (element is! BarcodeBar || !element.black) continue;
      final left = (quietZone + element.left).round().clamp(0, imageSize - 1);
      final top = (quietZone + element.top).round().clamp(0, imageSize - 1);
      final right = (quietZone + element.right).ceil().clamp(0, imageSize);
      final bottom = (quietZone + element.bottom).ceil().clamp(0, imageSize);
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: right,
        y2: bottom,
        color: img.ColorRgb8(0, 0, 0),
      );
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: iosBg,
      body: Stack(
        children: [
          // Arka Plan Yumuşak Turuncu Efekt
          Positioned(
            top: -size.height * 0.15,
            right: -size.width * 0.2,
            child: Container(
              height: size.height * 0.5,
              width: size.width * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    trendyolOrange.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Başlık ve Bildirim Zili
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Esnaf Paneli",
                                style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: isTablet ? 34 : 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1)),
                            const SizedBox(height: 4),
                            Text("Dükkanın Bugün Ne Durumda?",
                                style: GoogleFonts.inter(
                                    color: Colors.black45,
                                    fontSize: isTablet ? 18 : 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        // CANLI BİLDİRİM İKONU BURADA
                        _buildNotificationBell(),
                      ],
                    ),
                  ),
                ),

                // 🔥 YENİ EKLENDİ: ŞIK BİLDİRİM AÇ/KAPAT ANAHTARI
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ]),
                      child: ListTile(
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: trendyolOrange.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.bell_fill,
                                color: trendyolOrange, size: 20),
                          ),
                        ),
                        title: Text(
                          "Yeni Sipariş Bildirimleri",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          "Zil sesini açıp kapatın",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.black54),
                        ),
                        trailing: CupertinoSwitch(
                          value: isNotificationEnabled,
                          activeColor: Colors.green,
                          onChanged: _toggleNotification,
                        ),
                      ),
                    ),
                  ),
                ),

                if (!isNotificationEnabled)
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: _buildNotificationWarningCard(),
                    ),
                  ),

                // Özet Kartı (Ciro & Sipariş)
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  sliver: SliverToBoxAdapter(
                    child: _buildSummaryCard(),
                  ),
                ),

                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  sliver: SliverToBoxAdapter(
                    child: _buildQrMenuCard(),
                  ),
                ),

                // Menü Grid
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 3 : 2,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: isTablet ? 1.3 : 1.1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = menuList[index];
                        return _buildMenuCard(item, isTablet);
                      },
                      childCount: menuList.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('to', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationsScreen()));
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ],
                ),
                child: const Icon(CupertinoIcons.bell_fill,
                    color: trendyolOrange, size: 24),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      unreadCount > 9 ? "9+" : "$unreadCount",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQrMenuCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.qrcode,
                  color: trendyolOrange,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR Menüm',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Müşteriler masadan QR kodu okutup menünüzü ve güncel ürünlerinizi görebilir.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.link,
                    size: 17, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _menuUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _qrActionButton(
                  label: 'QR PDF Al',
                  icon: CupertinoIcons.arrow_down_doc_fill,
                  onPressed: _shareQrMenuPdf,
                  filled: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _qrActionButton(
                  label: 'QR Görsel Al',
                  icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                  onPressed: _shareQrMenuImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _qrActionButton(
                  label: 'Linki Kopyala',
                  icon: CupertinoIcons.doc_on_clipboard,
                  onPressed: _copyQrLink,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                width: 50,
                child: OutlinedButton(
                  onPressed: _shareQrLink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: trendyolOrange,
                    side: BorderSide(color: trendyolOrange.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(CupertinoIcons.share, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: trendyolOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: trendyolOrange,
            side: BorderSide(color: trendyolOrange.withOpacity(0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );

    return SizedBox(
      height: 44,
      child: filled
          ? ElevatedButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }

  Widget _buildNotificationWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: trendyolOrange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.bell_slash_fill,
                color: trendyolOrange, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sipariş bildirimleri kapalı',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7C2D12),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aktif etmezseniz yeni sipariş geldiğinde sesli uyarı alamazsınız.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.3,
                    color: const Color(0xFF9A3412),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleNotification(true),
                    icon: const Icon(CupertinoIcons.bell_fill, size: 16),
                    label: const Text('Bildirimleri Aktif Et'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: trendyolOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('sellerId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          int siparisSayisi = snapshot.hasData ? snapshot.data!.docs.length : 0;
          double ciro = 0.0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              ciro +=
                  (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0.0;
            }
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatDetail("$siparisSayisi", "Toplam Sipariş",
                  CupertinoIcons.bag_fill, const Color(0xFF007AFF)),
              Container(width: 1, height: 40, color: iosBg),
              _buildStatDetail(
                  "₺${ciro.toStringAsFixed(0)}",
                  "Kasa (Ciro)",
                  CupertinoIcons.money_dollar_circle_fill,
                  const Color(0xFF34C759)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatDetail(
      String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(val,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.black45,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> item, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => item['page'])),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(item['icon'],
                    size: isTablet ? 38 : 30, color: item['color']),
              ),
              const SizedBox(height: 12),
              Text(
                item['title'],
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.black87,
                    fontSize: isTablet ? 15 : 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
