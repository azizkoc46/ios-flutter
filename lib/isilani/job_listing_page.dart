import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

import 'job_detail_page.dart';
import 'add_job_page.dart';
import 'my_jobs_page.dart';

class JobListingPage extends StatefulWidget {
  const JobListingPage({Key? key}) : super(key: key);

  @override
  State<JobListingPage> createState() => _JobListingPageState();
}

class _JobListingPageState extends State<JobListingPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "Tümü"; // "Tümü", "Aktif", "Tamamlananlar"

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAdmin = false;

  final Color jobPrimaryColor = const Color(0xFF0284C7); // Kariyer Mavisi
  final Color jobAccentColor = const Color(0xFF0EA5E9);

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // Tarih Biçimlendirme (Göreceli ve Net Tarih)
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Yeni";
    final dt = timestamp.toDate();
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            child: Column(
              children: [
                // Arama Kutusu
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(CupertinoIcons.search,
                          color: Colors.grey.shade500, size: 18),
                      const SizedBox(width: 8),
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
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: "Pozisyon veya firma ara...",
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade400),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(CupertinoIcons.clear_circled_solid,
                                size: 16, color: Colors.grey.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Filtre Sekmeleri (Tümü, Aktif, Tamamlananlar)
                Row(
                  children: [
                    _buildFilterChip("Tümü", _selectedFilter == "Tümü", isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                        "Aktif", _selectedFilter == "Aktif", isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("Tamamlananlar",
                        _selectedFilter == "Tamamlananlar", isDark),
                  ],
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
                  final isHired =
                      job['isHired'] == true || job['status'] == 'filled';

                  // Sekme filtresi
                  if (_selectedFilter == "Aktif" && isHired) return false;
                  if (_selectedFilter == "Tamamlananlar" && !isHired) {
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
                  return _buildEmptyState("Aramanıza uygun ilan bulunamadı.", isDark);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final job = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;
                    return _buildJobCard(job, docId, isDark);
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
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? jobPrimaryColor
              : (isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
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

  // Modern İş İlanı Kartı
  Widget _buildJobCard(Map<String, dynamic> job, String docId, bool isDark) {
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

    final String dateStr = _formatDate(job['createdAt'] as Timestamp?);

    // İşe alım tamamlandıysa soluk / geçmiş görünüm
    return Opacity(
      opacity: isHired ? 0.72 : 1.0,
      child: GestureDetector(
        onTap: () {
          FirebaseFirestore.instance
              .collection('job_postings')
              .doc(docId)
              .update({'views': FieldValue.increment(1)});

          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => JobDetailPage(job: job, docId: docId),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isHired
                ? (isDark
                    ? const Color(0xFF121722)
                    : const Color(0xFFF1F5F9))
                : (isDark ? const Color(0xFF131B2E) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHired
                  ? (isDark ? Colors.white10 : Colors.grey.shade300)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE2E8F0)),
              width: 1,
            ),
            boxShadow: isHired
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Üst Satır: Logo, Başlık, Firma ve Yönetim Menüsü
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Firma Logosu / Baş Harf
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isHired
                            ? Colors.grey.withOpacity(0.2)
                            : jobPrimaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: logoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: PortalNetworkImage(
                                  url: logoUrl, fit: BoxFit.cover),
                            )
                          : Center(
                              child: Text(
                                company.isNotEmpty
                                    ? company[0].toUpperCase()
                                    : "İ",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isHired
                                      ? Colors.grey
                                      : jobPrimaryColor,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isHired
                                  ? (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700)
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(CupertinoIcons.building_2_fill,
                                  size: 13,
                                  color: isHired
                                      ? Colors.grey
                                      : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  company,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isHired
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

                    // Yönetici veya Yayınlayan Menüsü
                    if (canManage)
                      PopupMenuButton<String>(
                        icon: Icon(CupertinoIcons.ellipsis,
                            color: Colors.grey.shade500, size: 18),
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
                      borderRadius: BorderRadius.circular(8),
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

                // 3. Alt Etiketler: Çalışma Türü, Maaş ve YAYINLANMA TARİHİ
                Row(
                  children: [
                    // Çalışma Türü (Tam Zamanlı vs)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        employmentType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Maaş (Varsa)
                    if (salary != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHired
                              ? Colors.grey.withOpacity(0.12)
                              : Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$salary TL",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isHired ? Colors.grey : Colors.green.shade700,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // 🔥 YAYINLANMA TARİHİ (Net ve Belirgin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.calendar,
                              size: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
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
        ),
      ),
    );
  }
}
