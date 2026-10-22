// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveCourierMapCard extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const LiveCourierMapCard({
    Key? key,
    required this.orderData,
  }) : super(key: key);

  @override
  State<LiveCourierMapCard> createState() => _LiveCourierMapCardState();
}

class _LiveCourierMapCardState extends State<LiveCourierMapCard>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  LatLng? _lastKnownPosition;
  double _lastHeading = 0.0;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.45).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _extractLocation();
  }

  @override
  void didUpdateWidget(covariant LiveCourierMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _extractLocation();
  }

  void _extractLocation() {
    final location =
        widget.orderData['courierLocation'] as Map<String, dynamic>?;
    if (location != null &&
        location['latitude'] != null &&
        location['longitude'] != null) {
      final double lat = (location['latitude'] as num).toDouble();
      final double lng = (location['longitude'] as num).toDouble();
      final double heading =
          (location['heading'] as num?)?.toDouble() ?? _lastHeading;
      final newPos = LatLng(lat, lng);

      if (_lastKnownPosition == null ||
          _lastKnownPosition!.latitude != lat ||
          _lastKnownPosition!.longitude != lng) {
        _lastKnownPosition = newPos;
        _lastHeading = heading;
        if (_isMapReady) {
          _mapController.move(newPos, _mapController.camera.zoom);
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _formatSpeed(dynamic speedVal) {
    if (speedVal == null) return '0 km/s';
    final speed = (speedVal as num).toDouble();
    if (speed <= 0.5) return 'Durgun';
    final kmh = (speed * 3.6).round();
    return '$kmh km/s';
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Canlı';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    }
    if (dt == null) return 'Canlı';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 15) return 'Az önce';
    if (diff.inSeconds < 60) return '${diff.inSeconds} sn önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    return '${diff.inHours} sa önce';
  }

  Future<void> _callCourier(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openExternalGoogleMaps(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.orderData['status'] ?? '').toString();
    final bool isOnTheWay = status == 'Yolda';
    final bool isAtDoor = status == 'Kapıda';

    if (!isOnTheWay && !isAtDoor) {
      return const SizedBox.shrink();
    }

    final courierName =
        (widget.orderData['courierName'] ?? 'Kuryemiz').toString();
    final courierPhone =
        (widget.orderData['courierPhone'] ?? '').toString().trim();
    final location =
        widget.orderData['courierLocation'] as Map<String, dynamic>?;

    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();
    final speedVal = location?['speed'];
    final updatedAt = location?['updatedAt'];

    final bool hasLocation = lat != null && lng != null;
    final LatLng currentPos =
        hasLocation ? LatLng(lat, lng) : const LatLng(37.4858, 37.2981);

    final Color themeColor =
        isAtDoor ? const Color(0xFF2563EB) : const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: themeColor.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ÜST BAŞLIK & DURUM BİLGİSİ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isAtDoor
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF0FDF4),
                border: Border(
                  bottom: BorderSide(
                    color: themeColor.withOpacity(0.18),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAtDoor
                          ? CupertinoIcons.bell_fill
                          : CupertinoIcons.paperplane_fill,
                      color: themeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isAtDoor
                                  ? '🔔 Kuryeniz Kapınızda!'
                                  : '🛵 Kuryeniz Canlı Takipte',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: isAtDoor
                                    ? Colors.blue.shade900
                                    : const Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Canlı Nabız Göstergesi
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(
                                        0.3 + (0.7 * _pulseController.value)),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAtDoor
                              ? 'Lütfen siparişinizi teslim almak için kapıyı açınız.'
                              : '$courierName adresinize doğru ilerliyor.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (courierPhone.isNotEmpty)
                    IconButton(
                      tooltip: 'Kuryeyi Ara',
                      onPressed: () => _callCourier(courierPhone),
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.phone_fill,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── CANLI HARİTA GÖSTERİMİ (FLUTTER MAP)
            if (hasLocation)
              SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: currentPos,
                        initialZoom: 16.2,
                        minZoom: 12.0,
                        maxZoom: 18.5,
                        onMapReady: () {
                          _isMapReady = true;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.pazarcik.portal',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentPos,
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Radar Halkası (Pulse)
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Container(
                                          width: 55,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: themeColor.withOpacity(
                                              (1.0 - _pulseController.value)
                                                  .clamp(0.0, 0.4),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Kurye İkonu
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: themeColor,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Transform.rotate(
                                        angle: _lastHeading > 0
                                            ? (_lastHeading * math.pi / 180)
                                            : 0,
                                        child: Text(
                                          isAtDoor ? '🔔' : '🛵',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Harita Üzerindeki Kontroller
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _buildMapMiniButton(
                            icon: CupertinoIcons.scope,
                            tooltip: 'Kuryeye Odaklan',
                            onTap: () {
                              if (_lastKnownPosition != null) {
                                _mapController.move(_lastKnownPosition!, 16.5);
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildMapMiniButton(
                            icon: CupertinoIcons.plus,
                            tooltip: 'Yakınlaştır',
                            onTap: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildMapMiniButton(
                            icon: CupertinoIcons.minus,
                            tooltip: 'Uzaklaştır',
                            onTap: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Sol Üst Canlı GPS Rozeti
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Canlı GPS • ${_formatTimeAgo(updatedAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 120,
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CupertinoActivityIndicator(radius: 12),
                      const SizedBox(height: 8),
                      Text(
                        'Kuryenin canlı GPS sinyali bekleniyor...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── ALT BİLGİ VE HIZLI AKSİYONLAR
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatChip(
                        icon: CupertinoIcons.speedometer,
                        label: 'Kurye Hızı',
                        value: _formatSpeed(speedVal),
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        icon: CupertinoIcons.person_fill,
                        label: 'Kurye',
                        value: courierName,
                        color: const Color(0xFF3B82F6),
                      ),
                      if (hasLocation) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(CupertinoIcons.map, size: 14),
                            label: const Text(
                              'Google Harita',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () =>
                                _openExternalGoogleMaps(lat, lng),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🔒 Pazarcık Portal Güvencesi: Kurye siparişi teslim ettiği an canlı konum gizlilik nedeniyle anında kapatılır.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapMiniButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: Colors.grey.shade800),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
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
