// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Çek Gönder bildirimlerine admin tarafından verilen cevabı
/// büyük, ferah, rahat okunabilir ve detaylı gösteren modal sheet / dialog.
class CekGonderReplyDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? docId;

  const CekGonderReplyDialog({
    Key? key,
    this.initialData,
    this.docId,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? data,
    String? docId,
  }) async {
    final effectiveDocId = docId ?? data?['docId'] ?? data?['targetId'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CekGonderReplyDialog(
        initialData: data,
        docId: effectiveDocId != null ? effectiveDocId.toString() : null,
      ),
    );
  }

  @override
  State<CekGonderReplyDialog> createState() => _CekGonderReplyDialogState();
}

class _CekGonderReplyDialogState extends State<CekGonderReplyDialog> {
  Map<String, dynamic>? _data;
  double _replyFontSize = 17.0; // Kullanıcı büyütüp küçültebilir

  @override
  void initState() {
    super.initState();
    _data = widget.initialData != null
        ? Map<String, dynamic>.from(widget.initialData!)
        : null;

    if (widget.docId != null && widget.docId!.isNotEmpty) {
      _fetchLatest();
    }
  }

  Future<void> _fetchLatest() async {
    if (widget.docId == null || widget.docId!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cek_gonder_reports')
          .doc(widget.docId)
          .get();

      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          final fetched = doc.data()!;
          fetched['docId'] = doc.id;
          _data = {...?_data, ...fetched};
        });
      }
    } catch (e) {
      debugPrint("Çek Gönder rapor getirme hatası: $e");
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dt = timestamp;
      } else if (timestamp is String) {
        dt = DateTime.tryParse(timestamp) ?? DateTime.now();
      } else {
        return '';
      }
      return DateFormat('dd MMMM yyyy, HH:mm', 'tr').format(dt);
    } catch (e) {
      return '';
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Fotoğraf Detayı',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CupertinoActivityIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = (_data?['title'] ??
            _data?['reportTitle'] ??
            _data?['subject'] ??
            'Vatandaş Bildirimi')
        .toString();

    final userDesc = (_data?['description'] ??
            _data?['reportDesc'] ??
            _data?['message'] ??
            '')
        .toString();

    final adminReply = (_data?['adminReply'] ??
            _data?['reply'] ??
            _data?['body'] ??
            _data?['message'] ??
            '')
        .toString();

    final mediaUrl = (_data?['mediaUrl'] ??
            _data?['imageUrl'] ??
            _data?['photoUrl'] ??
            '')
        .toString();

    final mediaType = (_data?['mediaType'] ?? 'image').toString();
    final userName = (_data?['userName'] ?? '').toString();
    final userPhone =
        (_data?['userPhone'] ?? _data?['phone'] ?? '').toString();
    final isPhoneVerified =
        _data?['phoneVerified'] == true || _data?['isVerified'] == true;
    final createdAt = _data?['createdAt'] ?? _data?['time'];
    final replyDate = _data?['replyDate'] ?? _data?['updatedAt'];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tutamaç (Drag Handle)
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Başlık Çubuğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056D2).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.chat_bubble_2_fill,
                      color: Color(0xFF0056D2), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Çek & Gönder Yanıtı',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (_formatDate(replyDate).isNotEmpty)
                        Text(
                          'Cevaplandı: ${_formatDate(replyDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Kaydırılabilir İçerik
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─────────────────────────────────────────────────────────────
                  // 1. BELEDİYE / ADMİN YANITI (ÖNE ÇIKAN BÜYÜK ALAN)
                  // ─────────────────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0F2E28), const Color(0xFF133E35)]
                            : [const Color(0xFFF0FDF4), const Color(0xFFE6F7ED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'YETKİLİ YANITI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Yazı Boyutu Ayarlayıcı (Büyüt / Küçült)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Yazıyı Küçült',
                              onPressed: () {
                                if (_replyFontSize > 14) {
                                  setState(() => _replyFontSize -= 1.5);
                                }
                              },
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_replyFontSize.toInt()}pt',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Yazıyı Büyüt',
                              onPressed: () {
                                if (_replyFontSize < 26) {
                                  setState(() => _replyFontSize += 1.5);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            // Kopyalama Düğmesi
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Cevabı Kopyala',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: adminReply));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cevap metni kopyalandı 📋'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Büyük, Okunaklı Cevap Metni
                        SelectableText(
                          adminReply.isNotEmpty
                              ? adminReply
                              : 'Yetkili tarafından henüz bir açıklama eklenmedi.',
                          style: GoogleFonts.inter(
                            fontSize: _replyFontSize,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),

                        if (_formatDate(replyDate).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.schedule,
                                  size: 13,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(replyDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ─────────────────────────────────────────────────────────────
                  // 2. VATANDAŞIN BİLDİRİMİ (ORİJİNAL KAYIT)
                  // ─────────────────────────────────────────────────────────────
                  Text(
                    'İlettiğiniz Bildirim',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withOpacity(0.6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (userName.isNotEmpty || userPhone.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0056D2).withOpacity(0.2)
                                  : const Color(0xFF0056D2).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person,
                                    size: 14, color: Color(0xFF0056D2)),
                                const SizedBox(width: 5),
                                Text(
                                  userName.isNotEmpty ? userName : 'Vatandaş',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF0056D2),
                                  ),
                                ),
                                if (userPhone.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text('• $userPhone',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700)),
                                ],
                                if (isPhoneVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified,
                                      size: 13, color: Color(0xFF10B981)),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Konu Başlığı
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),

                        if (userDesc.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            userDesc,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ],

                        if (_formatDate(createdAt).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 13,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                'Gönderildi: ${_formatDate(createdAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Medya (Fotoğraf / Video)
                        if (mediaUrl.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          if (mediaType == 'image') ...[
                            GestureDetector(
                              onTap: () => _openFullScreenImage(mediaUrl),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: CachedNetworkImage(
                                      imageUrl: mediaUrl,
                                      height: 190,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        height: 190,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                            child: CupertinoActivityIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        height: 120,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                            child: Icon(Icons.broken_image,
                                                color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in,
                                              color: Colors.white, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Büyütmek için dokunun',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade900,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.video_library,
                                        color: Colors.white, size: 28),
                                    SizedBox(width: 8),
                                    Text('Gönderilen Video Kaydı',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Kapat Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0056D2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Anladım / Kapat',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
