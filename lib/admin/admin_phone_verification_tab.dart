import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Telefon Numarası Doğrulama Yönetim Sekmesi
///
/// Firestore yapısı:
///   phone_verification_requests/{docId} = {
///     uid, phoneNumber, fullName, email, status (pending|approved|rejected|cancelled),
///     submittedAt, reviewedAt, reviewedBy, adminNote, issueReason, errorDetails,
///     idImageUrl (opsiyonel), selfieUrl (opsiyonel)
///   }
///
///   customers/{uid} = { phoneVerified: true/false, phone: phoneNumber, ... }
class AdminPhoneVerificationTab extends StatefulWidget {
  const AdminPhoneVerificationTab({Key? key}) : super(key: key);

  @override
  State<AdminPhoneVerificationTab> createState() =>
      _AdminPhoneVerificationTabState();
}

class _AdminPhoneVerificationTabState extends State<AdminPhoneVerificationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _col = 'phone_verification_requests';
  static const _usersCol = 'customers';

  String _filter = 'pending';
  String _search = '';

  final Map<String, String> _filters = const {
    'pending': 'Bekleyenler',
    'approved': 'Onaylananlar',
    'rejected': 'Reddedilenler',
    'all': 'Tümü',
  };

  // ── Onayla ────────────────────────────────────────────────────────────────
  Future<void> _approve(String docId, String uid, String phone) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        FirebaseFirestore.instance.collection(_col).doc(docId),
        {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'admin',
        },
        SetOptions(merge: true),
      );

      if (uid.isNotEmpty) {
        batch.set(
          FirebaseFirestore.instance.collection(_usersCol).doc(uid),
          {
            'phoneVerified': true,
            'isPhoneVerified': true,
            'phone': phone,
            'phoneNumber': phone,
            'phoneVerifiedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // İlgili admin bildirim loglarını okundu yap
      _markNotificationSeen(docId);

      _snack('$phone onaylandı ve kullanıcı hesabı doğrulandı ✅', Colors.green);

      // Kullanıcıya hem push hem uygulama içi bildirim gönder
      if (uid.isNotEmpty) {
        await _sendUserNotification(
          uid: uid,
          title: 'Telefon Numaranız Onaylandı ✅',
          body: 'Hesabınızdaki $phone numarası başarıyla doğrulandı.',
        );
      }
    } catch (e) {
      _snack('Onaylama sırasında hata: $e', Colors.red);
    }
  }

  // ── Reddet ────────────────────────────────────────────────────────────────
  Future<void> _reject(String docId, String uid, String note) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        FirebaseFirestore.instance.collection(_col).doc(docId),
        {
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'adminNote': note,
        },
        SetOptions(merge: true),
      );

      if (uid.isNotEmpty) {
        batch.set(
          FirebaseFirestore.instance.collection(_usersCol).doc(uid),
          {
            'phoneVerified': false,
            'isPhoneVerified': false,
            'phoneVerificationRejectedAt': FieldValue.serverTimestamp(),
            'phoneVerificationNote': note,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      _markNotificationSeen(docId);

      _snack('Talep reddedildi.', Colors.orange);

      if (uid.isNotEmpty) {
        await _sendUserNotification(
          uid: uid,
          title: 'Telefon Doğrulama Reddedildi',
          body: note.isNotEmpty ? note : 'Lütfen bilgilerinizi kontrol ediniz.',
        );
      }
    } catch (e) {
      _snack('Reddetme sırasında hata: $e', Colors.red);
    }
  }

  // ── Bildirim günlüğü 'seen' yap ───────────────────────────────────────────
  Future<void> _markNotificationSeen(String docId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('admin_notifications_log')
          .where('docId', isEqualTo: docId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'seen': true});
      }
    } catch (_) {}
  }

  // ── Kullanıcı FCM ve Uygulama İçi Bildirimi ──────────────────────────────
  Future<void> _sendUserNotification({
    required String uid,
    required String title,
    required String body,
  }) async {
    if (uid.isEmpty) return;
    try {
      // 1. Push kuyruğu
      await FirebaseFirestore.instance
          .collection('user_notification_requests')
          .add({
        'targetUid': uid,
        'title': title,
        'body': body,
        'type': 'phone_verification',
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Uygulama içi bildirim listesi
      await FirebaseFirestore.instance.collection('app_notifications').add({
        'uid': uid,
        'userId': uid,
        'title': title,
        'body': body,
        'type': 'phone_verification',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── Reddetme dialog ───────────────────────────────────────────────────────
  Future<void> _showRejectDialog(String docId, String uid, String phone) async {
    final noteCtrl = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Talebi Reddet'),
        content: Column(children: [
          const SizedBox(height: 8),
          Text('$phone numaralı doğrulama talebini reddetmek istediğinize emin misiniz?'),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: noteCtrl,
            placeholder: 'Kullanıcıya iletilecek gerekçe (opsiyonel)',
            maxLines: 3,
          ),
        ]),
        actions: [
          CupertinoDialogAction(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reddet'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _reject(docId, uid, noteCtrl.text.trim());
    }
  }

  // ── Manuel Doğrulama Dialog ──────────────────────────────────────────────
  Future<void> _manualVerify(
      BuildContext context, String docId, String uid, String phone) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Manuel Doğrulama'),
        content: Text('$phone numarası manuel olarak onaylanacak ve kullanıcı profiline kaydedilecek.\n\nDevam edilsin mi?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Doğrula ve Onayla'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) await _approve(docId, uid, phone);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // DİKKAT: Composite index ihtiyacını ve Web'deki çökme/kaybolma
    // sorunlarını önlemek için Firestore'dan düz koleksiyon alıp
    // filtreleme ve sıralamayı doğrudan Dart içinde güvenli yapıyoruz.
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(_col)
            .limit(300)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                        color: Colors.orange, size: 52),
                    const SizedBox(height: 12),
                    const Text('Talepler yüklenirken hata oluştu',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(CupertinoIcons.refresh, size: 16),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator(radius: 14));
          }

          final allDocs = snapshot.data!.docs;

          // İstatistik sayıları (tüm belgeler üzerinden anlık hesaplanır)
          int pendingCount = 0;
          int approvedCount = 0;
          int rejectedCount = 0;

          for (final doc in allDocs) {
            final d = doc.data() as Map<String, dynamic>;
            final st = (d['status'] ?? 'pending').toString().toLowerCase().trim();
            if (st == 'approved') {
              approvedCount++;
            } else if (st == 'rejected') {
              rejectedCount++;
            } else {
              pendingCount++;
            }
          }

          // Filtreleme
          var docs = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final st = (d['status'] ?? 'pending').toString().toLowerCase().trim();
            if (_filter == 'all') return true;
            if (_filter == 'pending') return st != 'approved' && st != 'rejected';
            return st == _filter;
          }).toList();

          // Arama
          if (_search.isNotEmpty) {
            docs = docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final text = '${d['fullName'] ?? ''} ${d['phoneNumber'] ?? ''} ${d['email'] ?? ''} ${d['uid'] ?? ''} ${d['issueReason'] ?? ''} ${d['errorDetails'] ?? ''}'
                  .toLowerCase();
              return text.contains(_search);
            }).toList();
          }

          // Bellek içinde tarihe göre sıralama (Yeniden eskiye)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            DateTime getTime(Map<String, dynamic> d) {
              final ts = d['submittedAt'] ?? d['createdAt'] ?? d['reviewedAt'];
              if (ts is Timestamp) return ts.toDate();
              if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
              if (ts is String) return DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
              return DateTime.fromMillisecondsSinceEpoch(0);
            }
            return getTime(bData).compareTo(getTime(aData));
          });

          return Column(
            children: [
              // ── Header İstatistik Kutuları ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Bekliyor',
                      count: pendingCount,
                      color: Colors.orange,
                      icon: CupertinoIcons.clock_fill,
                      active: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Onaylandı',
                      count: approvedCount,
                      color: Colors.green,
                      icon: CupertinoIcons.checkmark_shield_fill,
                      active: _filter == 'approved',
                      onTap: () => setState(() => _filter = 'approved'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Reddedildi',
                      count: rejectedCount,
                      color: Colors.red,
                      icon: CupertinoIcons.xmark_shield_fill,
                      active: _filter == 'rejected',
                      onTap: () => setState(() => _filter = 'rejected'),
                    ),
                  ),
                ]),
              ),

              // ── Arama Çubuğu ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: CupertinoSearchTextField(
                  placeholder: 'İsim, telefon, e-posta veya sorun ara...',
                  onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
                ),
              ),

              // ── Filtre Chips ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.entries.map((e) {
                      final selected = _filter == e.key;
                      final countBadge = switch (e.key) {
                        'pending' => pendingCount,
                        'approved' => approvedCount,
                        'rejected' => rejectedCount,
                        _ => allDocs.length,
                      };
                      return GestureDetector(
                        onTap: () => setState(() => _filter = e.key),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF6366F1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: selected
                                    ? const Color(0xFF6366F1)
                                    : Colors.black.withOpacity(0.08)),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color: const Color(0xFF6366F1)
                                            .withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.value,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withOpacity(0.25)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('$countBadge',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: selected
                                            ? Colors.white
                                            : Colors.black54)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Liste ──
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.phone_badge_plus,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _search.isNotEmpty
                                  ? 'Aramaya uygun kayıt bulunamadı.'
                                  : (_filter == 'pending'
                                      ? 'Onay bekleyen talep yok 🎉'
                                      : 'Bu kategoride kayıt bulunmuyor.'),
                              style: const TextStyle(
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _RequestCard(
                            docId: doc.id,
                            data: data,
                            onApprove: () => _approve(
                              doc.id,
                              (data['uid'] ?? '').toString(),
                              (data['phoneNumber'] ?? '').toString(),
                            ),
                            onReject: () => _showRejectDialog(
                              doc.id,
                              (data['uid'] ?? '').toString(),
                              (data['phoneNumber'] ?? '').toString(),
                            ),
                            onManual: () => _manualVerify(
                              context,
                              doc.id,
                              (data['uid'] ?? '').toString(),
                              (data['phoneNumber'] ?? '').toString(),
                            ),
                            onCopyPhone: (phone) {
                              Clipboard.setData(ClipboardData(text: phone));
                              _snack('$phone kopyalandı 📋', Colors.blueGrey);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.14) : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color : color.withOpacity(0.15),
              width: active ? 1.8 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 17, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.85),
                    fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Doğrulama Talep Kartı
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onManual;
  final ValueChanged<String> onCopyPhone;

  const _RequestCard({
    required this.docId,
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.onManual,
    required this.onCopyPhone,
  });

  Color _statusColor(String s) => switch (s.toLowerCase().trim()) {
        'approved' => Colors.green,
        'rejected' => Colors.red,
        'cancelled' => Colors.blueGrey,
        _ => Colors.orange,
      };

  String _statusLabel(String s) => switch (s.toLowerCase().trim()) {
        'approved' => 'Onaylandı',
        'rejected' => 'Reddedildi',
        'cancelled' => 'İptal',
        _ => 'Onay Bekliyor',
      };

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase().trim();
    final phone = (data['phoneNumber'] ?? data['phone'] ?? '-').toString();
    final fullName = (data['fullName'] ?? data['name'] ?? 'Bilinmeyen Kullanıcı').toString();
    final uid = (data['uid'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final country = (data['country'] ?? '').toString();
    final issueReason = (data['issueReason'] ?? '').toString();
    final errorDetails = (data['errorDetails'] ?? '').toString();
    final idImageUrl = (data['idImageUrl'] ?? '').toString();
    final selfieUrl = (data['selfieUrl'] ?? '').toString();
    final adminNote = (data['adminNote'] ?? '').toString();

    final ts = data['submittedAt'] ?? data['createdAt'] ?? data['reviewedAt'];
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();
    if (ts is int) dt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) dt = DateTime.tryParse(ts);

    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    final isPending = status != 'approved' && status != 'rejected' && status != 'cancelled';
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.35)
              : Colors.black.withOpacity(0.06),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Başlık Satırı ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPending
                            ? CupertinoIcons.phone_fill
                            : (status == 'approved'
                                ? CupertinoIcons.checkmark_shield_fill
                                : CupertinoIcons.xmark_shield_fill),
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                phone,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B)),
                              ),
                              if (country.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  country,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black45),
                                ),
                              ],
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => onCopyPhone(phone),
                                child: const Icon(CupertinoIcons.doc_on_doc,
                                    size: 14, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _badge(_statusLabel(status), color),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Kullanıcı Bildirimi / Hata Uyarısı ──
                if (issueReason.isNotEmpty || errorDetails.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(CupertinoIcons.exclamationmark_bubble_fill,
                              color: Color(0xFFEA580C), size: 14),
                          SizedBox(width: 6),
                          Text('Kullanıcı Bildirdiği Sorun:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Color(0xFFEA580C))),
                        ]),
                        if (issueReason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(issueReason,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9A3412))),
                        ],
                        if (errorDetails.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text('Hata Kodu: $errorDetails',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFC2410C),
                                  fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ],

                // ── Detaylar Tablosu ──
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    if (uid.isNotEmpty)
                      _row('Kullanıcı ID', uid.length > 14 ? '${uid.substring(0, 14)}...' : uid),
                    if (email.isNotEmpty) _row('E-posta', email),
                    if (dateStr.isNotEmpty) _row('Talep Tarihi', dateStr),
                    if (adminNote.isNotEmpty)
                      _row('Admin Notu', adminNote, valueColor: Colors.red.shade700),
                  ]),
                ),

                // ── Kimlik Görselleri (Varsa) ──
                if (idImageUrl.isNotEmpty || selfieUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (idImageUrl.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showImage(context, idImageUrl, 'Kimlik Belgesi'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(idImageUrl,
                                height: 80, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    if (idImageUrl.isNotEmpty && selfieUrl.isNotEmpty)
                      const SizedBox(width: 8),
                    if (selfieUrl.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showImage(context, selfieUrl, 'Selfie'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(selfieUrl,
                                height: 80, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                  ]),
                ],

                const SizedBox(height: 12),

                // ── Aksiyon Butonları ──
                Row(children: [
                  // WhatsApp Butonu
                  IconButton(
                    icon: const Icon(CupertinoIcons.chat_bubble_fill,
                        color: Color(0xFF25D366), size: 20),
                    tooltip: "WhatsApp'tan Ulaş",
                    onPressed: () async {
                      final clean = phone.replaceAll(RegExp(r'\D'), '');
                      final fullPhone = clean.startsWith('90')
                          ? clean
                          : (clean.startsWith('0') ? '9$clean' : clean);
                      final url = Uri.parse(
                          'https://wa.me/$fullPhone?text=${Uri.encodeComponent('Merhaba $fullName, Pazarcık Portal telefon doğrulama talebiniz için yazıyoruz.')}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),

                  // Arama Butonu
                  IconButton(
                    icon: const Icon(CupertinoIcons.phone_fill,
                        color: Colors.blue, size: 20),
                    tooltip: 'Numarayı Ara',
                    onPressed: () async {
                      final clean = phone.replaceAll(' ', '');
                      final url = Uri.parse('tel:$clean');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),

                  const Spacer(),

                  if (isPending) ...[
                    // Reddet Butonu
                    OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(CupertinoIcons.xmark_circle, size: 15),
                      label: const Text('Reddet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),

                    // Onayla Butonu
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(CupertinoIcons.checkmark_shield_fill, size: 16),
                      label: const Text('Onayla',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  ],

                  if (!isPending) ...[
                    OutlinedButton.icon(
                      onPressed: onManual,
                      icon: const Icon(CupertinoIcons.pencil, size: 14),
                      label: const Text('Durumu Değiştir', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImage(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.black87)),
        ),
      ]),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
