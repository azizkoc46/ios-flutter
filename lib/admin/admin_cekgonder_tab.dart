// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'admin_notification_service.dart';
import 'package:pazarcik_portal/services/user_notification_service.dart';
import 'package:pazarcik_portal/widgets/cek_gonder_reply_dialog.dart';
import 'package:pazarcik_portal/services/cek_gonder_institution_service.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Çek Gönder için lütfen kayıtlı bir hesapla giriş yapın.')),
      );
      return;
    }

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

      String userName = user.displayName ?? '';
      String userPhone = user.phoneNumber ?? '';

      try {
        final custDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();
        if (custDoc.exists && custDoc.data() != null) {
          final cd = custDoc.data()!;
          if (userName.isEmpty) {
            userName = (cd['name'] ?? cd['fullName'] ?? '').toString();
          }
          if (userPhone.isEmpty) {
            userPhone = (cd['phone'] ?? cd['phoneNumber'] ?? '').toString();
          }
        }
      } catch (_) {}

      final docRef = await FirebaseFirestore.instance
          .collection('cek_gonder_reports')
          .add({
        'uid': user.uid,
        'userName': userName,
        'userPhone': userPhone,
        'userEmail': user.email ?? '',
        'phoneVerified': true,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'mediaUrl': mediaUrl,
        'mediaType': _mediaType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Admin'e bildirim ───────────────────────────────────────────────────
      await AdminNotificationService.instance.notifyAdmin(
        title: '📸 Yeni Çek Gönder: $userName',
        body: _titleController.text.trim(),
        type: AdminNotifType.cekGonder,
        docId: docRef.id,
        extra: {
          'uid': user.uid,
          'userName': userName,
          'userPhone': userPhone,
          'userEmail': user.email ?? '',
          'phoneVerified': 'true',
        },
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
class AdminCekGonderTab extends StatefulWidget {
  const AdminCekGonderTab({super.key});

  @override
  State<AdminCekGonderTab> createState() => _AdminCekGonderTabState();
}

class _AdminCekGonderTabState extends State<AdminCekGonderTab> {
  final String collectionName = 'cek_gonder_reports';
  String _selectedFilter = 'all'; // 'all', 'pending', 'replied', 'published'
  String _selectedInstitutionFilter = 'all'; // 'all', 'genel', or institutionId

  void _openManageInstitutionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.building_2_fill, color: Color(0xFF0056D2)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Kurum & Yönetim Masaları",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0056D2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _showAddOrEditInstitutionDialog();
                      },
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text("Yeni Kurum", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<CekGonderInstitution>>(
                  stream: CekGonderInstitutionService.instance.streamAllInstitutions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text("Henüz kurum eklenmemiş."));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final inst = list[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF0056D2).withOpacity(0.1),
                                child: Icon(
                                  inst.id == 'genel' ? CupertinoIcons.placemark_fill : CupertinoIcons.building_2_fill,
                                  color: const Color(0xFF0056D2),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inst.name,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${inst.category} • Tel: ${inst.phone.isNotEmpty ? inst.phone : 'Belirtilmedi'}",
                                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                    ),
                                    if (inst.authorizedPhones.isNotEmpty)
                                      Text(
                                        "Yetkili Tel: ${inst.authorizedPhones.join(', ')}",
                                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(CupertinoIcons.pencil, size: 18),
                                onPressed: () => _showAddOrEditInstitutionDialog(inst),
                              ),
                              if (inst.id != 'genel')
                                IconButton(
                                  icon: const Icon(CupertinoIcons.trash, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Kurumu Sil"),
                                        content: Text("${inst.name} kurumunu silmek istediğinize emin misiniz?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sil", style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await CekGonderInstitutionService.instance.deleteInstitution(inst.id);
                                    }
                                  },
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
      },
    );
  }

  void _showAddOrEditInstitutionDialog([CekGonderInstitution? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'Site / Konut Yönetimi');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final authPhoneCtrl = TextEditingController(
      text: existing?.authorizedPhones.join(', ') ?? '',
    );

    final parentContext = context;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existing == null ? "➕ Yeni Kurum / Yönetim Ekle" : "✏️ Kurumu Düzenle",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Kurum / Yönetim Adı *",
                      hintText: "Örn: İncirli TOKİ 2. Etap Yönetimi",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: catCtrl,
                    decoration: const InputDecoration(
                      labelText: "Kategori",
                      hintText: "Örn: Site / Konut Yönetimi veya Belediye",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: authPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: "Yetkili Telefon Numarası *",
                      hintText: "Örn: 05321234567 (Yetkili bu numarayla girer)",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: "Kurum İletişim Hattı",
                      hintText: "Örn: 0344 XXX XX XX",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Açıklama (Görev Alanı)",
                      hintText: "Örn: 2. Etap blokları ve arızalar",
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056D2),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text("Lütfen kurum adını girin."), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final phones = authPhoneCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();

                          await CekGonderInstitutionService.instance.saveInstitution(
                            id: existing?.id,
                            name: name,
                            category: catCtrl.text.trim().isEmpty ? 'Site / Konut Yönetimi' : catCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            authorizedPhones: phones,
                            authorizedUids: existing?.authorizedUids ?? [],
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text("Kurum başarıyla kaydedildi! ✅"), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          debugPrint("Kurum kaydetme hatası: $e");
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text("Kaydetme hatası: $e"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(color: Colors.white),
                      )
                    : const Text("KAYDET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferInstitutionDialog(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Şikayeti Başka Kuruma Aktar",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Bu bildirimi doğru kuruma yönlendirerek yetkilisinin ilgilenmesini sağlayabilirsiniz.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<CekGonderInstitution>>(
                stream: CekGonderInstitutionService.instance.streamActiveInstitutions(),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];
                  return Column(
                    children: list.map((inst) {
                      return ListTile(
                        leading: const Icon(CupertinoIcons.building_2_fill, color: Color(0xFF0056D2)),
                        title: Text(inst.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(inst.category),
                        onTap: () async {
                          await doc.reference.update({
                            'institutionId': inst.id,
                            'institutionName': inst.name,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Bildirim ${inst.name} kurumuna aktarıldı! ✅"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

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

  Future<void> _sendReply(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    final title = (data['title'] ?? data['subject'] ?? 'Bildiri').toString();
    final desc = (data['description'] ?? data['message'] ?? '').toString();
    final uid = (data['uid'] ?? '').toString();
    final userName = (data['userName'] ?? '').toString();
    final userPhone = (data['userPhone'] ??
            data['phone'] ??
            data['phoneNumber'] ??
            '')
        .toString();
    final userEmail = (data['userEmail'] ?? '').toString();
    final isPhoneVerified =
        data['phoneVerified'] == true || data['isVerified'] == true;

    final senderLabel = userName.isNotEmpty
        ? userName
        : userEmail.isNotEmpty
            ? userEmail
            : 'Kullanıcı';

    final replyController =
        TextEditingController(text: (data['adminReply'] ?? '').toString());

    final send = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.reply_all_rounded, color: Color(0xFF0056D2)),
            SizedBox(width: 8),
            Text('Kullanıcıya Cevap Yaz',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person,
                            size: 16, color: Color(0xFF0056D2)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Gönderen: $senderLabel',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (userPhone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_iphone,
                              size: 15, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            userPhone,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF047857)),
                          ),
                          const SizedBox(width: 6),
                          if (isPhoneVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ONAYLI',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '✉️ $userEmail',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Text('📋 Konu: $title',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Cevabınız:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: replyController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Vatandaşa iletilecek cevabı buraya yazın...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Kaydedildiğinde kullanıcıya sesli ve anlık bildirim gider.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056D2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send, size: 16, color: Colors.white),
            label: const Text('Gönder & Bildir',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (send == true && replyController.text.trim().isNotEmpty) {
      final replyText = replyController.text.trim();

      // 1. Raporu güncelle
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .set({
        'adminReply': replyText,
        'replyDate': FieldValue.serverTimestamp(),
        'status': 'replied',
        'repliedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
      }, SetOptions(merge: true));

      // 2. Kullanıcıya Bildirim (in-app + push) gönder
      if (uid.isNotEmpty && uid != 'anonymous') {
        await UserNotificationService.instance.sendNotificationToUser(
          targetUid: uid,
          title: '📸 Çek & Gönder Bildiriminize Yanıt Verildi',
          body: replyText,
          type: 'cek_gonder_reply',
          docId: docId,
          extraData: {
            'docId': docId,
            'targetId': docId,
            'targetType': 'cek_gonder',
            'reportTitle': title,
            'reportDesc': desc,
            'mediaUrl': (data['mediaUrl'] ?? '').toString(),
            'mediaType': (data['mediaType'] ?? 'image').toString(),
            'adminReply': replyText,
          },
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cevap gönderildi ve kullanıcıya anlık bildirim iletildi! ✅'),
          backgroundColor: Colors.green,
        ),
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

        final allDocs = snapshot.data!.docs;

        if (allDocs.isEmpty) {
          return const Center(child: Text('Çek Gönder kaydı bulunamadı.'));
        }

        final pendingCount = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = data['status'] ?? 'pending';
          final hasReply = (data['adminReply'] ?? '').toString().trim().isNotEmpty;
          return s == 'pending' && !hasReply;
        }).length;

        final repliedCount = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = data['status'];
          final hasReply = (data['adminReply'] ?? '').toString().trim().isNotEmpty;
          return s == 'replied' || hasReply;
        }).length;

        final publishedCount = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == 'published';
        }).length;

        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = data['status'] ?? 'pending';
          final hasReply = (data['adminReply'] ?? '').toString().trim().isNotEmpty;
          final instId = (data['institutionId'] ?? 'genel').toString();

          // Kurum Filtresi
          if (_selectedInstitutionFilter != 'all') {
            if (_selectedInstitutionFilter == 'genel') {
              if (instId != 'genel' && instId.isNotEmpty) return false;
            } else {
              if (instId != _selectedInstitutionFilter) return false;
            }
          }

          if (_selectedFilter == 'pending') {
            return s == 'pending' && !hasReply;
          } else if (_selectedFilter == 'replied') {
            return s == 'replied' || hasReply;
          } else if (_selectedFilter == 'published') {
            return s == 'published';
          }
          return true;
        }).toList();

        return Column(
          children: [
            // 🏢 Kurum Masaları & Yönetim Barı
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: StreamBuilder<List<CekGonderInstitution>>(
                      stream: CekGonderInstitutionService.instance.streamActiveInstitutions(),
                      builder: (context, instSnap) {
                        final insts = instSnap.data ?? [];
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text("Tüm Kurumlar"),
                                selected: _selectedInstitutionFilter == 'all',
                                onSelected: (_) => setState(() => _selectedInstitutionFilter = 'all'),
                                selectedColor: const Color(0xFF0056D2),
                                labelStyle: TextStyle(
                                  color: _selectedInstitutionFilter == 'all' ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ...insts.map((inst) {
                                final isSelected = _selectedInstitutionFilter == inst.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(inst.name),
                                    selected: isSelected,
                                    onSelected: (_) => setState(() => _selectedInstitutionFilter = inst.id),
                                    selectedColor: const Color(0xFF0056D2),
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0056D2),
                      side: const BorderSide(color: Color(0xFF0056D2)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openManageInstitutionsSheet,
                    icon: const Icon(CupertinoIcons.building_2_fill, size: 14),
                    label: const Text("Kurumlar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Durum Filtre Barı
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'Tümü (${allDocs.length})', Icons.list),
                    const SizedBox(width: 8),
                    _filterChip('pending', '⏳ Bekleyenler ($pendingCount)',
                        Icons.hourglass_empty, Colors.orange),
                    const SizedBox(width: 8),
                    _filterChip('replied', '💬 Cevaplananlar ($repliedCount)',
                        Icons.check_circle_outline, Colors.green),
                    const SizedBox(width: 8),
                    _filterChip('published', '📢 Yayınlananlar ($publishedCount)',
                        Icons.public, Colors.teal),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: docs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Bu filtreye uygun kayıt bulunamadı.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : ListView.builder(
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

            // 👤 Gönderen kullanıcı bilgileri
            final userName = (data['userName'] ?? '').toString();
            final userPhone = (data['userPhone'] ??
                    data['phone'] ??
                    data['phoneNumber'] ??
                    '')
                .toString();
            final userEmail = (data['userEmail'] ?? '').toString();
            final uid = (data['uid'] ?? '').toString();
            final isPhoneVerified =
                data['phoneVerified'] == true || data['isVerified'] == true;

            final senderLabel = userName.isNotEmpty
                ? userName
                : userEmail.isNotEmpty
                    ? userEmail
                    : uid.isNotEmpty
                        ? uid.substring(0, uid.length > 12 ? 12 : uid.length)
                        : 'Anonim';

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
                  // 🏢 İlgili Kurum Rozeti ve Aktarma Butonu
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0056D2).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0056D2).withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.building_2_fill, size: 12, color: Color(0xFF0056D2)),
                            const SizedBox(width: 4),
                            Text(
                              (data['institutionName'] ?? 'Genel / Belediye').toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0056D2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showTransferInstitutionDialog(doc),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.arrow_right_arrow_left, size: 12, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text(
                                "Kurumu Değiştir",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

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
                  const SizedBox(height: 8),

                  // 👤 GÖNDEREN VATANDAŞ KARTI (İSİM & DOĞRULANMIŞ TELEFON)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPhoneVerified || userPhone.isNotEmpty
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Color(0xFF0056D2)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                senderLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (isPhoneVerified || userPhone.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified,
                                        size: 12, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text(
                                      'ONAYLI TELEFON',
                                      style: TextStyle(
                                        color: Color(0xFF047857),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (userPhone.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone,
                                  size: 15, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              SelectableText(
                                userPhone,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              const Spacer(),
                              // Tek tıkla Ara
                              InkWell(
                                onTap: () async {
                                  final clean = userPhone.replaceAll(
                                      RegExp(r'[^0-9+]'), '');
                                  final uri = Uri.parse('tel:$clean');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0056D2)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone,
                                          size: 13, color: Color(0xFF0056D2)),
                                      SizedBox(width: 4),
                                      Text('Ara',
                                          style: TextStyle(
                                              color: Color(0xFF0056D2),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Kopyala
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: userPhone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Telefon numarası kopyalandı 📋'),
                                        duration: Duration(seconds: 2)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.copy,
                                      size: 13, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '✉️ $userEmail',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
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
                        onPressed: () => _sendReply(context, doc.id, data),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.visibility_outlined,
                            size: 16, color: Colors.teal),
                        label: const Text('Büyük Gör'),
                        onPressed: () => CekGonderReplyDialog.show(context,
                            data: data, docId: doc.id),
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
        ),
      ),
    ],
  );
      },
    );
  }

  Widget _filterChip(String key, String label, IconData icon, [Color? activeColor]) {
    final isSelected = _selectedFilter == key;
    final color = activeColor ?? const Color(0xFF0056D2);

    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 15, color: isSelected ? Colors.white : color),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      selectedColor: color,
      backgroundColor: color.withOpacity(0.08),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(isSelected ? 1.0 : 0.3)),
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
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
