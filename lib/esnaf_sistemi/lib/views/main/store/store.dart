// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:google_fonts/google_fonts.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/store/store_details.dart';

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String selectedFilter = "Hepsi";
  final List<String> filters = ["Hepsi", "Açık Olanlar", "Popüler", "En Hızlı"];

  // Firebase sorgusunu duruma göre dinamik hale getirdik
  Stream<QuerySnapshot> _getStoreStream() {
    Query query = FirebaseFirestore.instance
        .collection('customers')
        .where('role', isEqualTo: 'satici')
        .where('isApproved', isEqualTo: true);

    if (selectedFilter == "Açık Olanlar") {
      query = query.where('isStoreOpen', isEqualTo: true);
    } else if (selectedFilter == "Popüler") {
      query = query.orderBy('rating', descending: true);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Pazarcık Esnafları",
          style: GoogleFonts.inter(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStoreStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoStoreFound();
                }

                var stores = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status =
                      (data['restaurantStatus'] ?? 'active').toString();
                  return status == 'active' && data['isBlocked'] != true;
                }).toList();

                // En Hızlı filtresi seçildiyse (Client-Side sıralama yapıyoruz, Firestore'da string olduğu için)
                if (selectedFilter == "En Hızlı") {
                  stores.sort((a, b) {
                    int timeA = int.tryParse(
                            (a.data() as Map)['avgPrepTime']?.toString() ??
                                "30") ??
                        30;
                    int timeB = int.tryParse(
                            (b.data() as Map)['avgPrepTime']?.toString() ??
                                "30") ??
                        30;
                    return timeA.compareTo(timeB);
                  });
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    var data = stores[index].data() as Map<String, dynamic>;
                    return _buildRestaurantCard(data, stores[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 55,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedFilter == filters[index];
          return GestureDetector(
            onTap: () => setState(() => selectedFilter = filters[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? trendyolOrange : iosBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                filters[index],
                style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestaurantCard(
      Map<String, dynamic> store, DocumentSnapshot doc) {
    String imageUrl = store['storeCoverImage'] ??
        store['image'] ??
        store['profileImage'] ??
        "";
    bool isOpen = store['isStoreOpen'] ?? true;
    double rating = (store['rating'] ?? 5.0).toDouble();

    return Opacity(
      opacity: isOpen ? 1.0 : 0.6, // Kapalı olanlar soluk görünür
      child: GestureDetector(
        onTap: () {
          // Mağaza kapalı bile olsa menü görülebilsin
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => StoreDetails(store: doc)));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: imageUrl.isNotEmpty
                        ? PortalNetworkImage(
                            url: imageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: Container(
                                height: 160,
                                color: iosBg,
                                child: const CupertinoActivityIndicator()),
                            errorWidget: _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),

                  // Açık/Kapalı Rozeti
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: isOpen
                              ? const Color(0xFF34C759)
                              : Colors.redAccent,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(isOpen ? "AÇIK" : "KAPALI",
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ),
                  ),

                  // Puan Rozeti
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5)
                          ]),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.star_fill,
                              color: rating >= 4.0
                                  ? const Color(0xFF34C759)
                                  : trendyolOrange,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                              store['storeName'] ??
                                  store['businessName'] ??
                                  store['restaurantName'] ??
                                  store['fullname'] ??
                                  "Pazarcık Esnafı",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -0.5)),
                        ),
                        const Icon(CupertinoIcons.chevron_right,
                            size: 16, color: Colors.black26),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMiniInfo(
                            CupertinoIcons.stopwatch_fill,
                            "${store['avgPrepTime'] ?? '30'} dk",
                            trendyolOrange),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildMiniInfo(
                              CupertinoIcons.location_solid,
                              store['address'] ?? "Pazarcık",
                              const Color(0xFF007AFF)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      color: const Color(0xFFE5E5EA),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.building_2_fill, size: 40, color: Colors.black12),
          SizedBox(height: 8),
          Text("Görsel Yok",
              style: TextStyle(
                  color: Colors.black26,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNoStoreFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.bag_badge_minus,
              size: 70, color: Colors.black12),
          const SizedBox(height: 16),
          Text("Henüz aktif restoran yok!",
              style: GoogleFonts.inter(
                  color: Colors.black45, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
