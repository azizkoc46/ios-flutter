// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatisticsScreen extends StatefulWidget {
  static const routeName = '/statistics';
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  String _selectedFilter = "Haftalık";

  // Filtre tarihini hesapla
  DateTime _getStartDate() {
    DateTime now = DateTime.now();
    if (_selectedFilter == "Bugün")
      return DateTime(now.year, now.month, now.day);
    if (_selectedFilter == "Haftalık")
      return now.subtract(const Duration(days: 7));
    return now.subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS Gri Arka Plan
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Text("Performans Analizi",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTimeFilter(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 🔥 KRİTİK DÜZELTME: Sadece bu satıcının (userId) siparişlerini çekiyoruz
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('sellerId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return _errorWidget(snapshot.error.toString());
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  double totalRevenue = 0;
                  int deliveredCount = 0;
                  int canceledCount = 0;
                  Map<String, int> productSales = {};
                  DateTime filterDate = _getStartDate();

                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;

                    // Tarih Kontrolü
                    Timestamp? orderTimestamp = data['orderDate'] as Timestamp?;
                    if (orderTimestamp == null) continue;
                    DateTime orderDate = orderTimestamp.toDate();

                    // Sadece seçili tarih aralığındakileri işle
                    if (orderDate.isBefore(filterDate)) continue;

                    String status = data['status'] ?? "";

                    if (status == "Teslim Edildi") {
                      totalRevenue += (data['totalAmount'] ?? 0).toDouble();
                      deliveredCount++;
                    } else if (status == "İptal Edildi") {
                      canceledCount++;
                    }

                    var items = data['items'] as List<dynamic>? ?? [];
                    for (var item in items) {
                      String pName = item['prodName'] ?? "Bilinmeyen";
                      int qty = item['quantity'] ?? 0;
                      productSales[pName] = (productSales[pName] ?? 0) + qty;
                    }
                  }

                  var sortedProducts = productSales.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  var top3 = sortedProducts.take(3).toList();

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildRevenueCard(totalRevenue,
                            deliveredCount + canceledCount, isTablet),
                        const SizedBox(height: 20),
                        _buildOrderStats(deliveredCount, canceledCount,
                            deliveredCount + canceledCount),
                        const SizedBox(height: 30),
                        _sectionTitle("En Çok Satanlar"),
                        const SizedBox(height: 15),
                        if (top3.isEmpty)
                          _noDataWidget()
                        else
                          ...top3.map((p) => _buildTopProductItem(
                              p.key,
                              "${p.value} Adet",
                              (p.value /
                                  (top3.first.value == 0
                                      ? 1
                                      : top3.first.value)))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BİLEŞENLERİ (iOS Style) ---

  Widget _buildTimeFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ["Bugün", "Haftalık", "Aylık"].map((filter) {
          bool isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(filter,
                  style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueCard(double revenue, int total, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          const Text("Tahmini Kazanç",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          FittedBox(
            child: Text("₺${revenue.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isTablet ? 42 : 36,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Text("$total İşlem Yapıldı",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  Widget _buildOrderStats(int delivered, int canceled, int total) {
    double successRate = total == 0 ? 0 : delivered / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // ignore: duplicate_ignore
          // ignore: deprecated_member_use
          border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                  "Tamamlanan", delivered.toString(), const Color(0xFF34C759)),
              Container(height: 30, width: 1, color: Colors.black12),
              _statItem("İptal", canceled.toString(), const Color(0xFFFF3B30)),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: successRate,
              minHeight: 8,
              backgroundColor: const Color(0xFFF2F2F7),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
            ),
          ),
          const SizedBox(height: 8),
          Text("Başarı Oranı: %${(successRate * 100).toStringAsFixed(0)}",
              style: GoogleFonts.inter(
                  color: Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                color: color, fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildTopProductItem(String name, String count, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              Text(count,
                  style: const TextStyle(
                      color: Color(0xFF007AFF), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(10))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                height: 6,
                width: (MediaQuery.of(context).size.width - 72) * progress,
                decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title,
          style: GoogleFonts.inter(
              color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Widget _noDataWidget() {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Text("Bu dönemde satış verisi yok.",
          style: TextStyle(color: Colors.black38, fontSize: 13)),
    );
  }

  Widget _errorWidget(String err) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text("Hata: $err",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent)),
    ));
  }
}
