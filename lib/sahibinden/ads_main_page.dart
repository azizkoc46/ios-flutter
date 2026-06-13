import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pazarcik_portal/sahibinden/add_ad_page.dart';
import 'package:pazarcik_portal/sahibinden/ad_detail_page.dart';
import 'package:pazarcik_portal/sahibinden/my_ads_management_view.dart';
import 'package:pazarcik_portal/sahibinden/sahibinden_button.dart';
import 'package:pazarcik_portal/sahibinden/sprofil.dart';

class AdsMainPage extends StatefulWidget {
  const AdsMainPage({Key? key}) : super(key: key);

  @override
  State<AdsMainPage> createState() => _AdsMainPageState();
}

class _AdsMainPageState extends State<AdsMainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    AdsHomeView(),
    MyAdsManagementView(),
    SizedBox(),
    AddAdPage(),
    SahibindenProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SahibindenMagicBottomBar(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2) {
            Navigator.pop(context);
            return;
          }
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

class AdsHomeView extends StatefulWidget {
  const AdsHomeView({Key? key}) : super(key: key);

  @override
  State<AdsHomeView> createState() => _AdsHomeViewState();
}

class _AdsHomeViewState extends State<AdsHomeView> {
  final Color sahibindenYellow = const Color(0xFFFFE800);
  final Color sahibindenDark = const Color(0xFF27272A);

  String selectedCategory = "Hepsi";
  String selectedSubCategory = "Tümü";
  String searchText = "";

  final List<String> categories = const [
    "Hepsi",
    "Sıfır Ürün",
    "İkinci El",
    "Emlak",
    "Vasıta",
    "Tarım",
  ];

  final Map<String, List<String>> subCategories = const {
    "Sıfır Ürün": [
      "Tümü",
      "Cep Telefonu",
      "Bilgisayar",
      "Beyaz Eşya",
      "Elektronik",
      "Ev & Yaşam",
      "Giyim",
      "Diğer",
    ],
    "İkinci El": [
      "Tümü",
      "Cep Telefonu",
      "Bilgisayar",
      "Beyaz Eşya",
      "Ev Eşyaları",
      "Elektronik",
      "Giyim",
      "Diğer",
    ],
    "Emlak": ["Tümü", "Satılık", "Kiralık", "Arsa", "İş Yeri"],
    "Vasıta": ["Tümü", "Otomobil", "Motosiklet", "Traktör", "Ticari Araç"],
    "Tarım": ["Tümü", "Hayvan", "Ekipman", "Arazi", "Ürün"],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: sahibindenYellow,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "Pazarcık Sahibinden",
          style: GoogleFonts.inter(
            color: sahibindenDark,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          _buildCategoryList(),
          if (subCategories.containsKey(selectedCategory))
            _buildSubCategoryList(),
          Expanded(child: _buildAdGrid()),
          const SizedBox(height: 98),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: sahibindenYellow,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.search, size: 20, color: Colors.black45),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => searchText = value),
                decoration: const InputDecoration(
                  hintText: "İlan ara",
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (searchText.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => searchText = ""),
                child: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 20,
                  color: Colors.black38,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 58,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final bool isActive = selectedCategory == category;

          return GestureDetector(
            onTap: () => setState(() {
              selectedCategory = category;
              selectedSubCategory = "Tümü";
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive ? sahibindenDark : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? sahibindenDark : const Color(0xFFE5E7EB),
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : sahibindenDark,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubCategoryList() {
    final currentSubs = subCategories[selectedCategory]!;

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: currentSubs.length,
        itemBuilder: (context, index) {
          final sub = currentSubs[index];
          final bool isActive = selectedSubCategory == sub;

          return GestureDetector(
            onTap: () => setState(() => selectedSubCategory = sub),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? sahibindenYellow : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? sahibindenYellow : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sahibindenDark,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdGrid() {
    Query query = FirebaseFirestore.instance
        .collection('classified_ads')
        .where('status', isEqualTo: 'active');

    if (selectedCategory != "Hepsi") {
      query = query.where('category', isEqualTo: selectedCategory);
      if (selectedSubCategory != "Tümü") {
        query = query.where('subCategory', isEqualTo: selectedSubCategory);
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("İlanlar yüklenemedi."));
        }

        var ads = snapshot.data?.docs ?? [];

        if (searchText.trim().isNotEmpty) {
          final q = searchText.trim().toLowerCase();
          ads = ads.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final desc = (data['description'] ?? '').toString().toLowerCase();
            return title.contains(q) || desc.contains(q);
          }).toList();
        }

        if (ads.isEmpty) {
          return const Center(
            child: Text(
              "Bu alanda henüz ilan yok.",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: ads.length,
              itemBuilder: (context, index) {
                final adData = ads[index].data() as Map<String, dynamic>;
                adData['docId'] = ads[index].id;
                return _buildAdCard(adData);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final List<dynamic> images = ad['images'] ?? [];
    final String category = (ad['category'] ?? '').toString();
    final String condition = (ad['condition'] ?? '').toString();
    final String sellerType = (ad['sellerType'] ?? '').toString();

    final bool isNewProduct =
        category == "Sıfır Ürün" || condition == "new" || condition == "Yeni";
    final bool isUsed = category == "İkinci El" || condition == "used";
    final bool isCorporate =
        sellerType == "corporate" || sellerType == "Kurumsal";

    final String badgeText = isNewProduct
        ? "Yeni Ürün"
        : isUsed
            ? "İkinci El"
            : isCorporate
                ? "Kurumsal"
                : category;

    final Color badgeColor = isNewProduct
        ? const Color(0xFF16A34A)
        : isUsed
            ? const Color(0xFF2563EB)
            : isCorporate
                ? const Color(0xFF7C3AED)
                : const Color(0xFFF97316);

    final String price = (ad['price'] ?? '').toString();
    final String title = (ad['title'] ?? '').toString();
    final String district =
        (ad['district'] ?? ad['location'] ?? 'Pazarcık').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => AdDetailPage(ad: ad),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: images.isNotEmpty
                          ? PortalNetworkImage(
                              url: images.first.toString(),
                              fit: BoxFit.cover,
                              errorWidget: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.photo,
                              color: Colors.grey,
                              size: 38,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (isCorporate)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price.isEmpty ? "Fiyat belirtilmedi" : "$price TL",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0056D2),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_solid,
                        size: 12,
                        color: Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ],
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
