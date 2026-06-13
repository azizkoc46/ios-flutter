import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CommentManagementPage extends StatelessWidget {
  const CommentManagementPage({Key? key}) : super(key: key);

  // 🔥 Yorumu Silme Fonksiyonu
  Future<void> _deleteComment(
      BuildContext context, String businessId, String commentId) async {
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('comments')
        .doc(commentId)
        .delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Yorum silindi ❌"), behavior: SnackBarBehavior.floating));
  }

  // 🔥 Kullanıcıyı Silme Fonksiyonu
  Future<void> _deleteUser(BuildContext context, String userId) async {
    if (userId.isEmpty) return;

    bool confirm = await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("Üyeliği Sil"),
            content: const Text(
                "Bu kullanıcının profilini tamamen silmek istediğinize emin misiniz?"),
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
          .collection('customers')
          .doc(userId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Kullanıcı kaydı silindi ❌"),
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Yorum & Kullanıcı Yönetimi",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 Hata Veren 'orderBy' Kısmı Kaldırıldı. Artık direkt veriyi çekecek.
        stream:
            FirebaseFirestore.instance.collectionGroup('comments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          var comments = snapshot.data!.docs;
          if (comments.isEmpty) {
            return const Center(child: Text("Henüz yorum yapılmamış."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: comments.length,
            itemBuilder: (context, index) {
              var c = comments[index].data() as Map<String, dynamic>;
              String commentId = comments[index].id;
              String userId = c['userId'] ?? "";

              String displayId =
                  userId.length >= 8 ? userId.substring(0, 8) : userId;

              // Parent path üzerinden businessId çekme
              String businessId = comments[index].reference.parent.parent!.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: List.generate(
                                5,
                                (i) => Icon(Icons.star_rounded,
                                    size: 18,
                                    color: i < (c['rating'] ?? 0)
                                        ? Colors.amber
                                        : Colors.grey[300])),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_rounded,
                                color: Colors.red),
                            onPressed: () =>
                                _deleteComment(context, businessId, commentId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(c['comment'] ?? "Yorum metni yok",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("KULLANICI",
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              Text(
                                  displayId.isEmpty
                                      ? "Anonim"
                                      : "$displayId...",
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (userId.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () => _deleteUser(context, userId),
                              icon: const Icon(
                                  Icons.person_remove_alt_1_rounded,
                                  size: 14),
                              label: const Text("Üyeliği Sil"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[50],
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                  textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
