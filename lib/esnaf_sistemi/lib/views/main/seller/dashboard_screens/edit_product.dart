import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/utils/food_compliance.dart';
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
  late TextEditingController _calorieController;
  late TextEditingController _meatOriginController;

  File? _newImage;
  String? _existingImageUrl;
  bool isLoading = false;
  bool isAvailable = true;
  bool complianceApproved = false;
  String? selectedSuggestionName;
  List<String> selectedIngredients = [];
  List<String> selectedRemovableIngredients = [];
  List<String> selectedAddableIngredients = [];
  List<String> detectedAllergens = [];
  List<String> dietaryWarnings = [];

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
    _calorieController =
        TextEditingController(text: data['calorieText']?.toString() ?? "");
    _meatOriginController = TextEditingController(
        text: data['meatOrigin']?.toString() ?? "Türkiye");
    selectedSuggestionName = data['suggestedFoodName']?.toString();
    selectedIngredients = List<String>.from(data['ingredients'] ?? const []);
    selectedRemovableIngredients =
        List<String>.from(data['removableIngredients'] ?? const []);
    selectedAddableIngredients =
        List<String>.from(data['addableIngredients'] ?? const []);
    detectedAllergens = FoodComplianceHelper.allergensFor(selectedIngredients);
    if (data['allergens'] is List && detectedAllergens.isEmpty) {
      detectedAllergens = List<String>.from(data['allergens']);
    }
    dietaryWarnings = FoodComplianceHelper.warningsFor(
      selectedIngredients,
      suggestion:
          FoodComplianceHelper.findSuggestionByName(selectedSuggestionName),
    );
    if (data['dietaryWarnings'] is List && dietaryWarnings.isEmpty) {
      dietaryWarnings = List<String>.from(data['dietaryWarnings']);
    }

    _existingImageUrl = data['productImage'] ?? "";
    isAvailable = data['isAvailable'] ?? true;
    complianceApproved = data['complianceApprovedBySeller'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _portionController.dispose();
    _sideDishesController.dispose();
    _prepTimeController.dispose();
    _calorieController.dispose();
    _meatOriginController.dispose();
    super.dispose();
  }

  void _refreshAllergens() {
    detectedAllergens = FoodComplianceHelper.allergensFor(selectedIngredients);
    dietaryWarnings = FoodComplianceHelper.warningsFor(
      selectedIngredients,
      suggestion:
          FoodComplianceHelper.findSuggestionByName(selectedSuggestionName),
    );
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (selectedIngredients.contains(ingredient)) {
        selectedIngredients.remove(ingredient);
      } else {
        selectedIngredients.add(ingredient);
      }
      _refreshAllergens();
      complianceApproved = false;
    });
  }

  void _applySuggestion(FoodSuggestion suggestion) {
    final currentProductName = _nameController.text;
    setState(() {
      selectedSuggestionName = suggestion.name;
      selectedIngredients = List<String>.from(suggestion.ingredients);
      selectedRemovableIngredients =
          List<String>.from(suggestion.removableIngredients);
      selectedAddableIngredients =
          List<String>.from(suggestion.addableIngredients);
      _calorieController.text = suggestion.calorieText;
      _refreshAllergens();
      complianceApproved = false;
    });
    _nameController.text = currentProductName;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
  }

  void _toggleRemovableIngredient(String ingredient) {
    setState(() {
      if (selectedRemovableIngredients.contains(ingredient)) {
        selectedRemovableIngredients.remove(ingredient);
      } else {
        selectedRemovableIngredients.add(ingredient);
      }
      complianceApproved = false;
    });
  }

  void _toggleAddableIngredient(String ingredient) {
    setState(() {
      if (selectedAddableIngredients.contains(ingredient)) {
        selectedAddableIngredients.remove(ingredient);
      } else {
        selectedAddableIngredients.add(ingredient);
      }
      _refreshAllergens();
      complianceApproved = false;
    });
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
      final requiresMeatOrigin =
          FoodComplianceHelper.requiresMeatOrigin(selectedIngredients);
      if (requiresMeatOrigin && _meatOriginController.text.trim().isEmpty) {
        throw Exception('Et içeren ürünlerde et menşei zorunludur.');
      }
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
        'ingredients': selectedIngredients,
        'removableIngredients': selectedRemovableIngredients,
        'addableIngredients': selectedAddableIngredients,
        'allergens': detectedAllergens,
        'dietaryWarnings': dietaryWarnings,
        'calorieText': _calorieController.text.trim(),
        'addableIngredientCalories':
            FoodComplianceHelper.calorieMapFor(selectedAddableIngredients),
        'suggestedFoodName': selectedSuggestionName ?? '',
        'meatOrigin':
            requiresMeatOrigin ? _meatOriginController.text.trim() : '',
        'requiresMeatOrigin': requiresMeatOrigin,
        'celiacWarning': FoodComplianceHelper.celiacWarning(detectedAllergens),
        'complianceSource': 'Pazarcık Portal önerisi',
        'complianceApprovedBySeller': complianceApproved,
        'complianceApprovedAt':
            complianceApproved ? FieldValue.serverTimestamp() : null,
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
                    _buildComplianceGroup(),

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

  Widget _buildComplianceGroup() {
    final suggestions =
        FoodComplianceHelper.searchSuggestions(_nameController.text);
    final needsMeatOrigin =
        FoodComplianceHelper.requiresMeatOrigin(selectedIngredients);
    final celiacWarning = FoodComplianceHelper.celiacWarning(detectedAllergens);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_shield_fill,
                  color: Color(0xFF34C759), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Kalori, içerik ve alerjen beyanı',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSuggestionDropdown(suggestions),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FoodComplianceHelper.ingredients.map((item) {
              final selected = selectedIngredients.contains(item.name);
              return FilterChip(
                label: Text(item.name),
                selected: selected,
                selectedColor: trendyolOrange,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: iosBg,
                onSelected: (_) => _toggleIngredient(item.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildComplianceChipGroup(
            title: 'Müşteri çıkarabilir',
            values: selectedRemovableIngredients,
            color: Colors.redAccent,
            onToggle: _toggleRemovableIngredient,
          ),
          const SizedBox(height: 12),
          _buildComplianceChipGroup(
            title: 'Ekstra eklenebilir',
            values: selectedAddableIngredients,
            color: const Color(0xFF34C759),
            onToggle: _toggleAddableIngredient,
          ),
          const SizedBox(height: 12),
          _buildIOSTextField(_calorieController, 'Kalori / enerji değeri',
              CupertinoIcons.flame_fill),
          if (detectedAllergens.isNotEmpty)
            _smallWarning(
                'Alerjenler: ${detectedAllergens.join(', ')}', Colors.orange),
          if (celiacWarning.isNotEmpty)
            _smallWarning(celiacWarning, Colors.redAccent),
          if (dietaryWarnings.isNotEmpty)
            _smallWarning('Sağlık uyarıları: ${dietaryWarnings.join(' • ')}',
                Colors.purple),
          if (needsMeatOrigin)
            _buildIOSTextField(_meatOriginController, 'Et menşei / kökeni',
                CupertinoIcons.location_solid),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: complianceApproved,
            activeColor: const Color(0xFF34C759),
            onChanged: (v) => setState(() => complianceApproved = v),
            title: Text('İşletme olarak doğruluyorum',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionDropdown(List<FoodSuggestion> suggestions) {
    final shownSuggestions = List<FoodSuggestion>.from(suggestions);
    final selectedSuggestion =
        FoodComplianceHelper.findSuggestionByName(selectedSuggestionName);
    if (selectedSuggestion != null &&
        !shownSuggestions.any((item) => item.name == selectedSuggestion.name)) {
      shownSuggestions.insert(0, selectedSuggestion);
    }
    final safeValue = shownSuggestions.any(
      (item) => item.name == selectedSuggestionName,
    )
        ? selectedSuggestionName
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: iosBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          hint: Text(
            'İçerik şablonu seçin',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.black45,
              fontWeight: FontWeight.w700,
            ),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(CupertinoIcons.sparkles, color: trendyolOrange),
          ),
          items: shownSuggestions
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.name,
                  child: Text(
                    '${item.name}  •  ${item.category}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            final suggestion = FoodComplianceHelper.findSuggestionByName(value);
            if (suggestion != null) _applySuggestion(suggestion);
          },
        ),
      ),
    );
  }

  Widget _buildComplianceChipGroup({
    required String title,
    required List<String> values,
    required Color color,
    required ValueChanged<String> onToggle,
  }) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((item) {
            return FilterChip(
              selected: true,
              label: Text(item),
              selectedColor: color,
              checkmarkColor: Colors.white,
              labelStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (_) => onToggle(item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _smallWarning(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 12, color: color, fontWeight: FontWeight.w800)),
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
