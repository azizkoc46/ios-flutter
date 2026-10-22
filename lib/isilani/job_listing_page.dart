import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

import 'job_detail_page.dart';
import 'add_job_page.dart';
import 'my_jobs_page.dart';

class JobListingPage extends StatefulWidget {
  const JobListingPage({Key? key}) : super(key: key);

  @override
  State<JobListingPage> createState() => _JobListingPageState();
}

class _JobListingPageState extends State<JobListingPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "Tümü"; // "Tümü", "Aktif", "Tamamlananlar"

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAdmin = false;
  bool _jobNotificationsEnabled = false;

  final Color jobPrimaryColor = const Color(0xFF0284C7); // Kariyer Mavisi
  final Color jobAccentColor = const Color(0xFF0EA5E9);

  late AnimationController _glowController;
  late AnimationController _flameController;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadNotificationPreferences();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _glowController.dispose();
    _flameController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Varsayılan olarak pasif (false)
      final isEnabled = prefs.getBool('is_job_notifications_enabled') ?? false;
      final hasPrompted =
          prefs.getBool('has_prompted_job_notifications') ?? false;

      if (mounted) {
        setState(() {
          _jobNotificationsEnabled = isEnabled;
        });
      }

      // Sayfaya ilk kez girildiğinde ve henüz açılmamışsa şık Apple öneri modalı göster
      if (!hasPrompted && !isEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _showJobNotificationSuggestionModal();
            }
          });
        });
      }
    } catch (e) {
      debugPrint("İş bildirim tercihi okuma hatası: $e");
    }
  }

  Future<void> _toggleJobNotifications(bool enable,
      {bool isFromPrompt = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_job_notifications_enabled', enable);
      await prefs.setBool('has_prompted_job_notifications', true);

      if (!kIsWeb) {
        try {
          if (enable) {
            await FirebaseMessaging.instance.subscribeToTopic('is_ilanlari');
          } else {
            await FirebaseMessaging.instance.unsubscribeFromTopic('is_ilanlari');
          }
        } catch (e) {
          debugPrint("FCM topic kayıt hatası: $e");
        }
      }

      if (mounted) {
        setState(() {
          _jobNotificationsEnabled = enable;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  enable
                      ? CupertinoIcons.bell_fill
                      : CupertinoIcons.bell_slash,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enable
                        ? "İş ilanları bildirimleri açıldı! Yeni ilanlarda anında haberdar edileceksiniz."
                        : "İş ilanı bildirimleri kapatıldı.",
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor:
                enable ? const Color(0xFF0284C7) : const Color(0xFF475569),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Bildirim toggle hatası: $e");
    }
  }

  void _showJobNotificationSuggestionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS Drag Handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),

              // Glowing Icon Badge
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                "Yeni İş İlanlarından Haberdar Olun!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                "Pazarcık'ta yeni bir personel arayışı veya iş fırsatı yayınlandığında ilk sizin haberiniz olsun. İstediğiniz zaman üst menüdeki zil simgesinden kapatabilirsiniz.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: Aktif Et Butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleJobNotifications(true, isFromPrompt: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.bell_fill,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Hemen Bildirimleri Aktif Et",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary Action: Şimdilik Değil
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_prompted_job_notifications', true);
                  },
                  child: Text(
                    "Şimdilik Değil",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkAdminStatus() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
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
            .doc(_currentUserId)
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
      debugPrint("Admin kontrol hatası: $e");
    }
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    return null;
  }

  // Tarih Biçimlendirme (Göreceli ve Net Tarih)
  String _formatDate(dynamic timestamp) {
    final dt = _parseDate(timestamp);
    if (dt == null) return "Yeni";
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes <= 1) return "Az önce";
        return "${diff.inMinutes} dk önce";
      }
      return "${diff.inHours} saat önce";
    } else if (diff.inDays == 1) {
      return "Dün";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} gün önce";
    }
    return DateFormat('dd.MM.yyyy', 'tr_TR').format(dt);
  }

  bool _isJobExpired(Map<String, dynamic> job) {
    if (job['isHired'] == true ||
        job['status'] == 'filled' ||
        job['status'] == 'expired') {
      return true;
    }
    final endDate = _parseDate(job['applicationEndDate']);
    if (endDate != null) {
      final endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      return DateTime.now().isAfter(endOfDay);
    }
    return false;
  }

  bool _isJobLastDay(Map<String, dynamic> job) {
    if (_isJobExpired(job)) return false;
    final endDate = _parseDate(job['applicationEndDate']);
    if (endDate != null) {
      final endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      final now = DateTime.now();
      if (now.isAfter(endOfDay)) return false;
      final todayStart = DateTime(now.year, now.month, now.day);
      final endDayStart = DateTime(endDate.year, endDate.month, endDate.day);
      final calendarDays = endDayStart.difference(todayStart).inDays;
      return calendarDays <= 1;
    }
    return false;
  }

  int? _getRemainingDays(Map<String, dynamic> job) {
    if (_isJobExpired(job)) return null;
    final endDate = _parseDate(job['applicationEndDate']);
    if (endDate != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final endDayStart = DateTime(endDate.year, endDate.month, endDate.day);
      final calendarDays = endDayStart.difference(todayStart).inDays;
      if (calendarDays < 0) return 0;
      return calendarDays;
    }
    return null;
  }

  // İşe Alım Durumunu Değiştir (Yayınlayan veya Admin)
  Future<void> _toggleHiredStatus(String docId, bool currentHired) async {
    final newHired = !currentHired;
    try {
      await FirebaseFirestore.instance
          .collection('job_postings')
          .doc(docId)
          .update({
        'status': newHired ? 'filled' : 'active',
        'isHired': newHired,
        'hiredAt': newHired ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newHired
                ? "İlan işe alım gerçekleşti olarak işaretlendi."
                : "İlan yeniden aktif hale getirildi."),
            backgroundColor: newHired ? Colors.orange.shade800 : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("İşlem başarısız oldu: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // İlan Silme
  Future<void> _deleteJob(String docId) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text(
            "Bu iş ilanını kalıcı olarak silmek istediğinize emin misiniz?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('job_postings')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("İş ilanı silindi."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: jobPrimaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(CupertinoIcons.briefcase_fill,
                  size: 18, color: jobPrimaryColor),
            ),
            const SizedBox(width: 8),
            Text(
              "Pazarcık Kariyer",
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // İş İlanı Bildirim Çanı (Aktif / Pasif)
          Tooltip(
            message: _jobNotificationsEnabled
                ? "İş İlanı Bildirimleri Açık (Kapatmak için dokunun)"
                : "Yeni İş İlanı Bildirimlerini Aç",
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _toggleJobNotifications(!_jobNotificationsEnabled);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _jobNotificationsEnabled
                      ? jobPrimaryColor.withOpacity(0.14)
                      : (isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.04)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _jobNotificationsEnabled
                        ? jobPrimaryColor.withOpacity(0.35)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      _jobNotificationsEnabled
                          ? CupertinoIcons.bell_fill
                          : CupertinoIcons.bell,
                      size: 20,
                      color: _jobNotificationsEnabled
                          ? jobPrimaryColor
                          : (isDark
                              ? Colors.white54
                              : const Color(0xFF64748B)),
                    ),
                    if (_jobNotificationsEnabled)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF131B2E)
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.folder_badge_person_crop, size: 22),
            color: jobPrimaryColor,
            tooltip: "İlanlarım",
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("İlanlarınızı görüntülemek için lütfen önce giriş yapın."),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const MyJobsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. ÜST ARAMA & FİLTRELEME ÇUBUĞU
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Arama Kutusu (Apple Spotlight Tarzı)
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(CupertinoIcons.search,
                          color: const Color(0xFF0056D2), size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: "Pozisyon, meslek veya firma ara...",
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(CupertinoIcons.clear_circled_solid,
                                size: 18, color: Colors.grey.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Filtre Sekmeleri (Animasyonlu iOS Hap Butonlar)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip(
                          "Tümü", _selectedFilter == "Tümü", isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          "Aktif", _selectedFilter == "Aktif", isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip("🔥 Son Günler",
                          _selectedFilter == "🔥 Son Günler", isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip("Süresi Dolanlar",
                          _selectedFilter == "Süresi Dolanlar", isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 2. İLAN LİSTESİ (STREAM)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('job_postings')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 16),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text("Bir hata oluştu: ${snapshot.error}"),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(
                      "Henüz yayında iş ilanı bulunmuyor.", isDark);
                }

                var docs = snapshot.data!.docs;

                // Filtreleme: Arama ve Durum
                docs = docs.where((doc) {
                  final job = doc.data() as Map<String, dynamic>;
                  final isExpired = _isJobExpired(job);
                  final isLastDay = _isJobLastDay(job);
                  final remDays = _getRemainingDays(job);
                  final isClosingSoon =
                      isLastDay || (remDays != null && remDays <= 3);

                  // Sekme filtresi
                  if (_selectedFilter == "Aktif" && isExpired) return false;
                  if (_selectedFilter == "🔥 Son Günler" &&
                      (isExpired || !isClosingSoon)) {
                    return false;
                  }
                  if (_selectedFilter == "Süresi Dolanlar" && !isExpired) {
                    return false;
                  }

                  // Arama filtresi
                  if (_searchQuery.isNotEmpty) {
                    final title =
                        (job['title'] ?? "").toString().toLowerCase();
                    final company =
                        (job['companyName'] ?? "").toString().toLowerCase();
                    final desc =
                        (job['description'] ?? "").toString().toLowerCase();
                    if (!title.contains(_searchQuery) &&
                        !company.contains(_searchQuery) &&
                        !desc.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return _buildEmptyState(
                      "Aramanıza uygun ilan bulunamadı.", isDark);
                }

                // 🔥 AKILLI ÖNCELİK SIRALAMASI:
                // 1) Süresi dolan veya işe alım gerçekleşen ilanlar en alta (pasife) düşsün
                // 2) Aktif olanlar içinde: Son 1 gün kalan ilanlar en tepede kırmızı çerçeveyle parlasın
                // 3) Başvurusu yaklaşan aktif ilanlar üst sıralarda yer alsın
                // 4) Eşitlik durumunda en yeni eklenen ilanlar önce gelsin
                final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                sortedDocs.sort((a, b) {
                  final jobA = a.data() as Map<String, dynamic>;
                  final jobB = b.data() as Map<String, dynamic>;

                  final expA = _isJobExpired(jobA);
                  final expB = _isJobExpired(jobB);

                  if (expA != expB) {
                    return expA ? 1 : -1;
                  }

                  if (expA && expB) {
                    final cA = (jobA['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime(2000);
                    final cB = (jobB['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime(2000);
                    return cB.compareTo(cA);
                  }

                  final lastA = _isJobLastDay(jobA);
                  final lastB = _isJobLastDay(jobB);
                  if (lastA != lastB) {
                    return lastA ? -1 : 1;
                  }

                  final endA =
                      (jobA['applicationEndDate'] as Timestamp?)?.toDate();
                  final endB =
                      (jobB['applicationEndDate'] as Timestamp?)?.toDate();

                  if (endA != null && endB != null) {
                    final comp = endA.compareTo(endB);
                    if (comp != 0) return comp;
                  } else if (endA != null && endB == null) {
                    return -1;
                  } else if (endA == null && endB != null) {
                    return 1;
                  }

                  final cA = (jobA['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime(2000);
                  final cB = (jobB['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime(2000);
                  return cB.compareTo(cA);
                });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  physics: const BouncingScrollPhysics(),
                  itemCount: sortedDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final job = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(docId),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(
                          milliseconds: (240 + (index * 35)).clamp(240, 500)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _buildJobCard(job, docId, isDark),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // HIZLI İLAN EKLEME BUTONU
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: jobPrimaryColor,
        elevation: 4,
        onPressed: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null || user.isAnonymous) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("İş ilanı vermek için lütfen giriş yapınız."),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const AddJobPage()),
          );
        },
        icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
        label: const Text(
          "İlan Ver",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, bool isDark) {
    final bool isFlameTab = label.contains("Son Günler");

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? (isFlameTab
                  ? const LinearGradient(
                      colors: [Color(0xFFFF1744), Color(0xFFFF6D00)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF0056D2), Color(0xFF2563EB)],
                    ))
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isFlameTab
                            ? const Color(0xFFFF1744)
                            : const Color(0xFF0056D2))
                        .withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFlameTab && isSelected) ...[
              const Icon(CupertinoIcons.flame_fill,
                  size: 13, color: Colors.yellowAccent),
              const SizedBox(width: 5),
            ],
            Text(
              isFlameTab && !isSelected ? "🔥 Son Günler" : (isFlameTab ? "Son Günler" : label),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: jobPrimaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.briefcase,
                  size: 48, color: jobPrimaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Apple / iPhone Tarzı İş İlanı Kartı
  Widget _buildJobCard(Map<String, dynamic> job, String docId, bool isDark) {
    final isExpired = _isJobExpired(job);
    final isLastDay = _isJobLastDay(job);
    final remainingDays = _getRemainingDays(job);
    final isHired = job['isHired'] == true || job['status'] == 'filled';

    final ownerId = job['ownerId'] ?? "";
    final isAuthor = _currentUserId != null && _currentUserId == ownerId;
    final canManage = isAuthor || _isAdmin;

    final List<dynamic> images = job['images'] ?? [];
    final String logoUrl = images.isNotEmpty ? images.first.toString() : "";
    final String title = job['title'] ?? "Başlıksız İlan";
    final String company = job['companyName'] ?? "Firma Belirtilmemiş";
    final String employmentType = job['employmentType'] ?? "Tam Zamanlı";
    final String? salary =
        job['salary'] != null && job['salary'].toString().trim().isNotEmpty
            ? job['salary'].toString()
            : null;

    final String applicationUrl =
        (job['applicationUrl'] ?? '').toString().trim();
    final bool hasApplicationUrl = applicationUrl.isNotEmpty;
    final bool isIskur = (job['isIskur'] == true) ||
        (job['source'] == 'iskur') ||
        (job['iskurId'] != null && job['iskurId'].toString().isNotEmpty);

    final endDt = _parseDate(job['applicationEndDate']);
    final String? endDateStr = endDt != null
        ? DateFormat('dd.MM.yyyy', 'tr_TR').format(endDt)
        : null;

    final String dateStr = _formatDate(job['createdAt']);

    // Apple Tarzı Renk Paletleri (Her firma için harf koduna özel şık degrade)
    final List<List<Color>> avatarGradients = [
      [const Color(0xFF2563EB), const Color(0xFF1D4ED8)], // Azure Royal
      [const Color(0xFF7C3AED), const Color(0xFF6D28D9)], // Electric Purple
      [const Color(0xFF0D9488), const Color(0xFF0F766E)], // Cyber Teal
      [const Color(0xFFEA580C), const Color(0xFFC2410C)], // Sunset Amber
      [const Color(0xFFDB2777), const Color(0xFFBE185D)], // Rose Berry
      [const Color(0xFF059669), const Color(0xFF047857)], // Emerald Green
      [const Color(0xFF4F46E5), const Color(0xFF4338CA)], // Indigo
    ];
    final int colorIndex = company.hashCode.abs() % avatarGradients.length;
    final List<Color> cardAvatarColors = avatarGradients[colorIndex];

    // İşe alım tamamlandıysa veya süresi dolduysa soluk / pasif görünüm
    Widget cardContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isExpired
              ? [
                  isDark ? const Color(0xFF131822) : const Color(0xFFF8FAFC),
                  isDark ? const Color(0xFF0F141D) : const Color(0xFFF1F5F9),
                ]
              : [
                  isDark ? const Color(0xFF172033) : Colors.white,
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFCFF),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        // 🔥 Son 1 gün ise dönen çerçeve dıştan saracak, normalde standart çerçeve
        border: isLastDay
            ? null
            : Border.all(
                color: isExpired
                    ? (isDark ? Colors.white10 : Colors.grey.shade300)
                    : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : const Color(0xFFE2E8F0)),
                width: 1.2,
              ),
        boxShadow: isLastDay
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(isDark ? 0.3 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(isDark ? 0.12 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🚨 SON 1 GÜN UYARI BANDI (Animasyonlu Degrade & Alev İkonu)
            if (isLastDay) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF1744), Color(0xFFFF6D00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _flameController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.9 + (_flameController.value * 0.22),
                          child: const Icon(CupertinoIcons.flame_fill,
                              size: 16, color: Colors.yellowAccent),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remainingDays == 0
                            ? "🚨 BUGÜN SON GÜN! Başvuru Süresi Sona Eriyor"
                            : "🚨 SON 1 GÜN KALDI! Başvurunuzu Geciktirmeyin",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ⏰ SÜRESİ DOLDU UYARI BANDI
            if (isExpired && !isHired) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isDark ? Colors.white12 : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.clock_fill,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      "Başvuru Süresi Sona Erdi (İlan Pasif)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Üst Satır: Logo (iPhone Degrade Squircle), Başlık, Firma ve Menü
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Firma Logosu / Apple Degrade Squircle Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isExpired
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: cardAvatarColors,
                          ),
                    color: isExpired
                        ? (isDark ? Colors.white12 : Colors.grey.shade300)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isExpired
                        ? []
                        : [
                            BoxShadow(
                              color: cardAvatarColors[0].withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: PortalNetworkImage(
                              url: logoUrl, fit: BoxFit.cover),
                        )
                      : Center(
                          child: Text(
                            company.isNotEmpty
                                ? company[0].toUpperCase()
                                : "İ",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),

                // Başlık ve Firma
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: isExpired
                              ? (isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600)
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              CupertinoIcons.building_2_fill,
                              size: 11,
                              color: isExpired
                                  ? Colors.grey
                                  : (isDark
                                      ? Colors.blue.shade300
                                      : const Color(0xFF0056D2)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isExpired
                                    ? Colors.grey
                                    : (isDark
                                        ? Colors.grey.shade300
                                        : const Color(0xFF475569)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Yönetici veya Yayınlayan Menüsü (iPhone Yuvarlak Buton)
                if (canManage)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          color: isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF64748B),
                          size: 16,
                        ),
                      ),
                    ),
                    onSelected: (action) {
                      if (action == 'toggle_hired') {
                        _toggleHiredStatus(docId, isHired);
                      } else if (action == 'edit') {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => AddJobPage(
                                existingJob: job, docId: docId),
                          ),
                        );
                      } else if (action == 'delete') {
                        _deleteJob(docId);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle_hired',
                        child: Row(
                          children: [
                            Icon(
                              isHired
                                  ? CupertinoIcons.arrow_clockwise_circle
                                  : CupertinoIcons.checkmark_seal_fill,
                              color: isHired
                                  ? Colors.green
                                  : Colors.orange.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isHired
                                  ? "İlanı Tekrar Aç"
                                  : "İşe Alım Tamamlandı",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isHired
                                    ? Colors.green
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.pencil,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text("Düzenle"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.trash,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text("Sil",
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. İşe Alım Durum Rozeti (Eğer Tamamlandıysa)
            if (isHired) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill,
                        size: 14,
                        color: isDark
                            ? Colors.amber.shade300
                            : Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Text(
                      "İşe Alım Gerçekleşti (Pozisyon Kapandı)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 3. Online Başvuru & Son Tarih Bilgi Satırı (iPhone Rozetleri)
            if (hasApplicationUrl || endDateStr != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 🏛️ İŞKUR Resmi İlanı Rozeti veya Online Başvuru Rozeti
                  if (isIskur)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0056D2), Color(0xFF0284C7)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0056D2).withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.building_2_fill,
                              size: 12.5, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            "İŞKUR Resmi İlanı",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (hasApplicationUrl)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.arrow_up_right_square_fill,
                              size: 12.5, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            "Online Başvuru",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ⏳ Dinamik Aciliyet Renkli Son Başvuru Rozeti
                  if (endDateStr != null)
                    _buildCountdownBadge(
                      endDateStr: endDateStr,
                      remainingDays: remainingDays,
                      isLastDay: isLastDay,
                      isDark: isDark,
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // 4. Alt Etiketler: Çalışma Türü, Maaş ve Yayınlanma Tarihi
            Row(
              children: [
                // Çalışma Türü (Tam Zamanlı vs)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.briefcase_fill,
                          size: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        employmentType,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),

                // Maaş (Varsa)
                if (salary != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.grey.withOpacity(0.12)
                          : (isDark
                              ? const Color(0xFF064E3B).withOpacity(0.4)
                              : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isExpired
                            ? Colors.transparent
                            : (isDark
                                ? const Color(0xFF059669)
                                : const Color(0xFFA7F3D0)),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.money_dollar_circle_fill,
                            size: 12,
                            color: isExpired
                                ? Colors.grey
                                : (isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF059669))),
                        const SizedBox(width: 4),
                        Text(
                          "$salary ₺",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isExpired
                                ? Colors.grey
                                : (isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Yayınlanma Tarihi & iOS Ok İkonu
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.clock,
                        size: 12,
                        color: isDark
                            ? Colors.grey.shade500
                            : const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(CupertinoIcons.chevron_right,
                        size: 13,
                        color: isDark
                            ? Colors.grey.shade600
                            : const Color(0xFFCBD5E1)),
                  ],
                ),

                // 🔥 SAĞ ALT ANİMASYONLU ALEV ROZETİ (Son 1 gün ise)
                if (isLastDay) ...[
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _flameController,
                    builder: (context, child) {
                      final scale =
                          0.94 + (_flameController.value * 0.12);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF1744),
                                Color(0xFFFF6D00)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF1744).withOpacity(
                                    0.45 +
                                        (_flameController.value * 0.25)),
                                blurRadius:
                                    8 + (_flameController.value * 3),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.flame_fill,
                                  size: 13,
                                  color: Colors.yellowAccent),
                              const SizedBox(width: 4),
                              Text(
                                remainingDays == 0
                                    ? "Bugün Son!"
                                    : "Son 1 Gün!",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // Tıklanabilir Kart Bileşeni
    Widget interactiveCard = GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => JobDetailPage(job: job, docId: docId),
          ),
        );
      },
      child: cardContent,
    );

    // 🔥 SON 1 GÜN KALANLAR İÇİN DÖNEN KIRMIZI-TURUNCU NEON IŞIKLI ÇERÇEVE (iPhone Tarzı)
    Widget finalCard = interactiveCard;
    if (isLastDay) {
      finalCard = AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final angle = _glowController.value * 2 * math.pi;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: SweepGradient(
                colors: const [
                  Color(0xFFFF1744), // Crimson
                  Color(0xFFFF9100), // Fire Amber
                  Color(0xFFFF1744), // Crimson
                  Color(0xFFFF5252), // Light Flame
                  Color(0xFFFF1744), // Crimson
                ],
                transform: GradientRotation(angle),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF1744).withOpacity(
                      0.35 + (0.15 * math.sin(angle).abs())),
                  blurRadius: 14,
                  spreadRadius: 1.5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: child,
          );
        },
        child: interactiveCard,
      );
    }

    return Opacity(
      opacity: isExpired ? 0.68 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        child: finalCard,
      ),
    );
  }

  // Aciliyet durumuna göre iPhone tarzı dinamik geri sayım rozeti
  Widget _buildCountdownBadge({
    required String endDateStr,
    required int? remainingDays,
    required bool isLastDay,
    required bool isDark,
  }) {
    if (isLastDay) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF1744).withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.flame_fill,
                size: 12.5, color: Colors.yellowAccent),
            const SizedBox(width: 4),
            Text(
              remainingDays == 0 ? "Son: $endDateStr (Bugün Son!)" : "Son: $endDateStr (Son 1 Gün!)",
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    // 5 gün veya daha az kaldıysa kehribar/turuncu uyarı
    if (remainingDays != null && remainingDays <= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF78350F).withOpacity(0.3)
              : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.4 : 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.hourglass_bottomhalf_fill,
                size: 12,
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
            const SizedBox(width: 5),
            Text(
              "Son: $endDateStr ($remainingDays gün kaldı)",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    }

    // 15 gün veya daha az kaldıysa mavi dinamik rozet
    if (remainingDays != null && remainingDays <= 15) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E3A8A).withOpacity(0.25)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.35 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.calendar_today,
                size: 12,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
            const SizedBox(width: 5),
            Text(
              "Son: $endDateStr ($remainingDays gün)",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      );
    }

    // 15 günden fazla varsa nötr sade rozet
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.calendar,
              size: 12,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            "Son: $endDateStr${remainingDays != null ? ' ($remainingDays gün)' : ''}",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
