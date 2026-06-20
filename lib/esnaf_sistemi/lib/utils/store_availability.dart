class StoreAvailability {
  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  static double rating(Map<String, dynamic> store) {
    final value = store['rating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  static bool isOpen(Map<String, dynamic> store, {DateTime? now}) {
    if (store['isApproved'] == false || store['sellerApproved'] == false) {
      return false;
    }
    final status = (store['restaurantStatus'] ?? 'active').toString();
    if (status != 'active' || store['isStoreOpen'] == false) return false;

    final current = now ?? DateTime.now();
    final workingDays = store['workingDays'];
    if (workingDays is List &&
        workingDays.isNotEmpty &&
        !workingDays
            .map((e) => e.toString())
            .contains(_days[current.weekday - 1])) {
      return false;
    }

    final open = _minutes(store['openTime']);
    final close = _minutes(store['closeTime']);
    if (open == null || close == null) return true;
    final minute = current.hour * 60 + current.minute;
    if (open == close) return true;
    return close > open
        ? minute >= open && minute < close
        : minute >= open || minute < close;
  }

  static int? _minutes(Object? raw) {
    final parts = raw?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}
