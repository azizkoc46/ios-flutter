import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminStoryManagePage extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;

  const AdminStoryManagePage(
      {Key? key, required this.categoryId, required this.categoryTitle})
      : super(key: key);

  @override
  State<AdminStoryManagePage> createState() => _AdminStoryManagePageState();
}

class _AdminStoryManagePageState extends State<AdminStoryManagePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _uploadCoverImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      File file = File(image.path);
      Reference ref = FirebaseStorage.instance
          .ref()
          .child("story_covers/${widget.categoryId}_cover.jpg");
      await ref.putFile(file);
      String url = await ref.getDownloadURL();
      if (!mounted) return;
      await FirebaseFirestore.instance
          .collection('story_categories')
          .doc(widget.categoryId)
          .update({'coverImage': url});
      _showMessage("Kapak güncellendi ✅", Colors.green);
    } catch (e) {
      _showMessage("Hata: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadMedia(bool isVideo) async {
    final XFile? file = isVideo
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    setState(() => _isUploading = true);
    try {
      File mediaFile = File(file.path);
      String fileName =
          "story_media/${widget.categoryId}_${DateTime.now().millisecondsSinceEpoch}";
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(mediaFile);
      String url = await ref.getDownloadURL();
      if (!mounted) return;
      await FirebaseFirestore.instance
          .collection('story_categories')
          .doc(widget.categoryId)
          .update({
        'items': FieldValue.arrayUnion([
          {'type': isVideo ? 'video' : 'image', 'url': url}
        ])
      });
      _showMessage("Medya eklendi ✅", Colors.green);
    } catch (e) {
      _showMessage("Hata: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryTitle)),
      body: Center(
          child: Column(children: [
        ElevatedButton(
            onPressed: _uploadCoverImage, child: const Text("Kapak Yükle")),
        ElevatedButton(
            onPressed: () => _uploadMedia(false),
            child: const Text("Resim Ekle")),
        ElevatedButton(
            onPressed: () => _uploadMedia(true),
            child: const Text("Video Ekle")),
      ])),
    );
  }
}
