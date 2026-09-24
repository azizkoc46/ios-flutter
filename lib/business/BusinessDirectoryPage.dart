import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

import 'BusinessDetailPage.dart';
import 'business_add_page.dart';
import 'my_businesses_page.dart';

class BusinessDirectoryPage extends StatefulWidget {
  const BusinessDirectoryPage({Key? key}) : super(key: key);

  @override
  State<BusinessDirectoryPage> createState() => _BusinessDirectoryPageState();
}

enum BusinessSortOption { nameAsc, ratingDesc, reviewsDesc }

class _BusinessDirectoryPageState extends State<BusinessDirectoryPage> {
  // Zümrüt Yeşili Tema Renk Paleti
  final Color emeraldPrimary = const Color(0xFF004D40);
  final Color emeraldAccent = const Color(0xFF00796B);
  final Color emeraldLight = const Color(0xFFE0F2F1);

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String? selectedMainCat;
  String? selectedSubCat;
  String? selectedRegion;
  BusinessSortOption _sortOption = BusinessSortOption.nameAsc;

  // Kategori Listesi (Mevcut yapı eksiksiz korundu)
  final List<Map<String, dynamic>> categories = [
    {
      "name": "Restoran & Kafe",
      "icon": CupertinoIcons.flame_fill,
      "sub": [
        "Restoran",
        "Kafe",
        "Fast Food",
        "Dönerci",
        "Kebapçı",
        "Pide & Lahmacun",
        "Pastane",
        "Fırın",
        "Tatlıcı",
        "Dondurmacı",
        "Çay Ocağı",
        "Kahvaltı Salonu",
        "Balık Restoranı"
      ]
    },
    {
      "name": "Tamir & Servis",
      "icon": CupertinoIcons.wrench_fill,
      "sub": [
        "Elektrikçi",
        "Su Tesisatçısı",
        "Doğalgaz Ustası",
        "Klima Servisi",
        "Kombi Servisi",
        "Beyaz Eşya Servisi",
        "TV Tamircisi",
        "Telefon Tamircisi",
        "Bilgisayar Teknik Servis",
        "Uyducu",
        "Asansör Servisi"
      ]
    },
    {
      "name": "Emlak & İnşaat",
      "icon": CupertinoIcons.building_2_fill,
      "sub": [
        "Emlak Ofisi",
        "Gayrimenkul Danışmanı",
        "Kiralık Daire",
        "Satılık Daire",
        "Arsa & Tarla",
        "Müteahhit",
        "İnşaat Firması",
        "Boyacı",
        "Alçı Ustası",
        "Fayans Ustası",
        "Parke Ustası",
        "Marangoz",
        "Çatı Ustası",
        "Demir Doğrama",
        "PVC & Cam Balkon",
        "Yapı Malzemeleri"
      ]
    },
    {
      "name": "Market & Alışveriş",
      "icon": CupertinoIcons.cart_fill,
      "sub": [
        "Market",
        "Bakkal",
        "Şarküteri",
        "Kasap",
        "Manav",
        "Kuruyemişçi",
        "Züccaciye",
        "Hırdavatçı",
        "Kırtasiye",
        "Giyim Mağazası",
        "Ayakkabıcı",
        "Elektronik Mağazası",
        "Beyaz Eşya Mağazası",
        "Telefon Mağazası"
      ]
    },
    {
      "name": "Güzellik & Kuaför",
      "icon": CupertinoIcons.scissors,
      "sub": [
        "Kuaför (Kadın)",
        "Berber (Erkek)",
        "Güzellik Salonu",
        "Cilt Bakımı",
        "Lazer Epilasyon",
        "Manikür & Pedikür",
        "Spa & Masaj",
        "Solaryum"
      ]
    },
    {
      "name": "Sağlık",
      "icon": CupertinoIcons.heart_fill,
      "sub": [
        "Hastane",
        "Özel Klinik",
        "Aile Hekimi",
        "Diş Kliniği",
        "Eczane",
        "Psikolog",
        "Diyetisyen",
        "Fizyoterapist",
        "Veteriner"
      ]
    },
    {
      "name": "Otomotiv",
      "icon": CupertinoIcons.car_detailed,
      "sub": [
        "Oto Tamirci",
        "Oto Elektrikçi",
        "Kaportacı",
        "Araç Boya",
        "Lastikçi",
        "Oto Yıkama",
        "Oto Ekspertiz",
        "Oto Galeri",
        "Yedek Parça",
        "Motor Tamircisi",
        "Oto Klima"
      ]
    },
    {
      "name": "Hizmetler",
      "icon": CupertinoIcons.cube_box_fill,
      "sub": [
        "Temizlik Firması",
        "Güvenlik Firması",
        "Nakliyat",
        "Kargo & Kurye",
        "Matbaa",
        "Reklam Ajansı",
        "Fotoğrafçı",
        "Organizasyon",
        "Danışmanlık"
      ]
    },
    {
      "name": "Eğitim",
      "icon": CupertinoIcons.book_fill,
      "sub": [
        "Okul",
        "Kurs Merkezi",
        "Özel Ders",
        "Sürücü Kursu",
        "Kreş & Anaokulu"
      ]
    },
    {
      "name": "Tarım & Hayvancılık",
      "icon": CupertinoIcons.leaf_arrow_circlepath,
      "sub": [
        "Yem Bayii",
        "Tarım İlaçları",
        "Zirai Ekipman",
        "Süt Üreticisi",
        "Besi Çiftliği",
        "Tavukçuluk"
      ]
    },
    {
      "name": "Diğer",
      "icon": CupertinoIcons.sparkles,
      "sub": [
        "Saatçi",
        "Anahtarcı (Çilingir)",
        "İnternet Kafe",
        "Oyun Salonu",
        "Pet Shop"
      ]
    }
  ];

  final List<String> regions = [
    'Pazarcık Merkez',
    'Narlı',
    'Köyler',
    'Online'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _businessStream => FirebaseFirestore.instance
      .collection('businesses')
      .where('status', isEqualTo: 'approved')
      .snapshots();

  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      searchQuery = "";
      selectedMainCat = null;
      selectedSubCat = null;
      selectedRegion = null;
    });
  }

  bool get _hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedMainCat != null ||
      selectedSubCat != null ||
      selectedRegion != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final surfaceColor =
        isDark ? const Color(0xFF131B2E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: emeraldPrimary,
        elevation: 4,
        icon: const Icon(CupertinoIcons.plus_circle_fill,
            color: Colors.white, size: 20),
        label: Text(
          "İşletmeni Ekle",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        onPressed: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text("İşletme ekleyebilmek için lütfen önce giriş yapın."),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const BusinessAddPage()),
          );
        },
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. MODERN APP BAR
          SliverAppBar(
            pinned: true,
            expandedHeight: 70.0,
            elevation: 0.5,
            backgroundColor: surfaceColor,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(CupertinoIcons.chevron_left,
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: emeraldPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.building_2_fill,
                      size: 18, color: emeraldAccent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Pazarcık Esnafı",
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      "İşletmeler ve Hizmet Rehberi",
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (_hasActiveFilters)
                IconButton(
                  icon: const Icon(CupertinoIcons.clear_circled,
                      size: 20, color: Colors.redAccent),
                  tooltip: "Filtreleri Sıfırla",
                  onPressed: _clearFilters,
                ),
              IconButton(
                icon: const Icon(CupertinoIcons.briefcase, size: 21),
                color: emeraldAccent,
                tooltip: "İşletmelerim",
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "İşletmelerinizi görmek için lütfen önce giriş yapın."),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const MyBusinessesPage()),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),

          // 2. ARAMA VE FİLTRELEME BÖLÜMÜ
          SliverToBoxAdapter(
            child: Container(
              color: surfaceColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Arama Kutusu
                  _buildSearchBar(isDark),
                  const SizedBox(height: 12),

                  // Bölge Seçim Hapları (Merkez, Narlı, Köyler, Online)
                  _buildRegionChips(isDark),
                  const SizedBox(height: 12),

                  // Ana Kategori Kartları
                  _buildCategoryStrip(isDark),

                  // Alt Kategori Satırı (Ana kategori seçildiyse)
                  if (selectedMainCat != null) ...[
                    const SizedBox(height: 10),
                    _buildSubCategoryRow(isDark),
                  ],
                ],
              ),
            ),
          ),

          // 3. İŞLETME LİSTESİ VE SONUÇ BAŞLIĞI
          StreamBuilder<QuerySnapshot>(
            stream: _businessStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 16),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_triangle,
                              color: Colors.amber, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            "İşletmeler yüklenirken bir sorun oluştu:\n${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              var docs = (snapshot.data?.docs ?? []).where((doc) {
                var data = doc.data() as Map<String, dynamic>;

                // Kamu Kurumlarını Esnaf Listesinden Tamamen Gizle (Mevcut kural korundu)
                if (data['type'] == 'public' ||
                    data['category'] == "Kamu Kurumu" ||
                    data['mainCategory'] == "Kamu Kurumları") {
                  return false;
                }

                // Arama Filtresi (İsim ve Etiketler)
                final bName = (data['businessName'] ?? '').toString().toLowerCase();
                final tags = (data['tags'] as List? ?? [])
                    .map((t) => t.toString().toLowerCase())
                    .toList();
                final searchLower = searchQuery.toLowerCase().trim();

                bool matchesSearch = searchLower.isEmpty ||
                    bName.contains(searchLower) ||
                    tags.any((t) => t.contains(searchLower));

                // Kategori ve Bölge Filtreleri
                bool matchesMainCat = selectedMainCat == null ||
                    data['mainCategory'] == selectedMainCat;
                bool matchesSubCat = selectedSubCat == null ||
                    data['category'] == selectedSubCat;
                bool matchesRegion = selectedRegion == null ||
                    (data['regions'] as List? ?? []).contains(selectedRegion);

                return matchesSearch &&
                    matchesMainCat &&
                    matchesSubCat &&
                    matchesRegion;
              }).toList();

              // Sıralama
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                switch (_sortOption) {
                  case BusinessSortOption.ratingDesc:
                    final aRating = (aData['rating'] as num?)?.toDouble() ?? 0.0;
                    final bRating = (bData['rating'] as num?)?.toDouble() ?? 0.0;
                    return bRating.compareTo(aRating);
                  case BusinessSortOption.reviewsDesc:
                    final aCount = (aData['reviewCount'] as num?)?.toInt() ?? 0;
                    final bCount = (bData['reviewCount'] as num?)?.toInt() ?? 0;
                    return bCount.compareTo(aCount);
                  case BusinessSortOption.nameAsc:
                    final aName = (aData['businessName'] ?? '').toString();
                    final bName = (bData['businessName'] ?? '').toString();
                    return aName.compareTo(bName);
                }
              });

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: emeraldPrimary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.search,
                              size: 48,
                              color: emeraldAccent,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Eşleşen İşletme Bulunamadı",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isNotEmpty
                                ? "'$searchQuery' araması için sonuç bulunamadı. Filtreleri temizleyerek tekrar deneyebilirsiniz."
                                : "Seçili kategoride veya bölgede henüz onaylı bir işletme kaydı bulunmamaktadır.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (_hasActiveFilters) ...[
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _clearFilters,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: emeraldAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(CupertinoIcons.refresh, size: 16),
                              label: const Text("Tüm Filtreleri Temizle"),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverMainAxisGroup(
                slivers: [
                  // Sayı ve Sıralama Çubuğu
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${docs.length} İşletme Listeleniyor",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                            ),
                          ),
                          PopupMenuButton<BusinessSortOption>(
                            initialValue: _sortOption,
                            onSelected: (opt) =>
                                setState(() => _sortOption = opt),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.sort_down,
                                      size: 14, color: emeraldAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sortOption == BusinessSortOption.ratingDesc
                                        ? "Puana Göre"
                                        : _sortOption ==
                                                BusinessSortOption.reviewsDesc
                                            ? "Yoruma Göre"
                                            : "A - Z Sıralı",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down,
                                      size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: BusinessSortOption.nameAsc,
                                child: Text("Ada Göre (A - Z)"),
                              ),
                              const PopupMenuItem(
                                value: BusinessSortOption.ratingDesc,
                                child: Text("Puana Göre (En Yüksek)"),
                              ),
                              const PopupMenuItem(
                                value: BusinessSortOption.reviewsDesc,
                                child: Text("En Çok Değerlendirilen"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Kartlar
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildModernBusinessCard(docs[index], isDark),
                        childCount: docs.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- ARAMA KUTUSU ---
  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2438) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => searchQuery = val),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: "Dükkan, hizmet veya ürün ara...",
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
          ),
          prefixIcon: Icon(CupertinoIcons.search,
              size: 20, color: emeraldAccent),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(CupertinoIcons.clear_circled_solid,
                      size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // --- BÖLGE SEÇİM HAPLARI ---
  Widget _buildRegionChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildRegionPill(
            label: "Tüm Pazarcık",
            isSelected: selectedRegion == null,
            onTap: () => setState(() => selectedRegion = null),
            isDark: isDark,
            icon: CupertinoIcons.map_pin_ellipse,
          ),
          const SizedBox(width: 8),
          ...regions.map((region) {
            final isSelected = selectedRegion == region;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildRegionPill(
                label: region,
                isSelected: isSelected,
                onTap: () => setState(() {
                  selectedRegion = isSelected ? null : region;
                }),
                isDark: isDark,
                icon: CupertinoIcons.location_solid,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRegionPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? emeraldPrimary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? emeraldPrimary
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ANA KATEGORİ ŞERİDİ (İkonlu & Canlı Tasarım) ---
  Widget _buildCategoryStrip(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Tümü Kartı
          _buildCategoryCard(
            label: "Tümü",
            icon: CupertinoIcons.square_grid_2x2_fill,
            isSelected: selectedMainCat == null,
            isDark: isDark,
            onTap: () => setState(() {
              selectedMainCat = null;
              selectedSubCat = null;
            }),
          ),
          const SizedBox(width: 8),

          // Kategoriler
          ...categories.map((cat) {
            final name = cat['name'] as String;
            final icon = cat['icon'] as IconData? ?? CupertinoIcons.tag_fill;
            final isSelected = selectedMainCat == name;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildCategoryCard(
                label: name,
                icon: icon,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => setState(() {
                  if (isSelected) {
                    selectedMainCat = null;
                    selectedSubCat = null;
                  } else {
                    selectedMainCat = name;
                    selectedSubCat = null;
                  }
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? emeraldAccent
              : (isDark ? const Color(0xFF1A2234) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? emeraldAccent
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: emeraldAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ALT KATEGORİ ÇİPLERİ ---
  Widget _buildSubCategoryRow(bool isDark) {
    final catItem = categories.firstWhere(
      (e) => e['name'] == selectedMainCat,
      orElse: () => {'sub': <String>[]},
    );
    final List<String> subCats = List<String>.from(catItem['sub'] ?? []);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Tümü seçeneği
          GestureDetector(
            onTap: () => setState(() => selectedSubCat = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selectedSubCat == null
                    ? emeraldPrimary
                    : (isDark ? const Color(0xFF1C2438) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedSubCat == null
                      ? emeraldPrimary
                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                ),
              ),
              child: Text(
                "Tümü",
                style: TextStyle(
                  color: selectedSubCat == null
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 12,
                  fontWeight: selectedSubCat == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
          ...subCats.map((sub) {
            bool isSelected = selectedSubCat == sub;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: GestureDetector(
                onTap: () => setState(() {
                  selectedSubCat = isSelected ? null : sub;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? emeraldPrimary
                        : (isDark ? const Color(0xFF1C2438) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? emeraldPrimary
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    sub,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- MODERN İŞLETME KARTI ---
  Widget _buildModernBusinessCard(DocumentSnapshot doc, bool isDark) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['businessName'] ?? "İsimsiz İşletme";
    final String mainCat = data['mainCategory'] ?? "";
    final String subCat = data['category'] ?? "";
    final double rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
    final String phone = (data['contact'] ?? data['phone'] ?? '').toString();
    final List regionsList = data['regions'] as List? ?? [];
    final String regionStr =
        regionsList.isNotEmpty ? regionsList.first.toString() : "Pazarcık";
    final List imageUrls = data['imageUrls'] as List? ?? [];
    final String firstImage = imageUrls.isNotEmpty ? imageUrls[0].toString() : "";

    final bool isOwnershipVerified = data['claimStatus'] == 'approved' ||
        (data['claimedBy'] != null &&
            data['claimedBy'].toString().trim().isNotEmpty) ||
        data['isClaimed'] == true ||
        data['claimed'] == true ||
        data['isVerifiedOwner'] == true ||
        data['ownershipVerified'] == true ||
        (data['ownerId'] != null &&
            data['ownerId'].toString().trim().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => BusinessDetailPage(doc: doc),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ÜST BÖLÜM: Fotoğraf + Bilgiler
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İşletme Logosu / Fotoğrafı
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 82,
                        height: 82,
                        color: emeraldPrimary.withValues(alpha: 0.08),
                        child: firstImage.isNotEmpty
                            ? PortalNetworkImage(
                                url: firstImage,
                                fit: BoxFit.cover,
                                errorWidget: Center(
                                  child: Icon(CupertinoIcons.building_2_fill,
                                      color: emeraldAccent, size: 32),
                                ),
                              )
                            : Center(
                                child: Icon(CupertinoIcons.building_2_fill,
                                    color: emeraldAccent, size: 34),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Metin Alanı
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // İşletme Adı + Onay Rozeti
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              _buildVerificationBadge(isOwnershipVerified),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Kategori Etiketi
                          Text(
                            mainCat.isNotEmpty && subCat.isNotEmpty
                                ? "$mainCat • $subCat"
                                : mainCat.isNotEmpty
                                    ? mainCat
                                    : subCat.isNotEmpty
                                        ? subCat
                                        : "Genel Esnaf",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: emeraldAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Bölge + Değerlendirme Satırı
                          Row(
                            children: [
                              // Bölge Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.location_solid,
                                        size: 11,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700),
                                    const SizedBox(width: 3),
                                    Text(
                                      regionStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Puan Yıldızı
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Color(0xFFF59E0B), size: 16),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating > 0
                                        ? rating.toStringAsFixed(1)
                                        : "Yeni",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (reviewCount > 0)
                                    Text(
                                      " ($reviewCount)",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ALT KISIM: Hızlı Aksiyon Butonları
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Hızlı Arama Butonu
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _makeCall(phone),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: emeraldAccent,
                            side: BorderSide(
                              color: emeraldAccent.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(CupertinoIcons.phone_fill,
                              size: 14),
                          label: const Text(
                            "Hemen Ara",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // WhatsApp Butonu
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openWhatsApp(phone),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(CupertinoIcons.chat_bubble_2_fill,
                              size: 14),
                          label: const Text(
                            "WhatsApp",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Detay Oku
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CupertinoIcons.chevron_forward,
                          size: 16,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DOĞRULAMA ROZETİ (Altın / Yeşil Tik) ---
  Widget _buildVerificationBadge(bool isOwnershipVerified,
      {double size = 17, bool showLabel = false}) {
    if (isOwnershipVerified) {
      // 🌟 ALTIN DOĞRULAMA (Twitter/X Gold Badge)
      return Tooltip(
        message: "Doğrulanmış İşletme Sahibi (Altın Doğrulama)",
        child: Container(
          padding: showLabel
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
              : EdgeInsets.zero,
          decoration: showLabel
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: const Color(0xFFF59E0B), // Vibrant Gold
                  size: size,
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                const Text(
                  "Altın Onaylı",
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // 🟢 YEŞİL TİK (Rehber Kayıtlı İşletme)
      return Tooltip(
        message: "Rehber Kayıtlı ve Onaylı İşletme",
        child: Icon(
          Icons.verified_rounded,
          color: const Color(0xFF10B981), // Yeşil
          size: size,
        ),
      );
    }
  }
}
