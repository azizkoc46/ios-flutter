import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final VideoPlayerController? controller;
  final Duration? initialPosition;
  final bool autoPlay;

  const FullscreenVideoPlayer({
    Key? key,
    this.videoUrl,
    this.controller,
    this.initialPosition,
    this.autoPlay = true,
  })  : assert(videoUrl != null || controller != null,
            'videoUrl veya controller verilmelidir'),
        super(key: key);

  static Future<Duration?> open(
    BuildContext context, {
    String? videoUrl,
    VideoPlayerController? controller,
    Duration? initialPosition,
    bool autoPlay = true,
  }) {
    return Navigator.of(context).push<Duration>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: FullscreenVideoPlayer(
              videoUrl: videoUrl,
              controller: controller,
              initialPosition: initialPosition,
              autoPlay: autoPlay,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isOwnedController = false;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isMuted = false;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    // Tam ekran başlatılırken sistem çubuklarını daha şık yap
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.controller != null) {
      _controller = widget.controller!;
      _isOwnedController = false;
      _isInitialized = _controller.value.isInitialized;
      _isMuted = _controller.value.volume == 0;
      if (widget.initialPosition != null) {
        _controller.seekTo(widget.initialPosition!);
      }
      if (widget.autoPlay && !_controller.value.isPlaying) {
        _controller.play();
      }
      _controller.addListener(_controllerListener);
    } else {
      _isOwnedController = true;
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            if (widget.initialPosition != null) {
              _controller.seekTo(widget.initialPosition!);
            }
            if (widget.autoPlay) {
              _controller.play();
            }
          }
        });
      _controller.addListener(_controllerListener);
    }

    _startHideTimer();
  }

  void _controllerListener() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      _controller.play();
      _startHideTimer();
    }
  }

  void _seekRelative(int seconds) {
    final newPos = _controller.value.position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _controller.value.duration
            ? _controller.value.duration
            : newPos);
    _controller.seekTo(clamped);
    _startHideTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1.0);
    });
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${d.inHours}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_controllerListener);
    if (_isOwnedController) {
      _controller.dispose();
    }
    // Ekran yönünü ve sistem çubuklarını normale döndür
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exitFullscreen() {
    Navigator.of(context).pop(_controller.value.position);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Video Oynatıcı Alanı
              if (_isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio > 0
                        ? _controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(
                  child: CupertinoActivityIndicator(
                    radius: 20,
                    color: Color(0xFFFF5E62),
                  ),
                ),

              // 2. Kontrol Katmanı
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Üst Araç Çubuğu
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                // Çıkış Butonu
                                GestureDetector(
                                  onTap: _exitFullscreen,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.fullscreen_exit,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const Spacer(),

                                // Ses Aç / Kapat
                                GestureDetector(
                                  onTap: _toggleMute,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isMuted
                                          ? CupertinoIcons.volume_off
                                          : CupertinoIcons.volume_up,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Döndürme (Yatay/Dikey)
                                GestureDetector(
                                  onTap: _toggleOrientation,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isLandscape
                                          ? CupertinoIcons.device_phone_portrait
                                          : CupertinoIcons.device_phone_landscape,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Orta Kontroller (10sn Geri - Oynat/Durdur - 10sn İleri)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 10 sn geri
                              IconButton(
                                iconSize: 42,
                                icon: const Icon(
                                  CupertinoIcons.gobackward_10,
                                  color: Colors.white,
                                ),
                                onPressed: () => _seekRelative(-10),
                              ),
                              const SizedBox(width: 24),

                              // Oynat / Durdur
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFF5E62),
                                        Color(0xFFFF7E40)
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x66FF5E62),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _controller.value.isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),

                              // 10 sn ileri
                              IconButton(
                                iconSize: 42,
                                icon: const Icon(
                                  CupertinoIcons.goforward_10,
                                  color: Colors.white,
                                ),
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),

                          // Alt İlerleme Çubuğu & Süre Bilgisi
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(
                                          _controller.value.position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(
                                          _controller.value.duration),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    height: 18,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                          overlayRadius: 12,
                                        ),
                                        activeTrackColor:
                                            const Color(0xFFFF5E62),
                                        inactiveTrackColor:
                                            Colors.white.withOpacity(0.3),
                                        thumbColor: const Color(0xFFFF7E40),
                                      ),
                                      child: Slider(
                                        value: _isInitialized
                                            ? _controller
                                                .value.position.inMilliseconds
                                                .clamp(
                                                    0,
                                                    _controller.value.duration
                                                        .inMilliseconds)
                                                .toDouble()
                                            : 0.0,
                                        min: 0.0,
                                        max: _isInitialized &&
                                                _controller.value.duration
                                                        .inMilliseconds >
                                                    0
                                            ? _controller
                                                .value.duration.inMilliseconds
                                                .toDouble()
                                            : 1.0,
                                        onChanged: (val) {
                                          _controller.seekTo(Duration(
                                              milliseconds: val.toInt()));
                                          _startHideTimer();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
