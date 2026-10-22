// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pazarcik_portal/services/cek_gonder_institution_service.dart';
import 'package:pazarcik_portal/services/user_notification_service.dart';

class InstitutionCekGonderDeskPage extends StatefulWidget {
  final CekGonderInstitution institution;

  const InstitutionCekGonderDeskPage({
    super.key,
    required this.institution,
  });

  @override
  State<InstitutionCekGonderDeskPage> createState() =>
      _InstitutionCekGonderDeskPageState();
}

class _InstitutionCekGonderDeskPageState
    extends State<InstitutionCekGonderDeskPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _replyController = TextEditingController();
  String _selectedStatus = 'resolved'; // 'in_progress', 'resolved', 'rejected', 'replied'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dt = timestamp;
      } else {
        return '';
      }
      return DateFormat('dd MMM yyyy, HH:mm', 'tr').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showReplyModal(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final currentReply = (data['adminReply'] ?? '').toString();
    final currentStatus = (data['status'] ?? 'pending').toString();
    final citizenUid = (data['uid'] ?? '').toString();
    final citizenName = (data['userName'] ?? 'Vatandaş').toString();
    final reportTitle = (data['title'] ?? '').toString();

    _replyController.text = currentReply;
    _selectedStatus = (currentStatus == 'pending') ? 'resolved' : currentStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      "Vatandaşa Yanıt & Durum",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$citizenName için resmi yanıtınızı yazın",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Durum Seçici Çipler
                    const Text(
                      "TALEP DURUMU",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChoiceChip(
                          label: "İşleme Alındı",
                          value: "in_progress",
                          color: Colors.blue,
                          selected: _selectedStatus == "in_progress",
                          onTap: () => setModalState(() => _selectedStatus = "in_progress"),
                        ),
                        _statusChoiceChip(
                          label: "Çözüldü / Tamamlandı",
                          value: "resolved",
                          color: Colors.green,
                          selected: _selectedStatus == "resolved",
                          onTap: () => setModalState(() => _selectedStatus = "resolved"),
                        ),
                        _statusChoiceChip(
                          label: "Bilgilendirildi",
                          value: "replied",
                          color: Colors.purple,
                          selected: _selectedStatus == "replied",
                          onTap: () => setModalState(() => _selectedStatus = "replied"),
                        ),
                        _statusChoiceChip(
                          label: "Reddedildi / İlgisiz",
                          value: "rejected",
                          color: Colors.redAccent,
                          selected: _selectedStatus == "rejected",
                          onTap: () => setModalState(() => _selectedStatus = "rejected"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      "RESMİ YANIT MESAJI",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _replyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Örn: Bildirdiğiniz arıza ekiplerimizce incelenmiş olup tamirat tamamlanmıştır. Teşekkür ederiz.",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Gönder Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0056D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final replyText = _replyController.text.trim();
                                if (replyText.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Lütfen vatandaşa bir yanıt mesajı yazın."),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => _isSubmitting = true);
                                final currentUser = FirebaseAuth.instance.currentUser;

                                try {
                                  // 1. Raporu güncelle
                                  await doc.reference.update({
                                    'adminReply': replyText,
                                    'replyDate': FieldValue.serverTimestamp(),
                                    'status': _selectedStatus,
                                    'repliedBy': currentUser?.uid ?? 'authority',
                                    'repliedByName': currentUser?.displayName ??
                                        widget.institution.name,
                                    'repliedByInstitution': widget.institution.name,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  // 2. Vatandaşa Bildirim Gönder
                                  if (citizenUid.isNotEmpty && citizenUid != 'anonymous') {
                                    await UserNotificationService.instance.sendNotificationToUser(
                                      targetUid: citizenUid,
                                      title: '🏢 ${widget.institution.name} Bildiriminizi Yanıtladı',
                                      body: replyText,
                                      type: 'cek_gonder_reply',
                                      docId: doc.id,
                                      extraData: {
                                        'docId': doc.id,
                                        'targetId': doc.id,
                                        'targetType': 'cek_gonder',
                                        'institutionName': widget.institution.name,
                                        'reportTitle': reportTitle,
                                        'adminReply': replyText,
                                        'status': _selectedStatus,
                                      },
                                    );
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Yanıt kaydedildi ve vatandaşa bildirim gönderildi! ✅"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Hata oluştu: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  setModalState(() => _isSubmitting = false);
                                }
                              },
                        icon: _isSubmitting
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Icon(CupertinoIcons.paperplane_fill, color: Colors.white),
                        label: Text(
                          _isSubmitting ? "KAYDEDİLİYOR..." : "YANITI KAYDET VE İLET",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusChoiceChip({
    required String label,
    required String value,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.3),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CupertinoActivityIndicator(color: Colors.white)),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.institution.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              "Çek & Gönder Yönetim Masası",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0056D2),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          indicatorColor: const Color(0xFF0056D2),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: "Bekleyenler"),
            Tab(text: "İşlemdekiler"),
            Tab(text: "Çözülenler"),
            Tab(text: "Tümü"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cek_gonder_reports')
            .where('institutionId', isEqualTo: widget.institution.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Hata: ${snapshot.error}"),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final allDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          allDocs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          final pendingDocs = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final s = data['status'] ?? 'pending';
            final hasReply = (data['adminReply'] ?? '').toString().trim().isNotEmpty;
            return s == 'pending' && !hasReply;
          }).toList();

          final inProgressDocs = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'in_progress';
          }).toList();

          final resolvedDocs = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final s = data['status'];
            final hasReply = (data['adminReply'] ?? '').toString().trim().isNotEmpty;
            return s == 'resolved' || s == 'replied' || hasReply;
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportList(pendingDocs, emptyMsg: "Bekleyen bildirim yok. Harika! 🎉"),
              _buildReportList(inProgressDocs, emptyMsg: "İşleme alınmış bildirim bulunmuyor."),
              _buildReportList(resolvedDocs, emptyMsg: "Henüz yanıtlanmış bildirim yok."),
              _buildReportList(allDocs, emptyMsg: "Kurumunuza ait henüz bildirim gönderilmedi."),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportList(List<DocumentSnapshot> docs, {required String emptyMsg}) {
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.checkmark_seal_fill, size: 54, color: Colors.blue.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _buildReportCard(docs[index]);
      },
    );
  }

  Widget _buildReportCard(DocumentSnapshot doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final title = (data['title'] ?? 'İsimsiz Bildirim').toString();
    final description = (data['description'] ?? '').toString();
    final userName = (data['userName'] ?? 'Vatandaş').toString();
    final userPhone = (data['userPhone'] ?? '').toString();
    final mediaUrl = (data['mediaUrl'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();
    final adminReply = (data['adminReply'] ?? '').toString();
    final replyDate = _formatDate(data['replyDate']);
    final createdAt = _formatDate(data['createdAt']);

    Color statusColor = Colors.orange;
    String statusText = "Beklemede";

    if (status == 'in_progress') {
      statusColor = Colors.blue;
      statusText = "İşleme Alındı";
    } else if (status == 'resolved') {
      statusColor = Colors.green;
      statusText = "Çözüldü";
    } else if (status == 'replied' || adminReply.isNotEmpty) {
      statusColor = Colors.purple;
      statusText = "Yanıtlandı";
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusText = "Reddedildi";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Bar: Vatandaş Bilgisi ve Durum Rozeti
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF0056D2).withOpacity(0.12),
                  child: const Icon(CupertinoIcons.person_fill, size: 20, color: Color(0xFF0056D2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        createdAt,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Başlık & Açıklama
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.35,
                ),
              ),
            ],

            // Medya
            if (mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showImagePreview(mediaUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: mediaUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 160,
                          color: Colors.black12,
                          child: const Center(child: CupertinoActivityIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 160,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                "Büyüt",
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Telefon Arama Butonu
            if (userPhone.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _makeCall(userPhone),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.phone_fill, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        userPhone,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "• Vatandaşı Ara",
                        style: TextStyle(color: Colors.green, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Daha Önce Yapılan Resmi Yanıt Varsa Göster
            if (adminReply.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0056D2).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.checkmark_shield_fill,
                            size: 14, color: Color(0xFF0056D2)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${widget.institution.name} Resmi Yanıtı",
                            style: const TextStyle(
                              color: Color(0xFF0056D2),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        if (replyDate.isNotEmpty)
                          Text(
                            replyDate,
                            style: const TextStyle(fontSize: 10, color: Colors.black45),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adminReply,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Yanıt Butonu
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminReply.isNotEmpty
                      ? Colors.blueGrey.shade700
                      : const Color(0xFF0056D2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showReplyModal(doc),
                icon: Icon(
                  adminReply.isNotEmpty ? CupertinoIcons.pencil : CupertinoIcons.reply,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  adminReply.isNotEmpty ? "YANITI DÜZENLE / DURUM DEĞİŞTİR" : "YANITLA VE DURUM BELİRLE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
