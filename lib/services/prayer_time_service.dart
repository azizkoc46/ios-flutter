import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pazarcik_portal/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimeService {
  static final PrayerTimeService _instance = PrayerTimeService._internal();
  factory PrayerTimeService() => _instance;
  PrayerTimeService._internal();

  Map<String, String> namazVakitleri = {};
  String siradakiVakitAd = "Yükleniyor...";
  String siradakiVakitSaati = "";
  String geriSayim = "--:--:--";
  int aktifVakitIndex = -1;

  // 🔥 ARAYÜZ İÇİN VAKİT GETTER'I
  Map<String, String> get vakitler => namazVakitleri;

  // 🔥 VAKTE GÖRE RENK BELİRLEME
  Color getVakitRengi() {
    switch (siradakiVakitAd) {
      case "İmsak":
        return const Color(0xFF1A237E);
      case "Güneş":
        return const Color(0xFFF57C00);
      case "Öğle":
        return const Color(0xFF0288D1);
      case "İkindi":
        return const Color(0xFF7B1FA2);
      case "Akşam":
        return const Color(0xFFE64A19);
      case "Yatsı":
        return const Color(0xFF263238);
      default:
        return const Color(0xFF6A11CB);
    }
  }

  static const String _kPrayerCacheKey = 'pazarcik_namaz_vakitleri_cache_v1';

  /// ⚡ Önbellekteki namaz vakitlerini anında döndürür (0 ms)
  Future<Map<String, String>> getCachedVakitler() async {
    if (namazVakitleri.isNotEmpty) return namazVakitleri;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kPrayerCacheKey);
      if (cached != null && cached.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cached);
        namazVakitleri = decoded.map((k, v) => MapEntry(k, v.toString()));
        return namazVakitleri;
      }
    } catch (_) {}
    return namazVakitleri;
  }

  Future<Map<String, String>> fetchVakitler() async {
    // Önce varsa hafızadan yükle
    if (namazVakitleri.isEmpty) {
      await getCachedVakitler();
    }

    try {
      final response = await http.get(Uri.parse(
          "https://api.aladhan.com/v1/timingsByAddress?address=Pazarcık,Kahramanmaraş,Turkey&method=13"))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final timings = json.decode(response.body)['data']['timings'];
        // Vakitlerin sırasını ve isimlerini düzgün şekilde atadık
        namazVakitleri = {
          "İmsak": timings['Imsak'],
          "Güneş": timings['Sunrise'],
          "Öğle": timings['Dhuhr'],
          "İkindi": timings['Asr'],
          "Akşam": timings['Maghrib'],
          "Yatsı": timings['Isha']
        };

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kPrayerCacheKey, json.encode(namazVakitleri));
          if (prefs.getBool('namaz_bildirim') ?? true) {
            await NotificationService().schedulePrayerAlerts(namazVakitleri);
          }
        } catch (_) {}

        return namazVakitleri;
      }
    } catch (e) {
      debugPrint("Namaz vakti çekme hatası: $e");
    }

    if (namazVakitleri.isEmpty) {
      namazVakitleri = {
        "İmsak": "05:08",
        "Güneş": "06:28",
        "Öğle": "12:44",
        "İkindi": "16:18",
        "Akşam": "18:52",
        "Yatsı": "20:06"
      };
    }
    return namazVakitleri;
  }

  void hesaplaGeriSayim(Function onUpdate, bool bildirimAcik) {
    if (namazVakitleri.isEmpty) return;

    final now = DateTime.now();
    DateTime? siradakiZaman;
    String secilenAd = "";
    String secilenSaat = "";
    int sIndex = -1;

    final isimler = namazVakitleri.keys.toList();
    final saatler = namazVakitleri.values.toList();

    for (int i = 0; i < saatler.length; i++) {
      final parts = saatler[i].split(":");
      final vakit = DateTime(now.year, now.month, now.day, int.parse(parts[0]),
          int.parse(parts[1]));

      if (vakit.isAfter(now)) {
        siradakiZaman = vakit;
        secilenAd = isimler[i];
        secilenSaat = saatler[i];
        sIndex = i;
        break;
      }
    }

    if (siradakiZaman == null) {
      final ims = saatler[0].split(":");
      siradakiZaman = DateTime(now.year, now.month, now.day + 1,
          int.parse(ims[0]), int.parse(ims[1]));
      secilenAd = "İmsak";
      secilenSaat = saatler[0];
      sIndex = 0;
    }

    final fark = siradakiZaman.difference(now);

    // BİLDİRİM: Fark 0'a ulaştığında (saniye kontrolü ile)
    if (fark.inSeconds == 0 && bildirimAcik) {
      NotificationService().showNamazAlert(secilenAd);
    }

    siradakiVakitAd = secilenAd;
    siradakiVakitSaati = secilenSaat;
    aktifVakitIndex = sIndex;

    // Geri sayımı formatla
    geriSayim = [
      fark.inHours,
      fark.inMinutes.remainder(60),
      fark.inSeconds.remainder(60)
    ].map((e) => e.toString().padLeft(2, '0')).join(':');

    onUpdate();
  }
}
