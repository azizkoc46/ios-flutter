// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';

import 'ad_detail_page.dart';

class SellerStorePage extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic>? sellerData;

  const SellerStorePage({
    super.key,
    required this.sellerId,
    this.sellerData,
  });

  @override
  State<SellerStorePage> createState() => _SellerStorePageState();
}

class _SellerStorePageState extends State<SellerStorePage> {
  String selectedTab = "İlanlar";

  Stream<QuerySnapshot> _sellerAdsStream() {
    return FirebaseFirestore.instance
        .collection('classified_ads')
        .where('ownerId', isEqualTo: widget.sellerId)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Stream<QuerySnapshot> _sellerReviewsStream() {
    return FirebaseFirestore.instance
        .collection('seller_reviews')
        .where('sellerId', isEqualTo: widget.sellerId)
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

  String _formatPrice(dynamic value) {
    if (value == null) return "Fiyat yok";
    if (value is num) {
      return "${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} TL";
    }
    return "${value.toString()} TL";
  }

  String _formatDate(Timestamp? time) {
    if (time == null) return "Şimdi";
    final date = time.toDate();
    return "${date.day}.${date.month}.${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seller = widget.sellerData ?? {};

    final sellerName = (seller['businessName'] ??
            seller['storeName'] ??
            seller['name'] ??
            seller['fullName'] ??
            "Satıcı")
        .toString();

    final sellerPhone =
        (seller['phoneNumber'] ?? seller['phone'] ?? '').toString();

    final isCorporate = seller['corporateSellerApproved'] == true ||
        seller['sellerApproved'] == true ||
        seller['role'] == 'kurumsal_satici' ||
        seller['role'] == 'corporate_seller' ||
        seller['role'] == 'emlakci';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F5F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: const Color(0xFFFFE800),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 52,
                  left: 20,
                  right: 20,
                  bottom: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFE800),
                      Color(0xFFFFF4A3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _sellerReviewsStream(),
                  builder: (context, snapshot) {
                    final reviews = snapshot.data?.docs ?? [];
                    final rating = _averageRating(reviews);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.black,
                          child: Icon(
                            isCorporate
                                ? CupertinoIcons.building_2_fill
                                : CupertinoIcons.person_fill,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (isCorporate) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                CupertinoIcons.checkmark_seal_fill,
                                color: Color(0xFF16A34A),
                                size: 22,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.star_fill,
                              color: Colors.orange,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              rating == 0
                                  ? "Henüz puan yok"
                                  : "${rating.toStringAsFixed(1)} / 5",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "  •  ${reviews.length} yorum",
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (sellerPhone.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            sellerPhone,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _buildTab("İlanlar"),
                  const SizedBox(width: 10),
                  _buildTab("Yorumlar"),
                ],
              ),
            ),
          ),
          if (selectedTab == "İlanlar") _buildAdsList(),
          if (selectedTab == "Yorumlar") _buildReviewsList(),
        ],
      ),
    );
  }

  Widget _buildTab(String text) {
    final active = selectedTab == text;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = text),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 44,
          decoration: BoxDecoration(
            color: active ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? Colors.black : const Color(0xFFE5E7EB),
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sellerAdsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        final mainDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['parentId'] == null;
        }).toList();

        if (mainDocs.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text("Bu satıcının aktif ilanı yok.")),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.70,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ad = docs[index].data() as Map<String, dynamic>;
                ad['docId'] = docs[index].id;

                final images = ad['images'] as List? ?? [];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => AdDetailPage(ad: ad),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFFF1F5F9),
                              child: images.isNotEmpty
                                  ? PortalNetworkImage(
                                      url: images.first.toString(),
                                      fit: BoxFit.cover)
                                  : const Icon(CupertinoIcons.photo),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatPrice(ad['price']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sellerReviewsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        final mainDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['parentId'] == null;
        }).toList();

        if (mainDocs.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text("Henüz yorum yapılmamış.")),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = mainDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final rating = (data['rating'] ?? 0).toInt();
                final visibleName = CommentIdentity.visibleName(
                  data,
                  nameFields: const ['reviewerName'],
                );
                final replies = docs.where((replyDoc) {
                  final reply = replyDoc.data() as Map<String, dynamic>;
                  return reply['parentId'] == doc.id;
                }).toList();
                final isMine = data['reviewerId'] ==
                    FirebaseAuth.instance.currentUser?.uid;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            visibleName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (isMine)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editReview(doc);
                                } else if (value == 'delete') {
                                  doc.reference.delete();
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Düzenle')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Sil')),
                              ],
                              child: const Icon(Icons.more_horiz, size: 18),
                            ),
                          Text(
                            _formatDate(data['createdAt']),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < rating
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            color: Colors.orange,
                            size: 16,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['comment'] ?? '',
                        style: const TextStyle(
                          height: 1.4,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _replyReview(doc.id, visibleName),
                        child: const Text("Yanıtla",
                            style: TextStyle(
                                color: Color(0xFF0056D2),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (replies.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...replies.map((replyDoc) {
                          final reply = replyDoc.data() as Map<String, dynamic>;
                          final replyName = CommentIdentity.visibleName(
                            reply,
                            nameFields: const ['reviewerName'],
                          );
                          return Padding(
                            padding: const EdgeInsets.only(left: 18, top: 8),
                            child: Text(
                              "$replyName: ${reply['comment'] ?? ''}",
                              style: const TextStyle(
                                height: 1.4,
                                color: Color(0xFF475569),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              },
              childCount: mainDocs.length,
            ),
          ),
        );
      },
    );
  }

  Future<void> _editReview(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final controller = TextEditingController(text: data['comment'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yorumu Düzenle"),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Kaydet")),
        ],
      ),
    );
    if (saved != true || controller.text.trim().isEmpty) return;
    await doc.reference.update({
      'comment': controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _replyReview(String parentId, String replyToName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$replyToName kişisine yanıt"),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Gönder")),
        ],
      ),
    );
    if (send != true || controller.text.trim().isEmpty) return;
    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;
    final fullName = await CommentIdentity.currentUserFullName();
    await FirebaseFirestore.instance.collection('seller_reviews').add({
      'sellerId': widget.sellerId,
      'reviewerId': user.uid,
      'reviewerName': fullName,
      ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
      'rating': 0,
      'comment': controller.text.trim(),
      'parentId': parentId,
      'replyToName': replyToName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
