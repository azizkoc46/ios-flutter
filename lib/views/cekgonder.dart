import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p; // Dosya uzantısını bulmak için eklendi

class CekGonderPage extends StatefulWidget {
  const CekGonderPage({super.key});

  @override
  State<CekGonderPage> createState() => _CekGonderPageState();
}

class _CekGonderPageState extends State<CekGonderPage> {
  // Başlık için yeni bir controller eklendi
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _mediaFile;
  bool _isLoading = false;
  bool _isVideo = false; // Seçilen dosya video mu?

  // Fotoğraf veya Video Seçici
  Future<void> _pickMedia() async {
    final XFile? picked = await _picker.pickMedia(); // Hem video hem resim

    if (picked != null) {
      setState(() {
        _mediaFile = File(picked.path);

        // Dosya uzantısına bakarak video mu resim mi olduğunu anlıyoruz
        String ext = p.extension(picked.path).toLowerCase();
        _isVideo = ext == '.mp4' || ext == '.mov' || ext == '.avi';
      });
    }
  }

  // Firebase'e Gönderim
  Future<void> _submitReport() async {
    // Hem mesaj/başlık boş hem de medya yoksa gönderme
    if (_titleController.text.isEmpty &&
        _msgController.text.isEmpty &&
        _mediaFile == null) return;

    setState(() => _isLoading = true);
    String? downloadUrl;

    try {
      // 1. Medyayı Storage'a yükle
      if (_mediaFile != null) {
        // Uzantıyı koruyarak isim veriyoruz (storage'da videonun bozulmaması için önemli)
        String ext = p.extension(_mediaFile!.path);
        final fileName =
            'cek_gonder/${DateTime.now().millisecondsSinceEpoch}$ext';

        // Dosyanın video veya resim olduğunu metadata ile Firebase'e bildiriyoruz
        final metadata = SettableMetadata(
          contentType: _isVideo ? 'video/mp4' : 'image/jpeg',
        );

        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_mediaFile!, metadata);
        downloadUrl = await ref.getDownloadURL();
      }

      // 2. Veriyi Firestore'a kaydet (ADMİN PANELİ İLE BİREBİR UYUMLU ALANLAR)
      await FirebaseFirestore.instance.collection('cek_gonder_reports').add({
        'uid': FirebaseAuth.instance.currentUser?.uid,
        // KOLEKSİYON ADI DÜZELTİLDİ
        'title': _titleController.text.isNotEmpty
            ? _titleController.text
            : 'İsimsiz Bildirim', // Başlık eklendi
        'description':
            _msgController.text, // 'text' yerine 'description' yapıldı
        'mediaUrl': downloadUrl ?? '',
        'mediaType':
            _isVideo ? 'video' : 'image', // Admin paneli için tip eklendi
        'status': 'pending', // Admin paneli İngilizce 'pending' bekliyor
        'adminReply': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Bildiriminiz başarıyla gönderildi!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata oluştu: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Çek & Gönder",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // BAŞLIK GİRİŞİ (Admin paneli listelemede kullanıyor)
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: "Konu Başlığı (Örn: Çukur Sokak, Kaza...)",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 15),

            // AÇIKLAMA GİRİŞİ
            TextField(
              controller: _msgController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    "Gördüğün bir olayı, sorunu veya haberi detaylıca buraya yaz...",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 20),

            // MEDYA ÖNİZLEME ALANI
            if (_mediaFile != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _isVideo
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_file,
                                size: 60, color: Colors.blueGrey),
                            SizedBox(height: 10),
                            Text("Video Seçildi",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey)),
                          ],
                        )
                      : Image.file(_mediaFile!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 20),

            // MEDYA SEÇME BUTONU
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _pickMedia,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  side: const BorderSide(color: Colors.blueAccent),
                ),
                icon: const Icon(Icons.perm_media, color: Colors.blueAccent),
                label: const Text("Fotoğraf veya Video Seç",
                    style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),

            // GÖNDER BUTONU
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _submitReport,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text("Gönder",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
