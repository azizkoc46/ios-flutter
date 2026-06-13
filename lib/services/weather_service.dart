import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  Future<Map<String, dynamic>?> getWeather(String city) async {
    try {
      // Pazarcık Koordinatları: 37.48, 37.29
      // 🔥 YENİ: daily parametresi ile 7 günlük max/min sıcaklık ve hava durumu kodunu çekiyoruz
      final response = await http.get(Uri.parse(
          "https://api.open-meteo.com/v1/forecast?latitude=37.48&longitude=37.29&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        final daily = data['daily'];

        return {
          'temp': current['temperature'],
          'code': current['weathercode'],
          'daily': daily, // 7 günlük veriler listesi eklendi
        };
      }
    } catch (e) {
      print("Hava durumu çekilemedi: $e");
      return null;
    }
    return null;
  }
}
