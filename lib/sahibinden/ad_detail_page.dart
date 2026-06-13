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

class AdDetailPage extends StatefulWidget {
  final Map<String, dynamic> ad;

  const AdDetailPage({Key? key, required this.ad}) : super(key: key);

  @override
  State<AdDetailPage> createState() => _AdDetailPageState();
}

class _AdDetailPageState extends State<AdDetailPage> {
  int _currentImageIndex = 0;
  int _selectedRating = 5;
  final TextEditingController _reviewController = TextEditingController();

  final Color sahibindenYellow = const Color(0xFFFFE800);
  final Color sahibindenDark = const Color(0xFF1C1C1E);

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _increaseViewCount();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _increaseViewCount() async {
    final adId = widget.ad['docId'] ?? widget.ad['adId'];
    if (adId == null || adId.toString().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('classified_ads')
        .doc(adId.toString())
        .update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> _openMap(GeoPoint pos) async {
    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harita uygulaması açılamadı.")),
      );
    }
  }

  void _shareAd() {
    final title = widget.ad['title'] ?? "İlan";
    final price = widget.ad['price']?.toString() ?? "0";
    final adId = widget.ad['adId'] ?? "";

    if (adId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu ilan eski, paylaşılamaz.")),
      );
      return;
    }

    final shareUrl = "https://pazarcik-portal-7faf2.web.app/ilan?id=$adId";
    final playStore =
        "https://play.google.com/store/apps/details?id=com.pp.pazarckportal.pazarckportal";

    Share.share(
      "Pazarcık Portal'da Yeni İlan!\n\n"
      "$title\n"
      "Fiyat: $price TL\n\n"
      "İlanı Uygulamada Gör:\n$shareUrl\n\n"
      "Uygulama Yüklü Değilse:\n$playStore",
    );
  }

  String _formatPrice(dynamic value) {
    if (value == null) return "Fiyat belirtilmedi";
    if (value is num)
      return "${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} TL";
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

  Stream<QuerySnapshot> _sellerReviewsStream(String sellerId) {
    return FirebaseFirestore.instance
        .collection('seller_reviews')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  double _averageRating(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;

    double total = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['parentId'] != null) continue;
      total += (data['rating'] ?? 0).toDouble();
    }

    final mainCount = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['parentId'] == null;
    }).length;
    return mainCount == 0 ? 0 : total / mainCount;
  }

  void _showSellerAds(String sellerId, String sellerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "$sellerName ilanları",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('classified_ads')
                        .where('ownerId', isEqualTo: sellerId)
                        .where('status', isEqualTo: 'active')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CupertinoActivityIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("Bu satıcının aktif ilanı yok."),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final ad = docs[index].data() as Map<String, dynamic>;
                          ad['docId'] = docs[index].id;

                          final images = ad['images'] as List? ?? [];

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => AdDetailPage(ad: ad),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 76,
                                      height: 76,
                                      color: const Color(0xFFF1F5F9),
                                      child: images.isNotEmpty
                                          ? PortalNetworkImage(
                                              url: images.first.toString(),
                                              fit: BoxFit.cover)
                                          : const Icon(CupertinoIcons.photo),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatPrice(ad['price']),
                                          style: const TextStyle(
                                            color: Color(0xFF0056D2),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          ad['title'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ],
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
          ),
        );
      },
    );
  }

  void _showReviewDialog(String sellerId, String sellerName) {
    _selectedRating = 5;
    _reviewController.clear();

    showCupertinoDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: Text("$sellerName için yorum yap"),
              content: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => _selectedRating = star),
                        child: Icon(
                          star <= _selectedRating
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          color: Colors.orange,
                          size: 26,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  CupertinoTextField(
                    controller: _reviewController,
                    placeholder: "Yorumunuzu yazın",
                    minLines: 3,
                    maxLines: 4,
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text("Vazgeç"),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text("Gönder"),
                  onPressed: () async {
                    await _submitReview(sellerId);
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReview(String sellerId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yorum yapmak için giriş yapmalısınız.")),
      );
      return;
    }

    if (user.uid == sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kendi mağazanıza yorum yapamazsınız.")),
      );
      return;
    }

    final text = _reviewController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen yorum yazın.")),
      );
      return;
    }

    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;
    final fullName = await CommentIdentity.currentUserFullName();

    await FirebaseFirestore.instance.collection('seller_reviews').add({
      'sellerId': sellerId,
      'reviewerId': user.uid,
      'reviewerName': fullName,
      ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
      'rating': _selectedRating,
      'comment': text,
      'parentId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Yorumunuz gönderildi."),
        backgroundColor: Colors.green,
      ),
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
                                  return PortalNetworkImage(
                                    url: images[index].toString(),
                                    fit: BoxFit.cover,
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              "${_currentImageIndex + 1} / ${images.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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

  Widget _buildMainInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatPrice(widget.ad['price']),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF007AFF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.ad['title'] ?? "",
            style: const TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const Divider(height: 32),
          _buildInfoRow("Kategori", widget.ad['category'] ?? "-"),
          _buildInfoRow("Alt Kategori", widget.ad['subCategory'] ?? "-"),
          if ((widget.ad['brandModel'] ?? '').toString().isNotEmpty)
            _buildInfoRow("Marka / Model", widget.ad['brandModel']),
          _buildInfoRow("Durum", _badgeText()),
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
                                      : "${rating.toStringAsFixed(1)} (${reviewDocs.length} yorum)",
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
