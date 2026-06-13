import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ad_detail_page.dart';

class MyAdsManagementView extends StatefulWidget {
  const MyAdsManagementView({Key? key}) : super(key: key);

  @override
  State<MyAdsManagementView> createState() => _MyAdsManagementViewState();
}

class _MyAdsManagementViewState extends State<MyAdsManagementView> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final String collectionName = 'classified_ads';

  String selectedFilter = "Tümü";

  bool _isAdActive(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    final isActive = data['isActive'];

    if (status.isNotEmpty) return status == 'active';
    if (isActive is bool) return isActive;
    return true;
  }

  String _formatPrice(dynamic value) {
    if (value == null) return "Fiyat yok";
    if (value is num) {
      return "${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} TL";
    }
    final text = value.toString();
    return text.isEmpty ? "Fiyat yok" : "$text TL";
  }

  Future<void> _deleteAd(String docId) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text(
          "Bu ilanı kalıcı olarak silmek istediğinize emin misiniz?",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("İptal"),
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

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(docId)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("İlan başarıyla silindi."),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _toggleAdStatus(String docId, bool currentActive) async {
    final newActive = !currentActive;

    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(docId)
        .update({
      'isActive': newActive,
      'status': newActive ? 'active' : 'passive',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(newActive ? "İlan yayına alındı." : "İlan pasife çekildi."),
        backgroundColor: newActive ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showActionSheet(
    String docId,
    bool isActive,
    Map<String, dynamic> adData,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("İlan İşlemleri"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              adData['docId'] = docId;
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => AdDetailPage(ad: adData),
                ),
              );
            },
            child: const Text("İlanı Görüntüle"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _toggleAdStatus(docId, isActive);
            },
            child: Text(
              isActive ? "Pasif Yap" : "Yayına Al",
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteAd(docId);
            },
            child: const Text("Kalıcı Olarak Sil"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("İptal"),
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filteredDocs(List<QueryDocumentSnapshot> docs) {
    if (selectedFilter == "Tümü") return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final active = _isAdActive(data);

      if (selectedFilter == "Aktif") return active;
      if (selectedFilter == "Pasif") return !active;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Oturum bulunamadı.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(
          "İlan Yönetimi",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFFFFE800),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collectionName)
            .where('ownerId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "İlanlar yüklenemedi.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final visibleDocs = _filteredDocs(docs);

          int totalViews = 0;
          int activeAdsCount = 0;
          int passiveAdsCount = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final views = data['views'];

            if (views is int) {
              totalViews += views;
            } else if (views is num) {
              totalViews += views.toInt();
            }

            if (_isAdActive(data)) {
              activeAdsCount++;
            } else {
              passiveAdsCount++;
            }
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStats(
                    totalViews, activeAdsCount, passiveAdsCount, docs.length),
                const SizedBox(height: 22),
                _buildFilterBar(),
                const SizedBox(height: 20),
                Text(
                  "İLANLARIM",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                if (visibleDocs.isEmpty)
                  _buildEmptyState()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleDocs.length,
                    itemBuilder: (context, index) {
                      final adData =
                          visibleDocs[index].data() as Map<String, dynamic>;
                      final docId = visibleDocs[index].id;
                      return _buildManageAdItem(adData, docId);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(
    int totalViews,
    int activeAdsCount,
    int passiveAdsCount,
    int totalAds,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              "Toplam İlan",
              "$totalAds",
              CupertinoIcons.square_list_fill,
              Colors.black87,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              "Toplam İzlenme",
              "$totalViews",
              CupertinoIcons.eye_fill,
              Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              "Aktif",
              "$activeAdsCount",
              CupertinoIcons.checkmark_seal_fill,
              Colors.green,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              "Pasif",
              "$passiveAdsCount",
              CupertinoIcons.pause_circle_fill,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ["Tümü", "Aktif", "Pasif"];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final active = selectedFilter == filter;

          return GestureDetector(
            onTap: () => setState(() => selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: active ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? Colors.black : const Color(0xFFE5E7EB),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(CupertinoIcons.doc_text_search, size: 46, color: Colors.grey),
          SizedBox(height: 14),
          Text(
            "Bu filtrede ilan bulunmuyor.",
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageAdItem(Map<String, dynamic> adData, String docId) {
    final bool isActive = _isAdActive(adData);
    final List images = adData['images'] ?? [];
    final String imageUrl = images.isNotEmpty ? images.first.toString() : "";

    final int views = adData['views'] is int
        ? adData['views']
        : adData['views'] is num
            ? (adData['views'] as num).toInt()
            : 0;

    final String category = (adData['category'] ?? "-").toString();
    final String title = (adData['title'] ?? "Başlıksız").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 72,
              height: 72,
              color: const Color(0xFFF1F5F9),
              child: imageUrl.isNotEmpty
                  ? PortalNetworkImage(
                      url: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget:
                          const Icon(CupertinoIcons.photo, color: Colors.grey),
                    )
                  : const Icon(CupertinoIcons.photo, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatPrice(adData['price']),
                  style: const TextStyle(
                    color: Color(0xFF0056D2),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _miniBadge(
                      isActive ? "AKTİF" : "PASİF",
                      isActive ? Colors.green : Colors.orange,
                    ),
                    _miniBadge(category, Colors.blueGrey),
                    _miniBadge("$views görüntülenme", Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(
              CupertinoIcons.ellipsis_vertical,
              color: Colors.grey,
            ),
            onPressed: () => _showActionSheet(docId, isActive, adData),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
