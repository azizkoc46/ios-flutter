// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

class SahibindenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;

  const SahibindenImageViewer({
    Key? key,
    required this.images,
    this.initialIndex = 0,
    this.title = '',
  }) : super(key: key);

  /// Kolay açma metodu
  static void open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String title = '',
  }) {
    if (images.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => SahibindenImageViewer(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<SahibindenImageViewer> createState() => _SahibindenImageViewerState();
}

class _SahibindenImageViewerState extends State<SahibindenImageViewer> {
  late int _currentIndex;
  late PageController _pageController;
  final Map<int, TransformationController> _controllers = {};
  bool _isZoomed = false;
  final FocusNode _focusNode = FocusNode();

  final Color sahibindenYellow = const Color(0xFFFFE800);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  TransformationController _getController(int index) {
    if (!_controllers.containsKey(index)) {
      final c = TransformationController();
      c.addListener(() {
        final scale = c.value.getMaxScaleOnAxis();
        final zoomed = scale > 1.05;
        if (zoomed != _isZoomed) {
          setState(() => _isZoomed = zoomed);
        }
      });
      _controllers[index] = c;
    }
    return _controllers[index]!;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final c = _getController(_currentIndex);
    final currentScale = c.value.getMaxScaleOnAxis();
    final newScale = (currentScale + 0.5).clamp(1.0, 5.0);
    c.value = Matrix4.identity()..scale(newScale);
  }

  void _zoomOut() {
    final c = _getController(_currentIndex);
    final currentScale = c.value.getMaxScaleOnAxis();
    final newScale = (currentScale - 0.5).clamp(1.0, 5.0);
    if (newScale <= 1.05) {
      c.value = Matrix4.identity();
    } else {
      c.value = Matrix4.identity()..scale(newScale);
    }
  }

  void _resetZoom() {
    final c = _getController(_currentIndex);
    c.value = Matrix4.identity();
  }

  void _toggleDoubleTapZoom(TapDownDetails details) {
    final c = _getController(_currentIndex);
    if (c.value.getMaxScaleOnAxis() > 1.1) {
      c.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      c.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openInNewTab() {
    final url = widget.images[_currentIndex];
    if (url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prevPage();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextPage();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.96),
        body: Stack(
          children: [
            // Resim Kaydırıcı (PageView)
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _isZoomed = false;
                  });
                },
                itemBuilder: (context, index) {
                  final controller = _getController(index);
                  return GestureDetector(
                    onDoubleTapDown: _toggleDoubleTapZoom,
                    onDoubleTap: () {},
                    child: Center(
                      child: InteractiveViewer(
                        transformationController: controller,
                        minScale: 1.0,
                        maxScale: 5.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        clipBehavior: Clip.none,
                        child: PortalNetworkImage(
                          url: widget.images[index],
                          fit: BoxFit.contain,
                          errorWidget: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Üst Kontrol Çubuğu (Geri, Başlık, Sayfa Sayacı, Kapat)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 12,
                  16,
                  16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.black45,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Kapat Butonu
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Sayfa Sayacı & Başlık
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title.isNotEmpty)
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            "${_currentIndex + 1} / ${widget.images.length}",
                            style: TextStyle(
                              color: sahibindenYellow,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Yakınlaştırma Araçları (Web & Masaüstü için büyük kolaylık)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.zoom_out,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: "Uzaklaştır",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: _zoomOut,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 18,
                            ),
                            tooltip: "Sıfırla",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: _resetZoom,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: "Yakınlaştır",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: _zoomIn,
                          ),
                          if (kIsWeb)
                            IconButton(
                              icon: const Icon(
                                Icons.open_in_new,
                                color: Colors.white,
                                size: 18,
                              ),
                              tooltip: "Orijinal Resmi Aç",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: _openInNewTab,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sol Ok (Önceki Fotoğraf) - Masaüstü/Web için
            if (_currentIndex > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _prevPage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),

            // Sağ Ok (Sonraki Fotoğraf) - Masaüstü/Web için
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),

            // Alt Küçük Önizleme Şeridi (Thumbnails)
            if (widget.images.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.black45,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.images.length, (index) {
                          final isSelected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isSelected ? 52 : 42,
                              height: isSelected ? 52 : 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? sahibindenYellow
                                      : Colors.white24,
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: PortalNetworkImage(
                                  url: widget.images[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
