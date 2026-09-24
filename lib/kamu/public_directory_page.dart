// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'public_detail_page.dart';
import 'muhtarliklar_page.dart';

class PublicDirectoryPage extends StatefulWidget {
  const PublicDirectoryPage({Key? key}) : super(key: key);

  @override
  State<PublicDirectoryPage> createState() => _PublicDirectoryPageState();
}

class _PublicDirectoryPageState extends State<PublicDirectoryPage> {
  final Color publicRed = const Color(0xFFD32F2F);
  String searchQuery = "";
  String? selectedCategory;

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

  Future<void> _makeCall(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Arama başlatılamadı: $e");
    }
  }

  Future<void> _openWhatsApp(String phone, {String text = ""}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '9$cleanPhone';
    } else if (!cleanPhone.startsWith('90')) {
      cleanPhone = '90$cleanPhone';
    }
    final encoded = Uri.encodeComponent(text);
    final url = "https://wa.me/$cleanPhone${encoded.isNotEmpty ? '?text=$encoded' : ''}";
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("WhatsApp açılamadı: $e");
    }
  }

  Stream<QuerySnapshot> get _publicStream => FirebaseFirestore.instance
      .collection('businesses')
      .where('type', isEqualTo: 'public')
      .where('status', isEqualTo: 'approved')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              "Resmi Kurumlar",
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            border: null,
            backgroundColor: Colors.white.withOpacity(0.85),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ℹ️ Resmi Bilgilendirme / Sorumluluk Reddi Kutusu
                  _buildDisclaimerBanner(),
                  const SizedBox(height: 18),

                  // 🚨 Acil & Hızlı Numaralar Başlığı
                  Row(
                    children: [
                      Text(
                        "Acil Numaralar",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Tek tıkla ara",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 🔲 8'li Hızlı Arama & Muhtarlık Grid'i
                  _buildEmergencyGrid(),
                  const SizedBox(height: 24),

                  // 🏛️ Kurumlar & Arama Başlığı
                  Text(
                    "Kurumlar & Rehber",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

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
              if (snapshot.hasError) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text("Hata oluştu")),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }

              var docs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;

                String q = searchQuery.toLowerCase().trim();
                bool matchesSearch = true;

                if (q.isNotEmpty) {
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

                bool matchesCat = selectedCategory == null ||
                    data['mainCategory'] == selectedCategory ||
                    data['category'] == selectedCategory;

                return matchesSearch && matchesCat;
              }).toList();

              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.building_2_fill,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            "Sonuç bulunamadı.",
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  // ℹ️ Bilgilendirme / Sorumluluk Reddi Kutusu
  Widget _buildDisclaimerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDD5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Pazarcık Portal bağımsız bir şehir rehberi uygulamasıdır. Herhangi bir devlet kurumu, belediye veya kamu kuruluşunu temsil etmez ve bunlar adına hareket etmez.",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9A3412),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔲 8'li Acil Numaralar Grid'i (Ekran görüntüsündeki 4x2 düzeni)
  Widget _buildEmergencyGrid() {
    final items = [
      _EmergencyItem(
        title: "112 Acil",
        subtitle: "İtfaiye • Polis • Hızır",
        icon: Icons.emergency_rounded,
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEF2F2),
        onTap: () => _makeCall("112"),
      ),
      _EmergencyItem(
        title: "185 KASKİ",
        subtitle: "Su & Kanal Arıza",
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF0284C7),
        bg: const Color(0xFFF0F9FF),
        onTap: () => _makeCall("185"),
      ),
      _EmergencyItem(
        title: "187 Doğalgaz",
        subtitle: "ARMADAŞ Acil",
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFEA580C),
        bg: const Color(0xFFFFF7ED),
        onTap: () => _makeCall("187"),
      ),
      _EmergencyItem(
        title: "186 Elektrik",
        subtitle: "AKEDAŞ Arıza",
        icon: Icons.electric_bolt_rounded,
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFFFBEB),
        onTap: () => _makeCall("186"),
      ),
      _EmergencyItem(
        title: "153 B.Şehir",
        subtitle: "K.Maraş Beyaz Masa",
        icon: Icons.location_city_rounded,
        color: const Color(0xFF4F46E5),
        bg: const Color(0xFFEEF2FF),
        onTap: () => _makeCall("153"),
      ),
      _EmergencyItem(
        title: "Pazarcık Bld.",
        subtitle: "WhatsApp Hattı",
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFF0FDF4),
        onTap: () => _openWhatsApp(
          "05015460046",
          text: "Merhaba Pazarcık Belediyesi, Pazarcık Portal üzerinden ulaşıyorum.",
        ),
      ),
      _EmergencyItem(
        title: "Muhtarlıklar",
        subtitle: "Mahalle Rehberi",
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFFAF5FF),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => const MuhtarliklarPage()),
          );
        },
      ),
      _EmergencyItem(
        title: "182 ALO Sağlık",
        subtitle: "MHRS Randevu",
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFF0D9488),
        bg: const Color(0xFFF0FDFA),
        onTap: () => _makeCall("182"),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Geniş ekranlarda ve mobilde ferah ve uyumlu 4 sütun
        final int crossAxisCount = constraints.maxWidth > 650 ? 4 : 4;
        final double childAspectRatio = constraints.maxWidth < 360 ? 0.76 : 0.84;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: item.color.withOpacity(0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: publicRed.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: publicRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                image: data['imageUrls'] != null &&
                        (data['imageUrls'] as List).isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(data['imageUrls'][0]),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: data['imageUrls'] == null ||
                      (data['imageUrls'] as List).isEmpty
                  ? Icon(Icons.account_balance_rounded, color: publicRed, size: 26)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['businessName'] ?? "Kurum Adı",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['mainCategory'] ?? "Kamu Kurumu",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 13, color: publicRed),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['addressDesc'] ?? "Pazarcık",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
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
                size: 16, color: Colors.grey),
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
              onSelected: (val) {
                if (cat == 'Muhtarlık') {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const MuhtarliklarPage(),
                    ),
                  );
                  return;
                }
                setState(() => selectedCategory = val ? cat : null);
              },
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
                  color: isSelected ? publicRed : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmergencyItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  _EmergencyItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });
}
