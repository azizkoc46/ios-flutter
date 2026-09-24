import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webfeed_plus/webfeed_plus.dart';

class LiveNewsModel {
  final String title;
  final String description;
  final String imageUrl;
  final String link;
  final DateTime pubDate;
  final String sourceName;
  final Color sourceColor;

  LiveNewsModel({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.link,
    required this.pubDate,
    required this.sourceName,
    required this.sourceColor,
  });

  String get category => sourceName;

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(pubDate);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} dk önce";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} saat önce";
    } else {
      return "${pubDate.day}.${pubDate.month}.${pubDate.year}";
    }
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'link': link,
    'pubDate': pubDate.millisecondsSinceEpoch,
    'sourceName': sourceName,
    'sourceColor': sourceColor.value,
  };

  factory LiveNewsModel.fromMap(Map<String, dynamic> map) => LiveNewsModel(
    title: (map['title'] ?? '').toString(),
    description: (map['description'] ?? '').toString(),
    imageUrl: (map['imageUrl'] ?? '').toString(),
    link: (map['link'] ?? '').toString(),
    pubDate: map['pubDate'] is int
        ? DateTime.fromMillisecondsSinceEpoch(map['pubDate'])
        : (DateTime.tryParse(map['pubDate']?.toString() ?? '') ?? DateTime.now()),
    sourceName: (map['sourceName'] ?? 'Haber').toString(),
    sourceColor: Color(map['sourceColor'] is int ? map['sourceColor'] : 0xFF2563EB),
  );
}

class NewsSliderService {
  static const String _kNewsCacheKey = 'pazarcik_top_news_cache_v2';
  static List<LiveNewsModel>? _cachedTopNews;
  static DateTime? _lastFetchTime;

  static List<LiveNewsModel> _defaultFallbackNews() {
    return [
      LiveNewsModel(
        title: "Pazarcık'ta Yeni Sosyal Tesisler Hizmete Açıldı",
        description: "İlçemizde hemşehrilerimizin buluşma noktası olacak yeni yaşam alanı hizmete girdi.",
        imageUrl: "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=500&auto=format&fit=crop&q=60",
        link: "https://pazarcikportal.com",
        pubDate: DateTime.now().subtract(const Duration(hours: 2)),
        sourceName: "Pazarcık Havadis",
        sourceColor: const Color(0xFFEF4444),
      ),
      LiveNewsModel(
        title: "Kahramanmaraş Genelinde Tarımsal Destekler Açıklandı",
        description: "Çiftçilerimize yönelik yeni üretim ve sulama teşvik paketleri yürürlüğe girdi.",
        imageUrl: "https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=500&auto=format&fit=crop&q=60",
        link: "https://pazarcikportal.com",
        pubDate: DateTime.now().subtract(const Duration(hours: 4)),
        sourceName: "Maraş Haber",
        sourceColor: const Color(0xFF0284C7),
      ),
      LiveNewsModel(
        title: "Pazarcık Kültür ve Sanat Günleri Başlıyor",
        description: "Gençler ve aileler için düzenlenecek zengin etkinlik takvimi paylaşıldı.",
        imageUrl: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=60",
        link: "https://pazarcikportal.com",
        pubDate: DateTime.now().subtract(const Duration(hours: 6)),
        sourceName: "Sıcak Gelişme",
        sourceColor: const Color(0xFFFF9500),
      ),
    ];
  }

  /// ⚡ Önbellekteki son haberleri anında döndürür (0 ms)
  static Future<List<LiveNewsModel>> getCachedTopNews({int limit = 6}) async {
    if (_cachedTopNews != null && _cachedTopNews!.isNotEmpty) {
      return _cachedTopNews!.take(limit).toList();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNewsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = json.decode(raw);
        final parsed = list
            .map((e) => LiveNewsModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (parsed.isNotEmpty) {
          _cachedTopNews = parsed;
          return parsed.take(limit).toList();
        }
      }
    } catch (_) {}
    return _defaultFallbackNews().take(limit).toList();
  }

  static Future<List<LiveNewsModel>> fetchTopNews({int limit = 6, bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedTopNews != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < const Duration(minutes: 5)) {
      return _cachedTopNews!.take(limit).toList();
    }

    final List<LiveNewsModel> items = [];

    // Paralel olarak tüm RSS kaynaklarından çek
    await Future.wait([
      _loadRss(
        url: 'https://www.ensonhaber.com/rss/ensonhaber.xml',
        sourceName: 'En Son Haber',
        sourceColor: const Color(0xFFEF4444),
        targetList: items,
      ),
      _loadRss(
        url: 'https://www.sozcu.com.tr/rss/son-dakika.xml',
        sourceName: 'Son Dakika',
        sourceColor: const Color(0xFFDC2626),
        targetList: items,
      ),
      _loadRss(
        url: 'https://www.trthaber.com/sondakika_articles.rss',
        sourceName: 'TRT Haber',
        sourceColor: const Color(0xFF2563EB),
        targetList: items,
      ),
      _loadRss(
        url: 'https://rss.sondakika.com/rss/manset.xml',
        sourceName: 'Gündem',
        sourceColor: const Color(0xFFF59E0B),
        targetList: items,
      ),
      _loadRss(
        url: 'https://www.haber46.com.tr/rss',
        sourceName: 'Maraş Haber',
        sourceColor: const Color(0xFF0284C7),
        targetList: items,
      ),
      _loadRss(
        url: 'https://pazarcikhavadis.com/rss.xml',
        sourceName: 'Pazarcık Havadis',
        sourceColor: const Color(0xFF10B981),
        targetList: items,
      ),
    ]);

    if (items.isEmpty) {
      if (_cachedTopNews != null && _cachedTopNews!.isNotEmpty) {
        return _cachedTopNews!.take(limit).toList();
      }
      final diskCached = await getCachedTopNews(limit: limit);
      if (diskCached.isNotEmpty) return diskCached;
      items.addAll(_defaultFallbackNews());
    } else {
      // Başlığa göre benzersizleştir
      final seenTitles = <String>{};
      final uniqueItems = <LiveNewsModel>[];
      for (final item in items) {
        final cleanTitle = item.title.trim().toLowerCase();
        if (cleanTitle.isNotEmpty && !seenTitles.contains(cleanTitle)) {
          seenTitles.add(cleanTitle);
          uniqueItems.add(item);
        }
      }

      // En yeni tarihe göre sırala
      uniqueItems.sort((a, b) => b.pubDate.compareTo(a.pubDate));
      items.clear();
      items.addAll(uniqueItems);
    }

    _cachedTopNews = items;
    _lastFetchTime = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(items.take(20).map((e) => e.toMap()).toList());
      await prefs.setString(_kNewsCacheKey, encoded);
    } catch (_) {}

    return items.take(limit).toList();
  }

  static Future<void> _loadRss({
    required String url,
    required String sourceName,
    required Color sourceColor,
    required List<LiveNewsModel> targetList,
  }) async {
    List<String> urlsToTry = [url];
    if (kIsWeb) {
      urlsToTry = [
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
        'https://corsproxy.io/?${Uri.encodeComponent(url)}',
        url,
      ];
    }

    for (final fetchUrl in urlsToTry) {
      try {
        final response = await http.get(
          Uri.parse(fetchUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          String xmlString =
              utf8.decode(response.bodyBytes, allowMalformed: true);
          final rssFeed = RssFeed.parse(xmlString);

          int i = 0;
          final parsedItems = <LiveNewsModel>[];
          for (var item in rssFeed.items ?? []) {
            final imageUrl = _extractImageUrl(item, xmlString);
            parsedItems.add(LiveNewsModel(
              title: item.title?.trim() ?? "Başlıksız",
              description: _cleanHtml(item.description ?? ""),
              imageUrl: imageUrl,
              link: item.link ?? "",
              pubDate:
                  item.pubDate ?? DateTime.now().subtract(Duration(minutes: i++)),
              sourceName: sourceName,
              sourceColor: sourceColor,
            ));
          }

          if (parsedItems.isNotEmpty) {
            targetList.addAll(parsedItems);
            return;
          }
        }
      } catch (e) {
        debugPrint("News slider fetch error ($sourceName - $fetchUrl): $e");
      }
    }
  }

  static String _cleanHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  static String _extractImageUrl(RssItem item, [String? fullXml]) {
    if (item.enclosure != null &&
        item.enclosure!.url != null &&
        item.enclosure!.url!.isNotEmpty) {
      return item.enclosure!.url!;
    }
    if (item.media?.contents != null && item.media!.contents!.isNotEmpty) {
      final url = item.media!.contents!.first.url;
      if (url != null && url.isNotEmpty) return url;
    }
    if (item.title != null && fullXml != null) {
      try {
        final escapedTitle = RegExp.escape(item.title!.trim());
        final itemRegex = RegExp(
            escapedTitle + r'[\s\S]*?<image>(https?://[^<]+)</image>',
            caseSensitive: false);
        final m = itemRegex.firstMatch(fullXml);
        if (m != null && m.groupCount >= 1) {
          return m.group(1)!;
        }
      } catch (_) {}
    }
    if (item.content?.images.isNotEmpty == true) {
      return item.content!.images.first;
    }
    RegExp imgRegex = RegExp(r'<img[^>]+src="([^">]+)"');
    if (item.description != null) {
      Iterable<Match> matches = imgRegex.allMatches(item.description!);
      if (matches.isNotEmpty && matches.first.groupCount >= 1) {
        return matches.first.group(1)!;
      }
    }
    if (item.content?.value != null) {
      Iterable<Match> matches = imgRegex.allMatches(item.content!.value);
      if (matches.isNotEmpty && matches.first.groupCount >= 1) {
        return matches.first.group(1)!;
      }
    }
    return "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?q=80&w=600&auto=format&fit=crop";
  }
}
