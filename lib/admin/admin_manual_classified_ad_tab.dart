// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

class AdminManualClassifiedAdTab extends StatefulWidget {
  const AdminManualClassifiedAdTab({super.key});

  @override
  State<AdminManualClassifiedAdTab> createState() =>
      _AdminManualClassifiedAdTabState();
}

class _AdminManualClassifiedAdTabState
    extends State<AdminManualClassifiedAdTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _brandModelController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _sellerPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];

  String? _category;
  String? _subCategory;
  bool _isSaving = false;

  static const _primary = Color(0xFF6366F1);

  final Map<String, List<String>> _categories = const {
    "Sıfır Ürün": [
      "Cep Telefonu",
      "Bilgisayar",
      "Beyaz Eşya",
      "Elektronik",
      "Ev & Yaşam",
      "Giyim",
      "Kozmetik",
      "Anne & Bebek",
      "Spor & Outdoor",
      "Diğer",
    ],
    "İkinci El": [
      "Cep Telefonu",
      "Bilgisayar",
      "Beyaz Eşya",
      "Ev Eşyaları",
      "Elektronik",
      "Giyim",
      "Mobilya",
      "Hobi & Oyuncak",
      "Diğer",
    ],
    "Emlak": [
      "Satılık",
      "Kiralık",
      "Arsa",
      "İş Yeri",
      "Devren",
      "Günlük Kiralık",
    ],
    "Vasıta": [
      "Otomobil",
      "Motosiklet",
      "Traktör",
      "Ticari Araç",
      "Kamyonet",
      "Diğer",
    ],
    "Tarım": [
      "Traktör",
      "Tarım Aletleri",
      "İş Makinesi",
      "Hayvan",
      "Yem & Ürün",
      "Diğer",
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _brandModelController.dispose();
    _sellerNameController.dispose();
    _sellerPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    if (picked.isEmpty) return;

    setState(() {
      final spaceLeft = 8 - _images.length;
      _images.addAll(picked.take(spaceLeft).map((x) => File(x.path)));
    });
  }

  Future<void> _saveAd() async {
    if (!_formKey.currentState!.validate() ||
        _category == null ||
        _subCategory == null) {
      _snack("Kategori dahil zorunlu alanları doldurun.", Colors.orange);
      return;
    }

    if (_images.isEmpty) {
      _snack("En az 1 fotoğraf ekleyin.", Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final adRef =
          FirebaseFirestore.instance.collection('classified_ads').doc();
      final adId = adRef.id;
      final sellerPhone = _sellerPhoneController.text.trim();
      final sellerKey = sellerPhone.replaceAll(RegExp(r'\D'), '');
      final sellerId = sellerKey.isEmpty ? 'admin_manual' : 'manual_$sellerKey';

      final imageUrls = <String>[];
      for (var i = 0; i < _images.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('ads/admin_manual/$adId/image_$i.jpg');
        await uploadPortalFile(ref, _images[i]);
        imageUrls.add(await ref.getDownloadURL());
      }

      await adRef.set({
        'adId': adId,
        'title': _titleController.text.trim(),
        'price':
            double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
        'description': _descController.text.trim(),
        'address': _addressController.text.trim(),
        'lat_lang': null,
        'category': _category,
        'subCategory': _subCategory,
        'condition': _category == 'Sıfır Ürün'
            ? 'new'
            : _category == 'İkinci El'
                ? 'used'
                : 'standard',
        'brandModel': _brandModelController.text.trim(),
        'images': imageUrls,
        'ownerId': sellerId,
        'sellerId': sellerId,
        'sellerName': _sellerNameController.text.trim(),
        'sellerPhone': sellerPhone,
        'sellerType': 'admin_manual',
        'isCorporateSeller': false,
        'createdByAdmin': true,
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'isActive': true,
        'views': 0,
      });

      _clearForm();
      _snack("İlan yayına alındı.", Colors.green);
    } catch (e) {
      _snack("İlan kaydedilemedi: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _priceController.clear();
    _descController.clear();
    _brandModelController.clear();
    _sellerNameController.clear();
    _sellerPhoneController.clear();
    _addressController.clear();
    setState(() {
      _category = null;
      _subCategory = null;
      _images.clear();
    });
  }

  void _snack(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subCategories = _category == null ? <String>[] : _categories[_category]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 16),
                _section(
                  title: "Satıcı Bilgileri",
                  children: [
                    _field(_sellerNameController, "Satıcı adı", Icons.person),
                    _field(_sellerPhoneController, "Telefon numarası",
                        Icons.phone,
                        keyboardType: TextInputType.phone),
                    _field(_addressController, "Adres", Icons.place,
                        maxLines: 2, required: false),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: "İlan Bilgileri",
                  children: [
                    _field(_titleController, "İlan başlığı", Icons.title),
                    Row(
                      children: [
                        Expanded(child: _categoryDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: _subCategoryDropdown(subCategories)),
                      ],
                    ),
                    _field(_priceController, "Fiyat", Icons.payments,
                        keyboardType: TextInputType.number),
                    _field(_brandModelController, "Marka / model",
                        Icons.sell_outlined,
                        required: false),
                    _field(_descController, "Açıklama", Icons.description,
                        maxLines: 5),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: "Fotoğraflar",
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._images.asMap().entries.map(
                              (entry) => _imageTile(entry.key, entry.value),
                            ),
                        _addImageTile(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAd,
                    icon: _isSaving
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isSaving ? "Kaydediliyor..." : "Yayına Al"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_business, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Manuel Sahibinden İlanı",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Kayıt açamayan kullanıcılar adına ilanı direkt yayınlayın.",
                  style: GoogleFonts.inter(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 12),
          ...children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              )),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? "Zorunlu alan" : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _category,
      items: _categories.keys
          .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
          .toList(),
      validator: (v) => v == null ? "Kategori seçin" : null,
      onChanged: (value) {
        setState(() {
          _category = value;
          _subCategory = null;
        });
      },
      decoration: _dropdownDecoration("Kategori", Icons.category),
    );
  }

  Widget _subCategoryDropdown(List<String> values) {
    return DropdownButtonFormField<String>(
      value: _subCategory,
      items: values
          .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
          .toList(),
      validator: (v) => v == null ? "Alt kategori seçin" : null,
      onChanged: _category == null
          ? null
          : (value) => setState(() => _subCategory = value),
      decoration: _dropdownDecoration("Alt kategori", Icons.tune),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
    );
  }

  Widget _addImageTile() {
    return InkWell(
      onTap: _pickImages,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withOpacity(0.25)),
        ),
        child: const Icon(Icons.add_photo_alternate, color: _primary),
      ),
    );
  }

  Widget _imageTile(int index, File image) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: portalPickedImage(
            image,
            width: 92,
            height: 92,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: InkWell(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
