// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminClassifiedAdsTab extends StatefulWidget {
  const AdminClassifiedAdsTab({Key? key}) : super(key: key);

  @override
  State<AdminClassifiedAdsTab> createState() => _AdminClassifiedAdsTabState();
}

class _AdminClassifiedAdsTabState extends State<AdminClassifiedAdsTab> {
  static const String adsCollection = 'classified_ads';

  String _statusFilter = 'all';
  String _search = '';

  final Map<String, String> _statusLabels = const {
    'all': 'Hepsi',
    'active': 'Yayında',
    'pending': 'Bekleyen',
    'passive': 'Pasif',
    'sold': 'Satıldı',
    'rejected': 'Reddedildi',
  };

  Future<void> _updateAd(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection(adsCollection)
        .doc(docId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("İlan güncellendi.")),
    );
  }

  Future<void> _deleteAd(String docId) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text("Bu ilan kalıcı olarak silinsin mi?"),
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

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection(adsCollection)
        .doc(docId)
        .delete();
  }

  void _showActions(String docId, Map<String, dynamic> ad) {
    final status = (ad['status'] ?? 'active').toString();
    final featured = ad['isFeatured'] == true;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(ad['title']?.toString() ?? "İlan İşlemleri"),
        actions: [
          CupertinoActionSheetAction(
            child: Text(featured ? "Vitrinden Kaldır" : "Vitrine Al"),
            onPressed: () {
              Navigator.pop(context);
              _updateAd(docId, {'isFeatured': !featured});
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Yayına Al"),
            onPressed: () {
              Navigator.pop(context);
              _updateAd(docId, {'status': 'active', 'isActive': true});
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Pasife Al"),
            onPressed: () {
              Navigator.pop(context);
              _updateAd(docId, {'status': 'passive', 'isActive': false});
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Satıldı Yap"),
            onPressed: () {
              Navigator.pop(context);
              _updateAd(docId, {'status': 'sold', 'isActive': false});
            },
          ),
          if (status == 'pending')
            CupertinoActionSheetAction(
              child: const Text("Reddet"),
              onPressed: () {
                Navigator.pop(context);
                _updateAd(docId, {'status': 'rejected', 'isActive': false});
              },
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () {
              Navigator.pop(context);
              _deleteAd(docId);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("İptal"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection(adsCollection);

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                CupertinoSearchTextField(
                  placeholder: "İlan başlığı, kategori, satıcı ara",
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _statusLabels.entries
                        .map((e) => _filterChip(e.key, e.value))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query
                  .orderBy('createdAt', descending: true)
                  .limit(250)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                var docs = snapshot.data!.docs;

                if (_search.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final text =
                        "${data['title'] ?? ''} ${data['category'] ?? ''} ${data['subCategory'] ?? ''} ${data['sellerName'] ?? ''}"
                            .toLowerCase();
                    return text.contains(_search);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text("İlan bulunamadı."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _adCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ),
    );
  }

  Widget _adCard(String docId, Map<String, dynamic> ad) {
    final images = ad['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : '';
    final status = (ad['status'] ?? 'active').toString();
    final views = ad['views'] ?? 0;
    final featured = ad['isFeatured'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: imageUrl.isEmpty
                ? const Icon(CupertinoIcons.photo, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad['title']?.toString() ?? "Başlıksız",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text("${ad['price'] ?? 0} TL",
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(
                        _statusLabels[status] ?? status, _statusColor(status)),
                    _badge("${ad['category'] ?? '-'}", Colors.indigo),
                    _badge("$views görüntülenme", Colors.blueGrey),
                    if (featured) _badge("Vitrin", Colors.purple),
                  ],
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showActions(docId, ad),
            child: const Icon(CupertinoIcons.ellipsis_vertical),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'sold':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
