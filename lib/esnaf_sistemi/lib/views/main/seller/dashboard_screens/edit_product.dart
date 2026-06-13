import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

// ManageProductsScreen ile aynı tema renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class EditProduct extends StatefulWidget {
  final DocumentSnapshot
      product; // Daha sağlam veri yönetimi için DocumentSnapshot
  const EditProduct({Key? key, required this.product}) : super(key: key);

  @override
  State<EditProduct> createState() => _EditProductState();
}

class _EditProductState extends State<EditProduct> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;
  late TextEditingController _portionController;
  late TextEditingController _sideDishesController;
  late TextEditingController _prepTimeController;

  File? _newImage;
  String? _existingImageUrl;
  bool isLoading = false;
  bool isAvailable = true;

  @override
  void initState() {
    super.initState();
    var data = widget.product.data() as Map<String, dynamic>;

    _nameController = TextEditingController(text: data['productName'] ?? "");
    _priceController =
        TextEditingController(text: data['price']?.toString() ?? "");
    _descController = TextEditingController(text: data['description'] ?? "");
    _portionController = TextEditingController(text: data['portion'] ?? "");
    _sideDishesController =
        TextEditingController(text: data['sideDishes'] ?? "");
    _prepTimeController =
        TextEditingController(text: data['prepTime']?.toString() ?? "15");

    _existingImageUrl = data['productImage'] ?? "";
    isAvailable = data['isAvailable'] ?? true;
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _newImage = File(pickedFile.path));
    }
  }

  Future<String> _uploadToFirebase(File file) async {
    String fileName =
        'products/${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}.png';
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    TaskSnapshot snapshot = await uploadPortalFile(storageRef, file);
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      String finalImageUrl = _existingImageUrl ?? "";
      if (_newImage != null) {
        finalImageUrl = await _uploadToFirebase(_newImage!);
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update({
        'productName': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'portion': _portionController.text.trim(),
        'sideDishes': _sideDishesController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'prepTime': _prepTimeController.text.trim(),
        'productImage': finalImageUrl,
        'isAvailable': isAvailable,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Ürün başarıyla güncellendi ✅"),
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Hata: $e ❌"), backgroundColor: Colors.redAccent));
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
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ürünü Düzenle',
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 🖼️ GÖRSEL SEÇİM ALANI (İphone Tarzı Köşeli)
                    _buildImageSection(),

                    const SizedBox(height: 25),

                    // ⚙️ AYARLAR GRUBU (iOS List stili)
                    _buildSettingsGroup([
                      _buildSwitchTile("Ürün Satışta mı?", isAvailable,
                          (val) => setState(() => isAvailable = val)),
                    ]),

                    const SizedBox(height: 25),

                    // 📝 BİLGİ GİRİŞ GRUBU
                    _buildSettingsGroup([
                      _buildIOSTextField(
                          _nameController, "Ürün Adı", CupertinoIcons.pencil),
                      _buildIOSTextField(_priceController, "Fiyat (₺)",
                          CupertinoIcons.money_dollar,
                          isNumber: true),
                      _buildIOSTextField(_prepTimeController,
                          "Hazırlama Süresi (Dk)", CupertinoIcons.time,
                          isNumber: true),
                    ]),

                    const SizedBox(height: 25),

                    // 🍽️ İÇERİK GRUBU
                    _buildSettingsGroup([
                      _buildIOSTextField(_portionController, "Porsiyon/Gramaj",
                          CupertinoIcons.chart_pie),
                      _buildIOSTextField(_sideDishesController,
                          "Garnitür/İçerik", CupertinoIcons.list_bullet),
                    ]),

                    const SizedBox(height: 25),

                    // 📄 AÇIKLAMA GRUBU
                    _buildSettingsGroup([
                      _buildIOSTextField(_descController, "Ürün Açıklaması",
                          CupertinoIcons.doc_text,
                          maxLines: 3),
                    ]),

                    const SizedBox(height: 40),

                    // 🚀 KAYDET BUTONU (ManageProducts stili turuncu)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: trendyolOrange,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                          onPressed: _updateProduct,
                          child: Text("Değişiklikleri Kaydet",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 10)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: _newImage != null
                    ? portalPickedImage(_newImage!, fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: _existingImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                            CupertinoIcons.photo,
                            color: Colors.black12),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: trendyolOrange, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.camera_fill,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: CupertinoSwitch(
        activeColor: trendyolOrange,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildIOSTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isNumber = false, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: iosBg, width: 0.5))),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.inter(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
          prefixIcon: Icon(icon, color: trendyolOrange, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
        validator: (v) => v!.isEmpty ? "Lütfen doldurun" : null,
      ),
    );
  }
}
