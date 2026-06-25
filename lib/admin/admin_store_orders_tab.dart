// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

class AdminStoreOrdersTab extends StatefulWidget {
  const AdminStoreOrdersTab({Key? key}) : super(key: key);

  @override
  State<AdminStoreOrdersTab> createState() => _AdminStoreOrdersTabState();
}

class _AdminStoreOrdersTabState extends State<AdminStoreOrdersTab> {
  static const Color _primary = Color(0xFF6366F1);
  static const Color _orange = Color(0xFFF27A1A);

  String _statusFilter = 'all';
  String _periodFilter = 'today';
  String _search = '';
  final Map<String, String> _sellerNameCache = {};
  final Map<String, Future<String>> _sellerNameFutures = {};

  final Map<String, String> _statusLabels = const {
    'all': 'Hepsi',
    'Onay Bekliyor': 'Yeni',
    'Sipariş Onaylandı': 'Onaylandı',
    'Hazırlanıyor': 'Hazırlanıyor',
    'Yolda': 'Yolda',
    'Teslim Edildi': 'Teslim',
    'İptal Edildi': 'İptal',
  };

  final Map<String, String> _periodLabels = const {
    'today': 'Bugün',
    'yesterday': 'Dün',
    'week': '7 Gün',
    'month': '30 Gün',
    'all': 'Tümü',
  };

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .limit(500)
        .snapshots();
  }

  DateTime? _dateOf(Map<String, dynamic> data) {
    final value = data['orderDate'] ?? data['createdAt'] ?? data['lastUpdate'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double _amountOf(Map<String, dynamic> data) {
    final value =
        data['totalAmount'] ?? data['total'] ?? data['totalPrice'] ?? 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  String _textOf(Map<String, dynamic> data, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  bool _matchesPeriod(DateTime? date) {
    if (_periodFilter == 'all') return true;
    if (date == null) return false;

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(date.year, date.month, date.day);

    switch (_periodFilter) {
      case 'today':
        return startDate == startToday;
      case 'yesterday':
        return startDate == startToday.subtract(const Duration(days: 1));
      case 'week':
        return date.isAfter(now.subtract(const Duration(days: 7)));
      case 'month':
        return date.isAfter(now.subtract(const Duration(days: 30)));
      default:
        return true;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final needle = _search.trim().toLowerCase();
    return docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? 'Onay Bekliyor').toString();
      final date = _dateOf(data);
      if (_statusFilter != 'all' && status != _statusFilter) return false;
      if (!_matchesPeriod(date)) return false;

      if (needle.isEmpty) return true;
      final haystack = [
        doc.id,
        data['orderId'],
        data['sellerId'],
        data['customerId'],
        data['customerName'],
        data['customerPhone'],
        data['deliveryAddress'],
        data['restaurantName'],
        data['storeName'],
        data['businessName'],
        ...((data['items'] as List?) ?? const []).map((item) {
          if (item is Map) return item.values.join(' ');
          return item.toString();
        }),
      ].join(' ').toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  Future<String> _sellerName(
      String sellerId, Map<String, dynamic> order) async {
    final existing = _textOf(order, [
      'storeName',
      'businessName',
      'restaurantName',
      'sellerName',
    ]);
    if (existing.isNotEmpty) return existing;

    if (sellerId.isEmpty) return 'Restoran bilgisi yok';
    final cached = _sellerNameCache[sellerId];
    if (cached != null) return cached;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(sellerId)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final name = _textOf(
          data,
          [
            'restaurantName',
            'storeName',
            'businessName',
            'companyName',
            'fullname',
            'name',
          ],
          fallback: 'Restoran adı yok');
      _sellerNameCache[sellerId] = name;
      return name;
    } catch (_) {
      return 'Restoran okunamadı';
    }
  }

  Future<String> _sellerNameFuture(
      String sellerId, Map<String, dynamic> order) {
    if (sellerId.isEmpty) return Future.value(_sellerName(sellerId, order));
    return _sellerNameFutures.putIfAbsent(
      sellerId,
      () => _sellerName(sellerId, order),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'status': newStatus,
      'lastUpdate': FieldValue.serverTimestamp(),
      'adminLastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openStatusSheet(String orderId, String currentStatus) {
    final statuses = _statusLabels.keys.where((key) => key != 'all').toList();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Sipariş Durumu'),
        message: Text(
            'Mevcut durum: ${_statusLabels[currentStatus] ?? currentStatus}'),
        actions: statuses
            .map(
              (status) => CupertinoActionSheetAction(
                isDefaultAction: status == currentStatus,
                isDestructiveAction: status == 'İptal Edildi',
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateOrderStatus(orderId, status);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sipariş durumu güncellendi: $status'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text(_statusLabels[status] ?? status),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Vazgeç'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorState(snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator(radius: 15));
          }

          final docs = _filterDocs(snapshot.data!.docs);
          return Column(
            children: [
              _buildTopFilters(),
              _buildSummary(docs),
              Expanded(
                child: docs.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return _orderCard(doc.id, doc.data());
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Müşteri, telefon, restoran veya ürün ara',
              prefixIcon: const Icon(CupertinoIcons.search),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          _chipRow(_periodLabels, _periodFilter,
              (value) => setState(() => _periodFilter = value)),
          const SizedBox(height: 10),
          _chipRow(_statusLabels, _statusFilter,
              (value) => setState(() => _statusFilter = value)),
        ],
      ),
    );
  }

  Widget _chipRow(Map<String, String> items, String selected,
      ValueChanged<String> onSelected) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.entries.map((entry) {
          final active = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text(entry.value),
              selectedColor: _primary,
              backgroundColor: const Color(0xFFF3F4F6),
              labelStyle: TextStyle(
                color: active ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              side: BorderSide.none,
              onSelected: (_) => onSelected(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final totalRevenue =
        docs.fold<double>(0, (sum, doc) => sum + _amountOf(doc.data()));
    final waitingCount = docs.where((doc) {
      final status = (doc.data()['status'] ?? '').toString();
      return status == 'Onay Bekliyor' ||
          status == 'Sipariş Onaylandı' ||
          status == 'Hazırlanıyor' ||
          status == 'Yolda';
    }).length;
    final completedCount = docs
        .where(
            (doc) => (doc.data()['status'] ?? '').toString() == 'Teslim Edildi')
        .length;

    final bySeller = <String, _SellerOrderSummary>{};
    for (final doc in docs) {
      final data = doc.data();
      final sellerId = (data['sellerId'] ?? '').toString();
      final key = sellerId.isEmpty ? 'unknown_${doc.id}' : sellerId;
      final summary = bySeller.putIfAbsent(
        key,
        () => _SellerOrderSummary(sellerId: sellerId),
      );
      summary.count++;
      summary.revenue += _amountOf(data);
      final date = _dateOf(data);
      if (date != null &&
          (summary.lastOrder == null || date.isAfter(summary.lastOrder!))) {
        summary.lastOrder = date;
      }
      final status = (data['status'] ?? '').toString();
      if (status == 'Onay Bekliyor') summary.waiting++;
      if (summary.sampleOrder.isEmpty) summary.sampleOrder = data;
    }

    final sellers = bySeller.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _statBox('Sipariş', '${docs.length}', CupertinoIcons.bag_fill,
                  Colors.blue),
              const SizedBox(width: 8),
              _statBox('Aktif', '$waitingCount', CupertinoIcons.clock_fill,
                  Colors.orange),
              const SizedBox(width: 8),
              _statBox('Teslim', '$completedCount',
                  CupertinoIcons.checkmark_circle_fill, Colors.green),
              const SizedBox(width: 8),
              _statBox('Tutar', _money(totalRevenue),
                  CupertinoIcons.money_dollar_circle_fill, Colors.teal),
            ],
          ),
          if (sellers.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sellers.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _sellerSummaryCard(sellers[index]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withOpacity(0.82),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sellerSummaryCard(_SellerOrderSummary summary) {
    return FutureBuilder<String>(
      future: _sellerNameFuture(summary.sellerId, summary.sampleOrder),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Restoran yükleniyor';
        return Container(
          width: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.building_2_fill,
                      size: 16, color: _primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${summary.count} sipariş • ${_money(summary.revenue)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                summary.waiting > 0
                    ? '${summary.waiting} yeni sipariş bekliyor'
                    : 'Son: ${_formatDate(summary.lastOrder)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: summary.waiting > 0 ? Colors.orange : Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orderCard(String orderId, Map<String, dynamic> data) {
    final sellerId = (data['sellerId'] ?? '').toString();
    final customerName = _textOf(
      data,
      ['customerName', 'userName', 'name'],
      fallback: 'Müşteri bilgisi yok',
    );
    final customerPhone = _textOf(data, ['customerPhone', 'phone']);
    final address = _textOf(data, ['deliveryAddress', 'address']);
    final note = _textOf(data, ['orderNote', 'note']);
    final status = (data['status'] ?? 'Onay Bekliyor').toString();
    final amount = _amountOf(data);
    final date = _dateOf(data);
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return FutureBuilder<String>(
      future: _sellerNameFuture(sellerId, data),
      builder: (context, sellerSnapshot) {
        final sellerName = sellerSnapshot.data ?? 'Restoran yükleniyor';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _badge(_statusLabels[status] ?? status, _statusColor(status)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$customerName • ${_formatDate(date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(amount),
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            children: [
              const Divider(height: 18),
              _infoRow(CupertinoIcons.person_fill, customerName),
              if (customerPhone.isNotEmpty)
                _infoRow(
                  CupertinoIcons.phone_fill,
                  customerPhone,
                  trailing: IconButton(
                    tooltip: 'Ara',
                    icon: const Icon(CupertinoIcons.phone_circle_fill,
                        color: Colors.green, size: 30),
                    onPressed: () => _makeCall(customerPhone),
                  ),
                ),
              if (address.isNotEmpty)
                _infoRow(CupertinoIcons.location_solid, address),
              if (note.isNotEmpty)
                _infoRow(CupertinoIcons.doc_text_fill, 'Not: $note',
                    color: Colors.redAccent),
              const SizedBox(height: 10),
              _itemsBox(items),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(CupertinoIcons.slider_horizontal_3,
                          size: 17),
                      label: const Text('Durumu Güncelle'),
                      onPressed: () => _openStatusSheet(orderId, status),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#${orderId.substring(0, orderId.length.clamp(0, 6))}',
                    style: const TextStyle(
                      color: Colors.black38,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text,
      {Widget? trailing, Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _orange),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _itemsBox(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Ürün listesi bulunamadı.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş İçeriği',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final quantity = item['quantity'] ?? 1;
            final name =
                (item['prodName'] ?? item['name'] ?? 'Ürün').toString();
            final price = item['totalPrice'] ?? item['prodPrice'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${quantity}x',
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(price is num
                        ? price.toDouble()
                        : double.tryParse(price.toString()) ?? 0),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Teslim Edildi':
        return Colors.green;
      case 'İptal Edildi':
        return Colors.red;
      case 'Yolda':
        return Colors.purple;
      case 'Hazırlanıyor':
      case 'Sipariş Onaylandı':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.bag_badge_minus,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Bu filtrelerde sipariş bulunamadı.',
            style:
                TextStyle(color: Colors.black45, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.redAccent, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Siparişler yüklenemedi',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tarih yok';
    return intl.DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(date);
  }

  String _money(double value) {
    return '₺${value.toStringAsFixed(2)}';
  }
}

class _SellerOrderSummary {
  _SellerOrderSummary({required this.sellerId});

  final String sellerId;
  int count = 0;
  int waiting = 0;
  double revenue = 0;
  DateTime? lastOrder;
  Map<String, dynamic> sampleOrder = const {};
}
