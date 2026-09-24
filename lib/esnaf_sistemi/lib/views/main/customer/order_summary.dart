import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../providers/cart.dart';
import '../../../models/cart.dart';
import '../../../utils/delivery_neighborhoods.dart';
import '../../../utils/store_availability.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';
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
  bool _isSubmitting = false; // FIX: çift sipariş gönderme koruması
  List<String> storeNeighborhoods = [];

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

  // Bildirim Cloud Function kuyruğu üzerinden gönderilir (güvenli)
  Future<void> _sendOrderPushNotification(
      String sellerId, String customerName, double amount) async {
    try {
      await FirebaseFirestore.instance
          .collection('seller_order_push_requests')
          .add({
        'sellerId': sellerId,
        'customerName': customerName,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });
    } catch (e) {
      debugPrint('Bildirim kuyruğu hatası: $e');
    }
  }

  // FIX: Çift sipariş gönderme koruması
  Future<void> _handleOrderConfirmation() async {
    if (_isSubmitting || isLoading) return;
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

    _isSubmitting = true;
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
      final storeData = storeDoc.data() ?? const <String, dynamic>{};
      final storeName = (storeData['restaurantName'] ??
              storeData['storeName'] ??
              storeData['businessName'] ??
              storeData['companyName'] ??
              storeData['fullname'] ??
              '')
          .toString()
          .trim();
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
        if (storeName.isNotEmpty) 'restaurantName': storeName,
        if (storeName.isNotEmpty) 'storeName': storeName,
        'totalAmount': widget.totalAmount,
        'orderDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'Onay Bekliyor',
        'items': widget.cartItems.map((e) => e.toJson()).toList(),
      });

      final dealBatch = FirebaseFirestore.instance.batch();
      var hasDealCounterUpdate = false;
      for (final item in widget.cartItems) {
        if (item.isMonthlyDeal && item.prodId.isNotEmpty) {
          dealBatch.update(
            FirebaseFirestore.instance.collection('products').doc(item.prodId),
            {'dealSoldCount': FieldValue.increment(item.quantity)},
          );
          hasDealCounterUpdate = true;
        }
      }
      if (hasDealCounterUpdate) {
        await dealBatch.commit();
      }

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

      await AdminNotificationService.instance.notifyAdmin(
        title: 'Yeni yemek siparişi',
        body:
            '${storeName.isNotEmpty ? storeName : 'Restoran'} - $customerName - ₺${widget.totalAmount.toStringAsFixed(2)}',
        type: AdminNotifType.storeOrder,
        docId: newOrderRef.id,
        extra: {
          'orderId': newOrderRef.id,
          'sellerId': vendorId,
          'customerId': userId,
          'restaurantName': storeName,
        },
      );

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
      _isSubmitting = false;
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
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
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
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
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
