import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/phone_verification.dart';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key, required this.phone, this.gateway});
  final String phone;
  final PhoneVerificationGateway? gateway;

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  late final PhoneVerificationController _verification;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _focus = FocusNode();
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _verification = PhoneVerificationController(
      gateway: widget.gateway ?? FirebasePhoneVerificationGateway(),
      phone: widget.phone,
    )..addListener(_changed);

    // İsim soyisim hazırda varsa otomatik doldur
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser?.displayName != null &&
          authUser!.displayName!.trim().isNotEmpty) {
        _name.text = authUser.displayName!.trim();
      } else if (authUser != null) {
        FirebaseFirestore.instance
            .collection('customers')
            .doc(authUser.uid)
            .get()
            .then((doc) {
          if (doc.exists && mounted && _name.text.trim().isEmpty) {
            final data = doc.data();
            final n =
                data?['fullname'] ?? data?['fullName'] ?? data?['name'] ?? '';
            if (n.toString().trim().isNotEmpty) {
              setState(() {
                _name.text = n.toString().trim();
              });
            }
          }
        }).catchError((_) {});
      }
    } catch (_) {}
  }

  void _changed() {
    if (!mounted || _closed) return;
    if (_verification.done) {
      _closed = true;
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(widget.phone);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _verification.removeListener(_changed);
    _verification.dispose();
    _code.dispose();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _verification;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final foreground = dark ? Colors.white : const Color(0xFF1C1C1E);
    final muted = dark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);
    const blue = Color(0xFF007AFF);
    final busy = state.sending || state.verifying;

    return PopScope(
      canPop: !state.verifying,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Geri',
            onPressed:
                state.verifying ? null : () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.chevron_back),
          ),
          title: const Text('Telefon doğrulama',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                          state.verified
                              ? CupertinoIcons.checkmark_shield_fill
                              : CupertinoIcons.device_phone_portrait,
                          color:
                              state.verified ? const Color(0xFF34C759) : blue,
                          size: 60),
                      const SizedBox(height: 24),
                      Text(
                          state.verified
                              ? 'Numaranız doğrulandı'
                              : state.hasCode
                                  ? 'Doğrulama kodu'
                                  : 'Telefonunuzu doğrulayın',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: foreground)),
                      const SizedBox(height: 12),
                      Text(
                          state.verified
                              ? 'Telefon bilginizi profilinize kaydedelim.'
                              : state.hasCode
                                  ? '${widget.phone} numarasına gönderilen 6 haneli SMS kodunu girin.'
                                  : 'Hesabınızdaki telefon numarasını SMS ile doğrulayın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: muted, fontSize: 16, height: 1.5)),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(CupertinoIcons.phone,
                              color: blue, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(widget.phone,
                                  style: TextStyle(
                                      color: foreground,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600))),
                          IconButton(
                              tooltip: 'Numarayı değiştir',
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(CupertinoIcons.pencil,
                                  size: 20, color: blue)),
                        ]),
                      ),
                      if (state.hasCode && !state.verified) ...[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _code,
                          focusNode: _focus,
                          enabled: !busy,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.center,
                          enableSuggestions: false,
                          autocorrect: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6)
                          ],
                          style: TextStyle(
                              fontSize: 30,
                              letterSpacing: 0,
                              color: foreground,
                              fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                              labelText: 'SMS kodu',
                              hintText: '6 haneli kod',
                              hintStyle: TextStyle(fontSize: 18, color: muted),
                              filled: true,
                              fillColor: surface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: blue)),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16)),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => state.submit(_code.text),
                        ),
                      ],
                      if (state.verified) ...[
                        const SizedBox(height: 18),
                        TextField(
                          controller: _name,
                          enabled: !busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                              fontSize: 16,
                              color: foreground,
                              fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                              labelText: 'İsim Soyisim *',
                              hintText: 'Adınızı ve soyadınızı girin',
                              helperText: 'Profilinizde görünecek ad ve soyad',
                              helperStyle: TextStyle(color: muted, fontSize: 12),
                              prefixIcon: const Icon(CupertinoIcons.person_crop_circle,
                                  color: blue, size: 22),
                              hintStyle: TextStyle(fontSize: 15, color: muted),
                              filled: true,
                              fillColor: surface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: blue)),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16)),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: 18),
                        Semantics(
                            liveRegion: true,
                            child: Text(state.error!,
                                style: TextStyle(
                                    color: dark
                                        ? const Color(0xFFFF6961)
                                        : const Color(0xFFB42318),
                                    fontSize: 14,
                                    height: 1.5))),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: busy ||
                                (!state.hasCode &&
                                    state.secondsRemaining > 0) ||
                                (state.hasCode &&
                                    !state.verified &&
                                    _code.text.length != 6)
                            ? null
                            : () async {
                                if (state.verified) {
                                  final name = _name.text.trim();
                                  if (name.length < 3) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Lütfen adınızı ve soyadınızı eksiksiz girin.'),
                                        backgroundColor: Color(0xFFB42318),
                                      ),
                                    );
                                    return;
                                  }
                                  await state.submit(_code.text, name);
                                } else if (state.hasCode) {
                                  await state.submit(
                                      _code.text, _name.text.trim());
                                } else {
                                  await state.send();
                                }
                              },
                        child: busy
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const CupertinoActivityIndicator(),
                                    const SizedBox(width: 10),
                                    Flexible(
                                        child: Text(state.sending
                                            ? 'SMS isteniyor…'
                                            : 'Doğrulanıyor…'))
                                  ])
                            : Text(
                                state.verified
                                    ? 'Profilime kaydet'
                                    : state.hasCode
                                        ? 'Kodu doğrula'
                                        : state.secondsRemaining > 0
                                            ? '${state.secondsRemaining} saniye sonra tekrar gönder'
                                            : 'SMS kodu gönder',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (state.hasCode && !state.verified) ...[
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: busy || state.secondsRemaining > 0
                                ? null
                                : () async {
                                    _code.clear();
                                    await state.send();
                                  },
                            child: Text(
                                state.secondsRemaining > 0
                                    ? 'Tekrar gönder · ${state.secondsRemaining} sn'
                                    : 'Kodu tekrar gönder',
                                textAlign: TextAlign.center)),
                        Text(
                            'SMS henüz ulaşmadıysa numaranızı ve şebeke bağlantınızı kontrol edin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, height: 1.5, color: muted)),
                      ] else if (!state.verified) ...[
                        const SizedBox(height: 16),
                        Text(
                            'Devam ettiğinizde telefon numaranız doğrulama ve kötüye kullanımı önleme amacıyla Google ile paylaşılır.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, height: 1.5, color: muted)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
