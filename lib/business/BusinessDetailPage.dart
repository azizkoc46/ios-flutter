import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';

class BusinessDetailPage extends StatefulWidget {
  final DocumentSnapshot doc;
  const BusinessDetailPage({Key? key, required this.doc}) : super(key: key);

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage> {
  final Color primaryColor = const Color(0xFF004D40); // Zümrüt Yeşili
  final TextEditingController _commentController = TextEditingController();

  bool _isSaved = false;
  double _userRating = 5.0;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  // --- MAVİ LİNK PAYLAŞIM FONKSİYONU ---
  void _shareBusiness(Map<String, dynamic> data) {
    String name = data['businessName'] ?? "İşletme";
    String category = data['category'] ?? "Sektör";

    String shareUrl =
        "https://pazarcik-portal-7faf2.web.app/isletme?id=${widget.doc.id}";

    String shareText = "🏢 Pazarcık Rehberinde Yeni İşletme!\n\n"
        "📍 Adı: $name\n"
        "📂 Kategori: $category\n\n"
        "🔗 Detaylar ve Konum İçin Tıkla:\n$shareUrl";

    Share.share(shareText);
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
      _showToast("Yorum yapmak için giriş yapmalısınız.");
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
    _showToast("Yorumunuz eklendi!");
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

      Navigator.pop(context);
      _showToast("Talebiniz başarıyla alındı. Yönetim inceleyecektir.");
    } catch (e) {
      _showToast("Bir hata oluştu: $e");
    }
  }

  // --- SAHİPLİK BAŞVURUSU FORMU (BOTTOM SHEET) ---
  void _showClaimDialog(Map<String, dynamic> data) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController taxCtrl = TextEditingController();

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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Sahiplik Talebi",
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              "${data['businessName']} adlı işletmenin yetkilisi olduğunuzu doğrulamak için aşağıdaki bilgileri doldurun.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: nameCtrl,
              placeholder: "Adınız Soyadınız",
              padding: const EdgeInsets.all(16),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.person_solid, color: Colors.grey),
              ),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: phoneCtrl,
              placeholder: "İletişim Numaranız",
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(16),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.phone_fill, color: Colors.grey),
              ),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: taxCtrl,
              placeholder: "Vergi Numaranız (veya T.C.)",
              keyboardType: TextInputType.number,
              padding: const EdgeInsets.all(16),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.doc_text_fill, color: Colors.grey),
              ),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
                onPressed: () => _submitClaimRequest(
                    nameCtrl.text, phoneCtrl.text, taxCtrl.text),
                child: const Text("Talebi Gönder",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.doc.data() as Map<String, dynamic>;
    String? ownerId = data['ownerId'];
    bool isOwner = _currentUserId != null && ownerId == _currentUserId;
    bool hasOwner = ownerId != null && ownerId.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(data),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(data),
                  const SizedBox(height: 25),
                  _buildActions(data),
                  const Divider(height: 50, thickness: 0.5),

                  if (!hasOwner && !isOwner) ...[
                    _buildClaimBanner(data),
                    const SizedBox(height: 20),
                  ],

                  _buildSection("Hakkında", data['description']),
                  _buildSection("Adres Bilgisi", data['addressDesc']),

                  // 🔥 YENİ EKLENEN: Vitrin & Ürün Galerisi
                  _buildGallerySection(data['galleryUrls'] as List<dynamic>?),

                  _buildSection("Ürünler & Hizmetler", null,
                      isTags: true, tags: data['tags']),
                  _buildSection("Sosyal Medya", null,
                      isSocial: true, social: data['socialMedia']),

                  const Divider(height: 50, thickness: 0.5),
                  const Text("Yorumlar",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildCommentsList(),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildCommentBar(),
    );
  }

  // 🔥 YENİ EKLENEN: Galeri Widget'ı
  Widget _buildGallerySection(List<dynamic>? galleryUrls) {
    if (galleryUrls == null || galleryUrls.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Vitrin & Galeri",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120, // Resimlerin yüksekliği
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: galleryUrls.length,
            itemBuilder: (context, index) {
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PortalNetworkImage(
                    url: galleryUrls[index].toString(),
                    fit: BoxFit.cover,
                    placeholder:
                        const Center(child: CupertinoActivityIndicator()),
                    errorWidget:
                        const Icon(CupertinoIcons.photo, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 25), // Altındaki bölümle boşluk
      ],
    );
  }

  Widget _buildClaimBanner(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => _showClaimDialog(data),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.orange.shade100],
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
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.checkmark_seal_fill,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bu işletmenin sahibi misiniz?",
                      style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Sayfayı devralmak ve yönetmek için başvuru yapın.",
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 12)),
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

  Widget _buildSliverAppBar(Map<String, dynamic> data) => SliverAppBar(
        expandedHeight: 280,
        pinned: true,
        backgroundColor: primaryColor,
        leading: const BackButton(color: Colors.white),
        flexibleSpace: FlexibleSpaceBar(
            background:
                (data['imageUrls'] != null && data['imageUrls'].isNotEmpty)
                    ? PortalNetworkImage(
                        url: data['imageUrls'][0], fit: BoxFit.cover)
                    : Container(color: Colors.grey)),
      );

  Widget _buildHeader(Map<String, dynamic> data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(data['businessName'] ?? "",
                      style: GoogleFonts.inter(
                          fontSize: 24, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  Text(" ${data['rating'] ?? 0.0}",
                      style: const TextStyle(fontWeight: FontWeight.bold))
                ]),
              )
            ],
          ),
          Text(data['category'] ?? "",
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      );

  Widget _buildActions(Map<String, dynamic> data) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionIcon(CupertinoIcons.phone_fill, "Ara", Colors.green,
              () => launchUrl(Uri.parse("tel:${data['contact']}"))),
          _actionIcon(CupertinoIcons.location_fill, "Yol Tarifi", Colors.blue,
              () async {
            final String? mapUrl = data['mapLink'];
            if (mapUrl != null && mapUrl.isNotEmpty) {
              final Uri uri = Uri.parse(mapUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _showToast("Konum bilgisi bulunamadı.");
            }
          }),
          _actionIcon(CupertinoIcons.share, "Paylaş", Colors.orange,
              () => _shareBusiness(data)),
          _actionIcon(
              _isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              "Kaydet",
              Colors.pink,
              _toggleSave),
        ],
      );

  Widget _actionIcon(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.bold))
        ]),
      );

  Widget _buildSection(String title, String? content,
      {bool isTags = false, List? tags, bool isSocial = false, Map? social}) {
    if (!isTags && !isSocial && (content == null || content.isEmpty))
      return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (isTags)
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (tags ?? [])
                  .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(e, style: const TextStyle(fontSize: 12))))
                  .toList())
        else if (isSocial)
          Row(children: [
            if (social?['instagram'] != "" && social?['instagram'] != null)
              IconButton(
                  icon: const Icon(CupertinoIcons.camera_fill,
                      color: Colors.purple),
                  onPressed: () =>
                      _launchSocial("instagram", social?['instagram'])),
            if (social?['facebook'] != "" && social?['facebook'] != null)
              IconButton(
                  icon: const Icon(CupertinoIcons.link, color: Colors.blue),
                  onPressed: () =>
                      _launchSocial("facebook", social?['facebook'])),
            if (social?['website'] != "" && social?['website'] != null)
              IconButton(
                  icon: const Icon(CupertinoIcons.globe, color: Colors.teal),
                  onPressed: () => _launchSocial("web", social?['website'])),
          ])
        else
          Text(content ?? "",
              style: const TextStyle(color: Colors.black87, height: 1.4)),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.doc.id)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        if (snapshot.data!.docs.isEmpty)
          return const Text("Henüz yorum yapılmamış.");
        final docs = snapshot.data!.docs;
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
            return Column(
              children: [
                _buildCommentTile(doc, c),
                ...replies.map((replyDoc) => Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: _buildCommentTile(
                          replyDoc, replyDoc.data() as Map<String, dynamic>,
                          isReply: true),
                    )),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCommentTile(DocumentSnapshot doc, Map<String, dynamic> c,
      {bool isReply = false}) {
    final visibleName = CommentIdentity.visibleName(c);
    final isMine = c['userId'] == _currentUserId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(children: [
        Expanded(
          child: Text(visibleName,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        if (!isReply)
          ...List.generate(
              5,
              (i) => Icon(Icons.star,
                  size: 12,
                  color: i < (c['rating'] ?? 0) ? Colors.amber : Colors.grey)),
      ]),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['comment'] ?? ""),
          const SizedBox(height: 4),
          Row(children: [
            GestureDetector(
              onTap: () => _setReply(doc.id, visibleName),
              child: const Text("Yanıtla",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold)),
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
                    style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ]
          ])
        ],
      ),
    );
  }

  Widget _buildCommentBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
      ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Text("Yanıtlanıyor: $_replyToName",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _replyToId = null;
                    _replyToName = null;
                  }),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                )
              ]),
            ),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (index) => GestureDetector(
                      onTap: () => setState(() => _userRating = index + 1.0),
                      child: Icon(
                          index < _userRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: CupertinoTextField(
                    controller: _commentController,
                    placeholder: "Deneyiminizi paylaşın...",
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12)))),
            const SizedBox(width: 10),
            CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _sendComment,
                child: Icon(CupertinoIcons.arrow_up_circle_fill,
                    color: primaryColor, size: 42)),
          ]),
        ],
      ),
    );
  }
}
