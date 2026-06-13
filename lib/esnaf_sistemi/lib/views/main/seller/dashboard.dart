// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

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
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!.containsKey('sellerNotificationEnabled')) {
        if (mounted) {
          setState(() {
            isNotificationEnabled =
                doc.data()!['sellerNotificationEnabled'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint("Bildirim durumu çekilemedi: $e");
    }
  }

  // 🔥 BİLDİRİM AÇMA/KAPATMA FONKSİYONU
  void _toggleNotification(bool value) async {
    setState(() {
      isNotificationEnabled = value;
    });

    try {
      if (value) {
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
    } catch (e) {
      debugPrint("Bildirim ayarı değişirken hata: $e");
    }
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
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: trendyolOrange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.bell_fill,
                              color: trendyolOrange),
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

                // Özet Kartı (Ciro & Sipariş)
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  sliver: SliverToBoxAdapter(
                    child: _buildSummaryCard(),
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
