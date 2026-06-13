// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccountBalanceScreen extends StatefulWidget {
  static const routeName = '/account_balance';
  const AccountBalanceScreen({Key? key}) : super(key: key);

  @override
  State<AccountBalanceScreen> createState() => _AccountBalanceScreenState();
}

class _AccountBalanceScreenState extends State<AccountBalanceScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  String _selectedPeriod = "Bugün"; // Bugün, Bu Hafta, Bu Ay

  // Filtreye göre başlangıç tarihini al
  DateTime _getStartDate() {
    DateTime now = DateTime.now();
    if (_selectedPeriod == "Bugün")
      return DateTime(now.year, now.month, now.day);
    if (_selectedPeriod == "Bu Hafta")
      return now.subtract(const Duration(days: 7));
    return DateTime(now.year, now.month, 1); // Bu Ay başı
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text("Kasa ve Kazanç",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. ARKA PLAN
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage('assets/images/bg.jpg'),
                    fit: BoxFit.cover)),
          ),
          BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(0.7))),

          // 2. İÇERİK
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('sellerId', isEqualTo: userId)
                  .where('status', isEqualTo: 'Teslim Edildi')
                  .where('orderDate', isGreaterThanOrEqualTo: _getStartDate())
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                      child: Text("Veri yüklenemedi",
                          style: TextStyle(color: Colors.white)));
                if (!snapshot.hasData)
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.greenAccent));

                // Finansal Verileri Hesapla
                double currentCiro = 0;
                var docs = snapshot.data!.docs;
                for (var doc in docs) {
                  currentCiro += (doc['totalAmount'] ?? 0.0).toDouble();
                }

                return Column(
                  children: [
                    // 📅 DÖNEM SEÇİCİ (Filtre)
                    _buildPeriodSelector(),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // 🔥 ANA KASA KARTI 🔥
                            _buildMainBalanceCard(currentCiro, docs.length),

                            const SizedBox(height: 25),

                            // 🏦 ÖDEME YÖNTEMİ HATIRLATICI
                            _buildInfoTile(),

                            const SizedBox(height: 30),

                            // 📑 SON KAZANÇLAR (Liste)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Son Başarılı Teslimatlar",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 15),

                            if (docs.isEmpty)
                              _buildEmptyState()
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length > 10
                                    ? 10
                                    : docs.length, // Son 10 işlemi göster
                                itemBuilder: (context, index) {
                                  var order = docs[index].data()
                                      as Map<String, dynamic>;
                                  return _buildTransactionItem(order);
                                },
                              ),
                            const SizedBox(height: 50),
                          ],
                        ),
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

  Widget _buildPeriodSelector() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: ["Bugün", "Bu Hafta", "Bu Ay"].map((p) {
          bool isSelected = _selectedPeriod == p;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = p),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.greenAccent : Colors.white10,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(p,
                  style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainBalanceCard(double amount, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.greenAccent.withOpacity(0.05), blurRadius: 30)
        ],
      ),
      child: Column(
        children: [
          Text("$_selectedPeriod Toplam Kazanç",
              style: const TextStyle(color: Colors.white60, fontSize: 16)),
          const SizedBox(height: 10),
          Text("₺${amount.toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Text("$count Sipariş Tamamlandı",
                  style: const TextStyle(
                      color: Colors.greenAccent, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.15))),
      child: const Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: Colors.blueAccent, size: 30),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "Bu ekrandaki tutarlar 'Teslim Edildi' olarak işaretlediğiniz siparişlerin toplamıdır. Ödemeler kapıda doğrudan size yapılmaktadır.",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> order) {
    DateTime date = (order['orderDate'] as Timestamp).toDate();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order['customerName'] ?? "Müşteri",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(DateFormat('dd MMM, HH:mm').format(date),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Text("+ ₺${(order['totalAmount'] ?? 0).toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 30),
        child: Text("Seçilen dönemde henüz bir kazanç bulunmuyor.",
            style: TextStyle(color: Colors.white30)),
      ),
    );
  }
}
