// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'business_add_page.dart'; // Düzenleme sayfasına gitmek için gerekli

class MyBusinessesPage extends StatefulWidget {
  const MyBusinessesPage({Key? key}) : super(key: key);

  @override
  State<MyBusinessesPage> createState() => _MyBusinessesPageState();
}

class _MyBusinessesPageState extends State<MyBusinessesPage> {
  final Color primaryColor = const Color(0xFF004D40);

  // İşletme Silme Fonksiyonu
  Future<void> _deleteBusiness(String docId) async {
    bool confirm = await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("İşletmeyi Sil"),
        content: const Text(
            "Bu işletmeyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
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

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İşletme başarıyla silindi.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text("İşletmelerim",
            style: GoogleFonts.inter(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('businesses')
            .where('editorId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String status = data['status'] ?? 'pending';

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
                  // Sadece görseli render eder, tıklama özelliği yok
                  leading: _buildLeadingImage(data['imageUrls']),
                  title: Text(data['businessName'] ?? "İsimsiz",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: _buildStatusBadge(status),
                  trailing: PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    icon: const Icon(CupertinoIcons.ellipsis_vertical,
                        color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessAddPage(
                              existingBusiness: data,
                              docId: doc.id,
                              // 🔥 GÜNCELLENDİ: Kamu kurumu mu yoksa normal işletme mi kontrolü
                              isPublic: data['type'] == 'public',
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        _deleteBusiness(doc.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(CupertinoIcons.pencil, size: 20),
                          title: Text("Düzenle"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(CupertinoIcons.trash,
                              color: Colors.red, size: 20),
                          title:
                              Text("Sil", style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
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

  Widget _buildLeadingImage(dynamic imageUrls) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: primaryColor.withOpacity(0.05),
        image: imageUrls != null && (imageUrls as List).isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrls[0]), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrls == null || (imageUrls as List).isEmpty
          ? Icon(CupertinoIcons.building_2_fill,
              color: primaryColor.withOpacity(0.5))
          : null,
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isApproved = status == 'approved';
    return UnconstrainedBox(
      // Badge'in tüm satırı kaplamaması için
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isApproved
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isApproved ? "YAYINDA" : "ONAY BEKLİYOR",
          style: TextStyle(
              color: isApproved ? Colors.green : Colors.orange,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.doc_text_search,
              size: 60, color: primaryColor.withOpacity(0.1)),
          const SizedBox(height: 15),
          Text("Henüz bir işletme eklememişsiniz.",
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
