import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Java'daki EdgeToEdge (Tam ekran, üst ve alt çubuk şeffaf)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await [
    Permission.location,
    Permission.camera,
    Permission.notification,
  ].request();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PazarcikAnaEkran(),
    ),
  );
}

class PazarcikAnaEkran extends StatefulWidget {
  const PazarcikAnaEkran({super.key});

  @override
  State<PazarcikAnaEkran> createState() => _PazarcikAnaEkranState();
}

class _PazarcikAnaEkranState extends State<PazarcikAnaEkran>
    with SingleTickerProviderStateMixin {
  int _seciliIndex = 0;
  InAppWebViewController? webController;

  // Java'daki WebView Modu Kontrolü
  bool _webViewModunda = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 1. Kısım: Üst Gövde (Ya Native Ana Menü Ya Da WebView)
      body: SafeArea(
        top: false, // StatusBar arkasına taşsın
        child: _webViewModunda
            ? _buildWebViewGecisi()
            : _buildNativeAnaMenu(), // Ana menü tasarımı buraya gelecek
      ),

      // 2. Kısım: Sihirli Alt Navigasyon (Magic Circle)
      bottomNavigationBar: _buildSihirliAltMenu(),
    );
  }

  // --- O SENİN MEŞHUR NATIVE ANA EKRANIN (Şimdilik İskelet) ---
  Widget _buildNativeAnaMenu() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 50,
          left: 20,
          right: 20,
          bottom: 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Native Tasarım Yükleniyor...",
              style: TextStyle(fontSize: 20),
            ),
            // Bir sonraki adımda Grid, Banner ve Arama Motorunu buraya dikeceğiz!
          ],
        ),
      ),
    );
  }

  // --- WEBVIEW KISMI (SwipeRefresh ile) ---
  Widget _buildWebViewGecisi() {
    return Stack(
      children: [
        InAppWebView(
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useOnDownloadStart: true,
            supportMultipleWindows: true, // Google/FB Girişi için
          ),
          onWebViewCreated: (controller) => webController = controller,
        ),
        // Kapatma Tuşu
        Positioned(
          top: 40,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
            onPressed: () {
              setState(() {
                _webViewModunda = false;
                _seciliIndex = 0; // Ana sayfaya dön
              });
            },
          ),
        ),
      ],
    );
  }

  // --- SİHİRLİ ALT MENÜ (Magic Bottom Navigation) ---
  Widget _buildSihirliAltMenu() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sihirliButon(0, Icons.home_rounded, "Ana Sayfa"),
          _sihirliButon(1, Icons.chat_bubble_outline, "Destek"),
          _sihirliButon(2, Icons.person_outline, "Giriş Yap"),
          _sihirliButon(3, Icons.settings_outlined, "Ayarlar"),
        ],
      ),
    );
  }

  Widget _sihirliButon(int index, IconData ikon, String yazi) {
    bool secili = _seciliIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _seciliIndex = index;
          if (index != 0) {
            _webViewModunda = true; // Web sitesine geçir
            // İleride buraya URL yönlendirmeleri eklenecek
          } else {
            _webViewModunda = false; // Native menüye dön
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve:
            Curves.easeOutBack, // Senin Java'daki OvershootInterpolator efekti
        transform: Matrix4.translationValues(0, secili ? -15 : 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor:
                  secili ? Colors.blue.shade700 : Colors.transparent,
              radius: 25,
              child: Icon(
                ikon,
                color: secili ? Colors.white : Colors.grey,
                size: 28,
              ),
            ),
            if (secili)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  yazi,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
