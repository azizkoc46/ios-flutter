// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_notification_service.dart';

/// Telefon Numarası Doğrulama Yönetim Sekmesi
///
/// Firestore yapısı:
///   phone_verification_requests/{docId} = {
///     uid, phoneNumber, fullName, status (pending|approved|rejected|cancelled),
///     submittedAt, reviewedAt, reviewedBy, adminNote,
///     idImageUrl (opsiyonel), selfieUrl (opsiyonel)
///   }
///
///   customers/{uid} = { phoneVerified: true/false, phoneVerifiedAt, phoneNumber }
///
/// Kullanıcı tarafında (örnek kayıt kodu):
///   await FirebaseFirestore.instance.collection('phone_verification_requests').add({
///     'uid': FirebaseAuth.instance.currentUser!.uid,
///     'phoneNumber': '+90...',
///     'fullName': '...',
///     'status': 'pending',
///     'submittedAt': FieldValue.serverTimestamp(),
///   });

class AdminPhoneVerificationTab extends StatefulWidget {
  const AdminPhoneVerificationTab({Key? key}) : super(key: key);

  @override
  State<AdminPhoneVerificationTab> createState() =>
      _AdminPhoneVerificationTabState();
}

class _AdminPhoneVerificationTabState extends State<AdminPhoneVerificationTab> {
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
          'phoneNumber': phone,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Kullanıcıya bildirim
      await AdminNotificationService.instance.notifyAdmin(
        title: '✅ Tel. Onaylandı',
        body: '$phone numarası doğrulandı.',
        type: AdminNotifType.general,
        docId: docId,
      );
    }

    await batch.commit();
    _snack('Telefon numarası onaylandı ✅', Colors.green);

    // Kullanıcıya FCM push (tokens varsa)
    await _sendUserNotification(
      uid: uid,
      title: 'Telefon Numaranız Onaylandı ✅',
      body: 'Hesabınızdaki $phone numarası başarıyla doğrulandı.',
    );
  }

  // ── Reddet ────────────────────────────────────────────────────────────────
  Future<void> _reject(String docId, String uid, String note) async {
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
          'phoneVerificationRejectedAt': FieldValue.serverTimestamp(),
          'phoneVerificationNote': note,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    _snack('Talep reddedildi.', Colors.orange);

    await _sendUserNotification(
      uid: uid,
      title: 'Telefon Doğrulama Reddedildi',
      body: note.isNotEmpty ? note : 'Lütfen bilgilerinizi kontrol ediniz.',
    );
  }

  // ── Kullanıcı FCM bildirimi ────────────────────────────────────────────────
  Future<void> _sendUserNotification({
    required String uid,
    required String title,
    required String body,
  }) async {
    if (uid.isEmpty) return;
    try {
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
          const Text('Kullanıcıya iletilecek red gerekçesi:'),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: noteCtrl,
            placeholder: 'Gerekçe (opsiyonel)',
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

  // ── Kullanıcı detaylarını güncelle (admin manuel) ─────────────────────────
  Future<void> _manualVerify(
      BuildContext context, String docId, String uid, String phone) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Manuel Doğrulama'),
        content: Text('$phone numarası manuel olarak doğrulanacak.\nDevam?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Onayla'),
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection(_col);
    if (_filter != 'all') {
      query = query.where('status', isEqualTo: _filter);
    }
    query = query.orderBy('submittedAt', descending: true).limit(200);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Header istatistik kutuları ───────────────────────────────────
          _StatsHeader(),
          // ── Arama ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CupertinoSearchTextField(
              placeholder: 'İsim veya telefon numarası ara',
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          // ── Filtre chips ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _filters.entries.map((e) {
                  final selected = _filter == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = e.key),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            selected ? const Color(0xFF6366F1) : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.07)),
                      ),
                      child: Text(e.value,
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // ── Liste ─────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                var docs = snapshot.data!.docs;

                if (_search.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return '${d['fullName'] ?? ''} ${d['phoneNumber'] ?? ''}'
                        .toLowerCase()
                        .contains(_search);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.phone_badge_plus,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 'pending'
                              ? 'Bekleyen talep yok 🎉'
                              : 'Kayıt bulunamadı.',
                          style: const TextStyle(color: Colors.black45),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
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

// ─────────────────────────────────────────────────────────────────────────────
// İstatistik kutuları
// ─────────────────────────────────────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        _StatMini(
          label: 'Bekliyor',
          field: 'status',
          value: 'pending',
          color: Colors.orange,
          icon: CupertinoIcons.clock_fill,
        ),
        const SizedBox(width: 10),
        _StatMini(
          label: 'Onaylı',
          field: 'status',
          value: 'approved',
          color: Colors.green,
          icon: CupertinoIcons.checkmark_shield_fill,
        ),
        const SizedBox(width: 10),
        _StatMini(
          label: 'Reddedildi',
          field: 'status',
          value: 'rejected',
          color: Colors.red,
          icon: CupertinoIcons.xmark_shield_fill,
        ),
      ]),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, field, value;
  final Color color;
  final IconData icon;

  const _StatMini({
    required this.label,
    required this.field,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('phone_verification_requests')
            .where(field, isEqualTo: value)
            .snapshots(),
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.7),
                        fontWeight: FontWeight.w700)),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Doğrulama talep kartı
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onManual;

  const _RequestCard({
    required this.docId,
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.onManual,
  });

  Color _statusColor(String s) => switch (s) {
        'approved' => Colors.green,
        'rejected' => Colors.red,
        'cancelled' => Colors.blueGrey,
        _ => Colors.orange,
      };

  String _statusLabel(String s) => switch (s) {
        'approved' => 'Onaylandı',
        'rejected' => 'Reddedildi',
        'cancelled' => 'İptal',
        _ => 'Bekliyor',
      };

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();
    final phone = (data['phoneNumber'] ?? '-').toString();
    final fullName = (data['fullName'] ?? 'Bilinmiyor').toString();
    final uid = (data['uid'] ?? '').toString();
    final idImageUrl = (data['idImageUrl'] ?? '').toString();
    final selfieUrl = (data['selfieUrl'] ?? '').toString();
    final adminNote = (data['adminNote'] ?? '').toString();

    final Timestamp? ts = data['submittedAt'] as Timestamp?;
    final dateStr = ts != null
        ? '${ts.toDate().day}.${ts.toDate().month}.${ts.toDate().year} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    final color = _statusColor(status);
    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.3)
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
                // ── Başlık satırı ────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(CupertinoIcons.phone_fill, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(phone,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.black54)),
                        ]),
                  ),
                  _badge(_statusLabel(status), color),
                ]),
                const SizedBox(height: 12),
                // ── Detaylar ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    _row('Kullanıcı ID',
                        uid.length > 12 ? '${uid.substring(0, 12)}...' : uid),
                    if (dateStr.isNotEmpty) _row('Talep Tarihi', dateStr),
                    if (adminNote.isNotEmpty)
                      _row('Admin Notu', adminNote,
                          valueColor: Colors.red.shade700),
                  ]),
                ),
                // ── Kimlik görselleri ─────────────────────────────────────
                if (idImageUrl.isNotEmpty || selfieUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    if (idImageUrl.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _showImage(context, idImageUrl, 'Kimlik Belgesi'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(children: [
                              Image.network(idImageUrl,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                              Positioned(
                                bottom: 4,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Kimlik',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                ),
                              ),
                            ]),
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
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(children: [
                              Image.network(selfieUrl,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                              Positioned(
                                bottom: 4,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Selfie',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ],
                // ── Butonlar ─────────────────────────────────────────────
                if (isPending) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        icon: const Icon(CupertinoIcons.xmark_circle, size: 16),
                        label: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0),
                        icon: const Icon(CupertinoIcons.checkmark_shield,
                            size: 16),
                        label: const Text('Onayla'),
                      ),
                    ),
                  ]),
                ],
                if (!isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onManual,
                      icon: const Icon(CupertinoIcons.pencil, size: 15),
                      label: const Text('Manuel Düzelt'),
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
