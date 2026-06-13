import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

class AddJobPage extends StatefulWidget {
  // 🔥 DÜZENLEME DESTEĞİ İÇİN EKLENEN PARAMETRELER
  final Map<String, dynamic>? existingJob;
  final String? docId;

  const AddJobPage({Key? key, this.existingJob, this.docId}) : super(key: key);

  @override
  State<AddJobPage> createState() => _AddJobPageState();
}

class _AddJobPageState extends State<AddJobPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _personnelCountController =
      TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  String? _selectedEmploymentType;

  bool _isLoading = true;
  bool _hasPhoneVerified = false;
  String _userRole = "customer";

  final Color jobPrimaryColor = const Color(0xFF0284C7);
  final Color darkBgColor = const Color(0xFF1C1C1E);

  final List<String> _employmentTypes = [
    "Tam Zamanlı",
    "Yarı Zamanlı (Part-Time)",
    "Dönemsel / Geçici",
    "Stajyer",
    "Günlük Yevmiye"
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
    _checkIfEditMode(); // 🔥 Düzenleme kontrolü
  }

  // 🔥 EĞER DÜZENLEME MODUNDAYSA VERİLERİ KUTULARA DOLDUR
  void _checkIfEditMode() {
    if (widget.existingJob != null) {
      _titleController.text = widget.existingJob!['title'] ?? '';
      _companyController.text = widget.existingJob!['companyName'] ?? '';
      _personnelCountController.text =
          widget.existingJob!['personnelCount'] ?? '';
      _salaryController.text = widget.existingJob!['salary'] ?? '';
      _descController.text = widget.existingJob!['description'] ?? '';
      _selectedEmploymentType = widget.existingJob!['employmentType'];
    }
  }

  Future<void> _loadUserPermissions() async {
    try {
      String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      if (uid.isEmpty) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userRole = data['role'] ?? 'customer';
          _hasPhoneVerified = data['phoneVerified'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate() || _selectedEmploymentType == null) {
      _showSnackBar("Lütfen tüm alanları doldurun ve çalışma şeklini seçin.",
          Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      List<String> imageUrls = [];

      // Fotoğraf yükleme (Eğer yeni fotoğraf seçildiyse)
      if (_selectedImages.isNotEmpty) {
        for (var image in _selectedImages) {
          String fileName =
              "jobs/${uid}_${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg";
          Reference ref = FirebaseStorage.instance.ref().child(fileName);
          await uploadPortalFile(ref, image);
          String url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
      } else if (widget.existingJob != null &&
          widget.existingJob!['images'] != null) {
        // Yeni resim seçmediyse, eski resimleri koru
        imageUrls = List<String>.from(widget.existingJob!['images']);
      }

      // Güncellenecek veya eklenecek veri paketi
      Map<String, dynamic> jobData = {
        'title': _titleController.text.trim(),
        'companyName': _companyController.text.trim(),
        'personnelCount': _personnelCountController.text.trim(),
        'salary': _salaryController.text.trim(),
        'description': _descController.text.trim(),
        'employmentType': _selectedEmploymentType,
        'images': imageUrls,
        'ownerId': uid,
        'status': 'active',
      };

      if (widget.docId != null) {
        // 🔥 GÜNCELLEME İŞLEMİ
        await FirebaseFirestore.instance
            .collection('job_postings')
            .doc(widget.docId)
            .update(jobData);
        _showSnackBar("İş ilanınız başarıyla güncellendi!", Colors.green);
      } else {
        // 🔥 YENİ İLAN EKLEME İŞLEMİ
        jobData['createdAt'] = FieldValue.serverTimestamp();
        jobData['views'] = 0;
        await FirebaseFirestore.instance
            .collection('job_postings')
            .add(jobData);
        _showSnackBar("İş ilanınız başarıyla yayına alındı!", Colors.green);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("İşlem sırasında hata oluştu.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.docId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text(isEditing ? "İlanı Düzenle" : "İş İlanı Ver",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : (!_hasPhoneVerified)
              ? _buildPhoneWarningScreen()
              : _buildJobForm(isEditing),
    );
  }

  Widget _buildJobForm(bool isEditing) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePickerSection(),
            const SizedBox(height: 25),
            const Text("İŞ DETAYLARI",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey)),
            const SizedBox(height: 10),
            _buildTextField(
                _titleController,
                "İlan Başlığı (Örn: Deneyimli Aşçı Aranıyor)",
                Icons.work_outline),
            _buildTextField(_companyController, "Firma / İşyeri Adı",
                Icons.business_outlined),
            _buildDropdown(
                "Çalışma Şekli",
                _employmentTypes,
                _selectedEmploymentType,
                (val) => setState(() => _selectedEmploymentType = val)),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(_personnelCountController,
                        "Kaç Kişi Alınacak?", Icons.people_outline,
                        isNumber: true)),
                const SizedBox(width: 15),
                Expanded(
                    child: _buildTextField(_salaryController,
                        "Maaş (Opsiyonel)", Icons.payments_outlined)),
              ],
            ),
            _buildTextField(_descController, "İş Tanımı ve Aranan Özellikler",
                Icons.description_outlined,
                maxLines: 6),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: jobPrimaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: _checkAndSubmit,
                child: Text(
                    isEditing
                        ? "DEĞİŞİKLİKLERİ KAYDET"
                        : "İLANINI ŞİMDİ YAYINLA",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("İŞYERİ FOTOĞRAFI / LOGO (Opsiyonel)",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 15),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                return _selectedImages.length < 3
                    ? GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey[300]!)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.camera,
                                    color: Colors.grey[400], size: 30),
                                const SizedBox(height: 5),
                                Text("Yeni Foto",
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            )),
                      )
                    : const SizedBox();
              }
              return Stack(
                children: [
                  Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          image: DecorationImage(
                              image: portalPickedImageProvider(
                                  _selectedImages[index]),
                              fit: BoxFit.cover))),
                  Positioned(
                      top: 5,
                      right: 18,
                      child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(
                                  CupertinoIcons.minus_circle_fill,
                                  color: Colors.red,
                                  size: 24)))),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 60);
    if (images.isNotEmpty) {
      setState(() {
        int spaceLeft = 3 - _selectedImages.length;
        _selectedImages.addAll(
            images.take(spaceLeft).map((xFile) => File(xFile.path)).toList());
      });
    }
  }

  Widget _buildDropdown(String hint, List<String> items, String? value,
      Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(hint,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 15))))
                  .toList(),
              onChanged: onChanged)),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1, bool isNumber = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (v) =>
            (v == null || v.isEmpty) && hint.contains("Maaş") == false
                ? "Zorunlu alan"
                : null,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: maxLines == 1
              ? Icon(icon, color: jobPrimaryColor, size: 20)
              : null,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.all(18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: jobPrimaryColor)),
        ),
      ),
    );
  }

  Widget _buildPhoneWarningScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.red[50], shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.phone_badge_plus,
                    size: 70, color: Colors.red)),
            const SizedBox(height: 25),
            Text("Onaylı Hesap Gerekli",
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
              "İş ilanı verebilmek için profilinizden telefon numaranızı doğrulamış olmanız gerekmektedir.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: darkBgColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.pop(context),
                child: const Text("ANLADIM, GERİ DÖN",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
