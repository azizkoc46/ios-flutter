// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 Yeni oluşturduğumuz servisi import ediyoruz
import 'package:pazarcik_portal/dernek_sistemi/services/FirebaseStorage_service.dart';

class AddCustomPageScreen extends StatefulWidget {
  final String communityId;
  const AddCustomPageScreen({Key? key, required this.communityId})
      : super(key: key);

  @override
  State<AddCustomPageScreen> createState() => _AddCustomPageScreenState();
}

class _AddCustomPageScreenState extends State<AddCustomPageScreen> {
  final _titleController = TextEditingController();
  final List<Map<String, dynamic>> _blocks = [];
  bool _isLoading = false;

  // Yeni bir içerik bloğu ekler (Yazı + Resim alanı)
  void _addBlock() {
    setState(() {
      _blocks.add({
        "text": TextEditingController(),
        "imageFile": null,
        "imageUrl": "",
      });
    });
  }

  // 🔥 SAYFAYI KAYDETME (Firebase Storage & Firestore)
  Future<void> _savePage() async {
    if (_titleController.text.isEmpty) {
      _showSnackBar("Lütfen bir sayfa başlığı girin", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Map<String, String>> finalContent = [];

      for (var block in _blocks) {
        String url = "";
        // Eğer blokta bir resim seçildiyse Firebase'e yükle
        if (block["imageFile"] != null) {
          url = await FirebaseStorageService.uploadFile(block["imageFile"],
                  folderName: "custom_pages/${widget.communityId}") ??
              "";
        }

        finalContent.add({
          "text": block["text"].text.trim(),
          "image": url,
        });
      }

      // Firestore'a sayfa verilerini yaz
      await FirebaseFirestore.instance
          .collection('dernekler')
          .doc(widget.communityId)
          .collection('custom_pages')
          .add({
        "title": _titleController.text.trim(),
        "content": finalContent,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar("Sayfa başarıyla oluşturuldu!", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Hata oluştu: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text("İçerik Oluştur",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.clear, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: CupertinoActivityIndicator())
          else
            TextButton(
              onPressed: _savePage,
              child: const Text("Kaydet",
                  style: TextStyle(
                      color: Color(0xfff27a1a), fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SAYFA BAŞLIĞI", style: _headerStyle()),
            const SizedBox(height: 8),
            _buildTitleInput(),
            const SizedBox(height: 25),
            Text("SAYFA BLOKLARI", style: _headerStyle()),
            const SizedBox(height: 8),
            _buildBlockList(),
            const SizedBox(height: 20),
            _buildAddBlockButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Colors.black45,
      letterSpacing: 0.5);

  Widget _buildTitleInput() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          hintText: "Örn: Dernek Tarihçemiz",
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildBlockList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _blocks.length,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            // Resim Seçme Alanı
            GestureDetector(
              onTap: () async {
                final p = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 60);
                if (p != null)
                  setState(() => _blocks[index]["imageFile"] = File(p.path));
              },
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(15),
                  image: _blocks[index]["imageFile"] != null
                      ? DecorationImage(
                          image: FileImage(_blocks[index]["imageFile"]),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: _blocks[index]["imageFile"] == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.camera_fill,
                              color: Colors.black26),
                          Text("Resim Ekle",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black26,
                                  fontWeight: FontWeight.bold)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            // Metin Giriş Alanı
            TextField(
              controller: _blocks[index]["text"],
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Açıklama metni yazın...",
                hintStyle: TextStyle(fontSize: 13, color: Colors.black26),
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            // Bloğu Sil
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => setState(() => _blocks.removeAt(index)),
                icon: const Icon(CupertinoIcons.trash,
                    color: Colors.redAccent, size: 20),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAddBlockButton() {
    return InkWell(
      onTap: _addBlock,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        width: double.infinity,
        decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xfff27a1a).withOpacity(0.5),
                style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(15),
            color: const Color(0xfff27a1a).withOpacity(0.05)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.add_circled_solid, color: Color(0xfff27a1a)),
            SizedBox(width: 10),
            Text("Yeni İçerik Bloğu Ekle",
                style: TextStyle(
                    color: Color(0xfff27a1a), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
