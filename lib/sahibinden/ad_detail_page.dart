// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'seller_store_page.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';
import 'package:pazarcik_portal/utils/map_launcher.dart';
import 'sahibinden_image_viewer.dart';
import 'package:pazarcik_portal/utils/portal_seo_helper.dart';

class AdDetailPage extends StatefulWidget {
  final Map<String, dynamic> ad;

  const AdDetailPage({Key? key, required this.ad}) : super(key: key);

  @override
  State<AdDetailPage> createState() => _AdDetailPageState();
}

class _AdDetailPageState extends State<AdDetailPage> {
  int _currentImageIndex = 0;
  final TextEditingController _reviewController = TextEditingController();

  final Color sahibindenYellow = const Color(0xFFFFE800);
  final Color sahibindenDark = const Color(0xFF1C1C1E);

  @override
  void dispose() {
    _reviewController.dispose();
    PortalSeoHelper.resetTitle();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _increaseViewCount();
    PortalSeoHelper.updateTitle(widget.ad['title'] ?? 'İlan');
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _increaseViewCount() async {
    final adId = (widget.ad['docId'] ?? widget.ad['adId'] ?? '').toString();
    if (adId.isEmpty) return;

    try {
      final incrementVal = 8 + (DateTime.now().microsecond % 7); // 8..14 arası artış
      await FirebaseFirestore.instance
          .collection('classified_ads')
          .doc(adId)
          .set({
        'views': FieldValue.increment(incrementVal),
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Görüntülenme artırma hatası: $e");
    }
  }

  Future<void> _openMap(GeoPoint pos) async {
    await PortalMapLauncher.open(
      context,
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
  }

  void _shareAd() {
    final title = widget.ad['title'] ?? "İlan";
    final price = widget.ad['price']?.toString() ?? "0";
    final adId = (widget.ad['docId'] ?? widget.ad['adId'] ?? widget.ad['id'] ?? '').toString();

    if (adId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu ilan paylaşılamıyor.")),
      );
      return;
    }

    final shareUrl = "https://www.pazarcikportal.com/ilan?id=$adId";
    final playStore =
        "https://play.google.com/store/apps/details?id=com.pp.pazarckportal.pazarckportal";

    Share.share(
      "Pazarcık Portal'da Yeni İlan!\n\n"
      "$title\n"
      "Fiyat: $price TL\n\n"
      "İlan Detayı:\n$shareUrl\n\n"
      "Uygulama İndir:\n$playStore",
    );
  }

  String _formatPrice(dynamic value) {
    if (value == null) return "Fiyat belirtilmedi";
    if (value is num) {
      return "${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} TL";
    }
    final text = value.toString();
    return text.isEmpty ? "Fiyat belirtilmedi" : "$text TL";
  }

  String _badgeText() {
    final category = (widget.ad['category'] ?? '').toString();
    final condition = (widget.ad['condition'] ?? '').toString();
    final sellerType = (widget.ad['sellerType'] ?? '').toString();

    if (category == "Sıfır Ürün" || condition == "new") return "Yeni Ürün";
    if (category == "İkinci El" || condition == "used") return "İkinci El";
    if (sellerType == "corporate") return "Kurumsal";
    return category.isEmpty ? "İlan" : category;
  }

  Color _badgeColor() {
    final badge = _badgeText();

    if (badge == "Yeni Ürün") return const Color(0xFF16A34A);
    if (badge == "İkinci El") return const Color(0xFF2563EB);
    if (badge == "Kurumsal") return const Color(0xFF7C3AED);
    if (badge == "Emlak") return const Color(0xFFF97316);
    return const Color(0xFF0284C7);
  }

  String _ownerId() {
    return (widget.ad['ownerId'] ?? widget.ad['sellerId'] ?? '').toString();
  }

  Future<Map<String, dynamic>?> _getSellerData() async {
    final ownerId = _ownerId();
    if (ownerId.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(ownerId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['uid'] = doc.id;
    return data;
  }

  Widget _buildMainInfoCard() {
    final adId = (widget.ad['docId'] ?? widget.ad['adId'] ?? '').toString();

    return StreamBuilder<DocumentSnapshot>(
      stream: adId.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('classified_ads')
              .doc(adId)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        final liveData =
            (snapshot.data?.data() as Map<String, dynamic>?) ?? widget.ad;
        final int views = (liveData['views'] is num)
            ? (liveData['views'] as num).toInt()
            : 1;

        final displayAdNo = adId.length > 8
            ? adId.substring(0, 8).toUpperCase()
            : adId.toUpperCase();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatPrice(liveData['price'] ?? widget.ad['price']),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                liveData['title'] ?? widget.ad['title'] ?? "",
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const Divider(height: 28),
              if (displayAdNo.isNotEmpty)
                _buildInfoRow("İlan No", "#$displayAdNo"),
              _buildInfoRow(
                  "İlan Tarihi",
                  _formatDate(
                      liveData['createdAt'] ?? widget.ad['createdAt'])),
              _buildInfoRow("Görüntülenme", "$views kez görüntülendi"),
              _buildInfoRow("Kategori",
                  liveData['category'] ?? widget.ad['category'] ?? "-"),
              _buildInfoRow("Alt Kategori",
                  liveData['subCategory'] ?? widget.ad['subCategory'] ?? "-"),
              if ((liveData['brandModel'] ??
                      widget.ad['brandModel'] ??
                      '')
                  .toString()
                  .isNotEmpty)
                _buildInfoRow(
                    "Marka / Model",
                    (liveData['brandModel'] ?? widget.ad['brandModel'])
                        .toString()),
              _buildInfoRow("Durum", _badgeText()),
              if ((liveData['district'] ??
                      liveData['location'] ??
                      widget.ad['district'] ??
                      '')
                  .toString()
                  .isNotEmpty)
                _buildInfoRow(
                    "Konum",
                    (liveData['district'] ??
                            liveData['location'] ??
                            widget.ad['district'])
                        .toString()),
              if ((liveData['images'] ?? widget.ad['images']) is List &&
                  ((liveData['images'] ?? widget.ad['images']) as List).length > 1) ...[
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Fotoğraflar (${((liveData['images'] ?? widget.ad['images']) as List).length})",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final raw = (liveData['images'] ?? widget.ad['images']) as List;
                        final imgList = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
                        SahibindenImageViewer.open(
                          context,
                          images: imgList,
                          initialIndex: 0,
                          title: widget.ad['title'] ?? '',
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.zoom_in, size: 16, color: Color(0xFF0056D2)),
                          SizedBox(width: 4),
                          Text(
                            "Büyüt / Galeriyi Aç",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0056D2),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: ((liveData['images'] ?? widget.ad['images']) as List).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final raw = (liveData['images'] ?? widget.ad['images']) as List;
                      final imgUrl = raw[idx].toString();
                      return GestureDetector(
                        onTap: () {
                          final imgList = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
                          SahibindenImageViewer.open(
                            context,
                            images: imgList,
                            initialIndex: idx,
                            title: widget.ad['title'] ?? '',
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: idx == _currentImageIndex
                                    ? sahibindenYellow
                                    : Colors.black12,
                                width: idx == _currentImageIndex ? 2 : 1,
                              ),
                            ),
                            child: PortalNetworkImage(
                              url: imgUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _sellerReviewsStream(String sellerId) {
    return FirebaseFirestore.instance
        .collection('seller_reviews')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots();
  }

  double _averageRating(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;

    double total = 0;
    int count = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['parentId'] != null) continue;
      final r = (data['rating'] ?? 0).toDouble();
      if (r > 0) {
        total += r;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Az önce";
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp);
    }
    if (date == null) return "Az önce";

    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return "Az önce";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24 && date.day == now.day) return "${diff.inHours} saat önce";
    if (diff.inDays == 1 || (diff.inHours < 48 && date.day == now.subtract(const Duration(days: 1)).day)) {
      return "Dün ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  Widget _buildRatingBreakdown(List<QueryDocumentSnapshot> mainDocs, double avgRating) {
    final totalCount = mainDocs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['rating'] ?? 0) > 0;
    }).length;

    final starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final doc in mainDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final r = (data['rating'] ?? 0).toInt();
      if (r >= 1 && r <= 5) {
        starCounts[r] = (starCounts[r] ?? 0) + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Sol: Büyük Puan & Yıldızlar
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                avgRating == 0 ? "0.0" : avgRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return Icon(
                    starIndex <= avgRating.round()
                        ? Icons.star_rounded
                        : (starIndex - avgRating <= 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
                    color: Colors.amber[700],
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 5),
              Text(
                "$totalCount Puanlama",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 75, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 14),
          // Sağ: Yıldız Dağılım Çubukları (5'ten 1'e)
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = starCounts[star] ?? 0;
                final percent = totalCount > 0 ? (count / totalCount) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    children: [
                      Text(
                        "$star",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              star >= 4
                                  ? Colors.amber[700]!
                                  : (star == 3 ? Colors.orange : Colors.grey[400]!),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 20,
                        child: Text(
                          "$count",
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0056D2).withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF0056D2) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? const Color(0xFF0056D2) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? const Color(0xFF0056D2) : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? const Color(0xFF0056D2).withOpacity(0.8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? const Color(0xFF0056D2) : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReviewDialog(String sellerId, String sellerName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorum yapmak için lütfen önce giriş yapın."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (user.uid == sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kendi ilanınıza veya mağazanıza yorum yapamazsınız."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fullName = await CommentIdentity.currentUserFullName();
    final initials = CommentIdentity.initialsOnly(fullName);
    int rating = 5;
    PrivacyChoice privacy = PrivacyChoice.fullName;
    final textController = TextEditingController();
    bool isSubmitting = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String previewName = fullName;
            if (privacy == PrivacyChoice.initials) previewName = initials;
            if (privacy == PrivacyChoice.anonymous) previewName = "Pazarcık Sakini";

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Yorum ve Değerlendirme",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  sellerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Yıldız seçimi
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                final star = index + 1;
                                return GestureDetector(
                                  onTap: () => setModalState(() => rating = star),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      star <= rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: Colors.amber[700],
                                      size: 34,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rating == 5
                                  ? "Mükemmel (5 Yıldız)"
                                  : rating == 4
                                      ? "Çok İyi (4 Yıldız)"
                                      : rating == 3
                                          ? "Orta (3 Yıldız)"
                                          : rating == 2
                                              ? "Zayıf (2 Yıldız)"
                                              : "Kötü (1 Yıldız)",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: textController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "İlan veya satıcı hakkındaki deneyiminizi yazın...",
                          hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF0056D2), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "İsminiz Nasıl Görünsün?",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildPrivacyOption(
                        title: "Tam Adım",
                        subtitle: fullName,
                        icon: Icons.person_rounded,
                        selected: privacy == PrivacyChoice.fullName,
                        onTap: () => setModalState(() => privacy = PrivacyChoice.fullName),
                      ),
                      const SizedBox(height: 6),
                      _buildPrivacyOption(
                        title: "Sadece Baş Harfler",
                        subtitle: initials,
                        icon: Icons.sort_by_alpha_rounded,
                        selected: privacy == PrivacyChoice.initials,
                        onTap: () => setModalState(() => privacy = PrivacyChoice.initials),
                      ),
                      const SizedBox(height: 6),
                      _buildPrivacyOption(
                        title: "İsmimi Gizle (Anonim)",
                        subtitle: "Pazarcık Sakini",
                        icon: Icons.visibility_off_rounded,
                        selected: privacy == PrivacyChoice.anonymous,
                        onTap: () => setModalState(() => privacy = PrivacyChoice.anonymous),
                      ),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Görünecek İsim: $previewName",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Vazgeç"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final text = textController.text.trim();
                                      if (text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Lütfen bir yorum yazın.")),
                                        );
                                        return;
                                      }
                                      setModalState(() => isSubmitting = true);
                                      try {
                                        await FirebaseFirestore.instance.collection('seller_reviews').add({
                                          'sellerId': sellerId,
                                          'reviewerId': user.uid,
                                          'adId': widget.ad['id'] ?? widget.ad['adId'] ?? '',
                                          'adTitle': widget.ad['title'] ?? '',
                                          ...CommentIdentity.authorFieldsWithMode(
                                            fullName: fullName,
                                            choice: privacy,
                                          ),
                                          'rating': rating,
                                          'comment': text,
                                          'parentId': null,
                                          'createdAt': FieldValue.serverTimestamp(),
                                        });
                                        if (mounted) {
                                          Navigator.pop(dialogCtx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Yorumunuz başarıyla paylaşıldı."),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Hata: $e")),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0056D2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text("Yorumu Paylaş", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReplyDialog(String sellerId, String parentId, String replyToName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yanıt yazmak için lütfen önce giriş yapın."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fullName = await CommentIdentity.currentUserFullName();
    final initials = CommentIdentity.initialsOnly(fullName);
    PrivacyChoice privacy = PrivacyChoice.fullName;
    final textController = TextEditingController();
    bool isSubmitting = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String previewName = fullName;
            if (privacy == PrivacyChoice.initials) previewName = initials;
            if (privacy == PrivacyChoice.anonymous) previewName = "Pazarcık Sakini";

            final isOwner = user.uid == sellerId;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0056D2).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.reply_rounded, color: Color(0xFF0056D2), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Yoruma Yanıt Ver",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  "$replyToName kullanıcısına",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isOwner) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.verified_rounded, size: 16, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "İlan sahibi olarak yanıt veriyorsunuz. Yanıtınızda 'İlan Sahibi' rozeti görünecektir.",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78350F)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: textController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Yanıtınızı buraya yazın...",
                          hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF0056D2), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        "İsminiz Nasıl Görünsün?",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildPrivacyOption(
                        title: "Tam Adım",
                        subtitle: fullName,
                        icon: Icons.person_rounded,
                        selected: privacy == PrivacyChoice.fullName,
                        onTap: () => setModalState(() => privacy = PrivacyChoice.fullName),
                      ),
                      const SizedBox(height: 6),
                      _buildPrivacyOption(
                        title: "Sadece Baş Harfler",
                        subtitle: initials,
                        icon: Icons.sort_by_alpha_rounded,
                        selected: privacy == PrivacyChoice.initials,
                        onTap: () => setModalState(() => privacy = PrivacyChoice.initials),
                      ),
                      const SizedBox(height: 6),
                      _buildPrivacyOption(
                        title: "İsmimi Gizle (Anonim)",
                        subtitle: "Pazarcık Sakini",
                        icon: Icons.visibility_off_rounded,
                        selected: privacy == PrivacyChoice.anonymous,
                        onTap: () => setModalState(() => privacy = PrivacyChoice.anonymous),
                      ),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Görünecek İsim: $previewName",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Vazgeç"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final text = textController.text.trim();
                                      if (text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Lütfen bir yanıt yazın.")),
                                        );
                                        return;
                                      }
                                      setModalState(() => isSubmitting = true);
                                      try {
                                        await FirebaseFirestore.instance.collection('seller_reviews').add({
                                          'sellerId': sellerId,
                                          'reviewerId': user.uid,
                                          'adId': widget.ad['id'] ?? widget.ad['adId'] ?? '',
                                          'adTitle': widget.ad['title'] ?? '',
                                          ...CommentIdentity.authorFieldsWithMode(
                                            fullName: fullName,
                                            choice: privacy,
                                          ),
                                          'rating': 0,
                                          'comment': text,
                                          'parentId': parentId,
                                          'replyToName': replyToName,
                                          'createdAt': FieldValue.serverTimestamp(),
                                        });
                                        if (mounted) {
                                          Navigator.pop(dialogCtx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Yanıtınız başarıyla paylaşıldı."),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Hata: $e")),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0056D2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text("Yanıtla", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditReviewDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final controller = TextEditingController(text: data['comment'] ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yorumu Düzenle"),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (updated == true && controller.text.trim().isNotEmpty) {
      await doc.reference.update({
        'comment': controller.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _deleteReview(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yorumu Sil"),
        content: const Text("Bu yorumu silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repliesSnap = await FirebaseFirestore.instance
            .collection('seller_reviews')
            .where('parentId', isEqualTo: doc.id)
            .get();
        for (final r in repliesSnap.docs) {
          await r.reference.delete();
        }
        await doc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Yorum silindi.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Silinemedi: $e")),
          );
        }
      }
    }
  }

  Widget _buildCommentCard({
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String visibleName,
    required int rating,
    required bool isOwner,
    required bool isMine,
    required List<QueryDocumentSnapshot> replies,
    required String ownerId,
    required String? currentUserId,
  }) {
    final isAnonymous = data['isAnonymous'] == true || data['namePrivacy'] == 'anonymous';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Yazar Satırı
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: isAnonymous
                    ? const Color(0xFFE2E8F0)
                    : (isOwner ? Colors.amber.shade100 : const Color(0xFF0056D2).withOpacity(0.12)),
                child: Icon(
                  isAnonymous
                      ? Icons.person_outline_rounded
                      : (isOwner ? Icons.storefront_rounded : Icons.person_rounded),
                  size: 18,
                  color: isAnonymous
                      ? const Color(0xFF64748B)
                      : (isOwner ? Colors.amber.shade900 : const Color(0xFF0056D2)),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            visibleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade400, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.verified_rounded, size: 10, color: Colors.amber),
                                SizedBox(width: 3),
                                Text(
                                  "İlan Sahibi",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF78350F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(data['createdAt']),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (rating > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber[700],
                      size: 15,
                    );
                  }),
                ),
              if (isMine)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditReviewDialog(doc);
                    } else if (val == 'delete') {
                      _deleteReview(doc);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text("Düzenle")),
                    PopupMenuItem(value: 'delete', child: Text("Sil", style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Yorum Metni
          Text(
            data['comment'] ?? '',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),

          // Yanıtla Butonu
          Row(
            children: [
              InkWell(
                onTap: () => _showReplyDialog(ownerId, doc.id, visibleName),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.reply_rounded, size: 15, color: Color(0xFF0056D2)),
                      SizedBox(width: 4),
                      Text(
                        "Yanıtla",
                        style: TextStyle(
                          color: Color(0xFF0056D2),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (replies.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  "•  ${replies.length} yanıt",
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),

          // İç İçe Yanıtlar (Replies)
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFCBD5E1), width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies.map((replyDoc) {
                  final rData = replyDoc.data() as Map<String, dynamic>;
                  final rName = CommentIdentity.visibleName(
                    rData,
                    nameFields: const ['authorDisplayName', 'reviewerName', 'userName', 'authorFullName'],
                  );
                  final rIsOwner = rData['reviewerId'] == ownerId;
                  final rIsMine = currentUserId != null && rData['reviewerId'] == currentUserId;
                  final rIsAnon = rData['isAnonymous'] == true || rData['namePrivacy'] == 'anonymous';

                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: rIsOwner ? Colors.amber.withOpacity(0.06) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: rIsOwner ? Colors.amber.shade200 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              rIsAnon
                                  ? Icons.person_outline_rounded
                                  : (rIsOwner ? Icons.storefront_rounded : Icons.person_rounded),
                              size: 13,
                              color: rIsOwner ? Colors.amber.shade900 : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                rName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  color: rIsOwner ? const Color(0xFF78350F) : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            if (rIsOwner) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "İlan Sahibi",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF78350F),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              _formatDate(rData['createdAt']),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (rIsMine)
                              IconButton(
                                onPressed: () => _deleteReview(replyDoc),
                                icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rData['comment'] ?? '',
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsSection(String ownerId, String sellerName) {
    if (ownerId.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _sellerReviewsStream(ownerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: const Center(child: CupertinoActivityIndicator()),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final docs = List<QueryDocumentSnapshot>.from(allDocs);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final mainDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['parentId'] == null;
        }).toList();

        final avgRating = _averageRating(docs);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık Satırı
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rate_review_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("DEĞERLENDİRME VE YORUMLAR"),
                        Text(
                          mainDocs.isEmpty
                              ? "Henüz yorum yapılmamış"
                              : "${mainDocs.length} vatandaş yorum yaptı",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(ownerId, sellerName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sahibindenDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(CupertinoIcons.pencil, size: 14),
                    label: const Text(
                      "Yorum Yaz",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Puan Dağılım Özeti
              if (mainDocs.isNotEmpty) ...[
                _buildRatingBreakdown(mainDocs, avgRating),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.chat_bubble_2, size: 34, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      const Text(
                        "Bu ilan ve satıcı için henüz yorum yok.",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "İlan sahibiyle iletişim kurduysanız ilk yorumu ve puanı siz verin!",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Yorumlar Listesi
              if (mainDocs.isNotEmpty) ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mainDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = mainDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final rating = (data['rating'] ?? 0).toInt();
                    final visibleName = CommentIdentity.visibleName(
                      data,
                      nameFields: const ['authorDisplayName', 'reviewerName', 'userName', 'authorFullName'],
                    );
                    final isOwnerReview = data['reviewerId'] == ownerId;
                    final isMyReview = currentUserId != null && data['reviewerId'] == currentUserId;

                    final replies = docs.where((rDoc) {
                      final rData = rDoc.data() as Map<String, dynamic>;
                      return rData['parentId'] == doc.id;
                    }).toList();

                    return _buildCommentCard(
                      doc: doc,
                      data: data,
                      visibleName: visibleName,
                      rating: rating,
                      isOwner: isOwnerReview,
                      isMine: isMyReview,
                      replies: replies,
                      ownerId: ownerId,
                      currentUserId: currentUserId,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.ad['images'] as List? ?? [];
    final ownerId = _ownerId();
    final adLocation = widget.ad['lat_lang'] as GeoPoint?;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 390,
                pinned: true,
                backgroundColor: sahibindenYellow,
                leading: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(CupertinoIcons.share, color: Colors.black),
                      onPressed: _shareAd,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      Positioned.fill(
                        child: images.isNotEmpty
                            ? PageView.builder(
                                itemCount: images.length,
                                onPageChanged: (index) =>
                                    setState(() => _currentImageIndex = index),
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      final imgList = images
                                          .map((e) => e.toString())
                                          .where((e) => e.isNotEmpty)
                                          .toList();
                                      SahibindenImageViewer.open(
                                        context,
                                        images: imgList,
                                        initialIndex: index,
                                        title: widget.ad['title'] ?? '',
                                      );
                                    },
                                    child: PortalNetworkImage(
                                      url: images[index].toString(),
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    CupertinoIcons.photo,
                                    size: 54,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _badgeColor(),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _badgeText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      if (images.isNotEmpty)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: GestureDetector(
                            onTap: () {
                              final imgList = images
                                  .map((e) => e.toString())
                                  .where((e) => e.isNotEmpty)
                                  .toList();
                              SahibindenImageViewer.open(
                                context,
                                images: imgList,
                                initialIndex: _currentImageIndex,
                                title: widget.ad['title'] ?? '',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.24),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${_currentImageIndex + 1} / ${images.length} • Büyüt",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainInfoCard(),
                      const SizedBox(height: 14),
                      _buildSellerCard(ownerId),
                      const SizedBox(height: 14),
                      _buildLocationCard(adLocation),
                      const SizedBox(height: 14),
                      _buildDescriptionCard(),
                      const SizedBox(height: 14),
                      _buildReviewsSection(ownerId, (widget.ad['sellerName'] ?? 'Satıcı').toString()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomCallBar(ownerId),
        ],
      ),
    );
  }

  Widget _buildSellerCard(String ownerId) {
    if (ownerId.isEmpty) return const SizedBox();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getSellerData(),
      builder: (context, sellerSnapshot) {
        final seller = sellerSnapshot.data ?? {};
        final sellerName = (seller['businessName'] ??
                seller['storeName'] ??
                seller['name'] ??
                seller['fullName'] ??
                widget.ad['sellerName'] ??
                'Satıcı')
            .toString();

        final sellerPhone = (seller['phoneNumber'] ??
                seller['phone'] ??
                widget.ad['sellerPhone'] ??
                '')
            .toString();

        final isCorporate = widget.ad['isCorporateSeller'] == true ||
            widget.ad['sellerType'] == "corporate" ||
            seller['corporateSellerApproved'] == true ||
            seller['sellerApproved'] == true;

        return StreamBuilder<QuerySnapshot>(
          stream: _sellerReviewsStream(ownerId),
          builder: (context, reviewSnapshot) {
            final reviewDocs = reviewSnapshot.data?.docs ?? [];
            final rating = _averageRating(reviewDocs);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: sahibindenYellow,
                        child: Icon(
                          isCorporate
                              ? CupertinoIcons.building_2_fill
                              : CupertinoIcons.person_fill,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.star_fill,
                                  color: Colors.orange.shade600,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating == 0
                                      ? "Henüz puan yok"
                                      : "${rating.toStringAsFixed(1)} (${reviewDocs.where((d) => (d.data() as Map<String, dynamic>)['parentId'] == null && ((d.data() as Map<String, dynamic>)['rating'] ?? 0) > 0).length} değerlendirme)",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isCorporate)
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          color: Color(0xFF16A34A),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => SellerStorePage(
                                  sellerId: ownerId,
                                  sellerData: seller,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(CupertinoIcons.square_grid_2x2),
                          label: const Text("Tüm İlanlar"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showReviewDialog(ownerId, sellerName),
                          icon: const Icon(CupertinoIcons.star),
                          label: const Text("Yorum Yap"),
                        ),
                      ),
                    ],
                  ),
                  if (sellerPhone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Telefon: $sellerPhone",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationCard(GeoPoint? adLocation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Konum"),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.ad['address'] ?? "Adres bilgisi girilmemiş.",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (adLocation != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMap(adLocation),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text("Haritada Göster"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Açıklama"),
          const SizedBox(height: 12),
          Text(
            widget.ad['description'] ?? "Açıklama belirtilmemiş.",
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF3A3A3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCallBar(String ownerId) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _getSellerData(),
          builder: (context, snapshot) {
            final seller = snapshot.data ?? {};
            final phoneToShow = (seller['phoneNumber'] ??
                    seller['phone'] ??
                    widget.ad['sellerPhone'] ??
                    '')
                .toString();

            final canCall = phoneToShow.isNotEmpty;

            return SizedBox(
              height: 55,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: sahibindenDark,
                onPressed: canCall ? () => _makeCall(phoneToShow) : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      canCall
                          ? CupertinoIcons.phone_fill
                          : CupertinoIcons.phone,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      canCall ? "İlan Sahibini Ara" : "Numara Belirtilmemiş",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 13,
        color: Colors.grey,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Flexible(
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
