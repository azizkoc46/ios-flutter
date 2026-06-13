import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';

class GrupYorumlariEkran extends StatefulWidget {
  final String postId;

  const GrupYorumlariEkran({Key? key, required this.postId}) : super(key: key);

  @override
  State<GrupYorumlariEkran> createState() => _GrupYorumlariEkranState();
}

class _GrupYorumlariEkranState extends State<GrupYorumlariEkran> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String userName = "Kullanıcı";
  String userAvatar = "";
  String? replyingToId;
  String? replyingToName;
  bool isPosting = false;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      FirebaseFirestore.instance
          .collection('group_posts')
          .doc(widget.postId)
          .collection('comments');

  Future<void> _getUserData() async {
    if (currentUserId.isEmpty) return;
    var doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(currentUserId)
        .get();
    if (doc.exists && mounted) {
      final data = doc.data() ?? {};
      setState(() {
        userName = (data['fullname'] ?? "Kullanıcı").toString();
        userAvatar = (data['profileImage'] ?? data['image'] ?? "").toString();
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || isPosting) return;
    if (currentUserId.isEmpty) return;

    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;

    setState(() => isPosting = true);

    try {
      final fullName = userName.trim().isNotEmpty
          ? userName
          : await CommentIdentity.currentUserFullName();

      final docRef = await _commentsRef.add({
        'authorId': currentUserId,
        'authorName': fullName,
        ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
        'authorAvatar': userAvatar,
        'text': text,
        'parentId': replyingToId,
        'replyToName': replyingToName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final safeBody = text.length > 60 ? "${text.substring(0, 60)}..." : text;
      await AdminNotificationService.instance.notifyAdmin(
        title: 'Yeni Yorum',
        body: safeBody,
        type: AdminNotifType.comment,
        docId: docRef.id,
      );

      await FirebaseFirestore.instance
          .collection('group_posts')
          .doc(widget.postId)
          .update({'commentCount': FieldValue.increment(1)});

      _commentController.clear();
      _focusNode.unfocus();
      setState(() {
        replyingToId = null;
        replyingToName = null;
      });
    } catch (e) {
      debugPrint("Yorum hatası: $e");
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Yorumu Sil"),
        content: const Text("Bu yorumu silmek istediğinize emin misiniz?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _commentsRef.doc(commentId).delete();
    await FirebaseFirestore.instance
        .collection('group_posts')
        .doc(widget.postId)
        .update({'commentCount': FieldValue.increment(-1)});
  }

  Future<void> _editComment(String commentId, String currentText) async {
    final controller = TextEditingController(text: currentText);
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

    await _commentsRef.doc(commentId).update({
      'text': controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _setReply(String commentId, String name) {
    setState(() {
      replyingToId = commentId;
      replyingToName = name;
    });
    _focusNode.requestFocus();
  }

  String _formatTime(Timestamp? time) {
    if (time == null) return "Şimdi";
    final diff = DateTime.now().difference(time.toDate());
    if (diff.inMinutes < 1) return "Şimdi";
    if (diff.inHours < 1) return "${diff.inMinutes}d";
    if (diff.inDays < 1) return "${diff.inHours}s";
    return "${diff.inDays}g";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Yorumlar",
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _commentsRef
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "İlk yorumu sen yap!",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;
                final mainDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['parentId'] == null;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: mainDocs.length,
                  itemBuilder: (context, index) {
                    final doc = mainDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final replies = allDocs.where((replyDoc) {
                      final reply = replyDoc.data() as Map<String, dynamic>;
                      return reply['parentId'] == doc.id;
                    }).toList();

                    return Column(
                      children: [
                        _buildCommentRow(doc.id, data),
                        ...replies.map((replyDoc) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: _buildCommentRow(
                              replyDoc.id,
                              replyDoc.data() as Map<String, dynamic>,
                              isReply: true,
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildCommentComposer(),
        ],
      ),
    );
  }

  Widget _buildCommentRow(String commentId, Map<String, dynamic> data,
      {bool isReply = false}) {
    final visibleName = CommentIdentity.visibleName(data);
    final isMyComment = data['authorId'] == currentUserId;

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 10 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 15 : 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (data['authorAvatar'] ?? '').toString().isNotEmpty
                ? NetworkImage(data['authorAvatar'])
                : null,
            child: (data['authorAvatar'] ?? '').toString().isEmpty
                ? const Icon(Icons.person, color: Colors.grey, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visibleName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(data['text'] ?? "",
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4),
                  child: Row(
                    children: [
                      Text(
                        _formatTime(data['createdAt'] as Timestamp?),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => _setReply(commentId, visibleName),
                        child: Text(
                          "Yanıtla",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isMyComment) ...[
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () =>
                              _editComment(commentId, data['text'] ?? ""),
                          child: Text(
                            "Düzenle",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () => _deleteComment(commentId),
                          child: Text(
                            "Sil",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -2),
              blurRadius: 10,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingToName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Yanıtlanıyor: $replyingToName",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        replyingToId = null;
                        replyingToName = null;
                      }),
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                    )
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: "Bir yorum yaz...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CupertinoActivityIndicator(),
                        )
                      : IconButton(
                          icon:
                              const Icon(Icons.send, color: Color(0xFF0056D2)),
                          onPressed: _postComment,
                        )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
