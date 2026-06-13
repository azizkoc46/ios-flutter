// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'admin_notification_service.dart';

/// Kullanıcı tarafında gösterilecek telefon numarası doğrulama sayfası.
///
/// Kullanıcı telefon numarasını girer (ve opsiyonel kimlik fotoğrafı yükler),
/// admin panelinden onay verilince doğrulanır.
///
/// Kullanım: Bu sayfayı profil/ayarlar akışında çağırın.
///   Navigator.push(context, CupertinoPageRoute(
///     builder: (_) => const PhoneVerificationRequestPage()));
class PhoneVerificationRequestPage extends StatefulWidget {
  const PhoneVerificationRequestPage({Key? key}) : super(key: key);

  @override
  State<PhoneVerificationRequestPage> createState() =>
      _PhoneVerificationRequestPageState();
}

class _PhoneVerificationRequestPageState
    extends State<PhoneVerificationRequestPage> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;
  String? _existingStatus;

  @override
  void initState() {
    super.initState();
    _loadExisting();
    _prefillUser();
  }

  Future<void> _prefillUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _nameCtrl.text =
        (data['fullName'] ?? data['fullname'] ?? data['displayName'] ?? '')
            .toString();
    _phoneCtrl.text = (data['phoneNumber'] ?? data['phone'] ?? '').toString();
    setState(() {});
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('phone_verification_requests')
        .where('uid', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      setState(() {
        _existingStatus = snap.docs.first.data()['status']?.toString();
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (phone.isEmpty || name.isEmpty) {
      _snack('Lütfen tüm alanları doldurun.', Colors.red);
      return;
    }

    // Basit Türkiye telefon formatı kontrolü
    final cleanPhone = phone.replaceAll(' ', '').replaceAll('-', '');
    if (!RegExp(r'^(\+90|0)?[0-9]{10}$').hasMatch(cleanPhone)) {
      _snack(
          'Geçerli bir Türkiye telefon numarası girin. (Örn: 05xx xxx xx xx)',
          Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final docRef = await FirebaseFirestore.instance
          .collection('phone_verification_requests')
          .add({
        'uid': uid,
        'phoneNumber': cleanPhone,
        'fullName': name,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Admin'e bildirim gönder
      await AdminNotificationService.instance.notifyAdmin(
        title: '📱 Yeni Tel. Doğrulama Talebi',
        body: '$name — $cleanPhone',
        type: AdminNotifType.general,
        docId: docRef.id,
        extra: {'phoneNumber': cleanPhone, 'uid': uid},
      );

      setState(() {
        _submitted = true;
        _existingStatus = 'pending';
      });
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Telefon Doğrulama',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: const CupertinoNavigationBarBackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // ── Durum göstergesi ────────────────────────────────────────────
          if (_existingStatus != null) _StatusBanner(_existingStatus!),
          const SizedBox(height: 20),
          // ── Bilgi kartı ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF6366F1).withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.info_circle_fill,
                    color: Color(0xFF6366F1), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Telefon Numarası Neden Doğrulanır?',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 13)),
                        SizedBox(height: 6),
                        Text(
                          '• Hesabınızın güvenliğini artırır\n'
                          '• Esnaf ve satıcı başvurularında zorunludur\n'
                          '• Yönetici 24 saat içinde onaylar\n'
                          '• Onay sonrası bildirim alırsınız',
                          style: TextStyle(
                              color: Colors.black54, fontSize: 12, height: 1.6),
                        ),
                      ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ── Form ────────────────────────────────────────────────────────
          if (_existingStatus != 'approved' &&
              _existingStatus != 'pending') ...[
            _label('Ad Soyad'),
            const SizedBox(height: 8),
            _field(_nameCtrl, 'Adınız ve soyadınız',
                keyboardType: TextInputType.name),
            const SizedBox(height: 16),
            _label('Telefon Numarası'),
            const SizedBox(height: 8),
            _field(_phoneCtrl, '05xx xxx xx xx',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text(
                        'DOĞRULAMA TALEBİ GÖNDER',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14),
                      ),
              ),
            ),
          ],
          // ── Mevcut talep geçmişi ─────────────────────────────────────
          const SizedBox(height: 32),
          _RequestHistory(),
        ]),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Durum banner
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner(this.status);

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String title, String sub) =
        switch (status) {
      'approved' => (
          Colors.green,
          CupertinoIcons.checkmark_shield_fill,
          'Telefon Numaranız Doğrulandı ✅',
          'Hesabınıza telefon numarası başarıyla eklendi.',
        ),
      'rejected' => (
          Colors.red,
          CupertinoIcons.xmark_shield_fill,
          'Talep Reddedildi',
          'Bilgilerinizi kontrol ederek yeniden gönderebilirsiniz.',
        ),
      'pending' => (
          Colors.orange,
          CupertinoIcons.clock_fill,
          'Talebiniz İnceleniyor ⏳',
          'Yönetici en kısa sürede inceleyecektir.',
        ),
      _ => (
          Colors.blueGrey,
          CupertinoIcons.info_circle_fill,
          'Durum: $status',
          '',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: color, fontSize: 14)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(sub,
                  style:
                      TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Talep geçmişi
// ─────────────────────────────────────────────────────────────────────────────
class _RequestHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('phone_verification_requests')
          .where('uid', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Talep Geçmişi',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black45,
                    fontSize: 12,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...snap.data!.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final status = d['status']?.toString() ?? 'pending';
              final phone = d['phoneNumber']?.toString() ?? '-';
              final Timestamp? ts = d['submittedAt'] as Timestamp?;
              final note = d['adminNote']?.toString() ?? '';
              final dateStr = ts != null
                  ? '${ts.toDate().day}.${ts.toDate().month}.${ts.toDate().year}'
                  : '';
              final Color color = switch (status) {
                'approved' => Colors.green,
                'rejected' => Colors.red,
                _ => Colors.orange,
              };
              final String label = switch (status) {
                'approved' => 'Onaylandı',
                'rejected' => 'Reddedildi',
                _ => 'Bekliyor',
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.07)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(phone,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('$label • $dateStr',
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Not: $note',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ],
                    ]),
              );
            }),
          ],
        );
      },
    );
  }
}
