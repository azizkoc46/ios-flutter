import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

// --- HABER MODELİ ---
class NewsItem {
  final String title;
  final String description;
  final String imageUrl;
  final String link;
  final DateTime pubDate;
  final String sourceName;
  final Color sourceColor;

  NewsItem({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.link,
    required this.pubDate,
    required this.sourceName,
    required this.sourceColor,
  });
}

class NewsPage extends StatefulWidget {
  const NewsPage({Key? key}) : super(key: key);

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  bool _isLoading = true;
  List<NewsItem> _allNews = [];
  String _selectedSource = "Tümü";

  // 🔥 Çip İsimleri (Sıralama Tam İstediğin Gibi)
  final List<String> _sources = [
    "Son Dakika",
    "Pazarcık Havadis",
    "Maraş Haberleri"
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) => _fetchNews());
  }

  // --- 🔥 ANLIK HABER ÇEKME FONKSİYONU ---
  Future<void> _fetchNews() async {
    setState(() => _isLoading = true);
    List<NewsItem> tempNews = [];

    // 1. ENSONHABER (Hız Şampiyonu)
    await _loadRss(
      url: 'https://www.ensonhaber.com/rss/ensonhaber.xml',
      sourceName: 'Son Dakika',
      sourceColor: Colors.red.shade800,
      targetList: tempNews,
    );

    // 2. SÖZCÜ (Sıcak Gelişmeler)
    await _loadRss(
      url: 'https://www.sozcu.com.tr/rss/son-dakika.xml',
      sourceName: 'Son Dakika',
      sourceColor: Colors.black,
      targetList: tempNews,
    );

    // 3. PAZARCIK HAVADİS
    await _loadRss(
      url: 'https://pazarcikhavadis.com/rss.xml',
      sourceName: 'Pazarcık Havadis',
      sourceColor: const Color.fromARGB(255, 254, 1, 1),
      targetList: tempNews,
    );

    // 4. MARAŞ HABER 46
    await _loadRss(
      url: 'https://www.haber46.com.tr/rss',
      sourceName: 'Maraş Haberleri',
      sourceColor: Colors.blue.shade700,
      targetList: tempNews,
    );

    // Saniyelerle Yarışan Sıralama
    tempNews.sort((a, b) => b.pubDate.compareTo(a.pubDate));

    if (mounted) {
      setState(() {
        _allNews = tempNews;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRss({
    required String url,
    required String sourceName,
    required Color sourceColor,
    required List<NewsItem> targetList,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String xmlString =
            utf8.decode(response.bodyBytes, allowMalformed: true);
        final rssFeed = RssFeed.parse(xmlString);

        int i = 0;
        for (var item in rssFeed.items ?? []) {
          targetList.add(NewsItem(
            title: item.title?.trim() ?? "Başlıksız",
            description: _cleanHtml(item.description ?? ""),
            imageUrl: _extractImageUrl(item), // 🔥 Güçlendirilmiş görsel bulucu
            link: item.link ?? "",
            pubDate:
                item.pubDate ?? DateTime.now().subtract(Duration(minutes: i++)),
            sourceName: sourceName,
            sourceColor: sourceColor,
          ));
        }
      }
    } catch (e) {
      debugPrint("Hata ($sourceName): $e");
    }
  }

  String _cleanHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  // 🔥 YENİ VE GÜÇLENDİRİLMİŞ GÖRSEL BULUCU
  String _extractImageUrl(RssItem item) {
    // 1. Klasik Enclosure Kontrolü
    if (item.enclosure != null &&
        item.enclosure!.url != null &&
        item.enclosure!.url!.isNotEmpty) {
      return item.enclosure!.url!;
    }

    // 2. Media Content Kontrolü (Ensonhaber ve Sözcü genelde burayı kullanır)
    if (item.media?.contents != null && item.media!.contents!.isNotEmpty) {
      final url = item.media!.contents!.first.url;
      if (url != null && url.isNotEmpty) return url;
    }

    // 3. İçerik içi resimler
    if (item.content?.images.isNotEmpty == true) {
      return item.content!.images.first;
    }

    // 4. Description içinden Regex ile <img src="..." /> ayıklama
    RegExp imgRegex = RegExp(r'<img[^>]+src="([^">]+)"');
    if (item.description != null) {
      Iterable<Match> matches = imgRegex.allMatches(item.description!);
      if (matches.isNotEmpty && matches.first.groupCount >= 1) {
        return matches.first.group(1)!;
      }
    }

    // 5. Content Value içinden Regex
    if (item.content?.value != null) {
      Iterable<Match> matches = imgRegex.allMatches(item.content!.value!);
      if (matches.isNotEmpty && matches.first.groupCount >= 1) {
        return matches.first.group(1)!;
      }
    }

    // Hiçbir şey bulunamazsa varsayılan resim
    return "https://via.placeholder.com/400x250.png?text=Gorsel+Bulunamadi&bg=e0e0e0&textColor=999999";
  }

  // "3 dakika önce" gibi yazdıran fonksiyon
  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return "${duration.inDays} gün önce";
    if (duration.inHours > 0) return "${duration.inHours} saat önce";
    if (duration.inMinutes > 0) return "${duration.inMinutes} dk önce";
    return "Az önce";
  }

  @override
  Widget build(BuildContext context) {
    List<NewsItem> filteredNews = _selectedSource == "Tümü"
        ? _allNews
        : _allNews.where((n) => n.sourceName == _selectedSource).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        title: Text("SICAK TAKİP",
            style: GoogleFonts.oswald(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _fetchNews)
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                _buildSourceBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredNews.length,
                    itemBuilder: (context, index) =>
                        _buildTwitterStyleCard(filteredNews[index]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSourceBar() {
    return Container(
      height: 55,
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _sources.length,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemBuilder: (context, index) {
          bool isSelected = _selectedSource == _sources[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedSource = _sources[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(_sources[index],
                    style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTwitterStyleCard(NewsItem news) {
    return GestureDetector(
      onTap: () async =>
          await launchUrl(Uri.parse(news.link), mode: LaunchMode.inAppWebView),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: news.sourceColor, radius: 4),
                const SizedBox(width: 8),
                Text(news.sourceName,
                    style: TextStyle(
                        color: news.sourceColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
                const Spacer(),
                Text(_getTimeAgo(news.pubDate),
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(news.title,
                      style: GoogleFonts.roboto(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: news.imageUrl,
                    width: 90,
                    height: 70,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                        width: 90,
                        height: 70,
                        color: Colors.grey.shade100,
                        child: const CupertinoActivityIndicator()),
                    errorWidget: (context, url, error) => Container(
                        width: 90,
                        height: 70,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
