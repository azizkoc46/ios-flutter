// ignore_for_file: deprecated_member_use
import 'admin_activity_feed_tab.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'admin_notification_service.dart';
import 'admin_activity_feed_tab.dart';

class AdminAnnouncementsTab extends StatelessWidget {
  const AdminAnnouncementsTab({super.key});

  Future<void> _delete(BuildContext context, String docId) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: const Text('Bu duyuruyu silmek istiyor musunuz?'),
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
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .delete();
  }

  Future<void> _toggleActive(String docId, bool active) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .set({
      'isActive': !active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _openEditor(BuildContext context,
      {String? docId, Map<String, dynamic>? data}) {
    final titleController = TextEditingController(text: data?['title'] ?? '');
    final bodyController = TextEditingController(text: data?['body'] ?? '');
    final imageController =
        TextEditingController(text: data?['imageUrl'] ?? '');
    final videoController =
        TextEditingController(text: data?['videoUrl'] ?? '');
    String category = (data?['category'] ?? 'Duyuru').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
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
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        docId == null
                            ? 'Yeni İlan / Duyuru'
                            : 'Duyuruyu Düzenle',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      _field(titleController, 'Başlık'),
                      _field(bodyController, 'Metin', maxLines: 5),
                      _field(imageController, 'Görsel URL'),
                      _field(videoController, 'Video URL'),
                      DropdownButtonFormField<String>(
                        value: category,
                        items: const [
                          DropdownMenuItem(
                              value: 'Duyuru', child: Text('Duyuru')),
                          DropdownMenuItem(
                              value: 'Etkinlik', child: Text('Etkinlik')),
                          DropdownMenuItem(
                              value: 'Cenaze', child: Text('Cenaze')),
                          DropdownMenuItem(value: 'Acil', child: Text('Acil')),
                          DropdownMenuItem(
                              value: 'Genel', child: Text('Genel')),
                        ],
                        onChanged: (v) {
                          if (v != null) setModalState(() => category = v);
                        },
                        decoration:
                            const InputDecoration(labelText: 'Kategori'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final isNew = docId == null;
                            final title = titleController.text.trim();

                            final payload = {
                              'title': title,
                              'body': bodyController.text.trim(),
                              'imageUrl': imageController.text.trim(),
                              'videoUrl': videoController.text.trim(),
                              'category': category,
                              'isActive': true,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            String newDocId;

                            if (isNew) {
                              final ref = await FirebaseFirestore.instance
                                  .collection('announcements')
                                  .add({
                                ...payload,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              newDocId = ref.id;
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('announcements')
                                  .doc(docId)
                                  .set(payload, SetOptions(merge: true));
                              newDocId = docId; // Ünlem işaretini de kaldırdık
                            }

                            // ── Admin'e bildirim ve Log gönder ────────────────────
                            if (isNew) {
                              // 1. Adminlere push bildirimi atıyoruz
                              await AdminNotificationService.instance
                                  .notifyAdmin(
                                title: '📢 Yeni $category Eklendi',
                                body: title,
                                type: AdminNotifType.announcement,
                                docId: newDocId,
                                extra: {'category': category},
                              );

                              // 2. Sisteme aktivite logu olarak kaydediyoruz
                              await ActivityLogger.log(
                                type: 'announcement',
                                title: 'Yeni Duyuru Eklendi',
                                body: title,
                                docId: newDocId,
                              );
                            }
                            // ──────────────────────────────────────────────

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('KAYDET',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
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

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: const Text('Duyuru Ekle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.speaker_slash,
                      size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Henüz duyuru yok.',
                      style: TextStyle(color: Colors.black45)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final active = data['isActive'] == true;
              final imageUrl = (data['imageUrl'] ?? '').toString();
              final category = (data['category'] ?? 'Duyuru').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                        child: Image.network(
                          imageUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _badge(category, _categoryColor(category)),
                              const SizedBox(width: 8),
                              _badge(active ? 'Aktif' : 'Pasif',
                                  active ? Colors.green : Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data['title'] ?? 'Başlıksız',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data['body'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _openEditor(context,
                                      docId: doc.id, data: data),
                                  child: const Text('Düzenle'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _toggleActive(doc.id, active),
                                  child:
                                      Text(active ? 'Pasif Yap' : 'Aktif Et'),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _delete(context, doc.id),
                                icon: const Icon(CupertinoIcons.delete,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Color _categoryColor(String category) {
    switch (category) {
      case 'Acil':
        return Colors.red;
      case 'Etkinlik':
        return Colors.purple;
      case 'Cenaze':
        return Colors.grey;
      default:
        return Colors.blue;
    }
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
