import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:pazarcik_portal/widgets/interactive_media_viewer.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';
import 'package:pazarcik_portal/utils/map_launcher.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';
import 'package:pazarcik_portal/utils/portal_seo_helper.dart';

class BusinessDetailPage extends StatefulWidget {
  final DocumentSnapshot doc;
  const BusinessDetailPage({Key? key, required this.doc}) : super(key: key);

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage> {
  final Color primaryEmerald = const Color(0xFF004D40); // Zümrüt Yeşili
  final Color accentEmerald = const Color(0xFF00796B);
  final TextEditingController _commentController = TextEditingController();

  bool _isSaved = false;
  double _userRating = 5.0;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _replyToId;
  String? _replyToName;

  // 🔒 Sahiplik başvurusu durumu
  bool _hasPendingClaim = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    _checkExistingClaim();
    try {
      final name = (widget.doc.data() as Map<String, dynamic>?)?['businessName']
              ?.toString() ??
          (widget.doc.data() as Map<String, dynamic>?)?['name']?.toString() ??
          'İşletme';
      PortalSeoHelper.updateTitle(name);
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.dispose();
    PortalSeoHelper.resetTitle();
    super.dispose();
  }

  // 🔒 Mevcut sahiplik başvurusu kontrolü
  Future<void> _checkExistingClaim() async {
    if (_currentUserId == null) return;
    try {
      final existing = await FirebaseFirestore.instance
          .collection('business_claims')
          .where('businessId', isEqualTo: widget.doc.id)
          .where('userId', isEqualTo: _currentUserId)
          .where('status', whereIn: ['pending', 'approved'])
          .limit(1)
          .get();
      if (mounted) {
        setState(() => _hasPendingClaim = existing.docs.isNotEmpty);
      }
    } catch (_) {}
  }

  // --- PAYLAŞIM FONKSİYONU ---
  void _shareBusiness(Map<String, dynamic> data) {
    String name = data['businessName'] ?? "İşletme";
    String category = data['category'] ?? "Sektör";

    String shareUrl =
        "https://www.pazarcikportal.com/isletme?id=${widget.doc.id}";

    String shareText = "🏢 Pazarcık Rehberinde Yeni İşletme!\n\n"
        "📍 Adı: $name\n"
        "📂 Kategori: $category\n\n"
        "🔗 Detaylar ve Konum İçin Tıkla:\n$shareUrl";

    Share.share(shareText);
  }

  // --- Telefon Arama ---
  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // --- WhatsApp Açma ---
  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  // --- Sosyal Medya & Linkler ---
  Future<void> _launchSocial(String platform, String username) async {
    if (username.isEmpty) return;
    Uri uri;
    if (platform == "instagram") {
      uri = Uri.parse("https://instagram.com/$username");
    } else if (platform == "facebook") {
      uri = Uri.parse(username.startsWith('http')
          ? username
          : "https://facebook.com/$username");
    } else {
      uri = Uri.parse(
          username.startsWith('http') ? username : "https://$username");
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // --- Favoriler ---
  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('saved_businesses') ?? [];
    setState(() => _isSaved = savedIds.contains(widget.doc.id));
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('saved_businesses') ?? [];
    if (_isSaved) {
      savedIds.remove(widget.doc.id);
    } else {
      savedIds.add(widget.doc.id);
    }
    await prefs.setStringList('saved_businesses', savedIds);
    setState(() => _isSaved = !_isSaved);
    _showToast(_isSaved ? "Favorilere eklendi" : "Favorilerden çıkarıldı");
  }

  // --- Yorum Yazma ---
  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (_currentUserId == null) {
      _showToast("Yorum yapmak için lütfen önce giriş yapın.");
      return;
    }

    final commentRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.doc.id)
        .collection('comments');

    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;
    final fullName = await CommentIdentity.currentUserFullName();

    await commentRef.add({
      'comment': _commentController.text.trim(),
      'rating': _userRating,
      'userId': _currentUserId,
      ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
      'parentId': _replyToId,
      'replyToName': _replyToName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final allComments = await commentRef.get();
    double totalRating = 0;
    final ratingDocs = allComments.docs.where((doc) {
      final data = doc.data();
      return data['parentId'] == null;
    }).toList();
    for (var doc in ratingDocs) {
      totalRating += doc.data()['rating'] ?? 0;
    }
    double newAverage =
        ratingDocs.isEmpty ? 0 : totalRating / ratingDocs.length;

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.doc.id)
        .update({
      'rating': double.parse(newAverage.toStringAsFixed(1)),
      'reviewCount': ratingDocs.length,
    });

    _commentController.clear();
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
    FocusScope.of(context).unfocus();
    _showToast("Değerlendirmeniz başarıyla yayınlandı!");
  }

  Future<void> _deleteComment(String commentId) async {
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.doc.id)
        .collection('comments')
        .doc(commentId)
        .delete();
    _showToast("Yorum silindi.");
  }

  Future<void> _editComment(String commentId, String currentComment) async {
    final controller = TextEditingController(text: currentComment);
    final saved = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Yorumu Düzenle"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            placeholder: "Yorumunuz",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Kaydet"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (saved != true || controller.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.doc.id)
        .collection('comments')
        .doc(commentId)
        .update({
      'comment': controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _showToast("Yorum güncellendi.");
  }

  void _setReply(String commentId, String name) {
    setState(() {
      _replyToId = commentId;
      _replyToName = name;
    });
  }

  // --- SAHİPLİK BAŞVURUSU GÖNDERME ---
  Future<void> _submitClaimRequest(
      String name, String phone, String taxNumber) async {
    if (name.isEmpty || phone.isEmpty || taxNumber.isEmpty) {
      _showToast("Lütfen tüm alanları doldurunuz.");
      return;
    }
    if (_currentUserId == null) {
      _showToast("Başvuru yapmak için giriş yapmalısınız.");
      return;
    }

    try {
      final existingClaim = await FirebaseFirestore.instance
          .collection('business_claims')
          .where('businessId', isEqualTo: widget.doc.id)
          .where('userId', isEqualTo: _currentUserId)
          .where('status', whereIn: ['pending', 'approved'])
          .limit(1)
          .get();

      if (existingClaim.docs.isNotEmpty) {
        Navigator.pop(context);
        _showToast(
            "Bu işletme için zaten bir başvurunuz bulunmaktadır. Yönetim incelemektedir.");
        return;
      }

      final claimRef =
          await FirebaseFirestore.instance.collection('business_claims').add({
        'businessId': widget.doc.id,
        'businessName': widget.doc['businessName'],
        'userId': _currentUserId,
        'applicantName': name,
        'phone': phone,
        'taxNumber': taxNumber,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await AdminNotificationService.instance.notifyAdmin(
        title: 'Yeni sahiplik başvurusu',
        body: '$name, ${widget.doc['businessName']} için sahiplik talebi gönderdi.',
        type: AdminNotifType.ownershipClaim,
        docId: claimRef.id,
        extra: {
          'businessId': widget.doc.id,
          'userId': _currentUserId ?? '',
          'phone': phone,
        },
      );

      if (mounted) setState(() => _hasPendingClaim = true);
      Navigator.pop(context);
      _showToast("Sahiplik başvurunuz alındı. Yönetim inceleyecektir.");
    } catch (e) {
      _showToast("Bir hata oluştu: $e");
    }
  }

  // --- SAHİPLİK BAŞVURUSU FORMU (BOTTOM SHEET) ---
  void _showClaimDialog(Map<String, dynamic> data) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController taxCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 24,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sahiplik Başvurusu",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        "Altın Doğrulama Rozetini Alın",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${data['businessName']} adlı işletmenin yetkilisi olduğunuzu doğrulamak için lütfen aşağıdaki bilgileri doldurun.",
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 13),
            ),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: nameCtrl,
              placeholder: "Adınız Soyadınız",
              padding: const EdgeInsets.all(14),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.person_solid, color: Colors.grey),
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2438) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: phoneCtrl,
              placeholder: "İletişim Numaranız",
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(14),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.phone_fill, color: Colors.grey),
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2438) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: taxCtrl,
              placeholder: "Vergi No veya T.C. Kimlik No",
              keyboardType: TextInputType.number,
              padding: const EdgeInsets.all(14),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.doc_text_fill, color: Colors.grey),
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2438) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _submitClaimRequest(
                    nameCtrl.text, phoneCtrl.text, taxCtrl.text),
                child: Text(
                  "Talebi Gönder",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF131B2E) : Colors.white;

    var data = widget.doc.data() as Map<String, dynamic>;
    String? ownerId = data['ownerId'];
    bool isOwner = _currentUserId != null && ownerId == _currentUserId;
    bool hasOwner = ownerId != null && ownerId.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. MODERN FOTOĞRAF VE BAŞLIK APPBULL
          _buildSliverAppBar(data),

          // 2. ANA İÇERİK
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık, Kategori, Yıldız ve Doğrulama
                  _buildHeader(data, isDark),
                  const SizedBox(height: 20),

                  // Hızlı Eylem Butonları (Ara, WhatsApp, Yol Tarifi, Paylaş, Kaydet)
                  _buildModernActions(data, isDark),
                  const SizedBox(height: 20),

                  // Sahiplik Banner'ı (Altın Doğrulama Rozeti veya Başvuru Çağrısı)
                  if (!hasOwner && !isOwner) ...[
                    _buildClaimBanner(data, isDark),
                    const SizedBox(height: 20),
                  ] else if (hasOwner) ...[
                    _buildClaimBanner(data, isDark),
                    const SizedBox(height: 20),
                  ],

                  // Hakkında Bölümü
                  if (data['description'] != null &&
                      data['description'].toString().trim().isNotEmpty) ...[
                    _buildModernSectionCard(
                      title: "İşletme Hakkında",
                      icon: CupertinoIcons.info_circle_fill,
                      isDark: isDark,
                      child: Text(
                        data['description'].toString().trim(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Adres ve Harita Bilgisi
                  if (data['addressDesc'] != null &&
                      data['addressDesc'].toString().trim().isNotEmpty) ...[
                    _buildModernSectionCard(
                      title: "Adres ve Konum",
                      icon: CupertinoIcons.location_solid,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['addressDesc'].toString().trim(),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await PortalMapLauncher.open(
                                context,
                                address: (data['address'] ??
                                        data['addressDesc'] ??
                                        data['businessName'] ??
                                        'Pazarcık')
                                    .toString(),
                                fallbackUrl: data['mapLink']?.toString(),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(CupertinoIcons.location_fill,
                                size: 16),
                            label: const Text(
                              "Haritada Yol Tarifi Al",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Vitrin & Ürün Galerisi (Pinch-to-Zoom Destekli)
                  _buildGallerySection(
                      data['galleryUrls'] as List<dynamic>?, isDark),

                  // Ürünler & Hizmet Etiketleri
                  if (data['tags'] != null && (data['tags'] as List).isNotEmpty) ...[
                    _buildModernSectionCard(
                      title: "Hizmetler ve Ürünler",
                      icon: CupertinoIcons.tag_fill,
                      isDark: isDark,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (data['tags'] as List).map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryEmerald.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryEmerald.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.checkmark_alt,
                                    size: 13, color: accentEmerald),
                                const SizedBox(width: 5),
                                Text(
                                  t.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sosyal Medya ve Web Bağlantıları
                  _buildSocialMediaSection(data['socialMedia'], isDark),
                  const SizedBox(height: 24),

                  // Değerlendirmeler & Yorumlar Başlığı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Müşteri Yorumları",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "${data['rating'] ?? 0.0}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Yorum Listesi
                  _buildCommentsList(isDark),
                  const SizedBox(height: 160), // Alttaki yorum yazma çubuğu için boşluk
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildModernCommentBar(surfaceColor, isDark),
    );
  }

  // --- MODERN SLIVER APP BAR ---
  Widget _buildSliverAppBar(Map<String, dynamic> data) {
    final List imageUrls = data['imageUrls'] as List? ?? [];
    final String firstImage =
        imageUrls.isNotEmpty ? imageUrls.first.toString() : "";

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: primaryEmerald,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.55),
          child: IconButton(
            icon: const Icon(CupertinoIcons.chevron_left,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.55),
            child: IconButton(
              icon: Icon(
                _isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: _isSaved ? const Color(0xFFFF5E62) : Colors.white,
                size: 20,
              ),
              onPressed: _toggleSave,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.55),
            child: IconButton(
              icon: const Icon(CupertinoIcons.share,
                  color: Colors.white, size: 19),
              onPressed: () => _shareBusiness(data),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Resim (Tıklanınca Tam Ekran Büyür)
            GestureDetector(
              onTap: () {
                if (firstImage.isNotEmpty) {
                  InteractiveMediaViewer.show(
                    context,
                    imageUrls: [firstImage],
                    title: data['businessName'],
                  );
                }
              },
              child: firstImage.isNotEmpty
                  ? PortalNetworkImage(
                      url: firstImage,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: primaryEmerald,
                      child: const Center(
                        child: Icon(CupertinoIcons.building_2_fill,
                            color: Colors.white60, size: 64),
                      ),
                    ),
            ),

            // Üst ve Alt Gradyan Gölgeleri (Kontrollerin ve metinlerin okunması için)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Sağ Alttaki Tam Ekran İncele İpucu
            if (firstImage.isNotEmpty)
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(CupertinoIcons.viewfinder,
                          color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text(
                        "Büyütmek İçin Dokun",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- BAŞLIK, PUAN VE DOĞRULAMA ALANI ---
  Widget _buildHeader(Map<String, dynamic> data, bool isDark) {
    final bool isOwnershipVerified = data['claimStatus'] == 'approved' ||
        (data['claimedBy'] != null &&
            data['claimedBy'].toString().trim().isNotEmpty) ||
        data['isClaimed'] == true ||
        data['claimed'] == true ||
        data['isVerifiedOwner'] == true ||
        data['ownershipVerified'] == true ||
        (data['ownerId'] != null &&
            data['ownerId'].toString().trim().isNotEmpty);

    final String bName = data['businessName'] ?? "İşletme";
    final String mainCat = data['mainCategory'] ?? "";
    final String subCat = data['category'] ?? "";
    final double rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Satır: İşletme Adı + Altın veya Yeşil Onay Rozeti
        Row(
          children: [
            Flexible(
              child: Text(
                bName,
                style: GoogleFonts.inter(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildVerificationBadge(isOwnershipVerified,
                size: 21, showLabel: isOwnershipVerified),
          ],
        ),
        const SizedBox(height: 6),

        // 2. Satır: Kategori & Puan Rozeti
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mainCat.isNotEmpty && subCat.isNotEmpty
                    ? "$mainCat • $subCat"
                    : mainCat.isNotEmpty
                        ? mainCat
                        : subCat.isNotEmpty
                            ? subCat
                            : "Esnaf Rehberi",
                style: GoogleFonts.inter(
                  color: accentEmerald,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),

            // Yıldız ve Değerlendirme Sayısı
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 3),
                Text(
                  rating > 0 ? rating.toStringAsFixed(1) : "Yeni",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (reviewCount > 0)
                  Text(
                    " ($reviewCount yorum)",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- DOĞRULAMA ROZETİ (Altın Mühür vs. Yeşil Tik) ---
  Widget _buildVerificationBadge(bool isOwnershipVerified,
      {double size = 18, bool showLabel = false}) {
    if (isOwnershipVerified) {
      return Tooltip(
        message: "Doğrulanmış İşletme Sahibi (Altın Doğrulama)",
        child: Container(
          padding: showLabel
              ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5)
              : EdgeInsets.zero,
          decoration: showLabel
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: const Color(0xFFF59E0B),
                  size: size,
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                const Text(
                  "Altın Onaylı",
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      return Tooltip(
        message: "Rehber Kayıtlı ve Onaylı İşletme",
        child: Icon(
          Icons.verified_rounded,
          color: const Color(0xFF10B981),
          size: size,
        ),
      );
    }
  }

  // --- MODERN EYLEM BUTONLARI (Ara, WhatsApp, Yol Tarifi) ---
  Widget _buildModernActions(Map<String, dynamic> data, bool isDark) {
    final String phone = (data['contact'] ?? data['phone'] ?? '').toString();

    return Row(
      children: [
        // 1. Ara Butonu
        if (phone.isNotEmpty)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _makeCall(phone),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              icon: const Icon(CupertinoIcons.phone_fill, size: 16),
              label: const Text(
                "Ara",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        if (phone.isNotEmpty) const SizedBox(width: 8),

        // 2. WhatsApp Butonu
        if (phone.isNotEmpty)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openWhatsApp(phone),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              icon: const Icon(CupertinoIcons.chat_bubble_2_fill, size: 16),
              label: const Text(
                "WhatsApp",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        if (phone.isNotEmpty) const SizedBox(width: 8),

        // 3. Yol Tarifi Butonu
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await PortalMapLauncher.open(
                context,
                address: (data['address'] ??
                        data['addressDesc'] ??
                        data['businessName'] ??
                        'Pazarcık')
                    .toString(),
                fallbackUrl: data['mapLink']?.toString(),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(CupertinoIcons.location_fill, size: 16),
            label: const Text(
              "Yol Tarifi",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // --- SAHİPLİK BANNER'I (Doğrulanmış vs. Sahipsiz) ---
  Widget _buildClaimBanner(Map<String, dynamic> data, bool isDark) {
    final bool isOwnershipVerified = data['claimStatus'] == 'approved' ||
        (data['claimedBy'] != null &&
            data['claimedBy'].toString().trim().isNotEmpty) ||
        data['isClaimed'] == true ||
        data['claimed'] == true ||
        data['isVerifiedOwner'] == true ||
        data['ownershipVerified'] == true ||
        (data['ownerId'] != null &&
            data['ownerId'].toString().trim().isNotEmpty);

    // 🌟 Sahipliği Doğrulanmış İşletme (Altın Rozet)
    if (isOwnershipVerified) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF261D0C), const Color(0xFF332610)]
                : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.verified_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Doğrulanmış Resmi İşletme",
                    style: GoogleFonts.inter(
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Bu işletmenin sahipliği onaylanmıştır ve Altın Doğrulama Rozetine sahiptir.",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFFB45309),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.verified_rounded,
                color: Color(0xFFF59E0B), size: 20),
          ],
        ),
      );
    }

    // ⏳ Zaten Başvuru Yapılmış
    if (_hasPendingClaim) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0C2417), const Color(0xFF133621)]
                : [Colors.green.shade50, Colors.green.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade400, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.clock_solid,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Sahiplik Başvurunuz İncelemede",
                      style: TextStyle(
                          color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text("Yönetim ekibimiz başvurunuzu en kısa sürede değerlendirecektir.",
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.green.shade800,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(CupertinoIcons.checkmark_circle_fill,
                color: Colors.green.shade500, size: 20),
          ],
        ),
      );
    }

    // 🟠 Henüz Sahipliği Alınmamış → Sahiplik Başvuru Çağrısı
    return GestureDetector(
      onTap: () async {
        if (_currentUserId == null) {
          _showToast("Sahiplik başvurusu yapmak için lütfen giriş yapın.");
          return;
        }
        final existing = await FirebaseFirestore.instance
            .collection('business_claims')
            .where('businessId', isEqualTo: widget.doc.id)
            .where('userId', isEqualTo: _currentUserId)
            .where('status', whereIn: ['pending', 'approved'])
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          setState(() => _hasPendingClaim = true);
          _showToast(
              "Bu işletme için zaten bir başvurunuz bulunmaktadır.");
          return;
        }
        _showClaimDialog(data);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF261D0C), const Color(0xFF332610)]
                : [Colors.orange.shade50, Colors.orange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.checkmark_seal_fill,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bu işletmenin sahibi misiniz?",
                      style: TextStyle(
                          color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text("Sayfayı devralmak ve Altın Rozet almak için tıklayın.",
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.orange.shade800,
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward,
                color: Colors.orange, size: 18),
          ],
        ),
      ),
    );
  }

  // --- VİTRİN & GALERİ BÖLÜMÜ (Pinch-to-Zoom Entegre) ---
  Widget _buildGallerySection(List<dynamic>? galleryUrls, bool isDark) {
    if (galleryUrls == null || galleryUrls.isEmpty) return const SizedBox();

    final List<String> images =
        galleryUrls.map((e) => e.toString()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.photo_on_rectangle,
                    size: 18, color: accentEmerald),
                const SizedBox(width: 8),
                Text(
                  "Vitrin & Galeri",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              "${images.length} Fotoğraf",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  InteractiveMediaViewer.show(
                    context,
                    imageUrls: images,
                    initialIndex: index,
                    title: "Vitrin Galerisi",
                  );
                },
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: PortalNetworkImage(
                      url: images[index],
                      fit: BoxFit.cover,
                      placeholder: const Center(
                        child: CupertinoActivityIndicator(radius: 12),
                      ),
                      errorWidget: const Icon(CupertinoIcons.photo,
                          color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- SOSYAL MEDYA BÖLÜMÜ ---
  Widget _buildSocialMediaSection(Map? social, bool isDark) {
    if (social == null || social.isEmpty) return const SizedBox();

    final insta = (social['instagram'] ?? '').toString().trim();
    final fb = (social['facebook'] ?? '').toString().trim();
    final web = (social['website'] ?? '').toString().trim();

    if (insta.isEmpty && fb.isEmpty && web.isEmpty) return const SizedBox();

    return _buildModernSectionCard(
      title: "Sosyal Medya & İnternet",
      icon: CupertinoIcons.globe,
      isDark: isDark,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (insta.isNotEmpty)
            ActionChip(
              avatar: const Icon(CupertinoIcons.camera_fill,
                  size: 15, color: Colors.purple),
              label: Text("Instagram @$insta"),
              onPressed: () => _launchSocial("instagram", insta),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
            ),
          if (fb.isNotEmpty)
            ActionChip(
              avatar: const Icon(CupertinoIcons.link,
                  size: 15, color: Color(0xFF1877F2)),
              label: const Text("Facebook"),
              onPressed: () => _launchSocial("facebook", fb),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
            ),
          if (web.isNotEmpty)
            ActionChip(
              avatar: const Icon(CupertinoIcons.globe,
                  size: 15, color: Colors.teal),
              label: Text(web.replaceAll('https://', '').replaceAll('http://', '')),
              onPressed: () => _launchSocial("web", web),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
            ),
        ],
      ),
    );
  }

  // --- YARDIMCI KART YAPISI ---
  Widget _buildModernSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentEmerald),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // --- YORUM LİSTESİ ---
  Widget _buildCommentsList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.doc.id)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CupertinoActivityIndicator(radius: 12));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(CupertinoIcons.chat_bubble_2,
                      size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    "Henüz bir müşteri yorumu yazılmamış.",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "İlk değerlendirmeyi siz yazarak işletmeye destek olun!",
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final mainComments = docs.where((doc) {
          final c = doc.data() as Map<String, dynamic>;
          return c['parentId'] == null;
        }).toList();

        return Column(
          children: mainComments.map((doc) {
            var c = doc.data() as Map<String, dynamic>;
            final replies = docs.where((replyDoc) {
              final reply = replyDoc.data() as Map<String, dynamic>;
              return reply['parentId'] == doc.id;
            }).toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommentTile(doc, c, isDark: isDark),
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...replies.map((replyDoc) => Padding(
                          padding: const EdgeInsets.only(left: 20, top: 6),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _buildCommentTile(
                              replyDoc,
                              replyDoc.data() as Map<String, dynamic>,
                              isReply: true,
                              isDark: isDark,
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCommentTile(DocumentSnapshot doc, Map<String, dynamic> c,
      {bool isReply = false, required bool isDark}) {
    final visibleName = CommentIdentity.visibleName(c);
    final isMine = c['userId'] == _currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: accentEmerald.withValues(alpha: 0.15),
              child: Text(
                visibleName.isNotEmpty ? visibleName[0].toUpperCase() : "U",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentEmerald),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                visibleName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (!isReply)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: i < (c['rating'] ?? 0)
                        ? Colors.amber
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          c['comment'] ?? "",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () => _setReply(doc.id, visibleName),
              child: Text(
                "Yanıtla",
                style: TextStyle(
                  fontSize: 12,
                  color: accentEmerald,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _editComment(doc.id, c['comment'] ?? ""),
                child: const Text("Düzenle",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _deleteComment(doc.id),
                child: const Text("Sil",
                    style: TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- MODERN YORUM VE DEĞERLENDİRME ÇUBUĞU ---
  Widget _buildModernCommentBar(Color surfaceColor, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Yanıtlanan Kişi Bildirimi
          if (_replyToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(CupertinoIcons.reply, size: 14, color: accentEmerald),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Yanıtlanan: $_replyToName",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentEmerald,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyToId = null;
                      _replyToName = null;
                    }),
                    child:
                        const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Yıldız Puanı Seçici
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final isLit = index < _userRating;
              return GestureDetector(
                onTap: () => setState(() => _userRating = index + 1.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    isLit ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isLit
                        ? const Color(0xFFF59E0B)
                        : (isDark ? Colors.white24 : Colors.grey.shade400),
                    size: 28,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Yorum Giriş Alanı + Gönder Butonu
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C2438)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Deneyiminizi veya düşüncenizi paylaşın...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendComment,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentEmerald,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.paperplane_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
