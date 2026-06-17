import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard (Kopyalama) için eklendi
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';

class VendorApplicationPage extends StatefulWidget {
  const VendorApplicationPage({Key? key}) : super(key: key);

  @override
  State<VendorApplicationPage> createState() => _VendorApplicationPageState();
}

class _VendorApplicationPageState extends State<VendorApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mapLinkController =
      TextEditingController(); // 🔥 Harita Linki İçin Yeni Eklendi
  final TextEditingController _addressController = TextEditingController();

  // Sözleşme okuma kontrolü için ScrollController
  final ScrollController _scrollController = ScrollController();

  bool _isAgreed = false;
  bool _isLoading = false;
  bool _isScrolledToBottom = false; // Sözleşme okundu mu?

  final Color primaryColor =
      const Color(0xfff27a1a); // Trendyol Turuncusu / Esnaf Rengi

  // 🔥 Hazırlanan Hukuki Sözleşme Metni
  final String _contractText = """
PAZARCIK PORTAL ÜCRETSİZ ESNAF VE İŞBİRLİĞİ SÖZLEŞMESİ

MADDE 1: TARAFLAR VE KONU
Bu sözleşme, Pazarcık Portal (bundan sonra 'Platform' olarak anılacaktır) ile Platform'da ücretsiz mağaza açan İşletme/Esnaf (bundan sonra 'Esnaf' olarak anılacaktır) arasında akdedilmiştir. Sözleşme, Esnaf'ın Platform üzerinde ücretsiz mağaza açması ve bunun karşılığında uyacağı kuralları kapsar.

MADDE 2: SÜRE VE DEĞİŞİKLİK HAKKI
İşbu sözleşme, dijital olarak onaylandığı tarihten itibaren 1 (bir) yıl süreyle geçerlidir. Pazarcık Portal, sözleşme maddelerinde, kullanım koşullarında ve hizmet yapısında tek taraflı değişiklik yapma hakkını saklı tutar.

MADDE 3: SİPARİŞ VE FİNANSAL SORUMLULUK (SIFIR KOMİSYON)
Pazarcık Portal, Esnaf'tan platform üzerinden alınan siparişler için herhangi bir komisyon (%0) talep etmez. Platform sadece bir aracı/listeleme hizmeti sunar.
Ürün kalitesi, siparişin teslimatı, müşteri iletişimi, iade süreçleri ve her türlü vergisel/finansal yükümlülük tamamen Esnaf'ın sorumluluğundadır. Pazarcık Portal, doğabilecek müşteri mağduriyetlerinden ve ticari uyuşmazlıklardan sorumlu tutulamaz.

MADDE 4: REKLAM VE SOSYAL MEDYA TAAHHÜDÜ
Esnaf, Pazarcık Portal'da ücretsiz mağaza açması karşılığında; kendi işletmesine ait reklam, duyuru ve tanıtımları Instagram ve Facebook platformlarında yer alan rakip veya diğer yerel/bölgesel sayfalar üzerinden (ücretli veya ücretsiz olarak) YAPTIRMAYACAĞINI taahhüt eder.
İstisna: Esnaf'ın Meta (Facebook/Instagram) üzerinden resmi olarak çıkacağı sponsorlu (ücretli) reklamlar bu kısıtlamanın dışındadır ve serbesttir.

MADDE 5: PAZARCIK PORTAL REKLAM DESTEĞİ
Madde 4'te belirtilen taahhüde uyulması şartıyla Pazarcık Portal; Esnaf'a ait reklam ve duyuru gönderilerini kendi resmi Instagram hesabı (@pazarcikportal) üzerinden ücretsiz olarak onaylamayı ve paylaşmayı taahhüt eder. Bu ücretsiz paylaşım hakkı sözleşme süresince günlük toplam 8 (sekiz) gönderi ile sınırlıdır.

MADDE 6: SÖZLEŞMEYE AYKIRILIK VE CAYMA BEDELİ
Esnaf'ın Madde 4'te belirtilen "başka sayfalarda reklam yapmama" taahhüdünü ihlal etmesi durumunda; ihlalin gerçekleştiği ay ve sözleşme başlangıç tarihi baz alınarak, o tarihte geçerli olan Asgari Brüt Ücretin %50'si (yüzde ellisi) oranında cezai şart (cayma bedeli) Pazarcık Portal tarafından Esnaf'a fatura edilecek/yansıtılacaktır. Esnaf, bu bedeli gayrikabili rücu ödemeyi peşinen kabul ve beyan eder.

MADDE 7: KABUL VE ONAY
Esnaf, bu sözleşmeyi okuduğunu, anladığını ve dijital onay kutucuğunu işaretleyerek tüm maddeleri hür iradesiyle kabul ettiğini beyan eder.
""";

  @override
  void initState() {
    super.initState();
    // Scroll dinleyicisi: En alta inilip inilmediğini kontrol eder
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        if (!_isScrolledToBottom) {
          setState(() {
            _isScrolledToBottom = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _storeNameController.dispose();
    _taxNumberController.dispose();
    _phoneController.dispose();
    _mapLinkController.dispose(); // 🔥 Yeni eklenen controller temizlendi
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Lütfen esnaf sözleşmesini okuyup onaylayın.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("Esnaf başvurusu için önce giriş yapmanız gerekiyor."),
            ),
          );
          Navigator.pushNamed(context, '/auth-screen');
        }
        return;
      }

      String uid = user.uid;
      String storeName = _storeNameController.text.trim();
      final userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? const <String, dynamic>{};
      final fullName = (userData['fullname'] ??
              userData['fullName'] ??
              userData['name'] ??
              user.displayName ??
              '')
          .toString()
          .trim();
      final email = (userData['email'] ?? user.email ?? '').toString().trim();

      await FirebaseFirestore.instance.collection('customers').doc(uid).set({
        'fullname': fullName,
        'fullName': fullName,
        'name': fullName,
        'email': email,
        'storeName': storeName,
        'businessName': storeName,
        'taxNumber': _taxNumberController.text.trim(),
        'storePhone': _phoneController.text.trim(),
        'storeMapLink':
            _mapLinkController.text.trim(), // 🔥 Firestore'a eklendi
        'storeAddress': _addressController.text.trim(),
        'role': 'vendor_pending',
        'isApproved': false,
        'applicationDate': FieldValue.serverTimestamp(),
        'contractAccepted': true, // Sözleşme kabul edildi kaydı
      }, SetOptions(merge: true));

      // 🔥 YENİ EKLENEN: Admin Bildirimi
      await AdminNotificationService.instance.notifyAdmin(
        title: '📋 Esnaf Hesabı Başvurusu',
        body: storeName, // İşletme adını değişkenden alıyoruz
        type: AdminNotifType.corporateApply,
        docId:
            uid, // Başvuru, kullanıcının kendi belgesinde güncellendiği için UID'sini veriyoruz
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Başvuru Alındı"),
        content: const Text(
            "Esnaf başvurunuz ve sözleşme onayınız başarıyla yönetime iletildi. İncelendikten sonra size bildirim göndereceğiz."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Tamam"),
            onPressed: () {
              Navigator.pop(context); // Dialogu kapat
              Navigator.pop(context); // Sayfayı kapat (Profile dön)
            },
          )
        ],
      ),
    );
  }

  void _copyContractToClipboard() {
    Clipboard.setData(ClipboardData(text: _contractText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Sözleşme metni panoya kopyalandı. İstediğiniz yere yapıştırıp kaydedebilirsiniz."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Esnaf Başvurusu",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.left_chevron, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildSectionTitle("DÜKKAN BİLGİLERİ"),
                    _buildTextField(_storeNameController,
                        "Mağaza / İşletme Adı", CupertinoIcons.bag_fill),
                    _buildTextField(_taxNumberController, "Vergi Numarası / TC",
                        CupertinoIcons.doc_text_fill,
                        isNumber: true),
                    _buildTextField(_phoneController, "İşletme İletişim Hattı",
                        CupertinoIcons.phone_fill,
                        isPhone: true),

                    // 🔥 Yeni Eklenen Harita Linki Alanı
                    _buildTextField(
                        _mapLinkController,
                        "Google Haritalar Linki (İsteğe Bağlı)",
                        CupertinoIcons.map_pin_ellipse,
                        isRequired: false),

                    _buildTextField(_addressController, "Açık Adres",
                        CupertinoIcons.location_solid,
                        maxLines: 3),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle("ESNAF SÖZLEŞMESİ"),
                        TextButton.icon(
                          onPressed: _copyContractToClipboard,
                          icon: const Icon(CupertinoIcons.doc_on_clipboard_fill,
                              size: 14),
                          label: const Text("Sözleşmeyi Kopyala",
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                              foregroundColor: primaryColor),
                        )
                      ],
                    ),
                    _buildContractArea(),
                    const SizedBox(height: 15),
                    _buildAgreementCheckbox(),
                    const SizedBox(height: 40),
                    _buildSubmitButton(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.rocket_fill, color: primaryColor, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "Pazarcık Portal dükkanınızı açın, satışlara komisyonsuz hemen başlayın!",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, color: primaryColor),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 5),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black45,
              letterSpacing: 1)),
    );
  }

  // 🔥 isRequired parametresi eklendi ki harita linki boş geçilebilsin
  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isNumber = false,
      bool isPhone = false,
      int maxLines = 1,
      bool isRequired = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber
            ? TextInputType.number
            : (isPhone
                ? TextInputType.phone
                : TextInputType.url), // Link için TextInputType.url
        validator: isRequired
            ? (v) => v!.isEmpty ? "Bu alan boş bırakılamaz" : null
            : null,
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: primaryColor.withOpacity(0.5), size: 20),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _buildContractArea() {
    return Stack(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: _isScrolledToBottom ? Colors.green : Colors.black12,
                width: 2),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Text(
                _contractText,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.black87, height: 1.6),
              ),
            ),
          ),
        ),
        if (!_isScrolledToBottom)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Lütfen sözleşmeyi sonuna kadar okuyun ↓",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
      ],
    );
  }

  Widget _buildAgreementCheckbox() {
    return Opacity(
      opacity: _isScrolledToBottom ? 1.0 : 0.5,
      child: Row(
        children: [
          CupertinoCheckbox(
            value: _isAgreed,
            activeColor: primaryColor,
            onChanged: _isScrolledToBottom
                ? (v) => setState(() => _isAgreed = v ?? false)
                : null,
          ),
          Expanded(
            child: Text(
              "Sözleşmedeki tüm şartları okudum ve kabul ediyorum.",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isScrolledToBottom ? Colors.black : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAgreed ? primaryColor : Colors.grey.shade400,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        onPressed: _isAgreed ? _submitApplication : null,
        child: const Text("BAŞVURUYU VE SÖZLEŞMEYİ ONAYLA",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
