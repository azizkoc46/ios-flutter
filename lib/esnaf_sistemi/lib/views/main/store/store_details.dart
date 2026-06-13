// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/product/details.dart';
import 'package:pazarcik_portal/widgets/comment_identity.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import '../../../utils/store_availability.dart';

// Proje Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class StoreDetails extends StatefulWidget {
  const StoreDetails({Key? key, required this.store}) : super(key: key);
  final dynamic store;

  @override
  State<StoreDetails> createState() => _StoreDetailsState();
}

class _StoreDetailsState extends State<StoreDetails> {
  final TextEditingController _commentController = TextEditingController();
  double userRating = 5.0; // Varsayılan 5 yıldız
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  String selectedCategory = "Hepsi";

  // 🔥 SPAM KORUMASI İÇİN YENİ DEĞİŞKEN
  bool _hasReviewed = false;

  String get storeId => (widget.store is DocumentSnapshot)
      ? (widget.store as DocumentSnapshot).id
      : (widget.store['id'] ?? "");

  @override
  void initState() {
    super.initState();
    _checkIfUserAlreadyReviewed();
  }

  // 🔥 SAYFA AÇILDIĞINDA KULLANICININ YORUMU VAR MI KONTROL ET
  Future<void> _checkIfUserAlreadyReviewed() async {
    if (currentUserId.isEmpty || storeId.isEmpty) return;

    var snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('storeId', isEqualTo: storeId)
        .where('userId', isEqualTo: currentUserId)
        .where('parentId', isNull: true)
        .get();

    if (snapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _hasReviewed = true;
      });
    }
  }

  // 🔥 MAĞAZA PAYLAŞMA FONKSİYONU
  void _shareStore(Map<String, dynamic> data) {
    String name = data['storeName'] ?? "Pazarcık Esnafı";
    String shareUrl =
        "https://pazarcik-portal-7faf2.web.app/magaza?id=$storeId";

    String shareText = "🛍️ Pazarcık Portal'da Harika Bir Mağaza!\n\n"
        "🏪 Mağaza: $name\n"
        "📍 Adres: ${data['storeAddress'] ?? 'Pazarcık'}\n\n"
        "🔗 Ürünleri İncelemek İçin Tıkla:\n$shareUrl";

    Share.share(shareText);
  }

  // MAĞAZANIN GENEL ORTALAMASINI HESAPLAMA VE GÜNCELLEME
  double _calculateAverageRating(List<QueryDocumentSnapshot> reviews) {
    final mainReviews = reviews.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['parentId'] == null;
    }).toList();
    if (mainReviews.isEmpty) return 0.0;
    double total = mainReviews.fold(
        0,
        (sum, doc) =>
            sum + ((doc.data() as Map<String, dynamic>)['rating'] ?? 0));
    return double.parse((total / mainReviews.length).toStringAsFixed(1));
  }

  Future<void> _updateStoreAverageRating() async {
    var allReviews = await FirebaseFirestore.instance
        .collection('reviews')
        .where('storeId', isEqualTo: storeId)
        .get();

    double newAverage = _calculateAverageRating(allReviews.docs);

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(storeId)
        .update({'rating': newAverage});
  }

  // YORUM VE YILDIZ GÖNDERME
  Future<void> _submitReview() async {
    final String comment = _commentController.text.trim();
    if (comment.isEmpty || storeId.isEmpty) {
      _showSnackBar("Lütfen bir yorum yazın.", Colors.redAccent);
      return;
    }

    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 🔥 Ekstra Güvenlik: Göndermeden önce tekrar kontrol et
      var existingCheck = await FirebaseFirestore.instance
          .collection('reviews')
          .where('storeId', isEqualTo: storeId)
          .where('userId', isEqualTo: user.uid)
          .where('parentId', isNull: true)
          .get();

      if (existingCheck.docs.isNotEmpty) {
        _showSnackBar("Zaten bir değerlendirmeniz var.", Colors.orange);
        setState(() => _hasReviewed = true);
        return;
      }

      final hideName = await CommentIdentity.askHideName(context);
      if (hideName == null) return;
      final fullName = await CommentIdentity.currentUserFullName();

      await FirebaseFirestore.instance.collection('reviews').add({
        'storeId': storeId,
        'userId': user.uid,
        'userName': fullName,
        ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
        'comment': comment,
        'rating': userRating,
        'parentId': null,
        'date': FieldValue.serverTimestamp(),
      });

      await _updateStoreAverageRating();

      _commentController.clear();
      FocusScope.of(context).unfocus();

      // Başarılı olursa yorum yapma kutusunu kapat
      setState(() {
        userRating = 5.0;
        _hasReviewed = true;
      });

      _showSnackBar("Değerlendirmeniz paylaşıldı! Teşekkürler.", Colors.green);
    } catch (e) {
      debugPrint("Yorum hatası: $e");
    }
  }

  // --- KENDİ YORUMUNU SİLME ---
  Future<void> _deleteReview(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(docId)
          .delete();
      await _updateStoreAverageRating();

      // Silince yorum yapma kutusunu geri getir
      setState(() => _hasReviewed = false);

      _showSnackBar("Yorumunuz silindi.", Colors.redAccent);
    } catch (e) {
      debugPrint("Silme hatası: $e");
    }
  }

  // --- KENDİ YORUMUNU DÜZENLEME EKRANI ---
  void _showEditReviewDialog(
      String docId, String currentComment, double currentRating) {
    TextEditingController editController =
        TextEditingController(text: currentComment);
    double editRating = currentRating;

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CupertinoAlertDialog(
              title: const Text("Yorumu Düzenle"),
              content: Column(
                children: [
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            editRating = index + 1.0;
                          });
                        },
                        child: Icon(
                          index < editRating
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          color: trendyolOrange,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 15),
                  CupertinoTextField(
                    controller: editController,
                    maxLines: 3,
                    placeholder: "Yorumunuz...",
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child:
                      const Text("İptal", style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: const Text("Kaydet",
                      style: TextStyle(color: Colors.blue)),
                  onPressed: () async {
                    if (editController.text.trim().isEmpty) return;
                    Navigator.pop(context);

                    await FirebaseFirestore.instance
                        .collection('reviews')
                        .doc(docId)
                        .update({
                      'comment': editController.text.trim(),
                      'rating': editRating,
                    });

                    await _updateStoreAverageRating();
                    _showSnackBar("Yorumunuz güncellendi.", Colors.green);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> storeData = (widget.store is DocumentSnapshot)
        ? (widget.store as DocumentSnapshot).data() as Map<String, dynamic>? ??
            {}
        : (widget.store as Map<String, dynamic>? ?? {});

    String coverImg = storeData['storeCoverImage'] ?? storeData['image'] ?? '';
    final storeOpen = StoreAvailability.isOpen(storeData);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            stretch: true,
            backgroundColor: trendyolOrange,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(CupertinoIcons.back, color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(CupertinoIcons.share,
                        color: Colors.white, size: 20)),
                onPressed: () => _shareStore(storeData),
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverImg.isNotEmpty
                      ? PortalNetworkImage(url: coverImg, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(CupertinoIcons.photo,
                              size: 50, color: Colors.black26)),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.8)
                      ]))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(
                              storeData['storeName'] ?? "Pazarcık Esnafı",
                              style: GoogleFonts.inter(
                                  fontSize: 24, fontWeight: FontWeight.w900))),
                      _buildRatingBadge(storeData),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStoreMeta(storeData),
                  const Divider(height: 35, thickness: 0.5, color: iosBg),
                  _buildQuickStats(storeData),
                ],
              ),
            ),
          ),
          _buildDynamicCategoryHeader(),
          _buildProductList(storeOpen),
          _buildReviewInputCard(),
          _buildCommentsSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // --- Kategori ve Ürün Listeleme Widgetları ---
  Widget _buildDynamicCategoryHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('vendorId', isEqualTo: storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(child: SizedBox());
        Set<String> uniqueCategories = {"Hepsi"};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['categoryName'] != null)
            uniqueCategories.add(data['categoryName'].toString());
        }
        List<String> categoryList = uniqueCategories.toList();
        return SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
                child: Container(
                    color: iosBg,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        itemCount: categoryList.length,
                        itemBuilder: (context, i) {
                          bool isSelected = selectedCategory == categoryList[i];
                          return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  label: Text(categoryList[i]),
                                  selected: isSelected,
                                  onSelected: (v) => setState(
                                      () => selectedCategory = categoryList[i]),
                                  selectedColor: trendyolOrange,
                                  backgroundColor: Colors.white,
                                  labelStyle: GoogleFonts.inter(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                          color: Colors.transparent))));
                        }))));
      },
    );
  }

  Widget _buildProductList(bool storeOpen) {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('vendorId', isEqualTo: storeId);
    if (selectedCategory != "Hepsi")
      query = query.where('categoryName', isEqualTo: selectedCategory);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(child: CupertinoActivityIndicator());
        var docs = snapshot.data!.docs;
        return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
              var d = docs[index].data() as Map<String, dynamic>;
              return _buildProductItem(d, docs[index], storeOpen);
            }, childCount: docs.length)));
      },
    );
  }

  Widget _buildProductItem(
      Map<String, dynamic> d, QueryDocumentSnapshot doc, bool storeOpen) {
    return Opacity(
        opacity: storeOpen ? 1 : .48,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            onTap: storeOpen
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DetailsScreen(product: doc)))
                : null,
            leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PortalNetworkImage(
                    url: (d['productImage'] ?? "").toString(),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover)),
            title: Text(d['productName'] ?? "",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            subtitle: Text("₺${d['price']}",
                style: const TextStyle(
                    color: trendyolOrange, fontWeight: FontWeight.bold)),
            trailing: storeOpen
                ? const Icon(CupertinoIcons.add_circled_solid,
                    color: trendyolOrange)
                : const Tooltip(
                    message: 'Restoran şu anda kapalı',
                    child: Icon(CupertinoIcons.lock_fill,
                        color: Colors.redAccent)),
          ),
        ));
  }

  // --- Meta ve İstatistik ---
  Widget _buildRatingBadge(Map<String, dynamic> data) {
    double rating = (data['rating'] ?? 0.0).toDouble();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: rating >= 4.0 ? Colors.green : trendyolOrange,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(CupertinoIcons.star_fill, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold))
        ]));
  }

  Widget _buildStoreMeta(Map<String, dynamic> data) {
    return Column(children: [
      _metaRow(CupertinoIcons.location_solid,
          data['storeAddress'] ?? "Pazarcık", Colors.blue),
      const SizedBox(height: 8),
      _metaRow(CupertinoIcons.stopwatch_fill,
          "${data['avgPrepTime'] ?? '25'} dk hazırlama", trendyolOrange),
    ]);
  }

  Widget _metaRow(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: GoogleFonts.inter(color: Colors.black54, fontSize: 13)))
    ]);
  }

  Widget _buildQuickStats(Map<String, dynamic> data) {
    bool isOpen = StoreAvailability.isOpen(data);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _statItem("₺${data['minOrder'] ?? '0'}", "Min. Paket"),
      _statItem("Ücretsiz", "Teslimat"),
      _statItem(isOpen ? "Açık" : "Kapalı", "Durum"),
    ]);
  }

  Widget _statItem(String val, String label) {
    return Column(children: [
      Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))
    ]);
  }

  // 🔥 YORUM GİRİŞ KARTI (EĞER DAHA ÖNCE YORUM YAPTIYSA GİZLENİR VEYA BİLGİ VERİR)
  Widget _buildReviewInputCard() {
    if (_hasReviewed) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Bu mağazayı değerlendirdiniz. Yorumunuzu aşağıdan düzenleyebilir veya silebilirsiniz.",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Mağazayı Değerlendir",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < userRating
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    color: trendyolOrange,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      userRating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "Görüşlerinizi yazın...",
                filled: true,
                fillColor: iosBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                    onPressed: _submitReview,
                    icon: const Icon(Icons.send, color: trendyolOrange)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 🔥 YORUMLARI LİSTELEME ALANI
  Widget _buildCommentsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('storeId', isEqualTo: storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(child: CupertinoActivityIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                  child: Text("İlk değerlendirmeyi sen yap!",
                      style: TextStyle(color: Colors.grey))),
            ),
          );
        }

        var reviews = snapshot.data!.docs.toList();
        reviews.sort((a, b) {
          Timestamp t1 =
              (a.data() as Map<String, dynamic>)['date'] ?? Timestamp.now();
          Timestamp t2 =
              (b.data() as Map<String, dynamic>)['date'] ?? Timestamp.now();
          return t2.compareTo(t1);
        });

        final mainReviews = reviews.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['parentId'] == null;
        }).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final review = mainReviews[index];
              final replies = reviews.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['parentId'] == review.id;
              }).toList();
              return _buildSingleReview(review, replies: replies);
            },
            childCount: mainReviews.length,
          ),
        );
      },
    );
  }

  // 🔥 TEKİL YORUM KARTI VE DÜZENLE/SİL AKSİYONU
  Widget _buildSingleReview(QueryDocumentSnapshot doc,
      {List<QueryDocumentSnapshot> replies = const [], bool isReply = false}) {
    var review = doc.data() as Map<String, dynamic>;
    String docId = doc.id;

    double rating = (review['rating'] ?? 5.0).toDouble();
    Timestamp? time = review['date'];
    String dateStr = time != null
        ? "${time.toDate().day}/${time.toDate().month}/${time.toDate().year}"
        : "";

    bool isMyReview = review['userId'] == currentUserId;
    final visibleName =
        CommentIdentity.visibleName(review, nameFields: const ['userName']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(visibleName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (isMyReview)
                    GestureDetector(
                      onTap: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (context) => CupertinoActionSheet(
                            actions: [
                              CupertinoActionSheetAction(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEditReviewDialog(
                                      docId, review['comment'] ?? "", rating);
                                },
                                child: const Text("Düzenle",
                                    style: TextStyle(color: Colors.blue)),
                              ),
                              CupertinoActionSheetAction(
                                isDestructiveAction: true,
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteReview(docId);
                                },
                                child: const Text("Sil"),
                              ),
                            ],
                            cancelButton: CupertinoActionSheetAction(
                              child: const Text("İptal"),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(CupertinoIcons.ellipsis,
                            color: Colors.grey, size: 20),
                      ),
                    ),
                  if (!isReply) ...[
                    const Icon(CupertinoIcons.star_fill,
                        color: trendyolOrange, size: 14),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: trendyolOrange)),
                  ],
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(review['comment'] ?? "",
              style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),
          Row(children: [
            Text(dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            if (!isReply) ...[
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _showReplyDialog(doc.id, visibleName),
                child: const Text("Yanıtla",
                    style: TextStyle(
                        color: trendyolOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...replies.map((reply) => Padding(
                  padding: const EdgeInsets.only(left: 20, top: 8),
                  child: _buildSingleReview(reply, isReply: true),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _showReplyDialog(String parentId, String replyToName) async {
    final controller = TextEditingController();
    final send = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("$replyToName kişisine yanıt"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            placeholder: "Yanıtınızı yazın",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Gönder"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (send != true || controller.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final hideName = await CommentIdentity.askHideName(context);
    if (hideName == null) return;
    final fullName = await CommentIdentity.currentUserFullName();
    await FirebaseFirestore.instance.collection('reviews').add({
      'storeId': storeId,
      'userId': user.uid,
      'userName': fullName,
      ...CommentIdentity.authorFields(fullName: fullName, hideName: hideName),
      'comment': controller.text.trim(),
      'rating': 0,
      'parentId': parentId,
      'replyToName': replyToName,
      'date': FieldValue.serverTimestamp(),
    });
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child});
  final Widget child;
  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
