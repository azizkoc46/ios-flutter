import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _kCacheKey = 'pazarcik_weather_cache_v1';

  static String _translateWeatherCode(dynamic code) {
    final c = int.tryParse(code.toString()) ?? 0;
    if (c == 0) return 'Açık';
    if (c == 1) return 'Az Bulutlu';
    if (c == 2) return 'Parçalı Bulutlu';
    if (c == 3) return 'Bulutlu';
    if (c == 45 || c == 48) return 'Sisli';
    if (c >= 51 && c <= 55) return 'Çisenti';
    if (c >= 61 && c <= 65) return 'Yağmurlu';
    if (c == 66 || c == 67) return 'Dondurucu Yağmur';
    if (c >= 71 && c <= 77) return 'Kar Yağışlı';
    if (c >= 80 && c <= 82) return 'Sağanak Yağış';
    if (c >= 85 && c <= 86) return 'Kar Sağanağı';
    if (c >= 95 && c <= 99) return 'Gök Gürültülü';
    return 'Güneşli';
  }

  Map<String, dynamic>? _memoryCache;

  /// ⚡ Önbellekteki hava durumunu anında döndürür (0 ms)
  Future<Map<String, dynamic>?> getCachedWeather() async {
    if (_memoryCache != null) return _memoryCache;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCacheKey);
      if (cached != null && cached.isNotEmpty) {
        final cachedData = json.decode(cached);
        if (cachedData is Map<String, dynamic>) {
          _memoryCache = cachedData;
          return cachedData;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getWeather(String city) async {
    try {
      // Pazarcık Koordinatları: 37.4858, 37.2917
      final response = await http
          .get(Uri.parse(
              "https://api.open-meteo.com/v1/forecast?latitude=37.4858&longitude=37.2917&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto"))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        final daily = data['daily'];
        final rawTemp = current['temperature'];
        final temp = rawTemp is num ? rawTemp.round() : rawTemp;
        final code = current['weathercode'];
        final condition = _translateWeatherCode(code);

        final result = {
          'temp': temp,
          'sicaklik': temp,
          'code': code,
          'durum': condition,
          'condition': condition,
          'daily': daily,
        };

        // Başarılı sonucu yerel hafızaya kaydet (önbellek)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kCacheKey, json.encode(result));
        } catch (_) {}

        return result;
      }
    } catch (e) {
      debugPrint("Hava durumu canlı çekilemedi: $e");
    }

    // Canlı çekilemezse önbellekten oku
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCacheKey);
      if (cached != null && cached.isNotEmpty) {
        final cachedData = json.decode(cached);
        if (cachedData is Map<String, dynamic>) {
          return cachedData;
        }
      }
    } catch (_) {}

    // En son çare varsayılan değer
    return {
      'temp': 20,
      'sicaklik': 20,
      'code': 0,
      'durum': 'Açık',
      'condition': 'Açık',
    };
  }
}
