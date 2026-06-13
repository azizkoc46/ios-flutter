import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart'; // iOS İkonları için
import 'package:flutter/material.dart' hide Badge;
import 'package:google_fonts/google_fonts.dart'; // Fontlar için
import 'package:provider/provider.dart';
import '../../../models/cart.dart';
import '../../../providers/cart.dart';
import '../product/details.dart';

// Modern Renk Paleti
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBackground = Color(0xFFF2F2F7);

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final Query _favQuery = FirebaseFirestore.instance
      .collection('products')
      .where('isFav', isEqualTo: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.8),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Favorilerim",
          style: GoogleFonts.inter(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _favQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyFavs();
          }

          var favProducts = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 100),
            physics: const BouncingScrollPhysics(), // iOS Kaydırma Hissi
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.70,
            ),
            itemCount: favProducts.length,
            itemBuilder: (context, index) {
              var prodDoc = favProducts[index];
              return _buildFavoriteCard(prodDoc);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(DocumentSnapshot doc) {
    var prod = doc.data() as Map<String, dynamic>;
    var cartData = Provider.of<CartData>(context, listen: false);
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    String title = prod['productName'] ?? 'İsimsiz';
    String imgUrl = prod['productImage'] ?? '';
    double price = (prod['price'] ?? 0).toDouble();
    int discount = prod['discount'] ?? 0;
    double currentPrice =
        discount > 0 ? price - (price * discount / 100) : price;
    double rating = (prod['rating'] ?? 5.0).toDouble();

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (context) => DetailsScreen(product: doc))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Kısım: Resim ve Kalp
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[100],
                            child: const Icon(CupertinoIcons.photo)),
                      ),
                    ),
                  ),
                  // Favoriden Kaldır Butonu (Sağ Üst)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => doc.reference.update({'isFav': false}),
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.heart_fill,
                                color: Colors.red, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text("-%$discount",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            // Alt Kısım: Detaylar
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.star_fill,
                                color: Color(0xFFFFCC00), size: 12),
                            Text(" $rating",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (discount > 0)
                              Text("₺${price.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey)),
                            Text("₺${currentPrice.toStringAsFixed(1)}",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: trendyolOrange)),
                          ],
                        ),
                        // Sepete Ekle
                        GestureDetector(
                          onTap: () {
                            cartData.addToCart(CartItem(
                                id: doc.id,
                                docId: doc.id,
                                prodId: doc.id,
                                userId: currentUserId,
                                sellerId: prod['vendorId'],
                                prodName: title,
                                prodPrice: currentPrice,
                                prodImgUrl: imgUrl,
                                totalPrice: currentPrice,
                                quantity: 1));

                            // iOS Stili Başarılı Bildirimi
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("$title sepete eklendi"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              duration: const Duration(seconds: 1),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: trendyolOrange,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: trendyolOrange.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4))
                                ]),
                            child: const Icon(CupertinoIcons.add,
                                color: Colors.white, size: 20),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFavs() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 30)
                ]),
            child: Icon(CupertinoIcons.heart_slash,
                size: 80, color: Colors.grey[300]),
          ),
          const SizedBox(height: 30),
          Text("Favori Listen Boş",
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          const Text("Sevdiğin ürünleri kalple, burada saklayalım.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
