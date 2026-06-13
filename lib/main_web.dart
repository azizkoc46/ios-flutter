import 'dart:js_interop';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'main.dart' show MyApp, isDarkModeNotifier;

@JS('removeSplashFromWeb')
external void removeSplashFromWeb();

/// Web, mobil uygulamanın gerçek widget ağacını kullanır. Bildirim kanalları,
/// arka plan mesajları ve cihaz App Check sağlayıcıları mobil main.dart'ta kalır.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await initializeDateFormatting('tr_TR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final preferences = await SharedPreferences.getInstance();
  isDarkModeNotifier.value = preferences.getBool('darkMode') ?? false;

  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    removeSplashFromWeb();
  });
}
