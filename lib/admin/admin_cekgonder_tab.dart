// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'admin_notification_service.dart';

/// ─── Kullanıcı tarafı: Çek Gönder formu ─────────────────────────────────────
/// Bu widget kullanıcıların fotoğraf/video gönderdiği sayfadır.
/// Gönderim sonrası admin'e otomatik bildirim gider.
class CekGonderSubmitPage extends StatefulWidget {
  const CekGonderSubmitPage({Key? key}) : super(key: key);

  @override
  State<CekGonderSubmitPage> createState() => _CekGonderSubmitPageState();
}

class _CekGonderSubmitPageState extends State<CekGonderSubmitPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  File? _mediaFile;
  String _mediaType = 'image';
  bool _isLoading = false;

  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    final file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 72);

    if (file != null) {
      setState(() {
        _mediaFile = File(file.path);
        _mediaType = isVideo ? 'video' : 'image';
      });
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen başlık girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String mediaUrl = '';

      if (_mediaFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('cek_gonder/${DateTime.now().millisecondsSinceEpoch}');
        await ref.putFile(_mediaFile!);
        mediaUrl = await ref.getDownloadURL();
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final docRef = await FirebaseFirestore.instance
          .collection('cek_gonder_reports')
          .add({
        'uid': uid,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'mediaUrl': mediaUrl,
        'mediaType': _mediaType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Admin'e bildirim ───────────────────────────────────────────────────
      await AdminNotificationService.instance.notifyAdmin(
        title: '📸 Yeni Çek Gönder',
        body: _titleController.text.trim(),
        type: AdminNotifType.cekGonder,
        docId: docRef.id,
      );
      // ──────────────────────────────────────────────────────────────────────

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gönderildi ✅'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Çek Gönder',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field(_titleController, 'Başlık'),
            const SizedBox(height: 12),
            _field(_descController, 'Açıklama (isteğe bağlı)', maxLines: 4),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _mediaButton(CupertinoIcons.photo, 'Fotoğraf',
                      () => _pickMedia(false)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _mediaButton(CupertinoIcons.video_camera, 'Video',
                      () => _pickMedia(true)),
                ),
              ],
            ),
            if (_mediaFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _mediaType == 'image'
                    ? Image.file(_mediaFile!,
                        height: 180, width: double.infinity, fit: BoxFit.cover)
                    : Container(
                        height: 80,
                        color: Colors.black12,
                        child: const Center(
                            child: Icon(Icons.videocam, size: 40))),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('GÖNDER',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _mediaButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin tarafı: Çek Gönder yönetim sekmesi (mevcut kodun korunmuş hali)
// ─────────────────────────────────────────────────────────────────────────────
class AdminCekGonderTab extends StatelessWidget {
  const AdminCekGonderTab({super.key});

  final String collectionName = 'cek_gonder_reports';

  Future<void> _updateStatus(
      BuildContext context, String docId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Durum güncellendi: $status'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(BuildContext context, String docId) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu kaydı silmek istediğinize emin misiniz?'),
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
        .collection(collectionName)
        .doc(docId)
        .delete();
  }

  Future<void> _sendReply(BuildContext context, String docId) async {
    final replyController = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kullanıcıya Cevap Yaz'),
        content: TextField(
          controller: replyController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Cevabınızı buraya yazın...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (send == true && replyController.text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .set({
        'adminReply': replyController.text,
        'replyDate': FieldValue.serverTimestamp(),
        'status': 'replied',
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cevap gönderildi'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('Çek Gönder kaydı bulunamadı.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final title =
                (data['title'] ?? data['subject'] ?? 'Bildiri').toString();
            final desc =
                (data['description'] ?? data['message'] ?? '').toString();
            final mediaUrl = (data['mediaUrl'] ??
                    data['imageUrl'] ??
                    data['photoUrl'] ??
                    data['videoUrl'] ??
                    '')
                .toString();
            final mediaType = (data['mediaType'] ?? 'image').toString();
            final status = (data['status'] ?? 'pending').toString();
            final adminReply = (data['adminReply'] ?? '').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      _badge(status),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(desc,
                        style: const TextStyle(
                            color: Colors.black87, height: 1.4)),
                  ],
                  if (mediaUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: mediaType == 'image'
                          ? Image.network(mediaUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover)
                          : Container(
                              height: 80,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Icon(Icons.play_circle_fill,
                                    size: 48, color: Colors.black45),
                              ),
                            ),
                    ),
                  ],
                  if (adminReply.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cevabınız:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                          const SizedBox(height: 4),
                          Text(adminReply),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.check,
                            size: 16, color: Colors.blue),
                        label: const Text('İncelendi'),
                        onPressed: () =>
                            _updateStatus(context, doc.id, 'reviewed'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.public,
                            size: 16, color: Colors.green),
                        label: const Text('Yayınla'),
                        onPressed: () =>
                            _updateStatus(context, doc.id, 'published'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.reply,
                            size: 16, color: Colors.purple),
                        label: const Text('Cevap Yaz'),
                        onPressed: () => _sendReply(context, doc.id),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.delete,
                            size: 16, color: Colors.red),
                        label: const Text('Sil'),
                        backgroundColor: Colors.red.shade50,
                        onPressed: () => _delete(context, doc.id),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'reviewed':
        color = Colors.blue;
        text = 'İncelendi';
        break;
      case 'published':
        color = Colors.green;
        text = 'Yayınlandı';
        break;
      case 'replied':
        color = Colors.purple;
        text = 'Cevaplandı';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Reddedildi';
        break;
      default:
        color = Colors.orange;
        text = 'Bekliyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
