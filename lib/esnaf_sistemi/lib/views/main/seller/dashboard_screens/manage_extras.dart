import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Proje renklerin
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class ManageExtrasScreen extends StatefulWidget {
  const ManageExtrasScreen({Key? key}) : super(key: key);

  @override
  State<ManageExtrasScreen> createState() => _ManageExtrasScreenState();
}

class _ManageExtrasScreenState extends State<ManageExtrasScreen> {
  final firebase = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  bool _isAdding = false;

  void _addExtra() async {
    // Boşlukları temizle ve kontrol et
    String name = nameController.text.trim();
    String priceText = priceController.text.trim().replaceAll(',', '.');

    if (name.isNotEmpty && priceText.isNotEmpty) {
      setState(() => _isAdding = true);
      try {
        await firebase
            .collection('customers')
            .doc(userId)
            .collection('extras')
            .add({
          'name': name,
          'price': double.tryParse(priceText) ?? 0.0,
          'addedAt': FieldValue.serverTimestamp(),
        });

        nameController.clear();
        priceController.clear();
        FocusScope.of(context).unfocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$name başarıyla eklendi!"),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        debugPrint("Hata: $e");
      } finally {
        if (mounted) setState(() => _isAdding = false);
      }
    }
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
        title: Text("Ekstra Ürünler",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Ekleme formu (Klavye açıldığında taşmaması için Scroll eklendi)
          _buildAddForm(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                const Icon(CupertinoIcons.list_bullet,
                    size: 14, color: Colors.black45),
                const SizedBox(width: 8),
                Text("MEVCUT EKSTRALAR",
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black45,
                        letterSpacing: 0.8)),
              ],
            ),
          ),

          // Liste Alanı
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firebase
                  .collection('customers')
                  .doc(userId)
                  .collection('extras')
                  .orderBy('addedAt', descending: true)
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
                    var doc = snapshot.data!.docs[index];
                    return _buildExtraTile(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildModernInput(
                    nameController, "Ürün İsmi", CupertinoIcons.bag, false),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildModernInput(priceController, "Fiyat",
                    CupertinoIcons.money_dollar, true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: trendyolOrange, // Renk uyarlandı
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isAdding ? null : _addExtra,
            child: _isAdding
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text("LİSTEYE EKLE",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInput(
      TextEditingController c, String hint, IconData icon, bool isNum) {
    return Container(
      decoration: BoxDecoration(
        color: iosBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: c,
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
          border: InputBorder.none,
          prefixIcon: Icon(icon,
              size: 18, color: trendyolOrange), // İkon turuncu yapıldı
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildExtraTile(DocumentSnapshot doc) {
    double price = (doc['price'] ?? 0.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // ignore: deprecated_member_use
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: trendyolOrange.withOpacity(0.1),
                shape: BoxShape.circle),
            child:
                const Icon(CupertinoIcons.add, color: trendyolOrange, size: 20),
          ),
        ),
        title: Text(doc['name'],
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text("₺${price.toStringAsFixed(2)}",
            style: GoogleFonts.inter(
                color: trendyolOrange,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(CupertinoIcons.trash,
              color: Color(0xFFFF3B30), size: 20),
          onPressed: () => _confirmDelete(doc),
        ),
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Ürünü Sil?"),
        content: Text("${doc['name']} listeden kaldırılacak."),
        actions: [
          CupertinoDialogAction(
              child: const Text("Vazgeç"),
              onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () {
              firebase
                  .collection('customers')
                  .doc(userId)
                  .collection('extras')
                  .doc(doc.id)
                  .delete();
              Navigator.pop(context);
            },
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
          const Icon(CupertinoIcons.square_stack_3d_up,
              size: 60, color: Colors.black12),
          const SizedBox(height: 12),
          Text("Henüz ekstra ürün eklemediniz",
              style: GoogleFonts.inter(
                  color: Colors.black38,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
