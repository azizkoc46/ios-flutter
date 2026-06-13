import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

// Proje Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class UploadProduct extends StatefulWidget {
  static const String routeName = 'UploadProduct';
  const UploadProduct({Key? key}) : super(key: key);

  @override
  State<UploadProduct> createState() => _UploadProductState();
}

class _UploadProductState extends State<UploadProduct> {
  final _formKey = GlobalKey<FormState>();

  // Temel Bilgiler
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _descController = TextEditingController();

  String? selectedCategory;
  File? _image;
  bool isLoading = false;
  bool isAvailable = true;

  // 🔥 YENİ: Seçmeli Alan Değişkenleri
  String? selectedPortion;
  List<String> selectedSides = [];

  // Porsiyon Seçenekleri
  final List<String> portionOptions = [
    "Standart / 1 Porsiyon",
    "1.5 Porsiyon",
    "Duble / 2 Porsiyon",
    "Yarım Porsiyon",
    "Büyük Boy",
    "Orta Boy",
    "Küçük Boy",
    "Adet",
    "Kilogram"
  ];

  // Çok Geniş İkram/Ekstra Seçenekleri
  final List<String> sideOptions = [
    "Salata",
    "Ezme",
    "Çiğ Köfte",
    "Patates Kızartması",
    "Lavaş",
    "Tırnak Pide",
    "Turşu",
    "Söğüş",
    "Yoğurt",
    "Haydari",
    "Közlenmiş Biber/Domates",
    "Pirinç Pilavı",
    "Bulgur Pilavı",
    "Kutu Kola",
    "Ayran",
    "Şalgam",
    "Meyve Suyu",
    "Su",
    "Tatlı İkramı"
  ];

  // Görsel Seçici
  Future _pickImage(ImageSource source) async {
    final pickedFile =
        await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Fotoğraf Ekle",
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceButton(CupertinoIcons.camera_fill, "Kamera", () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                }),
                _buildSourceButton(CupertinoIcons.photo_fill, "Galeri", () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: trendyolOrange.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: trendyolOrange),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Future<String> _uploadImageToFirebase(File image) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
    String fileName =
        'products/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    TaskSnapshot snapshot = await uploadPortalFile(storageRef, image);
    return await snapshot.ref.getDownloadURL();
  }

  _uploadProduct() async {
    if (!_formKey.currentState!.validate() ||
        _image == null ||
        selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Lütfen fotoğraf seçip zorunlu alanları doldurun."),
          backgroundColor: Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      var userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();
      String storeName = userDoc.data()?['storeName'] ?? "Pazarcık Esnafı";

      String imageUrl = await _uploadImageToFirebase(_image!);
      double parsedPrice =
          double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;

      await FirebaseFirestore.instance.collection('products').add({
        'productName': _nameController.text.trim(),
        'price': parsedPrice,
        'discount': int.tryParse(_discountController.text) ?? 0,
        'prepTime': _prepTimeController.text.trim().isEmpty
            ? "15"
            : _prepTimeController.text.trim(),
        'productImage': imageUrl,
        'categoryName': selectedCategory,
        'vendorId': uid,
        'storeName': storeName,
        'isAvailable': isAvailable,
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 5.0,
        'salesCount': 0,

        // 🔥 YENİ: Listeden seçilen veriler kaydediliyor
        'portion': selectedPortion ?? "Standart / 1 Porsiyon",
        'sideDishes': selectedSides
            .join(', '), // Listeyi metne çevirip kaydeder (Örn: Lavaş, Ayran)
        'description': _descController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Ürün Başarıyla Yayına Alındı!"),
          backgroundColor: Color(0xFF34C759),
          behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Yükleme Hatası: $e"),
          backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => isLoading = false);
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
        title: Text("Yeni Ürün Ekle",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        leading: IconButton(
            icon: const Icon(CupertinoIcons.clear_thick, color: Colors.black45),
            onPressed: () => Navigator.pop(context)),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader("ÜRÜN GÖRSELİ"),
              _buildImagePicker(),
              const SizedBox(height: 25),

              _sectionHeader("TEMEL BİLGİLER"),
              _buildInputCard([
                _buildField(_nameController, "Ürün Adı (Örn: İskender)",
                    CupertinoIcons.cube_box_fill, false),
                const Divider(height: 1, indent: 50, color: iosBg),
                _buildCategoryPicker(),
                const Divider(height: 1, indent: 50, color: iosBg),
                _buildPriceAndStatusRow(),
              ]),
              const SizedBox(height: 25),

              // 🔥 YENİ SEÇMELİ İÇERİK BÖLÜMÜ
              _sectionHeader("ÜRÜN İÇERİĞİ VE İKRAMLAR"),
              _buildInputCard([
                _buildPortionPicker(), // Porsiyon Seçici
                const Divider(height: 1, indent: 50, color: iosBg),
                _buildSidesSelector(), // İkramlar Çoklu Seçici
                const Divider(height: 1, indent: 50, color: iosBg),
                _buildField(_descController, "Genel Açıklama (İsteğe Bağlı)",
                    CupertinoIcons.text_alignleft, false,
                    maxLines: 2),
              ]),
              const SizedBox(height: 25),

              _sectionHeader("KAMPANYA & SÜRE"),
              _buildInputCard([
                Row(
                  children: [
                    Expanded(
                        child: _buildField(_discountController, "İndirim %",
                            CupertinoIcons.tag_fill, true)),
                    Container(width: 1, height: 40, color: iosBg),
                    Expanded(
                        child: _buildField(_prepTimeController, "Süre (Dk)",
                            CupertinoIcons.timer_fill, true)),
                  ],
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black45,
                letterSpacing: 0.5)),
      );

  Widget _buildInputCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
          ]),
      child: Column(children: children),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          image: _image != null
              ? DecorationImage(
                  image: portalPickedImageProvider(_image!), fit: BoxFit.cover)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)
          ],
        ),
        child: _image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.camera_viewfinder,
                      size: 50, color: trendyolOrange),
                  const SizedBox(height: 10),
                  Text("Müşterilerin iştahını açacak\nbir fotoğraf seçin",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              )
            : Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(12),
                child: const CircleAvatar(
                    backgroundColor: trendyolOrange,
                    child: Icon(CupertinoIcons.pencil,
                        color: Colors.white, size: 20)),
              ),
      ),
    );
  }

  // 🔥 PORSİYON AÇILIR MENÜSÜ (DROPDOWN)
  Widget _buildPortionPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: selectedPortion,
          hint: Text("Porsiyon / Boyut Seçin",
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600)),
          decoration: InputDecoration(
              prefixIcon: Icon(Icons.scale_rounded,
                  color: trendyolOrange.withOpacity(0.7), size: 20),
              border: InputBorder.none),
          items: portionOptions
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))))
              .toList(),
          onChanged: (v) => setState(() => selectedPortion = v),
        ),
      ),
    );
  }

  // 🔥 İKRAMLAR SEÇİCİ TETİKLEYİCİ (MODAL AÇAR)
  Widget _buildSidesSelector() {
    return ListTile(
      leading: Icon(CupertinoIcons.gift_fill,
          color: trendyolOrange.withOpacity(0.7), size: 20),
      title: Text(
        selectedSides.isEmpty
            ? "Yanında Verilenler (Lavaş, Ayran vs.)"
            : selectedSides.join(', '),
        style: GoogleFonts.inter(
            fontSize: 14,
            color: selectedSides.isEmpty ? Colors.black45 : Colors.black87,
            fontWeight:
                selectedSides.isEmpty ? FontWeight.w600 : FontWeight.w700),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 16, color: Colors.black26),
      onTap: _showSidesModal,
    );
  }

  // 🔥 İKRAMLAR ÇOKLU SEÇİM EKRANI (BOTTOM SHEET)
  void _showSidesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(25))),
              child: Column(
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("Yanında Neler Var?",
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text("Ürünle birlikte verilen ikramları seçin",
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.black45)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sideOptions.map((side) {
                          bool isSelected = selectedSides.contains(side);
                          return FilterChip(
                            label: Text(side,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87)),
                            selected: isSelected,
                            selectedColor: trendyolOrange,
                            checkmarkColor: Colors.white,
                            backgroundColor: iosBg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                    color: Colors.transparent)),
                            onSelected: (bool selected) {
                              setModalState(() {
                                if (selected) {
                                  selectedSides.add(side);
                                } else {
                                  selectedSides.remove(side);
                                }
                              });
                              // Ana ekranı da güncelle
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Seçimi Tamamla",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceAndStatusRow() {
    return Row(
      children: [
        Expanded(
            child: _buildField(_priceController, "Fiyat ₺",
                CupertinoIcons.money_dollar_circle_fill, true)),
        Container(width: 1, height: 40, color: iosBg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text("Satışta",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54)),
              const SizedBox(width: 8),
              Switch.adaptive(
                  value: isAvailable,
                  activeColor: const Color(0xFF34C759),
                  onChanged: (v) => setState(() => isAvailable = v)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildField(
      TextEditingController controller, String hint, IconData icon, bool isNum,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNum
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: Colors.black26, fontSize: 13, fontWeight: FontWeight.normal),
        prefixIcon:
            Icon(icon, color: trendyolOrange.withOpacity(0.7), size: 20),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      ),
      validator: (v) {
        if (!isNum && hint.contains("Adı") && v!.isEmpty)
          return "Ürün adı zorunludur";
        if (isNum && hint.contains("Fiyat") && v!.isEmpty)
          return "Fiyat girmelisiniz";
        return null;
      },
    );
  }

  Widget _buildCategoryPicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cateogries').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Padding(
              padding: EdgeInsets.all(16.0),
              child: CupertinoActivityIndicator());
        var items = snapshot.data!.docs
            .map((doc) => doc['categoryName'].toString())
            .toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: selectedCategory,
              hint: Text("Kategori Seçin",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600)),
              decoration: InputDecoration(
                  prefixIcon: Icon(CupertinoIcons.square_grid_2x2_fill,
                      color: trendyolOrange.withOpacity(0.7), size: 20),
                  border: InputBorder.none),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))))
                  .toList(),
              onChanged: (v) => setState(() => selectedCategory = v),
              validator: (v) => v == null ? "Kategori seçiniz" : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
      ]),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: trendyolOrange,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          onPressed: isLoading ? null : _uploadProduct,
          child: isLoading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text("ÜRÜNÜ YAYINLA",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5)),
        ),
      ),
    );
  }
}
