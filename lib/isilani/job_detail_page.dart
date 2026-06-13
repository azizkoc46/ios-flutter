import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:share_plus/share_plus.dart'; // Paylaşım için gerekli

class JobDetailPage extends StatelessWidget {
  final Map<String, dynamic> job;
  final String docId;

  const JobDetailPage({Key? key, required this.job, required this.docId})
      : super(key: key);

  // 🔥 YENİ: İŞ İLANI PAYLAŞMA FONKSİYONU
  void _shareJob() {
    String title = job['title'] ?? "İş İlanı";
    String company = job['companyName'] ?? "Firma Belirtilmemiş";

    // Mavi link yapısı: /is path'ini kullanıyoruz
    String shareUrl = "https://pazarcik-portal-7faf2.web.app/is?id=$docId";

    String shareText = "📢 Pazarcık Portal'da Yeni İş Fırsatı!\n\n"
        "💼 Pozisyon: $title\n"
        "🏢 Firma: $company\n\n"
        "🔗 İlanın Detayları İçin Tıkla:\n$shareUrl";

    Share.share(shareText);
  }

  Future<void> _makeCall(String phoneNumber) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> images = job['images'] ?? [];
    String ownerId = job['ownerId'] ?? "";
    final Color jobPrimaryColor = const Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0.5,
        centerTitle: true,
        title: Text("İlan Detayı",
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context)),
        // 🔥 PAYLAŞ BUTONU EKLENDİ
        actions: [
          IconButton(
            icon: Icon(Icons.share,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: _shareJob,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 15),
                          width: 280,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: PortalNetworkImage(
                                url: images[index], fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ),
                if (images.isNotEmpty) const SizedBox(height: 25),
                Text(job['title'] ?? "",
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2)),
                const SizedBox(height: 8),
                Text(job['companyName'] ?? "",
                    style: TextStyle(
                        fontSize: 18,
                        color: jobPrimaryColor,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 25),
                Row(
                  children: [
                    _buildInfoChip(
                        Icons.access_time_filled, job['employmentType'] ?? "-"),
                    const SizedBox(width: 10),
                    _buildInfoChip(Icons.people_alt,
                        "${job['personnelCount'] ?? '1'} Kişi"),
                  ],
                ),
                if (job['salary'] != null &&
                    job['salary'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoChip(Icons.payments, "${job['salary']} TL",
                      color: Colors.green),
                ],
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider()),
                Text("Aranan Nitelikler & İş Tanımı",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 15),
                Text(job['description'] ?? "Açıklama girilmemiş.",
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 120),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5))
                  ]),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(ownerId)
                    .get(),
                builder: (context, snapshot) {
                  String phone = "";
                  bool hasPhone = false;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    var userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    phone = userData['phoneNumber'] ?? userData['phone'] ?? "";
                    if (phone.isNotEmpty) hasPhone = true;
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(
                                color: Colors.green, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed:
                              hasPhone ? () => _openWhatsApp(phone) : null,
                          icon: const Icon(Icons.wechat, color: Colors.green),
                          label: const Text("WhatsApp",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: jobPrimaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: hasPhone ? () => _makeCall(phone) : null,
                          icon: const Icon(CupertinoIcons.phone_fill,
                              color: Colors.white, size: 18),
                          label: const Text("Hemen Ara",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text,
      {Color color = Colors.black54}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
