import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'add_job_page.dart';
import 'job_detail_page.dart';

class MyJobsPage extends StatefulWidget {
  const MyJobsPage({Key? key}) : super(key: key);

  @override
  State<MyJobsPage> createState() => _MyJobsPageState();
}

class _MyJobsPageState extends State<MyJobsPage> {
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Yeni";
    final dt = timestamp.toDate();
    return DateFormat('dd.MM.yyyy', 'tr_TR').format(dt);
  }

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
            content: Text("Hata: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteJob(String docId) async {
    bool confirm = await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("İlanı Sil"),
            content: const Text(
                "Bu iş ilanını kalıcı olarak silmek istediğinize emin misiniz?"),
            actions: [
              CupertinoDialogAction(
                  child: const Text("Vazgeç"),
                  onPressed: () => Navigator.pop(context, false)),
              CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text("Evet, Sil"),
                  onPressed: () => Navigator.pop(context, true)),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('job_postings')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("İş ilanı başarıyla silindi."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          "İş İlanlarım",
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
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
      ),
      body: Builder(
        builder: (context) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
          if (currentUid.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.person_crop_circle_badge_exclam,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "İlanlarınızı görmek için lütfen giriş yapın.",
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('job_postings')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CupertinoActivityIndicator(radius: 16));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle,
                            color: Colors.amber, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          "İlanlar yüklenirken bir sorun oluştu:\n${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];
              final jobs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final owner = (data['ownerId'] ?? data['userId'] ?? data['authorId'] ?? '').toString();
                return owner == currentUid;
              }).toList();

              if (jobs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.briefcase,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        "Henüz bir iş ilanı vermediniz.",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    var jobData = jobs[index].data() as Map<String, dynamic>;
                    String docId = jobs[index].id;
                    String title = jobData['title'] ?? "Başlıksız İlan";
                    String company =
                        jobData['companyName'] ?? "Firma Belirtilmemiş";
                    String type = jobData['employmentType'] ?? "-";
                    final bool isHired = jobData['isHired'] == true ||
                        jobData['status'] == 'filled';
                    final String dateStr =
                        _formatDate(jobData['createdAt'] as Timestamp?);

                    return Opacity(
                      opacity: isHired ? 0.75 : 1.0,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) =>
                                  JobDetailPage(job: jobData, docId: docId),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isHired
                                ? (isDark
                                    ? const Color(0xFF131720)
                                    : const Color(0xFFF1F5F9))
                                : (isDark
                                    ? const Color(0xFF131B2E)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isHired
                                  ? (isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300)
                                  : (isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200),
                            ),
                            boxShadow: isHired
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                          isDark ? 0.2 : 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isHired
                                          ? Colors.grey.withOpacity(0.15)
                                          : const Color(0xFF0284C7)
                                              .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.briefcase_fill,
                                      color: isHired
                                          ? Colors.grey
                                          : const Color(0xFF0284C7),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          company,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white10
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                type,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                Icon(CupertinoIcons.calendar,
                                                    size: 12,
                                                    color:
                                                        Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dateStr,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              if (isHired) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: 13,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "İşe Alım Tamamlandı (Pozisyon Kapandı)",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const Divider(height: 24),

                              // BUTONLAR: İşe Alındı / Aç, Düzenle, Sil
                              Row(
                                children: [
                                  // İşe Alım Durum Butonu
                                  Expanded(
                                    flex: 3,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _toggleHiredStatus(docId, isHired),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isHired
                                            ? Colors.green
                                            : Colors.orange.shade800,
                                        side: BorderSide(
                                          color: isHired
                                              ? Colors.green.withOpacity(0.5)
                                              : Colors.orange.withOpacity(0.5),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      icon: Icon(
                                        isHired
                                            ? CupertinoIcons
                                                .arrow_clockwise_circle
                                            : CupertinoIcons
                                                .checkmark_seal_fill,
                                        size: 15,
                                      ),
                                      label: Text(
                                        isHired
                                            ? "Yeniden Aç"
                                            : "İşe Alındı",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Düzenle
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (_) => AddJobPage(
                                                existingJob: jobData,
                                                docId: docId),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0284C7),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      icon: const Icon(CupertinoIcons.pencil,
                                          size: 15),
                                      label: const Text(
                                        "Düzenle",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Sil
                                  IconButton(
                                    onPressed: () => _deleteJob(docId),
                                    icon: const Icon(CupertinoIcons.trash,
                                        color: Colors.redAccent, size: 20),
                                    tooltip: "İlanı Sil",
                                  ),
                                ],
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
          },
        ),
      );
  }
}
