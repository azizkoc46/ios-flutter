import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';

class KiblePusulasiEkrani extends StatefulWidget {
  const KiblePusulasiEkrani({super.key});

  @override
  State<KiblePusulasiEkrani> createState() => _KiblePusulasiEkraniState();
}

class _KiblePusulasiEkraniState extends State<KiblePusulasiEkrani>
    with SingleTickerProviderStateMixin {
  StreamSubscription<CompassEvent>? _compassSubscription;

  double _heading = 0;

  // Pazarcık için yaklaşık kıble açısı
  // İstersen GPS ile otomatik hesaplatabiliriz
  final double _kibleAcisi = 165.0;

  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();

    // Sadece dikey kullanım
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Animasyon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Pusula başlat
    _startCompass();
  }

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        setState(() {
          _heading = event.heading!;
        });
      }
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool isTablet = size.width > 700;

    final double compassSize = isTablet ? 420 : size.width * 0.78;
    final double arrowSize = isTablet ? 170 : size.width * 0.28;

    // Ok dönüşü
    final double rotation = ((_heading - _kibleAcisi) * (math.pi / 180)) * -1;

    // Hizalama farkı
    final double fark = (_heading - _kibleAcisi).abs();

    final bool isAligned = fark <= 5;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xff0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Kıble Pusulası",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 28 : 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: isTablet ? 30 : 10),

            // ÜST BİLGİ KARTI
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 20,
              ),
              padding: EdgeInsets.all(isTablet ? 28 : 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isAligned
                            ? 1 + ((_pulseController?.value ?? 0) * 0.08)
                            : 1,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.location_on_rounded,
                      color:
                          isAligned ? Colors.greenAccent : Colors.orangeAccent,
                      size: isTablet ? 52 : 40,
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAligned
                              ? "Kıble Yönüne Hizalandınız"
                              : "Telefonu Çevirin",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: isTablet ? 24 : 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          isAligned
                              ? "Namaz için doğru yöndesiniz."
                              : "Oku üstteki hedefe hizalayın.",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: isTablet ? 17 : 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // PUSULA
            Stack(
              alignment: Alignment.center,
              children: [
                // DIŞ HALKA
                Container(
                  width: compassSize,
                  height: compassSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // KIBLE HEDEFİ
                Positioned(
                  top: 20,
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_pin,
                        color:
                            isAligned ? Colors.greenAccent : Colors.redAccent,
                        size: isTablet ? 56 : 44,
                      ),
                      Text(
                        "KIBLE",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          fontSize: isTablet ? 18 : 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // DÖNEN OK
                Transform.rotate(
                  angle: rotation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.navigation_rounded,
                      size: arrowSize,
                      color: isAligned ? Colors.greenAccent : Colors.cyanAccent,
                    ),
                  ),
                ),

                // ORTA NOKTA
                Container(
                  width: isTablet ? 34 : 24,
                  height: isTablet ? 34 : 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 20,
                      )
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ALT BİLGİ KARTI
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 20,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 22 : 16,
                  horizontal: isTablet ? 28 : 18,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withOpacity(0.06),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoItem(
                      "Pusula",
                      "${_heading.toStringAsFixed(0)}°",
                      isTablet,
                    ),
                    _infoItem(
                      "Kıble",
                      "${_kibleAcisi.toStringAsFixed(0)}°",
                      isTablet,
                    ),
                    _infoItem(
                      "Fark",
                      "${fark.toStringAsFixed(1)}°",
                      isTablet,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: isTablet ? 35 : 22),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(
    String title,
    String value,
    bool isTablet,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: isTablet ? 16 : 12,
          ),
        ),
        SizedBox(height: isTablet ? 8 : 5),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 24 : 18,
          ),
        ),
      ],
    );
  }
}
