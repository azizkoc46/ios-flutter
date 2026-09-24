// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _orange = Color(0xFFF27A1A);
const Color _iosBg = Color(0xFFF2F2F7);

class OrderTrackingScreen extends StatelessWidget {
  static const String routeName = 'order-tracking';
  final String orderId;

  const OrderTrackingScreen({Key? key, required this.orderId})
      : super(key: key);

  // FIX: "Sipariş Onaylandı" adımı eklendi — 5 aşama
  static const _stages = [
    (
      label: 'Sipariş Alındı',
      desc: 'Esnafımız siparişinizi inceliyor',
      status: 'Onay Bekliyor',
    ),
    (
      label: 'Onaylandı',
      desc: 'Esnafımız siparişinizi kabul etti',
      status: 'Sipariş Onaylandı',
    ),
    (
      label: 'Hazırlanıyor',
      desc: 'Lezzetleriniz özenle hazırlanıyor 🍳',
      status: 'Hazırlanıyor',
    ),
    (
      label: 'Kurye Yolda',
      desc: 'Siparişiniz kapınıza geliyor 🛵',
      status: 'Yolda',
    ),
    (
      label: 'Teslim Edildi',
      desc: 'Afiyet olsun! Teşekkürler 🎉',
      status: 'Teslim Edildi',
    ),
  ];

  int _currentStage(String status) {
    if (status.contains('Onaylandı') && !status.contains('Bekliyor')) return 1;
    if (status.contains('Hazırlanıyor')) return 2;
    if (status.contains('Yolda')) return 3;
    if (status.contains('Teslim')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _iosBg,
      appBar: AppBar(
        title: Text(
          'Sipariş Takibi',
          style: GoogleFonts.inter(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: _orange),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Bir hata oluştu',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'Onay Bekliyor') as String;
          final stage = _currentStage(status);
          final isCancelled = status.contains('İptal');

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // ── Büyük durum başlığı
                    _buildHeroStatus(status, stage, isCancelled),
                    _buildEstimatedDeliveryCard(data, status),
                    _buildCustomerCancelButton(context, orderId, status),
                    const SizedBox(height: 24),
                    // ── Timeline
                    if (!isCancelled)
                      _buildTimeline(stage)
                    else
                      _buildCancelledCard(),
                    const SizedBox(height: 20),
                    // ── Sipariş detayları
                    _buildDetailsCard(data, orderId),
                    // ── Ürünler
                    _buildItemsCard(data),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroStatus(String status, int stage, bool isCancelled) {
    final color = isCancelled
        ? const Color(0xFFE74C3C)
        : stage == 4
            ? const Color(0xFF2ECC71)
            : _orange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(_statusIcon(status), size: 36, color: color),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusDescription(status),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4),
                  ),
                  if (!isCancelled && stage < 4) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (stage + 1) / _stages.length,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Adım ${stage + 1} / ${_stages.length}',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(int currentStage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sipariş Durumu',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ...List.generate(_stages.length, (i) {
              final isDone = i <= currentStage;
              final isActive = i == currentStage;
              final isLast = i == _stages.length - 1;
              final stageColor = isDone
                  ? (i == _stages.length - 1
                      ? const Color(0xFF2ECC71)
                      : _orange)
                  : Colors.grey.shade300;

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Connector line + circle
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isActive ? 30 : 24,
                              height: isActive ? 30 : 24,
                              decoration: BoxDecoration(
                                color: isDone ? stageColor : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isDone
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.shade300, width: 2),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: _orange.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isDone
                                  ? const Icon(CupertinoIcons.checkmark_alt,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                            if (!isLast)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 2,
                                height: 36,
                                color: i < currentStage
                                    ? _orange.withOpacity(0.4)
                                    : Colors.grey.shade200,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              bottom: isLast ? 0 : 20,
                              top: isActive ? 0 : 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stages[i].label,
                                style: GoogleFonts.inter(
                                  fontSize: isActive ? 15 : 14,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : (isDone
                                          ? FontWeight.w600
                                          : FontWeight.w500),
                                  color: isDone
                                      ? Colors.black87
                                      : Colors.grey.shade400,
                                ),
                              ),
                              if (isActive || isDone)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _stages[i].desc,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isActive
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade400),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.red.withOpacity(0.15), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(CupertinoIcons.xmark_circle_fill,
                  color: Colors.red, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sipariş İptal Edildi',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'Siparişiniz esnaf tarafından iptal edilmiştir. Destek için iletişime geçebilirsiniz.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data, String id) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sipariş Detayları',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.black87)),
            const SizedBox(height: 14),
            _detailRow(CupertinoIcons.number, 'Sipariş No',
                '#${id.substring(0, 8).toUpperCase()}'),
            const Divider(height: 20, thickness: 0.5),
            _detailRow(
              CupertinoIcons.location_solid,
              'Teslimat Adresi',
              (data['deliveryAddress'] ?? 'Adres bilgisi yok') as String,
            ),
            if ((data['totalAmount'] ?? 0) > 0) ...[
              const Divider(height: 20, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.money_dollar_circle,
                          size: 18, color: Colors.grey.shade400),
                      const SizedBox(width: 10),
                      Text('Toplam Tutar',
                          style: GoogleFonts.inter(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Text(
                    '₺${(data['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: _orange),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> data) {
    final items = (data['items'] as List?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sipariş İçeriği',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            ...items.map<Widget>((p) {
              final name = (p['prodName'] ?? p['name'] ?? 'Ürün').toString();
              final price = (p['prodPrice'] ?? p['price'] ?? 0);
              final qty = (p['quantity'] ?? 1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${qty}x',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              color: _orange,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text('₺$price',
                        style: GoogleFonts.inter(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
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
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(String status) {
    if (status.contains('Bekliyor')) return CupertinoIcons.clock_fill;
    if (status.contains('Onaylandı')) return CupertinoIcons.checkmark_circle_fill;
    if (status.contains('Hazırlanıyor')) return Icons.restaurant_rounded;
    if (status.contains('Yolda')) return Icons.delivery_dining_rounded;
    if (status.contains('Teslim')) return CupertinoIcons.checkmark_seal_fill;
    if (status.contains('İptal')) return CupertinoIcons.xmark_circle_fill;
    return CupertinoIcons.clock;
  }

  String _statusDescription(String status) {
    if (status.contains('Bekliyor')) return 'Esnafımız siparişinizi inceliyor...';
    if (status.contains('Onaylandı') && !status.contains('Bekliyor'))
      return 'Harika! Esnafımız siparişinizi kabul etti.';
    if (status.contains('Hazırlanıyor'))
      return 'Ürünleriniz özenle hazırlanıyor.';
    if (status.contains('Yolda'))
      return 'Kuryemiz siparişinizi kapınıza getiriyor.';
    if (status.contains('Teslim'))
      return 'Siparişiniz teslim edildi. Afiyet olsun!';
    if (status.contains('İptal'))
      return 'Siparişiniz maalesef iptal edildi.';
    return '';
  }

  // FIX: Tahmini teslimat süresi rozeti (Item 10)
  Widget _buildEstimatedDeliveryCard(Map<String, dynamic> data, String status) {
    if (['Teslim Edildi', 'İptal Edildi'].contains(status)) {
      return const SizedBox.shrink();
    }
    final String estTime = data['estimatedMinutes'] != null
        ? '${data['estimatedMinutes']} dk'
        : '30 - 45 dk';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF2ECC71).withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.stopwatch_fill,
                  color: Color(0xFF2ECC71), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tahmini Teslimat Süresi',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(estTime,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF27AE60))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Yaklaşık',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF27AE60))),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: Müşteri sipariş iptal onay dialog'u (Item 4)
  Widget _buildCustomerCancelButton(
      BuildContext context, String orderId, String status) {
    if (status != 'Onay Bekliyor') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE74C3C),
            side: BorderSide(color: const Color(0xFFE74C3C).withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(CupertinoIcons.xmark_circle, size: 18),
          label: Text('Siparişi İptal Et',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          onPressed: () => _confirmCustomerCancel(context, orderId),
        ),
      ),
    );
  }

  Future<void> _confirmCustomerCancel(
      BuildContext context, String orderId) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Siparişi İptal Et'),
        content: const Text(
            'Siparişinizi iptal etmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
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
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({
          'status': 'İptal Edildi',
          'cancelledBy': 'customer',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Siparişiniz iptal edildi.'),
              backgroundColor: Color(0xFFE74C3C),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
