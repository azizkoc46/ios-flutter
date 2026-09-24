import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

class GrupGonderiOlustur extends StatefulWidget {
  const GrupGonderiOlustur({Key? key}) : super(key: key);

  @override
  State<GrupGonderiOlustur> createState() => _GrupGonderiOlusturState();
}

class _GrupGonderiOlusturState extends State<GrupGonderiOlustur> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _contentController = TextEditingController();

  // Medya Yönetimi
  List<File> _selectedImages = [];
  File? _selectedVideo;
  bool isLoading = false;

  // Anket Yönetimi
  bool isPollMode = false;
  final TextEditingController _pollQuestionController = TextEditingController();
  List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Profil Bilgileri
  String userName = "Kullanıcı";
  String userAvatar = "";

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pollQuestionController.dispose();
    for (var c in _pollOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _getUserData() async {
    if (currentUser != null) {
      var doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists && mounted) {
        var data = doc.data()!;
        setState(() {
          userName = data['fullname'] ?? "Kullanıcı";
          userAvatar = data['profileImage'] ?? "";
        });
      }
    }
  }

  // --- FOTOĞRAF SEÇİCİ (En fazla 4 fotoğraf) ---
  Future<void> _pickImage() async {
    if (_selectedImages.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("En fazla 4 adet fotoğraf ekleyebilirsiniz."),
            backgroundColor: Color(0xFFFF5E62),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (pickedFiles.isNotEmpty) {
      final availableSlots = 4 - _selectedImages.length;
      final toAdd = pickedFiles.take(availableSlots).map((x) => File(x.path)).toList();
      setState(() {
        _selectedImages.addAll(toAdd);
        isPollMode = false; // Resim seçilirse anketi kapat
      });

      if (pickedFiles.length > availableSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("En fazla 4 fotoğraf seçilebilir. İlk 4 fotoğraf eklendi."),
            backgroundColor: Color(0xFFFF5E62),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- VİDEO SEÇİCİ ---
  Future<void> _pickVideo() async {
    try {
      final pickedFile = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final length = await file.length();
        if (length > 100 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Video boyutu en fazla 100MB olabilir."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedVideo = file;
          isPollMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Video seçilirken bir hata oluştu: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- ANKET YÖNETİMİ ---
  void _togglePollMode() {
    setState(() {
      isPollMode = !isPollMode;
      if (isPollMode) {
        _selectedImages.clear(); // Anket açılırsa resimleri ve videoyu temizle
        _selectedVideo = null;
      }
    });
  }

  void _addPollOption() {
    if (_pollOptionControllers.length < 5) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
    }
  }

  // --- FİREBASE YÜKLEME VE PAYLAŞMA ---
  Future<void> _sharePost() async {
    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideo == null &&
        (!isPollMode || _pollOptionControllers[0].text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Lütfen bir içerik, fotoğraf veya video ekleyin."),
          backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => isLoading = true);

    try {
      List<String> uploadedImageUrls = [];

      // 1. Resimleri Storage'a Yükle
      for (var image in _selectedImages) {
        String fileName =
            'group_media/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await uploadPortalFile(ref, image);
        String url = await ref.getDownloadURL();
        uploadedImageUrls.add(url);
      }

      // 1.5 Videoyu Storage'a Yükle
      String? uploadedVideoUrl;
      if (_selectedVideo != null) {
        String videoFileName =
            'group_media/videos/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        Reference vRef = FirebaseStorage.instance.ref().child(videoFileName);
        await uploadPortalFile(vRef, _selectedVideo!);
        uploadedVideoUrl = await vRef.getDownloadURL();
      }

      // 2. Anket Verilerini Hazırla
      Map<String, dynamic>? pollData;
      if (isPollMode && _pollQuestionController.text.isNotEmpty) {
        List<String> options = _pollOptionControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();

        if (options.length >= 2) {
          pollData = {
            'question': _pollQuestionController.text.trim(),
            'options': options,
            'votes': {},
          };
        }
      }

      // 3. Firestore'a Kaydet
      await FirebaseFirestore.instance.collection('group_posts').add({
        'authorId': currentUser!.uid,
        'authorName': userName,
        'authorAvatar': userAvatar,
        'content': _contentController.text.trim(),
        'imageUrls': uploadedImageUrls,
        'videoUrl': uploadedVideoUrl,
        'pollData': pollData,
        'likes': [],
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isEdited': false,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Gönderi başarıyla paylaşıldı! ✅"),
          backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Hata oluştu: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Gönderi Oluştur",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E62),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isLoading ? null : _sharePost,
              child: isLoading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("Paylaş",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- KULLANICI BİLGİSİ ---
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: userAvatar.isNotEmpty
                            ? NetworkImage(userAvatar)
                            : null,
                        child: userAvatar.isEmpty
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            // 🔥 HATA BURADAYDI: EdgeInsets.top yerine EdgeInsets.only kullanıldı
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                const Icon(Icons.public,
                                    size: 12, color: Colors.black54),
                                const SizedBox(width: 4),
                                Text("Pazarcık Meydanı",
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 15),

                  // --- METİN ALANI ---
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: isPollMode
                          ? "Anket hakkında bir şeyler söyle..."
                          : "Ne düşünüyorsun?",
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 20),
                      border: InputBorder.none,
                    ),
                  ),

                  // --- SEÇİLEN FOTOĞRAFLARI GÖSTER ---
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.photo_library, size: 16, color: Color(0xFFFF5E62)),
                        const SizedBox(width: 6),
                        Text(
                          "Seçilen Fotoğraflar (${_selectedImages.length}/4)",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF5E62),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedImages.map((file) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: portalPickedImage(file,
                                  width: 100, height: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _selectedImages.remove(file)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            )
                          ],
                        );
                      }).toList(),
                    )
                  ],

                  // --- SEÇİLEN VİDEO ÖNİZLEMESİ ---
                  if (_selectedVideo != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECE8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFFF5E62).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5E62),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.videocam_fill,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Video Eklendi",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1C1C1E)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedVideo!.path
                                      .split(Platform.pathSeparator)
                                      .last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark_circle_fill,
                                color: Colors.redAccent, size: 24),
                            onPressed: () =>
                                setState(() => _selectedVideo = null),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // --- ANKET ALANI ---
                  if (isPollMode) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _pollQuestionController,
                            decoration: const InputDecoration(
                                hintText: "Anket Sorusu Sor...",
                                border: InputBorder.none,
                                hintStyle:
                                    TextStyle(fontWeight: FontWeight.bold)),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          ...List.generate(_pollOptionControllers.length,
                              (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: TextField(
                                controller: _pollOptionControllers[index],
                                decoration: InputDecoration(
                                  hintText: "${index + 1}. Şık",
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            );
                          }),
                          if (_pollOptionControllers.length < 5)
                            TextButton.icon(
                              onPressed: _addPollOption,
                              icon: const Icon(Icons.add),
                              label: const Text("Şık Ekle"),
                            )
                        ],
                      ),
                    )
                  ],
                ],
              ),
            ),
          ),

          // --- ALT ARAÇ ÇUBUĞU ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Text("Şunu ekle:",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.photo_library,
                        color: Colors.green, size: 28),
                    onPressed: _pickImage),
                IconButton(
                    icon: const Icon(Icons.video_call,
                        color: Colors.redAccent, size: 30),
                    onPressed: _pickVideo),
                IconButton(
                    icon:
                        const Icon(Icons.poll, color: Colors.orange, size: 28),
                    onPressed: _togglePollMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
