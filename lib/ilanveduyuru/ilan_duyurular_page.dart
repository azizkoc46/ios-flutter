// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // Paylaşım özelliği için eklendi

class IlanDuyurularPage extends StatefulWidget {
  const IlanDuyurularPage({super.key});

  @override
  State<IlanDuyurularPage> createState() => _IlanDuyurularPageState();
}

class _IlanDuyurularPageState extends State<IlanDuyurularPage> {
  String selectedCategory = "Tümü";

  final List<String> categories = const [
    "Tümü",
    "Genel",
    "Duyuru",
    "Etkinlik",
    "Cenaze",
    "Acil",
  ];

  Stream<QuerySnapshot> _announcementStream() {
    Query query = FirebaseFirestore.instance
        .collection('announcements')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (selectedCategory != "Tümü") {
      query = FirebaseFirestore.instance
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: selectedCategory)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case "Etkinlik":
        return const Color(0xFF7C3AED);
      case "Cenaze":
        return const Color(0xFF374151);
      case "Acil":
        return const Color(0xFFDC2626);
      case "Duyuru":
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFFF97316);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case "Etkinlik":
        return CupertinoIcons.calendar_badge_plus;
      case "Cenaze":
        return CupertinoIcons.heart_slash;
      case "Acil":
        return CupertinoIcons.exclamationmark_triangle_fill;
      case "Duyuru":
        return CupertinoIcons.speaker_2_fill;
      default:
        return CupertinoIcons.info_circle_fill;
    }
  }

  // Liste görünümü için göreceli tarih (Az önce, Dün vs.)
  String _formatDateRelative(Timestamp? timestamp) {
    if (timestamp == null) return "Şimdi";

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return "Az önce";
    if (difference.inMinutes < 60) return "${difference.inMinutes} dk önce";
    if (difference.inHours < 24) return "${difference.inHours} saat önce";
    if (difference.inDays == 1) return "Dün";
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  // Detay ve Paylaşım için tam ve net tarih formatı
  String _formatDateExact(Timestamp? timestamp) {
    if (timestamp == null) return "Bilinmeyen Tarih";
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day.$month.$year - $hour:$minute";
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // İlan detayını dışarıya metin olarak paylaşma fonksiyonu
  void _shareAnnouncement(
      String title, String body, String exactDate, String category) {
    final String shareText =
        "📢 $category: $title\n\n$body\n\n🗓️ İlan Tarihi: $exactDate";
    Share.share(shareText);
  }

  void _showDetail(Map<String, dynamic> data) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String title = data['title'] ?? 'Başlıksız';
    final String body = data['body'] ?? '';
    final String imageUrl = (data['imageUrl'] ?? '').toString();
    final String videoUrl = (data['videoUrl'] ?? '').toString();
    final String category = data['category'] ?? 'Genel';
    final Timestamp? createdAt = data['createdAt'];

    final Color color = _categoryColor(category);
    final String exactDate = _formatDateExact(createdAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: 230,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 230,
                          color:
                              isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          child: const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 230,
                          color:
                              isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  if (imageUrl.isNotEmpty) const SizedBox(height: 18),

                  // Kategori, Tam Tarih ve Paylaş Butonu Satırı
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_categoryIcon(category),
                                size: 15, color: color),
                            const SizedBox(width: 6),
                            Text(
                              category,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Tam Tarih Görünümü
                      Expanded(
                        child: Text(
                          exactDate,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                      // Paylaş Butonu
                      IconButton(
                        onPressed: () => _shareAnnouncement(
                            title, body, exactDate, category),
                        icon: const Icon(CupertinoIcons.share),
                        color: isDark ? Colors.white70 : Colors.black87,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  if (videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openVideo(videoUrl),
                        icon: const Icon(CupertinoIcons.play_circle_fill),
                        label: const Text("Videoyu Aç"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "İlan ve Duyurular",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final bool active = selectedCategory == category;
                final Color color = _categoryColor(category);

                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: active
                          ? color
                          : isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: active
                            ? color
                            : isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _announcementStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text("Duyurular yüklenemedi."),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Henüz ilan veya duyuru yok.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final String title = data['title'] ?? 'Başlıksız';
                    final String body = data['body'] ?? '';
                    final String imageUrl = (data['imageUrl'] ?? '').toString();
                    final String videoUrl = (data['videoUrl'] ?? '').toString();
                    final String category = data['category'] ?? 'Genel';
                    final Timestamp? createdAt = data['createdAt'];

                    final Color color = _categoryColor(category);

                    return GestureDetector(
                      onTap: () => _showDetail(data),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF111827) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.22)
                                  : Colors.black.withOpacity(0.045),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl.isNotEmpty)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: double.infinity,
                                      height: 170,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (videoUrl.isNotEmpty)
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.45),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.play_fill,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Listede Göreceli Tarih (Örn: 5 dk önce) kalmaya devam ediyor
                                      Text(
                                        _formatDateRelative(createdAt),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.2,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
