import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'job_detail_page.dart'; // Bir sonraki adımda yapacağımız sayfa
import 'package:intl/intl.dart';

class JobListingPage extends StatelessWidget {
  const JobListingPage({Key? key}) : super(key: key);

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    return DateFormat('dd.MM.yyyy', 'tr_TR').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final Color jobPrimaryColor = const Color(0xFF0284C7); // Kariyer Mavisi

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Pazarcık Kariyer",
          style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_postings')
            .where('status', isEqualTo: 'active')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 20));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 15),
                  Text("Şu an yayında olan iş ilanı yok.",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16)),
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
              var job = jobs[index].data() as Map<String, dynamic>;
              String docId = jobs[index].id;
              List<dynamic> images = job['images'] ?? [];
              String logoUrl = images.isNotEmpty ? images.first : "";

              return GestureDetector(
                onTap: () {
                  // Tıklanma sayısını artır
                  FirebaseFirestore.instance
                      .collection('job_postings')
                      .doc(docId)
                      .update({'views': FieldValue.increment(1)});
                  Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (context) =>
                              JobDetailPage(job: job, docId: docId)));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo veya İkon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: jobPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: PortalNetworkImage(
                                    url: logoUrl, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.business,
                                color: Color(0xFF0284C7), size: 30),
                      ),
                      const SizedBox(width: 15),
                      // İlan Detayları
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job['title'] ?? "Başlıksız İlan",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  height: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              job['companyName'] ?? "Firma Belirtilmemiş",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    job['employmentType'] ?? "Belirtilmedi",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                    _formatDate(job['createdAt'] as Timestamp?),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            )
                          ],
                        ),
                      )
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
