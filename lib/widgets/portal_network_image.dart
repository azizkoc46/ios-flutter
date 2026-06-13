import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PortalNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const PortalNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl.isEmpty) return errorWidget ?? const SizedBox.shrink();

    return Image.network(
      normalizedUrl,
      width: width,
      height: height,
      fit: fit,
      webHtmlElementStrategy: kIsWeb
          ? WebHtmlElementStrategy.fallback
          : WebHtmlElementStrategy.never,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholder ??
            const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (_, __, ___) =>
          errorWidget ?? const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

String _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://')) {
    return 'https://${trimmed.substring('http://'.length)}';
  }
  return trimmed;
}
