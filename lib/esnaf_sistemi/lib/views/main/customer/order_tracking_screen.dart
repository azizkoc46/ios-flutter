import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Trendyol Turuncusu & iOS Teması
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class OrderTrackingScreen extends StatelessWidget {
  static const String routeName = 'order-tracking';
  final String orderId;

  const OrderTrackingScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        title: Text("Sipariş Takibi",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // 🔥 StreamBuilder sayesinde esnaf durumu değiştirdiği an ekran anlık güncellenir.
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Bir hata oluştu"));

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String status = data['status'] ?? "Onay Bekliyor";

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 25),
                // --- ÜST GÖRSEL VE DURUM ---
                _buildHeaderStatus(status),
                const SizedBox(height: 30),

                // --- MODERN TİMELİNE (DİKEY STEPPER) ---
                _buildModernTimeline(status),

                const SizedBox(height: 30),
                // --- SİPARİŞ DETAY KARTI ---
                _buildOrderDetailsCard(data, orderId),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderStatus(String status) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: trendyolOrange.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5)
            ],
          ),
          child: Icon(_getStatusIcon(status), size: 70, color: trendyolOrange),
        ),
        const SizedBox(height: 20),
        Text(status,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _getStatusDescription(status),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTimeline(String status) {
    // Aşamalar: 0: Onay Bekliyor, 1: Hazırlanıyor, 2: Yolda, 3: Teslim Edildi
    int currentStage = 0;
    if (status.contains("Hazırlanıyor")) currentStage = 1;
    if (status.contains("Yolda")) currentStage = 2;
    if (status.contains("Teslim")) currentStage = 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          _timelineStep("Sipariş Alındı", "Esnaf siparişinizi onayladı",
              currentStage >= 0, currentStage == 0),
          _timelineLine(currentStage >= 1),
          _timelineStep("Hazırlanıyor", "Lezzetleriniz özenle hazırlanıyor",
              currentStage >= 1, currentStage == 1),
          _timelineLine(currentStage >= 2),
          _timelineStep("Kurye Yolda", "Siparişiniz adrese doğru yola çıktı",
              currentStage >= 2, currentStage == 2),
          _timelineLine(currentStage >= 3),
          _timelineStep("Teslim Edildi", "Afiyet olsun!", currentStage >= 3,
              currentStage == 3),
        ],
      ),
    );
  }

  Widget _timelineStep(String title, String desc, bool isDone, bool isActive) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone ? trendyolOrange : Colors.grey[200],
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: trendyolOrange.withOpacity(0.3), width: 6)
                : null,
          ),
          child: isDone
              ? const Icon(CupertinoIcons.checkmark_alt,
                  size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive
                          ? Colors.black
                          : (isDone ? Colors.black87 : Colors.grey))),
              Text(desc,
                  style:
                      GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        )
      ],
    );
  }

  Widget _timelineLine(bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 13, top: 4, bottom: 4),
      height: 25,
      width: 2.5,
      decoration: BoxDecoration(
        color: isActive ? trendyolOrange : Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildOrderDetailsCard(Map<String, dynamic> data, String id) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Sipariş Detayları",
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 15),
          _infoRow(CupertinoIcons.number, "Sipariş No",
              "#${id.substring(0, 8).toUpperCase()}"),
          const Divider(height: 30, thickness: 0.5),
          _infoRow(CupertinoIcons.location, "Teslimat Adresi",
              data['deliveryAddress'] ?? "Adres Bilgisi Yok"),
          const Divider(height: 30, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Toplam Tutar",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.grey[600])),
              Text("₺${(data['totalAmount'] ?? 0.0).toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: trendyolOrange)),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    if (status.contains("Hazırlanıyor")) return Icons.restaurant_rounded;
    if (status.contains("Yolda")) return Icons.delivery_dining_rounded;
    if (status.contains("Teslim")) return CupertinoIcons.checkmark_circle_fill;
    return CupertinoIcons.time;
  }

  String _getStatusDescription(String status) {
    if (status.contains("Hazırlanıyor"))
      return "Esnafımız ürünlerinizi hazırlıyor.";
    if (status.contains("Yolda"))
      return "Kuryemiz siparişinizi kapınıza getiriyor.";
    if (status.contains("Teslim"))
      return "Siparişiniz teslim edildi. Afiyet olsun!";
    return "Esnafın siparişi onaylaması bekleniyor.";
  }
}
