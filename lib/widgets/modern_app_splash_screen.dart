import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Açılış / Karşılama Ekranı Veri Modeli (4K Video & Görsel Sponsorluk Desteği)
class StartupAnnouncementModel {
  final bool isActive;
  final String mediaType; // 'video' veya 'image'
  final String mediaUrl;
  final String fallbackImageUrl;
  final String badgeText;
  final String title;
  final String body;
  final String buttonText;
  final String linkUrl;
  final int autoCloseSeconds;
  final String showFrequency; // 'always', 'once_daily', 'once_per_update'
  final bool allowSkip;
  final DateTime? updatedAt;

  const StartupAnnouncementModel({
    required this.isActive,
    this.mediaType = 'image',
    required this.mediaUrl,
    this.fallbackImageUrl = '',
    this.badgeText = 'GÜNÜN SPONSORU 💎',
    required this.title,
    required this.body,
    this.buttonText = 'Fırsatı İncele ➔',
    this.linkUrl = '',
    this.autoCloseSeconds = 6,
    this.showFrequency = 'always',
    this.allowSkip = true,
    this.updatedAt,
  });

  factory StartupAnnouncementModel.fromMap(Map<String, dynamic> map) {
    // Medya URL'sinden otomatik video tespiti fallback
    final url = (map['mediaUrl'] ?? '').toString();
    String detectedType = (map['mediaType'] ?? '').toString().toLowerCase();
    if (detectedType.isEmpty) {
      final lower = url.toLowerCase();
      if (lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.m4v') ||
          lower.contains('video')) {
        detectedType = 'video';
      } else {
        detectedType = 'image';
      }
    }

    return StartupAnnouncementModel(
      isActive: map['isActive'] == true,
      mediaType: detectedType,
      mediaUrl: url,
      fallbackImageUrl: (map['fallbackImageUrl'] ?? '').toString(),
      badgeText: (map['badgeText'] ?? 'GÜNÜN SPONSORU 💎').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      buttonText: (map['buttonText'] ?? 'Fırsatı İncele ➔').toString(),
      linkUrl: (map['linkUrl'] ?? '').toString(),
      autoCloseSeconds: (map['autoCloseSeconds'] as num?)?.toInt() ?? 6,
      showFrequency: (map['showFrequency'] ?? 'always').toString(),
      allowSkip: map['allowSkip'] != false,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as dynamic).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'fallbackImageUrl': fallbackImageUrl,
      'badgeText': badgeText,
      'title': title,
      'body': body,
      'buttonText': buttonText,
      'linkUrl': linkUrl,
      'autoCloseSeconds': autoCloseSeconds,
      'showFrequency': showFrequency,
      'allowSkip': allowSkip,
    };
  }
}

/// Ultra-Modern, Animasyonlu ve Tüm Cihazlara Uyumlu Açılış / Karşılama Ekranı
class ModernAppSplashScreen extends StatefulWidget {
  final StartupAnnouncementModel announcement;

  const ModernAppSplashScreen({
    Key? key,
    required this.announcement,
  }) : super(key: key);

  /// Açılış ekranını tam ekran / modal olarak açar
  static Future<void> show(BuildContext context, StartupAnnouncementModel announcement) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: announcement.allowSkip,
      barrierLabel: 'Açılış Ekranı',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) {
        return ModernAppSplashScreen(announcement: announcement);
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ModernAppSplashScreen> createState() => _ModernAppSplashScreenState();
}

class _ModernAppSplashScreenState extends State<ModernAppSplashScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoError = false;
  bool _isMuted = true;

  int _remainingSeconds = 6;
  Timer? _countdownTimer;

  late AnimationController _animController;
  late Animation<double> _contentSlideAnim;

  double _btnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.announcement.autoCloseSeconds;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _contentSlideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    // Video Modu ise başlat
    if (widget.announcement.mediaType == 'video' && widget.announcement.mediaUrl.isNotEmpty) {
      _initVideo();
    }

    // Sayaç Başlat
    _startTimer();
  }

  Future<void> _initVideo() async {
    try {
      final uri = Uri.parse(widget.announcement.mediaUrl);
      _videoController = VideoPlayerController.networkUrl(uri);
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.setVolume(0.0); // Web ve mobilde oto-oynatma için başta sessiz
      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isMuted = true;
        });
      }
    } catch (e) {
      debugPrint('[ModernAppSplashScreen] Video başlatma hatası: $e');
      if (mounted) {
        setState(() {
          _isVideoError = true;
        });
      }
    }
  }

  void _startTimer() {
    if (_remainingSeconds <= 0) return; // Sayaçsız mod

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 1) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = 0;
          timer.cancel();
          // Süre dolunca otomatik kapat
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    });
  }

  void _toggleMute() {
    if (_videoController == null || !_isVideoInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  Future<void> _handleAction() async {
    final link = widget.announcement.linkUrl.trim();
    if (link.isEmpty) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    // Modal penceresini kapat
    Navigator.of(context, rootNavigator: true).pop();

    // 1. İç Rota ise (Örn: /esnaf-paketleri, /reklam-paketleri, /firsatlar)
    if (link.startsWith('/')) {
      try {
        Navigator.of(context).pushNamed(link);
        return;
      } catch (_) {}
    }

    // 2. Dış Web Bağlantısı ise
    try {
      final uri = Uri.parse(link.startsWith('http') ? link : 'https://$link');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[ModernAppSplashScreen] Bağlantı açılamadı: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _videoController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktopOrTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          // Tablet & Masaüstü Web için şık çerçeve, mobilde tam ekran
          width: isDesktopOrTablet ? 460 : double.infinity,
          height: isDesktopOrTablet ? 780 : double.infinity,
          constraints: BoxConstraints(
            maxHeight: size.height,
            maxWidth: size.width,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF090D16),
            borderRadius: isDesktopOrTablet ? BorderRadius.circular(28) : BorderRadius.zero,
            boxShadow: isDesktopOrTablet
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ]
                : null,
            border: isDesktopOrTablet
                ? Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. ARKA PLAN: 4K VIDEO VEYA 4K GÖRSEL
              _buildMediaBackground(),

              // 2. KARARTMA VE ESTETİK GRADIENT KATMANLARI
              _buildGradients(),

              // 3. ÜST BAR: ROZET, SES KONTROLÜ VE ATLA/KAPAT BUTONU
              _buildTopControls(),

              // 4. ALT İÇERİK: BAŞLIK, AÇIKLAMA VE İNSAN ELİ DEĞMİŞ BUTON
              _buildBottomContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBackground() {
    final isVideo = widget.announcement.mediaType == 'video';

    if (isVideo && !_isVideoError && widget.announcement.mediaUrl.isNotEmpty) {
      if (_isVideoInitialized && _videoController != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width > 0 ? _videoController!.value.size.width : 1080,
            height: _videoController!.value.size.height > 0 ? _videoController!.value.size.height : 1920,
            child: VideoPlayer(_videoController!),
          ),
        );
      } else {
        // Video yüklenirken zarif poster veya yükleniyor göstergesi
        return Container(
          color: const Color(0xFF0F172A),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(color: Colors.white, radius: 16),
                const SizedBox(height: 12),
                Text(
                  '4K Medya Yükleniyor...',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Görsel Modu (veya video hata verirse fallback)
    if (widget.announcement.mediaUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.announcement.mediaUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => Container(
          color: const Color(0xFF0F172A),
          child: const Center(child: CupertinoActivityIndicator(color: Colors.white)),
        ),
        errorWidget: (context, url, error) => _buildFallbackVisual(),
      );
    }

    return _buildFallbackVisual();
  }

  Widget _buildFallbackVisual() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF042F2E)],
        ),
      ),
      child: Center(
        child: Icon(Icons.stars_rounded, size: 80, color: Colors.white.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _buildGradients() {
    return Positioned.fill(
      child: Column(
        children: [
          // Üst Karartma (Status bar ve butonlar için)
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Spacer(),
          // Alt Karartma (Metin ve CTA butonun kusursuz okunması için)
          Container(
            height: 380,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.88),
                  const Color(0xFF090D16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    final hasAudio = widget.announcement.mediaType == 'video' && _isVideoInitialized;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sol: Şık Cam Rozet (Sponsor / Fırsat)
              if (widget.announcement.badgeText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFFFBBF24), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        widget.announcement.badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),

              // Sağ: Ses Kontrolü ve Geri Sayımlı Atla Butonu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ses Butonu
                  if (hasAudio)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: _toggleMute,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Icon(
                            _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Atla / Kapat Butonu (İnsan Eli Tasarımı)
                  if (widget.announcement.allowSkip)
                    InkWell(
                      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _remainingSeconds > 0 ? 'Atla ($_remainingSeconds)' : 'Kapat',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ],
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
  }

  Widget _buildBottomContent() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _contentSlideAnim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _contentSlideAnim.value),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                if (widget.announcement.title.isNotEmpty)
                  Text(
                    widget.announcement.title,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),

                // Açıklama / Gövde
                if (widget.announcement.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.announcement.body,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8, offset: const Offset(0, 1)),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 18),

                // 🔥 PROFESYONEL, İNSAN ELİ DEĞMİŞ CTA BUTONU
                GestureDetector(
                  onTapDown: (_) => setState(() => _btnScale = 0.96),
                  onTapUp: (_) {
                    setState(() => _btnScale = 1.0);
                    _handleAction();
                  },
                  onTapCancel: () => setState(() => _btnScale = 1.0),
                  child: AnimatedScale(
                    scale: _btnScale,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1), // Canlı Indigo
                            Color(0xFF8B5CF6), // Canlı Mor
                            Color(0xFFEC4899), // Pembe Işıltı
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.announcement.buttonText.isNotEmpty
                                ? widget.announcement.buttonText
                                : 'Fırsatı İncele ➔',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

                // Daha Sonra Geç Butonu
                if (widget.announcement.allowSkip) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      child: Text(
                        'Şimdi Değil, Daha Sonra',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

