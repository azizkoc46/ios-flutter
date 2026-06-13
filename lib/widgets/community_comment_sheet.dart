import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';

class CommunityCommentSheet extends StatefulWidget {
  final String postId;
  final String communityId;
  final String? currentUserEmail;
  final String adminEmail;

  const CommunityCommentSheet({
    super.key,
    required this.postId,
    required this.communityId,
    this.currentUserEmail,
    required this.adminEmail,
  });

  @override
  State<CommunityCommentSheet> createState() => _CommunityCommentSheetState();
}

class _CommunityCommentSheetState extends State<CommunityCommentSheet> {
  final _commentController = TextEditingController();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? replyToId;
  String? replyToName;

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.communityId)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments');

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 15),
          const Text("Yorumlar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _commentsRef.orderBy('date', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!.docs;
                final mainComments = all.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['parentId'] == null;
                }).toList();

                if (mainComments.isEmpty) {
                  return const Center(child: Text("İlk yorumu sen yap!"));
                }

                return ListView.builder(
                  itemCount: mainComments.length,
                  itemBuilder: (context, index) =>
                      _buildThread(mainComments[index], all),
                );
              },
            ),
          ),
          if (replyToName != null)
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(child: Text("$replyToName kişisine yanıt...")),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    replyToId = null;
                    replyToName = null;
                  }),
                )
              ]),
            ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 15,
              right: 15,
              top: 10,
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: "Yorum yaz...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: _sendComment,
              )
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildThread(DocumentSnapshot parent, List<DocumentSnapshot> all) {
    final replies = all.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['parentId'] == parent.id;
    }).toList();

    return Column(children: [
      _commentTile(parent, isReply: false),
      ...replies.map(
        (reply) => Padding(
          padding: const EdgeInsets.only(left: 45),
          child: _commentTile(reply, isReply: true),
        ),
      )
    ]);
  }

  Widget _commentTile(DocumentSnapshot doc, {required bool isReply}) {
    final data = doc.data() as Map<String, dynamic>;
    final visibleName = CommentIdentity.visibleName(
      data,
      nameFields: const ['senderName', 'authorFullName', 'sender'],
    );
    final isMine = data['senderId'] == currentUserId ||
        data['sender'] == widget.currentUserEmail;

    return ListTile(
      dense: isReply,
      leading: CircleAvatar(
        radius: isReply ? 14 : 18,
        child:
            Text(visibleName.isNotEmpty ? visibleName[0].toUpperCase() : "K"),
      ),
      title: Text(visibleName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['content'] ?? ""),
        const SizedBox(height: 4),
        Row(children: [
          GestureDetector(
            onTap: () => setState(() {
              replyToId = doc.id;
              replyToName = visibleName;
            }),
            child: const Text("Yanıtla",
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          if (isMine) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => _editComment(doc),
              child: const Text("Düzenle",
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => doc.reference.delete(),
              child: const Text("Sil",
                  style: TextStyle(color: Colors.red, fontSize: 11)),
            ),
          ],
        ]),
      ]),
      trailing: IconButton(
        icon: const Icon(Icons.flag_outlined, color: Colors.red, size: 16),
        onPressed: () => _reportComment(doc),
      ),
    );
  }

  Future<void> _editComment(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final controller = TextEditingController(text: data['content'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yorumu Düzenle"),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Kaydet")),
        ],
      ),
    );
    if (saved != true || controller.text.trim().isEmpty) return;
    await doc.reference.update({
      'content': controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reportComment(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    await FirebaseFirestore.instance.collection('sikayetler').add({
      'targetId': doc.id,
      'type': 'comment',
      'targetAdminEmail': widget.adminEmail,
      'content': data['content'],
      'reportedBy': widget.currentUserEmail,
      'date': FieldValue.serverTimestamp()
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Şikayet iletildi.")),
    );
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;
    final fullName = await CommentIdentity.currentUserFullName();

    await _commentsRef.add({
      'content': text,
      'sender': widget.currentUserEmail ?? "Anonim",
      'senderId': currentUserId,
      'senderName': fullName,
      ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
      'date': FieldValue.serverTimestamp(),
      'parentId': replyToId,
      'replyToName': replyToName,
    });

    _commentController.clear();
    setState(() {
      replyToId = null;
      replyToName = null;
    });
  }
}
