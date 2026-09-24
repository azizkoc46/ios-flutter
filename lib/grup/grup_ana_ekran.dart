import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'grup_gonderi_olustur.dart';
import 'grup_gonderi_karti.dart';
import 'kaydedilen_gonderiler_page.dart';
import 'package:pazarcik_portal/auth/auth.dart';

class GrupAnaEkran extends StatefulWidget {
  const GrupAnaEkran({Key? key}) : super(key: key);

  @override
  State<GrupAnaEkran> createState() => _GrupAnaEkranState();
}

class _GrupAnaEkranState extends State<GrupAnaEkran> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String userName = "Kullanıcı";
  String userAvatar = "";
  bool hasVerifiedPhone = false;

  String _selectedCategory = 'Meydan';
  String _selectedType = 'Tümü';

  final List<Map<String, dynamic>> _topCategories = [
    {"name": "Meydan", "icon": CupertinoIcons.square_stack_3d_up_fill, "color": Color(0xFFFF5E62)},
    {"name": "Anketler", "icon": CupertinoIcons.chart_bar_square_fill, "color": Color(0xFF0A84FF)},
    {"name": "Gündem", "icon": CupertinoIcons.flame_fill, "color": Color(0xFFFF9500)},
    {"name": "Acil", "icon": CupertinoIcons.radiowaves_right, "color": Color(0xFFFF3B30)},
    {"name": "Tümünü Gör", "icon": CupertinoIcons.square_grid_2x2_fill, "color": Color(0xFF5856D6)},
  ];

  final List<Map<String, dynamic>> _typeFilters = [
    {"name": "Tümü", "icon": CupertinoIcons.infinite},
    {"name": "Gönderi", "icon": CupertinoIcons.text_alignleft},
    {"name": "Fotoğraf", "icon": CupertinoIcons.photo},
    {"name": "Video", "icon": CupertinoIcons.videocam_fill},
    {"name": "Soru", "icon": CupertinoIcons.question_circle},
    {"name": "Anket", "icon": CupertinoIcons.chart_bar},
  ];

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    if (currentUser != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(currentUser!.uid)
            .get();
        if (doc.exists && mounted) {
          var data = doc.data()!;
          setState(() {
            userName = data['fullname'] ?? "Kullanıcı";
            userAvatar = data['profileImage'] ?? "";
            String phone = data['phone'] ?? "";
            hasVerifiedPhone = phone.isNotEmpty;
          });
        }
      } catch (_) {}
    }
  }

  void _requireLoginModal({String actionTitle = "Topluluk meydanında işlem yapabilmek"}) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(
          "Giriş Yapmanız Gerekmektedir",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        message: Text(
          "$actionTitle için lütfen hesabınıza giriş yapınız veya kayıt olunuz.",
        ),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const Auth()),
              );
            },
            child: const Text("Giriş Yap / Kayıt Ol"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Vazgeç"),
        ),
      ),
    );
  }

  void _onCreatePostTapped({String? initialType}) {
    if (currentUser == null || currentUser!.isAnonymous) {
      _requireLoginModal(actionTitle: "Paylaşım yapabilmek");
      return;
    }
    if (!hasVerifiedPhone) {
      _showPhoneVerificationAlert();
      return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const GrupGonderiOlustur()),
    );
  }

  void _showCreateOptionsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Pazarcık Meydanı'nda Paylaş"),
        message: const Text("Toplulukla paylaşmak istediğiniz içerik türünü seçin"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _onCreatePostTapped();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.text_bubble, color: Color(0xFFFF5E62), size: 20),
                SizedBox(width: 8),
                Text("Düşünce / Gönderi Paylaş"),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _onCreatePostTapped();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text("Fotoğraflı Gönderi"),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _onCreatePostTapped();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.videocam_fill, color: Color(0xFFFF5E62), size: 20),
                SizedBox(width: 8),
                Text("Videolu Gönderi"),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _onCreatePostTapped();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.chart_bar_alt_fill, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text("Anket Başlat"),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("Vazgeç"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showPhoneVerificationAlert() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Telefon Onayı Gerekli"),
        content: const Text(
            "Pazarcık Meydanı'nda paylaşım yapmak için profilinizden telefon numaranızı doğrulamanız gerekmektedir."),
        actions: [
          CupertinoDialogAction(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text("Profilime Git"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF6F8FA),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- APP BAR & HEADER (Görsel 5) ---
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      children: [
                        Text(
                          "Meydan",
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF5E62),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFFFECE8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.location_solid,
                                  size: 14, color: Color(0xFFFF5E62)),
                              SizedBox(width: 4),
                              Text(
                                "PAZARCIK",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF5E62),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Kaydedilenler butonu
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.white,
                            border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE5E7EB)),
                          ),
                          child: IconButton(
                            icon: const Icon(CupertinoIcons.bookmark_fill,
                                size: 20, color: Color(0xFFFF5E62)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const KaydedilenGonderilerPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Profil Avatar
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFF5E62),
                            backgroundImage: userAvatar.isNotEmpty
                                ? NetworkImage(userAvatar)
                                : null,
                            child: userAvatar.isEmpty
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : "P",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- ÜST KATEGORİ DAİRELERİ (Akış, Yakınım, Gündem, Acil, Tümü) ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    height: 86,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _topCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final cat = _topCategories[index];
                        final isSelected = _selectedCategory == cat['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat['name'] as String);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? (cat['color'] as Color)
                                      : (isDark
                                          ? const Color(0xFF131B2E)
                                          : (cat['color'] as Color).withOpacity(0.08)),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : (cat['color'] as Color).withOpacity(0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: (cat['color'] as Color).withOpacity(0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  cat['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : (cat['color'] as Color),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat['name'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? Colors.white : const Color(0xFF1C1C1E))
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // --- MİSAFİR UYARI BİLGİ KARTI ---
              if (currentUser == null || currentUser!.isAnonymous)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.person_crop_circle_badge_exclam, color: Color(0xFF6366F1), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Misafir modundasınız. Gönderi ve anket paylaşmak için giriş yapın.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF3730A3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const Auth()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Giriş Yap",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // --- İÇERİK TÜRÜ FİLTRELERİ (Tümü, Gönderi, Fotoğraf, Soru, Anket) ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _typeFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = _typeFilters[index];
                        final isSelected = _selectedType == filter['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedType = filter['name'] as String);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF5E62)
                                  : (isDark
                                      ? const Color(0xFF131B2E)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark
                                        ? Colors.white12
                                        : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  filter['icon'] as IconData,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  filter['name'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // --- GÖNDERİ LİSTESİ ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('group_posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 14),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131B2E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5856D6).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.lock_shield_fill,
                                    size: 44,
                                    color: Color(0xFF5856D6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Giriş Yapmanız Gerekmektedir",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Bu bölümü görebilmek ve akıştaki paylaşımlara erişebilmek için giriş yapmanız gerekmektedir.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                            builder: (_) => const Auth()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5856D6),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(CupertinoIcons.person_badge_plus_fill, size: 18),
                                    label: const Text(
                                      "Giriş Yap",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.chat_bubble_2,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "Henüz Meydan'da paylaşım yok.",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _onCreatePostTapped,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5E62),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text("İlk Sen Paylaş"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  // 1. Üst Kategori Filtreleme
                  if (_selectedCategory == 'Anketler') {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['pollData'] != null;
                    }).toList();
                  } else if (_selectedCategory == 'Gündem') {
                    // En çok etkileşim alanlar (beğeni + yorum)
                    docs = List.of(docs)..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aInteractions = (aData['likes'] as List? ?? []).length + (aData['commentCount'] as num? ?? 0);
                      final bInteractions = (bData['likes'] as List? ?? []).length + (bData['commentCount'] as num? ?? 0);
                      return bInteractions.compareTo(aInteractions);
                    });
                  }

                  // 2. İçerik Türü Filtreleme
                  if (_selectedType == 'Gönderi') {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final imgs = data['imageUrls'] as List? ?? [];
                      final vid = (data['videoUrl'] ?? '').toString().trim();
                      final hasPoll = data['pollData'] != null;
                      return imgs.isEmpty && vid.isEmpty && !hasPoll;
                    }).toList();
                  } else if (_selectedType == 'Fotoğraf') {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final imgs = data['imageUrls'] as List? ?? [];
                      return imgs.isNotEmpty;
                    }).toList();
                  } else if (_selectedType == 'Video') {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final vid = (data['videoUrl'] ?? '').toString().trim();
                      return vid.isNotEmpty;
                    }).toList();
                  } else if (_selectedType == 'Anket') {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['pollData'] != null;
                    }).toList();
                  } else if (_selectedType == 'Soru') {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final content = (data['content'] ?? '').toString();
                      return content.contains('?') || content.toLowerCase().contains('soru');
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedCategory == 'Anketler' || _selectedType == 'Anket'
                                  ? CupertinoIcons.chart_bar_square
                                  : CupertinoIcons.doc_text_search,
                              size: 52,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedCategory == 'Anketler' || _selectedType == 'Anket'
                                  ? "Henüz aktif anket bulunmuyor."
                                  : "Bu filtreye uygun gönderi bulunamadı.",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        var doc = docs[index];
                        return GrupGonderiKarti(
                          postId: doc.id,
                          data: doc.data() as Map<String, dynamic>,
                        );
                      },
                      childCount: docs.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // --- SAĞ ALT MODERN (+) PAYLAŞIM BUTONU (Görsel 6) ---
          Positioned(
            right: 18,
            bottom: 30,
            child: GestureDetector(
              onTap: _showCreateOptionsSheet,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF5E62),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5E62).withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
