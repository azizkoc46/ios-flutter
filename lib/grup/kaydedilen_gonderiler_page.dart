import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'grup_gonderi_karti.dart';
import 'package:pazarcik_portal/auth/auth.dart';

class KaydedilenGonderilerPage extends StatelessWidget {
  const KaydedilenGonderilerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Kaydedilen Gönderiler",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: currentUser == null || currentUser.isAnonymous
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5E62).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.bookmark_fill,
                        size: 48,
                        color: Color(0xFFFF5E62),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Kayıtlı Gönderilerinize Ulaşın",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Meydan'da beğendiğiniz gönderileri kaydedip daha sonra incelemek için giriş yapmanız gerekmektedir.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const Auth()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5E62),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.person_crop_circle_badge_plus, size: 18),
                      label: const Text(
                        "Giriş Yap / Kayıt Ol",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(currentUser.uid)
                  .collection('saved_posts')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator(radius: 14));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Hata oluştu: ${snapshot.error}",
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final savedDocs = snapshot.data?.docs ?? [];

                if (savedDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.bookmark,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Henüz kaydedilen gönderi yok",
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Meydan'daki gönderilerin altındaki 'Kaydet' butonuna dokunarak istediklerinizi buraya ekleyebilirsiniz.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 40),
                  itemCount: savedDocs.length,
                  itemBuilder: (context, index) {
                    final savedData = savedDocs[index].data() as Map<String, dynamic>;
                    final postId = savedData['postId']?.toString() ?? savedDocs[index].id;

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('group_posts')
                          .doc(postId)
                          .snapshots(),
                      builder: (context, postSnap) {
                        if (postSnap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 80,
                            child: Center(child: CupertinoActivityIndicator(radius: 10)),
                          );
                        }

                        if (!postSnap.hasData || !postSnap.data!.exists) {
                          // Gönderi silinmişse kullanıcıyı bilgilendirip temizleme seçeneği
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.trash, color: Colors.grey, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Bu gönderi yazarı veya yönetici tarafından silinmiş.",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('customers')
                                        .doc(currentUser.uid)
                                        .collection('saved_posts')
                                        .doc(savedDocs[index].id)
                                        .delete();
                                  },
                                  child: const Text("Kaldır", style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                        }

                        final postData = postSnap.data!.data() as Map<String, dynamic>;
                        return GrupGonderiKarti(
                          postId: postId,
                          data: postData,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
