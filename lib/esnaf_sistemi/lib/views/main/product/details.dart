import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

import 'package:pazarcik_portal/esnaf_sistemi/lib/models/cart.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/store/store_details.dart';
import '../../../providers/cart.dart';
import '../customer/cart.dart';
import '../../../utils/store_availability.dart';

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class _ExtraCartDraft {
  const _ExtraCartDraft({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final double price;
  final String imageUrl;
}

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({Key? key, required this.product}) : super(key: key);
  final dynamic product;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool isFav = false;
  DocumentSnapshot? store;
  int quantity = 1;

  // Ekstralar iÃ§in state yÃ¶netimi
  Map<String, int> selectedExtras = {};
  final Map<String, _ExtraCartDraft> selectedExtraDrafts = {};
  double extrasTotalPrice = 0.0;
  final Set<String> removedIngredients = {};
  final Set<String> addedIngredients = {};

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

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, int> _asIntMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, rawValue) {
      final parsed = rawValue is num
          ? rawValue.toInt()
          : int.tryParse(rawValue.toString()) ?? 0;
      return MapEntry(key.toString(), parsed);
    });
  }

  int? _calorieAverage(dynamic value) {
    final matches = RegExp(r'\d+').allMatches(value?.toString() ?? '').toList();
    if (matches.isEmpty) return null;
    final values = matches
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();
    if (values.isEmpty) return null;
    return (values.reduce((left, right) => left + right) / values.length)
        .round();
  }

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
    _checkFavStatus();
  }

  // Favori durumunu kontrol et
  void _checkFavStatus() {
    var data = widget.product.data() as Map<String, dynamic>? ?? {};
    setState(() => isFav = data['isFav'] ?? false);
  }

  // Favori durumunu deÄŸiÅŸtir
  void toggleIsFav() {
    final db = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id);
    setState(() {
      isFav = !isFav;
      db.update({'isFav': isFav});
    });
    HapticFeedback.mediumImpact(); // Titresim destegi
  }

  // MaÄŸaza verilerini Ã§ek
  _fetchStoreData() async {
    var data = widget.product.data() as Map<String, dynamic>? ?? {};
    var vendorId = _pickString(
        data, ['vendorId', 'sellerId', 'seller_id', 'storeId', 'userId']);
    if (vendorId.isNotEmpty) {
      var details = await FirebaseFirestore.instance
          .collection('customers')
          .doc(vendorId)
          .get();
      if (mounted) setState(() => store = details);
    }
  }

  @override
  Widget build(BuildContext context) {
    var cartData = Provider.of<CartData>(context);
    var userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    var data = widget.product.data() as Map<String, dynamic>? ?? {};

    // Veri AtamalarÄ±
    String title = data['productName'] ?? data['title'] ?? 'İsimsiz Ürün';
    double originalPrice = _asDouble(data['price']);
    int discount = _asInt(data['discount']);
    double currentPrice = discount > 0
        ? originalPrice - (originalPrice * discount / 100)
        : originalPrice;
    String desc =
        data['description'] ?? 'Ürün hakkında detaylı bilgi bulunmuyor.';
    String prepTime = data['prepTime']?.toString() ?? '20';
    String imageUrl = _pickString(
        data, ['productImage', 'imageUrl', 'image', 'photoUrl'],
        fallback: 'https://via.placeholder.com/400');
    String vendorId = _pickString(
        data, ['vendorId', 'sellerId', 'seller_id', 'storeId', 'userId'],
        fallback: 'unknown');
    final isMonthlyDeal = data['isMonthlyDeal'] == true;
    final baseCalories = _calorieAverage(data['calorieText']);
    final extraCalorieValues = _asIntMap(data['addableIngredientCalories']);
    final selectedExtraCalories = addedIngredients.fold<int>(
      0,
      (total, ingredient) => total + (extraCalorieValues[ingredient] ?? 0),
    );
    final storeOpen = store != null &&
        (store?.exists ?? false) &&
        StoreAvailability.isOpen(
            store!.data() as Map<String, dynamic>? ?? const {});

    // Toplam Fiyat (ÃœrÃ¼n x Adet + Ekstralar)
    double finalTotalPrice = (currentPrice * quantity) + extrasTotalPrice;

    // ğŸ”¥ SEPETE EKLEME MANTIÄI ğŸ”¥
    void handleCartAction() {
      if (!storeOpen) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Restoran şu anda kapalı. Çalışma saatleri içinde tekrar deneyin."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      // 1. Ana ÃœrÃ¼nÃ¼ Ekle
      cartData.addToCart(CartItem(
        id: widget.product.id,
        docId: widget.product.id,
        prodId: widget.product.id,
        userId: userId,
        sellerId: vendorId,
        prodName: title,
        prodPrice: currentPrice,
        prodImgUrl: imageUrl,
        isMonthlyDeal: isMonthlyDeal,
        removedIngredients: removedIngredients.toList()..sort(),
        addedIngredients: addedIngredients.toList()..sort(),
        estimatedCalories:
            baseCalories == null ? null : baseCalories + selectedExtraCalories,
        totalPrice: currentPrice * quantity,
        quantity: quantity,
      ));

      // 2. SeÃ§ili EkstralarÄ± Ekle (AyrÄ± kalemler olarak)
      selectedExtras.forEach((extraId, qty) {
        final extra = selectedExtraDrafts[extraId];
        if (qty > 0) {
          if (extra == null) return;
          cartData.addToCart(CartItem(
            id: 'extra_${vendorId}_$extraId',
            docId: extraId,
            prodId: 'extra_${vendorId}_$extraId',
            userId: userId,
            sellerId: vendorId,
            prodName: extra.name,
            prodPrice: extra.price,
            prodImgUrl: extra.imageUrl.isNotEmpty ? extra.imageUrl : imageUrl,
            totalPrice: extra.price * qty,
            quantity: qty,
          ));
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$title sepete eklendi!"),
          backgroundColor: trendyolOrange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: "SEPETE GİT",
            textColor: Colors.white,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const CartScreen())),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar:
          _buildBottomBar(finalTotalPrice, handleCartAction, storeOpen),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(imageUrl, widget.product.id),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                          title, currentPrice, originalPrice, discount),
                      const SizedBox(height: 20),
                      _buildInfoBadges(prepTime, data['salesCount'] ?? 25,
                          data['rating'] ?? 4.8),
                      const Divider(height: 40, thickness: 0.5, color: iosBg),
                      _buildSectionTitle("Ürün Açıklaması"),
                      const SizedBox(height: 10),
                      Text(desc,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.6)),
                      _buildComplianceCard(data),
                      _buildPersonalizationCard(data),
                      const SizedBox(height: 25),

                      // ğŸ”¥ ADET SEÃ‡Ä°CÄ° ğŸ”¥
                      _buildMainQuantitySelector(),

                      const SizedBox(height: 30),

                      // ğŸ”¥ YANINDA Ä°YÄ° GÄ°DER (EKSTRALAR) ğŸ”¥
                      _buildExtrasSection(vendorId),

                      const SizedBox(height: 25),
                      _buildStoreCard(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      String title, double curPrice, double oldPrice, int disc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w800))),
            if (disc > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(8)),
                child: Text("-%$disc",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text("₺${curPrice.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: trendyolOrange)),
            const SizedBox(width: 10),
            if (disc > 0)
              Text("₺${oldPrice.toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoBadges(String time, int sales, double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _badge(CupertinoIcons.star_fill, "$rating", Colors.amber),
        _badge(CupertinoIcons.stopwatch, "$time dk", Colors.blueAccent),
        _badge(CupertinoIcons.flame_fill, "$sales+ Satış", Colors.orange),
      ],
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.inter(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87));
  }

  Widget _buildComplianceCard(Map<String, dynamic> data) {
    final ingredients = _asStringList(data['ingredients']);
    final allergens = _asStringList(data['allergens']);
    final removable = _asStringList(data['removableIngredients']);
    final addable = _asStringList(data['addableIngredients']);
    final warnings = _asStringList(data['dietaryWarnings']);
    final calorieText = data['calorieText']?.toString().trim() ?? '';
    final meatOrigin = data['meatOrigin']?.toString().trim() ?? '';
    final celiacWarning = data['celiacWarning']?.toString().trim() ?? '';
    final approved = data['complianceApprovedBySeller'] == true;

    if (ingredients.isEmpty &&
        allergens.isEmpty &&
        removable.isEmpty &&
        addable.isEmpty &&
        warnings.isEmpty &&
        calorieText.isEmpty &&
        meatOrigin.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iosBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_shield_fill,
                  color: Color(0xFF34C759), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('İçerik ve alerjen beyanı',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: approved
                      ? const Color(0xFF34C759).withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  approved ? 'Onaylı' : 'Öneri',
                  style: GoogleFonts.inter(
                    color: approved ? const Color(0xFF248A3D) : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (ingredients.isNotEmpty)
            _complianceLine('İçindekiler', ingredients.join(', ')),
          if (allergens.isNotEmpty)
            _complianceLine('Alerjenler', allergens.join(', '),
                color: Colors.orange),
          if (removable.isNotEmpty)
            _complianceLine('Çıkarılabilir', removable.join(', '),
                color: Colors.blueGrey),
          if (addable.isNotEmpty)
            _complianceLine('Ekstra seçenekleri', addable.join(', '),
                color: Colors.blue),
          if (celiacWarning.isNotEmpty)
            _complianceLine('Çölyak uyarısı', celiacWarning,
                color: Colors.redAccent),
          if (calorieText.isNotEmpty)
            _complianceLine('Enerji', calorieText, color: trendyolOrange),
          if (meatOrigin.isNotEmpty)
            _complianceLine('Et menşei', meatOrigin, color: Colors.blue),
          if (warnings.isNotEmpty)
            _complianceLine('Beslenme uyarıları', warnings.join('\n'),
                color: const Color(0xFFAF52DE)),
          const SizedBox(height: 8),
          Text(
            'Bu bilgiler işletme beyanı ve Pazarcık Portal öneri sistemiyle oluşturulmuştur. Alerjik hassasiyetiniz varsa işletmeyle teyit ediniz.',
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.black45, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationCard(Map<String, dynamic> data) {
    final removable = _asStringList(data['removableIngredients']);
    final addable = _asStringList(data['addableIngredients']);
    if (removable.isEmpty && addable.isEmpty) return const SizedBox.shrink();

    final baseCalories = _calorieAverage(data['calorieText']);
    final calorieValues = _asIntMap(data['addableIngredientCalories']);
    final extraCalories = addedIngredients.fold<int>(
      0,
      (total, ingredient) => total + (calorieValues[ingredient] ?? 0),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.slider_horizontal_3,
                  color: trendyolOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Siparişini kişiselleştir',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (baseCalories != null)
                Text(
                  '≈ ${baseCalories + extraCalories} kcal',
                  style: GoogleFonts.inter(
                    color: trendyolOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (removable.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('İçinden çıkar',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: removable.map((ingredient) {
                final selected = removedIngredients.contains(ingredient);
                return FilterChip(
                  selected: selected,
                  label: Text(ingredient),
                  avatar: Icon(
                    selected
                        ? CupertinoIcons.minus_circle_fill
                        : CupertinoIcons.minus_circle,
                    size: 17,
                  ),
                  onSelected: (enabled) => setState(() {
                    enabled
                        ? removedIngredients.add(ingredient)
                        : removedIngredients.remove(ingredient);
                  }),
                );
              }).toList(),
            ),
          ],
          if (addable.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Ekstra ekle',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: addable.map((ingredient) {
                final selected = addedIngredients.contains(ingredient);
                final calories = calorieValues[ingredient] ?? 0;
                return FilterChip(
                  selected: selected,
                  label: Text(calories > 0
                      ? '$ingredient (+$calories kcal)'
                      : ingredient),
                  avatar: Icon(
                    selected
                        ? CupertinoIcons.plus_circle_fill
                        : CupertinoIcons.plus_circle,
                    size: 17,
                  ),
                  onSelected: (enabled) => setState(() {
                    enabled
                        ? addedIngredients.add(ingredient)
                        : addedIngredients.remove(ingredient);
                  }),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _complianceLine(String title, String body, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: color ?? Colors.black45,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.black87, height: 1.35),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        color: color ?? Colors.black87),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainQuantitySelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration:
          BoxDecoration(color: iosBg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Ürün Adedi",
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          Row(
            children: [
              _qtyBtn(CupertinoIcons.minus, () {
                if (quantity > 1) setState(() => quantity--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text("$quantity",
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              _qtyBtn(CupertinoIcons.plus, () => setState(() => quantity++)),
            ],
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              // ignore: deprecated_member_use
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
            ]),
        child: Icon(icon, size: 18, color: trendyolOrange),
      ),
    );
  }

  Widget _buildExtrasSection(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(vendorId)
          .collection('extras')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox();
        var extras = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Yanında İyi Gider"),
            const SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: extras.length,
              itemBuilder: (context, index) {
                var extra = extras[index];
                final extraData = extra.data() as Map<String, dynamic>? ?? {};
                String eId = extra.id;
                double ePrice = _asDouble(extraData['price']);
                String eName = _pickString(extraData, ['name', 'title'],
                    fallback: 'Ekstra');
                String eImage = _pickString(
                  extraData,
                  ['imageUrl', 'image', 'productImage', 'photoUrl'],
                  fallback: '',
                );
                int currentQty = selectedExtras[eId] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: currentQty > 0
                        // ignore: deprecated_member_use
                        ? trendyolOrange.withOpacity(0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: currentQty > 0 ? trendyolOrange : iosBg,
                        width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.add_circled,
                          color: trendyolOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(eName,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                            Text("+₺${ePrice.toStringAsFixed(2)}",
                                style: GoogleFonts.inter(
                                    color: trendyolOrange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (currentQty > 0)
                            _qtyBtn(CupertinoIcons.minus, () {
                              setState(() {
                                final nextQty = currentQty - 1;
                                if (nextQty <= 0) {
                                  selectedExtras.remove(eId);
                                  selectedExtraDrafts.remove(eId);
                                } else {
                                  selectedExtras[eId] = nextQty;
                                }
                                extrasTotalPrice -= ePrice;
                              });
                            }),
                          if (currentQty > 0)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text("$currentQty",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800)),
                            ),
                          _qtyBtn(CupertinoIcons.plus, () {
                            setState(() {
                              selectedExtras[eId] = currentQty + 1;
                              selectedExtraDrafts[eId] = _ExtraCartDraft(
                                id: eId,
                                name: eName,
                                price: ePrice,
                                imageUrl: eImage,
                              );
                              extrasTotalPrice += ePrice;
                            });
                          }),
                        ],
                      )
                    ],
                  ),
                );
              },
            )
          ],
        );
      },
    );
  }

  Widget _buildStoreCard() {
    final storeData = store?.data() as Map<String, dynamic>? ?? {};
    final productData = widget.product.data() as Map<String, dynamic>? ?? {};
    final storeName = _pickString(
      storeData,
      [
        'storeName',
        'businessName',
        'restaurantName',
        'fullname',
        'fullName',
        'name'
      ],
      fallback: _pickString(
        productData,
        ['storeName', 'businessName', 'restaurantName', 'sellerName'],
        fallback: 'Pazarcik Esnafi',
      ),
    );

    return GestureDetector(
      onTap: () {
        if (store != null && (store?.exists ?? false))
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => StoreDetails(store: store)));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: iosBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const CircleAvatar(
                backgroundColor: trendyolOrange,
                child: Icon(Icons.storefront, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Satan Esnaf",
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(storeName,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(String url, String id) {
    return SliverAppBar(
      expandedHeight: MediaQuery.sizeOf(context).width > 700 ? 300 : 350,
      pinned: true,
      backgroundColor: trendyolOrange,
      elevation: 0,
      leading: IconButton(
        icon: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(CupertinoIcons.back, color: Colors.black, size: 20)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                  isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: Colors.red)),
          onPressed: toggleIsFav,
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: id,
          child: PortalNetworkImage(url: url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildBottomBar(double total, VoidCallback onAdd, bool storeOpen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5))
      ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Toplam Tutar",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("₺${total.toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: trendyolOrange)),
            ],
          ),
          SizedBox(
            height: 55,
            width: 170,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: trendyolOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0),
              onPressed: storeOpen ? onAdd : null,
              icon: const Icon(CupertinoIcons.cart_badge_plus,
                  color: Colors.white),
              label: Text(storeOpen ? "SEPETE EKLE" : "RESTORAN KAPALI",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          )
        ],
      ),
    );
  }
}
