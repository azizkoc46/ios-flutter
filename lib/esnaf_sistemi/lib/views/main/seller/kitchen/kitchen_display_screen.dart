// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

/// Mutfak Ekranı (Kitchen Display System - KDS)
/// Restoran mutfakları ve şefler için özel tasarlanmış, büyük puntolu,
/// canlı akan sipariş hazırlık ekranı.
class KitchenDisplayScreen extends StatefulWidget {
  final String sellerId;
  const KitchenDisplayScreen({Key? key, required this.sellerId})
      : super(key: key);

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  // Canlı sayaç için timer yenilemesi
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Her 30 saniyede süreleri yenile
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      setState(() => _currentTime = DateTime.now());
      return true;
    });
  }

  Future<void> _advanceOrderStatus(
      String orderId, String currentStatus, String customerId) async {
    String nextStatus = 'Hazırlanıyor';
    if (currentStatus == 'Hazırlanıyor') {
      nextStatus = 'Yolda';
    }

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': nextStatus,
        'kitchenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Müşteriye bildirim kuyruğu
      if (customerId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('customer_order_push_requests')
            .add({
          'targetUid': customerId,
          'orderId': orderId,
          'status': nextStatus,
          'title': nextStatus == 'Hazırlanıyor'
              ? 'Yemeğiniz Hazırlanıyor 🍳'
              : 'Yemeğiniz Hazır, Yola Çıktı! 🛵',
          'body': nextStatus == 'Hazırlanıyor'
              ? 'Şefimiz siparişinizi hazırlamaya başladı.'
              : 'Siparişiniz kuryeye teslim edildi.',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  int _minutesElapsed(dynamic timestamp) {
    if (timestamp == null) return 0;
    try {
      final dt = (timestamp as Timestamp).toDate();
      return _currentTime.difference(dt).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  Color _timerColor(int minutes) {
    if (minutes < 15) return const Color(0xFF2ECC71); // Yeşil
    if (minutes < 25) return const Color(0xFFF39C12); // Turuncu
    return const Color(0xFFE74C3C); // Kırmızı (Gecikme)
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: widget.sellerId)
        .where('status', whereIn: ['Sipariş Onaylandı', 'Hazırlanıyor'])
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF28293D),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.soup_kitchen_rounded,
                  color: Color(0xFFFF6B35), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mutfak Ekranı (KDS)',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Canlı Hazırlık Listesi',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF383854),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    intl.DateFormat('HH:mm').format(_currentTime),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Bir hata oluştu: ${snapshot.error}',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(
                radius: 18,
                color: Color(0xFFFF6B35),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF2ECC71),
                      size: 54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Hazırlanacak Sipariş Yok! 👨‍🍳',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tüm siparişler hazırlandı veya kuryeye verildi.',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 440,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildKitchenCard(doc);
            },
          );
        },
      ),
    );
  }

  Widget _buildKitchenCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? 'Sipariş Onaylandı') as String;
    final customerName = (data['customerName'] ?? 'Müşteri') as String;
    final customerId = (data['customerId'] ?? '') as String;
    final items = (data['items'] as List?) ?? [];
    final note = (data['orderNote'] ?? data['note'] ?? '').toString().trim();
    final elapsedMinutes = _minutesElapsed(data['orderDate']);
    final timerColor = _timerColor(elapsedMinutes);

    final isCooking = status == 'Hazırlanıyor';
    final actionBtnColor =
        isCooking ? const Color(0xFF2ECC71) : const Color(0xFFFF6B35);
    final actionBtnText =
        isCooking ? 'HAZIR / KURYEYE VER 🛵' : 'HAZIRLAMAYA BAŞLA 🍳';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF28293D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCooking
              ? const Color(0xFFFF6B35).withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kart Başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF32344D),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: GoogleFonts.inter(
                          color: isCooking
                              ? const Color(0xFFFF9F43)
                              : const Color(0xFF2ECC71),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Süre Rozeti
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: timerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: timerColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.timer, color: timerColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$elapsedMinutes dk',
                        style: GoogleFonts.inter(
                          color: timerColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Müşteri Notu Varsa
          if (note.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFE74C3C).withOpacity(0.25),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFF6B6B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NOT: $note',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF8E8E),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Ürünler Listesi (Kaydırılabilir ve Büyük Puntolu)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withOpacity(0.06), height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final qty = item['quantity'] ?? 1;
                final name = item['prodName'] ?? item['name'] ?? 'Ürün';
                final removed = (item['removedIngredients'] as List?) ?? [];
                final added = (item['addedIngredients'] as List?) ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${qty}x',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name.toString(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (removed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 38, top: 3),
                        child: Text(
                          'Çıkar: ${removed.join(', ')}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF7675),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (added.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 38, top: 2),
                        child: Text(
                          'Ekle: ${added.join(', ')}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF55EFC4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Durum İlerleme Butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionBtnColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () =>
                    _advanceOrderStatus(doc.id, status, customerId),
                child: Text(
                  actionBtnText,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
