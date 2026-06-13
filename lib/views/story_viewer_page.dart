import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> allCategories;
  final int initialIndex;

  const StoryViewerPage({
    Key? key,
    required this.allCategories,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late StoryController controller;
  List<StoryItem> storyItems = [];

  @override
  void initState() {
    super.initState();
    _prepareStories();
  }

  void _prepareStories() {
    controller = StoryController();
    var currentCategory = widget.allCategories[widget.initialIndex];
    List<dynamic> rawStories = currentCategory['items'] ?? [];

    for (var item in rawStories) {
      try {
        if (item is Map) {
          String type = item['type'] ?? 'image';
          String url = item['url'] ?? '';

          if (url.isNotEmpty) {
            if (type == 'video') {
              storyItems.add(StoryItem.pageVideo(url,
                  controller: controller, imageFit: BoxFit.contain));
            } else {
              storyItems.add(StoryItem.pageImage(
                  url: url, controller: controller, imageFit: BoxFit.contain));
            }
          }
        } else if (item is String && item.isNotEmpty) {
          storyItems.add(StoryItem.pageImage(
              url: item, controller: controller, imageFit: BoxFit.contain));
        }
      } catch (e) {
        debugPrint("Hikaye atlandı: $e");
      }
    }
  }

  // 🔥 ÇÖZÜM: ValueKey yerine, sıradaki kategori için sayfayı baştan (yeniden) push ediyoruz.
  void _goToNextCategory() {
    if (widget.initialIndex < widget.allCategories.length - 1) {
      // Bir sonraki kategori varsa, EKRANI KAPATMADAN yeni sayfayı üzerine açıyoruz.
      // (Replacement yaparak üst üste binmesini engelliyoruz)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoryViewerPage(
            allCategories: widget.allCategories,
            initialIndex: widget.initialIndex + 1, // Bir sonrakine geç
          ),
        ),
      );
    } else {
      // Bütün kategoriler bittiyse Ana Sayfaya dön
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (storyItems.isEmpty) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()));
    }

    var currentCategory = widget.allCategories[widget.initialIndex];
    String categoryTitle = currentCategory['title'] ?? 'Hikaye';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StoryView(
            // key parametresi SİLİNDİ
            storyItems: storyItems,
            onStoryShow: (s, index) {},
            onComplete: _goToNextCategory, // Bittiğinde sıradaki sayfayı açar
            progressPosition: ProgressPosition.top,
            repeat: false,
            controller: controller,
          ),

          // Üst Kısım (Profil ve Kapatma Butonu)
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Image.asset('assets/images/logo.png',
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  categoryTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 5)]),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
