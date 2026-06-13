import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import '../../../providers/cart.dart';
import 'order_summary.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/customer/customer_bottomNav.dart';

const Color trendyolOrange = Color(0xfff27a1a);

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _motorController;
  Animation<double>? _motorAnimation;

  @override
  void initState() {
    super.initState();
    _motorController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _motorAnimation = Tween<double>(begin: -100, end: 500).animate(
      CurvedAnimation(parent: _motorController!, curve: Curves.linear),
    );
    _motorController!.repeat();
  }

  @override
  void dispose() {
    _motorController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Esnaf sistemi için Sepet verisi Provider üzerinden çekilir
    var cartData = Provider.of<CartData>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('Sepetim',
                style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
            if (cartData.cartItems.isNotEmpty)
              Text("${cartData.cartItems.length} Ürün",
                  style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
          ],
        ),
        centerTitle: true,
      ),
      body: cartData.cartItems.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                _buildInfoBar(),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: cartData.cartItems.length,
                    itemBuilder: (context, index) {
                      var item = cartData.cartItems[index];
                      // Firebase'den gelen ürün nesnesi gönderilir
                      return _buildModernCartItem(item, cartData);
                    },
                  ),
                ),
                _buildOrderSummaryBottom(cartData),
              ],
            ),
    );
  }

  Widget _buildModernCartItem(item, CartData cartData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          // Firebase Storage Görseli için Optimize Edilmiş Yapı
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: PortalNetworkImage(
              url: item.prodImgUrl,
              width: 85,
              height: 85,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 85,
                height: 85,
                color: Colors.grey[100],
                child: const CupertinoActivityIndicator(),
              ),
              errorWidget: Container(
                width: 85,
                height: 85,
                color: Colors.grey[100],
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.prodName,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("₺${item.prodPrice.toStringAsFixed(2)} / Adet",
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        "₺${(item.prodPrice * item.quantity).toStringAsFixed(2)}",
                        style: GoogleFonts.inter(
                            color: trendyolOrange,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    _buildQuantityController(item, cartData),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityController(item, CartData cartData) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          _qtyActionBtn(CupertinoIcons.minus, () {
            cartData.decrementProductQuantity(item.prodId);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text("${item.quantity}",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          _qtyActionBtn(CupertinoIcons.plus, () {
            cartData.incrementProductQuantity(item.prodId);
          }),
        ],
      ),
    );
  }

  Widget _qtyActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: trendyolOrange)),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: const Color(0xFFFFF3E0),
      child: Row(children: [
        const Icon(CupertinoIcons.info_circle, size: 16, color: trendyolOrange),
        const SizedBox(width: 10),
        Text("Pazarcık Esnafı: Kapıda ödeme geçerlidir.",
            style: GoogleFonts.inter(
                color: trendyolOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildOrderSummaryBottom(CartData cartData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ]),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(
                "Ara Toplam", "₺${cartData.cartTotalPrice.toStringAsFixed(2)}",
                isBold: false),
            _summaryRow("Gönderim", "Ücretsiz",
                isBold: false, valueColor: const Color(0xFF34C759)),
            const Divider(height: 25, thickness: 0.5),
            _summaryRow(
                "Toplam", "₺${cartData.cartTotalPrice.toStringAsFixed(2)}",
                isBold: true, fontSize: 20),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: trendyolOrange,
                    // ignore: deprecated_member_use
                    shadowColor: trendyolOrange.withOpacity(0.4),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OrderSummaryScreen(
                              cartItems: cartData.cartItems,
                              totalAmount: cartData.cartTotalPrice)));
                },
                child: Text("SİPARİŞİ ONAYLA",
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {required bool isBold, double fontSize = 14, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: isBold ? Colors.black : Colors.grey[600],
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
          Text(value,
              style: GoogleFonts.inter(
                  color:
                      valueColor ?? (isBold ? trendyolOrange : Colors.black87),
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _motorController!,
                builder: (context, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: _motorAnimation?.value ?? -100,
                        top: 20,
                        child: Column(
                          children: [
                            const Icon(Icons.delivery_dining_rounded,
                                size: 85, color: trendyolOrange),
                            Container(
                                height: 4,
                                width: 60,
                                decoration: BoxDecoration(
                                    // ignore: deprecated_member_use
                                    color: Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(2))),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text("Sepetin Boş Kalmasın",
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            Text("Lezzetli bir mola için hemen yemeklere göz at!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Kullanıcıyı doğrudan yemek sipariş sistemine (CustomerBottomNav) gönderir
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CustomerBottomNav()),
                    (route) =>
                        false, // Geri dönmesini engeller, orayı ana ekran gibi açar
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: trendyolOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: Text("Yemeklere Göz At",
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
