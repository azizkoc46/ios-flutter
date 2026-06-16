import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pazarcik_portal/utils/map_launcher.dart';

// ── Sabitler ──────────────────────────────────────────────────────
const _kRed = Color(0xFFE53935);
const _kRedLight = Color(0xFFFFEBEE);
const _kRedMid = Color(0xFFFFCDD2);
const _kBg = Color(0xFFF9F9F9);
const _kAfterHour = 17;

const _kScriptUrl =
    'https://script.google.com/macros/s/AKfycbyKYLWBU8pkuSljmyXRviOzK8aAVt4VIvTzJ8s7sigHBxShb0-26ch4vygN5h0IOtmV-g/exec';

const _kAllCacheHours = 12;
const _kDutyCacheHours = 2;

const _kPrefAll = 'gs_all_v1';
const _kPrefAllTs = 'gs_all_ts_v1';
const _kPrefDuty = 'gs_duty_v1';
const _kPrefDutyTs = 'gs_duty_ts_v1';
const _kPrefDutyLabel = 'gs_duty_label_v1';

// DÜZELTME: Önbelleğin hangi tarihe ait olduğunu saklıyoruz.
// Böylece gece yarısı geçtikten sonra eski önbellek geçersiz sayılır.
const _kPrefDutyDate = 'gs_duty_date_v1';

enum PharmacyTab { allPharmacies, onDuty }

// ═══════════════════════════════════════════════════════════════════
//  VERİ SERVİSİ
// ═══════════════════════════════════════════════════════════════════
class _PharmacyService {
  // ── Tüm eczaneler ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>?> getCachedAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kPrefAllTs);
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _kAllCacheHours * 3600 * 1000) return null;
    final raw = prefs.getString(_kPrefAll);
    if (raw == null) return null;
    try {
      return (json.decode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveAll(List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefAll, json.encode(data));
    await prefs.setInt(_kPrefAllTs, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final url = '$_kScriptUrl?type=all';
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body);
      final list = body['pharmacies'] as List?;
      if (list == null || list.isEmpty) return [];
      final data =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await _saveAll(data);
      return data;
    } catch (_) {
      return [];
    }
  }

  // ── Nöbetçi ────────────────────────────────────────────────────
  // DÜZELTME: Önbellek kontrolünde tarihi de karşılaştırıyoruz.
  // Eğer önbellekteki tarih bugünle eşleşmiyorsa (gece geçti),
  // önbelleği geçersiz sayıyoruz.
  static Future<({List<Map<String, dynamic>> list, String label})?>
      getCachedDuty() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kPrefDutyTs);
    if (ts == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _kDutyCacheHours * 3600 * 1000) return null;

    // DÜZELTME: Önbellek bugünün tarihine ait mi?
    final cachedDate = prefs.getString(_kPrefDutyDate);
    final todayStr = _isoDate(DateTime.now());
    if (cachedDate != todayStr) {
      // Tarih değişmiş (gece yarısı geçildi), önbellek geçersiz
      return null;
    }

    final raw = prefs.getString(_kPrefDuty);
    final label = prefs.getString(_kPrefDutyLabel) ?? '';
    if (raw == null) return null;
    try {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      return (list: list, label: label);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveDuty(
      List<Map<String, dynamic>> data, String label, String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefDuty, json.encode(data));
    await prefs.setString(_kPrefDutyLabel, label);
    await prefs.setString(_kPrefDutyDate, date); // DÜZELTME: tarihi kaydet
    await prefs.setInt(_kPrefDutyTs, DateTime.now().millisecondsSinceEpoch);
  }

  /// DÜZELTME: fetchDuty artık her zaman bugünün tarihini ister.
  /// Script tarafında "en yakın geçmiş" mantığı kaldırıldığından,
  /// bugün sheet'te yoksa boş liste döner (00:00-02:00 arası pencere).
  /// Bu durumda kullanıcıya net bir hata gösterilir.
  static Future<({List<Map<String, dynamic>> list, String label})?>
      fetchDuty() async {
    final today = _isoDate(DateTime.now());
    final url = '$_kScriptUrl?type=duty&date=$today';
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body);

      // DÜZELTME: Artık body['date'] yerine her zaman bugünün tarihini kullan.
      // Script "bulunan tarihi" döndürüyordu; bu dün olabiliyordu.
      final list = (body['pharmacies'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      if (list.isEmpty) return null;

      // DÜZELTME: Etiket için her zaman bugünün tarihini kullan
      final label = _turkishDate(DateTime.now());
      await _saveDuty(list, label, today);
      return (list: list, label: label);
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  YARDIMCI FONKSİYONLAR
// ═══════════════════════════════════════════════════════════════════
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

String _turkishDate(DateTime d) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];
  const days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year} ${days[d.weekday - 1]}';
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════
//  ANA EKRAN
// ═══════════════════════════════════════════════════════════════════
class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({Key? key}) : super(key: key);
  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen>
    with TickerProviderStateMixin {
  late PharmacyTab _activeTab;
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _allPharms = [];
  List<Map<String, dynamic>> _displayPharms = [];
  bool _pharmsLoading = true;
  String _pharmsError = '';
  bool _pharmsFromCache = false;

  List<Map<String, dynamic>> _allDuty = [];
  List<Map<String, dynamic>> _displayDuty = [];
  bool _dutyLoading = true;
  String _dutyError = '';
  String _dutyDateLabel = '';
  bool _dutyFromCache = false;

  Position? _userPosition;
  bool _pharmsLocLoading = false;
  bool _dutyLocLoading = false;
  bool _pharmsByDist = false;
  bool _dutyByDist = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    _activeTab =
        hour >= _kAfterHour ? PharmacyTab.onDuty : PharmacyTab.allPharmacies;
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: _activeTab == PharmacyTab.allPharmacies ? 0 : 1,
    );
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() => _activeTab =
          _tabCtrl.index == 0 ? PharmacyTab.allPharmacies : PharmacyTab.onDuty);
    });
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
    _loadDuty();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  //  YÜKLEME FONKSİYONLARI
  // ════════════════════════════════════════
  Future<void> _loadAll({bool force = false}) async {
    setState(() {
      _pharmsLoading = true;
      _pharmsError = '';
      _pharmsFromCache = false;
    });
    _fadeCtrl.reset();

    if (!force) {
      final cached = await _PharmacyService.getCachedAll();
      if (cached != null && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _allPharms = cached;
          _displayPharms = List.from(cached);
          _pharmsLoading = false;
          _pharmsFromCache = true;
        });
        _fadeCtrl.forward();
        if (_userPosition != null && _pharmsByDist) _applyPharmsSorting();
        return;
      }
    }

    final data = await _PharmacyService.fetchAll();
    if (!mounted) return;
    setState(() {
      _allPharms = data;
      _displayPharms = List.from(data);
      _pharmsLoading = false;
      if (data.isEmpty)
        _pharmsError =
            'Sunucudan veri alınamadı. Lütfen daha sonra tekrar deneyin.';
    });
    _fadeCtrl.forward();
    if (_userPosition != null && _pharmsByDist) _applyPharmsSorting();
  }

  Future<void> _loadDuty({bool force = false}) async {
    setState(() {
      _dutyLoading = true;
      _dutyError = '';
      _dutyFromCache = false;
    });
    _fadeCtrl.reset();

    // DÜZELTME: Önbellek kontrolü artık tarih duyarlı
    if (!force) {
      final cached = await _PharmacyService.getCachedDuty();
      if (cached != null && cached.list.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _allDuty = cached.list;
          _displayDuty = List.from(cached.list);
          _dutyDateLabel = cached.label;
          _dutyLoading = false;
          _dutyFromCache = true;
        });
        _fadeCtrl.forward();
        if (_userPosition != null && _dutyByDist) _applyDutySorting();
        return;
      }
    }

    final result = await _PharmacyService.fetchDuty();
    if (!mounted) return;
    if (result != null && result.list.isNotEmpty) {
      setState(() {
        _allDuty = result.list;
        _displayDuty = List.from(result.list);
        _dutyDateLabel = result.label;
        _dutyLoading = false;
      });
      _fadeCtrl.forward();
      if (_userPosition != null && _dutyByDist) _applyDutySorting();
    } else {
      setState(() {
        _dutyLoading = false;
        // DÜZELTME: Saat 00:00-02:00 arası özel mesaj
        final hour = DateTime.now().hour;
        _dutyError = hour == 0 || hour == 1
            ? 'Nöbetçi listesi güncelleniyor (00:00-02:00 arası). Lütfen birkaç dakika sonra tekrar deneyin.'
            : 'Nöbetçi eczane verisi alınamadı. Aşağı çekerek yenileyin.';
      });
    }
  }

  // ════════════════════════════════════════
  //  KONUM
  // ════════════════════════════════════════
  Future<void> _getLocation({required bool forDuty}) async {
    if (_userPosition != null) {
      setState(() {
        if (forDuty)
          _dutyByDist = true;
        else
          _pharmsByDist = true;
      });
      forDuty ? _applyDutySorting() : _applyPharmsSorting();
      _showSnack('📍 En yakın eczaneler önce gösteriliyor.');
      return;
    }
    setState(() {
      if (forDuty)
        _dutyLocLoading = true;
      else
        _pharmsLocLoading = true;
    });
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _dutyLocLoading = false;
        _pharmsLocLoading = false;
      });
      _showSnack('Konum izni reddedildi. Ayarlardan açın.');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        _userPosition = pos;
        _dutyLocLoading = false;
        _pharmsLocLoading = false;
        if (forDuty)
          _dutyByDist = true;
        else
          _pharmsByDist = true;
      });
      forDuty ? _applyDutySorting() : _applyPharmsSorting();
      _showSnack('📍 En yakın eczaneler önce gösteriliyor.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dutyLocLoading = false;
        _pharmsLocLoading = false;
      });
      _showSnack('Konum alınamadı. GPS\'in açık olduğunu kontrol edin.');
    }
  }

  double _haversine(double la1, double lo1, double la2, double lo2) {
    const R = 6371000.0;
    final dLa = (la2 - la1) * pi / 180;
    final dLo = (lo2 - lo1) * pi / 180;
    final a = sin(dLa / 2) * sin(dLa / 2) +
        cos(la1 * pi / 180) * cos(la2 * pi / 180) * sin(dLo / 2) * sin(dLo / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _fmtDist(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  double? _dist(dynamic p) {
    if (_userPosition == null) return null;
    final loc = p['location'] as Map<String, dynamic>?;
    final lat = _toDouble(loc?['latitude']);
    final lon = _toDouble(loc?['longitude']);
    if (lat == 0 && lon == 0) return null;
    return _haversine(
        _userPosition!.latitude, _userPosition!.longitude, lat, lon);
  }

  void _applyDutySorting() {
    if (!mounted) return;
    setState(() {
      _displayDuty = List.from(_allDuty)
        ..sort((a, b) => (_dist(a) ?? double.infinity)
            .compareTo(_dist(b) ?? double.infinity));
    });
  }

  void _applyPharmsSorting() {
    if (!mounted) return;
    setState(() {
      _displayPharms = List.from(_allPharms)
        ..sort((a, b) => (_dist(a) ?? double.infinity)
            .compareTo(_dist(b) ?? double.infinity));
    });
  }

  void _toggleDutySort() {
    if (_userPosition == null) {
      _getLocation(forDuty: true);
      return;
    }
    setState(() => _dutyByDist = !_dutyByDist);
    if (_dutyByDist)
      _applyDutySorting();
    else
      setState(() => _displayDuty = List.from(_allDuty));
  }

  void _togglePharmsSort() {
    if (_userPosition == null) {
      _getLocation(forDuty: false);
      return;
    }
    setState(() => _pharmsByDist = !_pharmsByDist);
    if (_pharmsByDist)
      _applyPharmsSorting();
    else
      setState(() => _displayPharms = List.from(_allPharms));
  }

  Future<void> _call(String phone) async {
    final c = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (c.isEmpty) {
      _showSnack('Telefon numarası yok.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: c);
    if (await canLaunchUrl(uri))
      await launchUrl(uri);
    else
      _showSnack('Arama başlatılamadı.');
  }

  Future<void> _map(double lat, double lon) async {
    if (lat == 0 && lon == 0) {
      _showSnack('Konum bilgisi yok.');
      return;
    }
    await PortalMapLauncher.open(context, latitude: lat, longitude: lon);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isAfterHours = hour >= _kAfterHour;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          _buildAppBar(isAfterHours),
          SliverToBoxAdapter(child: _buildTabBar(isAfterHours)),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          physics: isAfterHours
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          children: [
            RefreshIndicator(
              color: _kRed,
              onRefresh: () => _loadAll(force: true),
              child: _AllPharmaciesTab(
                pharmacies: _displayPharms,
                isLoading: _pharmsLoading,
                errorMsg: _pharmsError,
                sortByDist: _pharmsByDist,
                userPos: _userPosition,
                locLoading: _pharmsLocLoading,
                fadeAnim: _fadeAnim,
                fromCache: _pharmsFromCache,
                distFn: _dist,
                fmtDist: _fmtDist,
                onToggleSort: _togglePharmsSort,
                onCall: _call,
                onMap: _map,
                onRetry: () => _loadAll(force: true),
              ),
            ),
            RefreshIndicator(
              color: _kRed,
              onRefresh: () => _loadDuty(force: true),
              child: _OnDutyTab(
                pharmacies: _displayDuty,
                isLoading: _dutyLoading,
                errorMsg: _dutyError,
                dateLabel: _dutyDateLabel,
                sortByDist: _dutyByDist,
                userPos: _userPosition,
                locLoading: _dutyLocLoading,
                fadeAnim: _fadeAnim,
                fromCache: _dutyFromCache,
                distFn: _dist,
                fmtDist: _fmtDist,
                onToggleSort: _toggleDutySort,
                onCall: _call,
                onMap: _map,
                onRetry: () => _loadDuty(force: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isAfterHours) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: _kRed,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(CupertinoIcons.back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)
              ],
            ),
            child: Center(
                child: Text('E',
                    style: GoogleFonts.nunito(
                        color: _kRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eczane',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17)),
                Text('Pazarcık • Kahramanmaraş',
                    style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 10)),
              ]),
        ]),
      ),
      actions: [
        if (isAfterHours)
          Container(
            margin: const EdgeInsets.only(right: 14, top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(CupertinoIcons.moon_stars_fill,
                  size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text('Gece Modu',
                  style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
    );
  }

  Widget _buildTabBar(bool isAfterHours) {
    return Container(
      color: _kRed,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14)),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle:
              GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13),
          labelColor: _kRed,
          unselectedLabelColor: Colors.white,
          padding: const EdgeInsets.all(3),
          tabs: [
            Tab(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(CupertinoIcons.building_2_fill, size: 14),
              const SizedBox(width: 6),
              const Text('Tüm Eczaneler'),
              if (isAfterHours) ...[
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.lock_fill, size: 11)
              ],
            ])),
            Tab(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(CupertinoIcons.moon_fill, size: 14),
              const SizedBox(width: 6),
              const Text('Nöbetçi'),
            ])),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SEKMELER
// ═══════════════════════════════════════════════════════════════════
class _AllPharmaciesTab extends StatelessWidget {
  final List<Map<String, dynamic>> pharmacies;
  final bool isLoading, sortByDist, locLoading, fromCache;
  final String errorMsg;
  final Position? userPos;
  final Animation<double> fadeAnim;
  final double? Function(dynamic) distFn;
  final String Function(double) fmtDist;
  final VoidCallback onToggleSort, onRetry;
  final Future<void> Function(String) onCall;
  final Future<void> Function(double, double) onMap;

  const _AllPharmaciesTab({
    required this.pharmacies,
    required this.isLoading,
    required this.errorMsg,
    required this.sortByDist,
    required this.userPos,
    required this.locLoading,
    required this.fadeAnim,
    required this.fromCache,
    required this.distFn,
    required this.fmtDist,
    required this.onToggleSort,
    required this.onCall,
    required this.onMap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Center(
          child: CupertinoActivityIndicator(radius: 15, color: _kRed));
    if (pharmacies.isEmpty)
      return _EmptyView(
          msg: errorMsg.isNotEmpty ? errorMsg : 'Eczane bulunamadı.',
          onRetry: onRetry);
    return CustomScrollView(slivers: [
      if (fromCache)
        SliverToBoxAdapter(
            child: _CacheBadge(
                label:
                    'Önbellekten yüklendi • Aşağı çekerek sunucudan yenileyebilirsiniz')),
      SliverToBoxAdapter(
          child: _LocationBanner(
              userPos: userPos,
              sortByDist: sortByDist,
              locLoading: locLoading,
              onTap: onToggleSort)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
          final p = pharmacies[i];
          return FadeTransition(
              opacity: fadeAnim,
              child: _PharmacyCard(
                  p: p,
                  distance: distFn(p),
                  isNearest: sortByDist && userPos != null && i == 0,
                  fmtDist: fmtDist,
                  onCall: onCall,
                  onMap: onMap,
                  isDuty: false));
        }, childCount: pharmacies.length)),
      ),
    ]);
  }
}

class _OnDutyTab extends StatelessWidget {
  final List<Map<String, dynamic>> pharmacies;
  final bool isLoading, sortByDist, locLoading, fromCache;
  final String errorMsg, dateLabel;
  final Position? userPos;
  final Animation<double> fadeAnim;
  final double? Function(dynamic) distFn;
  final String Function(double) fmtDist;
  final VoidCallback onToggleSort, onRetry;
  final Future<void> Function(String) onCall;
  final Future<void> Function(double, double) onMap;

  const _OnDutyTab({
    required this.pharmacies,
    required this.isLoading,
    required this.errorMsg,
    required this.dateLabel,
    required this.sortByDist,
    required this.userPos,
    required this.locLoading,
    required this.fadeAnim,
    required this.fromCache,
    required this.distFn,
    required this.fmtDist,
    required this.onToggleSort,
    required this.onCall,
    required this.onMap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: _DateBanner(label: dateLabel, isLoading: isLoading)),
      if (fromCache && !isLoading && pharmacies.isNotEmpty)
        SliverToBoxAdapter(
            child: _CacheBadge(
                label:
                    'Önbellekten yüklendi • Aşağı çekerek sunucudan yenileyebilirsiniz')),
      if (!isLoading && pharmacies.isNotEmpty)
        SliverToBoxAdapter(
            child: _LocationBanner(
                userPos: userPos,
                sortByDist: sortByDist,
                locLoading: locLoading,
                onTap: onToggleSort)),
      if (isLoading)
        const SliverFillRemaining(
            child: Center(
                child: CupertinoActivityIndicator(radius: 15, color: _kRed)))
      else if (pharmacies.isEmpty)
        SliverFillRemaining(
            child: _EmptyView(
                msg: errorMsg.isNotEmpty
                    ? errorMsg
                    : 'Nöbetçi eczane bulunamadı.',
                onRetry: onRetry))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
            final p = pharmacies[i];
            return FadeTransition(
                opacity: fadeAnim,
                child: _PharmacyCard(
                    p: p,
                    distance: distFn(p),
                    isNearest: sortByDist && userPos != null && i == 0,
                    fmtDist: fmtDist,
                    onCall: onCall,
                    onMap: onMap,
                    isDuty: true));
          }, childCount: pharmacies.length)),
        ),
    ]);
  }
}

class _CacheBadge extends StatelessWidget {
  final String label;
  const _CacheBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE082))),
        child: Row(children: [
          const Icon(CupertinoIcons.checkmark_seal_fill,
              size: 13, color: Color(0xFFF9A825)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF795548)))),
        ]),
      );
}

class _DateBanner extends StatelessWidget {
  final String label;
  final bool isLoading;
  const _DateBanner({required this.label, required this.isLoading});
  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                  color: _kRedLight, shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.clock, size: 15, color: _kRed)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nöbet tarihi',
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            Text(isLoading ? 'Yükleniyor...' : (label.isNotEmpty ? label : '-'),
                style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _kRed)),
          ]),
        ]),
      );
}

class _LocationBanner extends StatelessWidget {
  final Position? userPos;
  final bool sortByDist, locLoading;
  final VoidCallback onTap;
  const _LocationBanner(
      {required this.userPos,
      required this.sortByDist,
      required this.locLoading,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    if (locLoading)
      return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: _kRedLight, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const CupertinoActivityIndicator(radius: 8, color: _kRed),
            const SizedBox(width: 10),
            Text('Konum alınıyor...',
                style: GoogleFonts.nunito(
                    color: _kRed, fontWeight: FontWeight.w700, fontSize: 13)),
          ]));
    if (userPos == null)
      return GestureDetector(
          onTap: onTap,
          child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: _kRed, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(CupertinoIcons.location,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('En yakın eczaneyi bulmak için konuma izin ver',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
                const Icon(CupertinoIcons.chevron_right,
                    color: Colors.white, size: 14),
              ])));
    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: sortByDist ? const Color(0xFFE8F5E9) : _kRedLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: sortByDist ? Colors.green.shade200 : _kRedMid)),
            child: Row(children: [
              Icon(CupertinoIcons.location_fill,
                  size: 15, color: sortByDist ? Colors.green : _kRed),
              const SizedBox(width: 8),
              Text(
                  sortByDist
                      ? 'Yakınlık sırasına göre — normale dön'
                      : 'Yakına göre sırala',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: sortByDist ? Colors.green.shade700 : _kRed)),
            ])));
  }
}

class _PharmacyCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final double? distance;
  final bool isNearest, isDuty;
  final String Function(double) fmtDist;
  final Future<void> Function(String) onCall;
  final Future<void> Function(double, double) onMap;
  const _PharmacyCard(
      {required this.p,
      required this.distance,
      required this.isNearest,
      required this.fmtDist,
      required this.onCall,
      required this.onMap,
      required this.isDuty});

  @override
  Widget build(BuildContext context) {
    final name = p['name'] as String? ?? 'Eczane';
    final addr = p['address'] as String? ?? 'Adres bilgisi yok';
    final phone = p['phone'] as String? ?? '';
    final loc = p['location'] as Map<String, dynamic>?;
    final lat = _toDouble(loc?['latitude']);
    final lon = _toDouble(loc?['longitude']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isNearest
                  ? _kRed.withOpacity(0.5)
                  : Theme.of(context).dividerColor,
              width: isNearest ? 2 : 1.5),
          boxShadow: [
            BoxShadow(
                color: isNearest
                    ? _kRed.withOpacity(0.07)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ]),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: isNearest ? _kRed : _kRedLight,
                      borderRadius: BorderRadius.circular(13)),
                  child: Center(
                      child: Text('E',
                          style: GoogleFonts.nunito(
                              color: isNearest ? Colors.white : _kRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(name,
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface))),
                      if (isNearest)
                        _badge('EN YAKIN', _kRed, Colors.white)
                      else if (isDuty)
                        _badge('NÖBETÇİ', _kRedLight, _kRed),
                    ]),
                    const SizedBox(height: 4),
                    Text(addr,
                        style: GoogleFonts.nunito(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (distance != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(CupertinoIcons.location_fill,
                            size: 10, color: _kRed),
                        const SizedBox(width: 4),
                        Text(fmtDist(distance!),
                            style: GoogleFonts.nunito(
                                color: _kRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ],
                  ])),
            ])),
        Container(
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor))),
          child: Row(children: [
            Expanded(
                child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onPressed: phone.isNotEmpty ? () => onCall(phone) : null,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.phone_fill,
                              size: 14,
                              color: phone.isNotEmpty
                                  ? const Color(0xFF34C759)
                                  : Colors.grey),
                          const SizedBox(width: 6),
                          Text(phone.isNotEmpty ? phone : 'Numara Yok',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: phone.isNotEmpty
                                      ? const Color(0xFF34C759)
                                      : Colors.grey)),
                        ]))),
            Container(
                width: 1, height: 22, color: Theme.of(context).dividerColor),
            Expanded(
                child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onPressed: () => onMap(lat, lon),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.map_fill,
                              size: 14, color: Color(0xFF007AFF)),
                          const SizedBox(width: 6),
                          Text('Yol Tarifi',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: const Color(0xFF007AFF))),
                        ]))),
          ]),
        ),
      ]),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(text,
          style: GoogleFonts.nunito(
              color: fg,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4)));
}

class _EmptyView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _EmptyView({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                    color: _kRedLight, shape: BoxShape.circle),
                child:
                    const Icon(CupertinoIcons.capsule, size: 44, color: _kRed)),
            const SizedBox(height: 18),
            Text(msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black54)),
            const SizedBox(height: 18),
            CupertinoButton(
                color: _kRed,
                borderRadius: BorderRadius.circular(13),
                onPressed: onRetry,
                child: Text('Tekrar Dene',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800))),
          ])));
}
