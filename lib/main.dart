// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:pazarcik_portal/business/BusinessDetailPage.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/store/store_details.dart';
import 'package:pazarcik_portal/isilani/job_detail_page.dart';
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
import 'firebase_options.dart';

// Servisler ve Dinamik Ayarlar
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
import 'package:lottie/lottie.dart';
import 'package:pazarcik_portal/views/home_header_section.dart';
import 'package:app_links/app_links.dart';
import 'package:pazarcik_portal/sahibinden/ad_detail_page.dart';
import 'package:pazarcik_portal/ilanveduyuru/ilan_duyurular_page.dart';

// 🔥 YENİ EKLENEN SAYFALAR
import 'package:pazarcik_portal/services/earthquake_page.dart';
import 'package:pazarcik_portal/kamu/public_directory_page.dart'; // Kamu sayfası importu (Yolu projene göre ayarla)
import 'package:package_info_plus/package_info_plus.dart';

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
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return;

  try {
    await auth.signInAnonymously();
    debugPrint("Misafir oturumu açıldı.");
  } catch (e) {
    debugPrint("Misafir oturumu açılamadı: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _ensureGuestSession();
  await _checkAndRefreshSellerSubscription();

  final prefs = await SharedPreferences.getInstance();
  isDarkModeNotifier.value = prefs.getBool('darkMode') ?? false;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // KRITIK DUZELTME:
  // Bildirim servisi baslatma adimi (FCM token kaydi gibi) arka plan
  // islevselligi icindir ve basarisiz olsa bile kullanicinin uygulamayi
  // acabilmesini engellememelidir. Daha once burada firlatilan bir hata
  // (ornegin Firestore permission-denied) runApp() cagrisina hic
  // ulasilamamasina ve uygulamanin acilis ekraninda donup kalmasina
  // sebep oluyordu.
  try {
    await NotificationService().initialize(navigatorKey);
  } catch (e) {
    debugPrint("Bildirim servisi başlatma hatası: $e");
  }

  runApp(const MyApp());
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
                  side:
                      BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: 'SF Pro Display',
              colorSchemeSeed: const Color(0xFF0056D2),
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.05), width: 1),
                ),
              ),
            ),
            home: const VersionCheckWrapper(
              child: StartupAnnouncementWrapper(child: RootAuthorityCheck()),
            ),
            routes: {
              '/home': (context) => const PazarcikAnaEkran(),
              '/profile': (context) => const ProfileScreen(),
              '/forgot-password': (context) => const ForgotPassword(),
              '/auth-screen': (context) => const Auth(),
            },
          );
        },
      ),
    );
  }
}

class RootAuthorityCheck extends StatelessWidget {
  const RootAuthorityCheck({super.key});

  @override
  Widget build(BuildContext context) => const PazarcikAnaEkran();
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

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ayarlariYukle();
    _baslangicVerileriniYukle();
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWebInstallPrompt();
    });
  }

  Future<void> _maybeShowWebInstallPrompt() async {
    if (!kIsWeb || _webInstallPromptShown || !mounted) return;

    final platform = defaultTargetPlatform;
    final bool isIos = platform == TargetPlatform.iOS;
    final bool isAndroid = platform == TargetPlatform.android;
    if (!isIos && !isAndroid) return;

    _webInstallPromptShown = true;
    final storeUrl = isIos ? _iosStoreUrl : _androidStoreUrl;
    final title =
        isIos ? "iPhone uygulamasını indir" : "Android uygulamasını indir";
    final subtitle = isIos
        ? "Pazarcık Portal'ı App Store'dan indirip daha hızlı kullanabilirsiniz."
        : "Pazarcık Portal'ı Google Play'den indirip daha hızlı kullanabilirsiniz.";
    final icon = isIos ? CupertinoIcons.device_phone_portrait : Icons.android;
    final accent = isIos ? const Color(0xFF0A84FF) : const Color(0xFF1EA64B);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.08),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width < 380 ? size.width - 32 : 360,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: accent, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "Kapat",
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(CupertinoIcons.xmark, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: TextStyle(
                            height: 1.35,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text("Sonra"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final uri = Uri.parse(storeUrl);
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon:
                                  const Icon(CupertinoIcons.arrow_down_circle),
                              label: const Text("İndir"),
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
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final appLink = await _appLinks.getInitialLink();
      if (appLink != null) {
        _handleDeepLink(appLink);
      }
    } catch (e) {
      debugPrint("Deep link başlatma hatası: $e");
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.host == 'pazarcik-portal-7faf2.web.app') {
      String? id = uri.queryParameters['id'];
      if (id == null) return;

      if (uri.path == '/is') {
        var doc = await FirebaseFirestore.instance
            .collection('job_ads')
            .doc(id)
            .get();
        if (doc.exists && mounted) {
          Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (context) =>
                      JobDetailPage(job: doc.data()!, docId: id)));
        }
      } else if (uri.path == '/isletme') {
        var doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(id)
            .get();
        if (doc.exists && mounted) {
          Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (context) => BusinessDetailPage(doc: doc)));
        }
      } else if (uri.path == '/magaza') {
        var doc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(id)
            .get();
        if (doc.exists && mounted) {
          Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (context) => StoreDetails(store: doc)));
        }
      } else if (uri.path == '/ilan') {
        var doc = await FirebaseFirestore.instance
            .collection('classified_ads')
            .doc(id)
            .get();
        if (doc.exists && mounted) {
          Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (context) => AdDetailPage(ad: doc.data()!)));
        }
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        namazBildirimAcik = prefs.getBool('namaz_bildirim') ?? true;
      });
    }
  }

  void _baslangicVerileriniYukle() async {
    _weatherService.getWeather("Pazarcık").then((wData) {
      if (mounted && wData != null) {
        setState(() {
          _weatherData = wData;
        });
      }
    }).catchError((e) {
      debugPrint("Hava durumu hatası: $e");
    });

    await _prayerService.fetchVakitler();

    if (mounted) {
      _namazTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _prayerService.hesaplaGeriSayim(() {
            setState(() {});
          }, namazBildirimAcik);
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _namazTimer?.cancel();
    super.dispose();
  }

  Future<void> _externalLinkAc(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<Map<String, dynamic>> _defaultTaxiItems() {
    return [
      {
        'name': 'TAKSI CRAZY',
        'phone': '0543 569 46 58',
        'telUrl': 'tel:+905435694658',
        'isActive': true,
      },
      {
        'name': 'Otogar Taksi',
        'phone': '(0344) 311 20 30',
        'telUrl': 'tel:+903443112030',
        'isActive': true,
      },
      {
        'name': 'Merkez Taksi',
        'phone': '(0344) 311 44 05',
        'telUrl': 'tel:+903443114405',
        'isActive': true,
      },
      {
        'name': 'Narlı Taksi',
        'phone': '0533 438 84 51',
        'telUrl': 'tel:+905334388451',
        'isActive': true,
      },
    ];
  }

  String _taxiTelUrl(Map<String, dynamic> item) {
    final existing = (item['telUrl'] ?? '').toString().trim();
    if (existing.startsWith('tel:')) return existing;

    final phone = (item['phone'] ?? '').toString();
    var digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return 'tel:$digits';
    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '90${digits.substring(1)}';
    } else if (digits.length == 10) {
      digits = '90$digits';
    }
    return digits.isEmpty ? '' : 'tel:+$digits';
  }

  List<Map<String, dynamic>> _parseTaxiItems(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    final rawItems = data?['items'];
    if (rawItems is! List) return _defaultTaxiItems();

    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['isActive'] != false &&
            (item['name'] ?? '').toString().trim().isNotEmpty &&
            (item['phone'] ?? '').toString().trim().isNotEmpty)
        .toList();

    items.sort((a, b) {
      final aOrder = a['sortOrder'];
      final bOrder = b['sortOrder'];
      if (aOrder is num && bOrder is num) {
        return aOrder.compareTo(bOrder);
      }
      return (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString());
    });

    return items.isEmpty ? _defaultTaxiItems() : items;
  }

  void _showTaxiMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Hangi durağı aramak istersiniz?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app_settings')
                  .doc('taxi_numbers')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: CupertinoActivityIndicator(),
                  );
                }

                final items = snapshot.hasError
                    ? _defaultTaxiItems()
                    : _parseTaxiItems(snapshot.data!);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items
                      .map((item) => _buildTaxiOption(
                            (item['name'] ?? '').toString(),
                            (item['phone'] ?? '').toString(),
                            _taxiTelUrl(item),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxiOption(String name, String displayPhone, String telUrl) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFBC02D).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.car_detailed,
              color: Color(0xFFF8A809),
              size: 22,
            ),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          displayPhone,
          style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.call, color: Colors.green, size: 20),
        ),
        onTap: () {
          Navigator.pop(context);
          _externalLinkAc(telUrl);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final int gridCrossAxisCount = screenWidth > 600 ? 6 : 4;
    final double gridChildAspectRatio = screenWidth > 600 ? 1.0 : 0.8;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. ÜST BAR, HAVA DURUMU VE NAMAZ
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseAuth.instance.currentUser == null
                        ? null
                        : FirebaseFirestore.instance
                            .collection('notifications')
                            .where('to',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser!.uid)
                            .where('isRead', isEqualTo: false)
                            .snapshots(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data?.docs.length ?? 0;

                      return HomeHeaderSection(
                        isDark: isDark,
                        unreadNotificationCount: unreadCount,
                        weatherWidget: _weatherData != null
                            ? _buildWeatherWidget(_weatherData)
                            : null,
                        namazWidget: _buildModernNamazKarti(),
                        onNotificationTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const BildirimKutusuAnaSayfa(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // 2. DİNAMİK GRID BUTONLAR
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: gridChildAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final btn = mainActionButtons[index];
                        return _buildGridItem(btn.title, btn.icon, btn.color,
                            () {
                          if (btn.title == "Etkinlikler") {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  "Pazarcık etkinlik takvimi çok yakında burada olacak! 🚀",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: Colors.orange.shade700,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;
                          }

                          if (btn.url != null && btn.url!.isNotEmpty) {
                            _externalLinkAc(btn.url!);
                          }
                          if (btn.destination != null) {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => btn.destination!));
                          }
                        });
                      },
                      childCount: mainActionButtons.length,
                    ),
                  ),
                ),

                // 🔥 3. ÇEK GÖNDER BUTONU (BÜYÜK VE ORTALI)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: GestureDetector(
                      onTap: () {
                        // 🔥 Çek & Gönder sayfasına yönlendirme
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CekGonderPage()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFff4b1f), Color(0xFFff9068)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.deepOrange.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ]),
                        child: const Column(
                          children: [
                            Icon(CupertinoIcons.camera_fill,
                                color: Colors.white, size: 40),
                            SizedBox(height: 8),
                            Text("ÇEK GÖNDER",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2)),
                            SizedBox(height: 4),
                            Text("Gördüğün bir olayı anında habere dönüştür!",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 🔥 4. ALT 4'LÜ MENÜ (Kamu Aktif Edildi)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: gridChildAspectRatio,
                            child: _buildGridItem("Kamu",
                                CupertinoIcons.building_2_fill, Colors.red, () {
                              // 🔥 Kamu sayfasına yönlendirme eklendi
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) =>
                                        const PublicDirectoryPage()),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: gridChildAspectRatio,
                            child: _buildGridItem(
                                "Taksi",
                                CupertinoIcons.car_detailed,
                                Colors.amber.shade700,
                                () => _showTaxiMenu(context)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: gridChildAspectRatio,
                            child: _buildGridItem(
                              "İlanlar",
                              CupertinoIcons.doc_text_fill,
                              Colors.blue,
                              () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) =>
                                        const IlanDuyurularPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: gridChildAspectRatio,
                            child: _buildGridItem(
                                "Deprem",
                                CupertinoIcons.waveform_path_ecg,
                                Colors.redAccent, () {
                              Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (context) =>
                                          const EarthquakePage()));
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. BOTTOM NAV BOŞLUĞU
                const SliverToBoxAdapter(
                  child: SizedBox(height: 140),
                ),
              ],
            ),
          ),

          // 6. MAGIC BOTTOM NAV
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildMagicBottomNav(isDark),
          )
        ],
      ),
    );
  }

  Map<String, dynamic> _getWeatherDetails(int code) {
    String text;
    Color color;
    String lottie;
    IconData fallbackIcon;

    if (code == 0) {
      text = 'Güneşli';
      color = const Color(0xFFF9A825);
      lottie =
          'https://lottie.host/8040d7c5-555d-4a1d-a36c-2f9cdb8fceaa/rF0S8X4u5P.json';
      fallbackIcon = CupertinoIcons.sun_max_fill;
    } else if (code == 1 || code == 2 || code == 3) {
      text = code == 3 ? 'Kapalı' : 'Parçalı Bulutlu';
      color = Colors.blueGrey;
      lottie =
          'https://lottie.host/c5c84cb1-536f-40e1-88fc-84f938c6d17e/pA1oH3uGxk.json';
      fallbackIcon = CupertinoIcons.cloud_sun_fill;
    } else if (code == 45 || code == 48) {
      text = 'Sisli';
      color = Colors.grey;
      lottie =
          'https://lottie.host/c5c84cb1-536f-40e1-88fc-84f938c6d17e/pA1oH3uGxk.json';
      fallbackIcon = CupertinoIcons.cloud_fog_fill;
    } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      text = 'Yağmurlu';
      color = Colors.blue.shade600;
      lottie =
          'https://lottie.host/5b736b7b-2325-4eb8-b99b-02b4852e008f/S1l1q9c6tA.json';
      fallbackIcon = CupertinoIcons.cloud_rain_fill;
    } else if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      text = 'Karlı';
      color = Colors.cyan.shade600;
      lottie =
          'https://lottie.host/3a2283df-eb3f-4e08-9df2-5d91e6b8c8d8/K2PqO8B8wN.json';
      fallbackIcon = CupertinoIcons.snow;
    } else if (code >= 95) {
      text = 'Fırtınalı';
      color = Colors.deepPurple;
      lottie =
          'https://lottie.host/7dfa2c20-63eb-4dfb-9a86-b4d24177ebfc/2iOq1gR67X.json';
      fallbackIcon = CupertinoIcons.cloud_bolt_rain_fill;
    } else {
      text = 'Bilinmiyor';
      color = Colors.grey;
      lottie =
          'https://lottie.host/c5c84cb1-536f-40e1-88fc-84f938c6d17e/pA1oH3uGxk.json';
      fallbackIcon = CupertinoIcons.cloud_fill;
    }

    return {
      'text': text,
      'color': color,
      'lottie': lottie,
      'icon': fallbackIcon
    };
  }

  Widget _buildWeatherWidget(dynamic data) {
    int code = (data['code'] ?? 0).toInt();
    var weatherInfo = _getWeatherDetails(code);

    return GestureDetector(
      onTap: () => _show7DayForecast(context, data['daily']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: weatherInfo['color'].withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Lottie.network(
              weatherInfo['lottie'],
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                  weatherInfo['icon'],
                  color: weatherInfo['color'],
                  size: 28),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${data['temp']?.round() ?? '0'}°",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: weatherInfo['color']),
                ),
                Text(
                  weatherInfo['text'],
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _show7DayForecast(BuildContext context, dynamic dailyData) {
    if (dailyData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Hava durumu verisi yükleniyor, lütfen bekleyin.")));
      return;
    }

    List<String> dates = List<String>.from(dailyData['time']);
    List<int> codes = List<int>.from(dailyData['weathercode']);
    List<double> maxTemps = List<double>.from(dailyData['temperature_2m_max']);
    List<double> minTemps = List<double>.from(dailyData['temperature_2m_min']);
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(
              "7 Günlük Pazarcık Hava Durumu",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                var info = _getWeatherDetails(codes[index]);

                DateTime date = DateTime.parse(dates[index]);
                String dayName = DateFormat('EEEE', 'tr_TR').format(date);
                if (index == 0) dayName = "Bugün";
                if (index == 1) dayName = "Yarın";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(dayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Lottie.network(
                              info['lottie'],
                              width: 35,
                              height: 35,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(info['icon'],
                                      color: info['color'], size: 28),
                            ),
                            const SizedBox(width: 5),
                            Text(info['text'],
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("${maxTemps[index].round()}°",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(width: 5),
                            Text("${minTemps[index].round()}°",
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNamazKarti() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color vakitRengi = _prayerService.getVakitRengi();
    final vakitler = _prayerService.vakitler.entries.toList();

    if (vakitler.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.28)
                : vakitRengi.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        vakitRengi.withOpacity(isDark ? 0.28 : 0.14),
                        vakitRengi.withOpacity(isDark ? 0.12 : 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: vakitRengi.withOpacity(isDark ? 0.25 : 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: vakitRengi,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: vakitRengi.withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.moon_stars_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Sonraki ezan",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _prayerService.siradakiVakitAd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.18)
                              : Colors.white.withOpacity(0.86),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _prayerService.geriSayim,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: vakitRengi,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const KiblePusulasiEkrani(),
                    ),
                  );
                },
                child: Container(
                  width: 62,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0056D2),
                        Color(0xFF0284C7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.compass_fill,
                        color: Colors.white,
                        size: 26,
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Kıble",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 360;

              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.045)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: List.generate(vakitler.length, (index) {
                    final vakit = vakitler[index];
                    final bool aktifMi =
                        index == _prayerService.aktifVakitIndex;

                    return Expanded(
                      child: _vakitSutun(
                        isim: vakit.key,
                        saat: vakit.value,
                        aktifMi: aktifMi,
                        renk: vakitRengi,
                        isDark: isDark,
                        compact: compact,
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _vakitSutun({
    required String isim,
    required String saat,
    required bool aktifMi,
    required Color renk,
    required bool isDark,
    required bool compact,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
      padding: EdgeInsets.symmetric(
        vertical: 9,
        horizontal: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: aktifMi
            ? renk.withOpacity(isDark ? 0.24 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: aktifMi
            ? Border.all(color: renk.withOpacity(isDark ? 0.38 : 0.24))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _vakitIconu(isim),
            size: compact ? 15 : 17,
            color: aktifMi
                ? renk
                : isDark
                    ? Colors.white38
                    : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 5),
          Text(
            _kisaVakitAdi(isim),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              color: aktifMi
                  ? renk
                  : isDark
                      ? Colors.white54
                      : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              saat,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w900,
                color: aktifMi
                    ? renk
                    : isDark
                        ? Colors.white
                        : const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _kisaVakitAdi(String isim) {
    switch (isim) {
      case "İmsak":
        return "İmsak";
      case "Güneş":
        return "Güneş";
      case "Öğle":
        return "Öğle";
      case "İkindi":
        return "İkindi";
      case "Akşam":
        return "Akşam";
      case "Yatsı":
        return "Yatsı";
      default:
        return isim;
    }
  }

  IconData _vakitIconu(String isim) {
    switch (isim) {
      case "İmsak":
        return CupertinoIcons.moon_stars;
      case "Güneş":
        return CupertinoIcons.sunrise_fill;
      case "Öğle":
        return CupertinoIcons.sun_max_fill;
      case "İkindi":
        return CupertinoIcons.cloud_sun_fill;
      case "Akşam":
        return CupertinoIcons.sunset_fill;
      case "Yatsı":
        return CupertinoIcons.moon_fill;
      default:
        return CupertinoIcons.clock_fill;
    }
  }

  // 🔥 GRID ITEM (Menü butonlarının mimarisi)
  Widget _buildGridItem(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).cardTheme.shape!.runtimeType ==
                    RoundedRectangleBorder
                ? (Theme.of(context).cardTheme.shape as RoundedRectangleBorder)
                    .side
                    .color
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: color, size: constraints.maxHeight < 78 ? 23 : 27),
              const SizedBox(height: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMagicBottomNav(bool isDark) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(bottomNavItems.length, (index) {
          final item = bottomNavItems[index];
          bool active = _seciliIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _seciliIndex = index);
              if (item.destination != null) {
                Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (context) => item.destination!));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(active ? 12 : 8),
              decoration: active
                  ? BoxDecoration(
                      color: item.color.withOpacity(0.15),
                      shape: BoxShape.circle)
                  : null,
              child: Icon(item.icon,
                  color: active ? item.color : Colors.white54,
                  size: active ? 28 : 24),
            ),
          );
        }),
      ),
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
  bool _isLoading = true;
  bool _needsUpdate = false;
  String _storeUrl = "";

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _isLoading = false;
      return;
    }
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      // 1. Cihazdaki sürüm kodunu al (pubspec'teki + işaretinden sonraki rakam)
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionCode = int.parse(packageInfo.buildNumber);

      // 2. Firestore'dan minimum sürüm kodunu çek
      var doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version_control')
          .get();

      if (doc.exists) {
        // Firestore'da 'min_version' artık bir sayı (örn: 24)
        int minVersionCode = (doc.data()?['min_version'] ?? 0).toInt();
        bool forceUpdate = doc.data()?['force_update'] ?? true;

        _storeUrl = defaultTargetPlatform == TargetPlatform.android
            ? (doc.data()?['android_url'] ?? "")
            : (doc.data()?['ios_url'] ?? "");

        // BASİT MANTIĞIMIZ: Eğer cihazdaki v24, sunucudaki v25'ten küçükse güncelle!
        if (forceUpdate && currentVersionCode < minVersionCode) {
          if (mounted) {
            setState(() {
              _needsUpdate = true;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Versiyon kontrol hatası: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator(radius: 15)),
      );
    }

    // Eğer güncelleme gerekiyorsa, kendi uygulamanı GİZLE ve bu ekranı göster
    if (_needsUpdate) {
      return ForceUpdateScreen(storeUrl: _storeUrl);
    }

    // Güncelse normal uygulamayı başlat
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
