// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Web tarayıcısında sayfa başlığı ve SEO görünürlüğünü dinamik güncelleyen yardımcı.
class PortalSeoHelper {
  static void updateTitle(String title) {
    if (!kIsWeb) return;
    try {
      final cleanTitle = title.trim();
      final pageTitle = cleanTitle.isEmpty
          ? "Pazarcık Portal — Bizim Memleketimiz"
          : "$cleanTitle | Pazarcık Portal";

      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
          label: pageTitle,
          primaryColor: 0xFF0056D2,
        ),
      );
    } catch (e) {
      debugPrint("SEO Title update error: $e");
    }
  }

  static void resetTitle() {
    updateTitle("");
  }
}
