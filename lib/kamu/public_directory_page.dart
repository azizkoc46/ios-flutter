import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'public_detail_page.dart';

class PublicDirectoryPage extends StatefulWidget {
  const PublicDirectoryPage({Key? key}) : super(key: key);

  @override
  State<PublicDirectoryPage> createState() => _PublicDirectoryPageState();
}

class _PublicDirectoryPageState extends State<PublicDirectoryPage> {
  // 🔥 Kamu Kurumları İçin Kırmızı Tema Rengi
  final Color publicRed = const Color(0xFFD32F2F);
  String searchQuery = "";
  String? selectedCategory;

  // 🔥 SENİN ORİJİNAL KATEGORİ LİSTEN (Tam istediğin gibi)
  final List<String> publicCategories = [
    'Kaymakamlık',
    'Belediye Hizmetleri',
    'İlçe Müdürleri',
    'Emniyet',
    'Hastane',
    'Sağlık Ocağı',
    'Muhtarlık',
    'Noter',
    'Banka',
    'PTT'
  ];

  Stream<QuerySnapshot> get _publicStream => FirebaseFirestore.instance
      .collection('businesses')
      .where('type', isEqualTo: 'public')
      .where('status', isEqualTo: 'approved')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text("Kamu & Devlet",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            border: null,
            backgroundColor: Colors.white.withOpacity(0.8),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CupertinoSearchTextField(
                    placeholder: "Kurum, hizmet veya adres ara...",
                    onChanged: (val) => setState(() => searchQuery = val),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryChips(),
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _publicStream,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const SliverToBoxAdapter(
                    child: Center(child: Text("Hata oluştu")));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(child: CupertinoActivityIndicator()));
              }

              var docs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;

                // 🔥 1. GELİŞMİŞ ARAMA MANTIĞI: Sayfadaki her şeyin içinde arar
                String q = searchQuery.toLowerCase().trim();
                bool matchesSearch = true;

                if (q.isNotEmpty) {
                  // Aramaya dahil edilecek tüm alanları birleştiriyoruz
                  String allSearchableText = [
                    data['businessName'] ?? '',
                    data['mainCategory'] ?? '',
                    data['category'] ?? '',
                    data['description'] ?? '',
                    data['addressDesc'] ?? '',
                    (data['tags'] as List? ?? []).join(' '),
                  ].join(' ').toLowerCase();

                  matchesSearch = allSearchableText.contains(q);
                }

                // 🔥 2. GÜÇLENDİRİLMİŞ KATEGORİ FİLTRESİ
                bool matchesCat = selectedCategory == null ||
                    data['mainCategory'] == selectedCategory ||
                    data['category'] == selectedCategory;

                return matchesSearch && matchesCat;
              }).toList();

              if (docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Text("Sonuç bulunamadı."),
                  )),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPublicCard(docs[index]),
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

  Widget _buildPublicCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => PublicDetailPage(doc: doc)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: publicRed.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: publicRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                image: data['imageUrls'] != null &&
                        (data['imageUrls'] as List).isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(data['imageUrls'][0]),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: data['imageUrls'] == null ||
                      (data['imageUrls'] as List).isEmpty
                  ? Icon(Icons.account_balance_rounded, color: publicRed)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['businessName'] ?? "Kurum Adı",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['mainCategory'] ?? "Kamu Kurumu",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: publicRed),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          data['addressDesc'] ?? "Pazarcık",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.blueGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: publicCategories.map((cat) {
          bool isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) =>
                  setState(() => selectedCategory = val ? cat : null),
              selectedColor: publicRed,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                    color: isSelected ? publicRed : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
