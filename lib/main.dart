// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/web_responsive_wrapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pazarcik_portal/views/cekgonder.dart';
import 'package:pazarcik_portal/views/bildirimkutusuanasayfa.dart';
import 'package:pazarcik_portal/auth/forgot_password.dart';
import 'package:pazarcik_portal/business/BusinessDetailPage.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/store/store_details.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/product/details.dart';
import 'package:pazarcik_portal/isilani/job_detail_page.dart';
import 'firebase_options.dart';
import 'onboarding/portal_welcome.dart';
import 'package:pazarcik_portal/services/notification_service.dart';
import 'package:pazarcik_portal/services/prayer_time_service.dart';
import 'package:pazarcik_portal/services/weather_service.dart';
import 'package:pazarcik_portal/core/home_buttons.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/providers/cart.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/providers/order.dart';
import 'package:pazarcik_portal/services/kible_pusulasi.dart';

// Ekranlar
import 'package:pazarcik_portal/auth/auth.dart';
import 'package:pazarcik_portal/profil/profile.dart';

import 'package:app_links/app_links.dart';
import 'package:pazarcik_portal/sahibinden/ad_detail_page.dart';
import 'package:pazarcik_portal/ilanveduyuru/ilan_duyurular_page.dart';

import 'package:pazarcik_portal/services/earthquake_page.dart';
import 'package:pazarcik_portal/kamu/public_directory_page.dart';
import 'package:pazarcik_portal/kamu/muhtarliklar_page.dart';
import 'package:pazarcik_portal/views/pharmacy_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pazarcik_portal/utils/quotes_pool.dart';
import 'package:pazarcik_portal/services/system_settings_service.dart';
import 'package:pazarcik_portal/widgets/security_gate_wrapper.dart';
import 'package:pazarcik_portal/services/news_slider_service.dart';
import 'package:pazarcik_portal/grup/grup_ana_ekran.dart';
import 'package:pazarcik_portal/business/BusinessDirectoryPage.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/customer/customer_bottomNav.dart';
import 'package:pazarcik_portal/sahibinden/ads_main_page.dart';
import 'package:pazarcik_portal/isilani/job_listing_page.dart';
import 'package:pazarcik_portal/news_page.dart';

// Global Kontrolcüler
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> _checkAndRefreshSellerSubscription() async {
  try {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      var doc = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        bool isEnabled = doc.data()?['sellerNotificationEnabled'] ?? false;
        if (isEnabled) {
          await FirebaseMessaging.instance
              .subscribeToTopic("seller_${user.uid}");
          debugPrint("🚀 Hafıza Tazelendi: Esnaf sipariş konusuna bağlı.");
        }
      }
    }
  } catch (e) {
    debugPrint("Hafıza tazeleme hatası: $e");
  }
}

Future<void> _ensureGuestSession() async {
  if (SystemSettingsService.instance.blockAnonymousUsers) {
    debugPrint("Kayıtsız/anonim kullanıcılar engellendi. Misafir oturumu açılmıyor.");
    return;
  }
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return;

  try {
    await auth.signInAnonymously();
    debugPrint("Misafir oturumu açıldı.");
  } catch (e) {
    debugPrint("Misafir oturumu açılamadı: $e");
  }
}

bool _initialWelcomeSeen = false;

void _startPostLaunchServices() {
  SystemSettingsService.instance.init();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    _ensureGuestSession().catchError((e) => debugPrint('Guest session hatası: $e'));
    _checkAndRefreshSellerSubscription().catchError((e) => debugPrint('Seller subscription hatası: $e'));
    if (!kIsWeb) {
      try {
        if (kDebugMode) {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.deviceCheck,
          );
        } else {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.deviceCheck,
          );
        }
      } catch (e) {
        debugPrint('App Check başlatma hatası: $e');
      }

      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('FCM background handler hatası: $e');
      }

      try {
        await NotificationService().initialize(navigatorKey);
      } catch (e) {
        debugPrint("Bildirim servisi başlatma hatası: $e");
      }
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔑 Mobil cihazlarda sistem barları saydam başlar (Siyah flash ve ani UI sıçramasını önler)
  if (!kIsWeb) {
    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
    } catch (_) {}
  }

  if (kIsWeb) {
    try {
      usePathUrlStrategy();
    } catch (e) {
      debugPrint("UrlStrategy hatası: $e");
    }
  }

  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    debugPrint('DateFormatting hatası: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      await FirebaseAuth.instance.setLanguageCode('tr');
    } catch (_) {}
    // ⚡ Çevrimdışı / zayıf ağlarda verilerin anında yüklenmesi için Firestore kalıcı önbelleği
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase başlatma hatası: $e');
  }

  // ⚡ Yerel ayarları hızlıca diskten oku (Ağ beklemesi yok, anında açılır)
  try {
    final prefs = await SharedPreferences.getInstance();
    isDarkModeNotifier.value = prefs.getBool('darkMode') ?? false;
    _initialWelcomeSeen = prefs.getBool('portal_welcome_completed_v1') ?? false;
  } catch (e) {
    debugPrint('SharedPreferences hatası: $e');
  }

  // 🚀 Flutter UI anında ekrana çizilir! Ağ beklemesi ve Play Integrity blokajı sıfır!
  runApp(const MyApp());

  // Arka plan servisleri ilk render tamamlandıktan sonra başlar
  _startPostLaunchServices();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartData()),
        ChangeNotifierProvider(create: (_) => OrderData()),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: isDarkModeNotifier,
        builder: (context, isDark, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Pazarcık Portal',
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'SF Pro Display',
              colorSchemeSeed: const Color(0xFF0056D2),
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8F9FA),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                scrolledUnderElevation: 0,
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: 'SF Pro Display',
              colorSchemeSeed: const Color(0xFF38BDF8),
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0B0F19),
              canvasColor: const Color(0xFF0B0F19),
              cardColor: const Color(0xFF131B2E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                scrolledUnderElevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: const Color(0xFF131B2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
                ),
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Color(0xFF131B2E),
                surfaceTintColor: Colors.transparent,
              ),
              dividerColor: Colors.white.withOpacity(0.08),
            ),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown,
              },
            ),
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return WebResponsiveWrapper(
                isDark: isDark,
                child: child,
              );
            },
            home: PortalWelcomeGate(
              initialCompleted: _initialWelcomeSeen,
              child: const RootAuthorityCheck(),
            ),
            onGenerateRoute: (RouteSettings settings) {
              final name = settings.name ?? '';
              final uri = Uri.tryParse(name.startsWith('/')
                  ? 'https://pazarcikportal.com$name'
                  : 'https://pazarcikportal.com/$name');
              final base = Uri.base;

              Map<String, String> mergedParams = {};
              mergedParams.addAll(base.queryParameters);
              if (uri != null) {
                mergedParams.addAll(uri.queryParameters);
              }
              if (base.fragment.isNotEmpty) {
                String frag = base.fragment;
                if (frag.startsWith('#')) frag = frag.substring(1);
                if (frag.startsWith('/')) frag = frag.substring(1);
                final fragUri = Uri.tryParse('https://pazarcikportal.com/$frag');
                if (fragUri != null) {
                  mergedParams.addAll(fragUri.queryParameters);
                }
              }

              final path = (uri != null && uri.path.isNotEmpty && uri.path != '/')
                  ? uri.path.toLowerCase()
                  : base.path.toLowerCase();

              String id = mergedParams['id'] ??
                  mergedParams['docId'] ??
                  mergedParams['adId'] ??
                  mergedParams['ilanId'] ??
                  mergedParams['isletmeId'] ??
                  mergedParams['jobId'] ??
                  '';

              if (id.isEmpty) {
                if (uri != null && uri.pathSegments.length >= 2) {
                  id = uri.pathSegments.last;
                } else if (base.pathSegments.length >= 2) {
                  id = base.pathSegments.last;
                }
              }

              if (id.isNotEmpty) {
                if (path.contains('ilan') ||
                    path.contains('classified') ||
                    path.contains('/ad')) {
                  return MaterialPageRoute(
                    builder: (_) =>
                        PortalDeepLinkDetailScreen(type: 'ilan', id: id),
                    settings: settings,
                  );
                }
                if (path.contains('isletme') ||
                    path.contains('business') ||
                    path.contains('rehber')) {
                  return MaterialPageRoute(
                    builder: (_) =>
                        PortalDeepLinkDetailScreen(type: 'isletme', id: id),
                    settings: settings,
                  );
                }
                if (path.contains('/is/') ||
                    path.contains('job') ||
                    path.contains('isilani') ||
                    path.endsWith('/is')) {
                  return MaterialPageRoute(
                    builder: (_) =>
                        PortalDeepLinkDetailScreen(type: 'is', id: id),
                    settings: settings,
                  );
                }
                if (path.contains('magaza') ||
                    path.contains('store') ||
                    path.contains('esnaf') ||
                    path.contains('seller')) {
                  return MaterialPageRoute(
                    builder: (_) =>
                        PortalDeepLinkDetailScreen(type: 'magaza', id: id),
                    settings: settings,
                  );
                }
              }

              // 🌐 Web Doğrudan URL Yönlendirmeleri
              if (path == '/kamu' || path == '/kamu-rehberi' || path == '/resmi-kurumlar') {
                return MaterialPageRoute(
                  builder: (_) => const PublicDirectoryPage(),
                  settings: settings,
                );
              }
              if (path == '/muhtarliklar' || path == '/muhtarlik') {
                return MaterialPageRoute(
                  builder: (_) => const MuhtarliklarPage(),
                  settings: settings,
                );
              }
              if (path == '/nobetci-eczane' || path == '/eczane') {
                return MaterialPageRoute(
                  builder: (_) => const PharmacyScreen(),
                  settings: settings,
                );
              }
              if (path == '/ilanlar' || path == '/sahibinden') {
                return MaterialPageRoute(
                  builder: (_) => const AdsMainPage(),
                  settings: settings,
                );
              }
              if (path == '/is-ilanlari' || path == '/is-ilani') {
                return MaterialPageRoute(
                  builder: (_) => const JobListingPage(),
                  settings: settings,
                );
              }
              if (path == '/haberler') {
                return MaterialPageRoute(
                  builder: (_) => const NewsPage(),
                  settings: settings,
                );
              }
              if (path == '/cekgonder') {
                return MaterialPageRoute(
                  builder: (_) => const CekGonderPage(),
                  settings: settings,
                );
              }

              return null;
            },
            routes: {
              '/home': (context) => const PortalHome(),
              '/profile': (context) => const ProfileScreen(),
              '/forgot-password': (context) => const ForgotPassword(),
              '/auth-screen': (context) => const Auth(),
              '/kamu': (context) => const PublicDirectoryPage(),
              '/resmi-kurumlar': (context) => const PublicDirectoryPage(),
              '/muhtarliklar': (context) => const MuhtarliklarPage(),
              '/nobetci-eczane': (context) => const PharmacyScreen(),
              '/eczane': (context) => const PharmacyScreen(),
              '/ilanlar': (context) => const AdsMainPage(),
              '/is-ilanlari': (context) => const JobListingPage(),
              '/haberler': (context) => const NewsPage(),
              '/cekgonder': (context) => const CekGonderPage(),
            },
          );
        },
      ),
    );
  }
}

class PortalDeepLinkDetailScreen extends StatefulWidget {
  final String type;
  final String id;

  const PortalDeepLinkDetailScreen({
    super.key,
    required this.type,
    required this.id,
  });

  @override
  State<PortalDeepLinkDetailScreen> createState() =>
      _PortalDeepLinkDetailScreenState();
}

class _PortalDeepLinkDetailScreenState
    extends State<PortalDeepLinkDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _debugInfo;
  dynamic _loadedData;
  String _resolvedType = '';

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  String _cleanId(String raw) {
    var cleaned = raw.trim();
    while (cleaned.startsWith('=') ||
        cleaned.startsWith('?') ||
        cleaned.startsWith('/') ||
        cleaned.startsWith('"') ||
        cleaned.startsWith("'")) {
      cleaned = cleaned.substring(1).trim();
    }
    while (cleaned.endsWith('"') ||
        cleaned.endsWith("'") ||
        cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    try {
      return Uri.decodeComponent(cleaned);
    } catch (_) {
      return cleaned;
    }
  }

  String _resolveTargetId() {
    if (widget.id.trim().isNotEmpty) return _cleanId(widget.id);

    final base = Uri.base;

    // 1. queryParameters
    String id = base.queryParameters['id'] ??
        base.queryParameters['docId'] ??
        base.queryParameters['adId'] ??
        base.queryParameters['ilanId'] ??
        base.queryParameters['isletmeId'] ??
        base.queryParameters['jobId'] ??
        '';
    if (id.isNotEmpty) return _cleanId(id);

    // 2. Fragment
    if (base.fragment.isNotEmpty) {
      String frag = base.fragment;
      if (frag.startsWith('#')) frag = frag.substring(1);
      if (frag.startsWith('/')) frag = frag.substring(1);
      final fragUri = Uri.tryParse('https://pazarcikportal.com/$frag');
      if (fragUri != null) {
        id = fragUri.queryParameters['id'] ??
            fragUri.queryParameters['docId'] ??
            fragUri.queryParameters['adId'] ??
            '';
        if (id.isNotEmpty) return _cleanId(id);
        if (fragUri.pathSegments.length >= 2) {
          return _cleanId(fragUri.pathSegments.last);
        }
      }
    }

    // 3. Regex on raw URL
    final rawUrl = base.toString();
    final match = RegExp(r'[?&](?:id|docId|adId|ilanId)=([^&#]+)').firstMatch(rawUrl);
    if (match != null && match.group(1) != null) {
      return _cleanId(match.group(1)!);
    }

    // 4. Path segments
    if (base.pathSegments.length >= 2) {
      return _cleanId(base.pathSegments.last);
    }

    return '';
  }

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _ensureGuestSession();
    } catch (_) {}

    final targetId = _resolveTargetId();
    debugPrint("PortalDeepLinkDetailScreen: type=${widget.type}, targetId='$targetId', url=${Uri.base}");

    if (targetId.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = "İlan veya içerik bağlantısı eksik (ID bulunamadı).";
          _debugInfo = "URL: ${Uri.base}";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // 1. classified_ads & ads & ilanlar
      try {
        final doc = await FirebaseFirestore.instance
            .collection('classified_ads')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['docId'] = doc.id;
          if (mounted) {
            setState(() {
              _loadedData = data;
              _resolvedType = 'ilan';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("classified_ads err: $e");
      }

      try {
        final q = await FirebaseFirestore.instance
            .collection('classified_ads')
            .where('adId', isEqualTo: targetId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final docItem = q.docs.first;
          final data = Map<String, dynamic>.from(docItem.data());
          data['docId'] = docItem.id;
          if (mounted) {
            setState(() {
              _loadedData = data;
              _resolvedType = 'ilan';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      try {
        final doc = await FirebaseFirestore.instance
            .collection('ads')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['docId'] = doc.id;
          if (mounted) {
            setState(() {
              _loadedData = data;
              _resolvedType = 'ilan';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 2. businesses (Doc ID & where id)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'isletme';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 3. job_ads & job_postings
      try {
        final doc = await FirebaseFirestore.instance
            .collection('job_ads')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'is';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      try {
        final doc = await FirebaseFirestore.instance
            .collection('job_postings')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'is';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 4. products (Esnaf Ürünü)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'product';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 5. sellers (Mağaza)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('sellers')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'magaza';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 6. announcements (Duyurular / Etkinlikler)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('announcements')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'announcement';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 7. posts (Grup / Dernek Gönderisi)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(targetId)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _loadedData = doc;
              _resolvedType = 'post';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _errorMessage =
              "Aradığınız içerik bulunamadı veya yayından kaldırılmış olabilir.";
          _debugInfo = "Aranan Kimlik: $targetId";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("İçerik yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "İçerik yüklenirken bir hata oluştu.";
          _debugInfo = "Hata detayı: $e (ID: $targetId)";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080A0C),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 16, color: Colors.white),
              SizedBox(height: 16),
              Text(
                "İçerik yükleniyor...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _loadedData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Pazarcık Portal"),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PortalHome()),
                (route) => false,
              );
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? "İçerik bulunamadı.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (_debugInfo != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _debugInfo!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fetchContent,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tekrar Dene"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const PortalHome()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: const Text("Anasayfaya Dön"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayType = _resolvedType.isNotEmpty ? _resolvedType : widget.type;
    if (displayType == 'ilan') {
      return AdDetailPage(ad: _loadedData as Map<String, dynamic>);
    } else if (displayType == 'isletme') {
      return BusinessDetailPage(doc: _loadedData as DocumentSnapshot);
    } else if (displayType == 'is') {
      final doc = _loadedData as DocumentSnapshot;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return JobDetailPage(job: data, docId: doc.id);
    } else if (displayType == 'magaza') {
      return StoreDetails(store: _loadedData as DocumentSnapshot);
    } else if (displayType == 'product') {
      return DetailsScreen(product: _loadedData as DocumentSnapshot);
    } else if (displayType == 'announcement') {
      return const IlanDuyurularPage();
    }

    return const PortalHome();
  }
}

class RootAuthorityCheck extends StatelessWidget {
  const RootAuthorityCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortalHome();
  }
}

class PortalHome extends StatelessWidget {
  const PortalHome({super.key});

  @override
  Widget build(BuildContext context) => const SecurityGateWrapper(
        child: VersionCheckWrapper(
          child: StartupAnnouncementWrapper(child: PazarcikAnaEkran()),
        ),
      );
}

class PazarcikAnaEkran extends StatefulWidget {
  const PazarcikAnaEkran({super.key});

  @override
  State<PazarcikAnaEkran> createState() => _PazarcikAnaEkranState();
}

class _PazarcikAnaEkranState extends State<PazarcikAnaEkran> {
  static bool _webInstallPromptShown = false;
  static const String _androidStoreUrl =
      "https://play.google.com/store/apps/details?id=com.pp.pazarckportal.pazarckportal";
  static const String _iosStoreUrl = "https://apps.apple.com/app/id6779951979";

  int _seciliIndex = 0;
  final PrayerTimeService _prayerService = PrayerTimeService();
  final WeatherService _weatherService = WeatherService();
  dynamic _weatherData;
  Timer? _namazTimer;
  bool namazBildirimAcik = true;

  List<String> _dutyPharmacies = [];
  int _currentDutyIndex = 0;
  Timer? _dutyPharmacyTimer;

  Map<String, String> _currentQuote = QuotesPool.getRandomQuoteSync();
  List<LiveNewsModel> _liveNews = [];
  bool _newsLoading = true;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // ℹ️ immersiveSticky zaten main()'de başlatıldı, burada tekrar çağrılmaz
      try {
        _initDeepLinks();
      } catch (_) {}
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkInitialWebDeepLink();
      });
    }
    _ayarlariYukle();
    _baslangicVerileriniYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWebInstallPrompt();
    });
  }

  void _checkInitialWebDeepLink() {
    try {
      final base = Uri.base;
      Uri targetUri = base;
      if (base.fragment.isNotEmpty && (base.fragment.contains('?') || base.fragment.contains('/'))) {
        String frag = base.fragment;
        if (frag.startsWith('/')) frag = frag.substring(1);
        final parsed = Uri.tryParse('https://${base.host}/$frag');
        if (parsed != null) targetUri = parsed;
      }
      _handleDeepLink(targetUri);
    } catch (e) {
      debugPrint("Web deep link hatası: $e");
    }
  }

  void _initDeepLinks() {
    try {
      _appLinks = AppLinks();

      _appLinks.getInitialLink().then((uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      }).catchError((err) {
        debugPrint("getInitialLink hatası: $err");
      });

      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleDeepLink(uri);
        },
        onError: (err) {
          debugPrint("uriLinkStream hatası: $err");
        },
      );
    } catch (e) {
      debugPrint("AppLinks başlatma hatası: $e");
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    try {
      debugPrint("Deep link kontrol ediliyor: $uri");
      String path = uri.path.toLowerCase();
      Map<String, String> queryParams = Map<String, String>.from(uri.queryParameters);
      List<String> pathSegments = uri.pathSegments;

      if (uri.fragment.isNotEmpty) {
        String frag = uri.fragment;
        if (frag.startsWith('#')) frag = frag.substring(1);
        if (frag.startsWith('/')) frag = frag.substring(1);
        final fragUri = Uri.tryParse('https://pazarcikportal.com/$frag');
        if (fragUri != null) {
          if (fragUri.path.isNotEmpty && fragUri.path != '/') {
            path = fragUri.path.toLowerCase();
            pathSegments = fragUri.pathSegments;
          }
          if (fragUri.queryParameters.isNotEmpty) {
            queryParams.addAll(fragUri.queryParameters);
          }
        }
      }

      String id = queryParams['id'] ?? queryParams['docId'] ?? queryParams['adId'] ?? '';
      if (id.isEmpty && pathSegments.length >= 2) {
        id = pathSegments.last;
      }

      if (id.isEmpty) {
        debugPrint("Deep link ID'si bulunamadı veya anasayfa.");
        return;
      }

      final navContext = navigatorKey.currentContext ?? context;
      if (!mounted) return;

      if (path.contains('ilan') || path.contains('classified') || path.contains('ad')) {
        final doc = await FirebaseFirestore.instance.collection('classified_ads').doc(id).get();
        if (doc.exists && mounted) {
          final adData = Map<String, dynamic>.from(doc.data()!);
          adData['docId'] = doc.id;
          Navigator.of(navContext).push(
            MaterialPageRoute(builder: (_) => AdDetailPage(ad: adData)),
          );
          return;
        }
      }

      if (path.contains('isletme') || path.contains('business') || path.contains('rehber')) {
        final doc = await FirebaseFirestore.instance.collection('businesses').doc(id).get();
        if (doc.exists && mounted) {
          Navigator.of(navContext).push(
            MaterialPageRoute(builder: (_) => BusinessDetailPage(doc: doc)),
          );
          return;
        }
      }

      if (path.contains('is') || path.contains('job')) {
        final doc = await FirebaseFirestore.instance.collection('job_ads').doc(id).get();
        if (doc.exists && mounted && doc.data() != null) {
          Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (_) => JobDetailPage(job: doc.data()!, docId: id),
            ),
          );
          return;
        }
      }

      if (path.contains('magaza') || path.contains('store') || path.contains('esnaf') || path.contains('seller')) {
        final doc = await FirebaseFirestore.instance.collection('sellers').doc(id).get();
        if (doc.exists && mounted) {
          Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (_) => StoreDetails(store: doc),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Deep link açılırken hata: $e");
    }
  }

  Future<void> _ayarlariYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          namazBildirimAcik = prefs.getBool('namazBildirim') ?? true;
        });
      }
    } catch (e) {
      debugPrint("Ayarlar yükleme hatası: $e");
    }

    _namazTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _prayerService.hesaplaGeriSayim(() {
          setState(() {});
        }, namazBildirimAcik);
      }
    });
  }

  Future<void> _baslangicVerileriniYukle() async {
    // ⚡ AŞAMA 1: Tüm verileri yerel hafızadan (0 ms) anında göster (Sıfır bekleme!)
    try {
      final cachedWeather = await _weatherService.getCachedWeather();
      if (cachedWeather != null && mounted) {
        setState(() => _weatherData = cachedWeather);
      }

      final cachedVakitler = await _prayerService.getCachedVakitler();
      if (cachedVakitler.isNotEmpty && mounted) {
        setState(() {});
      }

      final cachedNews = await NewsSliderService.getCachedTopNews(limit: 5);
      if (cachedNews.isNotEmpty && mounted) {
        setState(() {
          _liveNews = cachedNews;
          _newsLoading = false;
        });
      }

      final cachedDuty = await PharmacyService.getCachedDuty(allowStale: true);
      if (cachedDuty != null && cachedDuty.list.isNotEmpty && mounted) {
        _setDutyPharmaciesFromList(cachedDuty.list);
      }
    } catch (e) {
      debugPrint("Önbellekten ilk yükleme hatası: $e");
    }

    // 🚀 AŞAMA 2: Canlı verileri arka planda PARALEL olarak sorgula
    // Hiçbir servis diğerinin bitmesini beklemez, gelen veri anında ekrana yansır!
    _weatherService.getWeather("Pazarcık").then((weather) {
      if (mounted && weather != null) {
        setState(() => _weatherData = weather);
      }
    }, onError: (e) {
      debugPrint("Hava durumu canlı çekme hatası: $e");
    });

    _prayerService.fetchVakitler().then((_) {
      if (mounted) setState(() {});
    }, onError: (e) {
      debugPrint("Namaz vakti canlı çekme hatası: $e");
    });

    NewsSliderService.fetchTopNews(limit: 5, forceRefresh: true).then((news) {
      if (mounted && news.isNotEmpty) {
        setState(() {
          _liveNews = news;
          _newsLoading = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _newsLoading = false);
    });

    _loadDutyPharmacies();
  }

  Future<void> _loadDutyPharmacies() async {
    try {
      // 1. Varsa önbellekteki nöbetçileri derhal göster
      final cached = await PharmacyService.getCachedDuty(allowStale: true);
      if (cached != null && cached.list.isNotEmpty) {
        _setDutyPharmaciesFromList(cached.list);
      }

      // 2. Canlı veriyi Google Apps Script API'den paralel çek
      final live = await PharmacyService.fetchDuty();
      if (live != null && live.list.isNotEmpty) {
        _setDutyPharmaciesFromList(live.list);
      }
    } catch (e) {
      debugPrint("Canlı nöbetçi eczane yükleme hatası: $e");
    }
  }

  void _setDutyPharmaciesFromList(List<Map<String, dynamic>> list) {
    List<String> formatted = [];
    for (var item in list) {
      String name = (item['name'] ?? '').toString().trim();
      String address = (item['address'] ?? '').toString().toLowerCase();
      if (name.isNotEmpty) {
        if (address.contains('narlı') || address.contains('narli')) {
          formatted.add("$name (Narlı)");
        } else {
          formatted.add(name);
        }
      }
    }

    if (formatted.isNotEmpty && mounted) {
      setState(() {
        _dutyPharmacies = formatted;
        _currentDutyIndex = 0;
      });

      _dutyPharmacyTimer?.cancel();
      if (_dutyPharmacies.length > 1) {
        _dutyPharmacyTimer = Timer.periodic(const Duration(milliseconds: 2600), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _currentDutyIndex = (_currentDutyIndex + 1) % _dutyPharmacies.length;
          });
        });
      }
    }
  }

  Future<void> _maybeShowWebInstallPrompt() async {
    if (!kIsWeb || _webInstallPromptShown || !mounted) return;

    final platform = defaultTargetPlatform;
    final bool isIos = platform == TargetPlatform.iOS;
    final bool isAndroid = platform == TargetPlatform.android;
    if (!isIos && !isAndroid) return;

    // Kullanıcı son 24 saat içinde kapattıysa tekrar rahatsız etme
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDismissed = prefs.getInt('web_install_dismissed_ts') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastDismissed < 24 * 60 * 60 * 1000) return;
    } catch (_) {}

    _webInstallPromptShown = true;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final storeUrl = isIos ? _iosStoreUrl : _androidStoreUrl;
    final title = isIos ? "Pazarcık Portal iPhone'da!" : "Pazarcık Portal Android'de!";
    final subtitle = isIos
        ? "App Store'dan ücretsiz indirin, nöbetçi eczane ve sipariş bildirimlerini anında cebinizden takip edin."
        : "Google Play'den ücretsiz indirin, nöbetçi eczane ve sipariş bildirimlerini anında cebinizden takip edin.";
    final icon = isIos ? CupertinoIcons.device_phone_portrait : Icons.android_rounded;
    final accent = isIos ? const Color(0xFF007AFF) : const Color(0xFF10B981);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return SafeArea(
          child: Align(
            alignment: size.width > 600 ? Alignment.bottomRight : Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width < 400 ? size.width - 32 : 380,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2430) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: accent.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: accent.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isIos
                                      ? [const Color(0xFF007AFF), const Color(0xFF0056D2)]
                                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isIos ? "App Store" : "Google Play",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(dialogContext);
                                try {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setInt('web_install_dismissed_ts', DateTime.now().millisecondsSinceEpoch);
                                } catch (_) {}
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  size: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                try {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setInt('web_install_dismissed_ts', DateTime.now().millisecondsSinceEpoch);
                                } catch (_) {}
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade500,
                                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              child: const Text("Daha Sonra"),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                final uri = Uri.parse(storeUrl);
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(CupertinoIcons.arrow_down_circle_fill, size: 18),
                              label: const Text(
                                "Uygulamayı İndir",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _namazTimer?.cancel();
    _dutyPharmacyTimer?.cancel();
    super.dispose();
  }

  Future<void> _externalLinkAc(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<Map<String, dynamic>> _defaultTaxiItems() {
    return [];
  }

  List<Map<String, dynamic>> _defaultRoadsideItems() {
    return [];
  }

  String _taxiTelUrl(dynamic item) {
    if (item is Map) {
      final tel = (item['telUrl'] ?? '').toString().trim();
      if (tel.isNotEmpty) return tel;
      final phone = (item['phone'] ?? item['telefon'] ?? '')
          .toString()
          .replaceAll(RegExp(r'[^0-9+]'), '');
      if (phone.isNotEmpty) {
        return phone.startsWith('+') ? 'tel:$phone' : 'tel:+90$phone';
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _parseTaxiItems(dynamic rawList) {
    if (rawList is! List) return [];
    final parsed = <Map<String, dynamic>>[];
    for (final element in rawList) {
      if (element is Map) {
        final map = Map<String, dynamic>.from(element);
        if (map['isActive'] != false) {
          parsed.add(map);
        }
      }
    }
    return parsed;
  }

  List<Map<String, dynamic>> _parseRoadsideItems(dynamic rawList) {
    if (rawList is! List) return [];
    final parsed = <Map<String, dynamic>>[];
    for (final element in rawList) {
      if (element is Map) {
        final map = Map<String, dynamic>.from(element);
        if (map['isActive'] != false) {
          parsed.add(map);
        }
      }
    }
    return parsed;
  }

  void _showTaxiMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('app_settings')
            .doc('taxi_numbers')
            .get()
            .then((snap) async {
          if (snap.exists && snap.data() != null) return snap;
          return FirebaseFirestore.instance
              .collection('app_settings')
              .doc('taxi_services')
              .get();
        }),
        builder: (context, snapshot) {
          final items = snapshot.hasData && snapshot.data!.data() != null
              ? _parseTaxiItems(snapshot.data!.data()!['items'])
              : _defaultTaxiItems();

          if (items.isEmpty) {
            return CupertinoActionSheet(
              title: const Text(
                'Alo Taksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              message: const Text('Kayıtlı taksi durağı bulunmuyor.'),
              cancelButton: CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
            );
          }

          return CupertinoActionSheet(
            title: const Text(
              'Alo Taksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            message: const Text('Hızlı taksi çağırmak için durağı seçiniz:'),
            actions: items.map((item) => _buildTaxiOption(item)).toList(),
            cancelButton: CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
          );
        },
      ),
    );
  }

  CupertinoActionSheetAction _buildTaxiOption(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Taksi Durağı').toString();
    final phone = (item['phone'] ?? '').toString();
    final telUrl = _taxiTelUrl(item);

    return CupertinoActionSheetAction(
      onPressed: () {
        Navigator.pop(context);
        _externalLinkAc(telUrl);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.phone_fill, size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              phone.isNotEmpty ? '$name ($phone)' : name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoadsideMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('app_settings')
            .doc('roadside_services')
            .get(),
        builder: (context, snapshot) {
          final items = snapshot.hasData && snapshot.data!.data() != null
              ? _parseRoadsideItems(snapshot.data!.data()!['items'])
              : _defaultRoadsideItems();

          if (items.isEmpty) {
            return CupertinoActionSheet(
              title: const Text(
                '7/24 Yol Yardım & Çekici',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              message: const Text('Kayıtlı çekici veya yol yardım hizmeti bulunmuyor.'),
              cancelButton: CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
            );
          }

          return CupertinoActionSheet(
            title: const Text(
              '7/24 Yol Yardım & Çekici',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            message: const Text('Hızlı yol yardım veya çekici çağırmak için seçiniz:'),
            actions: items.map((item) => _buildRoadsideOption(item)).toList(),
            cancelButton: CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
          );
        },
      ),
    );
  }

  CupertinoActionSheetAction _buildRoadsideOption(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Çekici / Yol Yardım').toString();
    final phone = (item['phone'] ?? '').toString();
    final telUrl = _taxiTelUrl(item);

    return CupertinoActionSheetAction(
      onPressed: () {
        Navigator.pop(context);
        _externalLinkAc(telUrl);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.phone_fill, size: 18, color: Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              phone.isNotEmpty ? '$name ($phone)' : name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllCategoriesSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final categories = [
          {'title': 'Haberler', 'icon': CupertinoIcons.news_solid, 'color': const Color(0xFF3B82F6), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsPage()))},
          {'title': 'Etkinlikler & Duyurular', 'icon': CupertinoIcons.calendar, 'color': const Color(0xFFEC4899), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IlanDuyurularPage()))},
          {'title': 'Yeme & İçme (Sipariş)', 'icon': CupertinoIcons.bag_fill, 'color': const Color(0xFFF97316), 'onTap': () => setState(() => _seciliIndex = 1)},
          {'title': 'İkinci El (Al & Sat)', 'icon': CupertinoIcons.tag_fill, 'color': const Color(0xFF10B981), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsMainPage()))},
          {'title': 'İş İlanları (Kariyer)', 'icon': CupertinoIcons.briefcase_fill, 'color': const Color(0xFF8B5CF6), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobListingPage()))},
          {'title': 'İşletmeler Rehberi', 'icon': CupertinoIcons.building_2_fill, 'color': const Color(0xFF06B6D4), 'onTap': () => setState(() => _seciliIndex = 3)},
          {'title': 'Topluluk & Meydan', 'icon': CupertinoIcons.chat_bubble_2_fill, 'color': const Color(0xFFFF5E62), 'onTap': () => setState(() => _seciliIndex = 2)},
          {'title': 'Deprem Bilgi & Acil', 'icon': CupertinoIcons.waveform_path_ecg, 'color': const Color(0xFFEF4444), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarthquakePage()))},
          {'title': 'Nöbetçi Eczaneler', 'icon': CupertinoIcons.bandage_fill, 'color': const Color(0xFFE11D48), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyScreen()))},
          {'title': 'Kamu & Acil Numaralar', 'icon': CupertinoIcons.shield_fill, 'color': const Color(0xFF0284C7), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicDirectoryPage()))},
          {'title': 'Alo Taksi', 'icon': CupertinoIcons.car_detailed, 'color': const Color(0xFFF59E0B), 'onTap': _showTaxiMenu},
          {'title': '7/24 Yol Yardım (Çekici)', 'icon': CupertinoIcons.car_fill, 'color': const Color(0xFF0284C7), 'onTap': _showRoadsideMenu},
          {'title': 'Çek Gönder (Sorun Bildir)', 'icon': CupertinoIcons.camera_fill, 'color': const Color(0xFF14B8A6), 'onTap': () {
              if (FirebaseAuth.instance.currentUser == null) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Çek Gönder özelliğini kullanmak için lütfen giriş yapın."),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CekGonderPage()));
            }},
          {'title': 'Kıble Pusulası', 'icon': CupertinoIcons.compass_fill, 'color': const Color(0xFF10B981), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KiblePusulasiEkrani()))},
        ];

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tüm Hizmetler & Kategoriler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 24),
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final item = categories[index];
                    final color = item['color'] as Color;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(ctx);
                        (item['onTap'] as VoidCallback)();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withOpacity(0.2), width: 1),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item['icon'] as IconData, color: color, size: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title'] as String,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body;
    switch (_seciliIndex) {
      case 0:
        body = _buildAnaSayfaContent(isDark);
        break;
      case 1:
        body = CustomerBottomNav(
          onReturnToPortal: () {
            setState(() {
              _seciliIndex = 0;
            });
          },
        );
        break;
      case 2:
        body = const GrupAnaEkran();
        break;
      case 3:
        body = const BusinessDirectoryPage();
        break;
      case 4:
        body = const ProfileScreen();
        break;
      default:
        body = _buildAnaSayfaContent(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: _seciliIndex == 1
          ? null
          : Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildMagicBottomNav(isDark),
              ),
            ),
    );
  }

  Widget _buildAnaSayfaContent(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        await _baslangicVerileriniYukle();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          _buildHeaderBrandBar(isDark),
          const SizedBox(height: 12),
          _buildSearchBar(isDark),
          const SizedBox(height: 12),
          _buildQuotesCard(isDark),
          const SizedBox(height: 12),
          _buildTopQuickCards(isDark),
          const SizedBox(height: 14),
          _buildPrayerAndWeatherCard(isDark),
          const SizedBox(height: 18),
          _buildHizmetlerHeader(isDark),
          const SizedBox(height: 10),
          _buildHizmetlerGrid(isDark),
          const SizedBox(height: 14),
          _buildTumKategorilerBanner(isDark),
          const SizedBox(height: 20),
          _buildGundemSection(isDark),
          const SizedBox(height: 20),
          _buildEtkinliklerSection(isDark),
          const SizedBox(height: 20),
          _buildSonIlanlarSection(isDark),
          const SizedBox(height: 20),
          _buildCekGonderBanner(isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderBrandBar(bool isDark) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(CupertinoIcons.location_solid, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAZARCIK',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Kahramanmaraş',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        // Tema değiştirme butonu
        IconButton(
          onPressed: () {
            isDarkModeNotifier.value = !isDarkModeNotifier.value;
          },
          icon: ValueListenableBuilder<bool>(
            valueListenable: isDarkModeNotifier,
            builder: (_, dark, __) => Icon(
              dark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
              color: dark ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
              size: 22,
            ),
          ),
        ),
        // Bildirim butonu (Canlı Okunmamış Rozeti ile)
        _buildNotificationBellButton(isDark),
      ],
    );
  }

  Widget _buildNotificationBellButton(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BildirimKutusuAnaSayfa()),
          );
        },
        icon: const Icon(CupertinoIcons.bell_fill, size: 22),
        color: isDark ? Colors.white70 : const Color(0xFF334155),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('to', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BildirimKutusuAnaSayfa()),
                );
              },
              icon: const Icon(CupertinoIcons.bell_fill, size: 22),
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF0B0F19) : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        readOnly: true,
        onTap: _showAllCategoriesSheet,
        decoration: InputDecoration(
          hintText: "Pazarcık'ta ne aramak istersiniz?",
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
          prefixIcon: const Icon(CupertinoIcons.search, size: 20, color: Color(0xFF3B82F6)),
          suffixIcon: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.slider_horizontal_3, size: 16, color: Color(0xFF3B82F6)),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildQuotesCard(bool isDark) {
    final text = _currentQuote['text'] ?? 'Birlik ve beraberlik içinde daha güzel bir Pazarcık.';
    final author = _currentQuote['author'] ?? 'Pazarcık Portal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2430), const Color(0xFF181C26)]
              : [const Color(0xFFEFF6FF), const Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFBFDBFE).withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.quote_bubble_fill, size: 16, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$text"',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '— $author',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
            color: isDark ? Colors.white54 : Colors.grey.shade500,
            tooltip: "Farklı Söz Getir",
            onPressed: () {
              setState(() {
                _currentQuote = QuotesPool.getRandomQuoteSync(forceNew: true);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopQuickCards(bool isDark) {
    return Row(
      children: [
        // 1. Nöbetçi Eczane (Dinamik Dönen İsimler)
        Expanded(
          child: _buildActionPill(
            isDark: isDark,
            title: "Nöbetçi Eczane",
            subtitle: _dutyPharmacies.isNotEmpty
                ? _dutyPharmacies[_currentDutyIndex % _dutyPharmacies.length]
                : "Bugün Açık",
            customSubtitleWidget: _dutyPharmacies.isNotEmpty
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.45),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _dutyPharmacies[_currentDutyIndex % _dutyPharmacies.length],
                      key: ValueKey<String>(
                        "duty-$_currentDutyIndex-${_dutyPharmacies[_currentDutyIndex % _dutyPharmacies.length]}",
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                      ),
                    ),
                  )
                : null,
            icon: CupertinoIcons.bandage_fill,
            gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PharmacyScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // 2. 7/24 Yol Yardım & Çekici
        Expanded(
          child: _buildActionPill(
            isDark: isDark,
            title: "7/24 Yol Yardım",
            subtitle: "Oto Kurtarma & Çekici",
            icon: CupertinoIcons.car_fill,
            gradient: const [Color(0xFF0284C7), Color(0xFF0369A1)],
            onTap: _showRoadsideMenu,
          ),
        ),
        const SizedBox(width: 8),
        // 3. Alo Taksi
        Expanded(
          child: _buildActionPill(
            isDark: isDark,
            title: "Alo Taksi",
            subtitle: "Hemen Çağır",
            icon: CupertinoIcons.car_detailed,
            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            onTap: _showTaxiMenu,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required bool isDark,
    required String title,
    required String subtitle,
    Widget? customSubtitleWidget,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gradient.first.withOpacity(isDark ? 0.3 : 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              if (customSubtitleWidget != null)
                customSubtitleWidget
              else
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerAndWeatherCard(bool isDark) {
    final nextVakit = _prayerService.siradakiVakitAd.isNotEmpty &&
            _prayerService.siradakiVakitAd != "Yükleniyor..."
        ? _prayerService.siradakiVakitAd
        : "Vakit";
    final vakitSaati = _prayerService.siradakiVakitSaati.isNotEmpty
        ? _prayerService.siradakiVakitSaati
        : (_prayerService.namazVakitleri[nextVakit] ?? "");
    final countdown = _prayerService.geriSayim.isNotEmpty
        ? _prayerService.geriSayim
        : "--:--:--";
    final temp = _weatherData != null && _weatherData['sicaklik'] != null
        ? "${_weatherData['sicaklik']}°C"
        : "18°C";
    final condition = _weatherData != null && _weatherData['durum'] != null
        ? "${_weatherData['durum']}"
        : "Açık";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Namaz Vakti Sol Bölüm
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.moon_stars_fill,
                        color: Color(0xFFFBBF24), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      vakitSaati.isNotEmpty
                          ? '$nextVakit ($vakitSaati)'
                          : '$nextVakit Vaktine',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  countdown,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 38,
            width: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(width: 14),
          // Hava Durumu Sağ Bölüm
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.sun_max_fill,
                      color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    temp,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                condition,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Kıble Pusulası Butonu
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KiblePusulasiEkrani()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.compass,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHizmetlerHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Hizmetler",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _showAllCategoriesSheet,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Row(
            children: [
              Text(
                "Tümü",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6),
                ),
              ),
              SizedBox(width: 2),
              Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFF3B82F6)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHizmetlerGrid(bool isDark) {
    final items = [
      {
        'title': 'Haberler',
        'subtitle': 'Pazarcık & Maraş',
        'icon': CupertinoIcons.news_solid,
        'color': const Color(0xFF3B82F6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsPage())),
      },
      {
        'title': 'Etkinlikler',
        'subtitle': 'Duyuru & Taziye',
        'icon': CupertinoIcons.calendar,
        'color': const Color(0xFFEC4899),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IlanDuyurularPage())),
      },
      {
        'title': 'Yeme & İçme',
        'subtitle': 'Paket Sipariş',
        'icon': CupertinoIcons.bag_fill,
        'color': const Color(0xFFF97316),
        'onTap': () => setState(() => _seciliIndex = 1),
      },
      {
        'title': 'İkinci El',
        'subtitle': 'Alış & Satış',
        'icon': CupertinoIcons.tag_fill,
        'color': const Color(0xFF10B981),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsMainPage())),
      },
      {
        'title': 'İş İlanları',
        'subtitle': 'Kariyer & Eleman',
        'icon': CupertinoIcons.briefcase_fill,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobListingPage())),
      },
      {
        'title': 'İşletmeler',
        'subtitle': 'Esnaf Rehberi',
        'icon': CupertinoIcons.building_2_fill,
        'color': const Color(0xFF06B6D4),
        'onTap': () => setState(() => _seciliIndex = 3),
      },
      {
        'title': 'Deprem & Acil',
        'subtitle': 'Son Sarsıntılar',
        'icon': CupertinoIcons.waveform_path_ecg,
        'color': const Color(0xFFEF4444),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarthquakePage())),
      },
      {
        'title': 'Kamu Rehberi',
        'subtitle': 'Kurum & Muhtarlık',
        'icon': CupertinoIcons.shield_fill,
        'color': const Color(0xFF0284C7),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicDirectoryPage())),
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final color = item['color'] as Color;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTumKategorilerBanner(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _showAllCategoriesSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.square_grid_2x2_fill, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tüm Kategoriler & Hizmetler",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Pazarcık'a dair aradığınız her şey burada",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Color(0xFFF59E0B), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildGundemSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Gündemden Haberler",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsPage())),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                children: [
                  Text(
                    "Tüm Haberler",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFEF4444)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_newsLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator()))
        else if (_liveNews.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text("Haberler yükleniyor veya akış güncelleniyor..."),
            ),
          )
        else
          SizedBox(
            height: 205,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _liveNews.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final news = _liveNews[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (news.link.isNotEmpty) {
                      _externalLinkAc(news.link);
                    }
                  },
                  child: Container(
                    width: 230,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Image.network(
                              news.imageUrl,
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 110,
                                color: Colors.grey.shade800,
                                child: const Icon(CupertinoIcons.news, color: Colors.white54, size: 36),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  news.category,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                news.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(CupertinoIcons.clock, size: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    news.formattedDate,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _extractProductImageUrl(Map<String, dynamic> data) {
    try {
      if (data['productImage'] != null && data['productImage'].toString().trim().isNotEmpty) {
        return data['productImage'].toString().trim();
      }
      if (data['imageUrl'] != null && data['imageUrl'].toString().trim().isNotEmpty) {
        return data['imageUrl'].toString().trim();
      }
      if (data['image'] != null && data['image'].toString().trim().isNotEmpty) {
        return data['image'].toString().trim();
      }
      final rawImages = data['images'];
      if (rawImages is List && rawImages.isNotEmpty) {
        return rawImages.first.toString().trim();
      } else if (rawImages is String && rawImages.trim().isNotEmpty) {
        return rawImages.trim();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Widget _buildEtkinliklerSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Fırsatlar & Lezzetler",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _seciliIndex = 1),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                children: [
                  Text(
                    "Tüm Menüler",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9500),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFFF9500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 🔥 Kayar Yemek Siparişleri / Ayın İndirimli Fırsatları
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final allDocs = snapshot.data!.docs;
            // Ayın indirimli fırsatları öncelikli kontrolü
            final monthlyDeals = allDocs.where((doc) {
              final data = doc.data();
              return data['isMonthlyDeal'] == true &&
                  data['monthlyDealEnabled'] != false &&
                  data['dealStatus'] != 'passive';
            }).toList();

            final displayDocs = monthlyDeals.isNotEmpty
                ? monthlyDeals.take(8).toList()
                : allDocs.take(6).toList();

            if (displayDocs.isEmpty) return const SizedBox.shrink();

            return Container(
              height: 175,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displayDocs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final doc = displayDocs[index];
                  final data = doc.data();
                  final title = (data['productName'] ?? data['title'] ?? data['name'] ?? 'Lezzet').toString();
                  final priceNum = (data['price'] ?? data['dealPrice'] ?? 0);
                  final price = priceNum is num ? "${priceNum.toStringAsFixed(0)} ₺" : "$priceNum ₺";
                  final isDeal = data['isMonthlyDeal'] == true;
                  final discount = data['discount'];
                  final discountTag = isDeal
                      ? "Ayın Fırsatı"
                      : (discount != null ? "%$discount İndirim" : "Popüler");
                  final imageUrl = _extractProductImageUrl(data);

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailsScreen(product: doc),
                        ),
                      );
                    },
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDeal
                              ? const Color(0xFFFF2D55).withOpacity(0.4)
                              : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                          width: isDeal ? 1.2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDeal
                                ? const Color(0xFFFF2D55).withOpacity(0.12)
                                : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              if (imageUrl.isNotEmpty)
                                Image.network(
                                  imageUrl,
                                  height: 95,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 95,
                                    color: Colors.grey.shade800,
                                    child: const Icon(CupertinoIcons.flame_fill, color: Colors.white54, size: 28),
                                  ),
                                )
                              else
                                Container(
                                  height: 95,
                                  color: isDark ? const Color(0xFF262C38) : const Color(0xFFFFF3EE),
                                  child: const Center(
                                    child: Icon(CupertinoIcons.flame_fill, color: Color(0xFFFF6B35), size: 32),
                                  ),
                                ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDeal
                                        ? const Color(0xFFFF2D55)
                                        : const Color(0xFFFF9500),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    discountTag,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      price,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF6B35),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B35).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.plus,
                                        size: 12,
                                        color: Color(0xFFFF6B35),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        // 2 Geniş Buton (İkinci El Al/Sat & İş İlanları)
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsMainPage())),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.tag_fill, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "İkinci El",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              "Al & Sat İlanları",
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
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
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobListingPage())),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.briefcase_fill, color: Color(0xFF8B5CF6), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "İş İlanları",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              "Kariyer Fırsatları",
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
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
          ],
        ),
      ],
    );
  }

  Widget _buildSonIlanlarSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Son Eklenen İlanlar",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsMainPage())),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                children: [
                  Text(
                    "Tüm İlanlar",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFF10B981)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('classified_ads')
              .orderBy('createdAt', descending: true)
              .limit(4)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text("Henüz ilan bulunmuyor."),
                ),
              );
            }

            final docs = snapshot.data!.docs;
            return Column(
              children: [
                // 1. Öne Çıkan Büyük İlan
                if (docs.isNotEmpty)
                  _buildFeaturedAdCard(docs.first.data(), docs.first.id, isDark),
                const SizedBox(height: 10),
                // Kalan İlanlar (Yatay Slider)
                if (docs.length > 1)
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length - 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final adData = docs[index + 1].data();
                        final adId = docs[index + 1].id;
                        return _buildSmallAdCard(adData, adId, isDark);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _extractAdImageUrl(Map<String, dynamic> data) {
    try {
      final rawImages = data['images'];
      if (rawImages is List && rawImages.isNotEmpty) {
        return rawImages.first.toString().trim();
      } else if (rawImages is String && rawImages.trim().isNotEmpty) {
        return rawImages.trim();
      }
      final rawImg = data['imageUrl'] ?? data['image'] ?? data['photoUrl'] ?? '';
      return rawImg.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Widget _buildFeaturedAdCard(Map<String, dynamic> data, String id, bool isDark) {
    final title = (data['title'] ?? 'İlan Başlığı').toString();
    final price = data['price'] != null ? "${data['price']} ₺" : "Fiyat Belirtilmemiş";
    final location = (data['location'] ?? 'Pazarcık').toString();
    final imageUrl = _extractAdImageUrl(data);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailPage(ad: {...data, 'id': id}),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: Colors.grey.shade800,
                      child: const Icon(CupertinoIcons.photo, color: Colors.white54, size: 36),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: Icon(CupertinoIcons.photo, color: Colors.white54, size: 36),
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(CupertinoIcons.location, size: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAdCard(Map<String, dynamic> data, String id, bool isDark) {
    final title = (data['title'] ?? 'İlan').toString();
    final price = data['price'] != null ? "${data['price']} ₺" : "Fiyat Sorun";
    final imageUrl = _extractAdImageUrl(data);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailPage(ad: {...data, 'id': id}),
          ),
        );
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                height: 85,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 85,
                  color: Colors.grey.shade800,
                  child: const Icon(CupertinoIcons.photo, color: Colors.white54, size: 24),
                ),
              )
            else
              Container(
                height: 85,
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(CupertinoIcons.photo, color: Colors.white54, size: 24),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCekGonderBanner(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // 🔒 Giriş kontrolu
        if (FirebaseAuth.instance.currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Çek Gönder özelliğini kullanmak için lütfen giriş yapın."),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CekGonderPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Çek Gönder",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Gördüğün arıza, talep veya sorunu fotoğraflayıp yetkililere ilet!",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.arrow_right_circle_fill, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMagicBottomNav(bool isDark) {
    return HomeBottomNavBar(
      selectedIndex: _seciliIndex,
      isDark: isDark,
      onTap: (index) {
        setState(() {
          _seciliIndex = index;
        });
      },
    );
  }
}


// 🔥 ZORUNLU GÜNCELLEME KONTROLCÜSÜ
class StartupAnnouncementWrapper extends StatefulWidget {
  final Widget child;
  const StartupAnnouncementWrapper({super.key, required this.child});

  @override
  State<StartupAnnouncementWrapper> createState() =>
      _StartupAnnouncementWrapperState();
}

class _StartupAnnouncementWrapperState
    extends State<StartupAnnouncementWrapper> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartupAnnouncementIfNeeded();
    });
  }

  Future<void> _showStartupAnnouncementIfNeeded() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('startup_announcement')
          .get();
      final data = doc.data();
      if (data == null || data['isActive'] != true) return;

      final marker = (data['updatedAt'] as Timestamp?)
              ?.millisecondsSinceEpoch
              .toString() ??
          (data['title'] ?? '').toString();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('dismissed_startup_announcement') == marker) return;

      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => _StartupAnnouncementDialog(
          title: (data['title'] ?? 'Duyuru').toString(),
          body: (data['body'] ?? '').toString(),
          mediaUrl: (data['mediaUrl'] ?? '').toString(),
          linkUrl: (data['linkUrl'] ?? '').toString(),
        ),
      );

      await prefs.setString('dismissed_startup_announcement', marker);
    } catch (e) {
      debugPrint('Acilis duyurusu hatasi: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _StartupAnnouncementDialog extends StatelessWidget {
  final String title;
  final String body;
  final String mediaUrl;
  final String linkUrl;

  const _StartupAnnouncementDialog({
    required this.title,
    required this.body,
    required this.mediaUrl,
    required this.linkUrl,
  });

  bool get _looksLikeImage {
    final lower = mediaUrl.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.contains('firebasestorage.googleapis.com');
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title.isEmpty ? 'Duyuru' : title),
      content: Column(
        children: [
          if (mediaUrl.isNotEmpty && _looksLikeImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                mediaUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(body),
          ],
        ],
      ),
      actions: [
        if (mediaUrl.isNotEmpty && !_looksLikeImage)
          CupertinoDialogAction(
            child: const Text('Videoyu Aç'),
            onPressed: () => _openUrl(mediaUrl),
          ),
        if (linkUrl.isNotEmpty)
          CupertinoDialogAction(
            child: const Text('Bağlantıyı Aç'),
            onPressed: () => _openUrl(linkUrl),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('Kapat'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class VersionCheckWrapper extends StatefulWidget {
  final Widget child;
  const VersionCheckWrapper({super.key, required this.child});

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  bool _needsUpdate = false;
  String _storeUrl = "";

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkVersion();
    }
  }

  Future<void> _checkVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionCode = int.parse(packageInfo.buildNumber);

      var doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version_control')
          .get()
          .timeout(const Duration(seconds: 4));

      if (doc.exists && mounted) {
        int minVersionCode = (doc.data()?['min_version'] ?? 0).toInt();
        bool forceUpdate = doc.data()?['force_update'] ?? true;

        _storeUrl = defaultTargetPlatform == TargetPlatform.android
            ? (doc.data()?['android_url'] ?? "")
            : (doc.data()?['ios_url'] ?? "");

        if (forceUpdate && currentVersionCode < minVersionCode) {
          setState(() {
            _needsUpdate = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Versiyon kontrol hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsUpdate) {
      return ForceUpdateScreen(storeUrl: _storeUrl);
    }
    return widget.child;
  }
}

// 🔥 MODERN GÜNCELLEME EKRANI (UI)
class ForceUpdateScreen extends StatelessWidget {
  final String storeUrl;
  const ForceUpdateScreen({super.key, required this.storeUrl});

  void _launchStore() async {
    if (storeUrl.isEmpty) return;
    final Uri url = Uri.parse(storeUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // İkon veya Animasyon Alanı
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFF0056D2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_2_circlepath_circle_fill,
                  size: 100,
                  color: Color(0xFF0056D2),
                ),
              ),
              const SizedBox(height: 40),

              Text(
                "Yeni Bir Sürüm Mevcut!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                "Size daha iyi ve hızlı bir deneyim sunabilmek için Pazarcık Portal'ı güncelledik. Uygulamayı kullanmaya devam etmek için lütfen son sürüme güncelleyin.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),

              // Güncelleme Butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _launchStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Hemen Güncelle",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
