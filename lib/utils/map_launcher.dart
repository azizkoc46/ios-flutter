import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PortalMapLauncher {
  const PortalMapLauncher._();

  static Future<void> open(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? address,
    String? fallbackUrl,
  }) async {
    final hasCoords = latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;
    final query = hasCoords ? '$latitude,$longitude' : (address ?? '').trim();

    if (query.isEmpty && (fallbackUrl == null || fallbackUrl.trim().isEmpty)) {
      _snack(context, 'Konum bilgisi bulunamadı.');
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final appleUri = Uri.parse(hasCoords
          ? 'https://maps.apple.com/?daddr=$query'
          : 'https://maps.apple.com/?q=${Uri.encodeComponent(query)}');
      final googleUri = _googleUri(query, fallbackUrl);

      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Haritada aç'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _launch(context, appleUri);
              },
              child: const Text('Apple Maps'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _launch(context, googleUri);
              },
              child: const Text('Google Maps / Web'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
        ),
      );
      return;
    }

    await _launch(context, _googleUri(query, fallbackUrl));
  }

  static Uri _googleUri(String query, String? fallbackUrl) {
    final cleanFallback = fallbackUrl?.trim() ?? '';
    if (cleanFallback.isNotEmpty) return Uri.parse(cleanFallback);
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
  }

  static Future<void> _launch(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _snack(context, 'Harita uygulaması açılamadı.');
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
