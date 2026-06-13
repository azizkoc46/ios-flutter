import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Görsel performansı için
import 'edit_product.dart';
import 'manage_extras.dart';

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class ManageProductsScreen extends StatefulWidget {
  static const routeName = '/manage_products';
  const ManageProductsScreen({Key? key}) : super(key: key);

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final firebase = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Ürün Silme Fonksiyonu (iOS Tarzı Onay ile)
  void _removeProduct(String id, String title) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("$title Silinsin mi?"),
        content: const Text(
            "Bu ürünü sildiğinizde müşteriler artık sipariş veremez. Bu işlem geri alınamaz."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await firebase.collection('products').doc(id).delete();
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Ürün başarıyla silindi"),
                  behavior: SnackBarBehavior.floating));
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ürünlerimi Yönet',
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🚀 EKSTRA YÖNETİMİ BUTONU (Turuncu Modern Tasarım)
            _buildExtrasManagerButton(),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Kayıtlı Ürünlerim",
                      style: GoogleFonts.inter(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                  const Icon(CupertinoIcons.slider_horizontal_3,
                      color: Colors.black45),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firebase
                    .collection('products')
                    .where('vendorId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var item = snapshot.data!.docs[index];
                      return _buildProductCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtrasManagerButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ManageExtrasScreen())),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [trendyolOrange, Color(0xFFFF9500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  // ignore: deprecated_member_use
                  color: trendyolOrange.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.sparkles,
                  color: Colors.white, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Yanında İyi Giderleri Yönet",
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text("Sos, Lavaş, Ayran gibi ek özellikleri düzenleyin",
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String title = data['productName'] ?? 'İsimsiz Ürün';
    double price = (data['price'] ?? 0.0).toDouble();
    String imgUrl = data['productImage'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          // 🖼️ FIREBASE STORAGE GÖRSELİ (Cached)
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: imgUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    width: 75,
                    height: 75,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                        color: iosBg,
                        child: const CupertinoActivityIndicator()),
                    errorWidget: (c, u, e) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey),
                  )
                : Container(
                    width: 75,
                    height: 75,
                    color: iosBg,
                    child: const Icon(CupertinoIcons.photo,
                        color: Colors.black12)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black87)),
                const SizedBox(height: 5),
                Text("₺${price.toStringAsFixed(2)}",
                    style: GoogleFonts.inter(
                        color: trendyolOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ],
            ),
          ),
          // --- İŞLEM BUTONLARI ---
          Row(
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.pencil_circle_fill,
                    color: Color(0xFF007AFF), size: 30),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditProduct(product: doc))),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.trash_circle_fill,
                    color: Color(0xFFFF3B30), size: 30),
                onPressed: () => _removeProduct(doc.id, title),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.archivebox,
              size: 80, color: Colors.black12),
          const SizedBox(height: 15),
          Text("Henüz ürün eklememişsiniz",
              style: GoogleFonts.inter(
                  color: Colors.black45, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
