// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  late TabController _tabController;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<String> activeStatuses = [
    'Onay Bekliyor',
    'Sipariş Onaylandı',
    'Hazırlanıyor',
    'Yolda'
  ];
  final List<String> pastStatuses = ['Teslim Edildi', 'İptal Edildi'];

  // --- V1 API İÇİN GEREKLİ KİMLİK BİLGİLERİ ---
  final String _projectId = "pazarcik-portal-7faf2";
  final String _clientEmail =
      "firebase-adminsdk-fbsvc@pazarcik-portal-7faf2.iam.gserviceaccount.com";
  final String _privateKey = """-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDUtDfjJc/C+VFo
YtkTTH/7bHTsCQ/C+jTUE8b9PR+eXcbovD+iOmErimey9XowE6wJ9nAukipHEPlH
R1Opg0nrlauMOcKnC2bGtQWoVCPsIJLYYRxqQZ/o8+N7ZjxvUno9499XH7FhhYln
uBkTxmX2SpJAu8tAWXnoqfB2PQLhB8wzZyZsCAbKPj1mKef+WbUV53qHrbndYmn3
HiIVMDvZZ/jzAXRQ1oM3mOd7wiURuHfHUG85dkYlofvZaBImP62qN80vM1t74RA+
xdabu7VCY8GVaJh5FgHmDwL10caJlpUZTN54GzZfOUGgfWhzzIm+HZwL1gs67cke
YsFzyyqDAgMBAAECggEAWBw/emzTX6T/wAoSehgafAA1fwFR8ibLc36t04Fac7PN
DePNSFp+nha7Vjqx3vCHN6lKV0BdGwtA9/HoCjREjr51TaUvqRrj/DRIn64bI1lq
+w9fQfTlVQ6SkS+MoWC9Gp4mimSqigdTIA/282YgHqJNa1tfmsx135dl8NTdOHHM
6Dycfz3rtZO9p7dIbFLULHscq28Lc7kipHrfj1YHpoZ1gCtXsxTvcNUMyvIOInti
Q1VDosF1WUiOnfKSlKGFaXnL0QBfE+05YPi8pz0IgZUmM7daKrLeT7jY5bQO+KwS
zQLM05P4NGiYYFM7JggLWuJpidL0zAT+8BHGDV9VYQKBgQD1M4UK1SoewBwPrh4A
mAiIbud0jnKBXnx2qyBo0Uy1W612oouySdxJqBAzT59nSRP0rbCRJx95GbYD9HdL
3/pyY2/IRrnt64tN2j5XUY0P++GoN4UdeisSUL4Fakjw8m5qhoqButk9lYKA40IO
plcWM7vebDEjLhmiZlRxdRsiXwKBgQDeElBHTqZH0DO5qYQJw/sYNw5r1DtE12tq
jLPx0rddotMGuLUz6pGkveyH9zBZB+IjYYWMmRluTtFNRFIyuYBkxuu6H1D0Xor4
AjaTBGLGodkx1pzth5CDdKjVH6+3aIHeEY5UiCRATMfLZ7A/WXrerE/4k5HCE5ns
NNynb5sSXQKBgBJipI0lYp0fpnr+gT1mKO2h8zToIWnV3dtABZQWbXwDvcPxeCwM
IbpcIarXQ4qJDjgAdgbMOi3oYZ92SyOjTbIaBp2rv/E5Ah76SEZf1QXnywnD7/U/
3c7nwvfA+msmomTWZbhIfFWDyl9DqwZSLqF5i5Kn5h9PK5jjt10yfLBdAoGACzBV
ByK5Ugj1cjdORcewEQpFGb25tsA700R/lIGPZ5Jam44W4yTAbdJ75mXX88Rn6mxx
dCIKm/owpXn5wkCCbZFwMxJ827MfwVsrMMEZ0PQ6oz4y7ezUpSrtjr9n9Q+4611r
FGs/mFXGA0OYJ7j0bd+0r8uPnn2qVbJcI7uFzqkCgYBs5AgyqRe7dG3JEkt+t1KA
R8Qk09x+Fg6qM9tXX67eP2psFHbLgO76IXoZ4POZUY0W0KO7QjrTZyNlmQyAqULH
kb0f8Vu/zXfNM/ySHgIVv7EYnkWuIdWaQ8cgMvygT0C7HIdroJ77KKwTNA2vSMjH
0EoeZijLFPdi5Ax2yCuf6A==
-----END PRIVATE KEY-----""";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startOrderListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 🚨 YENİ SİPARİŞ DİNLEYİCİ (BİLDİRİM)
  void _startOrderListener() {
    FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: userId)
        .where('status', isEqualTo: 'Onay Bekliyor')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          if (mounted) {
            _showNewOrderAlert();
          }
        }
      }
    });
  }

  void _showNewOrderAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🚨 YENİ SİPARİŞ GELDİ!",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // 🔥 YENİ: MÜŞTERİYE ANLIK PUSH BİLDİRİM GÖNDEREN FONKSİYON
  Future<void> _sendCustomerPushNotification(
      String customerId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('customer_order_push_requests')
          .add({
        'customerId': customerId,
        'status': status,
        'requestedBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'statusText': 'queued',
      });
      if (DateTime.now().millisecondsSinceEpoch >= 0) return;

      final credentials = auth.ServiceAccountCredentials.fromJson({
        "private_key": _privateKey,
        "client_email": _clientEmail,
      });
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await auth.clientViaServiceAccount(credentials, scopes);
      final token = client.credentials.accessToken.data;
      client.close();

      final String url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      final String topic = 'customer_$customerId';

      String title = "Sipariş Güncellemesi";
      String body = "Sipariş durumunuz: $status";

      if (status == "Sipariş Onaylandı") {
        title = "Siparişiniz Onaylandı! ✅";
        body = "Esnafımız siparişinizi aldı ve hazırlıklara başlıyor.";
      } else if (status == "Hazırlanıyor") {
        title = "Siparişiniz Hazırlanıyor 🍳";
        body = "Lezzetleriniz özenle hazırlanıyor.";
      } else if (status == "Yolda") {
        title = "Kurye Yolda! 🛵";
        body = "Siparişiniz adrese doğru yola çıktı.";
      } else if (status == "Teslim Edildi") {
        title = "Teslim Edildi 🎉";
        body = "Siparişiniz teslim edildi. Afiyet olsun!";
      } else if (status == "İptal Edildi") {
        title = "Sipariş İptal Edildi ❌";
        body = "Siparişiniz maalesef iptal edildi.";
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': {
            'topic': topic,
            'notification': {'title': title, 'body': body},
            'data': {
              'type': 'order_status', // Servisimizde yönlendirmeyi bu sağlıyor
              'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            // 🔥 BURASI GÜNCELLENDİ (Sesli müşteri kanalı V3)
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'customer_order_channel_v3',
                'sound': 'default'
              }
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'badge': 1}
              }
            }
          }
        }),
      );
      debugPrint("Müşteri bildirim sonucu: ${response.statusCode}");
    } catch (e) {
      debugPrint("Push hatası: $e");
    }
  }

  // 🔥 DURUM GÜNCELLEME VE MÜŞTERİYE BİLDİRİM
  Future<void> _updateOrderStatus(
      String orderId, String newStatus, String customerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      // Müşterinin notifications koleksiyonuna yaz (Anlık Takip Ekranı için)
      await FirebaseFirestore.instance.collection('notifications').add({
        'to': customerId,
        'title': 'Sipariş Durumu: $newStatus',
        'message': 'Esnaf siparişinizi güncelledi.',
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'order_update',
        'orderId': orderId
      });

      // 🔥 İŞTE SİHRİN GERÇEKLEŞTİĞİ YER: Müşterinin telefonuna sesli bildirim at!
      await _sendCustomerPushNotification(customerId, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Durum güncellendi: $newStatus"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text('Sipariş Yönetimi',
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              _buildSearchBar(),
              TabBar(
                controller: _tabController,
                indicatorColor: trendyolOrange,
                labelColor: trendyolOrange,
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [Tab(text: "Aktif İşlemler"), Tab(text: "Geçmiş")],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(activeStatuses),
          _buildOrderList(pastStatuses),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
            color: iosBg, borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: "Müşteri veya Telefon Ara...",
            prefixIcon: const Icon(CupertinoIcons.search, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => searchQuery = "");
                    })
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(List<String> statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: userId)
          .where('status', whereIn: statusFilter)
          .orderBy('orderDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CupertinoActivityIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildEmptyState();

        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['customerName'] ?? '').toString().toLowerCase();
          String phone = (data['customerPhone'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery) || phone.contains(searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(filteredDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    var item = doc.data() as Map<String, dynamic>;
    String status = item['status'] ?? "Onay Bekliyor";
    List products = item['items'] ?? [];
    String note = item['orderNote'] ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item['customerName'] ?? "Müşteri",
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "₺${(item['totalAmount'] ?? 0).toStringAsFixed(2)} • ${_formatTimestamp(item['orderDate'])}",
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey.shade600)),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text("Not Var",
                        style: GoogleFonts.inter(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
        trailing: _buildStatusBadge(status),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: iosBg.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _actionRow(CupertinoIcons.phone_fill, item['customerPhone'],
                    isPhone: true),
                const SizedBox(height: 10),
                _actionRow(
                    CupertinoIcons.location_fill, item['deliveryAddress']),
                if (note.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text("Müşteri Notu:",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 12)),
                  Text(note,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontStyle: FontStyle.italic)),
                ],
                const Divider(height: 30),
                Text("Sipariş İçeriği",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                ...products
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text("${p['quantity']}x ",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: trendyolOrange)),
                              Expanded(
                                  child: Text(p['prodName'],
                                      style: const TextStyle(fontSize: 13))),
                              Text("₺${p['prodPrice']}",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ))
                    .toList(),
                const SizedBox(height: 20),
                _buildActionButtons(doc.id, status, item['customerId']),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _actionRow(IconData icon, String text, {bool isPhone = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: trendyolOrange),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600))),
        if (isPhone)
          IconButton(
            icon: const Icon(CupertinoIcons.phone_circle_fill,
                color: Colors.green, size: 30),
            onPressed: () => _makePhoneCall(text),
          )
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = trendyolOrange;
    if (status == "Hazırlanıyor") color = Colors.blue;
    if (status == "Yolda") color = Colors.purple;
    if (status == "Teslim Edildi") color = Colors.green;
    if (status == "İptal Edildi") color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Text(status,
          style: GoogleFonts.inter(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildActionButtons(
      String orderId, String currentStatus, String customerId) {
    if (currentStatus == "Teslim Edildi" || currentStatus == "İptal Edildi")
      return const SizedBox();

    String nextStatus = "";
    String btnText = "";
    Color btnColor = trendyolOrange;

    if (currentStatus == "Onay Bekliyor") {
      nextStatus = "Sipariş Onaylandı";
      btnText = "ONAYLA";
      btnColor = Colors.green;
    } else if (currentStatus == "Sipariş Onaylandı") {
      nextStatus = "Hazırlanıyor";
      btnText = "HAZIRLA";
      btnColor = Colors.blue;
    } else if (currentStatus == "Hazırlanıyor") {
      nextStatus = "Yolda";
      btnText = "YOLA ÇIKAR";
      btnColor = Colors.purple;
    } else if (currentStatus == "Yolda") {
      nextStatus = "Teslim Edildi";
      btnText = "TESLİM ET";
      btnColor = Colors.green;
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            onPressed: () =>
                _updateOrderStatus(orderId, nextStatus, customerId),
            child: Text(btnText,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          onPressed: () =>
              _updateOrderStatus(orderId, "İptal Edildi", customerId),
        )
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Şimdi";
    DateTime dt = (timestamp as Timestamp).toDate();
    return intl.DateFormat('HH:mm').format(dt);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.doc_text, size: 60, color: Colors.black12),
          const SizedBox(height: 10),
          Text("Şu an sipariş bulunmuyor",
              style: GoogleFonts.inter(
                  color: Colors.black38, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
