// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({Key? key}) : super(key: key);

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  static const String settingsCollection = 'app_settings';
  static const String settingsDoc = 'general';

  final _formKey = GlobalKey<FormState>();

  final _appNameController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _instagramController = TextEditingController();
  final _websiteController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _androidStoreUrlController = TextEditingController();
  final _iosStoreUrlController = TextEditingController();
  final _announcementController = TextEditingController();
  final _startupTitleController = TextEditingController();
  final _startupBodyController = TextEditingController();
  final _startupMediaUrlController = TextEditingController();
  final _startupLinkUrlController = TextEditingController();

  bool _maintenanceMode = false;
  bool _forceUpdate = false;
  bool _allowNewAds = true;
  bool _allowNewOrders = true;
  bool _startupAnnouncementActive = false;
  bool _isLoading = true;
  File? _startupImageFile;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _supportPhoneController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _minVersionController.dispose();
    _androidStoreUrlController.dispose();
    _iosStoreUrlController.dispose();
    _announcementController.dispose();
    _startupTitleController.dispose();
    _startupBodyController.dispose();
    _startupMediaUrlController.dispose();
    _startupLinkUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDoc)
        .get();

    final data = doc.data() ?? {};

    _appNameController.text = (data['appName'] ?? 'Pazarcık Portal').toString();
    _supportPhoneController.text = (data['supportPhone'] ?? '').toString();
    _whatsappController.text = (data['whatsapp'] ?? '').toString();
    _instagramController.text = (data['instagram'] ?? '').toString();
    _websiteController.text = (data['website'] ?? '').toString();
    final versionDoc = await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc('version_control')
        .get();
    final versionData = versionDoc.data() ?? {};

    final startupDoc = await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc('startup_announcement')
        .get();
    final startupData = startupDoc.data() ?? {};

    _minVersionController.text =
        (versionData['min_version'] ?? data['minVersion'] ?? '').toString();
    _androidStoreUrlController.text =
        (versionData['android_url'] ?? '').toString();
    _iosStoreUrlController.text = (versionData['ios_url'] ?? '').toString();
    _announcementController.text =
        (data['globalAnnouncement'] ?? '').toString();
    _startupTitleController.text = (startupData['title'] ?? '').toString();
    _startupBodyController.text = (startupData['body'] ?? '').toString();
    _startupMediaUrlController.text =
        (startupData['mediaUrl'] ?? '').toString();
    _startupLinkUrlController.text = (startupData['linkUrl'] ?? '').toString();

    setState(() {
      _maintenanceMode = data['maintenanceMode'] == true;
      _forceUpdate =
          versionData['force_update'] == true || data['forceUpdate'] == true;
      _allowNewAds = data['allowNewAds'] != false;
      _allowNewOrders = data['allowNewOrders'] != false;
      _startupAnnouncementActive = startupData['isActive'] == true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    if (_startupImageFile != null) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('settings/startup_announcements/$fileName.jpg');
      await ref.putFile(_startupImageFile!);
      _startupMediaUrlController.text = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDoc)
        .set({
      'appName': _appNameController.text.trim(),
      'supportPhone': _supportPhoneController.text.trim(),
      'whatsapp': _whatsappController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'website': _websiteController.text.trim(),
      'minVersion': _minVersionController.text.trim(),
      'globalAnnouncement': _announcementController.text.trim(),
      'maintenanceMode': _maintenanceMode,
      'forceUpdate': _forceUpdate,
      'allowNewAds': _allowNewAds,
      'allowNewOrders': _allowNewOrders,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc('version_control')
        .set({
      'min_version': int.tryParse(_minVersionController.text.trim()) ?? 0,
      'force_update': _forceUpdate,
      'android_url': _androidStoreUrlController.text.trim(),
      'ios_url': _iosStoreUrlController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc('startup_announcement')
        .set({
      'isActive': _startupAnnouncementActive,
      'title': _startupTitleController.text.trim(),
      'body': _startupBodyController.text.trim(),
      'mediaUrl': _startupMediaUrlController.text.trim(),
      'linkUrl': _startupLinkUrlController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Ayarlar kaydedildi."),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickStartupImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() {
      _startupImageFile = File(picked.path);
    });
  }

  Future<void> _clearCacheFlags() async {
    await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDoc)
        .set({
      'cacheVersion': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cache sürümü yenilendi.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _section(
                title: "Genel Bilgiler",
                icon: CupertinoIcons.settings_solid,
                children: [
                  _field(_appNameController, "Uygulama Adı"),
                  _field(_supportPhoneController, "Destek Telefonu"),
                  _field(_whatsappController, "WhatsApp Numarası"),
                  _field(
                      _instagramController, "Instagram Linki / Kullanıcı Adı"),
                  _field(_websiteController, "Web Sitesi"),
                ],
              ),
              _section(
                title: "Uygulama Kontrolü",
                icon: CupertinoIcons.slider_horizontal_3,
                children: [
                  _switchTile(
                    "Bakım Modu",
                    "Açık olursa uygulama bakım ekranına alınabilir.",
                    _maintenanceMode,
                    (v) => setState(() => _maintenanceMode = v),
                  ),
                  _switchTile(
                    "Zorunlu Güncelleme",
                    "Minimum sürüm altındaki kullanıcıya güncelleme uyarısı verilir.",
                    _forceUpdate,
                    (v) => setState(() => _forceUpdate = v),
                  ),
                  _field(_minVersionController, "Minimum Uygulama Versiyonu"),
                  _field(
                    _androidStoreUrlController,
                    "Android güncelleme linki",
                    required: false,
                  ),
                  _field(
                    _iosStoreUrlController,
                    "iOS güncelleme linki",
                    required: false,
                  ),
                  _switchTile(
                    "Yeni İlan Açık",
                    "Kullanıcılar yeni ilan verebilsin.",
                    _allowNewAds,
                    (v) => setState(() => _allowNewAds = v),
                  ),
                  _switchTile(
                    "Yeni Sipariş Açık",
                    "Yemek / mağaza siparişleri alınabilsin.",
                    _allowNewOrders,
                    (v) => setState(() => _allowNewOrders = v),
                  ),
                ],
              ),
              _section(
                title: "Duyuru Bandı",
                icon: CupertinoIcons.speaker_2_fill,
                children: [
                  _field(
                    _announcementController,
                    "Ana ekranda gösterilecek kısa duyuru",
                    maxLines: 3,
                    required: false,
                  ),
                ],
              ),
              _section(
                title: "Açılış Duyurusu",
                icon: CupertinoIcons.app_badge_fill,
                children: [
                  _switchTile(
                    "Açılışta Göster",
                    "Aktif olursa uygulama açıldığında kullanıcıya pencere olarak çıkar.",
                    _startupAnnouncementActive,
                    (v) => setState(() => _startupAnnouncementActive = v),
                  ),
                  _field(
                    _startupTitleController,
                    "Başlık",
                    required: false,
                  ),
                  _field(
                    _startupBodyController,
                    "Metin",
                    maxLines: 4,
                    required: false,
                  ),
                  _field(
                    _startupMediaUrlController,
                    "Görsel veya video linki",
                    required: false,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _pickStartupImage,
                      icon: const Icon(CupertinoIcons.photo_on_rectangle),
                      label: Text(
                        _startupImageFile == null
                            ? "Resim Yükle"
                            : "Resim Seçildi",
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _startupLinkUrlController,
                    "Buton dış linki",
                    required: false,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(CupertinoIcons.checkmark_circle_fill),
                  label: const Text("AYARLARI KAYDET"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _clearCacheFlags,
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text("CACHE SÜRÜMÜNÜ YENİLE"),
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? "Bu alan zorunlu" : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        activeColor: const Color(0xFF6366F1),
      ),
    );
  }
}
