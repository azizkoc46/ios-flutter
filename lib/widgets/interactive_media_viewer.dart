import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

class InteractiveMediaViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? title;

  const InteractiveMediaViewer({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String? title,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: InteractiveMediaViewer(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
              title: title,
            ),
          );
        },
      ),
    );
  }

  @override
  State<InteractiveMediaViewer> createState() => _InteractiveMediaViewerState();
}

class _InteractiveMediaViewerState extends State<InteractiveMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _controllers = {};
  bool _showControls = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  TransformationController _getController(int index) {
    if (!_controllers.containsKey(index)) {
      _controllers[index] = TransformationController();
    }
    return _controllers[index]!;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleDoubleTap(int index) {
    final controller = _getController(index);
    if (controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
    } else {
      final zoomed = Matrix4.diagonal3Values(2.4, 2.4, 1.0)
        ..setTranslationRaw(-30.0, -30.0, 0.0);
      controller.value = zoomed;
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToPrevious();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToNext();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Resim Galerisi (PageView + InteractiveViewer + Mouse/Touch Drag Desteği)
            GestureDetector(
              onTap: () {
                setState(() => _showControls = !_showControls);
              },
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    // Önceki sayfaların zoom'unu sıfırla
                    _controllers.forEach((key, controller) {
                      if (key != index) {
                        controller.value = Matrix4.identity();
                      }
                    });
                  },
                  itemBuilder: (context, index) {
                    final url = widget.imageUrls[index];
                    final controller = _getController(index);

                    return GestureDetector(
                      onDoubleTap: () => _handleDoubleTap(index),
                      child: Center(
                        child: InteractiveViewer(
                          transformationController: controller,
                          minScale: 0.8,
                          maxScale: 4.5,
                          clipBehavior: Clip.none,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            placeholder: (context, _) => const Center(
                              child: CupertinoActivityIndicator(
                                color: Colors.white,
                                radius: 16,
                              ),
                            ),
                            errorWidget: (context, _, __) => const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.exclamationmark_triangle,
                                      color: Colors.white70, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    "Görsel yüklenemedi",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Sol Gezinme Oku (Masaüstü / Web & Dokunmatik için Önceki Resim)
            if (widget.imageUrls.length > 1 && _currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showControls ? 1.0 : 0.0,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white30, width: 1),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _goToPrevious,
                        child: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Sağ Gezinme Oku (Masaüstü / Web & Dokunmatik için Sonraki Resim)
            if (widget.imageUrls.length > 1 &&
                _currentIndex < widget.imageUrls.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showControls ? 1.0 : 0.0,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white30, width: 1),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _goToNext,
                        child: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(
                            CupertinoIcons.chevron_right,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Üst Kontrol Çubuğu (Geri/Kapat, Sayaç, Paylaş)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Kapat Butonu
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Sayfa Sayacı Rozeti (örn: 1 / 4)
                    if (widget.imageUrls.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          "${_currentIndex + 1} / ${widget.imageUrls.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Paylaş Butonu
                    GestureDetector(
                      onTap: () {
                        if (_currentIndex < widget.imageUrls.length) {
                          Share.share(widget.imageUrls[_currentIndex],
                              subject: "Pazarcık Meydan Görseli");
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.share,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Alt Tıklanabilir Nokta Göstergeleri
            if (widget.imageUrls.length > 1 && widget.imageUrls.length <= 10)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: _showControls
                    ? MediaQuery.of(context).padding.bottom + 20
                    : -50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.imageUrls.length, (index) {
                    final isSelected = _currentIndex == index;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF5E62)
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
