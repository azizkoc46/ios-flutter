// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_notification_service.dart';

/// Bu dosyayı BusinessAddPage'de işletme eklenirken de çağırın:
///
///   await AdminNotificationService.instance.notifyAdmin(
///     title: '🏢 Yeni İşletme Başvurusu',
///     body: businessName,
///     type: AdminNotifType.businessApply,
///     docId: docRef.id,
///   );

class AdminPendingCenterTab extends StatelessWidget {
  const AdminPendingCenterTab({Key? key}) : super(key: key);

  static const String usersCollection = 'customers';
  static const String businessesCollection = 'businesses';
  static const String corporateApplicationsCollection =
      'corporate_seller_applications';
  static const String classifiedAdsCollection = 'classified_ads';
  static const String cekGonderCollection = 'cek_gonder_reports';

  Future<void> _approveCorporateSeller(BuildContext context,
      String applicationId, Map<String, dynamic> data) async {
    final uid = (data['uid'] ?? data['userId'] ?? '').toString();
    final categories = data['requestedCategories'] ?? ['Emlak', 'Sıfır Ürün'];

    final batch = FirebaseFirestore.instance.batch();

    batch.update(
      FirebaseFirestore.instance
          .collection(corporateApplicationsCollection)
          .doc(applicationId),
      {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      },
    );

    if (uid.isNotEmpty) {
      batch.set(
        FirebaseFirestore.instance.collection(usersCollection).doc(uid),
        {
          'role': 'kurumsal_satici',
          'isApproved': true,
          'sellerApproved': true,
          'corporateSellerApproved': true,
          'corporateSellerStatus': 'approved',
          'allowedCorporateCategories': categories,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    _toast(context, 'Kurumsal satıcı onaylandı.', Colors.green);
  }

  Future<void> _rejectCorporateSeller(BuildContext context,
      String applicationId, Map<String, dynamic> data) async {
    final uid = (data['uid'] ?? data['userId'] ?? '').toString();

    final batch = FirebaseFirestore.instance.batch();

    batch.update(
      FirebaseFirestore.instance
          .collection(corporateApplicationsCollection)
          .doc(applicationId),
      {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      },
    );

    if (uid.isNotEmpty) {
      batch.set(
        FirebaseFirestore.instance.collection(usersCollection).doc(uid),
        {
          'role': 'customer',
          'isApproved': false,
          'sellerApproved': false,
          'corporateSellerApproved': false,
          'corporateSellerStatus': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    _toast(context, 'Başvuru reddedildi.', Colors.orange);
  }

  Future<void> _updateDocStatus(
    BuildContext context,
    String collection,
    String docId,
    String status,
  ) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _toast(context, 'Durum güncellendi: $status', Colors.green);
  }

  void _toast(BuildContext context, String msg, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Bekleyen İşlemler',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Onay bekleyen başvurular, ilanlar ve içerikler burada toplanır.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          _buildCorporateApplications(context),
          _buildBusinessApplications(context),
          _buildPendingAds(context),
          _buildCekGonderReports(context),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCorporateApplications(BuildContext context) {
    return _SectionCard(
      title: 'Kurumsal Satıcı Başvuruları',
      icon: CupertinoIcons.checkmark_shield_fill,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(corporateApplicationsCollection)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (ctx, snapshot) {
          return _buildSnapshotList(
            ctx,
            snapshot,
            emptyText: 'Bekleyen kurumsal satıcı başvurusu yok.',
            itemBuilder: (doc, data) {
              final title = _pick(
                  data,
                  [
                    'businessName',
                    'storeName',
                    'companyName',
                    'applicantName',
                    'fullName'
                  ],
                  fallback: 'Başvuru');
              final subtitle = _pick(data, ['phone', 'phoneNumber', 'taxId']);

              return _PendingTile(
                title: title,
                subtitle: subtitle,
                badge: 'Kurumsal',
                onApprove: () => _approveCorporateSeller(ctx, doc.id, data),
                onReject: () => _rejectCorporateSeller(ctx, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBusinessApplications(BuildContext context) {
    return _SectionCard(
      title: 'İşletme / Kurum Başvuruları',
      icon: CupertinoIcons.building_2_fill,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(businessesCollection)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (ctx, snapshot) {
          return _buildSnapshotList(
            ctx,
            snapshot,
            emptyText: 'Bekleyen işletme başvurusu yok.',
            itemBuilder: (doc, data) {
              final title = _pick(data, ['name', 'businessName', 'title'],
                  fallback: 'İşletme');
              final subtitle = _pick(data, ['category', 'address', 'phone']);

              return _PendingTile(
                title: title,
                subtitle: subtitle,
                badge: data['type']?.toString() ?? 'İşletme',
                onApprove: () => _updateDocStatus(
                    ctx, businessesCollection, doc.id, 'approved'),
                onReject: () => _updateDocStatus(
                    ctx, businessesCollection, doc.id, 'rejected'),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingAds(BuildContext context) {
    return _SectionCard(
      title: 'Bekleyen İlanlar',
      icon: CupertinoIcons.doc_text_fill,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(classifiedAdsCollection)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (ctx, snapshot) {
          return _buildSnapshotList(
            ctx,
            snapshot,
            emptyText: 'Onay bekleyen ilan yok.',
            itemBuilder: (doc, data) {
              final title = _pick(data, ['title'], fallback: 'İlan');
              final subtitle =
                  '${data['category'] ?? '-'} / ${data['price'] ?? 0} TL';

              return _PendingTile(
                title: title,
                subtitle: subtitle,
                badge: 'İlan',
                onApprove: () => _updateDocStatus(
                    ctx, classifiedAdsCollection, doc.id, 'active'),
                onReject: () => _updateDocStatus(
                    ctx, classifiedAdsCollection, doc.id, 'rejected'),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCekGonderReports(BuildContext context) {
    return _SectionCard(
      title: 'Çek Gönder Bildirimleri',
      icon: CupertinoIcons.camera_fill,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(cekGonderCollection)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (ctx, snapshot) {
          return _buildSnapshotList(
            ctx,
            snapshot,
            emptyText: 'Bekleyen Çek Gönder kaydı yok.',
            itemBuilder: (doc, data) {
              final title = _pick(data, ['title', 'subject', 'category'],
                  fallback: 'Çek Gönder');
              final subtitle =
                  _pick(data, ['description', 'address', 'userName']);

              return _PendingTile(
                title: title,
                subtitle: subtitle,
                badge: 'Talep',
                onApprove: () => _updateDocStatus(
                    ctx, cekGonderCollection, doc.id, 'reviewed'),
                onReject: () => _updateDocStatus(
                    ctx, cekGonderCollection, doc.id, 'rejected'),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSnapshotList(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> snapshot, {
    required String emptyText,
    required Widget Function(
            QueryDocumentSnapshot doc, Map<String, dynamic> data)
        itemBuilder,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Hata: ${snapshot.error}'),
      );
    }

    final docs = snapshot.data?.docs ?? [];

    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_circle_fill,
                color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Text(emptyText, style: const TextStyle(color: Colors.black45)),
          ],
        ),
      );
    }

    return Column(
      children: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return itemBuilder(doc, data);
      }).toList(),
    );
  }

  String _pick(Map<String, dynamic> data, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Onayla'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
