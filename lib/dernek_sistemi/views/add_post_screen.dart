import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 Yeni Firebase Storage servisimiz
import 'package:pazarcik_portal/dernek_sistemi/services/FirebaseStorage_service.dart';

class AddPostScreen extends StatefulWidget {
  final String communityId;
  const AddPostScreen({Key? key, required this.communityId}) : super(key: key);

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  File? _selectedMedia;
  String _mediaType = 'none'; // 'image', 'video', 'file'
  bool _isLoading = false;
  String _feeling = "";

  final Color iosBlue = const Color(0xFF007AFF);
  final Color trendyolOrange = const Color(0xfff27a1a);

  // 🔥 Medya Seçme
  Future<void> _pickMedia(String type) async {
    try {
      if (type == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
        );
        if (result != null) {
          setState(() {
            _selectedMedia = File(result.files.single.path!);
            _mediaType = 'file';
          });
        }
      } else {
        final picker = ImagePicker();
        final pickedFile = type == 'video'
            ? await picker.pickVideo(source: ImageSource.gallery)
            : await picker.pickImage(
                source: ImageSource.gallery, imageQuality: 60);

        if (pickedFile != null) {
          setState(() {
            _selectedMedia = File(pickedFile.path);
            _mediaType = type;
          });
        }
      }
    } catch (e) {
      _showSnackBar("Medya seçilemedi: $e", Colors.red);
    }
  }

  // 🔥 ANA PAYLAŞMA FONKSİYONU (Firebase Storage Entegreli)
  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty && _selectedMedia == null) {
      _showSnackBar(
          "Lütfen bir şeyler yazın veya medya ekleyin.", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String uploadedUrl = "";

      // Eğer bir medya seçildiyse Firebase Storage'a yükle
      if (_selectedMedia != null) {
        String folder = _mediaType == 'image'
            ? 'posts/images'
            : (_mediaType == 'video' ? 'posts/videos' : 'posts/files');

        uploadedUrl = await FirebaseStorageService.uploadFile(_selectedMedia!,
                folderName: "$folder/${widget.communityId}") ??
            "";

        if (uploadedUrl.isEmpty)
          throw "Dosya yüklenemedi, lütfen tekrar deneyin.";
      }

      // 1. Firestore'a Gönderiyi Ekle
      DocumentReference postRef = await FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.communityId)
          .collection('posts')
          .add({
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'content': _contentController.text.trim(),
        'postImage':
            uploadedUrl, // Resim, Video veya Dosya URL'si buraya kaydedilir
        'mediaType': _mediaType,
        'feeling': _feeling,
        'date': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0,
      });

      // 2. İçeriği ilk yorum olarak ekle (İstediğin özel mantık)
      if (_contentController.text.trim().isNotEmpty) {
        await postRef.collection('comments').add({
          'content': _contentController.text.trim(),
          'sender': "Yönetici",
          'date': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("Gönderi başarıyla paylaşıldı! ✅", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Hata: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Gönderi Oluştur",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        leading: IconButton(
            icon:
                const Icon(CupertinoIcons.xmark, color: Colors.black, size: 22),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(15),
                child: CupertinoActivityIndicator())
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                  onPressed: _submitPost,
                  child: Text("PAYLAŞ",
                      style: GoogleFonts.inter(
                          color: trendyolOrange,
                          fontWeight: FontWeight.w800,
                          fontSize: 15))),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_feeling.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: iosBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text("😊 $_feeling hissediyor",
                          style: TextStyle(
                              color: iosBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: GoogleFonts.inter(fontSize: 17, height: 1.5),
                    decoration: const InputDecoration(
                        hintText: "Neler paylaşmak istersiniz?",
                        hintStyle: TextStyle(color: Colors.black26),
                        border: InputBorder.none),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedMedia != null) _buildPreview(),
                ],
              ),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFF2F2F7),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _mediaType == 'image'
                ? Image.file(_selectedMedia!, fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          _mediaType == 'video'
                              ? CupertinoIcons.video_camera_solid
                              : CupertinoIcons.doc_fill,
                          size: 60,
                          color: _mediaType == 'video'
                              ? Colors.red
                              : Colors.orange),
                      const SizedBox(height: 10),
                      Text(_selectedMedia!.path.split('/').last,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                    ],
                  ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: () => setState(() => _selectedMedia = null),
              child: const CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 15,
                child:
                    Icon(CupertinoIcons.xmark, color: Colors.white, size: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          10, 10, 10, MediaQuery.of(context).padding.bottom + 15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _toolIcon(CupertinoIcons.photo, "Fotoğraf", Colors.green,
              () => _pickMedia('image')),
          _toolIcon(CupertinoIcons.videocam_fill, "Video", Colors.red,
              () => _pickMedia('video')),
          _toolIcon(CupertinoIcons.paperclip, "Dosya", Colors.orange,
              () => _pickMedia('file')),
          _toolIcon(CupertinoIcons.smiley_fill, "Duygu", Colors.amber,
              _showFeelingPicker),
        ],
      ),
    );
  }

  Widget _toolIcon(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54))
          ],
        ),
      ),
    );
  }

  void _showFeelingPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          children: [
            "Duyuru 📢",
            "Haber 📰",
            "Etkinlik 🗓️",
            "Vefat / Taziye 🙏",
            "Mutlu 😊",
            "Bilgilendirme ℹ️"
          ]
              .map((f) => ListTile(
                    title: Text(f,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      setState(() => _feeling = f);
                      Navigator.pop(c);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))));
  }
}
