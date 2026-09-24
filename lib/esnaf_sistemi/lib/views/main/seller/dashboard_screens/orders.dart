// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import '../kitchen/kitchen_display_screen.dart';

// ── Tema ──────────────────────────────────────────────────────────────────────
const Color _orange = Color(0xFFF27A1A);
const Color _iosBg = Color(0xFFF2F2F7);

class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late TabController _tabController;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // FIX: StreamSubscription artık saklanıyor
  StreamSubscription? _orderSub;

  final _activeStatuses = [
    'Onay Bekliyor',
    'Sipariş Onaylandı',
    'Hazırlanıyor',
    'Yolda',
  ];
  final _pastStatuses = ['Teslim Edildi', 'İptal Edildi'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startOrderListener();
  }

  @override
  void dispose() {
    _orderSub?.cancel(); // FIX: memory leak giderildi
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Yeni sipariş dinleyici ─────────────────────────────────────────────────
  void _startOrderListener() {
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: _userId)
        .where('status', isEqualTo: 'Onay Bekliyor')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added && mounted) {
          _showNewOrderBanner();
        }
      }
    });
  }

  void _showNewOrderBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4757), Color(0xFFFF6B35)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.bell_fill,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Yeni Sipariş Geldi! 🚀',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    Text('Hemen incele ve onayla',
                        style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: Text('Tamam',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        actions: const [SizedBox.shrink()],
      ),
    );
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendCustomerPushNotification(
      String customerId, String status) async {
    // Bildirim Cloud Function üzerinden gönderilir (güvenli yöntem)
    try {
      await FirebaseFirestore.instance
          .collection('customer_order_push_requests')
          .add({
        'customerId': customerId,
        'status': status,
        'requestedBy': _userId,
        'createdAt': FieldValue.serverTimestamp(),
        'statusText': 'queued',
      });
    } catch (e) {
      debugPrint('Push kuyruğu hatası: $e');
    }
  }

  Future<void> _updateOrderStatus(
      String orderId, String newStatus, String customerId,
      {int? estimatedMinutes}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'lastUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (estimatedMinutes != null) {
        updateData['estimatedMinutes'] = estimatedMinutes;
      }
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);
      await FirebaseFirestore.instance.collection('notifications').add({
        'to': customerId,
        'title': 'Sipariş Durumu: $newStatus',
        'message': 'Esnaf siparişinizi güncelledi.',
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'order_update',
        'orderId': orderId,
      });
      await _sendCustomerPushNotification(customerId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_circle_fill,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Durum güncellendi: $newStatus',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Durum güncelleme hatası: $e');
    }
  }

  // Tahmini hazırlık süresi seçimi ve onay modalı
  Future<void> _showApprovalDialog(String orderId, String customerId) async {
    final chosen = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Siparişi Onayla & Hazırlık Süresi',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        message: Text('Müşteriye bildirilecek tahmini teslimat süresini seçin:',
            style: GoogleFonts.inter(fontSize: 13)),
        actions: [20, 30, 40, 50, 60].map((mins) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, mins),
            child: Text('$mins Dakika',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Vazgeç'),
        ),
      ),
    );
    if (chosen != null && mounted) {
      await _updateOrderStatus(orderId, 'Sipariş Onaylandı', customerId,
          estimatedMinutes: chosen);
    }
  }

  // FIX: İptal için onay dialog'u
  Future<void> _confirmCancel(
      String orderId, String customerId, String customerName) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Siparişi İptal Et'),
        content: Text(
            '$customerName adlı müşterinin siparişini iptal etmek istediğinizden emin misiniz?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('İptal Et'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _updateOrderStatus(orderId, 'İptal Edildi', customerId);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _iosBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Sipariş Yönetimi',
          style: GoogleFonts.inter(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Mutfak Ekranı (KDS)',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFFF6B35), size: 18),
                  const SizedBox(width: 4),
                  Text('KDS',
                      style: GoogleFonts.inter(
                          color: const Color(0xFFFF6B35),
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ],
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => KitchenDisplayScreen(sellerId: _userId),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              _buildSearchBar(),
              TabBar(
                controller: _tabController,
                indicatorColor: _orange,
                indicatorWeight: 3,
                labelColor: _orange,
                unselectedLabelColor: Colors.grey,
                labelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Aktif İşlemler'),
                  Tab(text: 'Geçmiş'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_activeStatuses),
          _buildOrderList(_pastStatuses),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(13),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Müşteri veya telefon ara…',
            hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
            prefixIcon:
                const Icon(CupertinoIcons.search, size: 18, color: Colors.grey),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill,
                        size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
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
          .where('sellerId', isEqualTo: _userId)
          .where('status', whereIn: statusFilter)
          .orderBy('orderDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name =
              (data['customerName'] ?? '').toString().toLowerCase();
          final phone =
              (data['customerPhone'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || phone.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildOrderCard(docs[index]),
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    final item = doc.data() as Map<String, dynamic>;
    final status = (item['status'] ?? 'Onay Bekliyor') as String;
    final products = (item['items'] as List?) ?? [];
    final note = (item['note'] ?? item['orderNote'] ?? '') as String;
    // FIX: null-safe erişim
    final customerName = (item['customerName'] ?? 'Müşteri') as String;
    final customerPhone = (item['customerPhone'] ?? '') as String;
    final deliveryAddress =
        (item['deliveryAddress'] ?? 'Adres belirtilmemiş') as String;
    final customerId = (item['customerId'] ?? '') as String;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_statusIcon(status),
                    color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          // FIX: gün + saat gösterimi
                          _formatTimestamp(item['orderDate']),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₺${(item['totalAmount'] ?? 0).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _orange),
                  ),
                  if (note.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(CupertinoIcons.exclamationmark_circle_fill,
                          color: Colors.red, size: 16),
                    ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  // İletişim & adres
                  if (customerPhone.isNotEmpty)
                    _infoTile(
                      icon: CupertinoIcons.phone_fill,
                      iconColor: const Color(0xFF2ECC71),
                      label: 'Telefon',
                      value: customerPhone,
                      trailing: GestureDetector(
                        onTap: () => _makePhoneCall(customerPhone),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.phone_circle_fill,
                              color: Color(0xFF2ECC71), size: 24),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _infoTile(
                    icon: CupertinoIcons.location_fill,
                    iconColor: const Color(0xFF3498DB),
                    label: 'Teslimat Adresi',
                    value: deliveryAddress,
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.15), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle_fill,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Müşteri Notu',
                                    style: GoogleFonts.inter(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(note,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.red.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Sipariş içeriği
                  Text('Sipariş İçeriği',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: products.map<Widget>((p) {
                        final pName = (p['prodName'] ?? p['name'] ?? 'Ürün')
                            .toString();
                        final pPrice = p['prodPrice'] ?? p['price'] ?? 0;
                        final qty = p['quantity'] ?? 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${qty}x',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        color: _orange,
                                        fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(pName,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Text('₺$pPrice',
                                  style: GoogleFonts.inter(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(doc.id, status, customerId, customerName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildActionButtons(
      String orderId, String status, String customerId, String customerName) {
    if (status == 'Teslim Edildi' || status == 'İptal Edildi') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'Teslim Edildi'
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.xmark_circle_fill,
              color: status == 'Teslim Edildi' ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              status == 'Teslim Edildi'
                  ? 'Sipariş tamamlandı'
                  : 'Sipariş iptal edildi',
              style: GoogleFonts.inter(
                  color: status == 'Teslim Edildi' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      );
    }

    String nextStatus = '';
    String btnText = '';
    Color btnColor = _orange;
    IconData btnIcon = CupertinoIcons.checkmark;

    if (status == 'Onay Bekliyor') {
      nextStatus = 'Sipariş Onaylandı';
      btnText = 'ONAYLA';
      btnColor = const Color(0xFF2ECC71);
      btnIcon = CupertinoIcons.checkmark_circle_fill;
    } else if (status == 'Sipariş Onaylandı') {
      nextStatus = 'Hazırlanıyor';
      btnText = 'HAZIRLAMAYA BAŞLA';
      btnColor = const Color(0xFF3498DB);
      btnIcon = Icons.restaurant_rounded;
    } else if (status == 'Hazırlanıyor') {
      nextStatus = 'Yolda';
      btnText = 'YOLA ÇIKAR';
      btnColor = const Color(0xFF9B59B6);
      btnIcon = Icons.delivery_dining_rounded;
    } else if (status == 'Yolda') {
      nextStatus = 'Teslim Edildi';
      btnText = 'TESLİM EDİLDİ';
      btnColor = const Color(0xFF2ECC71);
      btnIcon = CupertinoIcons.checkmark_seal_fill;
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (status == 'Onay Bekliyor') {
                _showApprovalDialog(orderId, customerId);
              } else {
                _updateOrderStatus(orderId, nextStatus, customerId);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [btnColor, btnColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(btnIcon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(btnText,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // FIX: İptal butonu onay dialog'u ile
        GestureDetector(
          onTap: () => _confirmCancel(orderId, customerId, customerName),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.red.withOpacity(0.2), width: 1),
            ),
            child: const Icon(CupertinoIcons.xmark,
                color: Colors.red, size: 20),
          ),
        ),
      ],
    );
  }

  // FIX: Gün + Saat formatı (Item 7)
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Şimdi';
    try {
      final dt = (timestamp is Timestamp)
          ? timestamp.toDate()
          : (timestamp is DateTime ? timestamp : DateTime.now());
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Bugün ${intl.DateFormat('HH:mm').format(dt)}';
      }
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${intl.DateFormat('HH:mm').format(dt)}';
    } catch (_) {
      return 'Şimdi';
    }
  }

  Color _statusColor(String status) {
    if (status == 'Onay Bekliyor') return const Color(0xFFF39C12);
    if (status == 'Sipariş Onaylandı') return const Color(0xFF2ECC71);
    if (status == 'Hazırlanıyor') return const Color(0xFF3498DB);
    if (status == 'Yolda') return const Color(0xFF9B59B6);
    if (status == 'Teslim Edildi') return const Color(0xFF27AE60);
    if (status == 'İptal Edildi') return const Color(0xFFE74C3C);
    return _orange;
  }

  IconData _statusIcon(String status) {
    if (status == 'Onay Bekliyor') return CupertinoIcons.clock_fill;
    if (status == 'Sipariş Onaylandı')
      return CupertinoIcons.checkmark_circle_fill;
    if (status == 'Hazırlanıyor') return Icons.restaurant_rounded;
    if (status == 'Yolda') return Icons.delivery_dining_rounded;
    if (status == 'Teslim Edildi')
      return CupertinoIcons.checkmark_seal_fill;
    if (status == 'İptal Edildi') return CupertinoIcons.xmark_circle_fill;
    return CupertinoIcons.bag;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.doc_text,
                size: 44, color: Colors.black26),
          ),
          const SizedBox(height: 20),
          Text('Şu an sipariş bulunmuyor',
              style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text('Yeni siparişler burada görünecek',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
