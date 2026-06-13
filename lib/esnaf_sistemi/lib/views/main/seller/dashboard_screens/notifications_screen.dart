import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Bildirimler",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: () {
              // Tümünü okundu işaretle
              FirebaseFirestore.instance
                  .collection('notifications')
                  .where('to', isEqualTo: userId)
                  .get()
                  .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.update({'isRead': true});
                }
              });
            },
            child: const Text("Tümünü Oku",
                style: TextStyle(color: Color(0xfff27a1a))),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('to', isEqualTo: userId)
            .orderBy('time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.bell_slash,
                      size: 60, color: Colors.black26),
                  const SizedBox(height: 10),
                  Text("Yeni bildiriminiz yok",
                      style: GoogleFonts.inter(
                          color: Colors.black45, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              bool isRead = doc['isRead'] ?? true;

              return GestureDetector(
                onTap: () {
                  if (!isRead) {
                    FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(doc.id)
                        .update({'isRead': true});
                  }
                },
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? Colors.grey.shade200
                          // ignore: deprecated_member_use
                          : const Color(0xfff27a1a).withOpacity(0.1),
                      child: Icon(CupertinoIcons.bag_fill,
                          color: isRead ? Colors.grey : const Color(0xfff27a1a),
                          size: 18),
                    ),
                    title: Text(doc['title'] ?? "",
                        style: GoogleFonts.inter(
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 14)),
                    subtitle: Text(doc['message'] ?? "",
                        style: GoogleFonts.inter(
                            color: Colors.black54, fontSize: 12)),
                    trailing: !isRead
                        ? const CircleAvatar(
                            radius: 5, backgroundColor: Colors.red)
                        : null,
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
