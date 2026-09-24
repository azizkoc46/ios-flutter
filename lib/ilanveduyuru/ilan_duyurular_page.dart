// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pazarcik_portal/admin/admin_announcements_tab.dart';

class IlanDuyurularPage extends StatefulWidget {
  const IlanDuyurularPage({super.key});

  @override
  State<IlanDuyurularPage> createState() => _IlanDuyurularPageState();
}

class _IlanDuyurularPageState extends State<IlanDuyurularPage> {
  String selectedCategory = "Tümü";
  String searchQuery = "";
  bool _isAdmin = false;

  final List<String> categories = const [
    "Tümü",
    "Duyuru",
    "Etkinlik",
    "Acil",
    "Cenaze",
    "Genel",
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await user.getIdTokenResult();
      final claims = token.claims ?? {};
      if (claims['admin'] == true || claims['role'] == 'admin') {
        if (mounted) setState(() => _isAdmin = true);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString();
      if (role == 'admin' || role == 'superadmin') {
        if (mounted) setState(() => _isAdmin = true);
      }
    } catch (_) {}
  }

  Stream<QuerySnapshot> _announcementStream() {
    return FirebaseFirestore.instance
        .collection('announcements')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
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
        return const Color(0xFF10B981);
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
        return CupertinoIcons.sparkles;
    }
  }

  String _formatDateTimeRange(dynamic startVal, dynamic endVal) {
    DateTime? start;
    DateTime? end;

    if (startVal is Timestamp) start = startVal.toDate();
    if (startVal is String && startVal.isNotEmpty) start = DateTime.tryParse(startVal);

    if (endVal is Timestamp) end = endVal.toDate();
    if (endVal is String && endVal.isNotEmpty) end = DateTime.tryParse(endVal);

    if (start == null && end == null) return "";

    final months = [
      "", "Oca", "Şub", "Mar", "Nis", "May", "Haz",
      "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"
    ];

    if (start != null && end != null) {
      final sDay = start.day;
      final sMonth = months[start.month];
      final sTime = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";

      final eDay = end.day;
      final eMonth = months[end.month];
      final eTime = "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";

      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return "$sDay $sMonth • $sTime - $eTime";
      }
      return "$sDay $sMonth $sTime – $eDay $eMonth $eTime";
    }

    if (start != null) {
      final sDay = start.day;
      final sMonth = months[start.month];
      final sTime = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
      return "$sDay $sMonth • $sTime";
    }

    final eDay = end!.day;
    final eMonth = months[end.month];
    final eTime = "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
    return "Bitiş: $eDay $eMonth • $eTime";
  }

  String _getEventStatus(dynamic startVal, dynamic endVal) {
    DateTime? start;
    DateTime? end;

    if (startVal is Timestamp) start = startVal.toDate();
    if (endVal is Timestamp) end = endVal.toDate();

    final now = DateTime.now();

    if (start != null && end != null) {
      if (now.isBefore(start)) return "Yakında";
      if (now.isAfter(end)) return "Sona Erdi";
      return "Devam Ediyor";
    }

    if (start != null) {
      if (now.isBefore(start)) return "Yakında";
      return "Aktif";
    }

    if (end != null) {
      if (now.isAfter(end)) return "Sona Erdi";
      return "Devam Ediyor";
    }

    return "";
  }

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

  String _formatDateExact(Timestamp? timestamp) {
    if (timestamp == null) return "Bilinmeyen Tarih";
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day.$month.$year • $hour:$minute";
  }

  Future<void> _increaseViewCount(String? docId) async {
    if (docId == null || docId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(docId)
          .set({
        'views': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _openVideoOrUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareAnnouncement({
    required String title,
    required String body,
    required String exactDate,
    required String category,
    String? location,
    String? eventDates,
  }) {
    String shareText = "📢 Pazarcık Bülteni | $category\n\n$title\n\n$body\n";
    if (eventDates != null && eventDates.isNotEmpty) {
      shareText += "\n🗓️ Tarih: $eventDates";
    }
    if (location != null && location.isNotEmpty) {
      shareText += "\n📍 Mekan: $location";
    }
    shareText += "\n🗓️ Yayın Tarihi: $exactDate\n\nPazarcık Portal Uygulamasından Paylaşıldı.";
    Share.share(shareText);
  }

  void _showDetail(String docId, Map<String, dynamic> data) {
    _increaseViewCount(docId);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = data['title'] ?? 'Başlıksız';
    final String body = data['body'] ?? '';
    final String imageUrl = (data['imageUrl'] ?? '').toString();
    final String videoUrl = (data['videoUrl'] ?? '').toString();
    final String category = data['category'] ?? 'Genel';
    final String location = (data['location'] ?? '').toString();
    final Timestamp? createdAt = data['createdAt'];
    final bool isUrgent = data['isUrgent'] == true || category == 'Acil';

    final Color color = _categoryColor(category);
    final String exactDate = _formatDateExact(createdAt);
    final String eventDateRange = _formatDateTimeRange(data['startDate'], data['endDate']);
    final String eventStatus = _getEventStatus(data['startDate'], data['endDate']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Büyük Dergi Kapağı
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            PortalNetworkImage(
                              url: imageUrl,
                              width: double.infinity,
                              height: 250,
                              fit: BoxFit.cover,
                            ),
                            if (isUrgent)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.exclamationmark_triangle_fill,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 5),
                                      Text(
                                        "🚨 ACİL BİLDİRİM",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategori, Tarih ve Paylaş Satırı
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_categoryIcon(category), size: 14, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    category.toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (eventStatus.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: eventStatus == "Devam Ediyor"
                                      ? Colors.green.withOpacity(0.12)
                                      : eventStatus == "Yakında"
                                          ? Colors.orange.withOpacity(0.12)
                                          : Colors.grey.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  eventStatus,
                                  style: TextStyle(
                                    color: eventStatus == "Devam Ediyor"
                                        ? Colors.green
                                        : eventStatus == "Yakında"
                                            ? Colors.orange
                                            : Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              onPressed: () => _shareAnnouncement(
                                title: title,
                                body: body,
                                exactDate: exactDate,
                                category: category,
                                location: location,
                                eventDates: eventDateRange,
                              ),
                              icon: const Icon(CupertinoIcons.share),
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Başlık
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Etkinlik Tarihi Kartı (iPhone Apple Calendar Style)
                        if (eventDateRange.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF7C3AED).withOpacity(0.12),
                                  const Color(0xFF6366F1).withOpacity(0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFF7C3AED).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.calendar_today,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "ETKİNLİK TARİHİ & SAATİ",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF7C3AED),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        eventDateRange,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Mekan / Konum Kartı
                        if (location.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.location_solid,
                                    size: 18, color: Colors.redAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Metin İçeriği
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Video / Bağlantı Butonu
                        if (videoUrl.isNotEmpty) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openVideoOrUrl(videoUrl),
                              icon: const Icon(CupertinoIcons.play_circle_fill),
                              label: const Text("Bağlantıyı / Videoyu Aç"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Yayın Tarihi Dipnotu
                        Row(
                          children: [
                            Icon(CupertinoIcons.clock, size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 5),
                            Text(
                              "Yayınlanma: $exactDate",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              "Şehir Bülteni & Etkinlik",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Text(
              "Pazarcık Yaşam & Duyurular",
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: "Yönetici Stüdyosu",
              icon: const Icon(CupertinoIcons.slider_horizontal_3, color: Color(0xFF6366F1)),
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text("Bülten & Etkinlik Stüdyosu"),
                        backgroundColor: Colors.white,
                        elevation: 0,
                      ),
                      body: const AdminAnnouncementsTab(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text("Bülten & Etkinlik Stüdyosu"),
                        backgroundColor: Colors.white,
                        elevation: 0,
                      ),
                      body: const AdminAnnouncementsTab(),
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(CupertinoIcons.sparkles, color: Colors.white),
              label: const Text(
                "Bülteni Yönet",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: Column(
        children: [
          // 1. Arama Çubuğu
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => searchQuery = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: "Duyuru, etkinlik veya haber ara...",
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => searchQuery = ""),
                      child: const Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          // 2. Kategori Pill Bar
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                final Color color = category == "Tümü" ? const Color(0xFF6366F1) : _categoryColor(category);

                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: active
                          ? color
                          : isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFF8FAFC),
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
                      child: Row(
                        children: [
                          if (category != "Tümü") ...[
                            Icon(
                              _categoryIcon(category),
                              size: 13,
                              color: active ? Colors.white : color,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            category,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Bülten & Etkinlik Akışı
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _announcementStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("İçerikler yüklenemedi."));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;

                // Kategori & Arama Filtreleme
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final cat = (data['category'] ?? 'Genel').toString();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final body = (data['body'] ?? '').toString().toLowerCase();

                  if (selectedCategory != "Tümü" && cat != selectedCategory) {
                    return false;
                  }

                  if (searchQuery.isNotEmpty) {
                    if (!title.contains(searchQuery) && !body.contains(searchQuery)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.sparkles, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 14),
                        Text(
                          "Bu filtrede henüz duyuru veya etkinlik yok.",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildMagazineCard(doc.id, data, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMagazineCard(String docId, Map<String, dynamic> data, bool isDark) {
    final String title = data['title'] ?? 'Başlıksız';
    final String body = data['body'] ?? '';
    final String imageUrl = (data['imageUrl'] ?? '').toString();
    final String category = data['category'] ?? 'Genel';
    final String location = (data['location'] ?? '').toString();
    final Timestamp? createdAt = data['createdAt'];
    final bool isUrgent = data['isUrgent'] == true || category == 'Acil';

    final Color color = _categoryColor(category);
    final String relativeDate = _formatDateRelative(createdAt);
    final String eventDateRange = _formatDateTimeRange(data['startDate'], data['endDate']);
    final String eventStatus = _getEventStatus(data['startDate'], data['endDate']);
    final int views = (data['views'] is num) ? (data['views'] as num).toInt() : 0;

    return GestureDetector(
      onTap: () => _showDetail(docId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUrgent
                ? Colors.red.withOpacity(0.5)
                : isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE2E8F0),
            width: isUrgent ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isUrgent
                  ? Colors.red.withOpacity(0.08)
                  : isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dergi Kapak Görseli veya Gradient Hero
            if (imageUrl.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: PortalNetworkImage(
                      url: imageUrl,
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Kategori & Acil Rozeti
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(category), size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                category.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              "🚨 ACİL",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (eventStatus.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          eventStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            // İçerik Alanı
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(category), size: 12, color: color),
                              const SizedBox(width: 5),
                              Text(
                                category.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              "🚨 ACİL",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          relativeDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Başlık
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),

                  // Açıklama Özeti
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  // Etkinlik Başlangıç & Bitiş Tarihi Şeridi
                  if (eventDateRange.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.calendar, size: 15, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              eventDateRange,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Mekan & Görüntülenme Alt Bilgisi
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (location.isNotEmpty) ...[
                        const Icon(CupertinoIcons.location_solid, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.eye, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "$views",
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (imageUrl.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          relativeDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
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
