import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

import '../../../providers/cart.dart';
import '../../../models/cart.dart';
import '../../../utils/delivery_neighborhoods.dart';
import '../../../utils/store_availability.dart';
import 'package:pazarcik_portal/auth/auth.dart';

// Tema Renkleri
const Color trendyolOrange = Color(0xfff27a1a);
const Color iosBg = Color(0xFFF2F2F7);

class OrderSummaryScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;

  const OrderSummaryScreen({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
  }) : super(key: key);

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

  String? selectedMahalle;
  final _phoneController = TextEditingController();
  final _addressDescController = TextEditingController();
  final _orderNoteController = TextEditingController();

  bool isLoading = false;
  List<String> storeNeighborhoods = [];

  // --- V1 API İÇİN GEREKLİ KİMLİK BİLGİLERİ ---
  final String _projectId = "pazarcik-portal-7faf2";
  final String _clientEmail =
      "firebase-adminsdk-fbsvc@pazarcik-portal-7faf2.iam.gserviceaccount.com";
  final String _clientId = "100884384179291445520";
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
    _initData();
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    await _fetchStoreNeighborhoods();
    await _fetchSavedData();
    setState(() => isLoading = false);
  }

  Future<void> _fetchStoreNeighborhoods() async {
    try {
      if (widget.cartItems.isEmpty) {
        if (mounted) {
          setState(() =>
              storeNeighborhoods = List.of(pazarcikDeliveryNeighborhoods));
        }
        return;
      }
      String vendorId = widget.cartItems[0].sellerId;
      var storeDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(vendorId)
          .get();

      final neighborhoods =
          readDeliveryNeighborhoods(storeDoc.data()?['deliveryZones']);
      if (mounted) setState(() => storeNeighborhoods = neighborhoods);
    } catch (e) {
      debugPrint("Mahalle çekme hatası: $e");
      if (mounted) {
        setState(
            () => storeNeighborhoods = List.of(pazarcikDeliveryNeighborhoods));
      }
    }
  }

  Future<void> _fetchSavedData() async {
    if (userId.isEmpty) return;
    var userDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      var data = userDoc.data() as Map<String, dynamic>;
      setState(() {
        _phoneController.text = data['phone'] ?? "";
        if (data['savedAddress'] != null) {
          var addr = data['savedAddress'];
          String savedM = addr['mahalle'] ?? "";
          if (storeNeighborhoods.contains(savedM)) {
            selectedMahalle = savedM;
          }
        }
        _addressDescController.text = data['savedAddress']?['tarif'] ?? "";
      });
    }
  }

// 🔥 FIREBASE CONSOLE İLE AYNI YAPI + V5 KANALI - HATASIZ V1 PAYLOAD
  Future<void> _sendOrderPushNotification(
      String sellerId, String customerName, double amount) async {
    try {
      debugPrint("🚀 Bildirim gönderiliyor: seller_$sellerId");

      await FirebaseFirestore.instance
          .collection('seller_order_push_requests')
          .add({
        'sellerId': sellerId,
        'customerName': customerName,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });
      if (DateTime.now().millisecondsSinceEpoch >= 0) return;

      final credentials = auth.ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": _projectId,
        "private_key": _privateKey,
        "client_email": _clientEmail,
        "client_id": _clientId,
      });

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await auth.clientViaServiceAccount(credentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();

      final String url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      // 🔥 HATASI GİDERİLMİŞ, KUSURSUZ JSON YAPISI
      final Map<String, dynamic> payload = {
        'message': {
          'topic': 'seller_$sellerId',
          'notification': {
            'title': '🔔 YENİ SİPARİŞ!',
            'body': '$customerName - ₺${amount.toStringAsFixed(2)}',
          },
          'data': {
            'type': 'new_order',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'customerName': customerName,
            'amount': amount.toString(),
            'sellerId': sellerId,
          },
          'android': {
            'priority': 'high', // 🔥 Küçük harf olmalı
            'ttl': '86400s',
            'notification': {
              'channel_id': 'seller_order_channel_v5',
              'sound': 'default',
              'notification_priority':
                  'PRIORITY_MAX', // 🔥 HATA VEREN SATIR DÜZELTİLDİ!
              'visibility': 'PUBLIC',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'tag': 'order_${DateTime.now().millisecondsSinceEpoch}',
            }
          },
          'apns': {
            'headers': {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            'payload': {
              'aps': {
                'alert': {
                  'title': '🔔 YENİ SİPARİŞ!',
                  'body': '$customerName - ₺${amount.toStringAsFixed(2)}',
                },
                'sound': 'default',
                'badge': 1,
                'category': 'NEW_ORDER_CATEGORY',
                'interruption-level': 'time-sensitive',
                'relevance-score': 1.0,
              }
            }
          },
          'webpush': {
            'headers': {
              'Urgency': 'high',
            },
            'notification': {
              'title': '🔔 YENİ SİPARİŞ!',
              'body': '$customerName - ₺${amount.toStringAsFixed(2)}',
              'requireInteraction': true,
              'vibrate': [200, 100, 200],
            }
          }
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      debugPrint("📬 HTTP Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        debugPrint("✅ BİLDİRİM BAŞARILI!");
        debugPrint("📨 Mesaj ID: ${responseBody['name']}");
      } else {
        debugPrint("❌ HATA: ${response.body}");
        final errorBody = jsonDecode(response.body);
        debugPrint("❌ Hata detayı: ${errorBody['error']['message']}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Bildirim gönderilemedi: ${errorBody['error']['message']}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ KRİTİK HATA: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bildirim hatası: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 SİPARİŞİ ONAYLA VE ESNAFA BİLDİRİM GÖNDER
  Future<void> _handleOrderConfirmation() async {
    if (userId.isEmpty) {
      _showErrorSnackBar("Sipariş vermek için giriş yapmalısınız.");
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const Auth()),
      );
      return;
    }

    if (selectedMahalle == null ||
        _addressDescController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showErrorSnackBar("Lütfen teslimat bilgilerini eksiksiz doldurun.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final vendorId = widget.cartItems[0].sellerId;
      final storeDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(vendorId)
          .get();
      if (!StoreAvailability.isOpen(storeDoc.data() ?? const {})) {
        _showErrorSnackBar(
            'Restoran şu anda kapalı veya çalışma saati dışında. Sipariş alınamıyor.');
        return;
      }
      var userDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .get();
      String customerName =
          userDoc.data()?['fullname'] ?? 'Pazarcık Portal Kullanıcısı';

      // 1. Kullanıcı Bilgilerini Güncelle
      await FirebaseFirestore.instance.collection('customers').doc(userId).set({
        'phone': _phoneController.text.trim(),
        'savedAddress': {
          'mahalle': selectedMahalle,
          'tarif': _addressDescController.text.trim(),
        }
      }, SetOptions(merge: true));

      // 2. Siparişi Orders Koleksiyonuna Kaydet
      var newOrderRef = FirebaseFirestore.instance.collection('orders').doc();

      await newOrderRef.set({
        'orderId': newOrderRef.id,
        'customerId': userId,
        'customerName': customerName,
        'customerPhone': _phoneController.text.trim(),
        'deliveryAddress':
            "$selectedMahalle Mah. - ${_addressDescController.text.trim()}",
        'orderNote': _orderNoteController.text.trim(),
        'sellerId': vendorId,
        'totalAmount': widget.totalAmount,
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'Onay Bekliyor',
        'items': widget.cartItems.map((e) => e.toJson()).toList(),
      });

      // 3. ESNAF PANELİNE UYGULAMA İÇİ BİLDİRİM DÜŞÜR
      await FirebaseFirestore.instance.collection('notifications').add({
        'to': vendorId,
        'title': 'Yeni Sipariş! 🛍️',
        'message':
            '$customerName isimli müşteriden ₺${widget.totalAmount.toStringAsFixed(2)} tutarında yeni sipariş geldi.',
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'order',
        'orderId': newOrderRef.id,
      });

      // 🔥 4. SENİN YENİ MOTORUNLA ESNAFIN TELEFONUNU ZİL SESİYLE ÇALDIR!
      await _sendOrderPushNotification(
          vendorId, customerName, widget.totalAmount);

      // 5. Sepeti Temizle ve Başarı Diyaloğunu Göster
      Provider.of<CartData>(context, listen: false).clearCart();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(context),
        );
      }
    } catch (e) {
      _showErrorSnackBar("Sipariş sırasında bir hata oluştu: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      appBar: AppBar(
        title: Text("Sipariş Özeti",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 15))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("Teslimat Bilgileri"),
                  const SizedBox(height: 15),
                  _buildModernField(
                      _phoneController,
                      "Telefon Numarası",
                      CupertinoIcons.device_phone_portrait,
                      TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildMahalleDropdown(),
                  const SizedBox(height: 12),
                  _buildModernField(
                      _addressDescController,
                      "Adres Tarifi / Kapı No",
                      CupertinoIcons.map_pin_ellipse,
                      TextInputType.multiline,
                      maxLines: 2),
                  const SizedBox(height: 12),
                  _buildModernField(
                      _orderNoteController,
                      "Sipariş Notu (Opsiyonel)",
                      CupertinoIcons.doc_text,
                      TextInputType.text),
                  const SizedBox(height: 30),
                  _sectionHeader("Sipariş İçeriği"),
                  const SizedBox(height: 12),
                  _buildOrderItemsList(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
      bottomSheet: _buildBottomConfirmBar(),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
      style: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87));

  Widget _buildModernField(TextEditingController controller, String hint,
      IconData icon, TextInputType type,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ]),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: trendyolOrange, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildMahalleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ]),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(CupertinoIcons.location_solid,
            color: trendyolOrange, size: 20),
        title: Text(selectedMahalle ?? "Teslimat Mahallesi Seçin",
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: selectedMahalle == null ? Colors.grey : Colors.black87,
                fontWeight: selectedMahalle == null
                    ? FontWeight.normal
                    : FontWeight.w600)),
        trailing: const Icon(CupertinoIcons.chevron_down, size: 18),
        onTap: _showNeighborhoodPicker,
      ),
    );
  }

  Future<void> _showNeighborhoodPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Teslimat Mahallesi',
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: storeNeighborhoods.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final neighborhood = storeNeighborhoods[index];
                  return ListTile(
                    title: Text(neighborhood),
                    trailing: selectedMahalle == neighborhood
                        ? const Icon(CupertinoIcons.check_mark_circled_solid,
                            color: trendyolOrange)
                        : null,
                    onTap: () => Navigator.pop(context, neighborhood),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => selectedMahalle = picked);
  }

  Widget _buildOrderItemsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: widget.cartItems
            .map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${item.quantity}x ${item.prodName}",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text("₺${item.totalPrice.toStringAsFixed(2)}",
                          style: GoogleFonts.inter(
                              color: Colors.grey, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBottomConfirmBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
          ]),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Toplam Tutar",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("₺${widget.totalAmount.toStringAsFixed(2)}",
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: trendyolOrange)),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: trendyolOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              onPressed: isLoading ? null : _handleOrderConfirmation,
              child: isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text("SİPARİŞİ ONAYLA",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.check_mark_circled_solid,
                size: 100, color: Colors.green),
            const SizedBox(height: 20),
            Text("Harika! Siparişin Alındı",
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text("Pazarcık esnafı siparişinizi hazırlamaya başlıyor.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: trendyolOrange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text("Ana Sayfaya Dön",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
