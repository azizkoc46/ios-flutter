import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const portalWelcomeSeenKey = 'portal_welcome_completed_v1';
const portalSplashPortrait = 'assets/portal_splash_portrait.jpg';
const portalSplashLandscape = 'assets/portal_splash_landscape.jpg';

/// Uygulamanın ana renk paleti
class _PortalColors {
  static const primaryBlue = Color(0xFF007AFF);
  static const accentOrange = Color(0xFFD85A22);
  static const accentGreen = Color(0xFF18806E);
  static const darkBackground = Color(0xFF111214);
  static const lightBackground = Color(0xFFF5F6FA);
  static const launchBgCenter = Color(0xFF162032);
  static const launchBgOuter = Color(0xFF080A0C);
}

/// Stores onboarding on this installation/browser, independent of sign-in.
class PortalWelcomeGate extends StatefulWidget {
  const PortalWelcomeGate({
    super.key,
    required this.child,
    this.initialCompleted,
    this.splashDuration = const Duration(milliseconds: 500),
  });

  final Widget child;
  final bool? initialCompleted;
  final Duration splashDuration;

  @override
  State<PortalWelcomeGate> createState() => _PortalWelcomeGateState();
}

class _PortalWelcomeGateState extends State<PortalWelcomeGate> {
  static bool _completedThisSession = false;
  late bool _loading;
  late bool _completed;
  bool _saving = false;
  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    final alreadyDone = widget.initialCompleted == true || _completedThisSession;
    _completed = alreadyDone;
    _loading = !alreadyDone;
    if (!alreadyDone) {
      _load();
    }
  }

  Future<void> _load() async {
    var completed = _completedThisSession;
    
    try {
      _preferences = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      completed = completed || (_preferences!.getBool(portalWelcomeSeenKey) ?? false);
    } catch (_) {
      // Depolama kısıtlamaları ziyaretçiyi asla uygulamanın dışında bırakmamalı.
    }
    
    // ⚡ Daha önce onboarding görülmüşse (her günlük açılış) splash beklemez.
    // İlk kez açılışta kısa bir bekleme yapılır.
    if (!completed) {
      await Future<void>.delayed(
          widget.splashDuration); // İlk kez: onboarding gösterilecek
    }
    
    if (!mounted) return; 
    
    setState(() {
      _loading = false;
      _completed = completed;
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    
    try {
      final preferences = _preferences ??
          await SharedPreferences.getInstance()
              .timeout(const Duration(seconds: 3));
      await preferences
          .setBool(portalWelcomeSeenKey, true)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Kalıcı depolama reddedilse bile mevcut oturumu kullanılabilir tut.
    }
    
    _completedThisSession = true;
    
    if (!mounted) return; 
    
    setState(() {
      _completed = true;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const PortalLaunchScreen();
    if (_completed) return widget.child;
    return PortalWelcomePages(onFinish: _finish, saving: _saving);
  }
}

class PortalLaunchScreen extends StatelessWidget {
  const PortalLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgOuter = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FA);
    final bgCenter = isDark ? const Color(0xFF162032) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF9AA7B6) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgOuter,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              bgCenter,
              bgOuter,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _PortalColors.primaryBlue.withOpacity(0.25),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/login.png',
                        width: 130,
                        height: 130,
                        semanticLabel: 'Pazarcık Portal logosu',
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Pazarcık Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Şehrin, hayatın, senin portalın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const CupertinoActivityIndicator(
                    color: _PortalColors.primaryBlue,
                    radius: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeSlide {
  const _WelcomeSlide(this.title, this.subtitle, this.body, this.icon, this.color);
  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final Color color;
}

// Sabit (const) liste olarak geri alındı. Çok daha performanslı.
const _slides = [
  _WelcomeSlide(
      'Hoş geldin, Pazarcıklı!',
      'Pazarcık şimdi yanında',
      'Haberler, duyurular ve günlük yaşamın ihtiyaçları aynı yerde. Şehrinde olup biteni keşfet.',
      CupertinoIcons.building_2_fill,
      _PortalColors.primaryBlue),
  _WelcomeSlide(
      'Mahallenin lezzetleri',
      'Yerel esnafla buluş',
      'Restoranları ve menülerini keşfet. Ayın indirimli menülerine göz at, siparişini kolayca ver.',
      Icons.restaurant_rounded,
      _PortalColors.accentOrange),
  _WelcomeSlide(
      'Fırsatları keşfet',
      'Aradığın belki de çok yakın',
      'İş ilanlarına, satılık ve kiralık ilanlarına göz at. Pazarcık’taki yeni fırsatlardan haberdar ol.',
      CupertinoIcons.tag_fill,
      _PortalColors.accentGreen),
  _WelcomeSlide(
      'Şehrinle buluş',
      'Birlikte daha güzel',
      'Meydanda paylaşımları takip et. Nöbetçi eczanelere, taksilere ve şehir rehberine kolayca ulaş.',
      CupertinoIcons.person_2_fill,
      _PortalColors.primaryBlue),
];

class PortalWelcomePages extends StatefulWidget {
  const PortalWelcomePages({
    super.key,
    required this.onFinish,
    this.saving = false,
  });
  
  final Future<void> Function() onFinish;
  final bool saving;

  @override
  State<PortalWelcomePages> createState() => _PortalWelcomePagesState();
}

class _PortalWelcomePagesState extends State<PortalWelcomePages> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? _PortalColors.darkBackground : _PortalColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: _index == 0
                            ? null
                            : IconButton(
                                tooltip: 'Önceki sayfa',
                                onPressed: widget.saving ? null : () => _go(_index - 1),
                                icon: const Icon(CupertinoIcons.chevron_back,
                                    color: _PortalColors.primaryBlue),
                              ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.saving ? null : widget.onFinish,
                        child: const Text('Atla',
                            style: TextStyle(
                                color: _PortalColors.primaryBlue, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      return _WelcomeSlideWidget(slide: _slides[index]);
                    },
                  ),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => _buildDotIndicator(index, dark),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.saving
                          ? null
                          : () {
                              if (_index == _slides.length - 1) {
                                widget.onFinish();
                              } else {
                                _go(_index + 1);
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: _PortalColors.primaryBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: widget.saving
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              _index == _slides.length - 1 ? 'Başlayalım' : 'Devam Et',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int index, bool isDark) {
    final muted = isDark ? const Color(0xFFBCC3CF) : const Color(0xFF616975);
    return Semantics(
      label: '${index + 1}. tanıtım sayfası',
      selected: _index == index,
      button: true,
      child: InkResponse(
        onTap: widget.saving ? null : () => _go(index),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              width: _index == index ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _index == index
                    ? _PortalColors.primaryBlue
                    : muted.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeSlideWidget extends StatelessWidget {
  final _WelcomeSlide slide;

  const _WelcomeSlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF171C26);
    final muted = dark ? const Color(0xFFBCC3CF) : const Color(0xFF616975);

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = constraints.maxHeight < 360 ? 100.0 : 164.0;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: slide.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(slide.icon, color: Colors.white, size: iconSize * 0.43),
                ),
                const SizedBox(height: 36),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 27,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? Colors.white : slide.color,
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 16,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}