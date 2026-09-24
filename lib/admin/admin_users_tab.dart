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
  _SortMode _sort = _SortMode.newestFirst;

  // Toplu seçim
  final Set<String> _selected = {};
  bool _selectMode = false;

  // Kullanıcı listesi (Auth + Firestore merge)
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = true;
  String? _loadError;

  final Map<String, String> _roles = const {
    'customer': 'Normal Üye',
    'satici': 'Mağaza / Esnaf',
    'kurumsal_satici': 'Kurumsal Satıcı',
    'emlakci': 'Emlakçı',
    'admin': 'Admin',
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // ── Tüm kullanıcıları Auth + Firestore merge ─────────────────────────────
  Future<void> _loadUsers() async {
    setState(() { _loadingUsers = true; _loadError = null; });
    try {
      // 1) Cloud Function'dan tüm Auth kullanıcıları
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Oturum açık değil.');
      final resp = await http.post(
        Uri.parse('$_functionsBase/adminListUsers'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'data': {}}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final authList = (body['result']?['users'] as List?) ?? [];

      // 2) Firestore customers koleksiyonu
      final fsSnap = await FirebaseFirestore.instance.collection(_collection).get();
      final fsMap = <String, Map<String, dynamic>>{};
      for (final doc in fsSnap.docs) {
        fsMap[doc.id] = doc.data();
      }

      // 3) Merge: Auth öncelikli, Firestore ile zenginleştir
      final merged = authList.map<Map<String, dynamic>>((authUser) {
        final uid = authUser['uid'] as String? ?? '';
        final fs = fsMap[uid] ?? {};
        return {
          '__uid': uid,
          // Auth alanları
          'email': authUser['email'] ?? fs['email'] ?? '',
          'phoneNumber': authUser['phoneNumber'] ?? fs['phoneNumber'] ?? fs['phone'] ?? '',
          'displayName': authUser['displayName'] ?? '',
          'photoURL': authUser['photoURL'] ?? '',
          'creationTime': authUser['creationTime'] ?? '',
          'lastSignInTime': authUser['lastSignInTime'] ?? '',
          'providers': authUser['providers'] ?? [],
          'disabled': authUser['disabled'] ?? false,
          // Firestore alanları (varsa)
          ...fs,
          // Auth alanlarını Firestore'un üzerine yaz
          'uid': uid,
          'email': authUser['email'] ?? fs['email'] ?? '',
          'phone': authUser['phoneNumber'] ?? fs['phone'] ?? fs['phoneNumber'] ?? '',
        };
      }).toList();

      setState(() { _allUsers = merged; _loadingUsers = false; });
    } catch (e) {
      setState(() { _loadError = e.toString(); _loadingUsers = false; });
    }
  }

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

  // ── Firebase Auth kullanıcı verisi çek ───────────────────────────────────
  Future<Map<String, dynamic>> _fetchAuthUser(String uid) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return {};
      final response = await http
          .post(
            Uri.parse('$_functionsBase/adminGetAuthUser'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': {'uid': uid}}),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['result'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── Detay sayfası ─────────────────────────────────────────────────────────
  void _openDetails(String uid, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailSheet(
        uid: uid,
        firestoreUser: user,
        roles: _roles,
        fetchAuthUser: _fetchAuthUser,
        onRoleChange: (role) {
          _updateUser(uid, {
            'role': role,
            'isApproved': role == 'satici' || role == 'admin',
            'sellerApproved': role == 'satici',
          });
        },
        onToggleApprove: (approved) => _updateUser(uid, {
          'isApproved': !approved,
          'sellerApproved': !approved,
          'sellerStatus': approved ? 'pending' : 'approved',
        }),
        onSendMessage: () => _sendDirectMessage(uid, _name(user)),
        onToggleVerify: (verified) => _updateUser(uid, {
          'phoneVerified': !verified,
          if (!verified) 'phoneVerifiedAt': FieldValue.serverTimestamp(),
        }),
        onToggleBlock: (blocked) {
          _updateUser(uid, {'isBlocked': !blocked});
          ActivityLogger.log(
            type: 'user',
            title: blocked ? 'Engel kaldırıldı' : 'Kullanıcı engellendi',
            body: _name(user),
          );
        },
        onDelete: () => _deleteUser(uid, _name(user)),
        nameHelper: _name,
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
    // Filtre + arama + sıralama local olarak
    var users = _allUsers.where((u) {
      if (_roleFilter != 'all') {
        final role = (u['role'] ?? 'customer').toString();
        if (role != _roleFilter) return false;
      }
      return true;
    }).toList();

    // Sıralama
    switch (_sort) {
      case _SortMode.newestFirst:
        users.sort((a, b) => _createdAtStr(b).compareTo(_createdAtStr(a)));
      case _SortMode.oldestFirst:
        users.sort((a, b) => _createdAtStr(a).compareTo(_createdAtStr(b)));
      case _SortMode.nameAZ:
        users.sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
      case _SortMode.nameZA:
        users.sort((a, b) => _name(b).toLowerCase().compareTo(_name(a).toLowerCase()));
    }

    // Arama
    if (_search.isNotEmpty) {
      users = users.where((u) {
        return '${_name(u)} ${_phone(u)} ${u['email'] ?? ''} ${u['storeName'] ?? ''}'
            .toLowerCase().contains(_search);
      }).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _showAddUser,
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(CupertinoIcons.person_add_solid, color: Colors.white),
              label: const Text('Kullanıcı Ekle', style: TextStyle(color: Colors.white)),
            ),
      body: Column(children: [
        // ── Toplu işlem çubuğu ──────────────────────────────────────────
        if (_selectMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF6366F1),
            child: Row(children: [
              Text('${_selected.length} seçildi',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
                  tooltip: 'Bildirim Gönder', onPressed: _bulkNotify),
              IconButton(icon: const Icon(CupertinoIcons.lock_fill, color: Colors.orange),
                  tooltip: 'Toplu Engelle', onPressed: _bulkBlock),
              IconButton(icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                  tooltip: 'Toplu Sil', onPressed: _bulkDelete),
              IconButton(icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
                  onPressed: () => setState(() { _selected.clear(); _selectMode = false; })),
            ]),
          ),
        // ── Başlık + arama + filtreler ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            Row(children: [
              const Text('Kullanıcılar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _loadingUsers ? '...' : '${_allUsers.length} kişi',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showSortSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Row(children: [
                    const Icon(CupertinoIcons.arrow_up_arrow_down, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(_sort.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: CupertinoSearchTextField(
                    placeholder: 'İsim, telefon, mağaza ara',
                    onChanged: (v) => setState(() => _search = v.toLowerCase())),
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
                      color: _selectMode ? Colors.white : Colors.black54, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _filter('all', 'Hepsi'),
                ..._roles.entries.map((e) => _filter(e.key, e.value)),
              ]),
            ),
          ]),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        // ── Kullanıcı listesi ────────────────────────────────────────────
        Expanded(
          child: _loadingUsers
              ? const Center(child: CupertinoActivityIndicator())
              : _loadError != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text(_loadError!, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadUsers, child: const Text('Tekrar Dene')),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: users.isEmpty
                          ? const Center(child: Text('Kullanıcı bulunamadı.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                final uid = (user['__uid'] ?? user['uid'] ?? '').toString();
                                final phoneVerified = user['phoneVerified'] == true;
                                final blocked = user['isBlocked'] == true;
                                final isSelected = _selected.contains(uid);
                                final photoUrl = (user['photoURL'] ?? user['image'] ?? user['photoUrl'] ?? user['profileImage'] ?? user['avatar'] ?? '').toString();
                                final providers = (user['providers'] as List?)?.cast<String>() ?? [];
                                final authType = providers.isNotEmpty
                                    ? providers.first
                                    : (user['auth-type'] ?? user['authType'] ?? 'password').toString();

                                return GestureDetector(
                                  onLongPress: () => setState(() { _selectMode = true; _selected.add(uid); }),
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: isSelected ? const BorderSide(color: Color(0xFF6366F1), width: 2) : BorderSide.none,
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        if (_selectMode) {
                                          setState(() { isSelected ? _selected.remove(uid) : _selected.add(uid); });
                                        } else {
                                          _openDetails(uid, user);
                                        }
                                      },
                                      leading: Stack(clipBehavior: Clip.none, children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: blocked ? Colors.red.withOpacity(0.1) : const Color(0xFF6366F1).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: photoUrl.isNotEmpty
                                              ? Image.network(photoUrl, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(child: Text(
                                                    _name(user).isEmpty ? '?' : _name(user)[0].toUpperCase(),
                                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                                                        color: blocked ? Colors.red : const Color(0xFF6366F1)))))
                                              : Center(child: Text(
                                                  _name(user).isEmpty ? '?' : _name(user)[0].toUpperCase(),
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                                                      color: blocked ? Colors.red : const Color(0xFF6366F1)))),
                                        ),
                                        if (phoneVerified)
                                          Positioned(bottom: -2, right: -2,
                                            child: Container(
                                              width: 16, height: 16,
                                              decoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 1.5)),
                                              child: const Icon(CupertinoIcons.phone_fill, size: 9, color: Colors.white),
                                            )),
                                      ]),
                                      title: Row(children: [
                                        Expanded(child: Text(_name(user),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w800))),
                                        if (blocked) const Icon(CupertinoIcons.lock_fill, color: Colors.red, size: 14),
                                        if (_selectMode)
                                          Icon(isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                                              color: isSelected ? const Color(0xFF6366F1) : Colors.black26, size: 20),
                                      ]),
                                      subtitle: Text(
                                        '${_roles[(user['role'] ?? 'customer').toString()] ?? user['role'] ?? 'Normal Üye'} • ${_authTypeLabel(authType)}\n${_phone(user).isEmpty ? (user['email'] ?? uid) : _phone(user)}',
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: _selectMode ? null : const Icon(CupertinoIcons.chevron_right, size: 17),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ]),
    );
  }

  String _createdAtStr(Map<String, dynamic> u) {
    final ts = u['createdAt'] as Timestamp?;
    if (ts != null) return ts.toDate().toIso8601String();
    final ct = u['creationTime']?.toString() ?? '';
    return ct;
  }

  void _showSortSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Sırala'),
        actions: _SortMode.values
            .map((mode) => CupertinoActionSheetAction(
                  isDefaultAction: _sort == mode,
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _sort = mode);
                  },
                  child: Text(mode.label),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ),
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
// Kullanıcı Detay Sheet — Firebase Auth + Firestore birleşik
// ─────────────────────────────────────────────────────────────────────────────
class _UserDetailSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> firestoreUser;
  final Map<String, String> roles;
  final Future<Map<String, dynamic>> Function(String uid) fetchAuthUser;
  final void Function(String role) onRoleChange;
  final void Function(bool approved) onToggleApprove;
  final VoidCallback onSendMessage;
  final void Function(bool verified) onToggleVerify;
  final void Function(bool blocked) onToggleBlock;
  final VoidCallback onDelete;
  final String Function(Map<String, dynamic>) nameHelper;

  const _UserDetailSheet({
    required this.uid,
    required this.firestoreUser,
    required this.roles,
    required this.fetchAuthUser,
    required this.onRoleChange,
    required this.onToggleApprove,
    required this.onSendMessage,
    required this.onToggleVerify,
    required this.onToggleBlock,
    required this.onDelete,
    required this.nameHelper,
  });

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  Map<String, dynamic>? _authUser;
  bool _authLoading = true;

  @override
  void initState() {
    super.initState();
    widget.fetchAuthUser(widget.uid).then((data) {
      if (mounted) setState(() { _authUser = data; _authLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _authLoading = false);
    });
  }

  String _fmt(dynamic v) => v == null || v.toString().isEmpty ? '—' : v.toString();

  String _providerLabel(String id) => switch (id) {
    'google.com' => 'Google',
    'apple.com' => 'Apple',
    'phone' => 'Telefon (SMS)',
    'password' => 'E-posta & Şifre',
    _ => id,
  };

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  Widget _row(String label, String value) {
    if (value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w900,
      color: Colors.black38, letterSpacing: 0.8)),
  );

  Widget _actionTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.firestoreUser;
    final auth = _authUser ?? {};

    // Merged data — Auth öncelikli
    final name = widget.nameHelper(fs);
    final email = _fmt(auth['email']?.toString().isNotEmpty == true ? auth['email'] : fs['email']);
    final phone = _fmt(auth['phoneNumber']?.toString().isNotEmpty == true ? auth['phoneNumber'] : (fs['phoneNumber'] ?? fs['phone']));
    final photoUrl = _fmt(auth['photoURL']?.toString().isNotEmpty == true ? auth['photoURL'] : (fs['image'] ?? fs['photoUrl'] ?? fs['photoURL'] ?? fs['profileImage'] ?? fs['avatar']));
    final role = (fs['role'] ?? 'customer').toString();
    final blocked = fs['isBlocked'] == true;
    final approved = fs['sellerApproved'] == true || fs['isApproved'] == true;
    final phoneVerified = fs['phoneVerified'] == true;
    final displayName = _fmt(auth['displayName']?.toString().isNotEmpty == true ? auth['displayName'] : fs['fullname'] ?? fs['fullName']);
    final providers = (auth['providers'] as List?)?.map((p) => _providerLabel(p['providerId'] ?? '')).join(', ') ?? '—';
    final creationTime = _fmtDate(auth['creationTime']?.toString());
    final lastSignIn = _fmtDate(auth['lastSignInTime']?.toString());
    final disabled = auth['disabled'] == true;

    // Firestore alanları
    final Timestamp? lastActiveTs = fs['lastActive'] as Timestamp?;
    final lastActive = lastActiveTs != null
        ? _fmtDate(lastActiveTs.toDate().toIso8601String())
        : '—';
    final Timestamp? createdAtTs = (fs['createdAt'] ?? fs['created_at']) as Timestamp?;
    final createdAt = createdAtTs != null
        ? _fmtDate(createdAtTs.toDate().toIso8601String())
        : creationTime;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FractionallySizedBox(
        heightFactor: .94,
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44, height: 5,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 30), children: [
              // ── Avatar + isim ──────────────────────────────────────
              Row(children: [
                Container(
                  width: 68, height: 68,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: photoUrl != '—'
                      ? Image.network(photoUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)))))
                      : Center(child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w900)),
                    Text(widget.roles[role] ?? role, style: const TextStyle(color: Colors.black45, fontSize: 13)),
                    if (_authLoading)
                      const Padding(padding: EdgeInsets.only(top: 4),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                  ],
                )),
              ]),
              const SizedBox(height: 12),

              // ── Durum badge'leri ────────────────────────────────────
              Wrap(spacing: 8, runSpacing: 6, children: [
                _chip(blocked ? '🔒 Engelli' : '✅ Aktif', blocked ? Colors.red : Colors.green),
                _chip(approved ? '✅ Onaylı' : '⏳ Onay Bekliyor', approved ? Colors.blue : Colors.orange),
                _chip(phoneVerified ? '📱 Tel. Doğrulandı' : '📱 Tel. Doğrulanmadı', phoneVerified ? Colors.teal : Colors.blueGrey),
                if (disabled) _chip('🚫 Auth Devre Dışı', Colors.red.shade900),
              ]),

              // ── Firebase Auth Bilgileri ──────────────────────────────
              _section('FİREBASE AUTH'),
              _row('E-posta', email),
              _row('Telefon', phone),
              _row('Görünen Ad', displayName),
              _row('Giriş Yöntemleri', providers),
              _row('Hesap Oluşturma', creationTime),
              _row('Son Giriş', lastSignIn),
              _row('Auth UID', widget.uid),

              // ── Firestore Bilgileri ─────────────────────────────────
              _section('PROFİL BİLGİLERİ'),
              _row('Kayıt Tarihi', createdAt),
              _row('Son Görülme', lastActive),
              _row('Mağaza', _fmt(fs['storeName'] ?? fs['businessName'])),
              _row('Adres', _fmt(fs['address'] ?? fs['businessAddress'])),
              _row('Şehir', _fmt(fs['city'] ?? fs['il'])),
              _row('İlçe', _fmt(fs['district'] ?? fs['ilce'])),
              _row('Hakkında', _fmt(fs['about'] ?? fs['bio'])),

              // ── Telefon Doğrulama Geçmişi ───────────────────────────
              _section('TELEFON DOĞRULAMA GEÇMİŞİ'),
              _PhoneVerificationStatus(uid: widget.uid),

              // ── Rol & Yetki ────────────────────────────────────────
              _section('ROL & YETKİ'),
              DropdownButtonFormField<String>(
                value: widget.roles.containsKey(role) ? role : 'customer',
                decoration: InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: widget.roles.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  Navigator.pop(context);
                  widget.onRoleChange(value);
                },
              ),

              // ── İşlemler ───────────────────────────────────────────
              _section('İŞLEMLER'),
              if (role.contains('satici') || role.contains('seller'))
                _actionTile(
                  icon: approved ? CupertinoIcons.xmark_circle : CupertinoIcons.checkmark_circle,
                  label: approved ? 'Esnaf onayını kaldır' : 'Esnafı onayla',
                  color: approved ? Colors.orange : Colors.green,
                  onTap: () { Navigator.pop(context); widget.onToggleApprove(approved); },
                ),
              _actionTile(
                icon: CupertinoIcons.paperplane_fill,
                label: 'Bildirim Gönder',
                color: const Color(0xFF6366F1),
                onTap: () { Navigator.pop(context); widget.onSendMessage(); },
              ),
              _actionTile(
                icon: phoneVerified ? CupertinoIcons.phone_badge_plus : CupertinoIcons.checkmark_shield_fill,
                label: phoneVerified ? 'Tel. Doğrulamayı Kaldır' : 'Tel. Manuel Onayla',
                color: phoneVerified ? Colors.orange : Colors.teal,
                onTap: () { Navigator.pop(context); widget.onToggleVerify(phoneVerified); },
              ),
              _actionTile(
                icon: blocked ? CupertinoIcons.lock_open : CupertinoIcons.lock,
                label: blocked ? 'Engeli kaldır' : 'Kullanıcıyı engelle',
                color: blocked ? Colors.green : Colors.orange,
                onTap: () { Navigator.pop(context); widget.onToggleBlock(blocked); },
              ),
              _actionTile(
                icon: CupertinoIcons.delete,
                label: 'Kullanıcıyı kalıcı sil',
                color: Colors.red,
                onTap: () { Navigator.pop(context); widget.onDelete(); },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sıralama modları
// ─────────────────────────────────────────────────────────────────────────────
enum _SortMode {
  newestFirst,
  oldestFirst,
  nameAZ,
  nameZA;

  String get label => switch (this) {
        _SortMode.newestFirst => 'Yeniden Eskiye',
        _SortMode.oldestFirst => 'Eskiden Yeniye',
        _SortMode.nameAZ => 'A → Z',
        _SortMode.nameZA => 'Z → A',
      };
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
