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
      final doc = await firebase.collection('customers').doc(userId).get();
      if (doc.exists) {
        userData = doc.data();
        _emailController.text = userData?['email'] ?? '';
        _fullnameController.text = userData?['fullname'] ?? '';
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
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── SMS gönder ───────────────────────────────────────────────
  Future<void> _sendSms() async {
    final formatted = _formatTurkishPhoneNumber(_phoneController.text.trim());

    if (formatted == null) {
      _showError("Geçerli bir telefon numarası girin (Örn: 5xx xxx xx xx)");
      return;
    }

    if (_lastSmsSentAt != null &&
        DateTime.now().difference(_lastSmsSentAt!) < _smsCooldown) {
      final remaining = _smsCooldown.inSeconds -
          DateTime.now().difference(_lastSmsSentAt!).inSeconds;
      _showError("Lütfen $remaining saniye bekleyin.");
      return;
    }

    setState(() => isSmsSending = true);

    try {
      FirebaseAuth.instance.setLanguageCode('tr');

      if (kIsWeb) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw FirebaseAuthException(code: 'user-not-found');
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
          await firebase.collection('customers').doc(userId).set(
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

    await confirmation.confirm(smsCode);
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
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Future.delayed(const Duration(milliseconds: 300), _sendSms);
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

        final updateData = <String, dynamic>{
          "email": _emailController.text.trim(),
          "fullname": _fullnameController.text.trim(),
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
      await user.delete();
      await firebase.collection('customers').doc(user.uid).delete();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(widget.editPasswordOnly ? "Şifre Değiştir" : "Profilim",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context)),
      ),
      bottomNavigationBar: _buildSaveButton(),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: maviRenk))
          : SafeArea(
              child: Center(
                // ✅ EKLENDİ: Formun geniş ekranlarda (tablet vb.) çok yayılmasını engellemek için Center + ConstrainedBox
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (!widget.editPasswordOnly) ...[
                            Center(
                              child: ProfileImagePicker(
                                selectImage: (img) =>
                                    setState(() => profileImage = img),
                                isReg: false,
                                imgUrl: userData?['image'] ?? '',
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                          _buildSection([
                            _buildField(
                                controller: _fullnameController,
                                icon: Icons.person_outline,
                                hint: "Ad Soyad",
                                field: Field.fullname),
                            _buildField(
                                controller: _emailController,
                                icon: Icons.mail_outline,
                                hint: "E-Posta",
                                field: Field.email),
                            _buildPhoneField(),
                          ]),
                          const SizedBox(height: 25),
                          _buildSection([
                            _buildDisabledRow(
                                icon: Icons.location_on_outlined,
                                val: "Kahramanmaraş / Pazarcık"),
                            _buildNeighborhoodDropdown(), // 🚀 Düzenlenen Kısım
                            _buildField(
                                controller: _openAddressController,
                                icon: Icons.home_outlined,
                                hint: "Sokak, Bina, Kapı No",
                                field: Field.openAddress),
                          ], title: "TESLİMAT ADRESİ"),
                          if (role == 'seller') ...[
                            const SizedBox(height: 25),
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
                            ], title: "İŞLETME BİLGİLERİ"),
                          ],
                          const SizedBox(height: 25),
                          _buildPasswordSection(),
                          if (!widget.editPasswordOnly) ...[
                            const SizedBox(height: 25),
                            _buildDangerZone(),
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

  Widget _buildSaveButton() {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 10,
          left: 20,
          right: 20),
      child: ElevatedButton(
        onPressed: isLoading ? null : _saveDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: maviRenk,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text("Bilgileri Güncelle",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildSection(List<Widget> children, {String? title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 8),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Field field,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && obscure,
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: maviRenk, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: maviRenk),
                  onPressed: () => setState(() => obscure = !obscure))
              : null,
        ),
        validator: (v) => (field == Field.fullname && (v == null || v.isEmpty))
            ? "Boş bırakılamaz"
            : null,
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Expanded(
          child: TextFormField(
            controller: _phoneController,
            enabled: _isEditingPhone || _originalPhone.isEmpty,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined, color: maviRenk, size: 22),
              hintText: "5xx xxx xx xx",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onChanged: (_) {
              if (isPhoneVerified) setState(() => isPhoneVerified = false);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: !_isEditingPhone && _originalPhone.isNotEmpty
              ? TextButton(
                  onPressed: () => setState(() {
                    _isEditingPhone = true;
                    isPhoneVerified = false;
                  }),
                  child: const Text("Değiştir"),
                )
              : isPhoneVerified
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text("Doğrulandı",
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ]))
                  : isSmsSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: maviRenk))
                      : GestureDetector(
                          onTap: _sendSms,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text("Doğrula",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _buildDisabledRow({required IconData icon, required String val}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Icon(icon, color: maviRenk, size: 22),
        const SizedBox(width: 12),
        Text(val, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
      ]),
    );
  }

  // 🚀 EKLENEN ANA ÇÖZÜM BURASI
  Widget _buildNeighborhoodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: DropdownButtonFormField<String>(
        isExpanded:
            true, // ✅ EKLENDİ: Dropdown'un sağa taşmasını engeller (sığdırır)
        value: _selectedNeighborhood,
        icon: Icon(Icons.arrow_drop_down, color: maviRenk),
        style: const TextStyle(color: Colors.black, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon:
              Icon(Icons.location_city_outlined, color: maviRenk, size: 22),
          hintText: "Mahalle / Köy seçin",
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
        ),
        items: pazarcikMahalleleri
            .map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    m,
                    overflow: TextOverflow
                        .ellipsis, // ✅ EKLENDİ: Uzun metinlerde sondan "..." ekler
                  ),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedNeighborhood = v),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Column(children: [
      if (!widget.editPasswordOnly && authType == 'email')
        _buildSection([
          CheckboxListTile(
            title: const Text("Şifremi Değiştir",
                style: TextStyle(color: Colors.black, fontSize: 15)),
            value: changePassword,
            activeColor: maviRenk,
            onChanged: (v) => setState(() => changePassword = v!),
          )
        ]),
      if (changePassword || widget.editPasswordOnly) ...[
        const SizedBox(height: 15),
        _buildSection([
          _buildField(
              controller: _passwordController,
              icon: Icons.lock_outline,
              hint: "Yeni Şifre",
              field: Field.password,
              isPassword: true),
        ]),
      ],
    ]);
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 10, bottom: 8),
          child: Text(
            "HESAP",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : _confirmDeleteAccount,
          icon: const Icon(Icons.delete_outline),
          label: const Text("Hesabımı Sil"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    );
  }
}
