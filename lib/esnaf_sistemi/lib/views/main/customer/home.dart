import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import '../../../utils/store_availability.dart';

import '../../../providers/cart.dart';
import '../../../models/cart.dart';
import '../customer/cart.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/product/details.dart';

const Color _orange = Color(0xFFFF6B35);
const Color _orangeLight = Color(0xFFFFF3EE);
const Color _dark = Color(0xFF1A1A2E);
const Color _textSub = Color(0xFF9B9BAA);

const List<Map<String, String>> _wheelItems = [
  {'label': 'Döner', 'emoji': '🌯'},
  {'label': 'Pizza', 'emoji': '🍕'},
  {'label': 'Hamburger', 'emoji': '🍔'},
  {'label': 'Tavuk Şiş', 'emoji': '🍢'},
  {'label': 'Tantuni', 'emoji': '🌮'},
  {'label': 'Adana', 'emoji': '🥩'},
  {'label': 'Kuşbaşı', 'emoji': '🍖'},
  {'label': 'Kokoreç', 'emoji': '🔥'},
];

String _pickString(Map<String, dynamic>? data, List<String> keys,
    {String fallback = ''}) {
  if (data == null) return fallback;
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ??
      fallback;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

bool _isMonthlyDealActive(Map<String, dynamic> data) {
  if (data['isMonthlyDeal'] != true ||
      data['monthlyDealEnabled'] == false ||
      data['dealStatus'] == 'passive') {
    return false;
  }

  final limit = _asInt(data['dealLimit'], fallback: 0);
  final sold = _asInt(data['dealSoldCount'], fallback: 0);
  if (limit > 0 && sold >= limit) return false;

  final now = DateTime.now();
  if (data['dealRepeatMonthly'] == true) {
    final startDay = _asInt(data['dealRepeatStartDay'], fallback: 1);
    final endDay = _asInt(data['dealRepeatEndDay'], fallback: startDay);
    final day = now.day;
    if (startDay <= endDay) return day >= startDay && day <= endDay;
    return day >= startDay || day <= endDay;
  }

  final start = _asDate(data['dealStartsAt']);
  final end = _asDate(data['dealEndsAt']);
  if (start != null && now.isBefore(start)) return false;
  if (end != null && now.isAfter(end)) return false;
  return true;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String selectedCategory = "Tümü";
  String userName = "Pazarcıklı";

  // Arama icin tek controller, her yerden guncellenebilir.
  final TextEditingController _searchCtrl = TextEditingController();
  String get searchQuery => _searchCtrl.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    // Arama degisince ekrani yenile.
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      final data = doc.data() ?? {};
      final displayName = _pickString(
        data,
        ['fullname', 'fullName', 'name', 'displayName', 'email'],
        fallback: 'Kullanıcı',
      );
      setState(() => userName = displayName.split(' ')[0]);
    }
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Günaydın";
    if (h < 18) return "İyi Günler";
    return "İyi Akşamlar";
  }

  // Carktaki secimi arama kutusuna yaz.
  void _applyWheelResult(String label) {
    _searchCtrl.text = label;
    // Cursor'u sona gotur.
    _searchCtrl.selection = TextSelection.collapsed(offset: label.length);
  }

  // Cark modalini ac.
  void _openWheelModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Çark",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, anim, __) => const SizedBox(),
      transitionBuilder: (ctx, anim, __, ___) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: Center(
              child: _WheelModal(
                onResult: (label) {
                  Navigator.of(ctx).pop();
                  _applyWheelResult(label);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final ar = w < 380 ? 0.62 : (w < 430 ? 0.68 : 0.76);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildCarousel(),
                _buildMonthlyDealsSection(),
                const SizedBox(height: 28),
                _buildSectionHeader("Kategoriler"),
                const SizedBox(height: 14),
                _buildCategoriesStream(),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  _searchCtrl.text.isEmpty
                      ? "Sana Özel Lezzetler"
                      : "Arama Sonuçları",
                ),
                const SizedBox(height: 16),
                _buildProductGrid(ar),
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),

      // Cark butonu, sag alt kose FAB.
      floatingActionButton: _WheelFab(onTap: _openWheelModal),
    );
  }

  // APP BAR
  Widget _buildAppBar(BuildContext context) {
    final cartData = Provider.of<CartData>(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      expandedHeight: 152,
      toolbarHeight: 76,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${_getGreeting()}, $userName",
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: _textSub,
                    fontWeight: FontWeight.w600)),
            Row(children: [
              const Icon(CupertinoIcons.location_solid,
                  color: _orange, size: 13),
              const SizedBox(width: 3),
              Text("Pazarcık",
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800)),
            ]),
          ]),
          Row(children: [
            _circleBtn(
                CupertinoIcons.bell,
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.onSurface,
                () {},
                border: true),
            const SizedBox(width: 10),
            _cartBtn(context, cartData),
          ]),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          color: Theme.of(context).colorScheme.surface,
          child: _SearchBar(controller: _searchCtrl),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color bg, Color fg, VoidCallback onTap,
      {bool border = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border
              ? Border.all(color: Theme.of(context).dividerColor, width: 1.5)
              : null,
        ),
        child: Icon(icon, size: 19, color: fg),
      ),
    );
  }

  Widget _cartBtn(BuildContext context, CartData cartData) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CartScreen())),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 38,
          height: 38,
          decoration:
              const BoxDecoration(color: _orange, shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.cart_fill,
              color: Colors.white, size: 18),
        ),
        if (cartData.cartItemCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
              child: Text('${cartData.cartItemCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title,
          style: GoogleFonts.nunito(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3)),
    );
  }

  Widget _buildCarousel() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('campaigns').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        return SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (_, i) {
              final c = snap.data!.docs[i];
              return Container(
                width: MediaQuery.of(context).size.width * 0.82,
                margin: const EdgeInsets.only(right: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PortalNetworkImage(
                        url: (c['image'] ?? '').toString(),
                        errorWidget: Container(color: _orangeLight),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          (c['title'] ?? '').toString(),
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMonthlyDealsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('isMonthlyDeal', isEqualTo: true)
          .limit(40)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox(height: 8);
        }

        final deals = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return _isMonthlyDealActive(data);
        }).toList();

        if (deals.isEmpty) return const SizedBox(height: 8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.sparkles,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("Ayın İndirimleri",
                        style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 214,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: deals.length,
                itemBuilder: (context, index) {
                  final doc = deals[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final name = _pickString(
                      data, ['productName', 'title', 'name'],
                      fallback: 'Ayın menüsü');
                  final image = _pickString(
                      data, ['productImage', 'imageUrl', 'image', 'photoUrl']);
                  final price = _asDouble(data['price']);
                  final discount = _asInt(data['discount']);
                  final current =
                      discount > 0 ? price - (price * discount / 100) : price;

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetailsScreen(product: doc)),
                    ),
                    child: Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                    child: PortalNetworkImage(
                                        url: image, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  top: 10,
                                  child: _dealBadge("Ayın Menüsü"),
                                ),
                                if (discount > 0)
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: _dealBadge("%$discount"),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    if (discount > 0)
                                      Text("₺${price.toStringAsFixed(0)}",
                                          style: GoogleFonts.nunito(
                                              color: _textSub,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              fontWeight: FontWeight.w700)),
                                    if (discount > 0) const SizedBox(width: 6),
                                    Text("₺${current.toStringAsFixed(1)}",
                                        style: GoogleFonts.nunito(
                                            color: const Color(0xFFFF2D55),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dealBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2D55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: GoogleFonts.nunito(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildCategoriesStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cateogries').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;
        return SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: docs.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _catItem("Tümü", "");
              return _catItem(
                  docs[i - 1]['categoryName'], docs[i - 1]['image']);
            },
          ),
        );
      },
    );
  }

  Widget _catItem(String name, String image) {
    final bool sel = selectedCategory == name;
    return GestureDetector(
      onTap: () => setState(() {
        selectedCategory = name;
        _searchCtrl.clear();
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? _orangeLight : Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: sel ? _orange : const Color(0xFFEEEEEE), width: 2),
              boxShadow: [
                BoxShadow(
                    color: sel
                        ? _orange.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ClipOval(
              child: name == "Tümü"
                  ? const Icon(Icons.grid_view_rounded,
                      color: _orange, size: 26)
                  : PortalNetworkImage(
                      url: image,
                      fit: BoxFit.cover,
                      placeholder: const CupertinoActivityIndicator()),
            ),
          ),
          const SizedBox(height: 7),
          Text(name,
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  color: sel ? _orange : _textSub)),
        ]),
      ),
    );
  }

  Widget _buildProductGrid(double ar) {
    final cartData = Provider.of<CartData>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    Query q = FirebaseFirestore.instance.collection('products');
    if (_searchCtrl.text.isEmpty && selectedCategory != "Tümü") {
      q = q.where('categoryName', isEqualTo: selectedCategory);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CupertinoActivityIndicator()));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) return _noResult();

        final list = snap.data!.docs.where((p) {
          final data = p.data() as Map<String, dynamic>? ?? {};
          if (data['isMonthlyDeal'] == true && !_isMonthlyDealActive(data)) {
            return false;
          }
          return _pickString(data, ['productName', 'title', 'name'])
              .toLowerCase()
              .contains(searchQuery);
        }).toList();

        if (list.isEmpty) return _noResult();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: ar),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final product = list[i];
            final productData = product.data() as Map<String, dynamic>? ?? {};
            final vendorId = _pickString(
                productData, ['vendorId', 'sellerId', 'seller_id', 'storeId']);
            if (vendorId.isEmpty) {
              return _ProductCard(
                  prod: product, cartData: cartData, userId: userId);
            }
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(vendorId)
                  .snapshots(),
              builder: (context, storeSnapshot) {
                final storeData =
                    storeSnapshot.data?.data() as Map<String, dynamic>?;
                final storeOpen =
                    storeData != null && StoreAvailability.isOpen(storeData);
                return Opacity(
                  opacity: storeOpen ? 1 : 0.52,
                  child: AbsorbPointer(
                    absorbing: !storeOpen,
                    child: _ProductCard(
                        prod: product, cartData: cartData, userId: userId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _noResult() {
    return Padding(
      padding: const EdgeInsets.only(top: 50, bottom: 20),
      child: Column(children: [
        const Text("🍽️", style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text("Ürün bulunamadı",
            style: GoogleFonts.nunito(
                color: _textSub, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// â”€â”€â”€ Ã‡ARK FAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WheelFab extends StatefulWidget {
  final VoidCallback onTap;
  const _WheelFab({required this.onTap});

  @override
  State<_WheelFab> createState() => _WheelFabState();
}

class _WheelFabState extends State<_WheelFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _dark.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🎰", style: TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text("Ne yesem?",
                  style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€ Ã‡ARK MODAL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WheelModal extends StatefulWidget {
  final ValueChanged<String> onResult;
  const _WheelModal({required this.onResult});

  @override
  State<_WheelModal> createState() => _WheelModalState();
}

class _WheelModalState extends State<_WheelModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _isSpinning = false;
  int _resultIndex = -1;
  double _currentAngle = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addListener(() => setState(() => _currentAngle = _anim.value));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onStop();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _resultIndex = -1;
    });

    final rand = Random();
    final target = rand.nextInt(_wheelItems.length);
    final sliceDeg = 360.0 / _wheelItems.length;
    // Okun tam tepede (270Â° baÅŸlangÄ±Ã§) durmasÄ± iÃ§in:
    final targetDeg = 270 - (target * sliceDeg + sliceDeg / 2);
    final totalRot = 1440 + ((targetDeg - (_currentAngle % 360)) % 360);

    _anim = Tween<double>(
      begin: _currentAngle,
      end: _currentAngle + totalRot,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));

    _ctrl
      ..duration = const Duration(milliseconds: 4000)
      ..forward(from: 0);
  }

  void _onStop() {
    // KaÃ§Ä±ncÄ± dilimde durduÄŸumuzu gerÃ§ek aÃ§Ä±dan hesapla
    final sliceDeg = 360.0 / _wheelItems.length;
    final normalized =
        (360 - (_currentAngle % 360)) % 360; // ok 0 derece, cark ters
    final idx = (normalized / sliceDeg).floor() % _wheelItems.length;

    setState(() {
      _isSpinning = false;
      _resultIndex = idx;
      _currentAngle = _currentAngle % 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _resultIndex >= 0 ? _wheelItems[_resultIndex] : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BaÅŸlÄ±k
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Bugün ne yesem?",
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  Text("Çevir, karar versin!",
                      style: GoogleFonts.nunito(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ã‡ARK
            SizedBox(
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                // DÄ±ÅŸ parlama
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _orange.withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 4)
                    ],
                  ),
                ),
                // Ã‡ark
                Transform.rotate(
                  angle: _currentAngle * pi / 180,
                  child: CustomPaint(
                      size: const Size(210, 210),
                      painter: _WheelPainter(items: _wheelItems)),
                ),
                // Merkez
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8)
                    ],
                  ),
                  child:
                      const Icon(Icons.star_rounded, color: _orange, size: 20),
                ),
                // Ok
                Positioned(
                  top: 5,
                  child: CustomPaint(
                      size: const Size(22, 28), painter: _PointerPainter()),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // SonuÃ§ rozeti
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: picked != null
                  ? Container(
                      key: ValueKey(picked['label']),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _orange.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(picked['emoji']!,
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Text(picked['label']!,
                              style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    )
                  : Container(
                      key: const ValueKey('empty'),
                      height: 52,
                    ),
            ),

            const SizedBox(height: 16),

            // Butonlar
            if (picked != null) ...[
              // Ara butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => widget.onResult(picked['label']!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text("${picked['emoji']!}  ${picked['label']!} ara",
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),
              // Tekrar Ã§evir
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _spin,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text("Tekrar çevir",
                      style: GoogleFonts.nunito(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ] else
              // Ä°lk Ã§evirme butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSpinning ? null : _spin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSpinning ? _orange.withValues(alpha: 0.5) : _orange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSpinning
                      ? const CupertinoActivityIndicator(
                          color: Colors.white, radius: 11)
                      : Text("🎰  Çevir!",
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ ARAMA Ã‡UBUÄU â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// âœ… ArtÄ±k dÄ±ÅŸarÄ±dan controller alÄ±yor â€” hiÃ§bir sync sorunu yok
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(CupertinoIcons.search, color: Color(0xFFAAAAAA), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "Ürün, kategori ara...",
              hintStyle: GoogleFonts.nunito(
                  color: const Color(0xFFAAAAAA),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        // âœ… X butonu ile temizleme
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, val, __) => val.text.isNotEmpty
              ? GestureDetector(
                  onTap: () => controller.clear(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(CupertinoIcons.xmark_circle_fill,
                        color: Color(0xFFCCCCCC), size: 18),
                  ),
                )
              : const SizedBox(width: 10),
        ),
      ]),
    );
  }
}

// â”€â”€â”€ ÃœRÃœN KARTI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ProductCard extends StatelessWidget {
  final DocumentSnapshot prod;
  final CartData cartData;
  final String userId;
  const _ProductCard(
      {required this.prod, required this.cartData, required this.userId});

  @override
  Widget build(BuildContext context) {
    final data = prod.data() as Map<String, dynamic>? ?? {};
    final double price = _asDouble(data['price']);
    final int disc = _asInt(data['discount']);
    final double cur = disc > 0 ? price - (price * disc / 100) : price;
    final productName =
        _pickString(data, ['productName', 'title', 'name'], fallback: 'Ürün');
    final productImage =
        _pickString(data, ['productImage', 'imageUrl', 'image', 'photoUrl']);
    final vendorId = _pickString(
        data, ['vendorId', 'sellerId', 'seller_id', 'storeId', 'userId']);
    final isMonthlyDeal = _isMonthlyDealActive(data);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailsScreen(product: prod))),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: PortalNetworkImage(
                    url: productImage,
                    fit: BoxFit.cover,
                    placeholder: Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child:
                            const Center(child: CupertinoActivityIndicator())),
                    errorWidget: Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(CupertinoIcons.photo,
                            color: Colors.grey)),
                  ),
                ),
              ),
              if (disc > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text("-%$disc",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              if (isMonthlyDeal)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text("Ayın Menüsü",
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (disc > 0)
                          Text("₺${price.toStringAsFixed(0)}",
                              style: GoogleFonts.nunito(
                                  color: _textSub,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.lineThrough)),
                        Text("₺${cur.toStringAsFixed(1)}",
                            style: GoogleFonts.nunito(
                                color: _orange,
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                      ]),
                  GestureDetector(
                    onTap: () {
                      cartData.addToCart(CartItem(
                          id: prod.id,
                          docId: prod.id,
                          prodId: prod.id,
                          userId: userId,
                          sellerId: vendorId,
                          prodName: productName,
                          prodPrice: cur,
                          prodImgUrl: productImage,
                          isMonthlyDeal: isMonthlyDeal,
                          totalPrice: cur,
                          quantity: 1));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Sepete eklendi 🛒",
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700)),
                        duration: const Duration(milliseconds: 600),
                        backgroundColor: _orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(14),
                      ));
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(CupertinoIcons.add,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// â”€â”€â”€ Ã‡ARK PAINTER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WheelPainter extends CustomPainter {
  final List<Map<String, String>> items;
  _WheelPainter({required this.items});

  static const List<Color> _colors = [
    Color(0xFFFF6B35),
    Color(0xFFFF8C42),
    Color(0xFFFFB347),
    Color(0xFFFF6B6B),
    Color(0xFFFF4757),
    Color(0xFFFF7043),
    Color(0xFFFF8F00),
    Color(0xFFFF5722),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = (2 * pi) / items.length;

    for (int i = 0; i < items.length; i++) {
      final startAngle = i * sliceAngle - pi / 2;

      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sliceAngle,
          true,
          Paint()..color = _colors[i % _colors.length]);

      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sliceAngle,
          true,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      final mid = startAngle + sliceAngle / 2;
      final tRad = radius * 0.60;
      final offset =
          Offset(center.dx + tRad * cos(mid), center.dy + tRad * sin(mid));

      final ep = TextPainter(
          text: TextSpan(
              text: items[i]['emoji'], style: const TextStyle(fontSize: 17)),
          textDirection: TextDirection.ltr)
        ..layout();

      final lp = TextPainter(
          text: TextSpan(
              text: items[i]['label'],
              style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          textDirection: TextDirection.ltr)
        ..layout();

      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..rotate(mid + pi / 2);
      ep.paint(canvas, Offset(-ep.width / 2, -ep.height / 2 - 9));
      lp.paint(canvas, Offset(-lp.width / 2, ep.height / 2 - 10));
      canvas.restore();
    }

    canvas.drawCircle(
        center,
        radius - 1,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

// â”€â”€â”€ POINTER PAINTER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}
