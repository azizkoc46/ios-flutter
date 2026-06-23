// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTaxiTab extends StatelessWidget {
  const AdminTaxiTab({super.key});

  static final DocumentReference<Map<String, dynamic>> _doc =
      FirebaseFirestore.instance.collection('app_settings').doc('taxi_numbers');

  List<Map<String, dynamic>> _defaultItems() {
    return [
      {
        'id': 'taksi_crazy',
        'name': 'TAKSI CRAZY',
        'phone': '0543 569 46 58',
        'telUrl': 'tel:+905435694658',
        'note': '',
        'sortOrder': 1,
        'isActive': true,
      },
      {
        'id': 'otogar_taksi',
        'name': 'Otogar Taksi',
        'phone': '(0344) 311 20 30',
        'telUrl': 'tel:+903443112030',
        'note': '',
        'sortOrder': 2,
        'isActive': true,
      },
      {
        'id': 'merkez_taksi',
        'name': 'Merkez Taksi',
        'phone': '(0344) 311 44 05',
        'telUrl': 'tel:+903443114405',
        'note': '',
        'sortOrder': 3,
        'isActive': true,
      },
      {
        'id': 'narli_taksi',
        'name': 'Narlı Taksi',
        'phone': '0533 438 84 51',
        'telUrl': 'tel:+905334388451',
        'note': '',
        'sortOrder': 4,
        'isActive': true,
      },
    ];
  }

  List<Map<String, dynamic>> _itemsFromData(Map<String, dynamic>? data) {
    final raw = data?['items'];
    if (raw is! List) return [];
    final items =
        raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    items.sort((a, b) {
      final aOrder = a['sortOrder'];
      final bOrder = b['sortOrder'];
      if (aOrder is num && bOrder is num) {
        return aOrder.compareTo(bOrder);
      }
      return (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString());
    });
    return items;
  }

  String _telUrlFromPhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return 'tel:$digits';
    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '90${digits.substring(1)}';
    } else if (digits.length == 10) {
      digits = '90$digits';
    }
    return digits.isEmpty ? '' : 'tel:+$digits';
  }

  Future<void> _saveItems(List<Map<String, dynamic>> items) async {
    await _doc.set({
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteItem(
      BuildContext context, int index, List<Map<String, dynamic>> items) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Taksi Kaydını Sil'),
        content:
            const Text('Bu taksi kaydını listeden kaldırmak istiyor musunuz?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sil'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final updated = [...items]..removeAt(index);
    await _saveItems(updated);
  }

  void _openEditor(
    BuildContext context,
    List<Map<String, dynamic>> items, {
    int? index,
  }) {
    final current = index == null ? <String, dynamic>{} : items[index];
    final nameController =
        TextEditingController(text: (current['name'] ?? '').toString());
    final phoneController =
        TextEditingController(text: (current['phone'] ?? '').toString());
    final noteController =
        TextEditingController(text: (current['note'] ?? '').toString());
    final orderController = TextEditingController(
      text: (current['sortOrder'] ?? (items.length + 1)).toString(),
    );
    bool isActive = current['isActive'] != false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        index == null
                            ? 'Yeni Taksi Ekle'
                            : 'Taksi Kaydını Düzenle',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _field(nameController, 'Durak / Taksi Adı'),
                      _field(
                        phoneController,
                        'Telefon',
                        keyboardType: TextInputType.phone,
                      ),
                      _field(
                        noteController,
                        'Not (isteğe bağlı)',
                        required: false,
                      ),
                      _field(
                        orderController,
                        'Sıralama',
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        activeColor: const Color(0xFF6366F1),
                        title: const Text(
                          'Uygulamada Göster',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onChanged: (value) {
                          setModalState(() => isActive = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon:
                              const Icon(CupertinoIcons.checkmark_circle_fill),
                          label: const Text(
                            'KAYDET',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final phone = phoneController.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Ad ve telefon zorunlu.'),
                                ),
                              );
                              return;
                            }

                            final updated = [...items];
                            final item = {
                              'id': (current['id'] ??
                                      DateTime.now()
                                          .microsecondsSinceEpoch
                                          .toString())
                                  .toString(),
                              'name': name,
                              'phone': phone,
                              'telUrl': _telUrlFromPhone(phone),
                              'note': noteController.text.trim(),
                              'sortOrder':
                                  int.tryParse(orderController.text.trim()) ??
                                      (items.length + 1),
                              'isActive': isActive,
                            };

                            if (index == null) {
                              updated.add(item);
                            } else {
                              updated[index] = item;
                            }

                            await _saveItems(updated);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(CupertinoIcons.add),
        label: const Text(
          'Taksi Ekle',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: () async {
          final snap = await _doc.get();
          _openEditor(context, _itemsFromData(snap.data()));
        },
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _doc.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final items = _itemsFromData(snapshot.data?.data());
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.car_detailed,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Henüz taksi kaydı yok.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sağ alttaki Taksi Ekle butonuyla listeyi oluşturabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black38),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _saveItems(_defaultItems()),
                      icon: const Icon(CupertinoIcons.arrow_down_doc_fill),
                      label: const Text('Varsayılan Taksileri Yükle'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final active = item['isActive'] != false;
              final note = (item['note'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBC02D).withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.car_detailed,
                        color: Color(0xFFF8A809),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (item['name'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _badge(active ? 'Aktif' : 'Pasif',
                                  active ? Colors.green : Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (item['phone'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black38),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: active ? 'Pasif yap' : 'Aktif et',
                      onPressed: () async {
                        final updated = [...items];
                        updated[index] = {
                          ...item,
                          'isActive': !active,
                        };
                        await _saveItems(updated);
                      },
                      icon: Icon(
                        active
                            ? CupertinoIcons.eye_fill
                            : CupertinoIcons.eye_slash_fill,
                        color: active ? Colors.green : Colors.orange,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Düzenle',
                      onPressed: () =>
                          _openEditor(context, items, index: index),
                      icon:
                          const Icon(CupertinoIcons.pencil, color: Colors.blue),
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => _deleteItem(context, index, items),
                      icon:
                          const Icon(CupertinoIcons.delete, color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
