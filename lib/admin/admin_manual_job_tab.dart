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

class AdminManualJobTab extends StatefulWidget {
  const AdminManualJobTab({super.key});

  @override
  State<AdminManualJobTab> createState() => _AdminManualJobTabState();
}

class _AdminManualJobTabState extends State<AdminManualJobTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _personnelCountController = TextEditingController(text: '1');
  final _salaryController = TextEditingController();
  final _descController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];

  String? _employmentType;
  bool _isSaving = false;

  static const _primary = Color(0xFF0284C7);

  final List<String> _employmentTypes = const [
    'Tam Zamanlı',
    'Yarı Zamanlı (Part-Time)',
    'Dönemsel / Geçici',
    'Stajyer',
    'Günlük Yevmiye',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _personnelCountController.dispose();
    _salaryController.dispose();
    _descController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 75);
    if (picked.isEmpty) return;

    setState(() {
      final spaceLeft = 6 - _images.length;
      _images.addAll(picked.take(spaceLeft).map((x) => File(x.path)));
    });
  }

  Future<List<String>> _uploadImages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final urls = <String>[];

    for (var i = 0; i < _images.length; i++) {
      final fileName =
          'jobs/admin_${uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await uploadPortalFile(ref, _images[i]);
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate() || _employmentType == null) {
      _snack('Zorunlu alanları ve çalışma şeklini doldurun.', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final imageUrls = await _uploadImages();

      await FirebaseFirestore.instance.collection('job_postings').add({
        'title': _titleController.text.trim(),
        'companyName': _companyController.text.trim(),
        'personnelCount': _personnelCountController.text.trim(),
        'salary': _salaryController.text.trim(),
        'description': _descController.text.trim(),
        'employmentType': _employmentType,
        'images': imageUrls,
        'ownerId': uid,
        'createdByAdmin': true,
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'phone': _contactPhoneController.text.trim(),
        'status': 'active',
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      _snack('İş ilanı yayına alındı.', Colors.green);
    } catch (e) {
      _snack('İş ilanı eklenemedi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _companyController.clear();
    _personnelCountController.text = '1';
    _salaryController.clear();
    _descController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    setState(() {
      _employmentType = null;
      _images.clear();
    });
  }

  Future<void> _setStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('job_postings').doc(id).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteJob(String id) async {
    await FirebaseFirestore.instance.collection('job_postings').doc(id).delete();
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _header(),
        const SizedBox(height: 16),
        _formCard(),
        const SizedBox(height: 18),
        _recentJobs(),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(CupertinoIcons.briefcase_fill,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manuel İş İlanı',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Telefon kullanmayan veya ilan açamayan kişiler adına direkt yayınlayın.',
                  style: GoogleFonts.inter(
                      color: Colors.black54, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İlan Bilgileri',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _field(_titleController, 'İlan başlığı', CupertinoIcons.briefcase,
                required: true),
            _field(_companyController, 'Firma / işyeri adı',
                CupertinoIcons.building_2_fill,
                required: true),
            Row(
              children: [
                Expanded(
                  child: _field(_personnelCountController, 'Kişi sayısı',
                      CupertinoIcons.person_2_fill,
                      keyboardType: TextInputType.number, required: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_salaryController, 'Maaş (opsiyonel)',
                      CupertinoIcons.money_dollar_circle),
                ),
              ],
            ),
            _dropdown(),
            _field(_descController, 'İş tanımı ve aranan özellikler',
                CupertinoIcons.doc_text_fill,
                maxLines: 5, required: true),
            const SizedBox(height: 8),
            Text('İletişim',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _field(_contactNameController, 'Yetkili adı (opsiyonel)',
                CupertinoIcons.person_crop_circle),
            _field(_contactPhoneController, 'Manuel telefon numarası',
                CupertinoIcons.phone_fill,
                keyboardType: TextInputType.phone, required: true),
            const SizedBox(height: 8),
            _imagesPicker(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSaving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Icon(CupertinoIcons.paperplane_fill),
                label: Text(_isSaving ? 'Yayınlanıyor...' : 'İlanı Yayınla',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {bool required = false,
      int maxLines = 1,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? 'Bu alan zorunlu' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primary),
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
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _employmentType,
        decoration: InputDecoration(
          labelText: 'Çalışma şekli',
          prefixIcon: const Icon(CupertinoIcons.clock_fill, color: _primary),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: _employmentTypes
            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: (value) => setState(() => _employmentType = value),
        validator: (value) => value == null ? 'Çalışma şeklini seçin' : null,
      ),
    );
  }

  Widget _imagesPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Görseller',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              onPressed: _images.length >= 6 ? null : _pickImages,
              icon: const Icon(CupertinoIcons.photo_on_rectangle),
              label: const Text('Görsel Seç'),
            ),
          ],
        ),
        if (_images.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_images[index],
                          width: 88, height: 88, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 3,
                      top: 3,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.xmark,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _recentJobs() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('job_postings')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Son İş İlanları',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CupertinoActivityIndicator())
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Henüz iş ilanı yok.'),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data();
                  final status = data['status']?.toString() ?? 'active';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.12),
                      child: const Icon(CupertinoIcons.briefcase_fill,
                          color: _primary),
                    ),
                    title: Text(data['title']?.toString() ?? 'Başlıksız',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${data['companyName'] ?? '-'} • ${data['contactPhone'] ?? data['phone'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: status == 'active' ? 'Pasife al' : 'Aktif et',
                          onPressed: () => _setStatus(
                              doc.id, status == 'active' ? 'passive' : 'active'),
                          icon: Icon(
                            status == 'active'
                                ? CupertinoIcons.pause_circle
                                : CupertinoIcons.play_circle,
                            color: status == 'active'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sil',
                          onPressed: () => _deleteJob(doc.id),
                          icon: const Icon(CupertinoIcons.delete,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
