// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'admin_activity_feed_tab.dart';

/// Gelişmiş Kullanıcı Yönetimi
/// ✅ Telefon doğrulama durumu
/// ✅ Toplu işlem (bulk delete/block/notify)
/// ✅ Gelişmiş detay sayfası
/// ✅ Kullanıcıya doğrudan mesaj gönderme
/// ✅ Login geçmişi gösterme
/// ✅ Kayıt tipi (Google, Apple, Normal) tespiti
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  static const _collection = 'customers';
  static const _functionsBase =
      'https://us-central1-pazarcik-portal-7faf2.cloudfunctions.net';

  String _search = '';
  String _roleFilter = 'all';
  bool _busy = false;

  // Toplu seçim
  final Set<String> _selected = {};
  bool _selectMode = false;

  final Map<String, String> _roles = const {
    'customer': 'Normal Üye',
    'satici': 'Mağaza / Esnaf',
    'kurumsal_satici': 'Kurumsal Satıcı',
    'emlakci': 'Emlakçı',
    'admin': 'Admin',
  };

  // ── Kayıt Yöntemi Çevirici ──────────────────────────────────────────────
  String _authTypeLabel(String type) {
    if (type.contains('google')) return 'Google İle Kayıt';
    if (type.contains('apple') || type.contains('ios'))
      return 'Apple İle Kayıt';
    if (type.contains('phone')) return 'Telefon İle Kayıt';
    if (type.contains('anonymous')) return 'Misafir Girişi';
    return 'Normal (E-Posta) Kayıt';
  }

  Future<Map<String, dynamic>> _callFunction(
      String name, Map<String, dynamic> data) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Yönetici oturumu bulunamadı.');
    final response = await http.post(
      Uri.parse('$_functionsBase/$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': data}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || body['error'] != null) {
      final error = body['error'];
      throw Exception(error is Map ? error['message'] : 'İşlem başarısız.');
    }
    return Map<String, dynamic>.from(body['result'] ?? const {});
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection(_collection).doc(uid).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    _snack('Kullanıcı güncellendi.');
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _name(Map<String, dynamic> user) => (user['fullname'] ??
          user['fullName'] ??
          user['name'] ??
          user['displayName'] ??
          user['businessName'] ??
          'İsimsiz Kullanıcı')
      .toString();

  String _phone(Map<String, dynamic> user) =>
      (user['phoneNumber'] ?? user['phone'] ?? user['gsm'] ?? '').toString();

  DateTime _createdAt(Map<String, dynamic> user) {
    final value = user['createdAt'] ?? user['registrationDate'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ── Toplu işlemler ────────────────────────────────────────────────────────
  Future<void> _bulkBlock() async {
    if (_selected.isEmpty) return;
    final ok = await _confirm(
      'Toplu Engelle',
      '${_selected.length} kullanıcı engellensin mi?',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final uid in _selected) {
        batch.set(
          FirebaseFirestore.instance.collection(_collection).doc(uid),
          {'isBlocked': true, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      await ActivityLogger.log(
        type: 'user',
        title: '${_selected.length} kullanıcı engellendi',
        body: 'Toplu işlem',
      );
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      _snack('${_selected.length} kullanıcı engellendi.');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final ok = await _confirm(
      'Toplu Sil',
      '${_selected.length} kullanıcı kalıcı silinsin mi? Bu işlem geri alınamaz!',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      for (final uid in _selected) {
        await _callFunction('adminDeleteUser', {'uid': uid});
      }
      await ActivityLogger.log(
        type: 'user',
        title: '${_selected.length} kullanıcı silindi',
        body: 'Toplu işlem',
      );
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      _snack('Kullanıcılar silindi.');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkNotify() async {
    if (_selected.isEmpty) return;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${_selected.length} kullanıcıya bildirim'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Başlık')),
          const SizedBox(height: 8),
          TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mesaj')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gönder')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final uid in _selected) {
        final ref = FirebaseFirestore.instance
            .collection('user_notification_requests')
            .doc();
        batch.set(ref, {
          'targetUid': uid,
          'title': titleCtrl.text.trim(),
          'body': bodyCtrl.text.trim(),
          'type': 'admin_broadcast',
          'status': 'queued',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      _snack('Bildirimler kuyruğa alındı.');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message,
      {bool destructive = false}) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
              child: const Text('Vazgeç'),
              onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(
              isDestructiveAction: destructive,
              child: Text(destructive ? 'Sil' : 'Onayla'),
              onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    return result == true;
  }

  // ── Kullanıcı ekleme ─────────────────────────────────────────────────────
  Future<void> _showAddUser() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    String role = 'customer';
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kullanıcı Ekle'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ad soyad')),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta')),
              TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Geçici şifre (en az 6 karakter)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: _roles.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => role = value ?? role),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Oluştur')),
          ],
        ),
      ),
    );
    if (submit != true) return;
    setState(() => _busy = true);
    try {
      await _callFunction('adminCreateUser', {
        'displayName': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'role': role,
      });
      await ActivityLogger.log(
        type: 'user',
        title: 'Yeni kullanıcı oluşturuldu',
        body: name.text.trim(),
      );
      _snack('Kullanıcı oluşturuldu.');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteUser(String uid, String name) async {
    final confirmed = await _confirm(
      'Kullanıcıyı Sil',
      '$name hesabı kalıcı olarak silinsin mi?',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final result = await _callFunction('adminDeleteUser', {'uid': uid});
      await ActivityLogger.log(
        type: 'user',
        title: 'Kullanıcı silindi',
        body: name,
      );
      final documents = result['deletedDocuments'] ?? 0;
      final files = result['deletedFiles'] ?? 0;
      _snack(
          'Kullanıcı ve bağlı verileri silindi ($documents kayıt, $files dosya).');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Detay sayfası ─────────────────────────────────────────────────────────
  void _openDetails(String uid, Map<String, dynamic> user) {
    final role = (user['role'] ?? 'customer').toString();
    final blocked = user['isBlocked'] == true;
    final approved =
        user['sellerApproved'] == true || user['isApproved'] == true;
    final phoneVerified = user['phoneVerified'] == true;

    // Resim alanı BURADA 'image' öncelikli olarak arandı.
    final photoUrl = (user['image'] ??
            user['photoUrl'] ??
            user['photoURL'] ??
            user['profileImage'] ??
            user['avatar'] ??
            '')
        .toString();
    final authType = (user['auth-type'] ?? user['authType'] ?? 'email')
        .toString()
        .toLowerCase();

    // Son görülme verisi
    final Timestamp? lastActiveTs = user['lastActive'] as Timestamp?;
    final String lastActiveStr = lastActiveTs != null
        ? '${lastActiveTs.toDate().day.toString().padLeft(2, '0')}.${lastActiveTs.toDate().month.toString().padLeft(2, '0')}.${lastActiveTs.toDate().year} - ${lastActiveTs.toDate().hour.toString().padLeft(2, '0')}:${lastActiveTs.toDate().minute.toString().padLeft(2, '0')}'
        : 'Bilinmiyor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: FractionallySizedBox(
          heightFactor: .92,
          child: Column(children: [
            // Tutaç
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(20), children: [
                // ── Avatar + isim ─────────────────────────────────────
                Row(children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: photoUrl.isNotEmpty
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                _name(user).substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF6366F1)),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _name(user).substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6366F1)),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name(user),
                              style: GoogleFonts.inter(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          Text(
                            _roles[role] ?? role,
                            style: const TextStyle(color: Colors.black45),
                          ),
                        ]),
                  ),
                ]),
                const SizedBox(height: 16),
                // ── Durum badge'leri ───────────────────────────────────
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _badge(blocked ? '🔒 Engelli' : '✅ Aktif',
                      blocked ? Colors.red : Colors.green),
                  _badge(approved ? '✅ Onaylı' : '⏳ Onay Bekliyor',
                      approved ? Colors.blue : Colors.orange),
                  _badge(
                      phoneVerified
                          ? '📱 Tel. Doğrulandı'
                          : '📱 Tel. Doğrulanmadı',
                      phoneVerified ? Colors.teal : Colors.blueGrey),
                ]),
                const SizedBox(height: 18),
                // ── Bilgiler ───────────────────────────────────────────
                _sectionTitle('Kişisel Bilgiler'),
                _detail('E-posta', (user['email'] ?? '').toString()),
                _detail('Telefon', _phone(user)),
                _detail('Kayıt Tipi', _authTypeLabel(authType)),
                _detail('Son Görülme', lastActiveStr),
                _detail('Kullanıcı ID', uid),
                _detail(
                    'Mağaza',
                    (user['storeName'] ?? user['businessName'] ?? '')
                        .toString()),
                _detail(
                    'Adres',
                    (user['address'] ?? user['businessAddress'] ?? '')
                        .toString()),
                _detail(
                    'Kayıt Tarihi',
                    _createdAt(user).year > 1970
                        ? '${_createdAt(user).day.toString().padLeft(2, '0')}.${_createdAt(user).month.toString().padLeft(2, '0')}.${_createdAt(user).year}'
                        : 'Bilinmiyor'),
                const SizedBox(height: 16),
                // ── Telefon doğrulama durumu ──────────────────────────
                _sectionTitle('Telefon Doğrulama'),
                _PhoneVerificationStatus(uid: uid),
                const SizedBox(height: 16),
                // ── Rol değiştir ───────────────────────────────────────
                _sectionTitle('Rol & Yetki'),
                DropdownButtonFormField<String>(
                  value: _roles.containsKey(role) ? role : 'customer',
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    Navigator.pop(context);
                    _updateUser(uid, {
                      'role': value,
                      'isApproved': value == 'satici' || value == 'admin',
                      'sellerApproved': value == 'satici',
                    });
                  },
                ),
                const SizedBox(height: 10),
                // ── Hızlı aksiyonlar ──────────────────────────────────
                _sectionTitle('İşlemler'),
                if (role.contains('satici') || role.contains('seller'))
                  _actionTile(
                    icon: approved
                        ? CupertinoIcons.xmark_circle
                        : CupertinoIcons.checkmark_circle,
                    label: approved ? 'Esnaf onayını kaldır' : 'Esnafı onayla',
                    color: approved ? Colors.orange : Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _updateUser(uid, {
                        'isApproved': !approved,
                        'sellerApproved': !approved,
                        'sellerStatus': approved ? 'pending' : 'approved',
                      });
                    },
                  ),
                _actionTile(
                  icon: CupertinoIcons.paperplane_fill,
                  label: 'Bildirim Gönder',
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    Navigator.pop(context);
                    _sendDirectMessage(uid, _name(user));
                  },
                ),
                _actionTile(
                  icon: phoneVerified
                      ? CupertinoIcons.phone_badge_plus
                      : CupertinoIcons.checkmark_shield_fill,
                  label: phoneVerified
                      ? 'Tel. Doğrulamayı Kaldır'
                      : 'Tel. Manuel Onayla',
                  color: phoneVerified ? Colors.orange : Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    _updateUser(uid, {
                      'phoneVerified': !phoneVerified,
                      if (!phoneVerified)
                        'phoneVerifiedAt': FieldValue.serverTimestamp(),
                    });
                  },
                ),
                _actionTile(
                  icon:
                      blocked ? CupertinoIcons.lock_open : CupertinoIcons.lock,
                  label: blocked ? 'Engeli kaldır' : 'Kullanıcıyı engelle',
                  color: blocked ? Colors.green : Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _updateUser(uid, {'isBlocked': !blocked});
                    ActivityLogger.log(
                      type: 'user',
                      title:
                          blocked ? 'Engel kaldırıldı' : 'Kullanıcı engellendi',
                      body: _name(user),
                    );
                  },
                ),
                _actionTile(
                  icon: CupertinoIcons.delete,
                  label: 'Kullanıcıyı kalıcı sil',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteUser(uid, _name(user));
                  },
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Doğrudan mesaj gönderme ───────────────────────────────────────────────
  Future<void> _sendDirectMessage(String uid, String name) async {
    final titleCtrl = TextEditingController(text: 'Yönetici Mesajı');
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$name Kullanıcısına Bildirim'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Başlık')),
          const SizedBox(height: 8),
          TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Mesaj')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gönder')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('user_notification_requests')
          .add({
        'targetUid': uid,
        'title': titleCtrl.text.trim(),
        'body': bodyCtrl.text.trim(),
        'type': 'direct_message',
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Bildirim gönderildi.');
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection(_collection);
    if (_roleFilter != 'all') {
      query = query.where('role', isEqualTo: _roleFilter);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _showAddUser,
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(CupertinoIcons.person_add_solid,
                  color: Colors.white),
              label: const Text('Kullanıcı Ekle',
                  style: TextStyle(color: Colors.white)),
            ),
      body: Column(children: [
        // ── Toplu işlem çubuğu ──────────────────────────────────────────
        if (_selectMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF6366F1),
            child: Row(children: [
              Text(
                '${_selected.length} seçildi',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
                tooltip: 'Bildirim Gönder',
                onPressed: _bulkNotify,
              ),
              IconButton(
                icon:
                    const Icon(CupertinoIcons.lock_fill, color: Colors.orange),
                tooltip: 'Toplu Engelle',
                onPressed: _bulkBlock,
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                tooltip: 'Toplu Sil',
                onPressed: _bulkDelete,
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
                onPressed: () => setState(() {
                  _selected.clear();
                  _selectMode = false;
                }),
              ),
            ]),
          ),
        // ── Arama + filtreler ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: CupertinoSearchTextField(
                    placeholder: 'İsim, telefon, mağaza ara',
                    onChanged: (v) =>
                        setState(() => _search = v.toLowerCase())),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _selectMode = !_selectMode),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _selectMode ? const Color(0xFF6366F1) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Icon(CupertinoIcons.checkmark_square,
                      color: _selectMode ? Colors.white : Colors.black54,
                      size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _filter('all', 'Hepsi'),
                  ..._roles.entries.map((e) => _filter(e.key, e.value)),
                ])),
          ]),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }
            var docs = snapshot.data!.docs.toList()
              ..sort((a, b) => _createdAt(b.data() as Map<String, dynamic>)
                  .compareTo(_createdAt(a.data() as Map<String, dynamic>)));
            if (_search.isNotEmpty) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return '${_name(data)} ${_phone(data)} ${data['email'] ?? ''} ${data['storeName'] ?? ''}'
                    .toLowerCase()
                    .contains(_search);
              }).toList();
            }
            if (docs.isEmpty) {
              return const Center(child: Text('Kullanıcı bulunamadı.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final user = doc.data() as Map<String, dynamic>;
                final phoneVerified = user['phoneVerified'] == true;
                final blocked = user['isBlocked'] == true;
                final isSelected = _selected.contains(doc.id);

                // Firestore'daki her tür URL formatı kontrol ediliyor ('image' dahil)
                final photoUrl = (user['image'] ??
                        user['photoUrl'] ??
                        user['photoURL'] ??
                        user['profileImage'] ??
                        user['avatar'] ??
                        '')
                    .toString();
                final authType =
                    (user['auth-type'] ?? user['authType'] ?? 'email')
                        .toString()
                        .toLowerCase();

                return GestureDetector(
                  onLongPress: () => setState(() {
                    _selectMode = true;
                    _selected.add(doc.id);
                  }),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: isSelected
                          ? const BorderSide(color: Color(0xFF6366F1), width: 2)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      onTap: () {
                        if (_selectMode) {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(doc.id);
                            } else {
                              _selected.add(doc.id);
                            }
                          });
                        } else {
                          _openDetails(doc.id, user);
                        }
                      },
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: blocked
                                  ? Colors.red.withOpacity(0.1)
                                  : const Color(0xFF6366F1).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                      child: Text(
                                        _name(user)
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: blocked
                                                ? Colors.red
                                                : const Color(0xFF6366F1)),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _name(user).substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: blocked
                                              ? Colors.red
                                              : const Color(0xFF6366F1)),
                                    ),
                                  ),
                          ),
                          if (phoneVerified)
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.teal,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(CupertinoIcons.phone_fill,
                                    size: 9, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      title: Row(children: [
                        Expanded(
                          child: Text(
                            _name(user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (blocked)
                          const Icon(CupertinoIcons.lock_fill,
                              color: Colors.red, size: 14),
                        if (_selectMode)
                          Icon(
                            isSelected
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.black26,
                            size: 20,
                          ),
                      ]),
                      subtitle: Text(
                        '${_roles[(user['role'] ?? 'customer').toString()] ?? user['role']} • ${_authTypeLabel(authType)}\n${_phone(user).isEmpty ? user['email'] ?? doc.id : _phone(user)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _selectMode
                          ? null
                          : const Icon(CupertinoIcons.chevron_right, size: 17),
                    ),
                  ),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  Widget _filter(String value, String label) {
    final selected = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _roleFilter = value)),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w700))),
          Expanded(child: SelectableText(value.isEmpty ? '-' : value)),
        ]),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.black38,
                letterSpacing: 0.8)),
      );

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 38,
        height: 38,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: onTap,
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
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Telefon doğrulama geçmişi widget'ı
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneVerificationStatus extends StatelessWidget {
  final String uid;
  const _PhoneVerificationStatus({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('phone_verification_requests')
          .where('uid', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(CupertinoIcons.phone_badge_plus,
                  size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text('Telefon doğrulama talebi yok.',
                  style: TextStyle(color: Colors.black45, fontSize: 13)),
            ]),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final status = d['status']?.toString() ?? 'pending';
            final phone = d['phoneNumber']?.toString() ?? '-';
            final Timestamp? ts = d['submittedAt'] as Timestamp?;
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
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(CupertinoIcons.phone_fill, color: color, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(phone,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Text('$label • $dateStr',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}
