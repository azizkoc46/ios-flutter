// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';

class RealEstateAuthPage extends StatefulWidget {
  const RealEstateAuthPage({Key? key}) : super(key: key);

  @override
  State<RealEstateAuthPage> createState() => _RealEstateAuthPageState();
}

class _RealEstateAuthPageState extends State<RealEstateAuthPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final Color sahibindenYellow = const Color(0xFFFFE800);
  final Color sahibindenDark = const Color(0xFF1C1C1E);

  bool _isLoading = false;
  bool _loadingExisting = true;

  final List<String> _selectedCategories = [];

  final List<String> _availableCategories = const [
    "Emlak",
    "Sıfır Ürün",
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingUserInfo();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingUserInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      if (uid.isEmpty) {
        setState(() => _loadingExisting = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _businessNameController.text =
            (data['businessName'] ?? data['storeName'] ?? '').toString();
        _taxIdController.text = (data['taxId'] ?? '').toString();
        _phoneController.text =
            (data['officePhone'] ?? data['phoneNumber'] ?? data['phone'] ?? '')
                .toString();
        _addressController.text =
            (data['businessAddress'] ?? data['address'] ?? '').toString();

        final allowed = data['allowedCorporateCategories'];
        if (allowed is List) {
          _selectedCategories
            ..clear()
            ..addAll(allowed.map((e) => e.toString()));
        }
      }
    } catch (_) {
      // Sessiz geçiyoruz, kullanıcı formu elle doldurabilir.
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategories.isEmpty) {
      _showSnackBar(
          "En az bir başvuru kategorisi seçmelisiniz.", Colors.orange);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "";

    if (uid.isEmpty) {
      _showSnackBar("Oturum bulunamadı.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appRef = FirebaseFirestore.instance
          .collection('corporate_seller_applications')
          .doc();

      final payload = {
        'applicationId': appRef.id,
        'userId': uid,
        'email': user?.email,
        'businessName': _businessNameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'officePhone': _phoneController.text.trim(),
        'businessAddress': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'requestedCategories': _selectedCategories,
        'allowedCategories': _selectedCategories,
        'status': 'pending',
        'applicationType': 'corporate_seller',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await appRef.set(payload);

      await FirebaseFirestore.instance.collection('customers').doc(uid).set({
        'businessName': _businessNameController.text.trim(),
        'storeName': _businessNameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'officePhone': _phoneController.text.trim(),
        'businessAddress': _addressController.text.trim(),
        'corporateSellerStatus': 'pending',
        'sellerStatus': 'pending',
        'role': 'kurumsal_satici_pending',
        'applicationType': 'corporate_seller',
        'requestedCorporateCategories': _selectedCategories,
        'allowedCorporateCategories': [],
        'corporateApplicationId': appRef.id,
        'corporateSellerApproved': false,
        'sellerApproved': false,
        'applicationDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔥 YENİ EKLENEN: Admin Bildirimi
      await AdminNotificationService.instance.notifyAdmin(
        title: '📋 Sahibinden Kurumsal Başvuru',
        body: _businessNameController.text.trim(),
        type: AdminNotifType.corporateApply,
        docId: appRef.id,
      );

      if (mounted) _showSuccessDialog();
    } catch (e) {
      _showSnackBar("Başvuru gönderilemedi: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Başvuru İletildi"),
        content: const Text(
          "Kurumsal satıcı başvurunuz yönetime gönderildi. Onaylandıktan sonra seçtiğiniz kategorilerde ilan yayınlayabilirsiniz.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Tamam"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: sahibindenYellow,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: sahibindenDark),
        title: Text(
          "Kurumsal Satıcı Başvurusu",
          style: GoogleFonts.inter(
            color: sahibindenDark,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: _loadingExisting
          ? const Center(child: CupertinoActivityIndicator())
          : Stack(
              children: [
                _buildForm(),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.12),
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth > 700;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isTablet ? 40 : 18,
            18,
            isTablet ? 40 : 18,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: "Başvuru Kategorileri",
                      child: Column(
                        children: _availableCategories.map((category) {
                          final selected =
                              _selectedCategories.contains(category);
                          return _buildCategoryTile(category, selected);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "İş Yeri Bilgileri",
                      child: Column(
                        children: [
                          _buildTextField(
                            _businessNameController,
                            "İş yeri / mağaza adı",
                            Icons.business,
                          ),
                          _buildTextField(
                            _taxIdController,
                            "Vergi kimlik no",
                            Icons.receipt_long,
                            isNumber: true,
                          ),
                          _buildTextField(
                            _phoneController,
                            "İletişim numarası",
                            Icons.phone,
                            isNumber: true,
                          ),
                          _buildTextField(
                            _addressController,
                            "İş yeri adresi",
                            Icons.location_on_outlined,
                          ),
                          _buildTextField(
                            _noteController,
                            "Yönetime notunuz (opsiyonel)",
                            Icons.notes_outlined,
                            requiredField: false,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sahibindenYellow,
                          foregroundColor: sahibindenDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submitRequest,
                        child: const Text(
                          "BAŞVURUYU ONAYA GÖNDER",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
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

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sahibindenDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: sahibindenYellow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              CupertinoIcons.building_2_fill,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "Emlak ve Sıfır Ürün kategorilerinde ilan yayınlamak için kurumsal satıcı onayı gerekir.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryTile(String category, bool selected) {
    final String subtitle = category == "Emlak"
        ? "Satılık, kiralık, arsa ve iş yeri ilanları"
        : "Mağaza üzerinden sıfır ürün satışı";

    return GestureDetector(
      onTap: () => _toggleCategory(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected ? sahibindenYellow.withOpacity(0.45) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? sahibindenYellow : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: selected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: Colors.grey,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool requiredField = true,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (v) {
          if (!requiredField) return null;
          return (v == null || v.trim().isEmpty) ? "Zorunlu alan" : null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
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
            borderSide: BorderSide(color: sahibindenYellow, width: 1.4),
          ),
        ),
      ),
    );
  }
}
