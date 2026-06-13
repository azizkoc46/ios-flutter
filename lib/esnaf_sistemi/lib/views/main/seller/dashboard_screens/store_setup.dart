// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

// Tema Renkleri (Proje standartlarına uygun)
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class StoreSetupScreen extends StatefulWidget {
  static const routeName = '/store_setup';
  const StoreSetupScreen({Key? key}) : super(key: key);

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final _storeDescController = TextEditingController();
  final _prepTimeController = TextEditingController();

  TimeOfDay _openTime = const TimeOfDay(hour: 08, minute: 00);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 00);
  bool _manualOpen = true;
  bool _isLoading = false;
  File? _storeImage;
  String? _existingImageUrl;

  final List<String> _workingDays = [
    "Pzt",
    "Sal",
    "Çar",
    "Per",
    "Cum",
    "Cmt",
    "Paz"
  ];
  List<String> _selectedDays = [];
  List<Map<String, dynamic>> _deliveryZones = [];

  // Pazarcık Mahalleleri Listesi (Alfabetik)
  final List<String> _pazarcikMahalleleri = [
    "Ahmet Bozdağ Mahallesi",
    "Akçakoyunlu Mahallesi",
    "Akçalar Mahallesi",
    "Akdemir Mahallesi",
    "Armutlu Mahallesi",
    "Aşağımülk Mahallesi",
    "Bağdınısağır Mahallesi",
    "Beşçeşme Mahallesi",
    "Bölükçam Mahallesi",
    "Büyüknacar Fatih Mahallesi",
    "Büyüknacar Kocadere Mahallesi",
    "Büyüknacar Merkez Mahallesi",
    "Cengiztopel Mahallesi",
    "Cimikanlı Mahallesi",
    "Camlıca Mahallesi",
    "Çamlıtepe Mahallesi",
    "Çiçek Mahallesi",
    "Çiçekalanı Mahallesi",
    "Çiğdemtepe Mahallesi",
    "Çöçelli Mahallesi",
    "Damlataş Mahallesi",
    "Dedepaşa Mahallesi",
    "Eğlen Mahallesi",
    "Eğrice Mahallesi",
    "Emiroğlu Mahallesi",
    "Evri Pınarbaşı Mahallesi",
    "Evri Taşbiçme Mahallesi",
    "Fatih Mahallesi",
    "Ganidağıketiler Mahallesi",
    "Göçer Mahallesi",
    "Göynük Mahallesi",
    "Hanobası Mahallesi",
    "Harmancık Mahallesi",
    "Hasankoca Mahallesi",
    "Hürriyet Mahallesi",
    "İncirli Mahallesi",
    "Kadıncık Mahallesi",
    "Karaağaç Mahallesi",
    "Karabıyıklı Mahallesi",
    "Karaçay Mahallesi",
    "Karagöl Mahallesi",
    "Karahüyük Mahallesi",
    "Keleş Mahallesi",
    "Kızkapanlı Mahallesi",
    "Kizirli Mahallesi",
    "Kuzeykent Mahallesi",
    "Mehmet Emin Arıkoğlu Mahallesi",
    "Memiş Özdal Mahallesi",
    "Memişkahya Mahallesi",
    "Menderes Mahallesi",
    "Mezere Mahallesi",
    "Musolar Mahallesi",
    "Narlı Bahçeli Evler Mahallesi",
    "Narlı İsmetpaşa Mahallesi",
    "Narlı Cumhuriyet Mahallesi",
    "Nefsidoğanlı Mahallesi",
    "Osmandede Mahallesi",
    "Ördekdede Mahallesi",
    "Sadakalar Mahallesi",
    "Sakarkaya Mahallesi",
    "Şallıuşağı Mahallesi",
    "Salmanıpak Mahallesi",
    "Salmanlı Mahallesi",
    "Sarıerik Mahallesi",
    "Sarıl Mahallesi",
    "Soku Mahallesi",
    "Sultanlar Mahallesi",
    "Şahintepe Mahallesi",
    "Şehit Nurettin Ademoğlu Mahallesi",
    "Taşdemir Mahallesi",
    "Tetirlik Mahallesi",
    "Tilkiler Mahallesi",
    "Turunçul Mahallesi",
    "Ufacıklı Mahallesi",
    "Ulubahçe Mahallesi",
    "Yarbaşı Mahallesi",
    "Yeşilkent Mahallesi",
    "Yiğitler Mahallesi",
    "Yolboyu Mahallesi",
    "Yukarıhöcüklü Mahallesi",
    "Yukarımülk Mahallesi",
    "Yumaklıcerit Bağlar Mahallesi",
    "Yumaklıcerit Cumhuriyet Mahallesi",
    "15 Temmuz Mahallesi"
  ]..sort();

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    setState(() => _isLoading = true);
    try {
      var doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _storeDescController.text = data['storeDesc'] ?? "";
          _prepTimeController.text = (data['avgPrepTime'] ?? "30").toString();
          _manualOpen = data['isStoreOpen'] ?? true;
          _existingImageUrl = data['storeCoverImage'];
          _selectedDays = List<String>.from(data['workingDays'] ?? []);
          _deliveryZones =
              List<Map<String, dynamic>>.from(data['deliveryZones'] ?? []);

          if (data['openTime'] != null) {
            final parts = data['openTime'].split(':');
            _openTime = TimeOfDay(
                hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (data['closeTime'] != null) {
            final parts = data['closeTime'].split(':');
            _closeTime = TimeOfDay(
                hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        });
      }
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<String> _uploadImage(File file) async {
    String fileName =
        'store_covers/${userId}_${DateTime.now().millisecondsSinceEpoch}.png';
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    TaskSnapshot snapshot = await uploadPortalFile(storageRef, file);
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      String finalImageUrl = _existingImageUrl ?? "";

      if (_storeImage != null) {
        finalImageUrl = await _uploadImage(_storeImage!);
      }

      // 🔥 SAAT VE DAKİKALARI SOLA SIFIR EKLEYEREK GÜVENLİ FORMATLADIK (08:00 ÖRNEĞİ)
      final openHourStr = _openTime.hour.toString().padLeft(2, '0');
      final openMinuteStr = _openTime.minute.toString().padLeft(2, '0');
      final closeHourStr = _closeTime.hour.toString().padLeft(2, '0');
      final closeMinuteStr = _closeTime.minute.toString().padLeft(2, '0');

      await FirebaseFirestore.instance.collection('customers').doc(userId).set({
        'storeCoverImage': finalImageUrl,
        'storeDesc': _storeDescController.text.trim(),
        'avgPrepTime': int.tryParse(_prepTimeController.text) ?? 30,
        'isStoreOpen': _manualOpen,
        'workingDays': _selectedDays,
        'openTime':
            "$openHourStr:$openMinuteStr", // Artık "08:00" olarak kaydolur
        'closeTime':
            "$closeHourStr:$closeMinuteStr", // Artık "22:00" olarak kaydolur
        'deliveryZones': _deliveryZones,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Ayarlar Başarıyla Güncellendi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Hata: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Dükkan Ayarları",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("MAĞAZA KAPAK GÖRSELİ"),
                  _buildCoverSection(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("DÜKKAN DURUMU"),
                  _buildStatusTile(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("ÇALIŞMA GÜNLERİ"),
                  _buildDaysPicker(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("ÇALIŞMA SAATLERİ"),
                  _buildTimeSection(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("HİZMET BÖLGELERİ & ÜCRETLER"),
                  _buildZonesList(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("DÜKKAN DETAYLARI"),
                  _buildModernInput(
                      _prepTimeController,
                      "Ortalama Hazırlanma Süresi (Dakika)",
                      CupertinoIcons.stopwatch,
                      true),
                  const SizedBox(height: 12),
                  _buildModernInput(_storeDescController,
                      "Dükkan Tanıtım Yazısı", CupertinoIcons.doc_text, false,
                      maxLines: 4),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 10, bottom: 8),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black45,
                letterSpacing: 0.5)),
      );

  Widget _buildCoverSection() {
    return GestureDetector(
      onTap: () async {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 70);
        if (picked != null) setState(() => _storeImage = File(picked.path));
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
          image: _storeImage != null
              ? DecorationImage(
                  image: portalPickedImageProvider(_storeImage!),
                  fit: BoxFit.cover)
              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(_existingImageUrl!),
                      fit: BoxFit.cover)
                  : null,
        ),
        child: Stack(
          children: [
            if (_storeImage == null &&
                (_existingImageUrl == null || _existingImageUrl!.isEmpty))
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.camera_fill,
                        color: Colors.black26, size: 40),
                    SizedBox(height: 8),
                    Text("Kapak Fotoğrafı Ekle",
                        style: TextStyle(
                            color: Colors.black26,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Positioned(
              bottom: 12,
              right: 12,
              child: CircleAvatar(
                backgroundColor: trendyolOrange,
                radius: 18,
                child: const Icon(CupertinoIcons.pencil,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile.adaptive(
        value: _manualOpen,
        activeColor: const Color(0xFF34C759),
        title: Text(_manualOpen ? "Dükkan Şuan Açık" : "Dükkan Şuan Kapalı",
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        subtitle: Text(
            _manualOpen
                ? "Müşteriler sipariş verebilir"
                : "Müşteriler kapalı olduğunuzu görecek",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        onChanged: (v) => setState(() => _manualOpen = v),
      ),
    );
  }

  Widget _buildDaysPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _workingDays.map((day) {
          bool isSelected = _selectedDays.contains(day);
          return FilterChip(
            label: Text(day,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87)),
            selected: isSelected,
            onSelected: (v) => setState(
                () => v ? _selectedDays.add(day) : _selectedDays.remove(day)),
            selectedColor: trendyolOrange,
            checkmarkColor: Colors.white,
            backgroundColor: iosBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _timeSelector(
              "Açılış Saati", _openTime, (t) => setState(() => _openTime = t)),
          Container(height: 40, width: 1, color: iosBg),
          _timeSelector("Kapanış Saati", _closeTime,
              (t) => setState(() => _closeTime = t)),
        ],
      ),
    );
  }

  Widget _timeSelector(
      String label, TimeOfDay time, Function(TimeOfDay) onPick) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPick(t);
      },
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black45,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(time.format(context),
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: trendyolOrange)),
        ],
      ),
    );
  }

  Widget _buildZonesList() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ..._deliveryZones.asMap().entries.map((e) => ListTile(
                title: Text(e.value['neighborhood'],
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "Min: ₺${e.value['minOrder']} | Kurye: ₺${e.value['deliveryFee']}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: IconButton(
                    icon: const Icon(CupertinoIcons.minus_circle_fill,
                        color: Colors.red, size: 22),
                    onPressed: () =>
                        setState(() => _deliveryZones.removeAt(e.key))),
              )),
          ListTile(
            onTap: _addZoneModal,
            leading: const Icon(CupertinoIcons.add_circled_solid,
                color: Color(0xFF007AFF)),
            title: const Text("Hizmet Bölgesi Ekle",
                style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          )
        ],
      ),
    );
  }

  void _addZoneModal() {
    String? selectedMahalle;
    final minC = TextEditingController();
    final feeC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Yeni Bölge Ekle",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: _inputDec("Mahalle Seçin")
                    .copyWith(prefixIcon: const Icon(CupertinoIcons.location)),
                items: _pazarcikMahalleleri
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setMState(() => selectedMahalle = v),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: minC,
                  keyboardType: TextInputType.number,
                  decoration: _inputDec("Minimum Sipariş Tutarı ₺")),
              const SizedBox(height: 12),
              TextField(
                  controller: feeC,
                  keyboardType: TextInputType.number,
                  decoration: _inputDec("Gönderim Ücreti ₺")),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: trendyolOrange,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (selectedMahalle != null && minC.text.isNotEmpty) {
                    setState(() => _deliveryZones.add({
                          'neighborhood': selectedMahalle,
                          'minOrder': double.parse(minC.text),
                          'deliveryFee':
                              double.parse(feeC.text.isEmpty ? "0" : feeC.text)
                        }));
                    Navigator.pop(context);
                  }
                },
                child: const Text("BÖLGEYİ KAYDET",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput(
      TextEditingController c, String hint, IconData icon, bool isNum,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: _inputDec(hint).copyWith(
            prefixIcon: Icon(icon, size: 20, color: trendyolOrange),
            border: InputBorder.none,
            enabledBorder: InputBorder.none),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        filled: true,
        fillColor: iosBg,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      );

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
      ]),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _saveSettings,
          child: _isLoading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text("Değişiklikleri Kaydet",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white)),
        ),
      ),
    );
  }
}
