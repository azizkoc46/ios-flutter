import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern, lüks ve %100 Türkçe iOS tarzı Tarih Seçici Modal
Future<DateTime?> showPortalDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = "Tarih Seçin",
  bool canClear = false,
}) async {
  return showModalBottomSheet<DateTime?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _PortalDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
      canClear: canClear,
    ),
  );
}

class _PortalDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final bool canClear;

  const _PortalDatePickerSheet({
    Key? key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.canClear,
  }) : super(key: key);

  @override
  State<_PortalDatePickerSheet> createState() => _PortalDatePickerSheetState();
}

class _PortalDatePickerSheetState extends State<_PortalDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _viewMonth;

  static const List<String> _turkishMonths = [
    "Ocak",
    "Şubat",
    "Mart",
    "Nisan",
    "Mayıs",
    "Haziran",
    "Temmuz",
    "Ağustos",
    "Eylül",
    "Ekim",
    "Kasım",
    "Aralık"
  ];

  static const List<String> _turkishDays = [
    "Pzt",
    "Sal",
    "Çar",
    "Per",
    "Cum",
    "Cmt",
    "Paz"
  ];

  static const List<String> _turkishDayNames = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar"
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    if (_selectedDate.isBefore(widget.firstDate)) {
      _selectedDate = widget.firstDate;
    } else if (_selectedDate.isAfter(widget.lastDate)) {
      _selectedDate = widget.lastDate;
    }
    _viewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _selectPresetDays(int daysToAdd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime target = today.add(Duration(days: daysToAdd));
    if (target.isBefore(widget.firstDate)) target = widget.firstDate;
    if (target.isAfter(widget.lastDate)) target = widget.lastDate;

    setState(() {
      _selectedDate = target;
      _viewMonth = DateTime(target.year, target.month, 1);
    });
  }

  String _formatLongDate(DateTime dt) {
    final dayName = _turkishDayNames[dt.weekday - 1];
    final monthName = _turkishMonths[dt.month - 1];
    return "${dt.day} $monthName ${dt.year}, $dayName";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0056D2);
    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget content = Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(26))
            : BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Sürükleme Çubuğu (Grabber)
              Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Başlık Satırı
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.calendar,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Seçilen Tarih Vurgu Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF0FDF4), const Color(0xFFECFDF5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SEÇİLEN TARİH",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatLongDate(_selectedDate),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Hızlı Seçim Butonları (Bugün, +7 gün, +15 gün, +30 gün)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildPresetChip("Bugün", 0, isDark),
                    _buildPresetChip("+7 Gün (1 Hafta)", 7, isDark),
                    _buildPresetChip("+15 Gün", 15, isDark),
                    _buildPresetChip("+30 Gün (1 Ay)", 30, isDark),
                    _buildPresetChip("+60 Gün (2 Ay)", 60, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Ay & Yıl Başlığı ve İleri/Geri Butonları
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                      onPressed: _prevMonth,
                      color: isDark ? Colors.white : Colors.black87,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      "${_turkishMonths[_viewMonth.month - 1]} ${_viewMonth.year}",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.chevron_right, size: 18),
                      onPressed: _nextMonth,
                      color: isDark ? Colors.white : Colors.black87,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Haftanın Günleri Başlıkları (Pzt, Sal, ...)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _turkishDays.map((d) {
                  final isWeekend = (d == "Cmt" || d == "Paz");
                  return SizedBox(
                    width: 38,
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isWeekend
                              ? (isDark
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFFEF4444))
                              : (isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 6),

              // Günler Tablosu (Calendar Grid)
              _buildDaysGrid(isDark, primaryColor),

              const SizedBox(height: 18),

              // Alt Butonlar (İptal / Temizle & Onayla)
              Row(
                children: [
                  if (widget.canClear) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Tarihi Kaldır",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0056D2), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0056D2).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _selectedDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(CupertinoIcons.checkmark_alt, size: 18),
                        label: const Text(
                          "Tarihi Onayla",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return content;
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: content,
      ),
    );
  }

  Widget _buildPresetChip(String label, int days, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = today.add(Duration(days: days));
    final isSelected = _selectedDate.year == target.year &&
        _selectedDate.month == target.month &&
        _selectedDate.day == target.day;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _selectPresetDays(days),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0056D2)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0056D2)
                  : (isDark ? Colors.white10 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysGrid(bool isDark, Color primaryColor) {
    final firstDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;

    // Pazartesi = 1 ... Pazar = 7
    final int startWeekday = firstDayOfMonth.weekday; // 1 to 7
    final int leadingEmptyCells = startWeekday - 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Widget> dayWidgets = [];

    // Önceki aydan boş hücreler
    for (int i = 0; i < leadingEmptyCells; i++) {
      dayWidgets.add(const SizedBox(width: 38, height: 38));
    }

    // Ayın günleri
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_viewMonth.year, _viewMonth.month, day);
      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      final bool isDisabled =
          date.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) ||
              date.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

      dayWidgets.add(
        InkWell(
          onTap: isDisabled
              ? null
              : () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF0056D2), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: primaryColor, width: 1.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0056D2).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              "$day",
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isDisabled
                    ? (isDark ? Colors.white24 : Colors.grey.shade300)
                    : isSelected
                        ? Colors.white
                        : isToday
                            ? primaryColor
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.start,
      children: dayWidgets,
    );
  }
}
