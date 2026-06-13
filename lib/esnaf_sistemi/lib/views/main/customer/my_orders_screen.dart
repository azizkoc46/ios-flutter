import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_tracking_screen.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için ekle: flutter pub add intl

// Trendyol/iOS Tarzı Renk Paleti
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class MyOrdersScreen extends StatelessWidget {
  static const String routeName = 'my-orders';
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
          // ... AppBar kodun aynı kalabilir
          ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: userId)
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(
                child: Text("Siparişler yüklenirken bir hata oluştu."));

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var order = snapshot.data!.docs[index];

              // Veri güvenliği için varsayılan değerler
              Map<String, dynamic> data = order.data() as Map<String, dynamic>;
              String status = data['status'] ?? "Onay Bekliyor";
              double totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

              // Tarih formatlama
              String formattedDate = "";
              if (data['orderDate'] != null) {
                DateTime dt = (data['orderDate'] as Timestamp).toDate();
                formattedDate = DateFormat('dd MMM, HH:mm', 'tr_TR').format(dt);
              }

              return _buildOrderCard(
                  context, order.id, status, totalAmount, formattedDate);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String orderId, String status,
      double amount, String date) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(orderId: orderId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Durum İkonu (Buradaki ikon ve renk mantığın çok iyi, aynen devam)
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_getStatusIcon(status),
                    color: _getStatusColor(status), size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Sipariş #${orderId.substring(0, 6).toUpperCase()}",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Text(
                          date,
                          style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Durum Etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "₺${amount.toStringAsFixed(2)}",
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: trendyolOrange),
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

  // Duruma göre renk belirleme
  Color _getStatusColor(String status) {
    if (status.contains("Onay") || status.contains("Bekliyor"))
      return Colors.blueAccent;
    if (status.contains("Hazırlanıyor")) return Colors.orange;
    if (status.contains("Yolda")) return Color(0xFF8E24AA); // Purple
    if (status.contains("Teslim")) return Colors.green;
    if (status.contains("İptal")) return Colors.red;
    return trendyolOrange;
  }

  // Duruma göre ikon belirleme
  IconData _getStatusIcon(String status) {
    if (status.contains("Onay") || status.contains("Bekliyor"))
      return CupertinoIcons.time;
    if (status.contains("Hazırlanıyor")) return Icons.restaurant_menu_rounded;
    if (status.contains("Yolda"))
      return CupertinoIcons.gauge; // Hız/Motor hissi
    if (status.contains("Teslim")) return CupertinoIcons.check_mark_circled;
    return CupertinoIcons.bag_badge_minus;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration:
                BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.square_list,
                size: 80, color: Colors.grey[300]),
          ),
          const SizedBox(height: 25),
          Text(
            "Henüz siparişiniz yok",
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Text(
            "Pazarcık Portal'da lezzet dolu bir yolculuğa başla!",
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
