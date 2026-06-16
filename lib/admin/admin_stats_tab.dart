// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'CommentManagementPage.dart';
import 'sikayet.dart';
import 'admin_notification_sender_page.dart';
import 'admin_pending_center_tab.dart'; // BEKLEYENLER SAYFASI BURAYA EKLENDİ

class AdminStatsTab extends StatelessWidget {
  final Color primaryColor = const Color(0xFF6366F1);
  final Color successColor = const Color(0xFF22C55E);
  final Color businessColor = const Color(0xFF004D40);
  final Color publicColor = const Color(0xFFD32F2F);
  final Color emlakciColor = const Color(0xFF0284C7);
  final Color storyColor = Colors.purple;
  final Color warningColor = const Color(0xFFF59E0B);

  const AdminStatsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Canlı uyarı kutuları ─────────────────────────────────────────
          _AlertsRow(),
          const SizedBox(height: 20),
          const Text("Sistem Özeti",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1.5,
            children: [
              _statBox(context, "Toplam Kullanıcı", "customers", Icons.people,
                  primaryColor),
              _statBox(context, "Aktif Esnaf", "customers", Icons.storefront,
                  successColor,
                  field: "role", value: "satici"),
              _statBox(context, "Onaylı Emlakçı", "customers",
                  Icons.real_estate_agent, emlakciColor,
                  field: "role", value: "emlakci"),
              _statBox(context, "Öne Çıkanlar", "story_categories",
                  Icons.play_circle_fill, storyColor),
              _statBox(context, "Özel İşletme", "businesses",
                  Icons.business_center, businessColor,
                  field: "type", value: "private"),
              _statBox(context, "Kamu Kurumu", "businesses",
                  Icons.account_balance, publicColor,
                  field: "type", value: "public"),
              _statBox(context, "Gelen Talepler", "complaints",
                  Icons.message_rounded, Colors.orange,
                  field: "status", value: "pending"),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Hızlı İşlemler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildNotificationButton(context),
          const SizedBox(height: 8),
          _buildCommentButton(context),
          const SizedBox(height: 8),
          _buildComplaintButton(context),
          const SizedBox(height: 24),
          const Text("Bekleyen Görevler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // ARTIK BU KUTULARA TIKLAYINCA "BEKLEYENLER" SAYFASI AÇILIYOR
          _pendingTile("Onay Bekleyen Emlakçı", "customers", Icons.home_work,
              warningColor,
              field: "role",
              value: "emlakci_pending",
              onTap: () => _openPending(context)),
          _pendingTile("Onay Bekleyen İşletme", "businesses",
              Icons.hourglass_empty, warningColor,
              field: "status",
              value: "pending",
              onTap: () => _openPending(context)),
          _pendingTile(
              "Onay Bekleyen Esnaf", "customers", Icons.store, warningColor,
              field: "role",
              value: "vendor_pending",
              onTap: () => _openPending(context)),
        ],
      ),
    );
  }

  void _openPending(BuildContext context) {
    Navigator.push(context,
        CupertinoPageRoute(builder: (_) => const AdminPendingCenterTab()));
  }

  Widget _statBox(BuildContext context, String title, String coll, dynamic icon,
      Color color,
      {String? field, dynamic value}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(coll).snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          if (field != null) {
            count = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data != null &&
                  data.containsKey(field) &&
                  data[field] == value;
            }).length;
          } else {
            count = snapshot.data!.docs.length;
          }
        }
        return GestureDetector(
          onTap: () {
            if (title == "Gelen Talepler") {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SikayetYonetimPage()));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon is IconData ? icon : Icons.info,
                    color: color, size: 28),
                const SizedBox(height: 5),
                Text(count.toString(),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(title,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return _QuickActionTile(
      icon: CupertinoIcons.paperplane_fill,
      iconColor: Colors.orange,
      title: "Kullanıcılara Bildirim Gönder",
      subtitle: "Duyuru veya Link oluşturun",
      onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
              builder: (_) => const AdminNotificationSenderPage())),
    );
  }

  Widget _buildCommentButton(BuildContext context) {
    return _QuickActionTile(
      icon: CupertinoIcons.chat_bubble_2_fill,
      iconColor: Colors.purple,
      title: "Yorum Yönetimi",
      subtitle: "İşletme yorumlarını incele ve sil",
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CommentManagementPage())),
    );
  }

  Widget _buildComplaintButton(BuildContext context) {
    return _QuickActionTile(
      icon: CupertinoIcons.exclamationmark_bubble_fill,
      iconColor: Colors.red,
      title: "Şikayet ve Talepler",
      subtitle: "Kullanıcı şikayetlerini yönet",
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SikayetYonetimPage())),
    );
  }

  // TIKLANABİLİR BEKLEYEN GÖREVLER
  Widget _pendingTile(String t, String c, dynamic i, Color col,
      {String? field, dynamic value, VoidCallback? onTap}) {
    return StreamBuilder<QuerySnapshot>(
      stream: (() {
        var q = FirebaseFirestore.instance.collection(c);
        if (field != null && value != null) {
          return q.where(field, isEqualTo: value).limit(99).snapshots();
        }
        return q.limit(99).snapshots();
      })(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: onTap, // TIKLAMA BURAYA EKLENDİ
            leading: Icon(i is IconData ? i : Icons.info, color: col),
            title: Text(t),
            trailing: count > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
                  )
                : const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _AlertsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, compSnap) {
        final compPending = compSnap.data?.docs.length ?? 0;
        if (compPending == 0) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(CupertinoIcons.checkmark_circle_fill,
                  color: Colors.green, size: 18),
              SizedBox(width: 10),
              Text('Bekleyen kritik şikayet yok 🎉',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.green)),
            ]),
          );
        }
        return Column(children: [
          _AlertCard(
            icon: CupertinoIcons.exclamationmark_bubble_fill,
            color: Colors.red,
            text: '$compPending bekleyen şikayet / talep',
          ),
        ]);
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _AlertCard(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor),
          ),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
