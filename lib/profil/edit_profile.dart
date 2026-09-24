// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import '../services/phone_verification.dart';
import 'phone_verification_page.dart';
import '../esnaf_sistemi/lib/helpers/image_picker.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

enum Field {
  fullname,
  email,
  password,
  phone,
  openAddress,
  businessName,
  businessType,
  vkn
}

class EditProfile extends StatefulWidget {
  const EditProfile({Key? key, this.editPasswordOnly = false})
      : super(key: key);
  final bool editPasswordOnly;

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _openAddressController = TextEditingController();
  String? _selectedNeighborhood;

  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _vknController = TextEditingController();

  var obscure = true;
  var obscureConfirm = true;
  File? profileImage;
  final _auth = FirebaseAuth.instance;
  final firebase = FirebaseFirestore.instance;
  var userId = FirebaseAuth.instance.currentUser?.uid ?? "";

  Map<String, dynamic>? userData;
  String authType = 'email';
  String role = 'customer';
  var isLoading = true;
  var changePassword = false;

  // ── Telefon doğrulama ────────────────────────────────────────
  bool isPhoneVerified = false;
  String _originalPhone = '';

  // Renk Paleti (Modern Zümrüt & Safir & Kehribar)
  static const Color primaryBlue = Color(0xFF0284C7);
  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningGold = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    pazarcikMahalleleri.sort();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fetchUserDetails();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _fullnameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _openAddressController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _vknController.dispose();
    super.dispose();
  }

  final List<String> pazarcikMahalleleri = [
    "Ahmet Bozdağ Mahallesi",
    "Akçakoyunlu Mahallesi",
    "Akçalar Mahallesi",
    "Akdemir Mahallesi",
    "Armutlu Mahallesi",
    "Aşağımülk Mahallesi",
    "Bağdınısağır Mahallesi",
    "Beşçeşme Mahallesi",
    "Bölükçam Mahallesi",
    "Büyüknacar Fatih Mahallesi",
    "Büyüknacar Kocadere Mahallesi",
    "Büyüknacar Merkez Mahallesi",
    "Cengiztopel Mahallesi",
    "Cimikanlı Mahallesi",
    "Camlıca Mahallesi",
    "Çamlıtepe Mahallesi",
    "Çiçek Mahallesi",
    "Çiçekalanı Mahallesi",
    "Çiğdemtepe Mahallesi",
    "Çöçelli Mahallesi",
    "Damlataş Mahallesi",
    "Dedepaşa Mahallesi",
    "Eğlen Mahallesi",
    "Eğrice Mahallesi",
    "Emiroğlu Mahallesi",
    "Evri Pınarbaşı Mahallesi",
    "Evri Taşbiçme Mahallesi",
    "Fatih Mahallesi",
    "Ganidağıketiler Mahallesi",
    "Göçer Mahallesi",
    "Göynük Mahallesi",
    "Hanobası Mahallesi",
    "Harmancık Mahallesi",
    "Hasankoca Mahallesi",
    "Hürriyet Mahallesi",
    "İncirli Mahallesi",
    "Kadıncık Mahallesi",
    "Karaağaç Mahallesi",
    "Karabıyıklı Mahallesi",
    "Karaçay Mahallesi",
    "Karagöl Mahallesi",
    "Karahüyük Mahallesi",
    "Keleş Mahallesi",
    "Kızkapanlı Mahallesi",
    "Kizirli Mahallesi",
    "Kuzeykent Mahallesi",
    "Mehmet Emin Arıkoğlu Mahallesi",
    "Memiş Özdal Mahallesi",
    "Memişkahya Mahallesi",
    "Menderes Mahallesi",
    "Mezere Mahallesi",
    "Musolar Mahallesi",
    "Narlı Bahçeli Evler Mahallesi",
    "Narlı İsmetpaşa Mahallesi",
    "Narlı Cumhuriyet Mahallesi",
    "Nefsidoğanlı Mahallesi",
    "Osmandede Mahallesi",
    "Ördekdede Mahallesi",
    "Sadakalar Mahallesi",
    "Sakarkaya Mahallesi",
    "Şallıuşağı Mahallesi",
    "Salmanıpak Mahallesi",
    "Salmanlı Mahallesi",
    "Sarıerik Mahallesi",
    "Sarıl Mahallesi",
    "Soku Mahallesi",
    "Sultanlar Mahallesi",
    "Şahintepe Mahallesi",
    "Şehit Nurettin Ademoğlu Mahallesi",
    "Taşdemir Mahallesi",
    "Tetirlik Mahallesi",
    "Tilkiler Mahallesi",
    "Turunçul Mahallesi",
    "Ufacıklı Mahallesi",
    "Ulubahçe Mahallesi",
    "Yarbaşı Mahallesi",
    "Yeşilkent Mahallesi",
    "Yiğitler Mahallesi",
    "Yolboyu Mahallesi",
    "Yukarıhöcüklü Mahallesi",
    "Yukarımülk Mahallesi",
    "Yumaklıcerit Bağlar Mahallesi",
    "Yumaklıcerit Cumhuriyet Mahallesi",
    "15 Temmuz Mahallesi",
  ];

  Future<void> _fetchUserDetails() async {
    try {
      final authUser = _auth.currentUser;
      final doc = await firebase.collection('customers').doc(userId).get();
      if (doc.exists) {
        userData = doc.data();
        _emailController.text = userData?['email'] ?? authUser?.email ?? '';
        _fullnameController.text = (userData?['fullname'] ??
                userData?['fullName'] ??
                userData?['name'] ??
                authUser?.displayName ??
                '')
            .toString();
        _phoneController.text = userData?['phone'] ?? '';
        _originalPhone = _phoneController.text.trim();
        _openAddressController.text =
            userData?['openAddress'] ?? userData?['address'] ?? '';

        final normalizedSavedPhone = normalizeTurkishMobile(_phoneController.text);
        isPhoneVerified = (authUser?.phoneNumber != null &&
                normalizedSavedPhone == authUser?.phoneNumber) ||
            userData?['isPhoneVerified'] == true ||
            userData?['phoneVerified'] == true;

        final saved = userData?['neighborhood'] as String?;
        if (saved != null && pazarcikMahalleleri.contains(saved)) {
          _selectedNeighborhood = saved;
        }

        authType = userData?['auth-type'] ?? 'email';
        role = userData?['role'] ?? 'customer';

        if (role == 'seller') {
          _businessNameController.text = userData?['businessName'] ?? '';
          _businessTypeController.text = userData?['businessType'] ?? '';
          _vknController.text = userData?['vkn'] ?? '';
        }
      } else {
        _emailController.text = authUser?.email ?? '';
        _fullnameController.text = authUser?.displayName ?? '';
        userData = {
          'email': _emailController.text,
          'fullname': _fullnameController.text,
          'role': 'customer',
          'auth-type': authUser?.providerData.isNotEmpty == true
              ? authUser!.providerData.first.providerId
              : 'email',
        };
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        _animController.forward();
      }
    }
  }

  // ── Telefon Doğrulama Akışı ──
  Future<void> _startPhoneVerification([String? targetPhone]) async {
    final rawPhone = targetPhone ?? _phoneController.text.trim();
    final phone = normalizeTurkishMobile(rawPhone);
    if (phone == null) {
      _showError('Lütfen geçerli bir cep telefonu girin (Örn: 05xx xxx xx xx)');
      return;
    }

    final verifiedPhone = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PhoneVerificationPage(phone: phone)),
    );

    if (!mounted || verifiedPhone == null) return;

    setState(() {
      _phoneController.text = rawPhone;
      _originalPhone = rawPhone;
      isPhoneVerified = true;
      final updatedDisplayName =
          FirebaseAuth.instance.currentUser?.displayName;
      if (updatedDisplayName != null && updatedDisplayName.isNotEmpty) {
        _fullnameController.text = updatedDisplayName;
      }
    });

    try {
      await firebase.collection('customers').doc(userId).set({
        'phone': rawPhone,
        'isPhoneVerified': true,
        'phoneVerified': true,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {}

    _showSuccess('Telefon numaranız SMS kodu ile başarıyla doğrulandı!');
  }

  // ── Profil Bilgilerini Kaydet ──
  Future<void> _saveDetails() async {
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid) return;

    if (changePassword || widget.editPasswordOnly) {
      final pass = _passwordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();
      if (pass.length < 6) {
        _showError("Şifreniz en az 6 karakterden oluşmalıdır.");
        return;
      }
      if (confirm.isNotEmpty && pass != confirm) {
        _showError("Girdiğiniz yeni şifreler birbiriyle eşleşmiyor.");
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      if (widget.editPasswordOnly || changePassword) {
        if (authType == 'email') {
          await _auth.currentUser!
              .updatePassword(_passwordController.text.trim());
        }
      }

      if (!widget.editPasswordOnly) {
        String? downloadUrl = userData?['image'];
        if (profileImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('user-images')
              .child('$userId.jpg');
          await uploadPortalFile(storageRef, profileImage!);
          downloadUrl = await storageRef.getDownloadURL();
        }

        final enteredPhone = _phoneController.text.trim();
        final normalizedPhone = normalizeTurkishMobile(enteredPhone);
        if (enteredPhone.isNotEmpty &&
            enteredPhone != _originalPhone &&
            !isPhoneVerified &&
            (normalizedPhone == null ||
                normalizedPhone != _auth.currentUser?.phoneNumber)) {
          _showError(
              "Yeni telefon numaranızı kaydetmeden önce SMS ile doğrulamanız gerekmektedir.");
          setState(() => isLoading = false);
          return;
        }

        final fullName = _fullnameController.text.trim();
        final updateData = <String, dynamic>{
          "email": _auth.currentUser?.email ?? _emailController.text.trim(),
          "fullname": fullName,
          "fullName": fullName,
          "name": fullName,
          "phone": enteredPhone,
          "isPhoneVerified": isPhoneVerified,
          "city": "Kahramanmaraş",
          "district": "Pazarcık",
          "neighborhood": _selectedNeighborhood ?? '',
          "openAddress": _openAddressController.text.trim(),
          "address": "Kahramanmaraş, Pazarcık, "
              "${_selectedNeighborhood ?? ''}, "
              "${_openAddressController.text.trim()}",
          "image": downloadUrl,
          "updatedAt": Timestamp.now(),
        };

        if (role == 'seller') {
          updateData['businessName'] = _businessNameController.text.trim();
          updateData['businessType'] = _businessTypeController.text.trim();
          updateData['vkn'] = _vknController.text.trim();
        }

        if (fullName.isNotEmpty) {
          await _auth.currentUser?.updateDisplayName(fullName);
        }

        await firebase
            .collection('customers')
            .doc(userId)
            .set(updateData, SetOptions(merge: true));
      }

      _showSuccessAndPop();
    } catch (e) {
      _showError("Güncelleme başarısız: ${e.toString().split(']').last.trim()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      backgroundColor: dangerRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      backgroundColor: successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccessAndPop() {
    _showSuccess("Profil bilgileriniz başarıyla güncellendi!");
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ── Hesap Silme Dialog & Silme İşlemleri ──
  Future<void> _confirmDeleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: dangerRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: dangerRed, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                "Hesabınızı Silmek İstiyor musunuz?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Bu işlem geri alınamaz. Profiliniz, kayıtlı ilanlarınız ve tüm verileriniz kalıcı olarak sistemden silinecektir.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        "Vazgeç",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dangerRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        "Hesabımı Sil",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      await _deleteOwnedUserData(user.uid);
      await firebase.collection('customers').doc(user.uid).delete();
      await user.delete();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showError(
          "Güvenlik için hesabınızı silmeden önce çıkış yapıp tekrar giriş yapmanız gerekmektedir.",
        );
      } else {
        _showError("Hesap silinemedi: ${e.message ?? e.code}");
      }
    } catch (e) {
      _showError("Hesap silinirken hata oluştu: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteOwnedUserData(String uid) async {
    final jobs = <Future<void>>[
      _deleteWhere('businesses', 'ownerId', uid),
      _deleteWhere('businesses', 'userId', uid),
      _deleteWhere('businesses', 'uid', uid),
      _deleteWhere('classified_ads', 'ownerId', uid),
      _deleteWhere('classified_ads', 'sellerId', uid),
      _deleteWhere('job_ads', 'ownerId', uid),
      _deleteWhere('job_postings', 'ownerId', uid),
      _deleteWhere('group_posts', 'uid', uid),
      _deleteWhere('group_posts', 'userId', uid),
      _deleteWhere('comments', 'userId', uid),
      _deleteWhere('seller_reviews', 'reviewerId', uid),
      _deleteWhere('reviews', 'reviewerId', uid),
      _deleteWhere('notifications', 'to', uid),
      _deleteWhere('app_notifications', 'uid', uid),
      _deleteWhere('phone_verification_requests', 'uid', uid),
      _deleteWhere('business_claims', 'claimedBy', uid),
    ];

    await Future.wait(jobs);
  }

  Future<void> _deleteWhere(String collection, String field, String uid) async {
    while (true) {
      final snapshot = await firebase
          .collection(collection)
          .where(field, isEqualTo: uid)
          .limit(400)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = firebase.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ── Profil Doluluk Oranı ──
  int _calculateProfileScore() {
    int total = 4;
    int completed = 0;
    if (_fullnameController.text.trim().isNotEmpty) completed++;
    if (_emailController.text.trim().isNotEmpty) completed++;
    if (_phoneController.text.trim().isNotEmpty && isPhoneVerified) completed++;
    if ((_selectedNeighborhood != null && _selectedNeighborhood!.isNotEmpty) ||
        _openAddressController.text.trim().isNotEmpty) completed++;
    return ((completed / total) * 100).round();
  }

  // ─────────────────────────────────────────────────────────────
  // MODAL / BOTTOMSHEET DÜZENLEYİCİLERİ
  // ─────────────────────────────────────────────────────────────

  /// İsim Soyisim Düzenleme Modalı (Yanlışlıkla değiştirmeyi engeller)
  void _showEditNameSheet(bool isDark) {
    final textController = TextEditingController(text: _fullnameController.text);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.badge_outlined,
                            color: primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ad Soyad Güncelle",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              "Pazarcık Portal genelinde görünecek adınız.",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: textController,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: "Ad Soyad girin",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2C2C32)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: primaryBlue, width: 2),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Ad Soyad alanı boş bırakılamaz"
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            "Vazgeç",
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              setState(() {
                                _fullnameController.text =
                                    textController.text.trim();
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            "Kaydet",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Telefon Numarası Güncelleme / Doğrulama Modalı
  void _showEditPhoneSheet(bool isDark) {
    final phoneInputController = TextEditingController(text: _phoneController.text);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: successGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.phone_iphone_rounded,
                            color: successGreen, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Telefon Numarası Güncelle",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              "Güvenliğiniz için yeni numaranıza SMS kodu iletilecektir.",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: phoneInputController,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("🇹🇷 +90 ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                                width: 1,
                                height: 20,
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                      hintText: "5xx xxx xx xx",
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, letterSpacing: 0),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2C2C32)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: successGreen, width: 2),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Telefon numarası gereklidir";
                      }
                      if (normalizeTurkishMobile(v.trim()) == null) {
                        return "Geçerli bir cep telefonu girin (5xx xxx xx xx)";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            "Vazgeç",
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final newPhone = phoneInputController.text.trim();
                              Navigator.pop(ctx);
                              _startPhoneVerification(newPhone);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            "SMS Kodu Gönder",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pazarcık Mahalleleri Arama & Seçim Modalı
  void _showNeighborhoodPicker(bool isDark) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredList = pazarcikMahalleleri
              .where((m) =>
                  m.toLowerCase().contains(searchQuery.toLowerCase().trim()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_city_rounded,
                              color: primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Mahalle / Köy Seçin",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                "Pazarcık ilçesine bağlı tüm mahalleler",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: false,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                      decoration: InputDecoration(
                        hintText: "Mahalle veya köy ara...",
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: primaryBlue, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2C2C32)
                            : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 44, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  "Mahalle bulunamadı",
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            itemBuilder: (context, index) {
                              final mahalle = filteredList[index];
                              final isSelected =
                                  _selectedNeighborhood == mahalle;
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                tileColor: isSelected
                                    ? primaryBlue.withValues(alpha: 0.08)
                                    : null,
                                title: Text(
                                  mahalle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryBlue
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: primaryBlue, size: 20)
                                    : null,
                                onTap: () {
                                  setState(
                                      () => _selectedNeighborhood = mahalle);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD ARAYÜZÜ
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F1014) : const Color(0xFFF6F8FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF14151A) : Colors.white,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text(
          widget.editPasswordOnly ? "Şifre ve Güvenlik" : "Kişisel Bilgilerim",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 19, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _buildModernBottomBar(isDark: isDark),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Bilgileriniz yükleniyor...",
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. Modern Profil Header & Avatar ──
                              if (!widget.editPasswordOnly) ...[
                                _buildHeaderProfileCard(isDark: isDark),
                                const SizedBox(height: 20),
                              ],

                              // ── 2. Kimlik & İletişim Bilgileri ──
                              _buildSectionHeader(
                                title: "KİMLİK VE İLETİŞİM",
                                subtitle:
                                    "Adınız ve iletişim kanallarınızın güvenliği",
                                isDark: isDark,
                              ),
                              _buildIdentityCard(isDark: isDark),
                              const SizedBox(height: 24),

                              // ── 3. Pazarcık Adres & İkametgah ──
                              _buildSectionHeader(
                                title: "İKAMETGAH VE ADRES",
                                subtitle:
                                    "Pazarcık içi teslimat ve rehber konumu",
                                isDark: isDark,
                              ),
                              _buildAddressCard(isDark: isDark),
                              const SizedBox(height: 24),

                              // ── 4. Esnaf / İşletme Bilgileri (Eğer Varsa) ──
                              if (role == 'seller') ...[
                                _buildSectionHeader(
                                  title: "İŞLETME BİLGİLERİ",
                                  subtitle:
                                      "Kayıtlı mağazanıza ait kurumsal veriler",
                                  isDark: isDark,
                                ),
                                _buildBusinessCard(isDark: isDark),
                                const SizedBox(height: 24),
                              ],

                              // ── 5. Şifre & Güvenlik ──
                              _buildSectionHeader(
                                title: "GÜVENLİK VE ŞİFRE",
                                subtitle: "Hesabınızın oturum açma ayarları",
                                isDark: isDark,
                              ),
                              _buildSecurityCard(isDark: isDark),
                              const SizedBox(height: 28),

                              // ── 6. Tehlike Bölgesi (Hesap Sil) ──
                              if (!widget.editPasswordOnly) ...[
                                _buildDangerCard(isDark: isDark),
                                const SizedBox(height: 40),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. HEADER PROFİL & DOLULUK KARTI
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeaderProfileCard({required bool isDark}) {
    final score = _calculateProfileScore();
    final displayName = _fullnameController.text.trim().isNotEmpty
        ? _fullnameController.text.trim()
        : "Kullanıcı";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E222D), const Color(0xFF161820)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with camera action
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primaryBlue, accentIndigo],
                      ),
                    ),
                    child: ProfileImagePicker(
                      selectImage: (img) => setState(() => profileImage = img),
                      isReg: false,
                      imgUrl: userData?['image'] ?? '',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E222D) : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: role == 'seller'
                                ? warningGold.withValues(alpha: 0.15)
                                : primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                role == 'seller'
                                    ? Icons.storefront_rounded
                                    : Icons.person_rounded,
                                color: role == 'seller'
                                    ? warningGold
                                    : primaryBlue,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                role == 'seller'
                                    ? "Pazarcık Esnafı"
                                    : "Pazarcık Sakini",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: role == 'seller'
                                      ? warningGold
                                      : primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isPhoneVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.verified_rounded,
                                color: successGreen, size: 13),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Profil Doluluk Göstergesi (Gamified Progress)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 16,
                            color: score == 100 ? successGreen : primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          "Profil ve Güvenlik Seviyesi",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "%$score",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: score == 100 ? successGreen : primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      score == 100 ? successGreen : primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. KİMLİK VE İLETİŞİM KARTI (Ad Soyad, E-posta, Telefon)
  // ─────────────────────────────────────────────────────────────
  Widget _buildIdentityCard({required bool isDark}) {
    final fullName = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    return _buildContainerCard(
      isDark: isDark,
      children: [
        // AD SOYAD (Modallı & Güvenli Düzenleme)
        _buildInteractiveItem(
          icon: Icons.person_rounded,
          iconColor: primaryBlue,
          label: "Ad Soyad",
          value: fullName.isNotEmpty ? fullName : "Belirtilmedi",
          actionText: "Düzenle",
          onTap: () => _showEditNameSheet(isDark),
          isDark: isDark,
          showDivider: true,
        ),

        // TELEFON NUMARASI & DOĞRULAMA DURUMU
        _buildInteractiveItem(
          icon: Icons.phone_android_rounded,
          iconColor: isPhoneVerified ? successGreen : warningGold,
          label: "Cep Telefonu",
          value: phone.isNotEmpty ? phone : "Telefon eklenmedi",
          badge: isPhoneVerified
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: successGreen, size: 12),
                      SizedBox(width: 4),
                      Text("SMS Onaylı",
                          style: TextStyle(
                              color: successGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: warningGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: warningGold, size: 12),
                      SizedBox(width: 4),
                      Text("Doğrulanmadı",
                          style: TextStyle(
                              color: warningGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
          actionText: isPhoneVerified ? "Değiştir" : "Doğrula",
          actionColor: isPhoneVerified ? primaryBlue : successGreen,
          onTap: () => _showEditPhoneSheet(isDark),
          isDark: isDark,
          showDivider: true,
        ),

        // E-POSTA ADRESİ (Kilitli & Güvenli)
        _buildInteractiveItem(
          icon: Icons.alternate_email_rounded,
          iconColor: Colors.grey.shade500,
          label: "E-Posta Adresi",
          value: email.isNotEmpty ? email : "Girilmedi",
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 11, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  "Hesap Kimliği",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          isDark: isDark,
          showDivider: false,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. İKAMETGAH VE ADRES KARTI (Pazarcık, Mahalle, Açık Adres)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAddressCard({required bool isDark}) {
    return _buildContainerCard(
      isDark: isDark,
      children: [
        // ŞEHİR VE İLÇE (Sabit Pazarcık)
        _buildInteractiveItem(
          icon: Icons.location_on_rounded,
          iconColor: accentIndigo,
          label: "İlçe / Şehir",
          value: "Kahramanmaraş / Pazarcık",
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("Yerel",
                style: TextStyle(
                    color: accentIndigo,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          isDark: isDark,
          showDivider: true,
        ),

        // MAHALLE / KÖY SEÇİMİ (Arama Modalı)
        _buildInteractiveItem(
          icon: Icons.location_city_rounded,
          iconColor: primaryBlue,
          label: "Mahalle / Köy",
          value: _selectedNeighborhood ?? "Lütfen mahalle seçin",
          actionText: "Değiştir",
          onTap: () => _showNeighborhoodPicker(isDark),
          isDark: isDark,
          showDivider: true,
        ),

        // AÇIK ADRES GİRİŞİ
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.home_outlined,
                      size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    "Açık Adres (Sokak, Bina No, Kat, Daire)",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _openAddressController,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "Örn: Cengiz Topel Cad. No: 12 Kat: 2",
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF232329)
                      : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. İŞLETME BİLGİLERİ (ESNAF)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBusinessCard({required bool isDark}) {
    return _buildContainerCard(
      isDark: isDark,
      children: [
        _buildTextFieldRow(
          controller: _businessNameController,
          icon: Icons.store_rounded,
          label: "İşletme / Dükkan Adı",
          hint: "İşletmenizin tabelada yazan adı",
          isDark: isDark,
          showDivider: true,
        ),
        _buildTextFieldRow(
          controller: _businessTypeController,
          icon: Icons.category_rounded,
          label: "Faaliyet Sektörü",
          hint: "Örn: Restoran, Market, Kuaför",
          isDark: isDark,
          showDivider: true,
        ),
        _buildTextFieldRow(
          controller: _vknController,
          icon: Icons.description_rounded,
          label: "Vergi Kimlik No (VKN / TCKN)",
          hint: "10 veya 11 haneli numara",
          isDark: isDark,
          showDivider: false,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. GÜVENLİK VE ŞİFRE KARTI
  // ─────────────────────────────────────────────────────────────
  Widget _buildSecurityCard({required bool isDark}) {
    return _buildContainerCard(
      isDark: isDark,
      children: [
        if (authType == 'email' && !widget.editPasswordOnly)
          SwitchListTile.adaptive(
            value: changePassword,
            onChanged: (val) => setState(() => changePassword = val),
            activeColor: primaryBlue,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  color: primaryBlue, size: 20),
            ),
            title: Text(
              "Şifremi Değiştir",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              "Giriş şifrenizi yenilemek için aktif edin",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        if (changePassword || widget.editPasswordOnly) ...[
          if (!widget.editPasswordOnly)
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Yeni Şifreniz",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: obscure,
                  style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "En az 6 karakter",
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF232329)
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Yeni Şifre Tekrar",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: obscureConfirm,
                  style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Yeni şifrenizi doğrulayın",
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF232329)
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. TEHLİKE BÖLGESİ (HESAP SİL)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDangerCard({required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1516) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dangerRed.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dangerRed.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: dangerRed, size: 22),
        ),
        title: const Text(
          "Hesabımı Kalıcı Olarak Sil",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: dangerRed,
          ),
        ),
        subtitle: Text(
          "Tüm verilerinizi ve profilinizi sistemden siler",
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.red.shade900,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: dangerRed, size: 22),
        onTap: _confirmDeleteAccount,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // YARDIMCI BİLEŞENLER
  // ─────────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCard({
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInteractiveItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? badge,
    String? actionText,
    Color? actionColor,
    VoidCallback? onTap,
    required bool isDark,
    required bool showDivider,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          splashColor: primaryBlue.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            badge,
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (actionText != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (actionColor ?? primaryBlue).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      actionText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: actionColor ?? primaryBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 52,
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
      ],
    );
  }

  Widget _buildTextFieldRow({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required bool isDark,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    TextFormField(
                      controller: controller,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 52,
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODERN SABİT KAYDET BUTONU
  // ─────────────────────────────────────────────────────────────
  Widget _buildModernBottomBar({required bool isDark}) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: isLoading ? null : _saveDetails,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            disabledBackgroundColor: primaryBlue.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Değişiklikleri Kaydet",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
