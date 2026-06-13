import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 Kendi projendeki add_job_page yolunu buraya ekle
import 'add_job_page.dart';

class MyJobsPage extends StatefulWidget {
  const MyJobsPage({Key? key}) : super(key: key);

  @override
  State<MyJobsPage> createState() => _MyJobsPageState();
}

class _MyJobsPageState extends State<MyJobsPage> {
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // İlan Silme Fonksiyonu
  Future<void> _deleteJob(String docId) async {
    bool confirm = await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("İlanı Sil"),
            content: const Text(
                "Bu iş ilanını kalıcı olarak silmek istediğinize emin misiniz?"),
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
          .collection('job_postings')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("İş ilanı başarıyla silindi."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text("İş İlanlarım",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _currentUid.isEmpty
          ? const Center(child: Text("Oturum açılmamış."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('job_postings')
                  .where('ownerId', isEqualTo: _currentUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CupertinoActivityIndicator(radius: 20));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 15),
                        Text("Henüz bir iş ilanı vermediniz.",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                var jobs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  physics: const BouncingScrollPhysics(),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    var jobData = jobs[index].data() as Map<String, dynamic>;
                    String docId = jobs[index].id;
                    String title = jobData['title'] ?? "Başlıksız İlan";
                    String company =
                        jobData['companyName'] ?? "Firma Belirtilmemiş";
                    String type = jobData['employmentType'] ?? "-";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.business_center,
                                    color: Color(0xFF0284C7)),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 5),
                                    Text(company,
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      child: Text(type,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _deleteJob(docId),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: BorderSide(
                                          color: Colors.red.shade200)),
                                  icon: const Icon(CupertinoIcons.trash,
                                      size: 18),
                                  label: const Text("Sil"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // 🔥 Düzenleme sayfasına (AddJobPage) mevcut verilerle gidiyoruz
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                          builder: (context) => AddJobPage(
                                              existingJob: jobData,
                                              docId: docId)),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7)),
                                  icon: const Icon(CupertinoIcons.pencil,
                                      size: 18),
                                  label: const Text("Düzenle"),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
