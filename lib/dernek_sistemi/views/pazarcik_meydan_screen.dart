import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'community_detail_screen.dart';
import 'apply_community_screen.dart';

class PazarcikMeydanScreen extends StatelessWidget {
  const PazarcikMeydanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Pazarcık Meydan",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔥 ÜST PANEL: BAŞVURU VEYA YÖNETİM DURUMU
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('dernekler')
                .where('adminEmail', isEqualTo: userEmail)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const SizedBox();

              var myCommunities = snapshot.data?.docs ?? [];

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: myCommunities.isEmpty
                    ? _buildApplyButton(context)
                    : Column(
                        children: myCommunities.map((doc) {
                          var d = doc.data() as Map<String, dynamic>;
                          bool isApproved = d['status'] == 'approved';

                          return _buildStatusCard(context, d, doc, isApproved);
                        }).toList(),
                      ),
              );
            },
          ),

          // 🏛️ TÜM ONAYLI KURULUŞLAR BAŞLIĞI
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Icon(Icons.account_balance, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Text("Aktif Kuruluşlar",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),

          // 🔥 TÜM ONAYLI DERNEKLERİN LİSTESİ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('dernekler')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty)
                  return const Center(
                      child: Text("Henüz onaylı kuruluş bulunmuyor."));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          backgroundImage: data['logo'] != ""
                              ? NetworkImage(data['logo'])
                              : null,
                          child: data['logo'] == ""
                              ? const Icon(Icons.business, color: Colors.blue)
                              : null,
                        ),
                        title: Text(data['dernekName'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['bio'] ?? "Açıklama yok.",
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.blue),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  CommunityDetailScreen(community: doc)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Başvuru Butonu Tasarımı
  Widget _buildApplyButton(BuildContext context) {
    return Column(
      children: [
        const Text("Kendi kuruluşunuzu Meydan'a ekleyin!",
            style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ApplyCommunityScreen())),
          icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
          label: const Text("Hemen Ücretsiz Başvur",
              style:
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ],
    );
  }

  // Durum Kartı (Yönet veya Onay Bekliyor)
  Widget _buildStatusCard(BuildContext context, Map<String, dynamic> d,
      DocumentSnapshot doc, bool isApproved) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(isApproved ? Icons.verified : Icons.hourglass_top,
                color: isApproved ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['dernekName'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(
                  isApproved
                      ? "Yönetim Paneliniz Hazır"
                      : "Başvurunuz İnceleniyor",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isApproved)
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          CommunityDetailScreen(community: doc))),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text("YÖNET"),
            ),
        ],
      ),
    );
  }
}
