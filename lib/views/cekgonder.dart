// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';
import 'package:pazarcik_portal/widgets/cek_gonder_reply_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

import 'package:pazarcik_portal/auth/auth.dart';
import 'package:pazarcik_portal/auth/phone_otp_page.dart';
import 'package:pazarcik_portal/services/system_settings_service.dart';

class CekGonderPage extends StatefulWidget {
  final int initialTabIndex;
  final String? selectedReportId;

  const CekGonderPage({
    super.key,
    this.initialTabIndex = 0,
    this.selectedReportId,
  });

  @override
  State<CekGonderPage> createState() => _CekGonderPageState();
}

class _CekGonderPageState extends State<CekGonderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _mediaFile;
  bool _isLoading = false;
  bool _isVideo = false;

  // Kullanıcı bilgileri ve telefon doğrulama durumu
  String _userPhone = '';
  bool _isPhoneVerified = false;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );

    _loadUserData();

    // Eğer doğrudan belirli bir rapor ID ile açıldıysa yanıt dialogunu göster
    if (widget.selectedReportId != null && widget.selectedReportId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CekGonderReplyDialog.show(context, docId: widget.selectedReportId);
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _isLoadingUserData = false);
      return;
    }

    try {
      String name = user.displayName ?? '';
      String phone = user.phoneNumber ?? '';
      bool verified = phone.isNotEmpty;

      // Firestore customers koleksiyonundan detayları oku
      final custDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      if (custDoc.exists && custDoc.data() != null) {
        final data = custDoc.data()!;
        if (name.isEmpty) {
          name = (data['name'] ?? data['fullName'] ?? '').toString();
        }
        if (phone.isEmpty) {
          phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();
        }
        if (!verified) {
          verified = data['phoneVerified'] == true ||
              data['isPhoneVerified'] == true;
        }
      }

      if (!verified) {
        verified =
            await SystemSettingsService.instance.isUserPhoneVerified(user);
      }

      if (mounted) {
        setState(() {
          if (_nameController.text.trim().isEmpty && name.isNotEmpty) {
            _nameController.text = name;
          }
          _userPhone = phone;
          _isPhoneVerified = verified;
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      debugPrint("Kullanıcı bilgisi getirme hatası: $e");
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  // Fotoğraf veya Video Seçici
  Future<void> _pickMedia() async {
    final XFile? picked = await _picker.pickMedia();

    if (picked != null) {
      setState(() {
        _mediaFile = File(picked.path);
        String ext = p.extension(picked.path).toLowerCase();
        _isVideo = ext == '.mp4' || ext == '.mov' || ext == '.avi';
      });
    }
  }

  // Firebase'e Gönderim
  Future<void> _submitReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Çek Gönder özelliğini kullanmak için lütfen kayıtlı bir hesap ile giriş yapın."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 1. İsim Soyisim Kontrolü
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty || fullName.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen geçerli bir Ad ve Soyad giriniz."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Telefon Doğrulama Kontrolü
    if (!_isPhoneVerified) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Telefon Onayı Zorunlu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Asılsız ve spam bildirimleri önlemek amacıyla şikayet veya öneri iletmeden önce telefon numaranızı doğrulamanız gerekmektedir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.phone_android, size: 16),
              label: const Text('Şimdi Doğrula'),
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhoneOtpPage(verifyOnly: true),
                  ),
                );
                await _loadUserData();
              },
            ),
          ],
        ),
      );
      return;
    }

    // 3. İçerik Kontrolü
    if (_titleController.text.trim().isEmpty &&
        _msgController.text.trim().isEmpty &&
        _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen bir başlık veya açıklama girin."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    String? downloadUrl;

    try {
      // 1. Kullanıcı profilinde isim güncel değilse kaydet
      try {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .set({
          'name': fullName,
          'fullName': fullName,
          if (_userPhone.isNotEmpty) 'phone': _userPhone,
          'phoneVerified': true,
        }, SetOptions(merge: true));

        if (user.displayName != fullName) {
          await user.updateDisplayName(fullName);
        }
      } catch (e) {
        debugPrint("Profil güncelleme uyarısı: $e");
      }

      // 2. Medyayı Storage'a yükle
      if (_mediaFile != null) {
        String ext = p.extension(_mediaFile!.path);
        final fileName =
            'cek_gonder/${DateTime.now().millisecondsSinceEpoch}$ext';

        final metadata = SettableMetadata(
          contentType: _isVideo ? 'video/mp4' : 'image/jpeg',
        );

        final ref = FirebaseStorage.instance.ref().child(fileName);
        await uploadPortalFile(ref, _mediaFile!, metadata: metadata);
        downloadUrl = await ref.getDownloadURL();
      }

      final senderPhone = _userPhone.isNotEmpty
          ? _userPhone
          : (user.phoneNumber ?? '');

      // 3. Veriyi Firestore'a kaydet (Doğrulanmış ad soyad ve telefon ile)
      final reportRef =
          await FirebaseFirestore.instance.collection('cek_gonder_reports').add({
        'uid': user.uid,
        'userName': fullName,
        'userPhone': senderPhone,
        'userEmail': user.email ?? '',
        'phoneVerified': true,
        'isVerified': true,
        'title': _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'İsimsiz Bildirim',
        'description': _msgController.text.trim(),
        'mediaUrl': downloadUrl ?? '',
        'mediaType': _isVideo ? 'video' : 'image',
        'status': 'pending',
        'adminReply': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Yöneticiye Bildirim İlet
      await AdminNotificationService.instance.notifyAdmin(
        title: '📸 Yeni Çek Gönder: $fullName',
        body: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Yeni bir vatandaş bildirimi geldi.',
        type: AdminNotifType.cekGonder,
        docId: reportRef.id,
        extra: {
          'uid': user.uid,
          'userName': fullName,
          'userPhone': senderPhone,
          'userEmail': user.email ?? '',
          'phoneVerified': 'true',
          'hasMedia': (_mediaFile != null).toString(),
          'mediaType': _isVideo ? 'video' : 'image',
        },
      );

      if (mounted) {
        _titleController.clear();
        _msgController.clear();
        setState(() {
          _mediaFile = null;
        });

        // Gönderdiklerim sekmesine geç
        _tabController.animateTo(1);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Bildiriminiz başarıyla iletildi! İncelendiğinde size bildirim gelecektir. ✅"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
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
    _tabController.dispose();
    _titleController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dt = timestamp;
      } else {
        return '';
      }
      return DateFormat('dd MMM yyyy, HH:mm', 'tr').format(dt);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isGuestOrNull = user == null || user.isAnonymous;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Çek & Gönder",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0.5,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: !isGuestOrNull
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF0056D2),
                indicatorWeight: 3,
                labelColor: const Color(0xFF0056D2),
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.add_photo_alternate_outlined, size: 20),
                    text: "Yeni Bildirim",
                  ),
                  Tab(
                    icon: Icon(Icons.mark_chat_read_outlined, size: 20),
                    text: "Bildirimlerim & Yanıtlar",
                  ),
                ],
              )
            : null,
      ),
      body: isGuestOrNull
          ? _buildLoginWarning()
          : _isLoadingUserData
              ? const Center(child: CupertinoActivityIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Sekme: Yeni Bildirim Formu
                    _buildSubmitForm(),
                    // 2. Sekme: Gönderdiklerim ve Admin Yanıtları
                    _buildMyReportsList(user.uid),
                  ],
                ),
    );
  }

  Widget _buildLoginWarning() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0056D2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_outlined,
                  size: 64, color: Color(0xFF0056D2)),
            ),
            const SizedBox(height: 24),
            Text(
              "Giriş Yapmanız Gerekiyor",
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Çek Gönder (Şikayet ve Öneri) özelliğini kullanabilmek ve takibini yapabilmek için lütfen kayıtlı hesabınıza giriş yapın.\n\nAsılsız, mükerrer ve spam bildirimleri önlemek amacıyla misafir kullanıcılar şikayet iletemez.",
              style: TextStyle(
                  color: Colors.grey.shade600, height: 1.5, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text(
                  "Giriş Yap / Kayıt Ol",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Auth()),
                  );
                  await _loadUserData();
                },
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Geri Dön",
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👤 GÖNDEREN BİLGİLERİ KARTI (İSİM & TELEFON DOĞRULAMA)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isPhoneVerified
                    ? const Color(0xFF10B981).withOpacity(0.4)
                    : Colors.amber.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPhoneVerified
                          ? Icons.verified_user_rounded
                          : Icons.warning_amber_rounded,
                      color: _isPhoneVerified
                          ? const Color(0xFF10B981)
                          : Colors.orange.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Bildirimi Gönderen Bilgileri",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // AD SOYAD ALANI
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Adınız ve Soyadınız *",
                    hintText: "Örn: Mehmet Yılmaz",
                    prefixIcon:
                        const Icon(Icons.person_outline, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // TELEFON DOĞRULAMA DURUM KUTUSU
                if (_isPhoneVerified) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Onaylı Telefon: ${_userPhone.isNotEmpty ? _userPhone : "Doğrulanmış"}",
                            style: const TextStyle(
                              color: Color(0xFF0F5132),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "ONAYLI",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade900, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Telefon Onayı Zorunludur",
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Yetkililerin geri dönüş sağlayabilmesi ve asılsız bildirimlerin önlenmesi için telefon numaranızı doğrulamanız gerekmektedir.",
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.phone_iphone, size: 16),
                            label: const Text(
                              "Telefonumu Şimdi Doğrula",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PhoneOtpPage(verifyOnly: true),
                                ),
                              );
                              await _loadUserData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bilgilendirme Notu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0056D2).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFF0056D2).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0056D2), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Pazarcık ile ilgili sorun, talep veya haberleri fotoğraf/video ekleyerek iletin. Yetkililer inceleyip yanıtladığında anlık bildirim alacaksınız.",
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0056D2),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // BAŞLIK GİRİŞİ
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: "Konu Başlığı",
              hintText: "Örn: Çukur Sokak, Park Temizliği, Su Kesintisi...",
              filled: true,
              fillColor: Colors.white,
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
              labelText: "Detaylı Açıklama",
              hintText: "Gördüğünüz sorunun yerini ve detayını açıkça yazın...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 16),

          // MEDYA ÖNİZLEME ALANI
          if (_mediaFile != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _isVideo
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.video_file, size: 54, color: Colors.blueGrey),
                                SizedBox(height: 8),
                                Text("Video Seçildi",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey)),
                              ],
                            ),
                          )
                        : portalPickedImage(_mediaFile!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _mediaFile = null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // MEDYA SEÇME BUTONU
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _pickMedia,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                side: const BorderSide(color: Color(0xFF0056D2), width: 1.5),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF0056D2)),
              label: Text(
                _mediaFile == null
                    ? "Fotoğraf veya Video Ekle"
                    : "Medyayı Değiştir",
                style: const TextStyle(
                    color: Color(0xFF0056D2),
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // GÖNDER BUTONU
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056D2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _submitReport,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text("YETKİLİLERE İLET",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. SEKME: KULLANICININ BİLDİRİMLERİ VE ADMİN YANITLARI
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMyReportsList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cek_gonder_reports')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "Henüz Bildiriminiz Yok",
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "İlettiğiniz sorun ve haberler burada listelenir; yetkililerin verdiği yanıtları buradan okuyabilirsiniz.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056D2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("İlk Bildirimi Yap",
                        style: TextStyle(color: Colors.white)),
                    onPressed: () => _tabController.animateTo(0),
                  ),
                ],
              ),
            ),
          );
        }

        // Tarihe göre sırala
        final sortedDocs = [...docs];
        sortedDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            data['docId'] = doc.id;

            final title = (data['title'] ?? 'İsimsiz Bildirim').toString();
            final desc = (data['description'] ?? '').toString();
            final status = (data['status'] ?? 'pending').toString();
            final adminReply = (data['adminReply'] ?? '').toString();
            final mediaUrl = (data['mediaUrl'] ?? '').toString();
            final createdAt = data['createdAt'];

            final hasReply = adminReply.trim().isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: hasReply
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : Colors.grey.shade200,
                  width: hasReply ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  CekGonderReplyDialog.show(context, data: data, docId: doc.id);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst satır: Başlık & Durum Rozeti
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(status, hasReply),
                        ],
                      ),

                      if (_formatDate(createdAt).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],

                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],

                      // Medya minik önizleme
                      if (mediaUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              data['mediaType'] == 'video' ? 'Video eklendi' : 'Fotoğraf eklendi',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],

                      // 🌟 ADMİN YANITI ÖZET KUTUSU (VARSA ÖNE ÇIKAR)
                      if (hasReply) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified, size: 15, color: Color(0xFF10B981)),
                                  SizedBox(width: 5),
                                  Text(
                                    'YETKİLİ YANITI:',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                adminReply,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Tamamını Oku & Büyüt 🔍',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0056D2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty, size: 13, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Yetkili incelemesi bekleniyor',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status, bool hasReply) {
    if (hasReply || status == 'replied') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
            SizedBox(width: 4),
            Text(
              'Cevaplandı',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'reviewed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'İncelendi',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (status == 'published') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Yayınlandı',
          style: TextStyle(
            color: Colors.teal,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Bekliyor',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
