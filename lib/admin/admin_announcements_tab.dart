// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

import 'admin_activity_feed_tab.dart';

class AdminAnnouncementsTab extends StatefulWidget {
  const AdminAnnouncementsTab({super.key});

  @override
  State<AdminAnnouncementsTab> createState() => _AdminAnnouncementsTabState();
}

class _AdminAnnouncementsTabState extends State<AdminAnnouncementsTab> {
  String _filterCategory = "Tümü";
  final List<String> _categories = const [
    "Tümü",
    "Duyuru",
    "Etkinlik",
    "Acil",
    "Cenaze",
    "Genel",
  ];

  Color _categoryColor(String category) {
    switch (category) {
      case 'Acil':
        return const Color(0xFFDC2626);
      case 'Etkinlik':
        return const Color(0xFF7C3AED);
      case 'Cenaze':
        return const Color(0xFF374151);
      case 'Duyuru':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Acil':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'Etkinlik':
        return CupertinoIcons.calendar_badge_plus;
      case 'Cenaze':
        return CupertinoIcons.heart_slash;
      case 'Duyuru':
        return CupertinoIcons.speaker_2_fill;
      default:
        return CupertinoIcons.sparkles;
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return "-";
    DateTime? dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else if (value is String && value.isNotEmpty) {
      dt = DateTime.tryParse(value);
    }
    if (dt == null) return value.toString();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$d.$m.$y $h:$min";
  }

  Future<void> _delete(BuildContext context, String docId) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Bülten İçeriğini Sil'),
        content: const Text(
          'Bu duyuru veya etkinliği kalıcı olarak silmek istediğinize emin misiniz?',
        ),
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("İçerik başarıyla silindi."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _toggleActive(String docId, bool active) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .set({
      'isActive': !active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!active ? "Yayına alındı." : "Yayından kaldırıldı."),
          backgroundColor: !active ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _broadcastPushNotification({
    required String docId,
    required String title,
    required String body,
    required String category,
    String? imageUrl,
  }) async {
    try {
      final notificationTitle = "📢 $category: $title";
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      // 1. App Notifications listesine ekle (Bildirim kutusu için)
      await FirebaseFirestore.instance.collection('app_notifications').add({
        'title': notificationTitle,
        'body': body,
        'type': category,
        'targetType': 'announcement',
        'targetId': docId,
        'targetLabel': title,
        'imageUrl': imageUrl ?? '',
        'senderId': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'pushStatus': 'queued',
      });

      // 2. FCM Bildirim Gönderim Kuyruğuna ekle (Tüm kullanıcılara topic bildirimi)
      await FirebaseFirestore.instance
          .collection('notification_send_requests')
          .add({
        'notificationId': docId,
        'title': notificationTitle,
        'body': body,
        'type': category,
        'targetType': 'announcement',
        'targetId': docId,
        'targetLabel': title,
        'imageUrl': imageUrl ?? '',
        'topic': 'pazarcik_duyuru',
        'requestedBy': currentUid,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });

      // 3. Admin logger
      await ActivityLogger.log(
        type: 'announcement_push',
        title: 'Bülten Bildirimi Yayınlandı',
        body: '$category: $title',
        docId: docId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📢 Bildirim tüm Pazarcık halkına gönderildi!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Bildirim gönderme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bildirim gönderilemedi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openEditor(BuildContext context,
      {String? docId, Map<String, dynamic>? data}) {
    final titleController = TextEditingController(text: data?['title'] ?? '');
    final bodyController = TextEditingController(text: data?['body'] ?? '');
    final imageController =
        TextEditingController(text: data?['imageUrl'] ?? '');
    final videoController =
        TextEditingController(text: data?['videoUrl'] ?? '');
    final locationController =
        TextEditingController(text: data?['location'] ?? '');

    String category = (data?['category'] ?? 'Duyuru').toString();
    bool isUrgent = data?['isUrgent'] == true || category == 'Acil';
    bool sendPush = docId == null; // Yeni eklenirken varsayılan açık
    File? localImageFile;
    bool isUploading = false;

    DateTime? startDate;
    DateTime? endDate;

    if (data?['startDate'] != null) {
      if (data!['startDate'] is Timestamp) {
        startDate = (data['startDate'] as Timestamp).toDate();
      } else if (data['startDate'] is String) {
        startDate = DateTime.tryParse(data['startDate']);
      }
    }

    if (data?['endDate'] != null) {
      if (data!['endDate'] is Timestamp) {
        endDate = (data['endDate'] as Timestamp).toDate();
      } else if (data['endDate'] is String) {
        endDate = DateTime.tryParse(data['endDate']);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickImage() async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 78,
              );
              if (picked != null) {
                setModalState(() {
                  localImageFile = File(picked.path);
                });
              }
            }

            Future<void> pickDateTime({required bool isStart}) async {
              final initial = (isStart ? startDate : endDate) ?? DateTime.now();
              final date = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                helpText: isStart
                    ? "Etkinlik Başlangıç Tarihi"
                    : "Etkinlik Bitiş Tarihi",
              );
              if (date == null) return;

              final time = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(initial),
                helpText: isStart
                    ? "Etkinlik Başlangıç Saati"
                    : "Etkinlik Bitiş Saati",
              );
              if (time == null) return;

              final fullDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );

              setModalState(() {
                if (isStart) {
                  startDate = fullDateTime;
                  if (endDate != null && endDate!.isBefore(startDate!)) {
                    endDate = startDate!.add(const Duration(hours: 2));
                  }
                } else {
                  endDate = fullDateTime;
                }
              });
            }

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.92,
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              CupertinoIcons.sparkles,
                              color: Color(0xFF6366F1),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  docId == null
                                      ? 'Yeni Bülten & Etkinlik Yayınla'
                                      : 'Bülten İçeriğini Düzenle',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const Text(
                                  "Görsel, tarih ve otomatik bildirim desteği",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // Kategori Seçimi
                      DropdownButtonFormField<String>(
                        value: category,
                        items: const [
                          DropdownMenuItem(
                            value: 'Duyuru',
                            child: Text('📢 Duyuru'),
                          ),
                          DropdownMenuItem(
                            value: 'Etkinlik',
                            child: Text('🎉 Etkinlik'),
                          ),
                          DropdownMenuItem(
                            value: 'Acil',
                            child: Text('🚨 Acil Durum'),
                          ),
                          DropdownMenuItem(
                            value: 'Cenaze',
                            child: Text('🕊️ Cenaze & Taziye'),
                          ),
                          DropdownMenuItem(
                            value: 'Genel',
                            child: Text('🌟 Genel / Yaşam'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() {
                              category = v;
                              if (category == 'Acil') isUrgent = true;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Başlık
                      _field(
                        titleController,
                        'Başlık *',
                        prefixIcon: CupertinoIcons.textbox,
                      ),

                      // İçerik
                      _field(
                        bodyController,
                        'Detaylı Açıklama / İçerik *',
                        maxLines: 4,
                        prefixIcon: CupertinoIcons.text_alignleft,
                      ),

                      // Görsel Seçme Alanı (Dergi Kapağı)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.photo,
                                    size: 18, color: Color(0xFF6366F1)),
                                SizedBox(width: 8),
                                Text(
                                  "Dergi Kapağı Görseli",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (localImageFile != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  localImageFile!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if (imageController.text.trim().isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: PortalNetworkImage(
                                  url: imageController.text.trim(),
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: pickImage,
                                    icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 16),
                                    label: Text(localImageFile != null
                                        ? "Görseli Değiştir"
                                        : "Galeriden Görsel Seç"),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                if (localImageFile != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.xmark_circle, color: Colors.red),
                                    onPressed: () => setModalState(() => localImageFile = null),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            _field(
                              imageController,
                              'Veya Görsel Web URL (İsteğe bağlı)',
                              prefixIcon: CupertinoIcons.link,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Etkinlik / Tarih Seçimleri
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.calendar,
                                    size: 18, color: Color(0xFF7C3AED)),
                                SizedBox(width: 8),
                                Text(
                                  "Etkinlik & Tarih Zamanlaması",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickDateTime(isStart: true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Başlangıç Tarihi",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            startDate != null
                                                ? _formatDateTime(startDate)
                                                : "Tarih Seç",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: startDate != null
                                                  ? Colors.black87
                                                  : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickDateTime(isStart: false),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Bitiş Tarihi",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            endDate != null
                                                ? _formatDateTime(endDate)
                                                : "Tarih Seç",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: endDate != null
                                                  ? Colors.black87
                                                  : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (startDate != null || endDate != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => setModalState(() {
                                    startDate = null;
                                    endDate = null;
                                  }),
                                  child: const Text("Tarihleri Temizle",
                                      style: TextStyle(fontSize: 11, color: Colors.red)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mekan / Konum & Video URL
                      _field(
                        locationController,
                        'Mekan / Konum (Örn: Pazarcık Kültür Merkezi)',
                        prefixIcon: CupertinoIcons.location_solid,
                      ),
                      _field(
                        videoController,
                        'Video veya Harici Web URL (İsteğe bağlı)',
                        prefixIcon: CupertinoIcons.play_rectangle,
                      ),

                      const SizedBox(height: 8),

                      // Acil Durum Rozeti Switch
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "🚨 Acil Durum / Önemli Olarak İşaretle",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        subtitle: const Text(
                          "Kırmızı parlayan acil durum şeridi ile en başta öne çıkarılır",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        value: isUrgent,
                        activeColor: Colors.red,
                        onChanged: (v) => setModalState(() => isUrgent = v),
                      ),

                      // Otomatik Bildirim Gönderme Switch
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "📢 Tüm Pazarcık'a Otomatik Bildirim Gönder",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        subtitle: const Text(
                          "Kaydedildiği anda tüm kullanıcılara push bildirim gönderilir",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        value: sendPush,
                        activeColor: const Color(0xFF6366F1),
                        onChanged: (v) => setModalState(() => sendPush = v),
                      ),

                      const SizedBox(height: 20),

                      // Kaydet Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isUploading
                              ? null
                              : () async {
                                  final title = titleController.text.trim();
                                  final body = bodyController.text.trim();

                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text("Lütfen bir başlık girin.")),
                                    );
                                    return;
                                  }

                                  setModalState(() => isUploading = true);

                                  try {
                                    String finalImageUrl = imageController.text.trim();

                                    // Dosya yükleme varsa
                                    if (localImageFile != null) {
                                      final fileName = "announcement_${DateTime.now().millisecondsSinceEpoch}.jpg";
                                      final ref = FirebaseStorage.instance
                                          .ref()
                                          .child('announcements/$fileName');
                                      await ref.putFile(localImageFile!);
                                      finalImageUrl = await ref.getDownloadURL();
                                    }

                                    final payload = {
                                      'title': title,
                                      'body': body,
                                      'imageUrl': finalImageUrl,
                                      'videoUrl': videoController.text.trim(),
                                      'location': locationController.text.trim(),
                                      'category': category,
                                      'isUrgent': isUrgent,
                                      'startDate': startDate != null
                                          ? Timestamp.fromDate(startDate!)
                                          : null,
                                      'endDate': endDate != null
                                          ? Timestamp.fromDate(endDate!)
                                          : null,
                                      'isActive': true,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };

                                    String finalDocId;

                                    if (docId == null) {
                                      final ref = await FirebaseFirestore.instance
                                          .collection('announcements')
                                          .add({
                                        ...payload,
                                        'views': 0,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });
                                      finalDocId = ref.id;
                                    } else {
                                      await FirebaseFirestore.instance
                                          .collection('announcements')
                                          .doc(docId)
                                          .set(payload, SetOptions(merge: true));
                                      finalDocId = docId;
                                    }

                                    // Otomatik bildirim seçildiyse
                                    if (sendPush) {
                                      await _broadcastPushNotification(
                                        docId: finalDocId,
                                        title: title,
                                        body: body,
                                        category: category,
                                        imageUrl: finalImageUrl,
                                      );
                                    }

                                    // Activity Log
                                    await ActivityLogger.log(
                                      type: 'announcement',
                                      title: docId == null
                                          ? 'Yeni Bülten/Etkinlik Eklendi'
                                          : 'Bülten/Etkinlik Güncellendi',
                                      body: '$category: $title',
                                      docId: finalDocId,
                                    );

                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    debugPrint("Kayıt hatası: $e");
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text("Hata: $e")),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => isUploading = false);
                                    }
                                  }
                                },
                          child: isUploading
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : Text(
                                  docId == null ? 'YAYINLA & BİLDİRİM GÖNDER' : 'GÜNCELLEMELERİ KAYDET',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
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
    String hint, {
    int maxLines = 1,
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
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
        elevation: 6,
        icon: const Icon(CupertinoIcons.plus_circle_fill, color: Colors.white),
        label: const Text(
          'Yeni İçerik Yayınla',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
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

          final allDocs = snapshot.data!.docs;

          // Filtreleme
          final filteredDocs = _filterCategory == "Tümü"
              ? allDocs
              : allDocs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return d['category'] == _filterCategory;
                }).toList();

          int totalCount = allDocs.length;
          int activeCount = allDocs.where((d) => (d.data() as Map)['isActive'] == true).length;
          int urgentCount = allDocs.where((d) => (d.data() as Map)['isUrgent'] == true).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. İstatistik Özet Kartları
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStatCard("Toplam İçerik", "$totalCount", CupertinoIcons.layers_alt_fill, Colors.blue),
                          const SizedBox(width: 10),
                          _buildStatCard("Yayında", "$activeCount", CupertinoIcons.checkmark_seal_fill, Colors.green),
                          const SizedBox(width: 10),
                          _buildStatCard("Acil/Önemli", "$urgentCount", CupertinoIcons.exclamationmark_triangle_fill, Colors.red),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Kategori Filtre Butonları
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final cat = _categories[i];
                            final active = _filterCategory == cat;
                            final color = cat == "Tümü" ? const Color(0xFF6366F1) : _categoryColor(cat);

                            return GestureDetector(
                              onTap: () => setState(() => _filterCategory = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: active ? color : Colors.white,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: active ? color : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      color: active ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. İçerik Listesi
              if (filteredDocs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.speaker_slash, size: 54, color: Colors.black26),
                        SizedBox(height: 12),
                        Text(
                          "Bu kategoride henüz duyuru veya etkinlik yok.",
                          style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildAdminCard(doc.id, data);
                      },
                      childCount: filteredDocs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(String docId, Map<String, dynamic> data) {
    final active = data['isActive'] == true;
    final isUrgent = data['isUrgent'] == true;
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final category = (data['category'] ?? 'Duyuru').toString();
    final color = _categoryColor(category);
    final title = (data['title'] ?? 'Başlıksız').toString();
    final body = (data['body'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final startDate = data['startDate'];
    final endDate = data['endDate'];
    final views = (data['views'] is num) ? (data['views'] as num).toInt() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent ? Colors.red.withOpacity(0.4) : const Color(0xFFE5E7EB),
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUrgent ? Colors.red.withOpacity(0.06) : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: PortalNetworkImage(
                url: imageUrl,
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
                // Rozetler
                Row(
                  children: [
                    _badge(category, color, icon: _categoryIcon(category)),
                    const SizedBox(width: 6),
                    _badge(active ? 'Yayında' : 'Pasif', active ? Colors.green : Colors.orange),
                    if (isUrgent) ...[
                      const SizedBox(width: 6),
                      _badge('🚨 ACİL', Colors.red),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.eye, size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          "$views",
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
                if (startDate != null || endDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 14, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 5),
                      Text(
                        "${_formatDateTime(startDate)} - ${_formatDateTime(endDate)}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.location_solid, size: 13, color: Colors.black45),
                      const SizedBox(width: 5),
                      Text(
                        location,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 22),

                // Aksiyon Butonları
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditor(context, docId: docId, data: data),
                        icon: const Icon(CupertinoIcons.pencil, size: 15),
                        label: const Text("Düzenle"),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _broadcastPushNotification(
                          docId: docId,
                          title: title,
                          body: body,
                          category: category,
                          imageUrl: imageUrl,
                        ),
                        icon: const Icon(CupertinoIcons.bell_fill, size: 14, color: Colors.white),
                        label: const Text("Bildir", style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: active ? "Pasif Yap" : "Yayına Al",
                      onPressed: () => _toggleActive(docId, active),
                      icon: Icon(
                        active ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                        color: active ? Colors.orange : Colors.green,
                      ),
                    ),
                    IconButton(
                      tooltip: "Sil",
                      onPressed: () => _delete(context, docId),
                      icon: const Icon(CupertinoIcons.trash, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
