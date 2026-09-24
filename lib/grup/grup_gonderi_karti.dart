import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:pazarcik_portal/widgets/interactive_media_viewer.dart';
import 'package:pazarcik_portal/widgets/fullscreen_video_player.dart';

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
  bool _isAdmin = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _checkSavedStatus();
  }

  Future<void> _checkAdminStatus() async {
    if (currentUserId.isEmpty) return;
    try {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdTokenResult();
      final claims = token?.claims ?? const <String, dynamic>{};
      final claimRole = (claims['role'] ?? claims['rol'] ?? claims['userRole'])
          ?.toString()
          .toLowerCase()
          .trim();
      bool isAdmin = claims['admin'] == true ||
          claims['isAdmin'] == true ||
          claimRole == 'admin' ||
          claimRole == 'yonetici' ||
          claimRole == 'yönetici';

      if (!isAdmin) {
        final doc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(currentUserId)
            .get();
        final role =
            (doc.data()?['role'] ?? '').toString().toLowerCase().trim();
        if (role == 'admin' || role == 'yonetici' || role == 'yönetici') {
          isAdmin = true;
        }
      }

      if (mounted && _isAdmin != isAdmin) {
        setState(() => _isAdmin = isAdmin);
      }
    } catch (e) {
      debugPrint("Admin yetki kontrol hatası: $e");
    }
  }

  Future<void> _checkSavedStatus() async {
    if (currentUserId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUserId)
          .collection('saved_posts')
          .doc(widget.postId)
          .get();
      if (mounted && doc.exists) {
        setState(() => _isSaved = true);
      }
    } catch (_) {}
  }

  // --- REAKSİYON İŞLEMİ ---
  Future<void> _toggleReaction(String reactionType) async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tepki vermek için giriş yapmalısınız.")),
      );
      return;
    }

    final postRef =
        FirebaseFirestore.instance.collection('group_posts').doc(widget.postId);

    final reactions = Map<String, dynamic>.from(widget.data['reactions'] ?? {});
    final currentReaction = reactions[currentUserId];

    if (currentReaction == reactionType) {
      // Tepkiyi kaldır
      reactions.remove(currentUserId);
      await postRef.update({
        'reactions': reactions,
        'likes': FieldValue.arrayRemove([currentUserId]),
      });
    } else {
      // Yeni tepkiyi kaydet
      reactions[currentUserId] = reactionType;
      await postRef.update({
        'reactions': reactions,
        'likes': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  // --- KAYDETME İŞLEMİ ---
  Future<void> _toggleSave() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kaydetmek için giriş yapmalısınız.")),
      );
      return;
    }

    final savedRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(currentUserId)
        .collection('saved_posts')
        .doc(widget.postId);

    try {
      if (_isSaved) {
        await savedRef.delete();
        if (mounted) {
          setState(() => _isSaved = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gönderi kayıtlılardan çıkarıldı.")),
          );
        }
      } else {
        await savedRef.set({
          'postId': widget.postId,
          'savedAt': FieldValue.serverTimestamp(),
          'authorName': widget.data['authorName'] ?? '',
          'content': widget.data['content'] ?? '',
        });
        if (mounted) {
          setState(() => _isSaved = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gönderi kaydedildi!"), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("İşlem başarısız: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- PAYLAŞMA İŞLEMİ ---
  void _sharePost() {
    final author = widget.data['authorName'] ?? "Kullanıcı";
    final content = widget.data['content'] ?? "";
    final shareUrl = "https://www.pazarcikportal.com";

    Share.share(
      "Pazarcık Portal Meydanında $author bir paylaşım yaptı:\n\n"
      "\"$content\"\n\n"
      "Detaylar ve topluluk sohbeti için:\n$shareUrl",
    );
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
                    await FirebaseFirestore.instance
                        .collection('group_reports')
                        .add({
                      'postId': widget.postId,
                      'reportedUserId': widget.data['authorId'],
                      'reporterId': currentUserId,
                      'reason': reason,
                      'status': 'Bekliyor',
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
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Oy kullanmak için giriş yapmalısınız.")),
      );
      return;
    }

    var postRef =
        FirebaseFirestore.instance.collection('group_posts').doc(widget.postId);

    await postRef.set({
      'pollData': {
        'votes': {currentUserId: option}
      }
    }, SetOptions(merge: true));
  }

  // --- ANKETİ BİLDİRİM OLARAK GÖNDERME ---
  Future<void> _broadcastPollNotification(
      Map<String, dynamic> pollData) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu işlem için yönetici yetkisi gerekiyor."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final question = (pollData['question'] ?? 'Grup Anketi').toString();
    final options = List<String>.from(pollData['options'] ?? []);

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Anketi Bildirim Gönder"),
        content: Text(
          "\"$question\" anketini tüm kullanıcılara anlık push bildirim olarak göndermek istiyor musunuz?",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Gönder"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docRef =
          await FirebaseFirestore.instance.collection('app_notifications').add({
        'title': '📊 Yeni Anket: $question',
        'body': 'Pazarcık Meydanı\'nda yeni bir anket başladı. Katılmak ve oy kullanmak için dokunun!',
        'type': 'Anket',
        'targetType': 'group_poll',
        'targetId': widget.postId,
        'targetLabel': question,
        'pollOptions': options,
        'senderId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'pushStatus': 'queued',
      });

      await FirebaseFirestore.instance
          .collection('notification_send_requests')
          .add({
        'notificationId': docRef.id,
        'title': '📊 Yeni Anket: $question',
        'body': 'Pazarcık Meydanı\'nda yeni bir anket başladı. Katılmak ve oy kullanmak için dokunun!',
        'type': 'Anket',
        'targetType': 'group_poll',
        'targetId': widget.postId,
        'targetLabel': question,
        'pollOptions': options,
        'topic': 'pazarcik_duyuru',
        'requestedBy': currentUserId,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("📢 Anket başarıyla tüm kullanıcılara bildirim gönderildi!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    }
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
    int commentCount = widget.data['commentCount'] ?? 0;

    String content = widget.data['content'] ?? "";
    List images = widget.data['imageUrls'] ?? [];
    String videoUrl = (widget.data['videoUrl'] ?? "").toString().trim();
    Map<String, dynamic>? pollData = widget.data['pollData'];
    final String location = (widget.data['location'] ?? 'Pazarcık').toString();

    // Reaksiyon sayıları
    final Map<String, dynamic> reactions =
        Map<String, dynamic>.from(widget.data['reactions'] ?? {});
    final List likes = widget.data['likes'] ?? [];

    final myReaction = reactions[currentUserId] ??
        (likes.contains(currentUserId) ? 'love' : null);

    int helpfulCount = 0;
    int loveCount = 0;
    int funnyCount = 0;
    int seenCount = 0;

    reactions.forEach((k, v) {
      if (v == 'helpful') helpfulCount++;
      if (v == 'love') loveCount++;
      if (v == 'funny') funnyCount++;
      if (v == 'seen') seenCount++;
    });

    if (reactions.isEmpty && likes.isNotEmpty) {
      loveCount = likes.length;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEFEFF4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KART BAŞLIĞI (Avatar, Kullanıcı Adı, Konum ve Menü)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5E62), Color(0xFFFF7E40)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: widget.data['authorAvatar'] != null &&
                            widget.data['authorAvatar'].toString().isNotEmpty
                        ? Image.network(
                            widget.data['authorAvatar'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                CupertinoIcons.person_fill,
                                color: Colors.white,
                                size: 22),
                          )
                        : const Icon(CupertinoIcons.person_fill,
                            color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.data['authorName'] ?? "Kullanıcı",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Pazarcık",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(CupertinoIcons.location_solid,
                              size: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            location,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "• ${_formatTime(widget.data['createdAt'] as Timestamp?)}",
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.ellipsis,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        actions: [
                          if (_isAdmin && pollData != null)
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.pop(context);
                                _broadcastPollNotification(pollData);
                              },
                              child: const Text(
                                  "📢 Anketi Bildirim Olarak Yayınla",
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ),
                          if (isAuthor || _isAdmin)
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
              child: Text(
                content,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.45,
                  color: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF2C2C2E),
                ),
              ),
            ),

          // 3. FOTOĞRAFLAR
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildImageGallery(images),
                ),
              ),
            ),

          // 3.5 VİDEO (Eğer Varsa)
          if (videoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _PostVideoPlayer(videoUrl: videoUrl),
              ),
            ),

          // 4. ANKET (Eğer Varsa)
          if (pollData != null) _buildPollUI(pollData, isDark),

          // 5. REAKSİYON İKONLARI (Faydalı, Beğendim, Güldüm, Gördüm)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                _buildReactionChip(
                  icon: "⭐",
                  label: "Faydalı",
                  count: helpfulCount,
                  isSelected: myReaction == 'helpful',
                  color: Colors.amber,
                  onTap: () => _toggleReaction('helpful'),
                ),
                _buildReactionChip(
                  icon: "❤️",
                  label: "Beğendim",
                  count: loveCount,
                  isSelected: myReaction == 'love',
                  color: Colors.redAccent,
                  onTap: () => _toggleReaction('love'),
                ),
                _buildReactionChip(
                  icon: "😂",
                  label: "Güldüm",
                  count: funnyCount,
                  isSelected: myReaction == 'funny',
                  color: Colors.orange,
                  onTap: () => _toggleReaction('funny'),
                ),
                _buildReactionChip(
                  icon: "👁️",
                  label: "Gördüm",
                  count: seenCount,
                  isSelected: myReaction == 'seen',
                  color: const Color(0xFFFF5E62),
                  onTap: () => _toggleReaction('seen'),
                ),
              ],
            ),
          ),

          const Divider(height: 16, thickness: 0.8),

          // 6. ALT AKSİYON ÇUBUĞU (Yorum, Paylaş, Kaydet)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                // Yorum Yap
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) =>
                            GrupYorumlariEkran(postId: widget.postId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.chat_bubble,
                            size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        const SizedBox(width: 5),
                        Text(
                          "$commentCount Yorum",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Paylaş
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _sharePost,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.share,
                            size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        const SizedBox(width: 5),
                        Text(
                          "Paylaş",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Kaydet
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _toggleSave,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          _isSaved
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          size: 18,
                          color: _isSaved
                              ? const Color(0xFFFF5E62)
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isSaved ? "Kaydedildi" : "Kaydet",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isSaved
                                ? const Color(0xFFFF5E62)
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChip({
    required String icon,
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: color.withOpacity(0.4), width: 1) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                count > 0 ? "$label $count" : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dinamik Resim Gösterimi (En fazla 4 resim, tıklandığında tam ekran büyür ve kaydırılabilir)
  Widget _buildImageGallery(List images) {
    List<String> validUrls = images.map((e) => e.toString()).toList();
    if (validUrls.isEmpty) return const SizedBox.shrink();

    // Kullanıcı talebi: En fazla 4 resim olsun, yer kaplamasın
    if (validUrls.length > 4) {
      validUrls = validUrls.take(4).toList();
    }

    if (validUrls.length == 1) {
      return GestureDetector(
        onTap: () => InteractiveMediaViewer.show(
          context,
          imageUrls: validUrls,
          initialIndex: 0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            validUrls[0],
            fit: BoxFit.cover,
            width: double.infinity,
            height: 240,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: validUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => InteractiveMediaViewer.show(
              context,
              imageUrls: validUrls,
              initialIndex: index,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                validUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  // İnteraktif Anket Arayüzü
  Widget _buildPollUI(Map<String, dynamic> pollData, bool isDark) {
    String question = pollData['question'] ?? "";
    List options = pollData['options'] ?? [];
    Map votes = pollData['votes'] ?? {};

    int totalVotes = votes.length;
    String myVote = votes[currentUserId] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.chart_bar_alt_fill,
                  size: 18, color: Color(0xFFFF5E62)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      height: 42,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: isMySelection
                            ? Border.all(color: const Color(0xFFFF5E62), width: 1.5)
                            : Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade200),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage > 0 ? percentage : 0.001,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isMySelection
                              ? const Color(0xFFFF5E62).withOpacity(0.25)
                              : const Color(0xFFFF7E40).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontWeight: isMySelection
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isMySelection
                                      ? const Color(0xFFFF5E62)
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              "${(percentage * 100).toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isMySelection
                                    ? const Color(0xFFFF5E62)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "$totalVotes oy kullanıldı",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 GÖNDERİ İÇİ VİDEO OYNATICI VE TAM EKRAN BUTONU
class _PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _PostVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.setVolume(_isMuted ? 0 : 1.0);
          _controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen() async {
    final wasPlaying = _controller.value.isPlaying;
    if (wasPlaying) {
      _controller.pause();
    }
    final newPos = await FullscreenVideoPlayer.open(
      context,
      videoUrl: widget.videoUrl,
      initialPosition: _controller.value.position,
      autoPlay: true,
    );
    if (mounted && newPos != null) {
      _controller.seekTo(newPos);
      if (wasPlaying) _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: CupertinoActivityIndicator(
            color: Color(0xFFFF5E62),
            radius: 14,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio > 0
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(_controller),
            ),
            // Oynat / Durdur Butonu (Ortada)
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            // Alt Kontrol Çubuğu (Ses, İlerleme ve Tam Ekran)
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  // Ses Butonu
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _controller.setVolume(_isMuted ? 0 : 1.0);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted
                            ? CupertinoIcons.volume_off
                            : CupertinoIcons.volume_up,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // İlerleme çubuğu
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFFFF5E62),
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tam Ekran Butonu
                  GestureDetector(
                    onTap: _openFullscreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.fullscreen,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Tam Ekran",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
