import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';
import 'package:path/path.dart' as path; // Dosya uzantısını almak için

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Dosyayı Firebase Storage'a yükler ve URL'sini döndürür.
  /// [folderName] parametresi ile 'products', 'store_covers' gibi klasörler belirleyebilirsin.
  static Future<String?> uploadFile(File file,
      {String folderName = "uploads"}) async {
    try {
      // 1. Dosya adını ve uzantısını al
      String fileName = path.basename(file.path);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // 2. Storage referansı oluştur (Örn: uploads/1714825000_resim.jpg)
      Reference ref =
          _storage.ref().child(folderName).child("${timestamp}_$fileName");

      // 3. Dosyayı yükle
      final uploadTask = uploadPortalFile(ref, file);

      // 4. Yükleme tamamlanana kadar bekle
      TaskSnapshot snapshot = await uploadTask;

      // 5. Yüklenen dosyanın indirme bağlantısını (URL) al
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print("Firebase Storage Hatası: $e");
      return null;
    }
  }

  /// Eğer bir dosyayı silmek istersen bu fonksiyonu kullanabilirsin.
  static Future<void> deleteFile(String imageUrl) async {
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (e) {
      print("Dosya silme hatası: $e");
    }
  }
}
