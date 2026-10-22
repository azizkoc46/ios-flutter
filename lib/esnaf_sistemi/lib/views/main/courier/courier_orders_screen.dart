// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/services/courier_service.dart';

const Color _orange = Color(0xFFF27A1A);
const Color _iosBg = Color(0xFFF2F2F7);

class CourierOrdersScreen extends StatefulWidget {
  final Map<String, dynamic> courierData;

  const CourierOrdersScreen({Key? key, required this.courierData})
      : super(key: key);

  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends State<CourierOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CourierService _courierService = CourierService();
  final Set<String> _loadingOrderIds = {};

  String get _sellerId => widget.courierData['sellerId'] ?? '';
  String get _courierName => widget.courierData['name'] ?? 'Kurye';
  String get _courierPhone => widget.courierData['phone'] ?? '';
  String get _storeName => widget.courierData['storeName'] ?? 'Restoran';

  final List<String> _activeStatuses = [
    'Onay Bekliyor',
    'Sipariş Onaylandı',
    'Hazırlanıyor',
    'Yolda',
    'Kapıda',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _callCustomer(String rawPhone) async {
    final clean = CourierService.normalizePhone(rawPhone);
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Müşteri telefon numarası bulunamadı."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNavigation(String address) async {
    if (address.trim().isEmpty) return;
    final encoded = Uri.encodeComponent(address.trim());
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleStartDelivery(String orderId, String customerId) async {
    setState(() => _loadingOrderIds.add(orderId));
    try {
      final hasPermission = await _courierService.checkAndRequestLocationPermission();
      if (!hasPermission) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text("Konum İzni Gerekli"),
              content: const Text(
                  "Müşterinin siparişini canlı takip edebilmesi için cihazınızın konum servisini ve iznini açmanız zorunludur."),
              actions: [
                CupertinoDialogAction(
                  child: const Text("Tamam"),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _courierService.startLiveLocationTracking(
        orderId: orderId,
        courierName: _courierName,
        courierPhone: _courierPhone,
      );

      await _courierService.notifyCustomer(
        customerId: customerId,
        orderId: orderId,
        title: '🛵 Siparişiniz Yola Çıktı!',
        message: 'Kuryeniz $_courierName siparişinizi teslim etmek üzere yola çıktı. Canlı takip edebilirsiniz.',
        type: 'order_on_the_way',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🛵 Sipariş teslimata alındı ve canlı konum başlatıldı!"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOrderIds.remove(orderId));
    }
  }

  Future<void> _handleAtDoor(String orderId, String customerId) async {
    setState(() => _loadingOrderIds.add(orderId));
    try {
      await _courierService.markCourierAtDoor(
        orderId: orderId,
        customerId: customerId,
        storeName: _storeName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🔔 Müşteriye kapıya ulaştığınız bildirildi!"),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOrderIds.remove(orderId));
    }
  }

  Future<void> _handleDelivered(String orderId, String customerId) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Siparişi Teslim Et"),
        content: const Text(
            "Sipariş başarıyla müşteriye teslim edildi mi? Teslim edildiğinde canlı konum yayınınız kapatılacak ve müşteri artık sizi takip edemeyecektir."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Evet, Teslim Ettim"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingOrderIds.add(orderId));
    try {
      await _courierService.markOrderDelivered(
        orderId: orderId,
        customerId: customerId,
        storeName: _storeName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Sipariş başarıyla teslim edildi. Konum yayınınız sonlandırıldı."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOrderIds.remove(orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : _iosBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Kurye Paneli",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              "$_storeName • $_courierName",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _orange,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: _orange),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _orange,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
          tabs: const [
            Tab(text: "Aktif Siparişler 🛵"),
            Tab(text: "Tamamlananlar ✅"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(isActive: true, isDark: isDark),
          _buildOrdersList(isActive: false, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildOrdersList({required bool isActive, required bool isDark}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: _sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'Onay Bekliyor').toString();
          if (isActive) {
            return _activeStatuses.contains(status);
          } else {
            return status == 'Teslim Edildi' || status == 'İptal Edildi';
          }
        }).toList();

        filteredDocs.sort((a, b) {
          final aDate = (a.data() as Map)['orderDate'] as Timestamp?;
          final bDate = (b.data() as Map)['orderDate'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? CupertinoIcons.cube_box : CupertinoIcons.checkmark_seal_fill,
                  size: 56,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                Text(
                  isActive
                      ? "Şu an teslim edilmeyi bekleyen sipariş yok"
                      : "Henüz teslim edilmiş bir siparişiniz bulunmuyor",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            return _buildOrderCard(doc.id, doc.data() as Map<String, dynamic>, isDark);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data, bool isDark) {
    final status = (data['status'] ?? 'Onay Bekliyor').toString();
    final customerId = (data['customerId'] ?? '').toString();
    final customerName = (data['customerName'] ?? data['name'] ?? 'Müşteri').toString();
    final customerPhone = (data['phone'] ?? data['customerPhone'] ?? '').toString();
    final address = (data['address'] ?? data['deliveryAddress'] ?? 'Adres belirtilmemiş').toString();
    final totalAmount = (data['totalAmount'] ?? data['total'] ?? 0.0);
    final paymentType = (data['paymentType'] ?? 'Kapıda Nakit / Kart').toString();
    final items = (data['items'] as List?) ?? [];
    final bool isLoading = _loadingOrderIds.contains(orderId);
    final bool isOnTheWay = status == 'Yolda';
    final bool isAtDoor = status == 'Kapıda';
    final bool isDelivered = status == 'Teslim Edildi';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnTheWay
              ? _orange.withOpacity(0.5)
              : isAtDoor
                  ? Colors.blue.withOpacity(0.5)
                  : isDark
                      ? Colors.white10
                      : Colors.grey.shade200,
          width: (isOnTheWay || isAtDoor) ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Sipariş Kodu ve Durum Rozeti
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.cube_box_fill, size: 14, color: _orange),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Sipariş #${orderId.length > 6 ? orderId.substring(orderId.length - 6).toUpperCase() : orderId}",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),

            // Canlı Konum Yayını Uyarısı (Eğer Yoldaysa)
            if (isOnTheWay) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Canlı GPS konumunuz müşteriyle güvenle paylaşılıyor",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (isAtDoor) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.bell_fill, color: Colors.blue, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Müşteriye kapıda olduğunuz bildirildi",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Müşteri Bilgileri ve İletişim Butonu (Numara Gizli Doğrudan Arama)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _orange.withOpacity(0.15),
                    child: const Icon(CupertinoIcons.person_fill, size: 18, color: _orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "🔒 İletişim Güvenli (Numara Maskeli)",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _callCustomer(customerPhone),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(CupertinoIcons.phone_fill, size: 14),
                    label: const Text(
                      "Müşteriyi Ara",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Teslimat Adresi ve Navigasyon Butonu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.location_solid, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openNavigation(address),
                  icon: const Icon(CupertinoIcons.compass, size: 14, color: Color(0xFF0284C7)),
                  label: const Text(
                    "Haritada Aç",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ürünler Özeti
            if (items.isNotEmpty) ...[
              Text(
                "Sipariş Özeti: ${items.map((i) => "${i['quantity'] ?? 1}x ${i['title'] ?? i['name'] ?? ''}").join(', ')}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Tutar & Ödeme Yöntemi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Ödeme: $paymentType",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                Text(
                  "₺${totalAmount.toString()}",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: _orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kurye Eylemleri
            if (!isDelivered) ...[
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CupertinoActivityIndicator(),
                  ),
                )
              else if (status != 'Yolda' && status != 'Kapıda')
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleStartDelivery(orderId, customerId),
                    icon: const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 16),
                    label: const Text(
                      "🛵 Siparişi Al & Yola Çık (Konumu Başlat)",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    // Kapıya Geldim Butonu
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: isAtDoor ? Colors.grey : Colors.blue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isAtDoor ? null : () => _handleAtDoor(orderId, customerId),
                        icon: Icon(CupertinoIcons.bell_fill,
                            color: isAtDoor ? Colors.grey : Colors.blue, size: 16),
                        label: Text(
                          isAtDoor ? "Kapıdayım" : "🔔 Kapıya Geldim",
                          style: TextStyle(
                            color: isAtDoor ? Colors.grey : Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Teslim Edildi Butonu
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _handleDelivered(orderId, customerId),
                        icon: const Icon(CupertinoIcons.checkmark_circle_fill,
                            color: Colors.white, size: 16),
                        label: const Text(
                          "✅ Teslim Edildi",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label = status;

    switch (status) {
      case 'Yolda':
        bg = Colors.orange.withOpacity(0.15);
        text = Colors.orange.shade800;
        label = "🛵 Yolda";
        break;
      case 'Kapıda':
        bg = Colors.blue.withOpacity(0.15);
        text = Colors.blue.shade700;
        label = "🔔 Kapıda";
        break;
      case 'Teslim Edildi':
        bg = Colors.green.withOpacity(0.15);
        text = Colors.green.shade700;
        label = "✅ Teslim Edildi";
        break;
      case 'Hazırlanıyor':
        bg = Colors.amber.withOpacity(0.15);
        text = Colors.amber.shade900;
        label = "🍳 Hazırlanıyor";
        break;
      default:
        bg = Colors.grey.withOpacity(0.15);
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
