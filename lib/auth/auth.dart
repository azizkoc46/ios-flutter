import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pazarcik_portal/main.dart';
import 'package:pazarcik_portal/auth/forgot_password.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/helpers/image_picker.dart';

class Auth extends StatefulWidget {
  static const routeName = '/auth-screen';
  const Auth({Key? key}) : super(key: key);

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool isLogin = true;
  File? profileImage;
  bool isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _auth = FirebaseAuth.instance;
  final firebase = FirebaseFirestore.instance;
  final cloudinary =
      CloudinaryPublic('dukmr152o', 'pazarcikportal', cache: false);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _fullnameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor:
            isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _selectPhoto(File img) => setState(() => profileImage = img);

  void _switchLog() {
    setState(() {
      isLogin = !isLogin;
      _formKey.currentState?.reset();
      _obscurePassword = true;
      _obscureConfirm = true;
    });
    _animController
      ..reset()
      ..forward();
  }

  Future<void> _signOutAnonymousBeforeRealAuth() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      debugPrint("Anonim oturum kapatılıyor: ${currentUser.uid}");
      await _auth.signOut();
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _saveUserAndNavigate(User user,
      {String? displayName, String? photoUrl, required String authType}) async {
    // Token'i zorla yeniliyoruz. Eger onceden anonim bir oturum vardiysa
    // ve simdi gercek bir hesaba gecildiyse, Firestore'a istek atmadan once
    // request.auth.uid'in guncel ve dogru kullaniciyi gostermesini garantiliyoruz.
    try {
      await user.getIdToken(true);
    } catch (e) {
      debugPrint("Token yenileme hatasi: $e");
    }

    final docRef = firebase.collection('customers').doc(user.uid);

    // KRITIK DUZELTME:
    // Auth durumu degistikten (signOut -> createUser/signIn) hemen sonra
    // gelen ilk Firestore istegi bazen request.auth henuz tam senkronize
    // olmadan gidebiliyor (token ve App Check tarafinda kisa bir
    // senkronizasyon farki). Bu durumda permission-denied alinir, ama
    // hemen ardindan tekrar denendiginde basarili olur. Bunu tolere etmek
    // icin kisa bir retry mekanizmasi kullaniyoruz.
    DocumentSnapshot<Map<String, dynamic>>? userDoc;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        userDoc = await docRef.get();
        break;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' && attempt < 2) {
          debugPrint(
              "Firestore okuma yarış durumu, yeniden deneniyor (deneme ${attempt + 1})");
          await Future.delayed(const Duration(milliseconds: 400));
          continue;
        }
        rethrow;
      }
    }

    if (userDoc != null && !userDoc.exists) {
      final newUserData = {
        'fullname': displayName ?? 'Pazarcık Üyesi',
        'email': user.email ?? '',
        'image': photoUrl ?? '',
        'role': 'customer',
        'isApproved': false,
        'auth-type': authType,
        'createdAt': Timestamp.now(),
      };

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await docRef.set(newUserData, SetOptions(merge: true));
          break;
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied' && attempt < 2) {
            debugPrint(
                "Firestore yazma yarış durumu, yeniden deneniyor (deneme ${attempt + 1})");
            await Future.delayed(const Duration(milliseconds: 400));
            continue;
          }
          rethrow;
        }
      }
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PazarcikAnaEkran()));
    }
  }

  Future<void> _handleAuth() async {
    final valid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    if (!valid) return;

    if (!isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      showSnackBar("Şifreler eşleşmiyor");
      return;
    }

    setState(() => isLoading = true);

    try {
      // KRITIK DUZELTME:
      // Uygulama acilisinda _ensureGuestSession() ile otomatik olarak
      // anonim bir oturum aciliyor. Kullanici email/password ile
      // giris ya da kayit yapmaya calistiginda, halen aktif olan bu
      // anonim oturum bazi firebase_auth surumlerinde native taraftan
      // donen kullanici verisinin Dart'a aktariminda tip hatasina
      // (PigeonUserDetails cast hatasi) yol aciyor. Bu hata
      // FirebaseAuthException olmadigi icin asagidaki genel catch
      // blogunda yakalanip ekranda sadece "Bir hata olustu" gosteriliyor.
      // Cozum: email/password islemine girmeden once, eger su an
      // oturum acmis kullanici anonim ise, once o oturumu kapatiyoruz.
      await _signOutAnonymousBeforeRealAuth();

      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim());

        // Giris sonrasi token'i tazeliyoruz
        await _auth.currentUser!.getIdToken(true);

        await _saveUserAndNavigate(_auth.currentUser!, authType: 'email');
      } else {
        final credential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim());

        // Anonim oturumu yukarida zaten kapattigimiz icin artik
        // credential.user, request.auth.uid ile uyumlu. Token'i
        // yine de tazeleyerek Firestore kurallarinin guncel kullaniciyi
        // gormesini garantiliyoruz.
        await credential.user!.getIdToken(true);

        debugPrint("Yeni kullanıcı UID: ${credential.user!.uid}");
        debugPrint("currentUser UID: ${_auth.currentUser?.uid}");

        String imageUrl = "";
        if (profileImage != null) {
          try {
            final response = await cloudinary.uploadFile(
                CloudinaryFile.fromFile(profileImage!.path,
                    resourceType: CloudinaryResourceType.Image));
            imageUrl = response.secureUrl;
          } catch (e) {
            debugPrint("Resim yükleme hatası: $e");
          }
        }

        // credential.user yerine guncel _auth.currentUser kullaniyoruz
        final activeUser = _auth.currentUser ?? credential.user!;

        final newCustomerData = {
          'fullname': _fullnameController.text.trim(),
          'email': _emailController.text.trim(),
          'image': imageUrl,
          'role': 'customer',
          'isApproved': false,
          'auth-type': 'email',
          'createdAt': Timestamp.now(),
        };

        // KRITIK DUZELTME:
        // signOut() -> createUserWithEmailAndPassword gecisinden hemen
        // sonraki ilk Firestore istegi, auth/App Check tarafindaki kisa
        // senkronizasyon farki nedeniyle permission-denied alabiliyor.
        // Kisa bir retry mekanizmasi ile bu yarış durumunu tolere ediyoruz.
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await firebase
                .collection('customers')
                .doc(activeUser.uid)
                .set(newCustomerData, SetOptions(merge: true));
            break;
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' && attempt < 2) {
              debugPrint(
                  "Kayıt yazma yarış durumu, yeniden deneniyor (deneme ${attempt + 1})");
              await Future.delayed(const Duration(milliseconds: 400));
              continue;
            }
            rethrow;
          }
        }

        showSnackBar("Hoş Geldiniz!", isError: false);
        if (mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PazarcikAnaEkran()));
        }
      }
    } on FirebaseAuthException catch (e) {
      final msg = _firebaseErrorMessage(e.code);
      showSnackBar(msg);
    } on FirebaseException catch (e) {
      // Firestore hatalarini ayri yakalayip logluyoruz (teshis icin).
      // Artik ekranda "Bir hata olustu" yerine gercek hata kodunu goreceksin.
      debugPrint("Firestore hatası: ${e.code} - ${e.message}");
      final signedUser = _auth.currentUser;
      if (signedUser != null && !signedUser.isAnonymous) {
        showSnackBar(
          "Giriş yapıldı, profil bilgileri sonra tamamlanacak.",
          isError: false,
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PazarcikAnaEkran()),
          );
        }
      } else {
        showSnackBar("Veritabanı hatası: ${e.code}");
      }
    } catch (e) {
      debugPrint("Bilinmeyen hata: $e");
      // Debug modda gercek hatayi goruyoruz, release modda kullaniciya
      // genel mesaj gosteriliyor (boylece teshis kolaylasiyor).
      if (kDebugMode) {
        showSnackBar("Hata: $e");
      } else {
        showSnackBar("Bir hata oluştu, tekrar deneyin.");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalıdır.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      default:
        return 'Giriş yapılamadı. Tekrar deneyin.';
    }
  }

  Future<void> _googleAuth() async {
    try {
      setState(() => isLoading = true);
      await _signOutAnonymousBeforeRealAuth();

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        final credential = await _auth.signInWithPopup(provider);
        final user = credential.user;
        if (user != null) {
          await _saveUserAndNavigate(
            user,
            displayName: user.displayName,
            photoUrl: user.photoURL,
            authType: 'google',
          );
        }
        return;
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final logCredential = await _auth.signInWithCredential(credential);
      await _saveUserAndNavigate(logCredential.user!,
          displayName: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
          authType: 'google');
    } on FirebaseAuthException catch (e) {
      debugPrint('Google giriş hatası: ${e.code} - ${e.message}');
      if (e.code == 'unauthorized-domain') {
        showSnackBar('Bu web adresi Firebase yetkili alanlarına eklenmemiş.');
      } else if (e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request') {
        showSnackBar("Google ile giriş başarısız: ${e.message ?? e.code}");
      }
    } catch (e) {
      debugPrint('Google giriş hatası: $e');
      showSnackBar("Google ile giriş başarısız.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _appleAuth() async {
    try {
      setState(() => isLoading = true);
      await _signOutAnonymousBeforeRealAuth();

      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final credential = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
      final user = credential.user;

      if (user != null) {
        final fallbackName = user.email?.split('@').first;
        await _saveUserAndNavigate(
          user,
          displayName: user.displayName ?? fallbackName,
          photoUrl: user.photoURL,
          authType: 'apple',
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Apple giriş hatası: ${e.code} - ${e.message}');
      if (e.code != 'web-context-cancelled' &&
          e.code != 'popup-closed-by-user' &&
          e.code != 'canceled') {
        showSnackBar('Apple ile giriş başarısız: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('Apple giriş hatası: $e');
      showSnackBar('Apple ile giriş başarısız.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 700;
    final hPad = size.width > 430 ? 40.0 : 28.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAEAF0),
                  Color(0xFFF2F2F7),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                      horizontal: hPad, vertical: isCompact ? 12 : 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'logo',
                          child: Container(
                            height: isCompact ? 90 : 110,
                            width: isCompact ? 90 : 110,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Image.asset(
                              'assets/login.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.storefront_rounded,
                                  size: 46,
                                  color: Color(0xFF007AFF)),
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 16 : 22),
                        Text(
                          isLogin ? "Pazarcık Portal" : "Hesap Oluştur",
                          style: GoogleFonts.inter(
                              fontSize: isCompact ? 26 : 30,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                              letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isLogin
                              ? "Devam etmek için giriş yapın"
                              : "Portal ayrıcalıkları için kayıt olun",
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: isCompact ? 20 : 30),
                        if (!isLogin) ...[
                          ProfileImagePicker(selectImage: _selectPhoto),
                          SizedBox(height: isCompact ? 16 : 22),
                        ],
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (!isLogin) ...[
                                _buildIOSField(
                                  controller: _fullnameController,
                                  icon: Icons.person_rounded,
                                  hint: "Ad Soyad",
                                  autofillHints: const [AutofillHints.name],
                                ),
                                SizedBox(height: isCompact ? 12 : 14),
                              ],
                              _buildIOSField(
                                controller: _emailController,
                                icon: Icons.mail_rounded,
                                hint: "E-posta",
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return "E-posta girin";
                                  if (!v.contains('@'))
                                    return "Geçerli e-posta girin";
                                  return null;
                                },
                              ),
                              SizedBox(height: isCompact ? 12 : 14),
                              _buildIOSField(
                                controller: _passwordController,
                                icon: Icons.lock_rounded,
                                hint: "Şifre",
                                isPassword: true,
                                obscure: _obscurePassword,
                                onObscureTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                autofillHints: isLogin
                                    ? const [AutofillHints.password]
                                    : const [AutofillHints.newPassword],
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return "Şifre girin";
                                  if (!isLogin && v.length < 6)
                                    return "En az 6 karakter olmalı";
                                  return null;
                                },
                              ),
                              if (!isLogin) ...[
                                SizedBox(height: isCompact ? 12 : 14),
                                _buildIOSField(
                                  controller: _confirmPasswordController,
                                  icon: Icons.shield_rounded,
                                  hint: "Şifre Tekrar",
                                  isPassword: true,
                                  obscure: _obscureConfirm,
                                  onObscureTap: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                  autofillHints: const [
                                    AutofillHints.newPassword
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return "Şifreyi tekrar girin";
                                    if (v != _passwordController.text)
                                      return "Şifreler eşleşmiyor";
                                    return null;
                                  },
                                ),
                              ],
                              if (isLogin)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4)),
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed(ForgotPassword.routeName),
                                    child: Text(
                                      "Şifremi Unuttum",
                                      style: GoogleFonts.inter(
                                          color: const Color(0xFF007AFF),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              SizedBox(height: isCompact ? 18 : 22),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                  ),
                                  onPressed: isLoading ? null : _handleAuth,
                                  child: isLoading
                                      ? const CupertinoActivityIndicator(
                                          color: Colors.white)
                                      : Text(
                                          isLogin ? "Giriş Yap" : "Kayıt Ol",
                                          style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isCompact ? 24 : 32),
                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Color(0xFFD1D1D6))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                "veya şununla devam et",
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF8E8E93),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: Color(0xFFD1D1D6))),
                          ],
                        ),
                        SizedBox(height: isCompact ? 18 : 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialButton(
                              icon: Icons.g_mobiledata_rounded,
                              color: const Color(0xFFEA4335),
                              label: "Google",
                              onTap: isLoading ? null : _googleAuth,
                            ),
                            if (kIsWeb ||
                                defaultTargetPlatform ==
                                    TargetPlatform.iOS) ...[
                              const SizedBox(width: 14),
                              _buildSocialButton(
                                icon: Icons.apple_rounded,
                                color: Colors.black,
                                label: "Apple",
                                onTap: isLoading ? null : _appleAuth,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: isCompact ? 18 : 24),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.of(context)
                                  .pushNamedAndRemoveUntil(
                                      '/home', (route) => false),
                          child: Text(
                            "Giriş yapmadan devam et",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF007AFF),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 18 : 24),
                        GestureDetector(
                          onTap: _switchLog,
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: const Color(0xFF1C1C1E)),
                              children: [
                                TextSpan(
                                    text: isLogin
                                        ? "Hesabınız yok mu? "
                                        : "Zaten üye misiniz? "),
                                TextSpan(
                                    text: isLogin ? "Kayıt Ol" : "Giriş Yap",
                                    style: const TextStyle(
                                        color: Color(0xFF007AFF),
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 12 : 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool obscure = true,
    VoidCallback? onObscureTap,
    TextInputType keyboardType = TextInputType.text,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? obscure : false,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction:
            isPassword ? TextInputAction.done : TextInputAction.next,
        style:
            GoogleFonts.inter(fontSize: 15.5, color: const Color(0xFF1C1C1E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.inter(color: const Color(0xFFC7C7CC), fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xFF8E8E93), size: 21),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF8E8E93),
                    size: 21,
                  ),
                  onPressed: onObscureTap,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          errorStyle: GoogleFonts.inter(fontSize: 11.5),
        ),
        validator: validator ??
            (v) => (v == null || v.isEmpty) ? "Lütfen doldurun" : null,
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E))),
          ],
        ),
      ),
    );
  }
}
