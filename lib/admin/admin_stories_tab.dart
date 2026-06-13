import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// 🔥 BURAYI KENDİ PROJE ADINA GÖRE DÜZENLE (Örn: pazarcik_portal)
import 'package:pazarcik_portal/admin/admin_story_manage_page.dart';

class AdminStoriesTab extends StatelessWidget {
  final Color storyColor = Colors.purple;
  final Color dangerColor = const Color(0xFFEF4444);

  const AdminStoriesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('story_categories')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Henüz hikaye kategorisi yok."));
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;
            String title = data['title'] ?? "İsimsiz";
            String coverImage = data['coverImage'] ?? "";
            List items = data['items'] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: storyColor.withOpacity(0.1),
                        backgroundImage: coverImage.isNotEmpty
                            ? NetworkImage(coverImage)
                            : null,
                        child: coverImage.isEmpty
                            ? Icon(Icons.photo_library, color: storyColor)
                            : null,
                      ),
                      title: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${items.length} İçerik"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _confirmDelete(context, docId),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: dangerColor,
                                side: BorderSide(
                                    color: dangerColor.withOpacity(0.5))),
                            child: const Text("Sil"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // 🔥 DOĞRU SAYFAYA YÖNLENDİRME YAPILDI
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => AdminStoryManagePage(
                                    categoryId: docId,
                                    categoryTitle: title,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: storyColor, elevation: 0),
                            child: const Text("İçeriği Yönet",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Silinsin mi?"),
        content: const Text("Bu hikaye kategorisi tamamen silinecektir."),
        actions: [
          CupertinoDialogAction(
              child: const Text("Vazgeç"),
              onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('story_categories')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
