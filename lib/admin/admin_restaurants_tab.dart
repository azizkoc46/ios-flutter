// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdminRestaurantsTab extends StatefulWidget {
  const AdminRestaurantsTab({super.key});

  @override
  State<AdminRestaurantsTab> createState() => _AdminRestaurantsTabState();
}

class _AdminRestaurantsTabState extends State<AdminRestaurantsTab> {
  String _search = '';
  String _filter = 'all';

  Future<void> _setStatus(String uid, String status) async {
    final approved = status != 'pending';
    await FirebaseFirestore.instance.collection('customers').doc(uid).set({
      'role': 'satici',
      'isApproved': approved,
      'sellerApproved': approved,
      'sellerStatus': approved ? 'approved' : 'pending',
      'restaurantStatus': status,
      'isStoreOpen': status == 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'active') 'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restoran durumu güncellendi.')),
      );
    }
  }

  Future<void> _remove(String uid, String name) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Restoranı Sil'),
        content: Text(
            '$name restoran kaydı kaldırılsın mı? Kullanıcı hesabı korunur.'),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('customers').doc(uid).set({
      'role': 'customer',
      'isApproved': false,
      'sellerApproved': false,
      'isSeller': false,
      'sellerStatus': 'removed',
      'restaurantStatus': 'removed',
      'isStoreOpen': false,
      'removedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setTableService(String uid, bool enabled) async {
    await FirebaseFirestore.instance.collection('customers').doc(uid).set({
      'tableServiceEnabled': enabled,
      'tableServiceUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'Masa yönetimi restoran için aktif edildi.'
              : 'Masa yönetimi restoran için kapatıldı.'),
        ),
      );
    }
  }

  String _name(Map<String, dynamic> data) => (data['storeName'] ??
          data['businessName'] ??
          data['fullname'] ??
          'İsimsiz Restoran')
      .toString();

  String _status(Map<String, dynamic> data) {
    if (data['isApproved'] != true || data['sellerApproved'] != true)
      return 'pending';
    return (data['restaurantStatus'] ?? 'active').toString();
  }

  String _label(String status) => switch (status) {
        'active' => 'Açık / Aktif',
        'paused' => 'Duraklatıldı',
        'closed' => 'Kapatıldı',
        'pending' => 'Onay Bekliyor',
        _ => status,
      };

  Color _color(String status) => switch (status) {
        'active' => Colors.green,
        'paused' => Colors.orange,
        'closed' => Colors.red,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: CupertinoSearchTextField(
            placeholder: 'Restoran, telefon veya adres ara',
            onChanged: (value) => setState(() => _search = value.toLowerCase()),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final item in const {
                'all': 'Tümü',
                'active': 'Aktif',
                'inactive': 'Pasif / Kapalı',
                'pending': 'Onay Bekleyen',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.value),
                    selected: _filter == item.key,
                    onSelected: (_) => setState(() => _filter = item.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
            child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance.collection('customers').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CupertinoActivityIndicator());
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final role = (data['role'] ?? '').toString();
              final status = _status(data);
              if (status == 'removed' ||
                  status == 'rejected' ||
                  data['sellerStatus'] == 'removed') {
                return false;
              }
              final restaurant = role == 'satici' ||
                  role == 'seller' ||
                  role == 'kurumsal_satici' ||
                  role == 'kurumsal_satici_pending' ||
                  role == 'seller_pending' ||
                  role == 'vendor_pending' ||
                  data['isSeller'] == true;
              if (!restaurant) return false;
              if (_filter == 'active' && status != 'active') return false;
              if (_filter == 'pending' && status != 'pending') return false;
              if (_filter == 'inactive' &&
                  status != 'paused' &&
                  status != 'closed') {
                return false;
              }
              return '${_name(data)} ${data['phone'] ?? ''} ${data['address'] ?? ''}'
                  .toLowerCase()
                  .contains(_search);
            }).toList();
            if (docs.isEmpty)
              return const Center(child: Text('Restoran kaydı bulunamadı.'));
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final status = _status(data);
                final color = _color(status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                        backgroundColor: color.withOpacity(.12),
                        child: Icon(CupertinoIcons.bag_fill, color: color)),
                    title: Text(_name(data),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                        '${data['phone'] ?? data['phoneNumber'] ?? '-'} • ${_label(status)}'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text((data['address'] ??
                                  data['businessAddress'] ??
                                  'Adres girilmemiş')
                              .toString())),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Masa ve Adisyon Sistemi',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(data['tableServiceEnabled'] == true
                            ? 'Restoran bu özelliği kullanabilir.'
                            : 'Restoran girişte iletişim uyarısı görür.'),
                        value: data['tableServiceEnabled'] == true,
                        onChanged: status == 'pending'
                            ? null
                            : (value) => _setTableService(doc.id, value),
                      ),
                      const SizedBox(height: 4),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                            onPressed: () => _setStatus(doc.id, 'active'),
                            icon: const Icon(CupertinoIcons.checkmark_circle),
                            label: const Text('Onayla / Aç')),
                        OutlinedButton.icon(
                            onPressed: () => _setStatus(doc.id, 'paused'),
                            icon: const Icon(CupertinoIcons.pause_circle),
                            label: const Text('Duraklat')),
                        OutlinedButton.icon(
                            onPressed: () => _setStatus(doc.id, 'closed'),
                            icon: const Icon(CupertinoIcons.xmark_circle),
                            label: const Text('Kapat')),
                        TextButton.icon(
                            onPressed: () => _remove(doc.id, _name(data)),
                            icon: const Icon(CupertinoIcons.delete,
                                color: Colors.red),
                            label: const Text('Sil',
                                style: TextStyle(color: Colors.red))),
                      ]),
                    ],
                  ),
                );
              },
            );
          },
        )),
      ]),
    );
  }
}
