import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/widgets/community_comment_sheet.dart';
import 'add_post_screen.dart';
import 'edit_community_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final DocumentSnapshot community;
  const CommunityDetailScreen({Key? key, required this.community})
      : super(key: key);

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;

  final Color iosBlue = const Color(0xFF007AFF);
  final Color iosLightBg = const Color(0xFFF2F2F7);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reportContent(
      String targetId, String content, String type, String adminEmail) async {
    await FirebaseFirestore.instance.collection('sikayetler').add({
      'targetId': targetId,
      'communityId': widget.community.id,
      'targetAdminEmail': adminEmail,
      'reportedBy': currentUserEmail ?? 'Anonim',
      'content': content,
      'type': type,
      'status': 'pending',
      'date': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: const Text("Şikayet iletildi."),
          backgroundColor: iosBlue,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url.startsWith("http") ? url : "https://$url");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // 🔥 SENİN İSTEDİĞİN O İLETİŞİM METODU BURADA OLMALIYDI
  Widget _contactItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.community.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        var data = snapshot.data!.data() as Map<String, dynamic>;
        bool isAdmin = (data['adminEmail'] == currentUserEmail &&
            currentUserEmail != null);
        String coverImg = data['coverImage'] ?? '';
        String logoImg = data['logo'] ?? '';
        String dernekName = data['dernekName'] ?? "İsimsiz Kuruluş";
        String adminEmail = data['adminEmail'] ?? "";

        return Scaffold(
          backgroundColor: iosLightBg,
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  heroTag: "fab_final",
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) =>
                              AddPostScreen(communityId: widget.community.id))),
                  backgroundColor: iosBlue,
                  icon: const Icon(Icons.add_a_photo, color: Colors.white),
                  label: const Text("Haber Paylaş",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : null,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: iosBlue,
                flexibleSpace: FlexibleSpaceBar(
                  background: coverImg.isNotEmpty
                      ? Image.network(coverImg,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              Container(color: Colors.grey))
                      : Container(color: iosBlue.withValues(alpha: 0.8)),
                ),
                actions: [
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.settings_suggest,
                          size: 28, color: Colors.white),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (c) => EditCommunityScreen(
                                  community: snapshot.data!))),
                    )
                ],
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // 👤 PROFİL RESMİ VE BEYAZ ÇERÇEVE
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          const SizedBox(height: 70, width: double.infinity),
                          Positioned(
                            top: 5,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 15,
                                      offset: Offset(0, 8))
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: iosLightBg,
                                backgroundImage: logoImg.isNotEmpty
                                    ? NetworkImage(logoImg)
                                    : null,
                                child: logoImg.isEmpty
                                    ? Icon(Icons.business,
                                        size: 50, color: iosBlue)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 📝 DERNEK ADI
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 70, bottom: 10, left: 15, right: 15),
                        child: Text(dernekName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900)),
                      ),
                      // 📞 GERÇEK VERİLERİ ÇEKEN İLETİŞİM SATIRI
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 15,
                          runSpacing: 10,
                          children: [
                            // 🔥 Telefon: Firestore'daki 'applicantPhone' alanını çeker
                            if (data['applicantPhone'] != null &&
                                data['applicantPhone'] != "")
                              _contactItem(Icons.phone, data['applicantPhone'],
                                  Colors.green),

                            // 🔥 Instagram: Firestore'daki 'instagram' alanını çeker
                            if (data['instagram'] != null &&
                                data['instagram'] != "")
                              _contactItem(Icons.camera_alt, data['instagram'],
                                  Colors.purple),

                            // 🔥 Web Sitesi: Firestore'daki 'website' alanını çeker
                            if (data['website'] != null &&
                                data['website'] != "")
                              _contactItem(
                                  Icons.language, data['website'], Colors.blue),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  Container(
                    color: Colors.white,
                    child: TabBar(
                        controller: _tabController,
                        labelColor: iosBlue,
                        indicatorColor: iosBlue,
                        tabs: const [
                          Tab(text: "Akış"),
                          Tab(text: "Kurumsal"),
                          Tab(text: "Sayfalar")
                        ]),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(logoImg, dernekName, isAdmin, adminEmail),
                _buildKurumsalTab(data),
                _buildPagesTab(isAdmin)
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(
      String logo, String name, bool isAdmin, String adminEmail) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.community.id)
          .collection('posts')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var posts = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 100),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _PostCard(
              post: posts[index].data() as Map<String, dynamic>,
              postId: posts[index].id,
              communityId: widget.community.id,
              logo: logo,
              name: name,
              isAdmin: isAdmin,
              adminEmail: adminEmail,
              currentUserEmail: currentUserEmail,
              onReport: (c) =>
                  _reportContent(posts[index].id, c, 'post', adminEmail),
            );
          },
        );
      },
    );
  }

  Widget _buildKurumsalTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hakkımızda",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(data['bio'] ?? "Bilgi yok.",
                style: const TextStyle(fontSize: 15, height: 1.5)),
            const Divider(height: 30),
            ListTile(
                leading: const Icon(Icons.phone, color: Colors.blue),
                title: Text(data['applicantPhone'] ?? "Yok"),
                contentPadding: EdgeInsets.zero),
          ],
        ),
      ),
    );
  }

  Widget _buildPagesTab(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.community.id)
          .collection('custom_pages')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var pages = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: pages.length,
          itemBuilder: (context, index) {
            var page = pages[index].data() as Map<String, dynamic>;
            return Card(
                child: ExpansionTile(
                    title: Text(page['title'] ?? "Sayfa"),
                    children: (page['content'] as List)
                        .map(
                            (item) => ListTile(title: Text(item['text'] ?? "")))
                        .toList()));
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final String communityId;
  final String logo;
  final String name;
  final bool isAdmin;
  final String adminEmail;
  final String? currentUserEmail;
  final Function(String) onReport;

  const _PostCard(
      {required this.post,
      required this.postId,
      required this.communityId,
      required this.logo,
      required this.name,
      required this.isAdmin,
      required this.adminEmail,
      this.currentUserEmail,
      required this.onReport});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.post['mediaType'] == 'video' && widget.post['postImage'] != "") {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.post['postImage']))
            ..initialize().then((_) {
              if (mounted)
                setState(() {
                  _isVideoInitialized = true;
                });
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List likes = widget.post['likes'] ?? [];
    bool isLiked = widget.currentUserEmail != null &&
        likes.contains(widget.currentUserEmail);
    String mediaUrl = widget.post['postImage'] ?? "";
    String type = widget.post['mediaType'] ?? "image";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
                backgroundImage:
                    widget.logo != "" ? NetworkImage(widget.logo) : null),
            title: Text(widget.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _showPostMenu(context)),
          ),
          if (mediaUrl.isNotEmpty)
            type == "video"
                ? (_isVideoInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Stack(alignment: Alignment.center, children: [
                          VideoPlayer(_videoController!),
                          IconButton(
                              icon: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  color: Colors.white,
                                  size: 60),
                              onPressed: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              })
                        ]))
                    : const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator())))
                : Image.network(mediaUrl,
                    fit: BoxFit.cover, width: double.infinity),
          Padding(
              padding: const EdgeInsets.all(15),
              child: Text(widget.post['content'] ?? "")),
          Row(
            children: [
              IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey),
                  onPressed: _toggleLike),
              Text("${likes.length}"),
              const SizedBox(width: 15),
              IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: _openComments),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => Share.share(widget.post['content'] ?? "")),
            ],
          )
        ],
      ),
    );
  }

  void _toggleLike() {
    var ref = FirebaseFirestore.instance
        .collection('dernekler')
        .doc(widget.communityId)
        .collection('posts')
        .doc(widget.postId);
    if ((widget.post['likes'] as List).contains(widget.currentUserEmail))
      ref.update({
        'likes': FieldValue.arrayRemove([widget.currentUserEmail])
      });
    else
      ref.update({
        'likes': FieldValue.arrayUnion([widget.currentUserEmail])
      });
  }

  void _openComments() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CommunityCommentSheet(
            postId: widget.postId,
            communityId: widget.communityId,
            currentUserEmail: widget.currentUserEmail,
            adminEmail: widget.adminEmail));
  }

  void _showPostMenu(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (c) => Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text("Haber Şikayet Et"),
                  onTap: () {
                    Navigator.pop(c);
                    widget.onReport(widget.post['content'] ?? "");
                  }),
              if (widget.isAdmin)
                ListTile(
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text("Sil"),
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('dernekler')
                          .doc(widget.communityId)
                          .collection('posts')
                          .doc(widget.postId)
                          .delete();
                      Navigator.pop(c);
                    }),
            ]));
  }
}

class _CommentSheet extends StatefulWidget {
  final String postId;
  final String communityId;
  final String? currentUserEmail;
  final String adminEmail;
  const _CommentSheet(
      {required this.postId,
      required this.communityId,
      this.currentUserEmail,
      required this.adminEmail});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? replyToId;
  String? replyToName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          const SizedBox(height: 15),
          const Text("Yorumlar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dernekler')
                  .doc(widget.communityId)
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('date', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var all = snapshot.data!.docs;
                var mainComments =
                    all.where((d) => d['parentId'] == null).toList();
                return ListView.builder(
                    itemCount: mainComments.length,
                    itemBuilder: (context, i) =>
                        _buildCommentThread(mainComments[i], all));
              },
            ),
          ),
          if (replyToName != null)
            Container(
                color: Colors.blue[50],
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Text("$replyToName kişisine yanıt..."),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                            replyToId = null;
                            replyToName = null;
                          }))
                ])),
          Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 15,
                right: 15,
                top: 10),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                          hintText: "Yorum yaz...", border: InputBorder.none))),
              IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendComment)
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCommentThread(
      DocumentSnapshot parent, List<DocumentSnapshot> all) {
    var replies = all.where((d) => d['parentId'] == parent.id).toList();
    return Column(children: [
      _commentTile(parent, isReply: false),
      ...replies.map((r) => Padding(
          padding: const EdgeInsets.only(left: 45),
          child: _commentTile(r, isReply: true)))
    ]);
  }

  Widget _commentTile(DocumentSnapshot doc, {required bool isReply}) {
    var c = doc.data() as Map<String, dynamic>;
    return ListTile(
      dense: isReply,
      leading: CircleAvatar(
          radius: isReply ? 14 : 18,
          child: Text(c['sender']?[0].toUpperCase() ?? "A")),
      title: Text(c['sender']?.split('@')[0] ?? "Kullanıcı",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c['content'] ?? ""),
        const SizedBox(height: 4),
        GestureDetector(
            onTap: () => setState(() {
                  replyToId = doc.id;
                  replyToName = c['sender']?.split('@')[0];
                }),
            child: const Text("Yanıtla",
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 11))),
      ]),
      trailing: IconButton(
          icon: const Icon(Icons.more_vert, size: 16),
          onPressed: () =>
              _showCommentMenu(doc, c['sender'] == widget.currentUserEmail)),
    );
  }

  void _showCommentMenu(DocumentSnapshot doc, bool isMine) {
    showModalBottomSheet(
        context: context,
        builder: (c) => Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text("Şikayet Et"),
                  onTap: () {
                    FirebaseFirestore.instance.collection('sikayetler').add({
                      'targetId': doc.id,
                      'type': 'comment',
                      'targetAdminEmail': widget.adminEmail,
                      'content': doc['content'],
                      'reportedBy': widget.currentUserEmail,
                      'date': FieldValue.serverTimestamp()
                    });
                    Navigator.pop(c);
                  }),
              if (isMine)
                ListTile(
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text("Yorumu Sil"),
                    onTap: () {
                      doc.reference.delete();
                      Navigator.pop(c);
                    }),
            ]));
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('dernekler')
        .doc(widget.communityId)
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'content': _commentController.text.trim(),
      'sender': widget.currentUserEmail ?? "Anonim",
      'date': FieldValue.serverTimestamp(),
      'parentId': replyToId
    });
    _commentController.clear();
    setState(() {
      replyToId = null;
      replyToName = null;
    });
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child);
  final Widget _child;
  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;
  @override
  Widget build(context, shrinkOffset, overlapsContent) => _child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
