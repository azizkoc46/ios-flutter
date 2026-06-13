// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'real_estate_auth_page.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

class AddAdPage extends StatefulWidget {
  const AddAdPage({Key? key}) : super(key: key);

  @override
  State<AddAdPage> createState() => _AddAdPageState();
}

class _AddAdPageState extends State<AddAdPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _brandModelController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  String? _selectedCategory;
  String? _selectedSubCategory;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLocating = false;

  bool _hasPhoneVerified = false;
  bool _isCorporateApproved = false;
  bool _isAdmin = false;

  String _userRole = "customer";
  String _sellerName = "";
  String _sellerPhone = "";
  List<String> _allowedCorporateCategories = [];

  GeoPoint? _adLocation;

  final Color sahibindenYellow = const Color(0xFFFFE800);
  final Color sahibindenDark = const Color(0xFF1C1C1E);
  final Color accentBlue = const Color.fromARGB(255, 10, 142, 199);

  final Map<String, List<String>> _categories = {
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
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _brandModelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? "";

      if (uid.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();

      Map<String, dynamic> data = {};
      if (userDoc.exists && userDoc.data() != null) {
        data = userDoc.data()!;
      }

      final role = (data['role'] ?? 'customer').toString();
      final corporateStatus =
          (data['corporateSellerStatus'] ?? data['sellerStatus'] ?? '')
              .toString();

      final allowedRaw =
          data['allowedCorporateCategories'] ?? data['allowedCategories'] ?? [];

      final allowedCategories = allowedRaw is List
          ? allowedRaw.map((e) => e.toString()).toList()
          : <String>[];

      setState(() {
        _userRole = role;
        _isAdmin = role == "admin" || role == "yonetici";
        _hasPhoneVerified = data['phoneVerified'] ?? false;

        _sellerName =
            (data['name'] ?? data['fullName'] ?? user?.displayName ?? '')
                .toString();
        _sellerPhone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();

        _allowedCorporateCategories = allowedCategories;

        _isCorporateApproved = _isAdmin ||
            role == "kurumsal_satici" ||
            role == "corporate_seller" ||
            role == "emlakci" ||
            corporateStatus == "approved" ||
            data['sellerApproved'] == true ||
            data['corporateSellerApproved'] == true;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Kullanıcı bilgileri alınamadı.", Colors.red);
    }
  }

  bool _isRestrictedCategory(String? category) {
    return category == "Emlak" || category == "Sıfır Ürün";
  }

  bool _canPostCategory(String? category) {
    if (!_isRestrictedCategory(category)) return true;
    if (_isAdmin) return true;

    if (category == "Emlak" && _userRole == "emlakci") return true;

    if (_isCorporateApproved) {
      if (_allowedCorporateCategories.isEmpty) return true;
      return _allowedCorporateCategories.contains(category);
    }

    return false;
  }

  String _conditionForSelectedCategory() {
    if (_selectedCategory == "Sıfır Ürün") return "new";
    if (_selectedCategory == "İkinci El") return "used";
    return "standard";
  }

  String _sellerTypeForSelectedCategory() {
    if (_isRestrictedCategory(_selectedCategory)) return "corporate";
    if (_isCorporateApproved) return "corporate";
    return "individual";
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showSnackBar("Konum izni verilmedi.", Colors.red);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _adLocation = GeoPoint(position.latitude, position.longitude);

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _addressController.text =
              "${place.street ?? ''}, ${place.subLocality ?? ''} ${place.locality ?? ''} / PAZARCIK"
                  .trim();
        });
      }

      _showSnackBar("Konum başarıyla tanımlandı.", Colors.green);
    } catch (e) {
      _showSnackBar(
          "Konum alınamadı. Konum servislerini kontrol edin.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCategory == null ||
        _selectedSubCategory == null) {
      _showSnackBar(
          "Lütfen kategori dahil tüm alanları doldurun.", Colors.orange);
      return;
    }

    if (!_hasPhoneVerified) {
      _showSnackBar(
          "İlan verebilmek için telefon doğrulaması zorunludur.", Colors.red);
      return;
    }

    if (!_canPostCategory(_selectedCategory)) {
      _showCorporateWarning(_selectedCategory!);
      return;
    }

    if (_selectedImages.isEmpty) {
      _showSnackBar("En az 1 fotoğraf eklemelisiniz.", Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isLoading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      final newAdRef =
          FirebaseFirestore.instance.collection('classified_ads').doc();
      final generatedAdId = newAdRef.id;

      final List<String> imageUrls = [];

      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = "ads/$uid/${generatedAdId}_image_$i.jpg";
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await uploadPortalFile(ref, _selectedImages[i]);
        imageUrls.add(await ref.getDownloadURL());
      }

      await newAdRef.set({
        'adId': generatedAdId,
        'title': _titleController.text.trim(),
        'price':
            double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
        'description': _descController.text.trim(),
        'address': _addressController.text.trim(),
        'lat_lang': _adLocation,
        'category': _selectedCategory,
        'subCategory': _selectedSubCategory,
        'condition': _conditionForSelectedCategory(),
        'brandModel': _brandModelController.text.trim(),
        'images': imageUrls,
        'ownerId': uid,
        'sellerId': uid,
        'sellerName': _sellerName,
        'sellerPhone': _sellerPhone,
        'sellerType': _sellerTypeForSelectedCategory(),
        'isCorporateSeller': _sellerTypeForSelectedCategory() == "corporate",
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'views': 0,
      });

      if (!mounted) return;

      _showSnackBar("İlanınız başarıyla yayına alındı.", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Yükleme başarısız oldu.", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 65);

    if (images.isEmpty) return;

    setState(() {
      final spaceLeft = 5 - _selectedImages.length;
      _selectedImages.addAll(
        images.take(spaceLeft).map((xFile) => File(xFile.path)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: sahibindenYellow,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "İlan Ver",
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && !_isSubmitting
          ? const Center(child: CupertinoActivityIndicator())
          : !_hasPhoneVerified
              ? _buildPhoneWarningScreen()
              : Stack(
                  children: [
                    _buildAdForm(),
                    if (_isSubmitting)
                      Container(
                        color: Colors.black.withOpacity(0.18),
                        child:
                            const Center(child: CupertinoActivityIndicator()),
                      ),
                  ],
                ),
    );
  }

  Widget _buildAdForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth > 700;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isTablet ? 40 : 18,
            18,
            isTablet ? 40 : 18,
            60,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 18),
                    _buildImagePickerSection(),
                    const SizedBox(height: 24),
                    _sectionTitle("Kategori Seçimi"),
                    const SizedBox(height: 10),
                    _buildDropdown(
                      "Kategori Seçin",
                      _categories.keys.toList(),
                      _selectedCategory,
                      (val) {
                        if (_isRestrictedCategory(val) &&
                            !_canPostCategory(val)) {
                          _showCorporateWarning(val!);
                          return;
                        }

                        setState(() {
                          _selectedCategory = val;
                          _selectedSubCategory = null;
                          _brandModelController.clear();
                        });
                      },
                    ),
                    if (_selectedCategory != null)
                      _buildDropdown(
                        "Alt Kategori Seçin",
                        _categories[_selectedCategory]!,
                        _selectedSubCategory,
                        (val) => setState(() => _selectedSubCategory = val),
                      ),
                    if (_isRestrictedCategory(_selectedCategory))
                      _buildCorporateNote(),
                    const SizedBox(height: 22),
                    _sectionTitle("İlan Bilgileri"),
                    const SizedBox(height: 10),
                    _buildTextField(
                      _titleController,
                      "İlan başlığı",
                      Icons.edit_note_outlined,
                    ),
                    if (_selectedCategory == "Vasıta" ||
                        _selectedCategory == "Sıfır Ürün" ||
                        _selectedCategory == "İkinci El")
                      _buildTextField(
                        _brandModelController,
                        "Marka / Model",
                        Icons.sell_outlined,
                        requiredField: false,
                      ),
                    _buildTextField(
                      _priceController,
                      "Fiyat (TL)",
                      Icons.payments_outlined,
                      isNumber: true,
                    ),
                    _buildTextField(
                      _descController,
                      "İlan açıklaması",
                      Icons.description_outlined,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle("Konum & Adres"),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _addressController,
                            "Mahalle, sokak, no...",
                            Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _isLocating ? null : _getCurrentLocation,
                          child: Container(
                            height: 56,
                            width: 56,
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: accentBlue.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: accentBlue.withOpacity(0.28),
                              ),
                            ),
                            child: _isLocating
                                ? const CupertinoActivityIndicator()
                                : Icon(Icons.my_location, color: accentBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _checkAndSubmit,
                        child: const Text(
                          "İLANINI ŞİMDİ YAYINLA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
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
      },
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: sahibindenYellow.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Sıfır Ürün ve Emlak ilanları yalnızca onaylı kurumsal satıcılar tarafından yayınlanabilir.",
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: sahibindenDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorporateNote() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withOpacity(0.20)),
      ),
      child: Row(
        children: const [
          Icon(CupertinoIcons.building_2_fill, color: Colors.green, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Bu kategori kurumsal satıcı onayı gerektirir. Hesabınız uygun olduğu için devam edebilirsiniz.",
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: Colors.grey,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("İlan Fotoğrafları"),
          const SizedBox(height: 5),
          const Text(
            "En fazla 5 fotoğraf ekleyebilirsiniz.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _selectedImages.length + 1,
              itemBuilder: (context, index) {
                if (index == _selectedImages.length) {
                  if (_selectedImages.length >= 5) return const SizedBox();
                  return _addPhotoButton();
                }

                return Stack(
                  children: [
                    Container(
                      width: 112,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        image: DecorationImage(
                          image:
                              portalPickedImageProvider(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 18,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.minus_circle_fill,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(CupertinoIcons.camera, color: Colors.grey, size: 30),
            SizedBox(height: 6),
            Text(
              "Fotoğraf Ekle",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          value: value,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 15)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool isNumber = false,
    bool requiredField = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: (v) {
          if (!requiredField) return null;
          return (v == null || v.trim().isEmpty)
              ? "Bu alan boş geçilemez"
              : null;
        },
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: accentBlue, size: 20),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accentBlue, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneWarningScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.phone_badge_plus,
                size: 70,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              "Telefon Doğrulaması Gerekli",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "İlan verebilmek için telefon numaranızı doğrulamış olmanız gerekir. Bu güvenli alışveriş için zorunludur.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 34),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sahibindenDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "PROFİLİME GİT VE DOĞRULA",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCorporateWarning(String category) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Kurumsal Satıcı Onayı Gerekli"),
        content: Text(
          "$category kategorisinde ilan yayınlamak için kurumsal satıcı başvurunuzun onaylanmış olması gerekir. Başvuru yapmak ister misiniz?",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Başvur"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const RealEstateAuthPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
