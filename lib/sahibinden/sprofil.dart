// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'real_estate_auth_page.dart';
import 'add_ad_page.dart';
import 'ad_detail_page.dart';
import 'seller_store_page.dart';
import 'package:pazarcik_portal/profil/edit_profile.dart';

class SahibindenProfileView extends StatefulWidget {
  const SahibindenProfileView({Key? key}) : super(key: key);

  @override
  State<SahibindenProfileView> createState() => _SahibindenProfileViewState();
}

class _SahibindenProfileViewState extends State<SahibindenProfileView> {
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "";

  final Color sahibindenYellow = const Color(0xFFFFE800);
  final Color sahibindenDark = const Color(0xFF1C1C1E);

  bool _isCorporateApproved(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final status = (user['corporateSellerStatus'] ?? user['sellerStatus'] ?? '')
        .toString();

    return role == 'kurumsal_satici' ||
        role == 'corporate_seller' ||
        role == 'emlakci' ||
        status == 'approved' ||
        user['corporateSellerApproved'] == true ||
        user['sellerApproved'] == true;
  }

  bool _isCorporatePending(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final status = (user['corporateSellerStatus'] ?? user['sellerStatus'] ?? '')
        .toString();

    return role == 'kurumsal_satici_pending' ||
        role == 'emlakci_pending' ||
        status == 'pending';
  }

  bool _isAdActive(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    if (status.isNotEmpty) return status == 'active';
    if (data['isActive'] is bool) return data['isActive'];
    return true;
  }

  String _formatPrice(dynamic value) {
    if (value == null) return "Fiyat yok";
    if (value is num) {
      return "${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} TL";
    }
    final text = value.toString();
    return text.isEmpty ? "Fiyat yok" : "$text TL";
  }

  double _averageRating(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    double total = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['rating'] ?? 0).toDouble();
    }
    return total / docs.length;
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Center(
          child: CupertinoButton(
            color: sahibindenDark,
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const EditProfile()),
              );
            },
            child: const Text("Giriş Yap"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: sahibindenYellow,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          "Sahibinden Panelim",
          style: GoogleFonts.inter(
            color: sahibindenDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(child: Text("Bağlantı hatası oluştu."));
          }

          if (!userSnapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final userData =
              (userSnapshot.data?.data() as Map<String, dynamic>?) ?? {};

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(userData),
                const SizedBox(height: 18),
                _buildReviewSummary(),
                const SizedBox(height: 22),
                _sectionTitle("Performans Özeti"),
                const SizedBox(height: 12),
                _buildQuickStats(),
                const SizedBox(height: 24),
                _sectionTitle("Hızlı İşlemler"),
                const SizedBox(height: 12),
                _buildActionButtons(userData),
                const SizedBox(height: 24),
                _sectionTitle("İlanlarımı Yönet"),
                const SizedBox(height: 12),
                _buildMyAdsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader(Map<String, dynamic> user) {
    final isPhoneVerified = user['phoneVerified'] ?? false;
    final isCorporate = _isCorporateApproved(user);
    final isPending = _isCorporatePending(user);

    final displayName = (user['businessName'] ??
            user['storeName'] ??
            user['fullname'] ??
            user['fullName'] ??
            user['name'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            "Pazarcıklı Üye")
        .toString();

    final photoUrl =
        (user['image'] ?? FirebaseAuth.instance.currentUser?.photoURL ?? '')
            .toString();

    String badgeText;
    Color badgeColor;

    if (isCorporate) {
      badgeText = "Onaylı Kurumsal Satıcı";
      badgeColor = Colors.green;
    } else if (isPending) {
      badgeText = "Kurumsal Başvuru İncelemede";
      badgeColor = Colors.orange;
    } else if (isPhoneVerified) {
      badgeText = "Telefon Doğrulandı";
      badgeColor = Colors.blue;
    } else {
      badgeText = "Telefonu Doğrula";
      badgeColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: sahibindenYellow,
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "P",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: sahibindenDark,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: isPhoneVerified
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const EditProfile(),
                            ),
                          );
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isCorporate
                ? CupertinoIcons.checkmark_seal_fill
                : CupertinoIcons.person_crop_circle,
            color: isCorporate ? Colors.green : Colors.black38,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('seller_reviews')
          .where('sellerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final rating = _averageRating(docs);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.star_fill,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  rating == 0
                      ? "Henüz mağaza puanınız yok"
                      : "${rating.toStringAsFixed(1)} / 5 mağaza puanı",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                "${docs.length} yorum",
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classified_ads')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        int activeCount = 0;
        int soldCount = 0;
        int passiveCount = 0;
        int totalViews = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();

          if (_isAdActive(data)) activeCount++;
          if (status == 'sold') soldCount++;
          if (status == 'passive') passiveCount++;

          final views = data['views'];
          if (views is int) totalViews += views;
          if (views is num) totalViews += views.toInt();
        }

        return Column(
          children: [
            Row(
              children: [
                _statCard("Yayında", "$activeCount",
                    CupertinoIcons.arrow_up_circle_fill, Colors.blue),
                const SizedBox(width: 12),
                _statCard("İzlenme", "$totalViews", CupertinoIcons.eye_fill,
                    Colors.purple),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard("Satıldı", "$soldCount",
                    CupertinoIcons.check_mark_circled_solid, Colors.green),
                const SizedBox(width: 12),
                _statCard("Pasif", "$passiveCount",
                    CupertinoIcons.pause_circle_fill, Colors.orange),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              val,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> userData) {
    final isPhoneVerified = userData['phoneVerified'] ?? false;
    final isCorporate = _isCorporateApproved(userData);
    final isPending = _isCorporatePending(userData);

    return Column(
      children: [
        _actionTile(
          "Yeni İlan Ekle",
          CupertinoIcons.add_circled,
          Colors.blue,
          () {
            if (!isPhoneVerified) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "İlan verebilmek için telefon numaranızı doğrulamalısınız.",
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const AddAdPage()),
            );
          },
        ),
        _actionTile(
          "Mağazamı Gör",
          CupertinoIcons.building_2_fill,
          Colors.black87,
          () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => SellerStorePage(
                  sellerId: uid,
                  sellerData: userData,
                ),
              ),
            );
          },
        ),
        _actionTile(
          isPhoneVerified ? "Profili Düzenle" : "Telefon Numarasını Doğrula",
          isPhoneVerified
              ? CupertinoIcons.profile_circled
              : CupertinoIcons.phone_badge_plus,
          isPhoneVerified ? Colors.blueGrey : Colors.red,
          () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const EditProfile()),
            );
          },
        ),
        if (!isCorporate)
          _actionTile(
            isPending
                ? "Kurumsal Başvuruyu Görüntüle"
                : "Kurumsal Satıcı Başvurusu",
            CupertinoIcons.checkmark_shield_fill,
            isPending ? Colors.orange : Colors.green,
            () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const RealEstateAuthPage()),
              );
            },
          ),
      ],
    );
  }

  Widget _actionTile(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
      ),
    );
  }

  Widget _buildMyAdsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classified_ads')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Hata oluştu."));
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final ads = snapshot.data!.docs.toList();

        ads.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final tA = aData['createdAt'] as Timestamp?;
          final tB = bData['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        if (ads.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: _cardDecoration(),
            child: const Column(
              children: [
                Icon(CupertinoIcons.doc_text_search,
                    size: 42, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  "Henüz ilanınız bulunmamaktadır.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ads.length,
          itemBuilder: (context, index) {
            final doc = ads[index];
            final data = doc.data() as Map<String, dynamic>;
            data['docId'] = doc.id;
            return _buildAdManagementCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildAdManagementCard(String docId, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'active').toString();
    final images = data['images'] as List? ?? [];
    final views = data['views'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 72,
                  height: 72,
                  color: const Color(0xFFF1F5F9),
                  child: images.isNotEmpty
                      ? PortalNetworkImage(
                          url: images.first.toString(), fit: BoxFit.cover)
                      : const Icon(CupertinoIcons.photo, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? "Başlıksız",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatPrice(data['price']),
                      style: const TextStyle(
                        color: Color(0xFF0056D2),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStatusBadge(status),
                        const SizedBox(width: 8),
                        const Icon(CupertinoIcons.eye_fill,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          views.toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: _manageButton(
                  "Görüntüle",
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => AdDetailPage(ad: data),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _manageButton(
                  status == 'passive' ? "Yayına Al" : "Kaldır",
                  Colors.orange,
                  () => _updateAdStatus(
                    docId,
                    status == 'passive' ? 'active' : 'passive',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _manageButton(
                  "Satıldı",
                  Colors.green,
                  () => _updateAdStatus(docId, 'sold'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.green;
    String text = "Yayında";

    if (status == 'sold') {
      color = Colors.blue;
      text = "Satıldı";
    } else if (status == 'passive') {
      color = Colors.red;
      text = "Kaldırıldı";
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _manageButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateAdStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('classified_ads')
        .doc(docId)
        .update({
      'status': newStatus,
      'isActive': newStatus == 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Güncellendi: $newStatus")),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: Colors.grey,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}
