import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔥 Diğer dosyaları içeri aktarıyoruz
import 'grup_gonderi_olustur.dart';
import 'grup_gonderi_karti.dart';

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

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    if (currentUser != null) {
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
    }
  }

  void _onCreatePostTapped() {
    if (!hasVerifiedPhone) {
      _showPhoneVerificationAlert();
      return;
    }
    // 🔥 Gönderi Oluşturma sayfasına git
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const GrupGonderiOlustur()),
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- ÜST KAPAK VE APPBAR ---
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0056D2),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text("Pazarcık Meydanı",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?q=80&w=1000&auto=format&fit=crop",
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- PAYLAŞIM BAŞLATMA ALANI ---
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: userAvatar.isNotEmpty
                            ? NetworkImage(userAvatar)
                            : null,
                        child: userAvatar.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _onCreatePostTapped,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text("Ne düşünüyorsun, $userName?",
                                style: TextStyle(color: Colors.grey.shade700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _quickAction(Icons.photo_library, "Fotoğraf",
                          Colors.green, _onCreatePostTapped),
                      _quickAction(Icons.poll, "Anket", Colors.orange,
                          _onCreatePostTapped),
                      _quickAction(
                          Icons.info_outline, "Kurallar", Colors.blue, () {}),
                    ],
                  )
                ],
              ),
            ),
          ),

          // --- CANLI AKIŞ (FIREBASE) ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('group_posts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                    child: Center(child: CupertinoActivityIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                    child: Center(child: Text("Henüz paylaşım yok.")));
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return GrupGonderiKarti(
                      postId: doc.id,
                      data: doc.data() as Map<String, dynamic>,
                    );
                  },
                  childCount: snapshot.data!.docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
