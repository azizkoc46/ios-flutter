import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';
import 'package:pazarcik_portal/utils/map_launcher.dart';

class PublicDetailPage extends StatefulWidget {
  final DocumentSnapshot doc;
  const PublicDetailPage({Key? key, required this.doc}) : super(key: key);

  @override
  State<PublicDetailPage> createState() => _PublicDetailPageState();
}

class _PublicDetailPageState extends State<PublicDetailPage> {
  // 🔥 Kamu Kurumu Teması: Türk Bayrağı Kırmızısı
  final Color publicRed = const Color(0xFFD32F2F);
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

  // --- Yardımcı Fonksiyonlar ---
  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('saved_public') ?? [];
    setState(() => _isSaved = savedIds.contains(widget.doc.id));
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIds = prefs.getStringList('saved_public') ?? [];
    if (_isSaved)
      savedIds.remove(widget.doc.id);
    else
      savedIds.add(widget.doc.id);
    await prefs.setStringList('saved_public', savedIds);
    setState(() => _isSaved = !_isSaved);
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Yorum yapmak için giriş yapmalısınız."),
          behavior: SnackBarBehavior.floating));
      return;
    }

    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;
    final fullName = await CommentIdentity.currentUserFullName();

    final commentRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.doc.id)
        .collection('comments');

    await commentRef.add({
      'comment': _commentController.text.trim(),
      'rating': _userRating,
      'userId': _currentUserId,
      ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
      'parentId': _replyToId,
      'replyToName': _replyToName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Geri bildiriminiz iletildi."),
        behavior: SnackBarBehavior.floating));
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
  }

  void _setReply(String commentId, String name) {
    setState(() {
      _replyToId = commentId;
      _replyToName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.doc.data() as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: Colors.white,
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
                  _buildSection("Kurum Hakkında", data['description']),
                  _buildSection("Adres & Konum", data['addressDesc']),
                  _buildSection("İletişim & Sosyal Medya", null,
                      isSocial: true, social: data['socialMedia']),
                  const Divider(height: 50, thickness: 0.5),
                  const Text("Vatandaş Yorumları",
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

  // --- Widget Bileşenleri ---

  Widget _buildSliverAppBar(Map<String, dynamic> data) => SliverAppBar(
        expandedHeight: 250,
        pinned: true,
        backgroundColor: publicRed,
        leading: const BackButton(color: Colors.white),
        flexibleSpace: FlexibleSpaceBar(
          background: data['imageUrls'] != null &&
                  (data['imageUrls'] as List).isNotEmpty
              ? Image.network(data['imageUrls'][0], fit: BoxFit.cover)
              : Container(
                  color: publicRed.withOpacity(0.1),
                  child:
                      Icon(Icons.account_balance, size: 80, color: publicRed)),
        ),
      );

  Widget _buildHeader(Map<String, dynamic> data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['businessName'] ?? "Kamu Kurumu",
              style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.bold, color: publicRed)),
          Text(data['mainCategory'] ?? "Kamu Hizmeti",
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      );

  Widget _buildActions(Map<String, dynamic> data) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionIcon(CupertinoIcons.phone_fill, "Ara", Colors.green,
              () => launchUrl(Uri.parse("tel:${data['contact']}"))),
          _actionIcon(CupertinoIcons.location_solid, "Yol Tarifi", publicRed,
              () async {
            await PortalMapLauncher.open(
              context,
              address: (data['address'] ?? data['businessName'] ?? 'Pazarcık')
                  .toString(),
              fallbackUrl: data['mapLink']?.toString(),
            );
          }),
          _actionIcon(
              CupertinoIcons.share,
              "Paylaş",
              Colors.blue,
              () => Share.share(
                  "${data['businessName']} detayları için Pazarcık Portal'a bak!")),
          _actionIcon(
              _isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              "Kaydet",
              Colors.pink,
              _toggleSave),
        ],
      );

  Widget _actionIcon(IconData i, String l, Color c, VoidCallback t) =>
      GestureDetector(
        onTap: t,
        child: Column(children: [
          Icon(i, color: c, size: 28),
          const SizedBox(height: 5),
          Text(l,
              style: TextStyle(
                  fontSize: 11, color: c, fontWeight: FontWeight.bold))
        ]),
      );

  Widget _buildSection(String title, String? content,
      {bool isSocial = false, Map? social}) {
    if (!isSocial && (content == null || content.isEmpty))
      return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: publicRed)),
        const SizedBox(height: 8),
        if (isSocial)
          Row(children: [
            if (social?['website'] != "")
              IconButton(
                  icon:
                      const Icon(CupertinoIcons.globe, color: Colors.blueGrey),
                  onPressed: () => launchUrl(Uri.parse(social!['website']))),
            if (social?['instagram'] != "")
              IconButton(
                  icon: const Icon(CupertinoIcons.camera_fill,
                      color: Colors.purple),
                  onPressed: () => launchUrl(Uri.parse(
                      "https://instagram.com/${social!['instagram']}"))),
          ])
        else
          Text(content ?? "",
              style: const TextStyle(color: Colors.black87, height: 1.4)),
        const SizedBox(height: 20),
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Text("Henüz geri bildirim yapılmamış.",
              style: TextStyle(color: Colors.grey));
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
            return Column(children: [
              _buildCommentTile(doc, c),
              ...replies.map((replyDoc) => Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: _buildCommentTile(
                        replyDoc, replyDoc.data() as Map<String, dynamic>,
                        isReply: true),
                  )),
            ]);
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
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              onTap: () => doc.reference.delete(),
              child: const Text("Sil",
                  style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ],
        ])
      ]),
    );
  }

  Widget _buildCommentBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
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
                  (i) => GestureDetector(
                      onTap: () => setState(() => _userRating = i + 1.0),
                      child: Icon(
                          i < _userRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30)))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: CupertinoTextField(
                      controller: _commentController,
                      placeholder: "Görüşünüzü yazın...",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12)))),
              const SizedBox(width: 10),
              CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _sendComment,
                  child: Icon(CupertinoIcons.arrow_up_circle_fill,
                      color: publicRed, size: 40)),
            ],
          ),
        ],
      ),
    );
  }
}
