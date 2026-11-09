// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'compass_service/compass_service.dart';

/// Şehir Veri Modeli
class QiblaCity {
  final String name;
  final String province;
  final double lat;
  final double lng;
  final bool isDefault;

  const QiblaCity({
    required this.name,
    required this.province,
    required this.lat,
    required this.lng,
    this.isDefault = false,
  });
}

/// Konum Kaynak Türü
enum LocationSourceType { gps, networkIp, manualCity, cached }

class KiblePusulasiEkrani extends StatefulWidget {
  const KiblePusulasiEkrani({super.key});

  @override
  State<KiblePusulasiEkrani> createState() => _KiblePusulasiEkraniState();
}

class _KiblePusulasiEkraniState extends State<KiblePusulasiEkrani>
    with TickerProviderStateMixin {
  StreamSubscription<double?>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // Cihazın pusula açısı (Kuzey = 0°, Doğu = 90°, Güney = 180°, Batı = 270°)
  double _heading = 0.0;
  bool _isSensorReceiving = false;

  // Telefonun düzlük (tilt) durumu (Su Terazisi)
  double _tiltAngle = 0.0;
  bool _isFlat = true;

  // Kâbe Koordinatları (Mekke-i Mükerreme)
  static const double _kabeLat = 21.422487;
  static const double _kabeLng = 39.826206;

  // Varsayılan Koordinatlar (Pazarcık, Kahramanmaraş)
  double _userLat = 37.4872;
  double _userLng = 37.2964;
  String _locationName = "Pazarcık, Kahramanmaraş";
  LocationSourceType _locationSource = LocationSourceType.cached;
  bool _isLocating = false;

  // Hesaplanan Değerler
  double _kibleAcisi = 171.5;
  double _meccaDistanceKm = 1845.0;

  // Animasyon Kontrolcüleri
  late AnimationController _pulseController;
  late AnimationController _alignGlowController;

  bool _hasVibrated = false;

  // Türkiye, Pazarcık Yöresi ve Gurbetçi Şehirleri
  static const List<QiblaCity> _popularCities = [
    // Pazarcık ve Kahramanmaraş Yöresi
    QiblaCity(name: "Pazarcık (Merkez)", province: "Kahramanmaraş", lat: 37.4872, lng: 37.2964, isDefault: true),
    QiblaCity(name: "Narlı", province: "Kahramanmaraş", lat: 37.3828, lng: 37.1456),
    QiblaCity(name: "Kahramanmaraş (Merkez)", province: "Kahramanmaraş", lat: 37.5858, lng: 36.9371),
    QiblaCity(name: "Türkoğlu", province: "Kahramanmaraş", lat: 37.3861, lng: 36.8458),
    QiblaCity(name: "Elbistan", province: "Kahramanmaraş", lat: 38.2047, lng: 37.1983),
    QiblaCity(name: "Afşin", province: "Kahramanmaraş", lat: 38.2478, lng: 36.9142),
    QiblaCity(name: "Göksun", province: "Kahramanmaraş", lat: 38.0211, lng: 36.4972),
    QiblaCity(name: "Çağlayancerit", province: "Kahramanmaraş", lat: 37.7478, lng: 37.2917),
    QiblaCity(name: "Andırın", province: "Kahramanmaraş", lat: 37.5786, lng: 36.3533),
    QiblaCity(name: "Nurhak", province: "Kahramanmaraş", lat: 37.9697, lng: 37.4422),
    QiblaCity(name: "Ekinözü", province: "Kahramanmaraş", lat: 38.0708, lng: 37.1944),

    // Çevre İller & Metropoller
    QiblaCity(name: "Gaziantep", province: "Gaziantep", lat: 37.0662, lng: 37.3833),
    QiblaCity(name: "Adıyaman", province: "Adıyaman", lat: 37.7648, lng: 38.2786),
    QiblaCity(name: "Malatya", province: "Malatya", lat: 38.3552, lng: 38.3095),
    QiblaCity(name: "Şanlıurfa", province: "Şanlıurfa", lat: 37.1674, lng: 38.7955),
    QiblaCity(name: "Adana", province: "Adana", lat: 37.0000, lng: 35.3213),
    QiblaCity(name: "Osmaniye", province: "Osmaniye", lat: 37.0742, lng: 36.2472),
    QiblaCity(name: "Hatay (Antakya)", province: "Hatay", lat: 36.2023, lng: 36.1606),
    QiblaCity(name: "Mersin", province: "Mersin", lat: 36.8121, lng: 34.6415),
    QiblaCity(name: "Kayseri", province: "Kayseri", lat: 38.7205, lng: 35.4826),
    QiblaCity(name: "Sivas", province: "Sivas", lat: 39.7505, lng: 37.0150),
    QiblaCity(name: "Diyarbakır", province: "Diyarbakır", lat: 37.9144, lng: 40.2306),
    QiblaCity(name: "Konya", province: "Konya", lat: 37.8746, lng: 32.4932),
    QiblaCity(name: "Ankara", province: "Ankara", lat: 39.9334, lng: 32.8597),
    QiblaCity(name: "İstanbul", province: "İstanbul", lat: 41.0082, lng: 28.9784),
    QiblaCity(name: "İzmir", province: "İzmir", lat: 38.4237, lng: 27.1428),
    QiblaCity(name: "Bursa", province: "Bursa", lat: 40.1885, lng: 29.0610),
    QiblaCity(name: "Antalya", province: "Antalya", lat: 36.8969, lng: 30.7133),
    QiblaCity(name: "Eskişehir", province: "Eskişehir", lat: 39.7767, lng: 30.5206),
    QiblaCity(name: "Samsun", province: "Samsun", lat: 41.2867, lng: 36.3300),
    QiblaCity(name: "Trabzon", province: "Trabzon", lat: 41.0027, lng: 39.7168),
    QiblaCity(name: "Erzurum", province: "Erzurum", lat: 39.9055, lng: 41.2658),
    QiblaCity(name: "Van", province: "Van", lat: 38.4891, lng: 43.4089),
    QiblaCity(name: "Mardin", province: "Mardin", lat: 37.3129, lng: 40.7350),

    // Kutsal Mekanlar
    QiblaCity(name: "Mekke (Kâbe-i Muazzama)", province: "Suudi Arabistan", lat: 21.4225, lng: 39.8262),
    QiblaCity(name: "Medine-i Münevvere", province: "Suudi Arabistan", lat: 24.4672, lng: 39.6111),
    QiblaCity(name: "Kudüs (Mescid-i Aksa)", province: "Filistin", lat: 31.7761, lng: 35.2358),

    // Gurbetçi Şehirleri (Avrupa & Dünya)
    QiblaCity(name: "Berlin", province: "Almanya", lat: 52.5200, lng: 13.4050),
    QiblaCity(name: "Köln", province: "Almanya", lat: 50.9375, lng: 6.9603),
    QiblaCity(name: "Frankfurt", province: "Almanya", lat: 50.1109, lng: 8.6821),
    QiblaCity(name: "Stuttgart", province: "Almanya", lat: 48.7758, lng: 9.1829),
    QiblaCity(name: "Münih", province: "Almanya", lat: 48.1351, lng: 11.5820),
    QiblaCity(name: "Paris", province: "Fransa", lat: 48.8566, lng: 2.3522),
    QiblaCity(name: "Lyon", province: "Fransa", lat: 45.7640, lng: 4.8357),
    QiblaCity(name: "Strazburg", province: "Fransa", lat: 48.5734, lng: 7.7521),
    QiblaCity(name: "Amsterdam", province: "Hollanda", lat: 52.3676, lng: 4.9041),
    QiblaCity(name: "Rotterdam", province: "Hollanda", lat: 51.9244, lng: 4.4777),
    QiblaCity(name: "Viyana", province: "Avusturya", lat: 48.2082, lng: 16.3738),
    QiblaCity(name: "Zürih", province: "İsviçre", lat: 47.3769, lng: 8.5417),
    QiblaCity(name: "Basel", province: "İsviçre", lat: 47.5596, lng: 7.5886),
    QiblaCity(name: "Brüksel", province: "Belçika", lat: 50.8503, lng: 4.3517),
    QiblaCity(name: "Londra", province: "Birleşik Krallık", lat: 51.5074, lng: -0.1278),
    QiblaCity(name: "Stockholm", province: "İsveç", lat: 59.3293, lng: 18.0686),
    QiblaCity(name: "Kopenhag", province: "Danimarka", lat: 55.6761, lng: 12.5683),
    QiblaCity(name: "Oslo", province: "Norveç", lat: 59.9139, lng: 10.7522),
    QiblaCity(name: "Lefkoşa", province: "KKTC", lat: 35.1856, lng: 33.3823),
    QiblaCity(name: "Bakü", province: "Azerbaycan", lat: 40.4093, lng: 49.8671),
  ];

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _alignGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // 1. Önce kayıtlı son konumu 0 ms gecikmeyle yükle
    _loadCachedLocation();

    // 2. Canlı GPS konumunu otomatik al
    _getUserLocation();

    // 3. Pusula sensörünü başlat
    _initCompass();

    // 4. Su terazisi / Tilt sensörü (Telefon düz mü tutuluyor?)
    _initAccelerometer();
  }

  void _initAccelerometer() {
    try {
      _accelSubscription?.cancel();
      _accelSubscription = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        final ax = event.x;
        final ay = event.y;
        final az = event.z;
        final norm = math.sqrt(ax * ax + ay * ay + az * az);
        if (norm > 0.1) {
          // Z ekseni yerçekimine ne kadar yakın? (Düz iken az ~ 9.8)
          final cosZ = (az / norm).clamp(-1.0, 1.0);
          final tiltDeg = math.acos(cosZ) * (180.0 / math.pi);
          final flat = tiltDeg <= 25.0;
          if (flat != _isFlat || (tiltDeg - _tiltAngle).abs() > 2.0) {
            setState(() {
              _tiltAngle = tiltDeg;
              _isFlat = flat;
            });
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Yerel önbellekten son kaydedilen konumu yükler
  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final double? savedLat = prefs.getDouble('qibla_lat');
      final double? savedLng = prefs.getDouble('qibla_lng');
      final String? savedName = prefs.getString('qibla_name');

      if (savedLat != null && savedLng != null && mounted) {
        setState(() {
          _userLat = savedLat;
          _userLng = savedLng;
          if (savedName != null && savedName.isNotEmpty) {
            _locationName = savedName;
          }
        });
      }
      _calculateQiblaAngle(_userLat, _userLng);
    } catch (_) {
      _calculateQiblaAngle(_userLat, _userLng);
    }
  }

  /// Konumu yerel önbelleğe saklar
  Future<void> _saveCachedLocation(double lat, double lng, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('qibla_lat', lat);
      await prefs.setDouble('qibla_lng', lng);
      await prefs.setString('qibla_name', name);
    } catch (_) {}
  }

  /// GPS konumundan Mekke'ye olan Büyük Daire (Great-Circle) Rota Açısını ve Mesafesini hesaplar
  void _calculateQiblaAngle(double lat, double lng) {
    final double phi1 = lat * (math.pi / 180.0);
    final double phi2 = _kabeLat * (math.pi / 180.0);
    final double deltaLambda = (_kabeLng - lng) * (math.pi / 180.0);

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    double qibla = math.atan2(y, x) * (180.0 / math.pi);
    qibla = (qibla + 360.0) % 360.0;

    // Kuş uçuşu mesafe (Haversine formülü)
    const double earthRadiusKm = 6371.0;
    final double dLat = (_kabeLat - lat) * (math.pi / 180.0);
    final double dLng = (_kabeLng - lng) * (math.pi / 180.0);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distanceKm = earthRadiusKm * c;

    if (mounted) {
      setState(() {
        _kibleAcisi = qibla;
        _meccaDistanceKm = distanceKm;
      });
    }
  }

  /// Koordinatlardan şehir adını çözer (Reverse Geocoding)
  Future<String> _resolveCityName(double lat, double lng) async {
    // 1. Mobil için yerel platform geocoding
    if (!kIsWeb) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng)
            .timeout(const Duration(seconds: 4));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final district = p.subAdministrativeArea?.trim() ?? '';
          final city = p.administrativeArea?.trim() ?? '';
          if (district.isNotEmpty && city.isNotEmpty) {
            return "$district, $city";
          } else if (city.isNotEmpty) {
            return city;
          } else if (p.locality != null && p.locality!.trim().isNotEmpty) {
            return p.locality!.trim();
          }
        }
      } catch (_) {}
    }

    // 2. Web & CORS Güvenli Ters Coğrafi Kodlama API'si
    try {
      final uri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=tr');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['city'] ?? data['locality'] ?? '';
        final principalSubdivision = data['principalSubdivision'] ?? '';
        if (city.toString().isNotEmpty && principalSubdivision.toString().isNotEmpty) {
          return "$city, $principalSubdivision";
        } else if (principalSubdivision.toString().isNotEmpty) {
          return principalSubdivision.toString();
        } else if (city.toString().isNotEmpty) {
          return city.toString();
        }
      }
    } catch (_) {}

    return "${lat.toStringAsFixed(2)}° N, ${lng.toStringAsFixed(2)}° E";
  }

  /// IP tabanlı otomatik konum alma (Yedek)
  Future<bool> _fetchIpLocation() async {
    try {
      final res = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final city = data['city']?.toString() ?? '';
        final region = data['region']?.toString() ?? '';

        if (lat != null && lng != null && mounted) {
          setState(() {
            _userLat = lat;
            _userLng = lng;
            _locationName = city.isNotEmpty && region.isNotEmpty ? "$city, $region" : (city.isNotEmpty ? city : "Mevcut Konum");
            _locationSource = LocationSourceType.networkIp;
          });
          _calculateQiblaAngle(_userLat, _userLng);
          _saveCachedLocation(_userLat, _userLng, _locationName);
          return true;
        }
      }
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('https://freeipapi.com/api/json')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final city = data['cityName']?.toString() ?? '';
        final region = data['regionName']?.toString() ?? '';

        if (lat != null && lng != null && mounted) {
          setState(() {
            _userLat = lat;
            _userLng = lng;
            _locationName = city.isNotEmpty && region.isNotEmpty ? "$city, $region" : (city.isNotEmpty ? city : "Mevcut Konum");
            _locationSource = LocationSourceType.networkIp;
          });
          _calculateQiblaAngle(_userLat, _userLng);
          _saveCachedLocation(_userLat, _userLng, _locationName);
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<void> _applyPosition(Position pos, {required bool isInstant}) async {
    if (!mounted) return;
    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _locationSource = LocationSourceType.gps;
    });
    _calculateQiblaAngle(_userLat, _userLng);

    if (!isInstant) {
      final name = await _resolveCityName(_userLat, _userLng);
      if (mounted) {
        setState(() {
          _locationName = name;
        });
        _saveCachedLocation(_userLat, _userLng, _locationName);
      }
    }
  }

  /// Çok platformlu, tam otomatik GPS Konum Alımı (Web + Android + iOS)
  Future<void> _getUserLocation({bool userInitiated = false}) async {
    if (_isLocating) return;
    if (mounted) setState(() => _isLocating = true);

    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          await _fetchIpLocation();
          if (mounted) {
            setState(() => _isLocating = false);
            if (userInitiated) {
              _showLocationServiceDialog();
            }
          }
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _fetchIpLocation();
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      // 1. Çok hızlı son bilinen konum (< 50ms)
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null && mounted) {
          await _applyPosition(pos, isInstant: true);
        }
      } catch (_) {}

      // 2. Canlı ve hassas GPS konumu
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (_) {}
      }

      if (position != null && mounted) {
        await _applyPosition(position, isInstant: false);
        if (userInitiated && mounted) {
          _showSnackBar("📍 GPS Konumu Alındı: $_locationName");
        }
        return;
      }

      await _fetchIpLocation();
    } catch (_) {
      await _fetchIpLocation();
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Canlı Çok Platformlu Pusula Sensör Dinleyicisi (Web Mobile + Android + iOS)
  Future<void> _initCompass() async {
    try {
      final service = CompassService();
      _compassSubscription?.cancel();
      _compassSubscription = service.headingStream.listen((double? newHeading) {
        if (!mounted || newHeading == null || newHeading.isNaN) return;

        final double raw = (newHeading + 360.0) % 360.0;

        if (!_isSensorReceiving) {
          _heading = raw;
          _isSensorReceiving = true;
        } else {
          // Pürüzsüz ve anlık geçiş yumuşatması
          final double diff = (raw - _heading + 540.0) % 360.0 - 180.0;
          _heading = (_heading + diff * 0.55 + 360.0) % 360.0;
        }

        _checkAlignmentHaptic(_heading);

        setState(() {});
      });

      await service.init();
    } catch (_) {}
  }

  Future<void> _requestWebSensorPermission() async {
    final granted = await CompassService().requestPermission();
    if (granted) {
      _showSnackBar("Pusula sensörü başarıyla bağlandı.");
    } else {
      _showSnackBar("Pusula sensör izni verilemedi.");
    }
  }

  /// Kâbe'ye tam hizalandığında titreşim uyarısı verir
  void _checkAlignmentHaptic(double headingVal) {
    final double currentDiff = (headingVal - _kibleAcisi).abs();
    final double minDiff = math.min(currentDiff, 360.0 - currentDiff);

    if (minDiff <= 4.0) {
      if (!_hasVibrated) {
        HapticFeedback.mediumImpact();
        _hasVibrated = true;
      }
    } else if (minDiff > 8.0) {
      _hasVibrated = false;
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.location_slash_fill, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text("Konum Servisi Kapalı", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Cihazınızın GPS konumu kapalı. Kesin kıble yönü için GPS açabilir veya dilediğiniz şehri listeden seçebilirsiniz.",
          style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openCityPicker();
            },
            child: const Text("Şehir Seç", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text("Ayarları Aç", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Kalibrasyon ve Yardım Diyaloğu
  void _showCalibrationHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(CupertinoIcons.compass, color: Color(0xFF10B981), size: 26),
                const SizedBox(width: 10),
                Text(
                  "Pusula ve Kalibrasyon Rehberi",
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _helpRow("1", "Telefonu yere paralel, avucunuzun içinde düz tutun.", CupertinoIcons.device_phone_portrait),
            _helpRow("2", "Kılıfınızda mıknatıs veya metal varsa pusulayı yanıltabilir.", CupertinoIcons.shield),
            _helpRow("3", "İbre takılırsa telefonu havada yatay sekiz (8) çizecek şekilde çevirin.", CupertinoIcons.arrow_2_circlepath),
            _helpRow("4", "Kâbe ibresi tepedeki çizgiye geldiğinde yeşil yanar ve titreşim verir.", CupertinoIcons.check_mark_circled),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Anladım, Tamam", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }

  /// Şehir Seçici Modal Bottom Sheet
  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CityPickerBottomSheet(
          cities: _popularCities,
          currentCityName: _locationName,
          onGpsSelected: () {
            Navigator.pop(ctx);
            _getUserLocation(userInitiated: true);
          },
          onCitySelected: (city) {
            Navigator.pop(ctx);
            setState(() {
              _userLat = city.lat;
              _userLng = city.lng;
              _locationName = "${city.name}, ${city.province}";
              _locationSource = LocationSourceType.manualCity;
            });
            _calculateQiblaAngle(_userLat, _userLng);
            _saveCachedLocation(_userLat, _userLng, _locationName);
            _showSnackBar("📍 Konum: $_locationName (Kıble: ${_kibleAcisi.toStringAsFixed(1)}°)");
          },
        );
      },
    );
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _compassSubscription?.cancel();
    _accelSubscription?.cancel();
    CompassService().dispose();
    _pulseController.dispose();
    _alignGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 700;
    final double compassSize = isTablet ? 380 : math.min(size.width * 0.85, 330);

    // Kıble ile açı farkı (En kısa dairesel açı)
    final double rawRelativeDiff = (_kibleAcisi - _heading + 360.0) % 360.0;
    final bool turnRight = rawRelativeDiff <= 180.0;
    final double diffAngle = turnRight ? rawRelativeDiff : (360.0 - rawRelativeDiff);

    final bool isAligned = diffAngle <= 4.5;
    final bool isNear = diffAngle <= 18.0;

    // Kadran Dönüş Açısı (Kuzey daima gerçek Kuzeyi göstersin)
    final double dialRotation = -_heading * (math.pi / 180.0);

    // Kıble İbresinin Telefona Göre Dönüş Açısı:
    // Telefon ne yöne dönerse dönsün, bu ibre daima MEKKE'yi gösterir!
    final double qiblaNeedleRotation = (_kibleAcisi - _heading) * (math.pi / 180.0);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // 1. Zengin İslami Gece Radyal Gradyanı
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.15),
                  radius: 1.3,
                  colors: [
                    Color(0xFF0F2338),
                    Color(0xFF07121E),
                    Color(0xFF040810),
                  ],
                ),
              ),
            ),
          ),

          // 2. Ambiyans Işığı (Hizalanınca Parlayan Zümrüt Işık)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: size.height * 0.23,
            left: (size.width - compassSize) / 2,
            child: AnimatedBuilder(
              animation: isAligned ? _alignGlowController : _pulseController,
              builder: (context, _) {
                final glowOpacity = isAligned
                    ? 0.50 + (_alignGlowController.value * 0.35)
                    : (isNear ? 0.25 + (_pulseController.value * 0.15) : 0.08);
                return Container(
                  width: compassSize,
                  height: compassSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isAligned
                            ? const Color(0xFF10B981).withOpacity(glowOpacity)
                            : (isNear
                                ? const Color(0xFFF59E0B).withOpacity(glowOpacity)
                                : const Color(0xFF38BDF8).withOpacity(glowOpacity * 0.4)),
                        blurRadius: isAligned ? 90 : 45,
                        spreadRadius: isAligned ? 24 : 4,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. Ana İçerik
          SafeArea(
            child: Column(
              children: [
                // --- ÜST BAR (Geri, Konum Seçici, GPS Butonu) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _openCityPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _locationSource == LocationSourceType.gps
                                      ? CupertinoIcons.location_fill
                                      : CupertinoIcons.placemark_fill,
                                  size: 15,
                                  color: _locationSource == LocationSourceType.gps
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF38BDF8),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _locationName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _locationSource == LocationSourceType.gps
                                            ? "GPS Otomatik • Kıble: ${_kibleAcisi.toStringAsFixed(0)}° ${_getDirectionNameShort(_kibleAcisi)}"
                                            : "Seçili Şehir • Kıble: ${_kibleAcisi.toStringAsFixed(0)}° ${_getDirectionNameShort(_kibleAcisi)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _locationSource == LocationSourceType.gps
                                              ? const Color(0xFF34D399)
                                              : Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(CupertinoIcons.chevron_down, size: 12, color: Colors.white54),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // GPS Yenile Butonu
                      IconButton(
                        tooltip: "GPS Konumunu Güncelle",
                        icon: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                          ),
                          child: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34D399)),
                                )
                              : const Icon(CupertinoIcons.location, color: Color(0xFF34D399), size: 18),
                        ),
                        onPressed: () => _getUserLocation(userInitiated: true),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // --- BÜYÜK YÖN KILAVUZ KARTI (Basit & Çok Net) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: isAligned
                          ? const Color(0xFF064E3B).withOpacity(0.95)
                          : (isNear
                              ? const Color(0xFF78350F).withOpacity(0.85)
                              : Colors.white.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isAligned
                            ? const Color(0xFF34D399)
                            : (isNear ? const Color(0xFFF59E0B) : Colors.white12),
                        width: isAligned ? 2.4 : 1.2,
                      ),
                      boxShadow: [
                        if (isAligned)
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAligned
                                ? const Color(0xFF10B981).withOpacity(0.35)
                                : (isNear
                                    ? const Color(0xFFF59E0B).withOpacity(0.25)
                                    : Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: isAligned
                                ? const Text("🕋", style: TextStyle(fontSize: 26))
                                : Icon(
                                    turnRight
                                        ? CupertinoIcons.arrow_right_circle_fill
                                        : CupertinoIcons.arrow_left_circle_fill,
                                    color: isNear ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
                                    size: 34,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAligned
                                    ? "KÂBE TAM KARŞINIZDA 🕋"
                                    : (turnRight
                                        ? "➡️ ${diffAngle.toStringAsFixed(0)}° Sağa Dönün"
                                        : "⬅️ ${diffAngle.toStringAsFixed(0)}° Sola Dönün"),
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isAligned
                                    ? "Mükemmel hizalandınız. Namaza durabilirsiniz."
                                    : "Yeşil Kâbe ibresini telefonun tepesindeki çizgiye getirin.",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isAligned ? const Color(0xFFD1FAE5) : Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tilt / Düz Tut Uyarısı
                if (!_isFlat) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFBBF24), size: 14),
                          SizedBox(width: 6),
                          Text(
                            "Telefonunuzu yere paralel (düz) tutunuz",
                            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // --- MERKEZİ PUSULA: DÖNEN KADRAN + KIBLEYE KİLİTLİ CANLI İBRE ---
                Center(
                  child: SizedBox(
                    width: compassSize,
                    height: compassSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. Dış Kadran: Gerçek Dünya Yönlerini Gösterir (Kuzey, Doğu, Güney, Batı)
                        Transform.rotate(
                          angle: dialRotation,
                          child: CustomPaint(
                            size: Size(compassSize, compassSize),
                            painter: _CompassDialPainter(
                              qiblaAngle: _kibleAcisi,
                              isAligned: isAligned,
                            ),
                          ),
                        ),

                        // 2. KIBLEYE KİLİTLİ DÖNEN CANLI İBRE (Mecca Needle)
                        Transform.rotate(
                          angle: qiblaNeedleRotation,
                          child: _buildQiblaLiveNeedle(compassSize, isAligned, qiblaNeedleRotation),
                        ),

                        // 3. Sabit Tepe Yön Göstergesi (Telefonun Baktığı Yön - 12 Hizalama Çizgisi)
                        Positioned(
                          top: 2,
                          child: Column(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isAligned ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isAligned ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                          .withOpacity(0.85),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 3.5,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: isAligned ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4. Merkez Göbek ve Su Terazisi
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isAligned
                                  ? const [Color(0xFF064E3B), Color(0xFF022C22)]
                                  : const [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: isAligned ? const Color(0xFF34D399) : Colors.white24,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.65),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${_heading.toStringAsFixed(0)}°",
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isFlat ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getDirectionNameShort(_heading),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isAligned ? const Color(0xFF34D399) : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // --- BİLGİ KARTLARI (Kıble Açısı, Mesafe, Sensör) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricItem(
                          title: "Kıble Açısı",
                          value: "${_kibleAcisi.toStringAsFixed(0)}°",
                          subtext: _getDirectionNameLong(_kibleAcisi),
                          icon: CupertinoIcons.compass,
                          color: const Color(0xFF34D399),
                        ),
                        Container(width: 1, height: 38, color: Colors.white12),
                        _metricItem(
                          title: "Kâbe Mesafesi",
                          value: "${_meccaDistanceKm.toStringAsFixed(0)} km",
                          subtext: "Kuş Uçuşu",
                          icon: CupertinoIcons.location_solid,
                          color: const Color(0xFFF59E0B),
                        ),
                        Container(width: 1, height: 38, color: Colors.white12),
                        _metricItem(
                          title: "Hedefe Kalan",
                          value: isAligned ? "Hizalandı" : "${diffAngle.toStringAsFixed(0)}°",
                          subtext: isAligned ? "Tam Yön" : (turnRight ? "Sağa Çevir" : "Sola Çevir"),
                          icon: isAligned
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.arrow_2_circlepath,
                          color: isAligned ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // --- SENSÖR BİLGİLENDİRME & KALİBRASYON YARDIMI ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSensorReceiving ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.compass,
                        size: 14,
                        color: _isSensorReceiving ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSensorReceiving ? "Manyetik Pusula Aktif" : "Sensör Kalibre Ediliyor...",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _isSensorReceiving ? const Color(0xFF34D399) : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _showCalibrationHelp,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(CupertinoIcons.question_circle, size: 13, color: Color(0xFF38BDF8)),
                        label: const Text(
                          "Nasıl Kullanılır?",
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (kIsWeb && !_isSensorReceiving) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _requestWebSensorPermission,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: const Text(
                              "Sensör İzni",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// KIBLEYE KİLİTLİ CANLI İBRE WIDGET'I (Ters Dönmeyen Kâbe Rozeti ile)
  Widget _buildQiblaLiveNeedle(double compassSize, bool isAligned, double currentNeedleRotation) {
    final needleLength = compassSize * 0.38;
    return SizedBox(
      width: compassSize,
      height: compassSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Kuzeye bakan ince kuyruk
          Positioned(
            bottom: (compassSize / 2) - (needleLength * 0.45),
            child: Container(
              width: 3,
              height: needleLength * 0.40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white24, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Kâbe'ye uzanan kalın zümrüt/altın iğne
          Positioned(
            top: (compassSize / 2) - needleLength,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Kâbe İkonlu Tepe Rozeti (Her zaman düz dursun diye karşı rotasyon uygulanır)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = isAligned ? 1.0 + (_pulseController.value * 0.12) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAligned ? const Color(0xFF064E3B) : const Color(0xFF065F46),
                          border: Border.all(
                            color: isAligned ? const Color(0xFF34D399) : const Color(0xFFF59E0B),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isAligned ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                                  .withOpacity(isAligned ? 0.85 : 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -currentNeedleRotation,
                            child: const Text("🕋", style: TextStyle(fontSize: 20)),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 2),

                // Sivri İbre Oku
                Icon(
                  CupertinoIcons.triangle_fill,
                  size: 20,
                  color: isAligned ? const Color(0xFF34D399) : const Color(0xFFF59E0B),
                ),

                // Parlak Işık Gövdesi
                Container(
                  width: 5,
                  height: needleLength - 66,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAligned
                          ? [const Color(0xFF34D399), const Color(0xFF10B981).withOpacity(0.2)]
                          : [const Color(0xFFF59E0B), const Color(0xFFF59E0B).withOpacity(0.1)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricItem({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          subtext,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getDirectionNameShort(double heading) {
    if (heading >= 337.5 || heading < 22.5) return "K";
    if (heading >= 22.5 && heading < 67.5) return "KD";
    if (heading >= 67.5 && heading < 112.5) return "D";
    if (heading >= 112.5 && heading < 157.5) return "GD";
    if (heading >= 157.5 && heading < 202.5) return "G";
    if (heading >= 202.5 && heading < 247.5) return "GB";
    if (heading >= 247.5 && heading < 292.5) return "B";
    if (heading >= 292.5 && heading < 337.5) return "KB";
    return "";
  }

  String _getDirectionNameLong(double heading) {
    if (heading >= 337.5 || heading < 22.5) return "Kuzey";
    if (heading >= 22.5 && heading < 67.5) return "Kuzeydoğu";
    if (heading >= 67.5 && heading < 112.5) return "Doğu";
    if (heading >= 112.5 && heading < 157.5) return "Güneydoğu";
    if (heading >= 157.5 && heading < 202.5) return "Güney";
    if (heading >= 202.5 && heading < 247.5) return "Güneybatı";
    if (heading >= 247.5 && heading < 292.5) return "Batı";
    if (heading >= 292.5 && heading < 337.5) return "Kuzeybatı";
    return "";
  }
}

/// Lüks Pusula Kadranı Çizimi (Kuzey, Doğu, Güney, Batı, Dereceler ve Kâbe İşareti)
class _CompassDialPainter extends CustomPainter {
  final double qiblaAngle;
  final bool isAligned;

  _CompassDialPainter({
    required this.qiblaAngle,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dış Daire Arka Planı
    final bgPaint = Paint()
      ..color = const Color(0xFF0C1626).withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 4, bgPaint);

    // 2. Dış ve İç Çember Çizgileri
    final outerRingPaint = Paint()
      ..color = isAligned
          ? const Color(0xFF10B981).withOpacity(0.7)
          : Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius - 4, outerRingPaint);

    final innerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 0.72, innerRingPaint);

    // 3. Derece Çentikleri ve Yönler
    final tickPaint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 360; i += 5) {
      final double angle = i * (math.pi / 180.0) - (math.pi / 2.0);
      final bool isMajor = i % 30 == 0;
      final bool isCardinal = i % 90 == 0;

      final double tickLength = isCardinal ? 16 : (isMajor ? 11 : 5);
      final double strokeWidth = isCardinal ? 2.8 : (isMajor ? 1.6 : 0.9);

      tickPaint.color = isCardinal
          ? (i == 0 ? const Color(0xFFEF4444) : Colors.white)
          : (isMajor ? Colors.white70 : Colors.white30);
      tickPaint.strokeWidth = strokeWidth;

      final double startRadius = radius - 8;
      final double endRadius = startRadius - tickLength;

      final p1 = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );

      canvas.drawLine(p1, p2, tickPaint);

      // Ana Yön Harfleri: K (Kırmızı), D, G, B
      if (isCardinal) {
        final String text = i == 0
            ? "K"
            : (i == 90 ? "D" : (i == 180 ? "G" : "B"));
        final textPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: i == 0 ? const Color(0xFFEF4444) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final double textRadius = radius - 34;
        final textOffset = Offset(
          center.dx + textRadius * math.cos(angle) - (textPainter.width / 2),
          center.dy + textRadius * math.sin(angle) - (textPainter.height / 2),
        );
        textPainter.paint(canvas, textOffset);
      }
    }

    // 4. Kadran Üzerindeki Sabit Altın Kâbe Noktası (Kıble Açısı Konumu)
    final double qiblaRad = qiblaAngle * (math.pi / 180.0) - (math.pi / 2.0);
    final double markerRadius = radius - 16;
    final markerCenter = Offset(
      center.dx + markerRadius * math.cos(qiblaRad),
      center.dy + markerRadius * math.sin(qiblaRad),
    );

    final qiblaDotPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(markerCenter, 5, qiblaDotPaint);
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned || oldDelegate.qiblaAngle != qiblaAngle;
  }
}

/// Şehir ve Konum Seçici Modal
class _CityPickerBottomSheet extends StatefulWidget {
  final List<QiblaCity> cities;
  final String currentCityName;
  final VoidCallback onGpsSelected;
  final Function(QiblaCity) onCitySelected;

  const _CityPickerBottomSheet({
    required this.cities,
    required this.currentCityName,
    required this.onGpsSelected,
    required this.onCitySelected,
  });

  @override
  State<_CityPickerBottomSheet> createState() => _CityPickerBottomSheetState();
}

class _CityPickerBottomSheetState extends State<_CityPickerBottomSheet> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredCities = widget.cities.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.province.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Çentik
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(CupertinoIcons.placemark_fill, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Şehir ve Konum Seçimi",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // GPS Butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              onTap: widget.onGpsSelected,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.location_fill, color: Color(0xFF34D399), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Mevcut GPS Konumumu Bul",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Cihazınızın GPS koordinatlarını alarak kıbleyi otomatik hesaplar",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),
          ),

          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Şehir veya ilçe ara...",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(CupertinoIcons.search, color: Colors.white54, size: 18),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Şehirler Listesi
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: filteredCities.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (ctx, idx) {
                final city = filteredCities[idx];
                final isSelected = widget.currentCityName.contains(city.name);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      city.isDefault ? CupertinoIcons.star_fill : CupertinoIcons.placemark,
                      color: isSelected
                          ? const Color(0xFF34D399)
                          : (city.isDefault ? const Color(0xFFF59E0B) : Colors.white60),
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        city.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF34D399) : Colors.white,
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (city.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Pazarcık",
                            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    city.province,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Color(0xFF10B981), size: 22)
                      : null,
                  onTap: () => widget.onCitySelected(city),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
