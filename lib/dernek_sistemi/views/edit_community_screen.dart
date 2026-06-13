import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 Senin oluşturduğun servis ismine göre burayı kontrol et
import 'package:pazarcik_portal/dernek_sistemi/services/FirebaseStorage_service.dart';
import 'add_custom_page_screen.dart';

class EditCommunityScreen extends StatefulWidget {
  final DocumentSnapshot community;
  const EditCommunityScreen({Key? key, required this.community})
      : super(key: key);

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _innerTabController;

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _instaController = TextEditingController();
  final _webController = TextEditingController();

  File? _logoImage;
  File? _coverImage;
  bool _isLoading = false;
  late Map<String, dynamic> data;

  final Color iosBlue = const Color(0xFF007AFF);
  final Color iosLightBg = const Color(0xFFF2F2F7);

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 3, vsync: this);
    data = widget.community.data() as Map<String, dynamic>;
    _loadInitialData();
  }

  void _loadInitialData() {
    _nameController.text = data['dernekName'] ?? "";
    _bioController.text = data['bio'] ?? "";
    _phoneController.text = data['applicantPhone'] ?? "";
    _addressController.text = data['address'] ?? "";
    _instaController.text = data['instagram'] ?? "";
    _webController.text = data['website'] ?? "";
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _instaController.dispose();
    _webController.dispose();
    super.dispose();
  }

  // 🔥 GÖRSEL SEÇİCİ
  Future<void> _pickImage(bool isLogo) async {
    final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 50 // Firebase maliyeti için kaliteyi optimize ettik
        );
    if (pickedFile != null) {
      setState(() {
        if (isLogo)
          _logoImage = File(pickedFile.path);
        else
          _coverImage = File(pickedFile.path);
      });
    }
  }

  // 🔥 PROFİL KAYDETME (Firebase Storage Entegreli)
  Future<void> _saveProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);

    try {
      String logoUrl = data['logo'] ?? '';
      String coverUrl = data['coverImage'] ?? '';

      // Eğer yeni logo seçildiyse Firebase'e yükle
      if (_logoImage != null) {
        logoUrl = await FirebaseStorageService.uploadFile(_logoImage!,
                folderName: "communities/logos") ??
            logoUrl;
      }

      // Eğer yeni kapak seçildiyse Firebase'e yükle
      if (_coverImage != null) {
        coverUrl = await FirebaseStorageService.uploadFile(_coverImage!,
                folderName: "communities/covers") ??
            coverUrl;
      }

      await FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.community.id)
          .update({
        'dernekName': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'applicantPhone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'instagram': _instaController.text.trim(),
        'website': _webController.text.trim(),
        'logo': logoUrl,
        'coverImage': coverUrl,
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Profil başarıyla güncellendi! ✅", Colors.green);
    } catch (e) {
      _showSnackBar("Güncelleme hatası: $e", Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 KURULUŞU SİLME
  Future<void> _deleteEntireCommunity() async {
    String confirmText = "";
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Kuruluşu Sil"),
        content: Column(
          children: [
            const Text("Bu işlem geri alınamaz! Onaylamak için 'SİL' yazın."),
            const SizedBox(height: 10),
            CupertinoTextField(
              placeholder: "SİL",
              onChanged: (v) => confirmText = v,
              textAlign: TextAlign.center,
            )
          ],
        ),
        actions: [
          CupertinoDialogAction(
              child: const Text("Vazgeç"),
              onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              if (confirmText == "SİL") {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await FirebaseFirestore.instance
                    .collection('dernekler')
                    .doc(widget.community.id)
                    .delete();
                if (mounted) {
                  Navigator.pop(context); // Paneli kapat
                  _showSnackBar("Kuruluş silindi.", Colors.black);
                }
              }
            },
            child: const Text("Kalıcı Olarak Sil"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosLightBg,
      appBar: AppBar(
        title: Text("Yönetim Paneli",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        bottom: TabBar(
          controller: _innerTabController,
          labelColor: iosBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: iosBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Profil"),
            Tab(text: "Sayfalar"),
            Tab(text: "Denetim"),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(15),
                child: CupertinoActivityIndicator())
          else
            TextButton(
                onPressed: _saveProfile,
                child: Text("KAYDET",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: iosBlue))),
        ],
      ),
      body: TabBarView(
        controller: _innerTabController,
        children: [
          _buildProfileEditTab(),
          _buildPagesManagementTab(),
          _buildContentModerationTab(),
        ],
      ),
    );
  }

  // --- 1. SEKME: PROFİL EDİT ---
  Widget _buildProfileEditTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildVisualHeader(),
          _buildSection("TEMEL BİLGİLER", [
            _buildTextField(
                _nameController, "Kuruluş Adı", CupertinoIcons.briefcase_fill),
            const Divider(height: 1, indent: 50),
            _buildTextField(
                _bioController, "Hakkımızda", CupertinoIcons.info_circle_fill,
                maxLines: 4),
          ]),
          _buildSection("İLETİŞİM & SOSYAL", [
            _buildTextField(
                _phoneController, "Telefon", CupertinoIcons.phone_fill,
                isPhone: true),
            const Divider(height: 1, indent: 50),
            _buildTextField(_instaController, "Instagram Kullanıcı Adı",
                CupertinoIcons.camera_fill),
            const Divider(height: 1, indent: 50),
            _buildTextField(_webController, "Web Sitesi", CupertinoIcons.globe),
          ]),
          const SizedBox(height: 30),
          CupertinoButton(
            onPressed: _deleteEntireCommunity,
            child: const Text("Kuruluşu Sistemden Kaldır",
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- 2. SEKME: ÖZEL SAYFA YÖNETİMİ ---
  Widget _buildPagesManagementTab() {
    return Scaffold(
      backgroundColor: iosLightBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (c) =>
                    AddCustomPageScreen(communityId: widget.community.id))),
        backgroundColor: iosBlue,
        icon: const Icon(CupertinoIcons.add_circled),
        label: const Text("Yeni Sayfa Ekle"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dernekler')
            .doc(widget.community.id)
            .collection('custom_pages')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CupertinoActivityIndicator());
          var pages = snapshot.data!.docs;
          if (pages.isEmpty)
            return const Center(child: Text("Henüz bir içerik sayfası yok."));

          return ListView.builder(
            itemCount: pages.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              var page = pages[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const Icon(CupertinoIcons.doc_text_fill,
                      color: Colors.orange),
                  title: Text(page['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(CupertinoIcons.trash,
                        color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDeletePage(page.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- 3. SEKME: ŞİKAYET DENETİMİ ---
  Widget _buildContentModerationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sikayetler')
          .where('communityId', isEqualTo: widget.community.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CupertinoActivityIndicator());
        var reports = snapshot.data!.docs;
        if (reports.isEmpty)
          return const Center(child: Text("Şikayet edilen içerik yok. ✅"));

        return ListView.builder(
          itemCount: reports.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            var report = reports[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("İçerik Şikayeti",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 5),
                  Text("Sebep: ${report['reason'] ?? 'Belirtilmedi'}",
                      style: const TextStyle(fontSize: 13)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => FirebaseFirestore.instance
                            .collection('sikayetler')
                            .doc(reports[index].id)
                            .delete(),
                        child: const Text("Kapat/Yoksay",
                            style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent, elevation: 0),
                        onPressed: () {
                          /* Burada postu sildirme mantığı eklenebilir */
                        },
                        child: const Text("İçeriği Kaldır",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- YARDIMCI GÖRSEL TASARIMLARI ---
  Widget _buildVisualHeader() {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(15),
                image: _coverImage != null
                    ? DecorationImage(
                        image: FileImage(_coverImage!), fit: BoxFit.cover)
                    : (data['coverImage'] != ""
                        ? DecorationImage(
                            image: NetworkImage(data['coverImage']),
                            fit: BoxFit.cover)
                        : null),
              ),
              child: const Icon(CupertinoIcons.camera_fill,
                  color: Colors.white, size: 30),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 20,
            child: GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: iosLightBg,
                  backgroundImage: _logoImage != null
                      ? FileImage(_logoImage!)
                      : (data['logo'] != "" ? NetworkImage(data['logo']) : null)
                          as ImageProvider?,
                  child: (_logoImage == null &&
                          (data['logo'] == null || data['logo'] == ""))
                      ? const Icon(CupertinoIcons.photo_camera)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 20),
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black45))),
        Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(children: children)),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1, bool isPhone = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.black38),
          prefixIcon: Icon(icon, color: iosBlue, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15)),
    );
  }

  Future<void> _confirmDeletePage(String pageId) async {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("Sayfayı Sil"),
        content:
            const Text("Bu özel içerik sayfası kalıcı olarak silinecektir."),
        actions: [
          CupertinoDialogAction(
              child: const Text("Vazgeç"), onPressed: () => Navigator.pop(c)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('dernekler')
                  .doc(widget.community.id)
                  .collection('custom_pages')
                  .doc(pageId)
                  .delete();
              Navigator.pop(c);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }
}
