// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart.dart';
import '../../../models/cart.dart';

// Trendyol/iOS Tarzı Renk Paleti
const Color trendyolOrange = Color(0xFFF27A1A);
const Color iosBg = Color(0xFFF2F2F7);

class MyOrdersScreen extends StatelessWidget {
  static const String routeName = 'my-orders';
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Siparişlerim',
          style: GoogleFonts.inter(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: const CupertinoNavigationBarBackButton(color: trendyolOrange),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: userId)
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError();
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          final active = docs
              .where((d) => !['Teslim Edildi', 'İptal Edildi']
                  .contains((d.data() as Map)['status']))
              .toList();
          final past = docs
              .where((d) => ['Teslim Edildi', 'İptal Edildi']
                  .contains((d.data() as Map)['status']))
              .toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (active.isNotEmpty) ...[
                _sliverHeader('Aktif Siparişler'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _buildOrderCard(context, active[i], isActive: true),
                      childCount: active.length,
                    ),
                  ),
                ),
              ],
              if (past.isNotEmpty) ...[
                _sliverHeader('Geçmiş Siparişler'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _buildOrderCard(context, past[i], isActive: false),
                      childCount: past.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sliverHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(
          title,
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, DocumentSnapshot doc,
      {required bool isActive}) {
    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? 'Onay Bekliyor') as String;
    final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
    final storeName = (data['storeName'] ??
            data['restaurantName'] ??
            'Restoran')
        .toString();
    final items = (data['items'] as List?) ?? [];
    final statusColor = _getStatusColor(status);

    String formattedDate = '';
    if (data['orderDate'] != null) {
      final dt = (data['orderDate'] as Timestamp).toDate();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        formattedDate =
            'Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return GestureDetector(
      onTap: () {
        if (isActive) {
          Navigator.pushNamed(context, 'order-tracking',
              arguments: doc.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? statusColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Durum ikonu
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_getStatusIcon(status),
                        color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${items.length} ürün  •  $formattedDate',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₺${totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: trendyolOrange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Durum Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                    if (isActive) ...[
                      Text(
                        'Takip Et',
                        style: GoogleFonts.inter(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_right,
                          color: statusColor, size: 13),
                    ],
                  ],
                ),
              ),
              // Sipariş içerik özeti
              if (items.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  items
                      .take(3)
                      .map((e) =>
                          '${e['quantity'] ?? 1}× ${e['prodName'] ?? e['name'] ?? ''}')
                      .join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500),
                ),
              ],
              // FIX: Tekrar Sipariş Özelliği (Item 11)
              if (!isActive && items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _reorder(context, items),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: trendyolOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: trendyolOrange.withOpacity(0.35), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.arrow_2_circlepath, size: 14, color: trendyolOrange),
                          const SizedBox(width: 6),
                          Text(
                            'Tekrar Sipariş Ver',
                            style: GoogleFonts.inter(
                              color: trendyolOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // FIX: Tekrar sipariş aksiyonu (Item 11)
  void _reorder(BuildContext context, List items) {
    if (items.isEmpty) return;
    final cartProvider = Provider.of<CartData>(context, listen: false);
    int addedCount = 0;
    for (final raw in items) {
      try {
        final itemMap = Map<String, dynamic>.from(raw as Map);
        final cartItem = CartItem.fromJson(itemMap);
        cartProvider.addToCart(cartItem);
        addedCount++;
      } catch (e) {
        debugPrint('Tekrar sipariş öğe ekleme hatası: $e');
      }
    }

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedCount ürün sepetinize eklendi! 🛒'),
          backgroundColor: trendyolOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          action: SnackBarAction(
            label: 'Sepete Git',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, 'cart');
            },
          ),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'Onay Bekliyor') return const Color(0xFFF39C12);
    if (status == 'Sipariş Onaylandı') return const Color(0xFF2ECC71);
    if (status == 'Hazırlanıyor') return const Color(0xFF3498DB);
    if (status == 'Yolda') return const Color(0xFF9B59B6);
    if (status == 'Teslim Edildi') return const Color(0xFF27AE60);
    if (status == 'İptal Edildi') return const Color(0xFFE74C3C);
    return trendyolOrange;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'Onay Bekliyor') return CupertinoIcons.clock_fill;
    if (status == 'Sipariş Onaylandı') return CupertinoIcons.checkmark_circle_fill;
    if (status == 'Hazırlanıyor') return Icons.restaurant_rounded;
    if (status == 'Yolda') return Icons.delivery_dining_rounded;
    if (status == 'Teslim Edildi') return CupertinoIcons.checkmark_seal_fill;
    if (status == 'İptal Edildi') return CupertinoIcons.xmark_circle_fill;
    return CupertinoIcons.bag;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  trendyolOrange.withOpacity(0.08),
                  trendyolOrange.withOpacity(0.04),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.bag,
                size: 52, color: trendyolOrange),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz siparişiniz yok',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Pazarcık Portal\'da lezzet dolu\nbir yolculuğa başla!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.grey.shade500, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Siparişler yüklenemedi',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: Colors.black87)),
        ],
      ),
    );
  }
}
