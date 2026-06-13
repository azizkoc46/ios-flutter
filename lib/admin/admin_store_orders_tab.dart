// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminStoreOrdersTab extends StatefulWidget {
  const AdminStoreOrdersTab({Key? key}) : super(key: key);

  @override
  State<AdminStoreOrdersTab> createState() => _AdminStoreOrdersTabState();
}

class _AdminStoreOrdersTabState extends State<AdminStoreOrdersTab> {
  static const List<String> possibleCollections = [
    'orders',
    'store_orders',
    'food_orders',
  ];

  String _collection = 'orders';
  String _statusFilter = 'all';

  final Map<String, String> _statuses = const {
    'all': 'Hepsi',
    'pending': 'Yeni / Bekliyor',
    'accepted': 'Onaylandı',
    'preparing': 'Hazırlanıyor',
    'delivering': 'Yolda',
    'completed': 'Tamamlandı',
    'cancelled': 'İptal',
  };

  Future<void> _updateOrder(String docId, String status) async {
    await FirebaseFirestore.instance.collection(_collection).doc(docId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showOrderActions(String docId, Map<String, dynamic> data) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Sipariş Durumunu Güncelle"),
        actions: _statuses.entries
            .where((e) => e.key != 'all')
            .map(
              (e) => CupertinoActionSheetAction(
                isDestructiveAction: e.key == 'cancelled',
                child: Text(e.value),
                onPressed: () {
                  Navigator.pop(context);
                  _updateOrder(docId, e.key);
                },
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text("İptal"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sorguyu oluştur
    Query query = FirebaseFirestore.instance.collection(_collection);

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    // EN GÜNCEL SİPARİŞLERİ EN ÜSTTE GÖSTERMEK İÇİN SIRALAMA
    query = query.orderBy('createdAt', descending: true).limit(300);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Üst Seçenekler (Koleksiyon Seçimi) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: DropdownButtonFormField<String>(
              value: _collection,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: "Aktif Sipariş Koleksiyonu",
                prefixIcon: const Icon(CupertinoIcons.cube_box,
                    color: Color(0xFF6366F1)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: possibleCollections
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c,
                          style: const TextStyle(fontWeight: FontWeight.bold))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _collection = v);
              },
            ),
          ),

          // ── Durum Filtreleri (Yatay Kaydırmalı Butonlar) ─────────────────
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: _statuses.entries.map((e) {
                final selected = _statusFilter == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _statusFilter = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6366F1) : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Center(
                      child: Text(e.value,
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Siparişler Listesi ve İstatistikler ─────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Hata: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red)));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;

                // Dinamik İstatistik Hesaplama
                double totalRevenue = 0;
                int completedCount = 0;
                int pendingCount = 0;

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';

                  // Fiyatı güvenli bir şekilde çek ve topla
                  final priceRaw = data['total'] ??
                      data['totalPrice'] ??
                      data['amount'] ??
                      0;
                  final double price =
                      double.tryParse(priceRaw.toString()) ?? 0.0;

                  if (status == 'completed') {
                    completedCount++;
                    totalRevenue += price;
                  } else if (status == 'pending' ||
                      status == 'preparing' ||
                      status == 'accepted') {
                    pendingCount++;
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // İstatistik Kartları
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          children: [
                            _statBox("Toplam\nSipariş", "${docs.length}",
                                CupertinoIcons.cart_fill, Colors.blue),
                            const SizedBox(width: 10),
                            _statBox("Bekleyen\nİşlem", "$pendingCount",
                                CupertinoIcons.clock_fill, Colors.orange),
                            const SizedBox(width: 10),
                            // Eğer 'Hepsi' veya 'Tamamlandı' filtresindeysek Toplam Ciroyu gösterelim
                            _statBox(
                                "Ciro\n(Tamamlanan)",
                                "₺${totalRevenue.toStringAsFixed(0)}",
                                CupertinoIcons.money_dollar_circle_fill,
                                Colors.green),
                          ],
                        ),
                      ),
                    ),

                    // Liste Durumu (Boşsa veya Doluysa)
                    if (docs.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.bag_badge_minus,
                                  size: 50, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              const Text("Sipariş bulunamadı.",
                                  style: TextStyle(color: Colors.black45)),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _orderCard(doc.id, data);
                          },
                          childCount: docs.length,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Üst Kısımdaki Renkli İstatistik Kutuları
  Widget _statBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // Sipariş Kartı Tasarımı
  Widget _orderCard(String docId, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString();
    final customerName = (data['customerName'] ??
            data['userName'] ??
            data['name'] ??
            'Bilinmeyen Müşteri')
        .toString();
    final storeName = (data['storeName'] ??
            data['businessName'] ??
            data['restaurantName'] ??
            data['sellerName'] ??
            'Bilinmeyen Restoran/Mağaza')
        .toString();
    final totalRaw = data['total'] ?? data['totalPrice'] ?? data['amount'] ?? 0;
    final address =
        (data['address'] ?? data['deliveryAddress'] ?? '').toString();

    // Tarih ve Saati Çekme
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? '${ts.toDate().day.toString().padLeft(2, '0')}.${ts.toDate().month.toString().padLeft(2, '0')} - ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : 'Tarih Yok';

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: Restoran Adı ve Durum
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(
                    bottom: BorderSide(color: Colors.black.withOpacity(0.04)))),
            child: Row(
              children: [
                const Icon(CupertinoIcons.building_2_fill,
                    size: 18, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                _badge(_statuses[status] ?? status, _statusColor(status)),
              ],
            ),
          ),

          // Alt Kısım: Müşteri, Tutar ve Aksiyon
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.person_fill,
                              size: 14, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ],
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(CupertinoIcons.location_solid,
                                size: 14, color: Colors.black45),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.time,
                              size: 14, color: Colors.black45),
                          const SizedBox(width: 6),
                          Text(dateStr,
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Fiyat ve Düzenle Butonu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("$totalRaw TL",
                        style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _showOrderActions(docId, data),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text("Güncelle",
                          style: TextStyle(fontSize: 12)),
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'preparing':
      case 'accepted':
      case 'delivering':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}
