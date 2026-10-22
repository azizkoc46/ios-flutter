import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:pazarcik_portal/widgets/interactive_media_viewer.dart';
import 'package:share_plus/share_plus.dart';

class JobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final String docId;

  const JobDetailPage({Key? key, required this.job, required this.docId})
      : super(key: key);

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAdmin = false;
  final Color jobPrimaryColor = const Color(0xFF0284C7);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _increaseViewCount();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _increaseViewCount() async {
    final jobId = widget.docId.isNotEmpty
        ? widget.docId
        : (widget.job['docId'] ?? widget.job['id'] ?? '').toString();
    if (jobId.isEmpty) return;

    try {
      final incrementVal = 8 + (DateTime.now().microsecond % 7); // 8..14 arası artış
      await FirebaseFirestore.instance
          .collection('job_postings')
          .doc(jobId)
          .set({
        'views': FieldValue.increment(incrementVal),
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("İş ilanı görüntülenme hatası: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  Future<void> _openApplicationUrl(String rawUrl) async {
    String cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) return;
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri != null) {
      try {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Başvuru linki açılamadı. Lütfen geçerli bir internet adresi olduğunu kontrol edin."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Link açılırken hata oluştu: $e"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
    } catch (_) {}
  }

  void _shareJob(Map<String, dynamic> job) {
    String title = job['title'] ?? "İş İlanı";
    String company = job['companyName'] ?? "Firma Belirtilmemiş";
    String shareUrl = "https://www.pazarcikportal.com/is?id=${widget.docId}";

    String shareText = "📢 Pazarcık Portal'da İş İlanı!\n\n"
        "💼 Pozisyon: $title\n"
        "🏢 Firma: $company\n\n"
        "🔗 İlanın Detayları İçin Tıkla:\n$shareUrl";

    Share.share(shareText, subject: "Pazarcık İş İlanı: $title");
  }

  Future<void> _makeCall(String phoneNumber) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleHiredStatus(bool currentHired) async {
    final newHired = !currentHired;
    try {
      await FirebaseFirestore.instance
          .collection('job_postings')
          .doc(widget.docId)
          .update({
        'status': newHired ? 'filled' : 'active',
        'isHired': newHired,
        'hiredAt': newHired ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newHired
                ? "İlan işe alım gerçekleşti olarak güncellendi."
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
            content: Text("Hata: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    final dt = _parseDate(timestamp);
    if (dt == null) return "Yeni";
    return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_postings')
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> job = widget.job;
        if (snapshot.hasData && snapshot.data!.exists) {
          job = snapshot.data!.data() as Map<String, dynamic>;
        }

        final bool isHired =
            job['isHired'] == true || job['status'] == 'filled';
        final bool isExpired = _isJobExpired(job);
        final bool isLastDay = _isJobLastDay(job);
        final int? remainingDays = _getRemainingDays(job);

        final String applicationUrl =
            (job['applicationUrl'] ?? '').toString().trim();
        final bool hasApplicationUrl = applicationUrl.isNotEmpty;

        final startDt = _parseDate(job['applicationStartDate']);
        final String? startDateStr = startDt != null
            ? DateFormat('dd MMMM yyyy', 'tr_TR').format(startDt)
            : null;

        final endDt = _parseDate(job['applicationEndDate']);
        final String? endDateStr = endDt != null
            ? DateFormat('dd MMMM yyyy', 'tr_TR').format(endDt)
            : null;

        final String ownerId = (job['ownerId'] ?? "").toString().trim();
        final bool isAuthor =
            _currentUserId != null && _currentUserId == ownerId;
        final bool canManage = isAuthor || _isAdmin;

        final List<dynamic> rawImages =
            job['images'] is List ? (job['images'] as List) : [];
        final List<String> images =
            rawImages.map((e) => e.toString()).toList();
        final String manualPhone =
            (job['contactPhone'] ?? job['phone'] ?? '').toString().trim();
        final bool isIskur = (job['isIskur'] == true) ||
            (job['source'] == 'iskur') ||
            (job['iskurId'] != null && job['iskurId'].toString().isNotEmpty);
        final String createdAtStr = _formatDate(job['createdAt']);
        final int views = (job['views'] is num)
            ? (job['views'] as num).toInt()
            : int.tryParse(job['views']?.toString() ?? '0') ?? 0;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF131B2E) : Colors.white,
            elevation: 0.5,
            centerTitle: true,
            title: Text(
              "İlan Detayı",
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                CupertinoIcons.chevron_left,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.share, size: 20),
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                tooltip: "Paylaş",
                onPressed: () => _shareJob(job),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: Icon(
                    CupertinoIcons.ellipsis_circle,
                    size: 22,
                    color: isHired ? Colors.orange : jobPrimaryColor,
                  ),
                  onSelected: (val) {
                    if (val == 'toggle') {
                      _toggleHiredStatus(isHired);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isHired
                                ? CupertinoIcons.arrow_clockwise_circle
                                : CupertinoIcons.checkmark_seal_fill,
                            color: isHired ? Colors.green : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHired
                                ? "İlanı Tekrar Yayına Al"
                                : "İşe Alım Gerçekleşti",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isHired ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  (hasApplicationUrl && !isExpired) ? 180 : 130,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🚨 SON 1 GÜN UYARI BANNER'I
                    if (isLastDay) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.flame_fill,
                                color: Colors.white, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "SON 1 GÜN KALDI!",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Bu ilanın başvuru süresi bugün sona eriyor. Başvurunuzu geciktirmeyin.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ⏰ BAŞVURU SÜRESİ SONA ERDİ BANNER'I
                    if (isExpired && !isHired) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.clock_fill,
                                color: Colors.grey.shade600, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "BAŞVURU SÜRESİ DOLMUŞTUR",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Bu ilanın son başvuru tarihi geçmiş olup yeni başvurular kabul edilmemektedir.",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. İŞE ALIM GERÇEKLEŞTİ BİLGİ BANNER'I
                    if (isHired) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF261D12)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.amber.shade700.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(CupertinoIcons.checkmark_seal_fill,
                                color: Colors.amber.shade700, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "İşe Alım Gerçekleşti (Pozisyon Doldu)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Bu pozisyon için aranan personel bulunmuş ve ilan tamamlanmıştır.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. FOTOĞRAFLAR (Tıklayınca İnteraktif Büyütme)
                    if (images.isNotEmpty) ...[
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                InteractiveMediaViewer.show(
                                  context,
                                  imageUrls: images,
                                  initialIndex: index,
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 290,
                                  color: Colors.black12,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      PortalNetworkImage(
                                        url: images[index],
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(CupertinoIcons.zoom_in,
                                                  color: Colors.white, size: 14),
                                              SizedBox(width: 4),
                                              Text(
                                                "Büyüt",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
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
                      const SizedBox(height: 18),
                    ],

                    // 3. BAŞLIK VE FİRMA
                    Text(
                      job['title'] ?? "",
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(CupertinoIcons.building_2_fill,
                            size: 16, color: jobPrimaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            job['companyName'] ?? "Firma Belirtilmemiş",
                            style: TextStyle(
                              fontSize: 16,
                              color: jobPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isIskur) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0056D2).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF0056D2).withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0056D2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.checkmark_seal_fill,
                                  color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "🏛️ İŞKUR Resmi İlanı",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Color(0xFF0056D2),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Bu ilan İŞKUR e-Şube üzerinden otomatik alınmıştır. Firmanın açık adres ve iletişim bilgilerini görmek için e-Devlet ile başvuru yapabilirsiniz.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.3,
                                      color: isDark
                                          ? Colors.blue.shade200
                                          : const Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // 4. BİLGİ ROZETLERİ (Çalışma Türü, Kontenjan, Maaş, Görüntülenme)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          icon: CupertinoIcons.time,
                          label: job['employmentType'] ?? "Tam Zamanlı",
                          color: jobPrimaryColor,
                          isDark: isDark,
                        ),
                        _buildInfoChip(
                          icon: CupertinoIcons.person_2_fill,
                          label: "${job['personnelCount'] ?? '1'} Kişi",
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                        if (job['salary'] != null &&
                            job['salary'].toString().trim().isNotEmpty)
                          _buildInfoChip(
                            icon: CupertinoIcons.money_dollar_circle,
                            label: job['salary'].toString().toLowerCase().contains('tl') ||
                                    job['salary'].toString().toLowerCase().contains('standart') ||
                                    job['salary'].toString().toLowerCase().contains('asgari')
                                ? job['salary'].toString()
                                : "${job['salary']} TL",
                            color: Colors.green.shade600,
                            isDark: isDark,
                          ),
                        _buildInfoChip(
                          icon: CupertinoIcons.eye,
                          label: "$views Görüntülenme",
                          color: Colors.grey.shade600,
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 5. 🔥 YAYINLANMA TARİHİ KARTI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF131B2E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.calendar,
                              color: jobPrimaryColor, size: 18),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Yayınlanma Tarihi",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                createdAtStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 5b. 📅 BAŞVURU SÜRECİ & TARİHLERİ KARTI
                    if (startDateStr != null || endDateStr != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isLastDay
                              ? (isDark
                                  ? const Color(0xFF261215)
                                  : const Color(0xFFFEF2F2))
                              : (isDark
                                  ? const Color(0xFF131B2E)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLastDay
                                ? const Color(0xFFEF4444)
                                : isExpired
                                    ? Colors.grey.shade400
                                    : (isDark
                                        ? Colors.white10
                                        : Colors.grey.shade200),
                            width: isLastDay ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.calendar_badge_plus,
                                  color: isLastDay
                                      ? const Color(0xFFEF4444)
                                      : jobPrimaryColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Başvuru Takvimi",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                if (isLastDay)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "SON 1 GÜN",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                else if (isExpired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade600,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "SÜRESİ BİTTİ",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (remainingDays != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "$remainingDays gün kaldı",
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Başlangıç Tarihi",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        startDateStr ?? "Yayın anından itibaren",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Son Başvuru Tarihi",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isLastDay
                                              ? const Color(0xFFEF4444)
                                              : Colors.grey.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        endDateStr ?? "Süresiz / Belirtilmedi",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isLastDay
                                              ? const Color(0xFFEF4444)
                                              : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 5c. 🚀 HARİKA ANİMASYONLU BAŞVURU BUTONU (İŞKUR / Web Sitesi)
                    if (hasApplicationUrl) ...[
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: isExpired ? 1.0 : _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: isExpired
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0284C7),
                                      Color(0xFF0369A1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: isExpired
                                ? (isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey.shade300)
                                : null,
                            boxShadow: isExpired
                                ? []
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF0284C7)
                                          .withOpacity(0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (isExpired) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Bu ilanın başvuru süresi sona ermiştir."),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  _openApplicationUrl(applicationUrl);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isExpired
                                            ? CupertinoIcons.clock_fill
                                            : CupertinoIcons.paperplane_fill,
                                        color: isExpired
                                            ? Colors.grey.shade600
                                            : Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isExpired
                                                ? "BAŞVURU SÜRESİ DOLDU"
                                                : (isIskur
                                                    ? "🏛️ İŞKUR İLE RESMİ BAŞVURU YAP"
                                                    : "RESMİ BAŞVURU SAYFASINA GİT"),
                                            style: TextStyle(
                                              color: isExpired
                                                  ? Colors.grey.shade600
                                                  : Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isExpired
                                                ? "Yeni başvuru alınmamaktadır"
                                                : (isIskur
                                                    ? "e-Devlet ile giriş yaparak ilana resmi başvuru yapın"
                                                    : "İŞKUR / Kurumun online başvuru adresi"),
                                            style: TextStyle(
                                              color: isExpired
                                                  ? Colors.grey.shade500
                                                  : Colors.white
                                                      .withOpacity(0.85),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.arrow_up_right_square_fill,
                                      color: isExpired
                                          ? Colors.grey.shade500
                                          : Colors.white,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 6. YÖNETİCİ / YAYINLAYAN KONTROL DÜĞMESİ (İşe Alım Durumu)
                    if (canManage) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isHired
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHired
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isHired
                                  ? CupertinoIcons.arrow_clockwise_circle_fill
                                  : CupertinoIcons.checkmark_seal_fill,
                              color: isHired
                                  ? Colors.green
                                  : Colors.orange.shade800,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isHired
                                        ? "İlan Şu An Kapalı"
                                        : "İşe Alım Gerçekleşti mi?",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isHired
                                          ? Colors.green
                                          : Colors.orange.shade900,
                                    ),
                                  ),
                                  Text(
                                    isHired
                                        ? "İlanı tekrar aktif yapmak için tıklayın."
                                        : "İşe alım olduysa ilanı tamamlandı olarak işaretleyin.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _toggleHiredStatus(isHired),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isHired
                                    ? Colors.green
                                    : Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                isHired ? "Yeniden Aç" : "Tamamla",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // 7. İŞ TANIMI & AÇIKLAMA
                    Text(
                      "Aranan Nitelikler & İş Tanımı",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      job['description'] ?? "Açıklama girilmemiş.",
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // 8. ALT İLETİŞİM & BAŞVURU BUTONLARI (Başvur, WhatsApp & Ara)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    MediaQuery.of(context).padding.bottom + 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: FutureBuilder<DocumentSnapshot?>(
                    future: ownerId.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('customers')
                            .doc(ownerId)
                            .get()
                        : null,
                    builder: (context, snap) {
                      String phone = manualPhone;
                      if (phone.isEmpty &&
                          snap.hasData &&
                          snap.data != null &&
                          snap.data!.exists) {
                        final userData =
                            snap.data!.data() as Map<String, dynamic>?;
                        if (userData != null) {
                          phone = (userData['phoneNumber'] ??
                                  userData['phone'] ??
                                  '')
                              .toString()
                              .trim();
                        }
                      }

                      final bool hasPhone = phone.isNotEmpty;

                      if (!hasPhone && isIskur) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasApplicationUrl && !isExpired) ...[
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0056D2),
                                        Color(0xFF0284C7),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0056D2)
                                            .withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _openApplicationUrl(applicationUrl),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(
                                      CupertinoIcons.paperplane_fill,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "e-Devlet ile İŞKUR'da Başvur",
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasApplicationUrl && !isExpired) ...[
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: double.infinity,
                                height: 46,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF1D4ED8),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB)
                                          .withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _openApplicationUrl(applicationUrl),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(
                                    CupertinoIcons.paperplane_fill,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    "Online Başvuru Yap (İŞKUR / Web)",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              // WhatsApp Butonu
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    side: BorderSide(
                                      color: isHired
                                          ? Colors.grey
                                          : const Color(0xFF25D366),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: hasPhone
                                      ? () => _openWhatsApp(phone)
                                      : null,
                                  icon: Icon(
                                    CupertinoIcons.chat_bubble_text_fill,
                                    color: isHired
                                        ? Colors.grey
                                        : const Color(0xFF25D366),
                                    size: 18,
                                  ),
                                  label: Text(
                                    "WhatsApp",
                                    style: TextStyle(
                                      color: isHired
                                          ? Colors.grey
                                          : const Color(0xFF25D366),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Hemen Ara Butonu
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    backgroundColor: isHired
                                        ? Colors.grey.shade600
                                        : jobPrimaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed:
                                      hasPhone ? () => _makeCall(phone) : null,
                                  icon: const Icon(CupertinoIcons.phone_fill,
                                      color: Colors.white, size: 18),
                                  label: const Text(
                                    "Hemen Ara",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
