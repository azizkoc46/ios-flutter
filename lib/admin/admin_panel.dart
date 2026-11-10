// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_stats_tab.dart';
import 'admin_stories_tab.dart';
import 'admin_business_tab.dart';
import 'admin_story_manage_page.dart';
import 'admin_cekgonder_tab.dart';
import 'admin_announcements_tab.dart';
import 'admin_users_tab.dart';
import 'admin_restaurants_tab.dart';
import 'admin_store_orders_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_classified_ads_tab.dart';
import 'admin_manual_classified_ad_tab.dart';
import 'admin_manual_job_tab.dart';
import 'admin_activity_feed_tab.dart';
import 'admin_pending_center_tab.dart';
import 'admin_phone_verification_tab.dart';
import 'admin_taxi_tab.dart';
import 'admin_roadside_tab.dart';
import 'admin_muhtarlik_tab.dart';
import 'admin_ad_management_tab.dart';
import 'package:pazarcik_portal/business/business_add_page.dart';
import 'admin_notification_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF6366F1);
  bool _checkingAdmin = true;
  bool _isAuthorized = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 21, vsync: this);
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() { _checkingAdmin = false; _isAuthorized = false; });
      return;
    }

    try {
      final token = await user.getIdTokenResult();
      final claims = token.claims ?? const <String, dynamic>{};
      final claimRole = (claims['role'] ?? claims['rol'] ?? claims['userRole'])
          ?.toString()
          .toLowerCase()
          .trim();
      final hasClaim = claims['admin'] == true ||
          claims['isAdmin'] == true ||
          claimRole == 'admin' ||
          claimRole == 'yonetici' ||
          claimRole == 'yönetici';

      if (hasClaim) {
        if (mounted) {
          setState(() {
            _checkingAdmin = false;
            _isAuthorized = true;
          });
        }
        await _registerAdminToken();
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      final data = doc.data() ?? {};
      final role = (data['role'] ?? data['rol'] ?? data['userRole'] ?? '').toString().toLowerCase().trim();
      final isAdmin = role == 'admin' ||
          role == 'yonetici' ||
          role == 'yönetici' ||
          data['isAdmin'] == true ||
          data['admin'] == true;

      if (mounted) {
        setState(() {
          _checkingAdmin = false;
          _isAuthorized = isAdmin;
        });
      }
      if (isAdmin) {
        await _registerAdminToken();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingAdmin = false;
          _isAuthorized = false;
        });
      }
    }
  }

  Future<void> _registerAdminToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await AdminNotificationService.instance.registerAdminToken(uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.lock_shield_fill, color: Colors.redAccent, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Yetkisiz Erişim',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Bu yönetim merkezine yalnızca yetkili Pazarcık Portal yöneticileri erişebilir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.house_fill, size: 16),
                  label: const Text('Ana Sayfaya Dön'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.shield_fill,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Yönetim Merkezi',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          actions: [
            _BadgeIcon(
              icon: CupertinoIcons.bell_fill,
              collection: 'admin_notifications_log',
              color: Colors.orange,
              filterField: 'seen',
              filterValue: false,
              onTap: _showNotificationsSheet,
            ),
            const SizedBox(width: 4),
            _buildAddMenu(),
            const SizedBox(width: 10),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: _primary,
                unselectedLabelColor: Colors.black45,
                indicatorColor: _primary,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 12),
                tabs: const [
                  Tab(text: "Özet"),
                  Tab(text: "Bekleyenler"),
                  Tab(text: "Tel. Doğrulama"),
                  Tab(text: "Aktivite"),
                  Tab(text: "Kullanıcılar"),
                  Tab(text: "Restoranlar"),
                  Tab(text: "Siparişler"),
                  Tab(text: "İlanlar"),
                  Tab(text: "Manuel İlan"),
                  Tab(text: "İş İlanı"),
                  Tab(text: "Öne Çıkanlar"),
                  Tab(text: "Emlakçılar"),
                  Tab(text: "İşletmeler"),
                  Tab(text: "Sahiplik"),
                  Tab(text: "Çek Gönder"),
                  Tab(text: "Taksiler"),
                  Tab(text: "7/24 Yol Yardım"),
                  Tab(text: "Muhtarlıklar"),
                  Tab(text: "Bülten & Etkinlik"),
                  Tab(text: "Reklam Yönetimi"),
                  Tab(text: "Ayarlar"),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            AdminStatsTab(),
            AdminPendingCenterTab(),
            AdminPhoneVerificationTab(),
            AdminActivityFeedTab(),
            AdminUsersTab(),
            AdminRestaurantsTab(),
            AdminStoreOrdersTab(),
            AdminClassifiedAdsTab(),
            AdminManualClassifiedAdTab(),
            AdminManualJobTab(),
            AdminStoriesTab(),
            AdminBusinessTab(type: 'emlakci'),
            AdminBusinessTab(type: 'private'),
            AdminBusinessTab(type: 'claims'),
            AdminCekGonderTab(),
            AdminTaxiTab(),
            AdminRoadsideTab(),
            AdminMuhtarlikTab(),
            AdminAnnouncementsTab(),
            AdminAdManagementTab(),
            AdminSettingsTab(),
          ],
        ),
      );
  }

  Widget _buildAddMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(CupertinoIcons.add, color: _primary, size: 20),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (val) {
        if (val == 'story') {
          _showAddStoryDialog();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessAddPage(isPublic: val == 'public'),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        _menuItem('story', CupertinoIcons.play_circle_fill, 'Öne Çıkan Ekle',
            Colors.purple),
        const PopupMenuDivider(),
        _menuItem('private', CupertinoIcons.building_2_fill, 'İşletme Ekle',
            Colors.teal),
        _menuItem(
            'public', CupertinoIcons.globe, 'Kamu Kurumu Ekle', Colors.blue),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminNotificationsSheet(
        onGoToPhoneVerification: () {
          Navigator.pop(ctx);
          _tabController.animateTo(2); // Tel. Doğrulama sekmesi
        },
      ),
    );
  }

  void _showAddStoryDialog() {
    final titleController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Yeni Öne Çıkan Ekle'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: titleController,
            placeholder: 'Başlık',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Oluştur'),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              final docRef = await FirebaseFirestore.instance
                  .collection('story_categories')
                  .add({
                'title': title,
                'coverImage': '',
                'items': [],
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => AdminStoryManagePage(
                      categoryId: docRef.id,
                      categoryTitle: title,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final String collection;
  final Color color;
  final String filterField;
  final dynamic filterValue;
  final VoidCallback onTap;

  const _BadgeIcon({
    required this.icon,
    required this.collection,
    required this.color,
    required this.filterField,
    required this.filterValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(filterField, isEqualTo: filterValue)
          .limit(99)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(icon, color: color, size: 22),
              onPressed: onTap,
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yönetici Bildirimleri Alt Çekmecesi (Modal Sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminNotificationsSheet extends StatelessWidget {
  final VoidCallback onGoToPhoneVerification;

  const _AdminNotificationsSheet({
    required this.onGoToPhoneVerification,
  });

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['seen'] != true) {
        batch.update(doc.reference, {'seen': true});
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Çekme kolu
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Başlık ve Eylemler
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin_notifications_log')
                .limit(60)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final unreadCount = docs.where((d) {
                final m = d.data() as Map<String, dynamic>;
                return m['seen'] != true;
              }).length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.bell_fill,
                              color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yönetici Bildirimleri',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.black87),
                              ),
                              Text(
                                unreadCount > 0
                                    ? '$unreadCount yeni okunmamış bildirim'
                                    : 'Tüm bildirimler okundu',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: unreadCount > 0
                                        ? Colors.orange.shade800
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          TextButton.icon(
                            onPressed: () => _markAllAsRead(docs),
                            icon: const Icon(CupertinoIcons.checkmark_circle,
                                size: 14),
                            label: const Text('Tümünü Oku',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            },
          ),

          // Bildirim Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admin_notifications_log')
                  .limit(60)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Bildirimler yüklenemedi: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.bell_slash,
                            size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Henüz bir bildirim bulunmuyor.',
                            style: TextStyle(
                                color: Colors.black45,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                // Bellek içinde tarihe göre sıralama
                final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                sortedDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTs = aData['createdAt'] ?? aData['timestamp'];
                  final bTs = bData['createdAt'] ?? bData['timestamp'];
                  DateTime aTime = aTs is Timestamp ? aTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  DateTime bTime = bTs is Timestamp ? bTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: sortedDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSeen = data['seen'] == true;
                    final title = (data['title'] ?? 'Yeni Bildirim').toString();
                    final body = (data['body'] ?? '').toString();
                    final type = (data['type'] ?? 'general').toString();
                    final isPhoneReq = type == 'phone_verification_request' ||
                        title.contains('Tel Doğrulama') ||
                        title.contains('SMS Doğrulama');

                    final ts = data['createdAt'] ?? data['timestamp'];
                    DateTime? dt;
                    if (ts is Timestamp) dt = ts.toDate();
                    if (ts is int) dt = DateTime.fromMillisecondsSinceEpoch(ts);
                    final timeStr = dt != null
                        ? '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                        : '';

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        if (!isSeen) {
                          await doc.reference.update({'seen': true});
                        }
                        if (isPhoneReq) {
                          onGoToPhoneVerification();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSeen
                              ? Colors.white
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSeen
                                ? Colors.grey.shade200
                                : Colors.amber.shade300,
                            width: isSeen ? 1 : 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (!isSeen)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isSeen
                                          ? FontWeight.w700
                                          : FontWeight.w900,
                                      fontSize: 14,
                                      color: isSeen
                                          ? Colors.black87
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                if (timeStr.isNotEmpty)
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black45,
                                        fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSeen
                                      ? Colors.black54
                                      : const Color(0xFF78350F),
                                  height: 1.3,
                                ),
                              ),
                            ],
                            if (isPhoneReq) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await doc.reference.update({'seen': true});
                                    onGoToPhoneVerification();
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(CupertinoIcons.phone_fill,
                                      size: 13),
                                  label: const Text('Talebi İncele & Onayla',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
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
