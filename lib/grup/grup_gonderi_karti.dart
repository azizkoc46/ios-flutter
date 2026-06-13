import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 Yorumlar sayfasını içeri aktarıyoruz
import 'grup_yorumlari_ekran.dart';

class GrupGonderiKarti extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;

  const GrupGonderiKarti({Key? key, required this.postId, required this.data})
      : super(key: key);

  @override
  State<GrupGonderiKarti> createState() => _GrupGonderiKartiState();
}

class _GrupGonderiKartiState extends State<GrupGonderiKarti> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  // --- BEĞENİ İŞLEMİ ---
  Future<void> _toggleLike() async {
    if (currentUserId.isEmpty) return;

    List likes = widget.data['likes'] ?? [];
    bool isLiked = likes.contains(currentUserId);

    var postRef =
        FirebaseFirestore.instance.collection('group_posts').doc(widget.postId);

    if (isLiked) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  // --- GÖNDERİ SİLME ---
  Future<void> _deletePost() async {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Gönderiyi Sil"),
        content: const Text(
            "Bu gönderiyi kalıcı olarak silmek istediğinize emin misiniz?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("İptal", style: TextStyle(color: Colors.blue)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('group_posts')
                  .doc(widget.postId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Gönderi silindi."),
                      backgroundColor: Colors.redAccent),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // --- GÖNDERİ ŞİKAYET ETME ---
  Future<void> _reportPost() async {
    List<String> reasons = [
      "Spam / Reklam",
      "Nefret Söylemi",
      "Yanlış Bilgi",
      "Rahatsız Edici İçerik",
      "Diğer"
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Gönderiyi Şikayet Et",
            style: TextStyle(color: Colors.red)),
        message: const Text(
            "Bu gönderiyi neden şikayet ediyorsunuz? Yönetim ekibimiz inceleyecektir."),
        actions: reasons
            .map((reason) => CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Şikayeti Firestore'a kaydet (Admin paneli için)
                    await FirebaseFirestore.instance
                        .collection('group_reports')
                        .add({
                      'postId': widget.postId,
                      'reportedUserId': widget.data['authorId'],
                      'reporterId': currentUserId,
                      'reason': reason,
                      'status': 'Bekliyor', // Admin incelemesi için
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Şikayetiniz yönetime iletildi. Teşekkürler!"),
                            backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: Text(reason,
                      style: const TextStyle(color: Colors.black87)),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text("İptal", style: TextStyle(color: Colors.blue)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // --- ANKET OY KULLANMA ---
  Future<void> _votePoll(String option) async {
    if (currentUserId.isEmpty) return;

    var postRef =
        FirebaseFirestore.instance.collection('group_posts').doc(widget.postId);

    // Yalnızca 1 kere oy kullanabilir, oyu değiştirebilir.
    await postRef.set({
      'pollData': {
        'votes': {currentUserId: option}
      }
    }, SetOptions(merge: true));
  }

  // --- TARİH FORMATLAMA ---
  String _formatTime(Timestamp? time) {
    if (time == null) return "Şimdi";
    Duration diff = DateTime.now().difference(time.toDate());
    if (diff.inMinutes < 1) return "Az önce";
    if (diff.inHours < 1) return "${diff.inMinutes} d";
    if (diff.inDays < 1) return "${diff.inHours} s";
    if (diff.inDays < 7) return "${diff.inDays} g";
    return "${time.toDate().day}/${time.toDate().month}/${time.toDate().year}";
  }

  @override
  Widget build(BuildContext context) {
    bool isAuthor = widget.data['authorId'] == currentUserId;
    List likes = widget.data['likes'] ?? [];
    bool isLiked = likes.contains(currentUserId);
    int commentCount = widget.data['commentCount'] ?? 0;

    String content = widget.data['content'] ?? "";
    List images = widget.data['imageUrls'] ?? [];
    Map<String, dynamic>? pollData = widget.data['pollData'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KART BAŞLIĞI (Profil Fotocusu, İsim, Tarih ve 3 Nokta)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: widget.data['authorAvatar'] != null &&
                          widget.data['authorAvatar'].toString().isNotEmpty
                      ? NetworkImage(widget.data['authorAvatar'])
                      : null,
                  child: widget.data['authorAvatar'] == null ||
                          widget.data['authorAvatar'].toString().isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.data['authorName'] ?? "Kullanıcı",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Row(
                        children: [
                          Text(
                              _formatTime(
                                  widget.data['createdAt'] as Timestamp?),
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(width: 4),
                          Icon(Icons.public,
                              size: 12, color: Colors.grey.shade600),
                        ],
                      ),
                    ],
                  ),
                ),
                // Kendi gönderisiyse SİL, başkasınınsa ŞİKAYET ET seçenekleri
                IconButton(
                  icon: const Icon(CupertinoIcons.ellipsis, color: Colors.grey),
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        actions: [
                          if (isAuthor)
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () {
                                Navigator.pop(context);
                                _deletePost();
                              },
                              child: const Text("Gönderiyi Sil"),
                            )
                          else
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () {
                                Navigator.pop(context);
                                _reportPost();
                              },
                              child: const Text("Gönderiyi Şikayet Et"),
                            )
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          child: const Text("İptal"),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 2. İÇERİK METNİ
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(content, style: const TextStyle(fontSize: 15)),
            ),

          // 3. FOTOĞRAFLAR (Eğer Varsa)
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildImageGallery(images),
            ),

          // 4. ANKET (Eğer Varsa)
          if (pollData != null) _buildPollUI(pollData),

          // 5. İSTATİSTİKLER (Beğeni ve Yorum Sayısı)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.thumb_up,
                          color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 6),
                    Text("${likes.length}",
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                Text("$commentCount Yorum",
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // 6. AKSİYON BUTONLARI (Beğen, Yorum Yap, Paylaş)
          Row(
            children: [
              _buildActionButton(
                icon: isLiked
                    ? CupertinoIcons.hand_thumbsup_fill
                    : CupertinoIcons.hand_thumbsup,
                label: "Beğen",
                color: isLiked ? Colors.blue : Colors.grey.shade700,
                onTap: _toggleLike,
              ),
              // 🔥 Yorum sayfasına yönlendirme aktif edildi
              _buildActionButton(
                icon: CupertinoIcons.chat_bubble,
                label: "Yorum Yap",
                color: Colors.grey.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) =>
                          GrupYorumlariEkran(postId: widget.postId),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dinamik Resim Gösterimi (1 resim tam boy, 2+ resim grid)
  Widget _buildImageGallery(List images) {
    if (images.length == 1) {
      return Image.network(images[0],
          fit: BoxFit.cover, width: double.infinity);
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 2, mainAxisSpacing: 2),
        itemCount: images.length > 4 ? 4 : images.length,
        itemBuilder: (context, index) {
          if (index == 3 && images.length > 4) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(images[index], fit: BoxFit.cover),
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Text("+${images.length - 4}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
          return Image.network(images[index], fit: BoxFit.cover);
        },
      );
    }
  }

  // İnteraktif Anket Arayüzü
  Widget _buildPollUI(Map<String, dynamic> pollData) {
    String question = pollData['question'] ?? "";
    List options = pollData['options'] ?? [];
    Map votes = pollData['votes'] ?? {};

    int totalVotes = votes.length;
    String myVote = votes[currentUserId] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...options.map((option) {
            int optionVotes = votes.values.where((v) => v == option).length;
            double percentage = totalVotes == 0 ? 0 : optionVotes / totalVotes;
            bool isMySelection = myVote == option;

            return GestureDetector(
              onTap: () => _votePoll(option),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  children: [
                    Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: isMySelection
                            ? Border.all(color: Colors.blue)
                            : null,
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isMySelection
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(option,
                                    style: TextStyle(
                                        fontWeight: isMySelection
                                            ? FontWeight.bold
                                            : FontWeight.normal))),
                            Text("${(percentage * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
          Text("$totalVotes oy",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
