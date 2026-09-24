// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminMuhtarlikTab extends StatefulWidget {
  const AdminMuhtarlikTab({Key? key}) : super(key: key);

  @override
  State<AdminMuhtarlikTab> createState() => _AdminMuhtarlikTabState();
}

class _AdminMuhtarlikTabState extends State<AdminMuhtarlikTab> {
  String _searchQuery = "";
  final Color _primary = const Color(0xFF6366F1);

  void _showAddEditDialog({DocumentSnapshot? doc}) {
    final isEditing = doc != null;
    final data = isEditing ? (doc.data() as Map<String, dynamic>) : {};

    final neighborhoodCtrl = TextEditingController(text: data['neighborhood'] ?? '');
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
    bool hasWhatsapp = data['hasWhatsapp'] ?? true;

    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return CupertinoAlertDialog(
              title: Text(isEditing ? "Muhtarlık Düzenle" : "Yeni Muhtarlık Ekle"),
              content: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: [
                    CupertinoTextField(
                      controller: neighborhoodCtrl,
                      placeholder: "Mahalle Adı (Örn: Bağdınısağır)",
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: nameCtrl,
                      placeholder: "Muhtar Adı Soyadı",
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: phoneCtrl,
                      placeholder: "Telefon Numarası (Örn: 0532...)",
                      keyboardType: TextInputType.phone,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "WhatsApp Aktif mi?",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        CupertinoSwitch(
                          value: hasWhatsapp,
                          onChanged: (val) => setDlgState(() => hasWhatsapp = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text("İptal"),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    final neighborhood = neighborhoodCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();

                    if (neighborhood.isEmpty || name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Lütfen tüm alanları doldurunuz.")),
                      );
                      return;
                    }

                    final payload = {
                      'neighborhood': neighborhood,
                      'name': name,
                      'phone': phone,
                      'hasWhatsapp': hasWhatsapp,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (!isEditing) {
                      payload['createdAt'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance.collection('muhtarliklar').add(payload);
                    } else {
                      await doc.reference.update(payload);
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? "Muhtarlık güncellendi." : "Yeni muhtarlık eklendi."),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(isEditing ? "Güncelle" : "Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Muhtarlığı Sil"),
        content: Text("${data['neighborhood'] ?? 'Bu'} muhtarlığını silmek istediğinize emin misiniz?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () async {
              Navigator.pop(ctx);
              await doc.reference.delete();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Muhtarlık silindi."), backgroundColor: Colors.red),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Yeni Muhtar Ekle",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Arama
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: CupertinoSearchTextField(
              placeholder: "Mahalle veya muhtar ara...",
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('muhtarliklar')
                  .orderBy('neighborhood')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = (snapshot.data?.docs ?? []).where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final neighborhood = (data['neighborhood'] ?? '').toString().toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  if (_searchQuery.isEmpty) return true;
                  return neighborhood.contains(_searchQuery) || name.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.person_2_square_stack, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            "Kayıtlı muhtarlık bulunamadı.\nSağ alttaki butondan ekleyebilirsiniz.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final neighborhood = data['neighborhood'] ?? '-';
                    final name = data['name'] ?? '-';
                    final phone = data['phone'] ?? '-';
                    final hasWhatsapp = data['hasWhatsapp'] ?? true;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.account_balance, color: _primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  neighborhood,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Muhtar: $name",
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      "Tel: $phone",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    if (hasWhatsapp) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "WhatsApp",
                                          style: TextStyle(
                                            color: Color(0xFF16A34A),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                            onPressed: () => _showAddEditDialog(doc: doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () => _confirmDelete(doc),
                          ),
                        ],
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
