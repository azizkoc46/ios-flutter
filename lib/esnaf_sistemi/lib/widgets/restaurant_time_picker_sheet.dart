// ignore_for_file: deprecated_member_use
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _trendyolOrange = Color(0xFFF27A1A);
const Color _iosBg = Color(0xFFF2F2F7);

/// Restoran / Mağaza çalışma saatlerini modern, animasyonlu ve %100 Türkçe
/// 24 saat formatında seçtiren alt sayfa (Bottom Sheet).
class RestaurantTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialOpenTime;
  final TimeOfDay initialCloseTime;
  final bool initialIsOpening; // Başlangıçta Açılış mı Kapanış mı seçili olsun?

  const RestaurantTimePickerSheet({
    Key? key,
    required this.initialOpenTime,
    required this.initialCloseTime,
    this.initialIsOpening = true,
  }) : super(key: key);

  /// Kolay açma fonksiyonu
  static Future<Map<String, TimeOfDay>?> show({
    required BuildContext context,
    required TimeOfDay openTime,
    required TimeOfDay closeTime,
    bool isOpening = true,
  }) {
    return showModalBottomSheet<Map<String, TimeOfDay>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => RestaurantTimePickerSheet(
        initialOpenTime: openTime,
        initialCloseTime: closeTime,
        initialIsOpening: isOpening,
      ),
    );
  }

  @override
  State<RestaurantTimePickerSheet> createState() =>
      _RestaurantTimePickerSheetState();
}

class _RestaurantTimePickerSheetState extends State<RestaurantTimePickerSheet>
    with SingleTickerProviderStateMixin {
  late bool _isOpening;
  late int _openHour;
  late int _openMinute;
  late int _closeHour;
  late int _closeMinute;

  late FixedExtentScrollController _hourScrollController;
  late FixedExtentScrollController _minuteScrollController;

  // Hızlı Açılış Seçenekleri
  static const List<String> _openPresets = [
    "07:00",
    "07:30",
    "08:00",
    "08:30",
    "09:00",
    "09:30",
    "10:00",
    "10:30",
    "11:00",
  ];

  // Hızlı Kapanış Seçenekleri
  static const List<String> _closePresets = [
    "20:00",
    "21:00",
    "22:00",
    "22:30",
    "23:00",
    "23:30",
    "00:00",
    "01:00",
    "02:00",
  ];

  @override
  void initState() {
    super.initState();
    _isOpening = widget.initialIsOpening;
    _openHour = widget.initialOpenTime.hour;
    _openMinute = widget.initialOpenTime.minute;
    _closeHour = widget.initialCloseTime.hour;
    _closeMinute = widget.initialCloseTime.minute;

    final initialH = _isOpening ? _openHour : _closeHour;
    final initialM = _isOpening ? _openMinute : _closeMinute;

    _hourScrollController = FixedExtentScrollController(initialItem: initialH);
    _minuteScrollController =
        FixedExtentScrollController(initialItem: initialM);
  }

  @override
  void dispose() {
    _hourScrollController.dispose();
    _minuteScrollController.dispose();
    super.dispose();
  }

  void _switchTab(bool toOpening) {
    if (_isOpening == toOpening) return;
    setState(() {
      _isOpening = toOpening;
    });

    final targetH = _isOpening ? _openHour : _closeHour;
    final targetM = _isOpening ? _openMinute : _closeMinute;

    _animatePickersTo(targetH, targetM);
  }

  void _animatePickersTo(int hour, int minute) {
    if (_hourScrollController.hasClients) {
      _hourScrollController.animateToItem(
        hour,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (_minuteScrollController.hasClients) {
      _minuteScrollController.animateToItem(
        minute,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _applyPreset(String presetStr) {
    final parts = presetStr.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);

    setState(() {
      if (_isOpening) {
        _openHour = h;
        _openMinute = m;
      } else {
        _closeHour = h;
        _closeMinute = m;
      }
    });

    _animatePickersTo(h, m);
  }

  String _formatDigits(int val) => val.toString().padLeft(2, '0');

  String _calculateOpenDuration() {
    int startMinutes = _openHour * 60 + _openMinute;
    int endMinutes = _closeHour * 60 + _closeMinute;

    // Eğer kapanış ertesi güne sarkıyorsa (örn: 08:00 - 02:00)
    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60;
    }

    final diff = endMinutes - startMinutes;
    final h = diff ~/ 60;
    final m = diff % 60;

    if (m == 0) return "$h saat";
    return "$h saat $m dakika";
  }

  @override
  Widget build(BuildContext context) {
    final curH = _isOpening ? _openHour : _closeHour;
    final curM = _isOpening ? _openMinute : _closeMinute;

    final themeColor = _isOpening ? const Color(0xFFF27A1A) : const Color(0xFF5B5CE5);
    final themeBgLight = _isOpening ? const Color(0xFFFFF3E6) : const Color(0xFFEEF0FD);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Sürükleme Çubuğu
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık & Açıklama
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeBgLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        _isOpening
                            ? CupertinoIcons.sun_max_fill
                            : CupertinoIcons.moon_stars_fill,
                        color: themeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOpening ? "Açılış Saati Ayarı" : "Kapanış Saati Ayarı",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isOpening
                                ? "Müşteriler bu saatten itibaren sipariş verebilir."
                                : "Bu saatten sonra restoranınız siparişe kapanır.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill,
                          color: Colors.black26, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Segment Seçici (Açılış vs Kapanış Sekmesi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _iosBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          title: "Açılış Saati",
                          timeStr:
                              "${_formatDigits(_openHour)}:${_formatDigits(_openMinute)}",
                          icon: CupertinoIcons.sun_max_fill,
                          isActive: _isOpening,
                          activeColor: const Color(0xFFF27A1A),
                          onTap: () => _switchTab(true),
                        ),
                      ),
                      Expanded(
                        child: _tabButton(
                          title: "Kapanış Saati",
                          timeStr:
                              "${_formatDigits(_closeHour)}:${_formatDigits(_closeMinute)}",
                          icon: CupertinoIcons.moon_stars_fill,
                          isActive: !_isOpening,
                          activeColor: const Color(0xFF5B5CE5),
                          onTap: () => _switchTab(false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Büyük LED / Dijital Saat Göstergesi
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor.withOpacity(0.08),
                      themeColor.withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: themeColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _digitalDigitBlock(_formatDigits(curH), "SAAT"),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        ":",
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: themeColor,
                        ),
                      ),
                    ),
                    _digitalDigitBlock(_formatDigits(curM), "DAKİKA"),
                    const SizedBox(width: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isOpening ? "24 Saat (Gündüz)" : "24 Saat (Gece)",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Çark Seçici (CupertinoPicker 24-Saat & Dakika)
              SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    // Arka plan seçim vurgusu
                    Center(
                      child: Container(
                        height: 42,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themeColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        // Saat Çarkı (00 - 23)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Saat (00 - 23)",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: _hourScrollController,
                                  itemExtent: 42,
                                  selectionOverlay: const SizedBox.shrink(),
                                  childCount: 24,
                                  onSelectedItemChanged: (index) {
                                    setState(() {
                                      if (_isOpening) {
                                        _openHour = index;
                                      } else {
                                        _closeHour = index;
                                      }
                                    });
                                  },
                                  itemBuilder: (ctx, index) {
                                    final isSelected = index == curH;
                                    return Center(
                                      child: Text(
                                        _formatDigits(index),
                                        style: GoogleFonts.inter(
                                          fontSize: isSelected ? 24 : 18,
                                          fontWeight: isSelected
                                              ? FontWeight.w900
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? themeColor
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // İki nokta ayırıcı
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            ":",
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: themeColor,
                            ),
                          ),
                        ),

                        // Dakika Çarkı (00 - 59)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Dakika (00 - 59)",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: _minuteScrollController,
                                  itemExtent: 42,
                                  selectionOverlay: const SizedBox.shrink(),
                                  childCount: 60,
                                  onSelectedItemChanged: (index) {
                                    setState(() {
                                      if (_isOpening) {
                                        _openMinute = index;
                                      } else {
                                        _closeMinute = index;
                                      }
                                    });
                                  },
                                  itemBuilder: (ctx, index) {
                                    final isSelected = index == curM;
                                    return Center(
                                      child: Text(
                                        _formatDigits(index),
                                        style: GoogleFonts.inter(
                                          fontSize: isSelected ? 24 : 18,
                                          fontWeight: isSelected
                                              ? FontWeight.w900
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? themeColor
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Hızlı Seçim Çipleri (Presets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.bolt_fill,
                            size: 14, color: themeColor),
                        const SizedBox(width: 6),
                        Text(
                          _isOpening
                              ? "Popüler Açılış Saatleri"
                              : "Popüler Kapanış Saatleri",
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: (_isOpening ? _openPresets : _closePresets)
                            .map((preset) {
                          final isCurrent = preset ==
                              "${_formatDigits(curH)}:${_formatDigits(curM)}";
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _applyPreset(preset),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isCurrent ? themeColor : _iosBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrent
                                        ? themeColor
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  preset,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color:
                                        isCurrent ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Özet Bilgi Kartı
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.info_circle_fill,
                        color: _trendyolOrange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Dükkanınız günde ${_calculateOpenDuration()} açık kalacaktır (${_formatDigits(_openHour)}:${_formatDigits(_openMinute)} - ${_formatDigits(_closeHour)}:${_formatDigits(_closeMinute)}).",
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Onay ve Vazgeç Butonları
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Vazgeç",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _trendyolOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'openTime': TimeOfDay(
                                hour: _openHour, minute: _openMinute),
                            'closeTime': TimeOfDay(
                                hour: _closeHour, minute: _closeMinute),
                          });
                        },
                        icon: const Icon(CupertinoIcons.checkmark_alt, size: 18),
                        label: Text(
                          "Saatleri Onayla",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required String timeStr,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? activeColor : Colors.grey),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isActive ? activeColor : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _digitalDigitBlock(String digits, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            digits,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
