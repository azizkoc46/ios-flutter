import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

import 'package:pazarcik_portal/esnaf_sistemi/lib/models/cart.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/store/store_details.dart';
import '../../../providers/cart.dart';
import '../customer/cart.dart';
import '../../../utils/store_availability.dart';

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({Key? key, required this.product}) : super(key: key);
  final dynamic product;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool isFav = false;
  DocumentSnapshot? store;
  int quantity = 1;

  // Ekstralar için state yönetimi
  Map<String, int> selectedExtras = {};
  double extrasTotalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
    _checkFavStatus();
  }

  // Favori durumunu kontrol et
  void _checkFavStatus() {
    var data = widget.product.data() as Map<String, dynamic>? ?? {};
    setState(() => isFav = data['isFav'] ?? false);
  }

  // Favori durumunu değiştir
  void toggleIsFav() {
    final db = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id);
    setState(() {
      isFav = !isFav;
      db.update({'isFav': isFav});
    });
    HapticFeedback.mediumImpact(); // Titreşim desteği
  }

  // Mağaza verilerini çek
  _fetchStoreData() async {
    var data = widget.product.data() as Map<String, dynamic>? ?? {};
    var vendorId = data['vendorId'] ?? data['seller_id'] ?? '';
    if (vendorId.isNotEmpty) {
      var details = await FirebaseFirestore.instance
          .collection('customers')
          .doc(vendorId)
          .get();
      if (mounted) setState(() => store = details);
    }
  }

  @override
  Widget build(BuildContext context) {
    var cartData = Provider.of<CartData>(context);
    var userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    var data = widget.product.data() as Map<String, dynamic>? ?? {};

    // Veri Atamaları
    String title = data['productName'] ?? data['title'] ?? 'İsimsiz Ürün';
    double originalPrice = double.tryParse(data['price'].toString()) ?? 0.0;
    int discount = data['discount'] ?? 0;
    double currentPrice = discount > 0
        ? originalPrice - (originalPrice * discount / 100)
        : originalPrice;
    String desc =
        data['description'] ?? 'Ürün hakkında detaylı bilgi bulunmuyor.';
    String prepTime = data['prepTime']?.toString() ?? '20';
    String imageUrl = data['productImage'] ?? 'https://via.placeholder.com/400';
    String vendorId = data['vendorId'] ?? data['seller_id'] ?? 'unknown';
    final storeOpen = store != null &&
        StoreAvailability.isOpen(
            store!.data() as Map<String, dynamic>? ?? const {});

    // Toplam Fiyat (Ürün x Adet + Ekstralar)
    double finalTotalPrice = (currentPrice * quantity) + extrasTotalPrice;

    // 🔥 SEPETE EKLEME MANTIĞI 🔥
    void handleCartAction() {
      if (!storeOpen) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Restoran şu anda kapalı. Çalışma saatleri içinde tekrar deneyin."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      // 1. Ana Ürünü Ekle
      cartData.addToCart(CartItem(
        id: widget.product.id,
        docId: widget.product.id,
        prodId: widget.product.id,
        userId: userId,
        sellerId: vendorId,
        prodName: title,
        prodPrice: currentPrice,
        prodImgUrl: imageUrl,
        totalPrice: currentPrice * quantity,
        quantity: quantity,
      ));

      // 2. Seçili Ekstraları Ekle (Ayrı kalemler olarak)
      selectedExtras.forEach((extraId, qty) {
        if (qty > 0) {
          // Ekstranın bilgilerini (isim ve fiyat) o anki Stream verisinden alıyoruz
          // Basitleştirmek için burada genel bir isim kullanabilirsin veya
          // extras listesini state'de tutabilirsin.
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$title sepete eklendi!"),
          backgroundColor: trendyolOrange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: "SEPETE GİT",
            textColor: Colors.white,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const CartScreen())),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar:
          _buildBottomBar(finalTotalPrice, handleCartAction, storeOpen),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(imageUrl, widget.product.id),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                          title, currentPrice, originalPrice, discount),
                      const SizedBox(height: 20),
                      _buildInfoBadges(prepTime, data['salesCount'] ?? 25,
                          data['rating'] ?? 4.8),
                      const Divider(height: 40, thickness: 0.5, color: iosBg),
                      _buildSectionTitle("Ürün Açıklaması"),
                      const SizedBox(height: 10),
                      Text(desc,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.6)),
                      const SizedBox(height: 25),

                      // 🔥 ADET SEÇİCİ 🔥
                      _buildMainQuantitySelector(),

                      const SizedBox(height: 30),

                      // 🔥 YANINDA İYİ GİDER (EKSTRALAR) 🔥
                      _buildExtrasSection(vendorId),

                      const SizedBox(height: 25),
                      _buildStoreCard(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      String title, double curPrice, double oldPrice, int disc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w800))),
            if (disc > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(8)),
                child: Text("-%$disc",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text("₺${curPrice.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: trendyolOrange)),
            const SizedBox(width: 10),
            if (disc > 0)
              Text("₺${oldPrice.toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoBadges(String time, int sales, double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _badge(CupertinoIcons.star_fill, "$rating", Colors.amber),
        _badge(CupertinoIcons.stopwatch, "$time dk", Colors.blueAccent),
        _badge(CupertinoIcons.flame_fill, "$sales+ Satış", Colors.orange),
      ],
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.inter(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87));
  }

  Widget _buildMainQuantitySelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration:
          BoxDecoration(color: iosBg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Ürün Adedi",
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          Row(
            children: [
              _qtyBtn(CupertinoIcons.minus, () {
                if (quantity > 1) setState(() => quantity--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text("$quantity",
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              _qtyBtn(CupertinoIcons.plus, () => setState(() => quantity++)),
            ],
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              // ignore: deprecated_member_use
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
            ]),
        child: Icon(icon, size: 18, color: trendyolOrange),
      ),
    );
  }

  Widget _buildExtrasSection(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(vendorId)
          .collection('extras')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox();
        var extras = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Yanında İyi Gider"),
            const SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: extras.length,
              itemBuilder: (context, index) {
                var extra = extras[index];
                String eId = extra.id;
                double ePrice = (extra['price'] ?? 0).toDouble();
                int currentQty = selectedExtras[eId] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: currentQty > 0
                        // ignore: deprecated_member_use
                        ? trendyolOrange.withOpacity(0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: currentQty > 0 ? trendyolOrange : iosBg,
                        width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.add_circled,
                          color: trendyolOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(extra['name'],
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                            Text("+₺${ePrice.toStringAsFixed(2)}",
                                style: GoogleFonts.inter(
                                    color: trendyolOrange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (currentQty > 0)
                            _qtyBtn(CupertinoIcons.minus, () {
                              setState(() {
                                selectedExtras[eId] = currentQty - 1;
                                extrasTotalPrice -= ePrice;
                              });
                            }),
                          if (currentQty > 0)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text("$currentQty",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800)),
                            ),
                          _qtyBtn(CupertinoIcons.plus, () {
                            setState(() {
                              selectedExtras[eId] = currentQty + 1;
                              extrasTotalPrice += ePrice;
                            });
                          }),
                        ],
                      )
                    ],
                  ),
                );
              },
            )
          ],
        );
      },
    );
  }

  Widget _buildStoreCard() {
    return GestureDetector(
      onTap: () {
        if (store != null)
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => StoreDetails(store: store)));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: iosBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const CircleAvatar(
                backgroundColor: trendyolOrange,
                child: Icon(Icons.storefront, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Satan Esnaf",
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(store?.get('storeName') ?? "Yükleniyor...",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(String url, String id) {
    return SliverAppBar(
      expandedHeight: MediaQuery.sizeOf(context).width > 700 ? 300 : 350,
      pinned: true,
      backgroundColor: trendyolOrange,
      elevation: 0,
      leading: IconButton(
        icon: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(CupertinoIcons.back, color: Colors.black, size: 20)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                  isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: Colors.red)),
          onPressed: toggleIsFav,
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: id,
          child: PortalNetworkImage(url: url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildBottomBar(double total, VoidCallback onAdd, bool storeOpen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5))
      ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Toplam Tutar",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("₺${total.toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: trendyolOrange)),
            ],
          ),
          SizedBox(
            height: 55,
            width: 170,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: trendyolOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0),
              onPressed: storeOpen ? onAdd : null,
              icon: const Icon(CupertinoIcons.cart_badge_plus,
                  color: Colors.white),
              label: Text(storeOpen ? "SEPETE EKLE" : "RESTORAN KAPALI",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          )
        ],
      ),
    );
  }
}
