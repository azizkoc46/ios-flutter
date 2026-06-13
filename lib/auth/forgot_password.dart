import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPassword extends StatefulWidget {
  static const routeName = '/forgot-password';
  const ForgotPassword({Key? key}) : super(key: key);

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    final valid = _formKey.currentState!.validate();
    if (!valid) return;
    FocusScope.of(context).unfocus();

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      _showIOSDialog(
        "Bağlantı Gönderildi",
        "Şifre sıfırlama talimatları e-posta adresinize iletildi. Lütfen gelen kutunuzu kontrol edin.",
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      final msg = _firebaseErrorMessage(e.code);
      _showIOSDialog("Hata", msg);
    } catch (_) {
      _showIOSDialog(
          "Hata", "Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı bir hesap bulunamadı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      default:
        return 'Bir hata oluştu. Tekrar deneyin.';
    }
  }

  void _showIOSDialog(String title, String content, {bool isSuccess = false}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title:
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(content, style: GoogleFonts.inter(fontSize: 13)),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Tamam"),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (isSuccess) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 700;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1C1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE5E5EA),
                  Color(0xFFF2F2F7),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                    horizontal: 30, vertical: isCompact ? 12 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // İKON
                      Container(
                        height: isCompact ? 90 : 110,
                        width: isCompact ? 90 : 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 28,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: isCompact ? 52 : 62,
                          color: const Color(0xFF007AFF),
                        ),
                      ),

                      SizedBox(height: isCompact ? 20 : 28),

                      Text(
                        'Şifremi Unuttum',
                        style: GoogleFonts.inter(
                            fontSize: isCompact ? 24 : 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1E),
                            letterSpacing: -0.8),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kayıtlı e-posta adresinizi yazın,\nsize bir şifre yenileme bağlantısı gönderelim.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF8E8E93),
                            height: 1.55,
                            fontWeight: FontWeight.w500),
                      ),

                      SizedBox(height: isCompact ? 28 : 38),

                      // FORM
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) =>
                                    isLoading ? null : _handleForgotPassword(),
                                style: GoogleFonts.inter(
                                    color: const Color(0xFF1C1C1E),
                                    fontSize: 15.5),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.mail_rounded,
                                      color: Color(0xFF8E8E93), size: 21),
                                  hintText: 'E-posta adresiniz',
                                  hintStyle: GoogleFonts.inter(
                                      color: const Color(0xFFC7C7CC),
                                      fontSize: 15),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 17),
                                  errorStyle: GoogleFonts.inter(fontSize: 11.5),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'E-posta girin';
                                  if (!v.contains('@'))
                                    return 'Geçerli bir e-posta girin';
                                  return null;
                                },
                              ),
                            ),

                            SizedBox(height: isCompact ? 18 : 24),

                            // GÖNDER BUTONU
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF007AFF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                ),
                                onPressed:
                                    isLoading ? null : _handleForgotPassword,
                                child: isLoading
                                    ? const CupertinoActivityIndicator(
                                        color: Colors.white)
                                    : Text(
                                        'Bağlantı Gönder',
                                        style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isCompact ? 20 : 28),

                      // VAZGEÇ
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Vazgeç ve Giriş Ekranına Dön',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF007AFF),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
