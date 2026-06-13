import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart'; // Medya linklerini açmak için eklendi

class SikayetYonetimPage extends StatelessWidget {
  const SikayetYonetimPage({Key? key}) : super(key: key);

  // Status durumlarına göre Türkçe metin ve renk döndüren yardımcı metot
  Map<String, dynamic> _getStatusDetails(String status, bool isAnswered) {
    if (isAnswered) return {'text': 'Cevaplandı ✅', 'color': Colors.green};
    switch (status) {
      case 'read':
        return {'text': 'Okundu 👀', 'color': Colors.blue};
      case 'on_hold':
        return {'text': 'İncelemede / Bekliyor ⏳', 'color': Colors.orange};
      default:
        return {'text': 'Yeni Mesaj 🔴', 'color': Colors.redAccent};
    }
  }

  // Durum güncelleme butonu fonksiyonu
  Future<void> _updateStatus(
      BuildContext context, String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('requests_complaints')
          .doc(docId)
          .update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Durum güncellendi!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Hata oluştu!"), backgroundColor: Colors.red),
      );
    }
  }

  // Medya (Resim/Video) açma fonksiyonu
  Future<void> _openMedia(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("İstek & Şikayetler",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests_complaints')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          var docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Text("Henüz bir başvuru yok.",
                    style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;

              // 🔥 KULLANICI BİLGİLERİ (Firestore'da hangi isimle kayıtlıysa onu çeker)
              String userId = data['userId'] ?? "";
              String userName = data['userName'] ??
                  data['fullname'] ??
                  data['name'] ??
                  "İsimsiz Kullanıcı";
              String userPhone =
                  data['userPhone'] ?? data['phone'] ?? "Telefon Yok";

              String status = data['status'] ?? 'pending';
              bool isAnswered = data.containsKey('adminReply') &&
                  data['adminReply'].toString().isNotEmpty;
              var statusInfo = _getStatusDetails(status, isAnswered);
              String mediaUrl = data['mediaUrl'] ?? data['imageUrl'] ?? "";

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  leading: CircleAvatar(
                    backgroundColor: data['type'] == 'İstek'
                        ? Colors.blue.shade50
                        : Colors.red.shade50,
                    child: Icon(
                      data['type'] == 'İstek'
                          ? Icons.lightbulb_outline
                          : Icons.warning_amber_rounded,
                      color: data['type'] == 'İstek'
                          ? Colors.blue.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  title: Text(
                    data['subject'] ?? "Konu Belirtilmemiş",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 10, color: statusInfo['color']),
                        const SizedBox(width: 5),
                        Text(
                          statusInfo['text'],
                          style: TextStyle(
                              color: statusInfo['color'],
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔥 KULLANICI DETAYLARI KARTI
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.person_alt_circle,
                                    size: 40, color: Colors.blueGrey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(userName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(userPhone,
                                          style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          // 🔥 MESAJ DETAYI
                          Text("MESAJ İÇERİĞİ:",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blueGrey.shade400)),
                          const SizedBox(height: 5),
                          Text(data['message'] ?? "Mesaj içeriği boş.",
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.4)),

                          // 🔥 MEDYA (RESİM/VİDEO) GÖRÜNTÜLEME
                          if (mediaUrl.isNotEmpty) ...[
                            const SizedBox(height: 15),
                            InkWell(
                              onTap: () => _openMedia(mediaUrl),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 10),
                                decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.blue.shade100)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.perm_media_outlined,
                                        color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Text("Ekli Dosyayı Gör (Resim/Video)",
                                        style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const Divider(height: 30),

                          // 🔥 YENİ: OKUNDU VE BEKLEMEYE AL BUTONLARI
                          if (!isAnswered) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _updateStatus(context, docId, 'read'),
                                    icon: const Icon(Icons.done_all, size: 18),
                                    label: const Text("Okundu Yap"),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus(
                                        context, docId, 'on_hold'),
                                    icon: const Icon(Icons.pause_circle_outline,
                                        size: 18),
                                    label: const Text("Beklemeye Al"),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                          ],

                          // 🔥 CEVAP BÖLÜMÜ
                          if (isAnswered) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.green.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings,
                                          color: Colors.green.shade700,
                                          size: 16),
                                      const SizedBox(width: 5),
                                      Text("SENİN CEVABIN:",
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(data['adminReply'],
                                      style: const TextStyle(
                                          fontSize: 15, color: Colors.black87)),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Cevap Input Alanı
                            _AdminCevapInput(docId: docId, userId: userId),
                          ],
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminCevapInput extends StatefulWidget {
  final String docId;
  final String userId;
  const _AdminCevapInput({required this.docId, required this.userId});

  @override
  State<_AdminCevapInput> createState() => _AdminCevapInputState();
}

class _AdminCevapInputState extends State<_AdminCevapInput> {
  final TextEditingController _cevapController = TextEditingController();
  bool _isSending = false;

  Future<void> _cevapGonder() async {
    if (_cevapController.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    try {
      // 1. Şikayete cevabı ekle ve durumu çözüldü yap
      await FirebaseFirestore.instance
          .collection('requests_complaints')
          .doc(widget.docId)
          .update({
        'adminReply': _cevapController.text.trim(),
        'status': 'resolved',
        'repliedAt': FieldValue.serverTimestamp(),
      });

      // 2. Kullanıcıya bildirim gönder
      if (widget.userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'to': widget.userId,
          'title': "Şikayetiniz / Talebiniz Cevaplandı 📢",
          'message': _cevapController.text.trim(),
          'time': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'complaint_reply'
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cevap başarıyla iletildi! ✅"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("VATANDAŞA CEVAP YAZ:",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey.shade400)),
        const SizedBox(height: 5),
        TextField(
          controller: _cevapController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Sorunu çözdüğünüzü belirten bir mesaj yazın...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blueAccent)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _cevapGonder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isSending
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
                _isSending ? "Gönderiliyor..." : "Cevapla ve Bildirim Gönder",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
