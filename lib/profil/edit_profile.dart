// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _openAddressController = TextEditingController();
  String? _selectedNeighborhood;

  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _vknController = TextEditingController();

  var obscure = true;
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
  bool _isEditingPhone = false;
  String _originalPhone = '';
  bool isSmsSending = false;
  String _verificationId = "";
  ConfirmationResult? _webConfirmationResult;
  int? _resendToken;

  // ✅ Rate-limit: son SMS zamanı
  DateTime? _lastSmsSentAt;
  static const _smsCooldown = Duration(seconds: 90);
  static const _lastSmsSentKey = 'phone_verification_last_sms_at';

  final Color maviRenk = const Color(0xFF0A8EC7);

  String? _formatTurkishPhoneNumber(String rawPhone) {
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0090')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('90') && digits.length == 12) {
      return '+$digits';
    }

    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    if (digits.length == 10 && digits.startsWith('5')) {
      return '+90$digits';
    }

    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullnameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
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

  @override
  void initState() {
    super.initState();
    pazarcikMahalleleri.sort();
    _restoreSmsCooldown();
    _fetchUserDetails();
  }

  Future<void> _restoreSmsCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getInt(_lastSmsSentKey);
    if (savedAt != null) {
      _lastSmsSentAt = DateTime.fromMillisecondsSinceEpoch(savedAt);
    }
  }

  Future<void> _rememberSmsSent() async {
    _lastSmsSentAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastSmsSentKey,
      _lastSmsSentAt!.millisecondsSinceEpoch,
    );
  }

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
        isPhoneVerified = userData?['phoneVerified'] ?? false;

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
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── SMS gönder ───────────────────────────────────────────────
  Future<void> _sendSms() async {
    final formatted = _formatTurkishPhoneNumber(_phoneController.text.trim());

    if (formatted == null) {
      _showError("Geçerli bir telefon numarası girin (Örn: 5xx xxx xx xx). "
          "Numara 05 veya 5 ile başlamalı, 10 haneli olmalıdır.");
      return;
    }

    if (_lastSmsSentAt != null &&
        DateTime.now().difference(_lastSmsSentAt!) < _smsCooldown) {
      final remaining = _smsCooldown.inSeconds -
          DateTime.now().difference(_lastSmsSentAt!).inSeconds;
      _showError("Lütfen $remaining saniye bekleyin.");
      return;
    }

    // FIX #5: Her yeni SMS isteğinde eski oturumu temizle
    _verificationId = "";
    _webConfirmationResult = null;

    setState(() => isSmsSending = true);

    try {
      FirebaseAuth.instance.setLanguageCode('tr');

      if (kIsWeb) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw FirebaseAuthException(code: 'user-not-found');
        }

        // FIX #1: Web'de provider zaten bağlıysa linkWithPhoneNumber hata fırlatır.
        // Bu durumda kullanıcının numarasını güncellemek için önce unlink edip
        // yeniden link ediyoruz; ya da sadece Firestore'u güncelliyoruz (numara aynıysa).
        final hasPhone = user.providerData.any((p) => p.providerId == 'phone');

        if (hasPhone) {
          // Telefon provider'ı zaten bağlı — numarayı değiştirmek için
          // önce unlink edip ardından yeniden linkWithPhoneNumber çağırıyoruz.
          try {
            await user.unlink('phone');
          } on FirebaseAuthException catch (unlinkErr) {
            // unlink başarısız olursa (örn. tek provider) direkt Firestore'u güncelle
            if (unlinkErr.code == 'no-such-provider' ||
                unlinkErr.code == 'requires-recent-login') {
              await firebase.collection('customers').doc(user.uid).set({
                'phoneVerified': true,
                'phone': _phoneController.text.trim(),
              }, SetOptions(merge: true));
              if (!mounted) return;
              setState(() {
                isSmsSending = false;
                isPhoneVerified = true;
                _originalPhone = _phoneController.text.trim();
                _isEditingPhone = false;
              });
              _showSuccess("Telefon numaranız güncellendi!");
              return;
            }
            rethrow;
          }
        }

        _webConfirmationResult = await user.linkWithPhoneNumber(formatted);
        await _rememberSmsSent();
        if (!mounted) return;
        setState(() => isSmsSending = false);
        _showOtpDialog();
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          await _linkCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => isSmsSending = false);
          _showError(_phoneErrorMessage(e.code, e.message));
        },
        codeSent: (String verificationId, int? resendToken) async {
          await _rememberSmsSent();
          if (!mounted) return;
          setState(() {
            isSmsSending = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isSmsSending = false);
      _showError(_phoneErrorMessage(e.code, e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => isSmsSending = false);
      _showError("SMS servisine ulaşılamadı. Birkaç dakika sonra deneyin.");
    }
  }

  String _phoneErrorMessage(String code, String? message) {
    switch (code) {
      case 'too-many-requests':
        return "Çok fazla SMS denemesi yapıldı (hata 39). Yeni istek göndermeden birkaç saat bekleyin.";
      case 'invalid-phone-number':
        return "Geçersiz telefon numarası formatı.";
      case 'quota-exceeded':
        return "SMS kotası aşıldı. Lütfen daha sonra tekrar deneyin.";
      case 'app-not-authorized':
        return "Uygulama SMS göndermek için yetkilendirilmemiş.";
      case 'network-request-failed':
        return "İnternet bağlantınızı kontrol edin.";
      case 'internal-error':
      case 'web-internal-error':
        return "Firebase SMS servisi geçici olarak yanıt vermiyor. Birkaç dakika sonra tekrar deneyin.";
      case 'captcha-check-failed':
        return "reCAPTCHA doğrulaması tamamlanamadı. Sayfayı yenileyip tekrar deneyin.";
      case 'unauthorized-domain':
        return "Bu web adresi Firebase telefon doğrulaması için yetkili değil.";
      case 'operation-not-allowed':
        return "Firebase'de telefonla doğrulama etkin değil.";
      case 'user-not-found':
        return "Oturumunuz bulunamadı. Çıkış yapıp yeniden giriş yapın.";
      default:
        return message ?? "SMS gönderilemedi. Tekrar deneyin.";
    }
  }

  Future<void> _linkCredential(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final hasPhone = user.providerData.any((p) => p.providerId == 'phone');

      if (hasPhone) {
        await firebase.collection('customers').doc(user.uid).set({
          'phoneVerified': true,
          'phone': _phoneController.text.trim(),
        }, SetOptions(merge: true));
      } else {
        await user.linkWithCredential(credential);
        await firebase.collection('customers').doc(user.uid).set({
          'phoneVerified': true,
          'phone': _phoneController.text.trim(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() {
        isPhoneVerified = true;
        _originalPhone = _phoneController.text.trim();
        _isEditingPhone = false;
      });
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSuccess("Telefon numaranız başarıyla doğrulandı!");
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'provider-already-linked':
          // FIX #3: catch scope'unda user yok, currentUser'dan al
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) break;
          await firebase.collection('customers').doc(currentUser.uid).set(
              {'phoneVerified': true, 'phone': _phoneController.text.trim()},
              SetOptions(merge: true));
          if (mounted) {
            setState(() {
              isPhoneVerified = true;
              _originalPhone = _phoneController.text.trim();
              _isEditingPhone = false;
            });
          }
          if (Navigator.canPop(context)) Navigator.pop(context);
          _showSuccess("Telefon zaten doğrulanmış, bilgiler güncellendi!");
          break;
        case 'credential-already-in-use':
          _showError("Bu numara başka bir hesaba kayıtlı.");
          break;
        case 'invalid-verification-code':
          _showError("Girdiğiniz kod hatalı. Lütfen tekrar deneyin.");
          break;
        case 'session-expired':
          _showError("Kodun süresi doldu. Yeni bir kod isteyin.");
          break;
        default:
          _showError("Doğrulama hatası: ${e.message}");
      }
    } catch (e) {
      if (mounted) _showError("Beklenmeyen bir hata oluştu.");
    }
  }

  Future<void> _completeWebPhoneVerification(String smsCode) async {
    final confirmation = _webConfirmationResult;
    if (confirmation == null) {
      throw FirebaseAuthException(code: 'session-expired');
    }

    // FIX #4: Hataları burada yakala, yukarıya fırlatmak yerine
    try {
      await confirmation.confirm(smsCode);
    } on FirebaseAuthException catch (e) {
      _webConfirmationResult = null;
      rethrow; // OTP dialog'daki catch'e ilet
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await firebase.collection('customers').doc(user.uid).set({
      'phoneVerified': true,
      'phone': _phoneController.text.trim(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      isPhoneVerified = true;
      _originalPhone = _phoneController.text.trim();
      _isEditingPhone = false;
      _webConfirmationResult = null;
    });
    if (Navigator.canPop(context)) Navigator.pop(context);
    _showSuccess("Telefon numaranız başarıyla doğrulandı!");
  }

  void _showOtpDialog() {
    if (!kIsWeb && _verificationId.isEmpty) {
      _showError("Doğrulama oturumu başlatılamadı. Tekrar deneyin.");
      return;
    }

    final otpController = TextEditingController();
    var isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (_, setModalState) {
          Future<void> verify() async {
            if (isVerifying) return;
            if (otpController.text.trim().length != 6) {
              return;
            }
            setModalState(() => isVerifying = true);
            try {
              if (kIsWeb) {
                await _completeWebPhoneVerification(
                  otpController.text.trim(),
                );
                return;
              }
              final credential = PhoneAuthProvider.credential(
                verificationId: _verificationId,
                smsCode: otpController.text.trim(),
              );
              await _linkCredential(credential);
            } on FirebaseAuthException catch (e) {
              setModalState(() => isVerifying = false);
              if (mounted) {
                _showError(e.code == 'invalid-verification-code'
                    ? "Hatalı kod girdiniz."
                    : "Doğrulama başarısız: ${e.message}");
              }
            } catch (_) {
              setModalState(() => isVerifying = false);
              if (mounted) _showError("Beklenmeyen hata. Tekrar deneyin.");
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                ),
                Icon(Icons.sms_outlined, color: maviRenk, size: 44),
                const SizedBox(height: 14),
                const Text("SMS Doğrulama",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  "Telefonunuza gönderilen 6 haneli kodu girin.\nKod 60 saniye geçerlidir.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableSuggestions: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "------",
                    hintStyle: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 28,
                        letterSpacing: 8),
                    counterText: "",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    if (v.length == 6) {
                      FocusScope.of(sheetContext).unfocus();
                      verify();
                    }
                  },
                  onSubmitted: (_) => verify(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maviRenk,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text("Doğrula",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // FIX #2: async/await ile güvenli kapanış ve yeniden gönderim
                    Navigator.pop(sheetContext);
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (mounted) _sendSms();
                  },
                  child: Text("Kodu almadım, tekrar gönder",
                      style: TextStyle(color: maviRenk, fontSize: 13)),
                ),
                SizedBox(
                    height: MediaQuery.of(sheetContext).padding.bottom + 8),
              ],
            ),
          );
        });
      },
    ).whenComplete(otpController.dispose);
  }

  Future<void> _saveDetails() async {
    final valid = _formKey.currentState!.validate();
    if (!valid) return;

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
        if (enteredPhone != _originalPhone && !isPhoneVerified) {
          _showError(
              "Yeni telefon numarasını kaydetmeden önce SMS ile doğrulayın.");
          return;
        }

        final fullName = _fullnameController.text.trim();
        final updateData = <String, dynamic>{
          "email": _auth.currentUser?.email ?? _emailController.text.trim(),
          "fullname": fullName,
          "fullName": fullName,
          "name": fullName,
          "phone": enteredPhone,
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
      _showError("Güncelleme başarısız: ${e.toString().split(']').last}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(14)));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(14)));
  }

  void _showSuccessAndPop() {
    _showSuccess("Profil başarıyla güncellendi!");
    Timer(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hesabını Sil"),
        content: const Text(
          "Bu işlem hesabını ve profil bilgilerini kalıcı olarak siler. Devam etmek istiyor musun?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Hesabımı Sil"),
          ),
        ],
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
          "Güvenlik için hesabını silmeden önce çıkış yapıp tekrar giriş yapmalısın.",
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

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text(
          widget.editPasswordOnly ? "Şifre Değiştir" : "Profili Düzenle",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios, size: 17, color: maviRenk),
                Text("Geri", style: TextStyle(fontSize: 17, color: maviRenk)),
              ],
            ),
          ),
        ),
        leadingWidth: 80,
      ),
      bottomNavigationBar: _buildSaveButton(isDark: isDark),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: maviRenk))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Profil fotoğrafı ──────────────────
                          if (!widget.editPasswordOnly) ...[
                            Center(
                              child: ProfileImagePicker(
                                selectImage: (img) =>
                                    setState(() => profileImage = img),
                                isReg: false,
                                imgUrl: userData?['image'] ?? '',
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          // ── Kişisel bilgiler ──────────────────
                          _iosLabel("KİŞİSEL BİLGİLER"),
                          _buildSection([
                            _buildField(
                                controller: _fullnameController,
                                icon: Icons.person_outline_rounded,
                                hint: "Ad Soyad",
                                field: Field.fullname),
                            _buildField(
                                controller: _emailController,
                                icon: Icons.mail_outline_rounded,
                                hint: "E-Posta",
                                field: Field.email),
                            _buildPhoneField(),
                          ], isDark: isDark),
                          const SizedBox(height: 28),

                          // ── Teslimat adresi ───────────────────
                          _iosLabel("TESLİMAT ADRESİ"),
                          _buildSection([
                            _buildDisabledRow(
                                icon: Icons.location_on_outlined,
                                val: "Kahramanmaraş / Pazarcık",
                                isDark: isDark),
                            _buildNeighborhoodDropdown(isDark: isDark),
                            _buildField(
                                controller: _openAddressController,
                                icon: Icons.home_outlined,
                                hint: "Sokak, Bina, Kapı No",
                                field: Field.openAddress),
                          ], isDark: isDark),
                          const SizedBox(height: 28),

                          // ── İşletme bilgileri (seller) ────────
                          if (role == 'seller') ...[
                            _iosLabel("İŞLETME BİLGİLERİ"),
                            _buildSection([
                              _buildField(
                                  controller: _businessNameController,
                                  icon: Icons.store_outlined,
                                  hint: "İşletme Adı",
                                  field: Field.businessName),
                              _buildField(
                                  controller: _businessTypeController,
                                  icon: Icons.category_outlined,
                                  hint: "İşletme Türü",
                                  field: Field.businessType),
                              _buildField(
                                  controller: _vknController,
                                  icon: Icons.assignment_outlined,
                                  hint: "VKN",
                                  field: Field.vkn),
                            ], isDark: isDark),
                            const SizedBox(height: 28),
                          ],

                          // ── Şifre ─────────────────────────────
                          _buildPasswordSection(isDark: isDark),

                          // ── Hesabı sil ────────────────────────
                          if (!widget.editPasswordOnly) ...[
                            const SizedBox(height: 28),
                            _buildDangerZone(isDark: isDark),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────────

  /// iOS ayarlar tarzı gri section başlığı
  Widget _iosLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Color _cardColor(bool isDark) =>
      isDark ? const Color(0xFF2C2C2E) : Colors.white;

  // ─────────────────────────────────────────────────────────────
  // KAYDET BUTONU
  // ─────────────────────────────────────────────────────────────
  Widget _buildSaveButton({required bool isDark}) {
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        left: 16,
        right: 16,
        top: 10,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: isLoading ? null : _saveDetails,
          style: ElevatedButton.styleFrom(
            backgroundColor: maviRenk,
            disabledBackgroundColor: maviRenk.withValues(alpha: 0.4),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Text(
                  "Kaydet",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION KAPSAYICISI
  // ─────────────────────────────────────────────────────────────
  Widget _buildSection(List<Widget> children, {required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(children: children),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // METİN ALANI
  // ─────────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Field field,
    bool isPassword = false,
  }) {
    final isDisabled = field == Field.email;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: TextFormField(
        controller: controller,
        enabled: !isDisabled,
        obscureText: isPassword && obscure,
        style: TextStyle(
          fontSize: 16,
          letterSpacing: -0.2,
          color: isDisabled ? Colors.grey : null,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon,
                color: isDisabled ? Colors.grey.shade400 : maviRenk, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade400,
                      size: 20),
                  onPressed: () => setState(() => obscure = !obscure))
              : isDisabled
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(Icons.lock_outline_rounded,
                          color: Colors.grey.shade400, size: 16))
                  : null,
        ),
        validator: (v) => (field == Field.fullname && (v == null || v.isEmpty))
            ? "Ad Soyad boş bırakılamaz"
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TELEFON ALANI
  // ─────────────────────────────────────────────────────────────
  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(Icons.phone_outlined, color: maviRenk, size: 20),
        ),
        Expanded(
          child: TextFormField(
            controller: _phoneController,
            enabled: _isEditingPhone || _originalPhone.isEmpty,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 16, letterSpacing: -0.2),
            decoration: InputDecoration(
              hintText: "5xx xxx xx xx",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            ),
            onChanged: (_) {
              if (isPhoneVerified) setState(() => isPhoneVerified = false);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: !_isEditingPhone && _originalPhone.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _isEditingPhone = true;
                    isPhoneVerified = false;
                  }),
                  child: Text("Değiştir",
                      style: TextStyle(
                          color: maviRenk,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                )
              : isPhoneVerified
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green.shade500, size: 16),
                      const SizedBox(width: 4),
                      Text("Doğrulandı",
                          style: TextStyle(
                              color: Colors.green.shade500,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ])
                  : isSmsSending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: maviRenk))
                      : GestureDetector(
                          onTap: _sendSms,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                                color: maviRenk.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text("Doğrula",
                                style: TextStyle(
                                    color: maviRenk,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DEĞİŞTİRİLEMEZ SATIR (şehir/ilçe)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDisabledRow(
      {required IconData icon, required String val, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: Colors.grey.shade400, size: 20),
        ),
        Text(val,
            style: TextStyle(
                fontSize: 16,
                letterSpacing: -0.2,
                color: Colors.grey.shade500)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Icon(Icons.lock_outline_rounded,
              color: Colors.grey.shade400, size: 14),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MAHALLE DROPDOWN
  // ─────────────────────────────────────────────────────────────
  Widget _buildNeighborhoodDropdown({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: _selectedNeighborhood,
        dropdownColor: _cardColor(isDark),
        icon: Icon(Icons.chevron_right_rounded,
            color: Colors.grey.shade400, size: 20),
        style: TextStyle(
            fontSize: 16,
            letterSpacing: -0.2,
            color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child:
                Icon(Icons.location_city_outlined, color: maviRenk, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          hintText: "Mahalle / Köy seçin",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
        items: pazarcikMahalleleri
            .map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(m, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedNeighborhood = v),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ŞİFRE BÖLÜMÜ
  // ─────────────────────────────────────────────────────────────
  Widget _buildPasswordSection({required bool isDark}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!widget.editPasswordOnly && authType == 'email') ...[
        _iosLabel("GÜVENLİK"),
        _buildSection([
          _buildIosToggleRow(
            icon: Icons.lock_outline_rounded,
            label: "Şifremi Değiştir",
            value: changePassword,
            onChanged: (v) => setState(() => changePassword = v),
            isDark: isDark,
            showDivider: false,
          ),
        ], isDark: isDark),
      ],
      if (changePassword || widget.editPasswordOnly) ...[
        const SizedBox(height: 14),
        if (widget.editPasswordOnly) _iosLabel("GÜVENLİK"),
        _buildSection([
          _buildField(
              controller: _passwordController,
              icon: Icons.lock_outline_rounded,
              hint: "Yeni Şifre",
              field: Field.password,
              isPassword: true),
        ], isDark: isDark),
      ],
    ]);
  }

  /// iOS Switch satırı
  Widget _buildIosToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    bool showDivider = true,
  }) {
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: Colors.grey.withValues(alpha: 0.15))))
          : null,
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: maviRenk,
        title: Text(label,
            style: const TextStyle(fontSize: 16, letterSpacing: -0.2)),
        secondary: Icon(icon, color: maviRenk, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HESAP SİL
  // ─────────────────────────────────────────────────────────────
  Widget _buildDangerZone({required bool isDark}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _iosLabel("HESAP"),
      _buildSection([
        ListTile(
          onTap: isLoading ? null : _confirmDeleteAccount,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 18),
          ),
          title: const Text(
            "Hesabımı Sil",
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          trailing:
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
      ], isDark: isDark),
    ]);
  }
}
