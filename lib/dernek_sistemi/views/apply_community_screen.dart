import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplyCommunityScreen extends StatefulWidget {
  const ApplyCommunityScreen({Key? key}) : super(key: key);

  @override
  State<ApplyCommunityScreen> createState() => _ApplyCommunityScreenState();
}

class _ApplyCommunityScreenState extends State<ApplyCommunityScreen> {
  final _dernekNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendApplication() async {
    // 1. Klavyeyi kapat (DONMAYI ENGELLER)
    FocusManager.instance.primaryFocus?.unfocus();

    if (_dernekNameController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      _showError("Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('dernekler').add({
        'applicantId': FirebaseAuth.instance.currentUser?.uid,
        'dernekName': _dernekNameController.text.trim(),
        'applicantName': _nameController.text.trim(),
        'applicantPhone': _phoneController.text.trim(),
        'adminEmail': FirebaseAuth.instance.currentUser?.email,
        'status': 'pending', // Onay bekliyor
        'logo': '',
        'coverImage': '',
        'bio': '',
        'rating': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Başvurunuz alındı! İnceleniyor... ⏳",
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.blue.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Hata: $e");
      _showError("Bir hata oluştu, lütfen tekrar deneyin.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Kuruluş Ekle",
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ÜST BİLGİ İKONU
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.domain_add_rounded,
                  size: 60, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text(
              "Meydan'da Yerinizi Alın",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              "Dernek, kulüp veya kuruluşunuzu tamamen ücretsiz ekleyerek Pazarcık halkına ulaşın.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 35),

            // FORMLAR
            _buildTextField(
                _dernekNameController, "Kuruluş/Dernek Adı", Icons.business),
            const SizedBox(height: 15),
            _buildTextField(
                _nameController, "Adınız Soyadınız", Icons.person_outline),
            const SizedBox(height: 15),
            _buildTextField(
                _phoneController, "Telefon Numaranız", Icons.phone_android,
                isPhone: true),

            const SizedBox(height: 40),

            // MODERN GÖNDER BUTONU
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shadowColor: Colors.blue.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Başvuruyu Gönder",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern TextField Tasarım Aracı
  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade300),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
      ),
    );
  }
}
