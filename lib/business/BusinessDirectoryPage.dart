import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'BusinessDetailPage.dart';

class BusinessDirectoryPage extends StatefulWidget {
  const BusinessDirectoryPage({Key? key}) : super(key: key);

  @override
  State<BusinessDirectoryPage> createState() => _BusinessDirectoryPageState();
}

class _BusinessDirectoryPageState extends State<BusinessDirectoryPage> {
  // Zümrüt Yeşili Tema Rengi
  final Color emeraldGreen = const Color(0xFF004D40);

  String searchQuery = "";
  String? selectedMainCat;
  String? selectedSubCat;
  String? selectedRegion;

  // Kategori Listesi
  final List<Map<String, dynamic>> categories = [
    {
      "name": "Restoran & Kafe",
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
      "sub": [
        "Saatçi",
        "Anahtarcı (Çilingir)",
        "İnternet Kafe",
        "Oyun Salonu",
        "Pet Shop"
      ]
    }
  ];

  final List<String> regions = ['Pazarcık Merkez', 'Narlı', 'Köyler', 'Online'];

  // 🔥 GÜNCELLENEN SORGU: isPublic filtresini kaldırdık.
  // Kamu filtrelemesi zaten StreamBuilder içinde client-side olarak kusursuz yapılıyor.
  Stream<QuerySnapshot> get _businessStream => FirebaseFirestore.instance
      .collection('businesses')
      .where('status', isEqualTo: 'approved')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text("İşletme Rehberi",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            border: null,
            backgroundColor:
                Theme.of(context).colorScheme.surface.withOpacity(0.92),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildSearchBar(),
                ),
                _buildMainFilters(),
                if (selectedMainCat != null) _buildSubCategoryRow(),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _businessStream,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const SliverToBoxAdapter(
                    child: Center(
                        child: Text("Hata oluştu veya Index bekleniyor...")));
              if (snapshot.connectionState == ConnectionState.waiting)
                return const SliverToBoxAdapter(
                    child: Center(child: CupertinoActivityIndicator()));

              var docs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;

                // 🔥 KESİN ÇÖZÜM: Kamu Kurumlarını Esnaf Listesinden Tamamen Gizle
                // Eğer type 'public' ise VEYA kategorilerinde Kamu geçiyorsa listeye alma!
                if (data['type'] == 'public' ||
                    data['category'] == "Kamu Kurumu" ||
                    data['mainCategory'] == "Kamu Kurumları") {
                  return false;
                }

                // Arama Filtresi
                bool matchesSearch = data['businessName']
                        .toString()
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    (data['tags'] as List? ?? []).any((t) => t
                        .toString()
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()));

                // Kategori ve Bölge Filtreleri
                bool matchesMainCat = selectedMainCat == null ||
                    data['mainCategory'] == selectedMainCat;
                bool matchesSubCat = selectedSubCat == null ||
                    data['category'] == selectedSubCat;
                bool matchesRegion = selectedRegion == null ||
                    (data['regions'] as List? ?? []).contains(selectedRegion);

                // Tüm şartları sağlayan ESNAFLARI göster
                return matchesSearch &&
                    matchesMainCat &&
                    matchesSubCat &&
                    matchesRegion;
              }).toList();

              docs.sort((a, b) => (a['businessName'] as String)
                  .compareTo(b['businessName'] as String));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildBusinessCard(docs[index]),
                  childCount: docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMainFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildEmeraldDropdown(
            value: selectedMainCat,
            hint: "Ana Kategori",
            items: categories.map((e) => e['name'] as String).toList(),
            onChanged: (val) => setState(() {
              selectedMainCat = val;
              selectedSubCat = null;
            }),
          ),
          const SizedBox(width: 10),
          _buildEmeraldDropdown(
            value: selectedRegion,
            hint: "Bölge",
            items: regions,
            onChanged: (val) => setState(() => selectedRegion = val),
          ),
          if (selectedMainCat != null || selectedRegion != null)
            TextButton(
              onPressed: () => setState(() {
                selectedMainCat = null;
                selectedSubCat = null;
                selectedRegion = null;
              }),
              child: const Text("Temizle",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildSubCategoryRow() {
    List<String> subCats =
        categories.firstWhere((e) => e['name'] == selectedMainCat)['sub'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: subCats.map((sub) {
          bool isSelected = selectedSubCat == sub;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(sub),
              selected: isSelected,
              onSelected: (val) =>
                  setState(() => selectedSubCat = val ? sub : null),
              selectedColor: emeraldGreen,
              backgroundColor: Theme.of(context).colorScheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                    color: isSelected ? emeraldGreen : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmeraldDropdown(
      {required String? value,
      required String hint,
      required List<String> items,
      required Function(String?) onChanged}) {
    bool isSelected = value != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isSelected ? emeraldGreen : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isSelected ? emeraldGreen : Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(value ?? hint,
              style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.black87)),
          icon: Icon(Icons.arrow_drop_down,
              color: isSelected ? Colors.white : Colors.black87),
          dropdownColor: Colors.white,
          items: items
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s,
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return CupertinoSearchTextField(
      placeholder: "Dükkan veya hizmet ara...",
      onChanged: (val) => setState(() => searchQuery = val),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildBusinessCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
              builder: (context) => BusinessDetailPage(doc: doc))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(data['imageUrls'] != null &&
                    (data['imageUrls'] as List).isNotEmpty
                ? data['imageUrls'][0]
                : ""),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['businessName'] ?? "İsimsiz",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                      "${data['mainCategory'] ?? ''} • ${data['category'] ?? ''}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(" ${data['rating']?.toDouble() ?? 0.0}",
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold))
                  ]),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String url) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          image: url.isNotEmpty
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null),
      child:
          url.isEmpty ? const Icon(Icons.business, color: Colors.grey) : null,
    );
  }
}
