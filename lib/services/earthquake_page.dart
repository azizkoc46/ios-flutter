// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class EarthquakeModel {
  final String id;
  final String title;
  final double magnitude;
  final DateTime dateTime; // Her zaman yerel saat (UTC+3)
  final double depth;
  final double lat;
  final double lng;
  final String source; // 'AFAD' | 'EMSC' | 'Kandilli'

  EarthquakeModel({
    required this.id,
    required this.title,
    required this.magnitude,
    required this.dateTime,
    required this.depth,
    required this.lat,
    required this.lng,
    required this.source,
  });

  /// AFAD apiv2 JSON → Model
  /// Örnek alan adları: eventDate, lat, lon, mag, depth, location
  factory EarthquakeModel.fromAFAD(Map<String, dynamic> json) {
    final rawDate = json['eventDate'] as String? ?? '';
    // AFAD UTC döndürür — UTC olarak parse et, sonra local'a çevir
    DateTime dt;
    try {
      dt = DateTime.parse('${rawDate.replaceAll(' ', 'T')}Z').toLocal();
    } catch (_) {
      dt = DateTime.now();
    }
    return EarthquakeModel(
      id: json['eventID']?.toString() ?? rawDate,
      title: json['location'] as String? ?? 'Konum Belirsiz',
      magnitude: double.tryParse(json['mag']?.toString() ?? '0') ?? 0.0,
      dateTime: dt,
      depth: double.tryParse(json['depth']?.toString() ?? '0') ?? 0.0,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      source: 'AFAD',
    );
  }

  /// EMSC GeoJSON feature → Model
  factory EarthquakeModel.fromEMSC(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final coords = (feature['geometry']?['coordinates'] as List?) ?? [];
    final lat = coords.length > 1 ? (coords[1] as num).toDouble() : 0.0;
    final lng = coords.isNotEmpty ? (coords[0] as num).toDouble() : 0.0;

    // EMSC: time epoch ms veya ISO string
    DateTime dt;
    final rawTime = props['time'];
    if (rawTime is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTime, isUtc: true).toLocal();
    } else if (rawTime is String) {
      try {
        dt = DateTime.parse(rawTime).toLocal();
      } catch (_) {
        dt = DateTime.now();
      }
    } else {
      dt = DateTime.now();
    }

    final mag = double.tryParse(props['mag']?.toString() ?? '0') ?? 0.0;
    final depth = double.tryParse(props['depth']?.toString() ?? '0') ?? 0.0;
    final title = props['flynn_region'] as String? ??
        props['place'] as String? ??
        'Konum Belirsiz';

    return EarthquakeModel(
      id: props['source_id']?.toString() ?? dt.toIso8601String(),
      title: title,
      magnitude: mag,
      dateTime: dt,
      depth: depth,
      lat: lat,
      lng: lng,
      source: 'EMSC',
    );
  }

  /// orhanaydogdu (Kandilli ara katman) → Model
  ///
  /// Gerçek API yanıtı (https://api.orhanaydogdu.com.tr/deprem/kandilli/live)
  /// üç farklı zaman alanı içerir, hepsi de TR yerel saatidir (UTC+3):
  ///   - "date"       → "2024.01.08 11:45:23"  (NOKTA ile ayrılmış, ISO formatı DEĞİL)
  ///   - "date_time"  → "2024-01-08 11:45:23"  (TİRE ile ayrılmış, ISO benzeri)
  ///   - "created_at" → 1704710723              (epoch SANİYE, UTC)
  ///
  /// Eski kod `date` alanını okuyup sonuna 'Z' ekleyerek parse etmeye
  /// çalışıyordu. Ancak "2024.01.08 11:45:23Z" formatı Dart'ın
  /// DateTime.parse'ı için GEÇERSİZDİR (nokta ayraçlı tarih ISO 8601 değil),
  /// bu yüzden her zaman istisna fırlatıp catch bloğunda DateTime.now()'a
  /// düşülüyordu — yani uygulama her zaman "şu anki saat"i gösteriyordu.
  ///
  /// Çözüm: doğrudan parse edilebilen `date_time` alanını (tire formatlı)
  /// önceliklendir; o da yoksa epoch `created_at` alanını kullan; en son
  /// çare olarak nokta formatlı `date` alanını manuel parse et.
  factory EarthquakeModel.fromKandilli(Map<String, dynamic> json) {
    DateTime dt;

    final dateTimeStr = json['date_time'] as String?; // "2024-01-08 11:45:23"
    final dateStr = json['date'] as String?; // "2024.01.08 11:45:23"
    final createdAt = json['created_at']; // epoch seconds (UTC)

    try {
      if (dateTimeStr != null && dateTimeStr.isNotEmpty) {
        // Tire formatlı, zaten TR yerel saati — Z eklemeden, toLocal()
        // çağırmadan OLDUĞU GİBİ parse et.
        dt = DateTime.parse(dateTimeStr);
      } else if (dateStr != null && dateStr.isNotEmpty) {
        // Nokta formatını tire formatına çevirip parse et:
        // "2024.01.08 11:45:23" → "2024-01-08 11:45:23"
        final normalized = dateStr.replaceAll('.', '-');
        dt = DateTime.parse(normalized);
      } else if (createdAt != null) {
        final epochSec =
            createdAt is int ? createdAt : int.tryParse(createdAt.toString());
        if (epochSec == null) throw FormatException('created_at geçersiz');
        dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000, isUtc: true)
            .toLocal();
      } else {
        dt = DateTime.now();
      }
    } catch (_) {
      dt = DateTime.now();
    }

    final coords = json['geojson']?['coordinates'];
    double lat = 0, lng = 0;
    if (coords is List && coords.length >= 2) {
      lng = double.tryParse(coords[0].toString()) ?? 0;
      lat = double.tryParse(coords[1].toString()) ?? 0;
    }

    return EarthquakeModel(
      id: json['earthquake_id']?.toString() ??
          dateTimeStr ??
          dateStr ??
          dt.toIso8601String(),
      title: json['title'] as String? ?? 'Konum Belirsiz',
      magnitude:
          double.tryParse((json['mag'] ?? json['magnitude'] ?? 0).toString()) ??
              0.0,
      dateTime: dt,
      depth: double.tryParse((json['depth'] ?? '0').toString()) ?? 0.0,
      lat: lat,
      lng: lng,
      source: 'Kandilli',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA SOURCE
// ─────────────────────────────────────────────────────────────────────────────

class EarthquakeService {
  static const double _pazarcikLat = 37.4878;
  static const double _pazarcikLng = 37.2958;
  static const double _minMag = 3.0;
  static const double _maxDistKm = 200.0;

  static double _dist(double lat, double lng) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat - _pazarcikLat) * p) / 2 +
        math.cos(_pazarcikLat * p) *
            math.cos(lat * p) *
            (1 - math.cos((lng - _pazarcikLng) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  static bool _keep(EarthquakeModel eq) =>
      eq.magnitude >= _minMag && _dist(eq.lat, eq.lng) <= _maxDistKm;

  // ── 1. AFAD (en hızlı, ~1–2 dk gecikme) ──────────────────────────────────
  static Future<List<EarthquakeModel>> fetchAFAD() async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(hours: 48));

    final uri = Uri.parse(
      'https://deprem.afad.gov.tr/apiv2/event/filter'
      '?start=${_fmt(start)}'
      '&end=${_fmt(now)}'
      '&minMag=$_minMag'
      '&orderby=timedesc',
    );

    final response = await http.get(uri, headers: {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('AFAD ${response.statusCode}');
    }

    final raw = jsonDecode(response.body);
    final List list = raw is List ? raw : (raw['data'] ?? raw['result'] ?? []);

    return list
        .map((e) => EarthquakeModel.fromAFAD(e as Map<String, dynamic>))
        .where(_keep)
        .toList();
  }

  // ── 2. EMSC (yedek, Avrupa ağı, kararlı) ─────────────────────────────────
  static Future<List<EarthquakeModel>> fetchEMSC() async {
    // Türkiye bounding box: lat 35–43, lon 25–45
    final uri = Uri.parse(
      'https://www.emsc-csem.org/service/api/1.6/get.geojson'
      '?type=full&minmag=$_minMag&minlat=35&maxlat=43&minlon=25&maxlon=45',
    );

    final response = await http.get(uri, headers: {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('EMSC ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final List features = data['features'] ?? [];

    return features
        .map((e) => EarthquakeModel.fromEMSC(e as Map<String, dynamic>))
        .where(_keep)
        .toList();
  }

  // ── 3. Kandilli ara katman (son çare) ─────────────────────────────────────
  static Future<List<EarthquakeModel>> fetchKandilli() async {
    final response = await http
        .get(Uri.parse('https://api.orhanaydogdu.com.tr/deprem/kandilli/live'))
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('Kandilli ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final List list = data['result'] ?? data['data'] ?? [];

    return list
        .map((e) => EarthquakeModel.fromKandilli(e as Map<String, dynamic>))
        .where(_keep)
        .toList();
  }

  // ── Zincir: AFAD → EMSC → Kandilli ───────────────────────────────────────
  static Future<({List<EarthquakeModel> list, String source})>
      fetchWithFallback() async {
    // 1. AFAD
    try {
      final list = await fetchAFAD();
      if (list.isNotEmpty) return (list: list, source: 'AFAD');
    } catch (_) {}

    // 2. EMSC
    try {
      final list = await fetchEMSC();
      if (list.isNotEmpty) return (list: list, source: 'EMSC');
    } catch (_) {}

    // 3. Kandilli
    final list = await fetchKandilli();
    return (list: list, source: 'Kandilli');
  }

  static String _fmt(DateTime dt) =>
      DateFormat("yyyy-MM-dd HH:mm:ss").format(dt);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class EarthquakePage extends StatefulWidget {
  const EarthquakePage({Key? key}) : super(key: key);

  @override
  State<EarthquakePage> createState() => _EarthquakePageState();
}

class _EarthquakePageState extends State<EarthquakePage> {
  List<EarthquakeModel> _earthquakes = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  String _activeSource = '';
  DateTime? _lastUpdated;
  Timer? _pollingTimer;
  Timer? _clockTimer; // son güncelleme yazısını tazele

  // Yeni deprem tespiti
  final Set<String> _seenIds = {};
  final Set<String> _newIds = {};

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
    // 15 saniyede bir arka planda güncelle (daha hızlı yenileme)
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
    // Her saniye "X sn önce" yazısını güncelle
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) _isLoading = true;
      _isRefreshing = !initial;
      _errorMessage = '';
    });

    try {
      final result = await EarthquakeService.fetchWithFallback();
      result.list.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      final incoming = result.list.map((e) => e.id).toSet();
      final fresh = incoming.difference(_seenIds);
      _seenIds.addAll(incoming);

      if (!mounted) return;
      setState(() {
        _earthquakes = result.list;
        _activeSource = result.source;
        _isLoading = false;
        _isRefreshing = false;
        _lastUpdated = DateTime.now();
        if (!initial) {
          _newIds
            ..clear()
            ..addAll(fresh);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Tüm kaynaklar yanıt vermedi.\n$e';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  String _lastUpdatedText() {
    if (_lastUpdated == null) return '';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s önce';
    return '${diff.inMinutes}dk önce';
  }

  @override
  Widget build(BuildContext context) {
    final maxMag = _earthquakes.isEmpty
        ? 0.0
        : _earthquakes.map((e) => e.magnitude).reduce(math.max);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CupertinoActivityIndicator(
                radius: 20,
                color: Colors.white54,
              ),
            )
          : _errorMessage.isNotEmpty
              ? _ErrorState(
                  message: _errorMessage,
                  onRetry: () => _fetch(initial: true),
                )
              : Column(
                  children: [
                    _StatusBar(
                      count: _earthquakes.length,
                      maxMag: maxMag,
                      source: _activeSource,
                      lastUpdatedText: _lastUpdatedText(),
                      isRefreshing: _isRefreshing,
                    ),
                    Expanded(
                      child: _earthquakes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.checkmark_shield,
                                    color: Color(0xFF30D158),
                                    size: 44,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Bölgede 3.0+ deprem kaydedilmedi.',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                              itemCount: _earthquakes.length,
                              itemBuilder: (context, i) {
                                final eq = _earthquakes[i];
                                return _EarthquakeTile(
                                  eq: eq,
                                  isNew: _newIds.contains(eq.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          const SizedBox(width: 8),
          Text(
            'Deprem Radarı',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : () => _fetch(initial: true),
          icon: _isRefreshing
              ? const CupertinoActivityIndicator(
                  color: Colors.white54, radius: 10)
              : const Icon(CupertinoIcons.refresh, color: Colors.white),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULSE DOT (animasyonlu canlı göstergesi)
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4444),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BAR
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final int count;
  final double maxMag;
  final String source;
  final String lastUpdatedText;
  final bool isRefreshing;

  const _StatusBar({
    required this.count,
    required this.maxMag,
    required this.source,
    required this.lastUpdatedText,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          _Chip(
            label: 'TOPLAM',
            value: '$count deprem',
            color: const Color(0xFF58A6FF),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'EN BÜYÜK',
            value: maxMag > 0 ? 'M${maxMag.toStringAsFixed(1)}' : '—',
            color: maxMag >= 4.0
                ? const Color(0xFFFF4444)
                : maxMag >= 3.5
                    ? const Color(0xFFFF9500)
                    : const Color(0xFF30D158),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'KAYNAK',
            value: source,
            color: source == 'AFAD'
                ? const Color(0xFF30D158)
                : source == 'EMSC'
                    ? const Color(0xFFFFCC00)
                    : const Color(0xFFFF9500),
          ),
          const Spacer(),
          if (isRefreshing)
            const CupertinoActivityIndicator(color: Colors.grey, radius: 8)
          else if (lastUpdatedText.isNotEmpty)
            Text(
              lastUpdatedText,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EARTHQUAKE TILE
// ─────────────────────────────────────────────────────────────────────────────

class _EarthquakeTile extends StatelessWidget {
  final EarthquakeModel eq;
  final bool isNew;

  const _EarthquakeTile({required this.eq, this.isNew = false});

  Color get _color {
    if (eq.magnitude >= 4.5) return const Color(0xFFFF2D2D);
    if (eq.magnitude >= 4.0) return const Color(0xFFFF6B35);
    if (eq.magnitude >= 3.5) return const Color(0xFFFF9500);
    return const Color(0xFFFFCC00);
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(eq.dateTime);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('HH:mm').format(eq.dateTime);
    final formattedDate = DateFormat('dd.MM.yyyy').format(eq.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew ? _color.withOpacity(0.55) : const Color(0xFF30363D),
          width: isNew ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Büyüklük kutusu
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _color.withOpacity(0.35)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'M',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: _color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    eq.magnitude.toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      color: _color,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Detaylar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık + YENİ badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isNew) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YENİ',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: _color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          eq.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Tarih & Saat
                  Row(
                    children: [
                      const Icon(CupertinoIcons.calendar,
                          size: 11, color: Color(0xFF8B949E)),
                      const SizedBox(width: 3),
                      Text(
                        '$formattedDate  $formattedTime',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8B949E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Derinlik & Zaman önce & Kaynak
                  Row(
                    children: [
                      const Icon(CupertinoIcons.arrow_down_circle,
                          size: 11, color: Color(0xFF6E7681)),
                      const SizedBox(width: 3),
                      Text(
                        '${eq.depth.toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF6E7681),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(CupertinoIcons.clock,
                          size: 11, color: Color(0xFF6E7681)),
                      const SizedBox(width: 3),
                      Text(
                        _timeAgo(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF6E7681),
                        ),
                      ),
                      const Spacer(),
                      // Kaynak etiketi
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          eq.source,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: const Color(0xFF8B949E),
                            fontWeight: FontWeight.w600,
                          ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF9500),
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF8B949E),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              color: const Color(0xFF238636),
              onPressed: onRetry,
              child: Text(
                'Tekrar Dene',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
