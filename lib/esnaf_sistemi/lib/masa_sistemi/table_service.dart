import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RestaurantTableService {
  RestaurantTableService(this.vendorId);

  final String vendorId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get restaurantRef =>
      _db.collection('customers').doc(vendorId);

  CollectionReference<Map<String, dynamic>> get tablesRef =>
      restaurantRef.collection('restaurant_tables');

  CollectionReference<Map<String, dynamic>> get ordersRef =>
      restaurantRef.collection('table_orders');

  Stream<DocumentSnapshot<Map<String, dynamic>>> permissionStream() =>
      restaurantRef.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> tablesStream() =>
      tablesRef.orderBy('sortOrder').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> activeOrdersStream() =>
      ordersRef.where('status', isEqualTo: 'active').snapshots();

  Future<void> addTable(String name) async {
    final existing = await tablesRef.get();
    await tablesRef.add({
      'name': name.trim(),
      'status': 'empty',
      'sortOrder': existing.size,
      'activeOrderId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameTable(String tableId, String name) =>
      tablesRef.doc(tableId).update({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteTable(String tableId) async {
    final table = await tablesRef.doc(tableId).get();
    if ((table.data()?['activeOrderId'] ?? '').toString().isNotEmpty) {
      throw StateError('Açık adisyonu olan masa silinemez.');
    }
    await tablesRef.doc(tableId).delete();
  }

  Future<void> setTableStatus(String tableId, String status) =>
      tablesRef.doc(tableId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<String> openOrder({
    required String tableId,
    required String tableName,
  }) async {
    final tableRef = tablesRef.doc(tableId);
    return _db.runTransaction((transaction) async {
      final table = await transaction.get(tableRef);
      final activeOrderId = (table.data()?['activeOrderId'] ?? '').toString();
      if (activeOrderId.isNotEmpty) return activeOrderId;

      final orderRef = ordersRef.doc();
      transaction.set(orderRef, {
        'vendorId': vendorId,
        'tableId': tableId,
        'tableName': tableName,
        'status': 'active',
        'tableStatus': 'occupied',
        'items': <Map<String, dynamic>>[],
        'payments': <Map<String, dynamic>>[],
        'subtotal': 0.0,
        'discountTotal': 0.0,
        'grandTotal': 0.0,
        'paidTotal': 0.0,
        'balance': 0.0,
        'orderNote': '',
        'kitchenStatus': 'new',
        'openedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(tableRef, {
        'status': 'occupied',
        'activeOrderId': orderRef.id,
        'openedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return orderRef.id;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> orderStream(String orderId) =>
      ordersRef.doc(orderId).snapshots();

  double asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ??
        fallback;
  }

  int asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  bool isMonthlyDealActive(Map<String, dynamic> data) {
    if (data['isMonthlyDeal'] != true ||
        data['monthlyDealEnabled'] == false ||
        data['dealStatus'] == 'passive') {
      return false;
    }

    final limit = asInt(data['dealLimit'], fallback: 0);
    final sold = asInt(data['dealSoldCount'], fallback: 0);
    if (limit > 0 && sold >= limit) return false;

    final now = DateTime.now();
    if (data['dealRepeatMonthly'] == true) {
      final startDay = asInt(data['dealRepeatStartDay'], fallback: 1);
      final endDay = asInt(data['dealRepeatEndDay'], fallback: startDay);
      final day = now.day;
      if (startDay <= endDay) return day >= startDay && day <= endDay;
      return day >= startDay || day <= endDay;
    }

    final start = asDate(data['dealStartsAt']);
    final end = asDate(data['dealEndsAt']);
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  double dealPrice(Map<String, dynamic> data) {
    final price = asDouble(data['price']);
    final discount = asInt(data['discount']);
    if (discount <= 0) return price;
    return price - (price * discount / 100);
  }

  Map<String, dynamic> _menuItemFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final isMonthlyDeal = data['isMonthlyDeal'] == true;
    final price = asDouble(data['price']);
    final discount = asInt(data['discount']);
    return <String, dynamic>{
      'id': doc.id,
      'name':
          (data['productName'] ?? data['name'] ?? 'İsimsiz Ürün').toString(),
      'price': isMonthlyDeal ? dealPrice(data) : price,
      'originalPrice': price,
      'discount': discount,
      'category': isMonthlyDeal
          ? 'Ayın İndirimli Menüsü'
          : (data['categoryName'] ?? data['category'] ?? 'Diğer').toString(),
      'portion': (data['portion'] ?? '').toString(),
      'sideDishes': (data['sideDishes'] ?? '').toString(),
      'isAvailable': data['isAvailable'] != false,
      'isMonthlyDeal': isMonthlyDeal,
      'dealActive': isMonthlyDealActive(data),
      'dealLimit': data['dealLimit'],
      'dealSoldCount': data['dealSoldCount'],
    };
  }

  bool _menuItemVisible(Map<String, dynamic> item) =>
      item['isAvailable'] == true &&
      (item['isMonthlyDeal'] != true || item['dealActive'] == true);

  Future<List<Map<String, dynamic>>> loadProductExtras(String productId) async {
    final extras = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<void> addFrom(CollectionReference<Map<String, dynamic>> ref) async {
      try {
        final snapshot = await ref.get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = (data['name'] ?? data['title'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final key = '${doc.id}::$name';
          if (!seen.add(key)) continue;
          extras.add({
            'id': doc.id,
            'name': name,
            'price': asDouble(data['price']),
          });
        }
      } catch (_) {}
    }

    await addFrom(
        _db.collection('products').doc(productId).collection('extras'));
    await addFrom(restaurantRef
        .collection('products')
        .doc(productId)
        .collection('extras'));

    if (extras.isEmpty) {
      await addFrom(restaurantRef.collection('extras'));
    }

    extras.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    return extras;
  }

  Future<void> saveItems(
      String orderId, List<Map<String, dynamic>> items) async {
    final totals = calculateTotals(items);
    final orderRef = ordersRef.doc(orderId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final paid = (snapshot.data()?['paidTotal'] as num?)?.toDouble() ?? 0;
      transaction.update(orderRef, {
        'items': items,
        ...totals,
        'balance': totals['grandTotal']! - paid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, double> calculateTotals(List<Map<String, dynamic>> items) {
    var subtotal = 0.0;
    var discount = 0.0;
    for (final item in items) {
      if (item['cancelled'] == true) continue;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final extraPrice = (item['extraPrice'] as num?)?.toDouble() ?? 0;
      final lineTotal = (unitPrice + extraPrice) * quantity;
      subtotal += lineTotal;
      if (item['comped'] == true) discount += lineTotal;
    }
    return {
      'subtotal': subtotal,
      'discountTotal': discount,
      'grandTotal': subtotal - discount,
    };
  }

  Future<void> updateOrderStatus(String orderId, String status) =>
      ordersRef.doc(orderId).update({
        'kitchenStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> requestBill(String tableId, String orderId) async {
    final batch = _db.batch();
    batch.update(tablesRef.doc(tableId), {
      'status': 'bill_requested',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(ordersRef.doc(orderId), {
      'tableStatus': 'bill_requested',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> addPayment({
    required String tableId,
    required String orderId,
    required String method,
    required double amount,
    List<Map<String, dynamic>> allocations = const [],
  }) async {
    final orderRef = ordersRef.doc(orderId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final data = snapshot.data() ?? {};
      final payments = List<Map<String, dynamic>>.from(
        ((data['payments'] as List?) ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      payments.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'method': method,
        'amount': amount,
        'mode': allocations.isEmpty ? 'amount' : 'items',
        'allocations': allocations,
        'createdAt': DateTime.now().toIso8601String(),
      });
      final paid = payments.fold<double>(
        0,
        (sum, payment) => sum + ((payment['amount'] as num?)?.toDouble() ?? 0),
      );
      final total = (data['grandTotal'] as num?)?.toDouble() ?? 0;
      transaction.update(orderRef, {
        'payments': payments,
        'paidTotal': paid,
        'balance': total - paid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, double> paidQuantities(Map<String, dynamic> order) {
    final result = <String, double>{};
    for (final rawPayment in (order['payments'] as List?) ?? const []) {
      final payment = Map<String, dynamic>.from(rawPayment as Map);
      for (final rawAllocation
          in (payment['allocations'] as List?) ?? const []) {
        final allocation = Map<String, dynamic>.from(rawAllocation as Map);
        final lineId = (allocation['lineId'] ?? '').toString();
        if (lineId.isEmpty) continue;
        result[lineId] = (result[lineId] ?? 0) +
            ((allocation['quantity'] as num?)?.toDouble() ?? 0);
      }
    }
    return result;
  }

  Future<void> closeOrder({
    required String tableId,
    required String orderId,
  }) async {
    final batch = _db.batch();
    batch.update(ordersRef.doc(orderId), {
      'status': 'closed',
      'tableStatus': 'empty',
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(tablesRef.doc(tableId), {
      'status': 'empty',
      'activeOrderId': null,
      'openedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> loadMenu({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'table_menu_v3_$vendorId';
    final cacheTimeKey = '${cacheKey}_time';
    final cachedAt = prefs.getInt(cacheTimeKey) ?? 0;

    final cacheFresh = DateTime.now().millisecondsSinceEpoch - cachedAt <
        const Duration(minutes: 30).inMilliseconds;
    final cached = prefs.getString(cacheKey);
    if (!force && cacheFresh && cached != null) {
      try {
        return List<Map<String, dynamic>>.from(
          (jsonDecode(cached) as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
      } catch (_) {}
    }

    List<Map<String, dynamic>> menu = [];

    try {
      final subSnap = await restaurantRef.collection('products').get();
      if (subSnap.docs.isNotEmpty) {
        menu = subSnap.docs
            .map((doc) {
              final data = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'name': (data['productName'] ?? data['name'] ?? 'İsimsiz Ürün')
                    .toString(),
                'price': (data['price'] as num?)?.toDouble() ?? 0,
                'category':
                    (data['categoryName'] ?? data['category'] ?? 'Diğer')
                        .toString(),
                'portion': (data['portion'] ?? '').toString(),
                'sideDishes': (data['sideDishes'] ?? '').toString(),
                'isAvailable': data['isAvailable'] != false,
              };
            })
            .where((item) => item['isAvailable'] == true)
            .toList();
      }
    } catch (_) {}

    if (menu.isEmpty) {
      final snapshot = await _db
          .collection('products')
          .where('vendorId', isEqualTo: vendorId)
          .get();
      menu = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              'name': (data['productName'] ?? data['name'] ?? 'İsimsiz Ürün')
                  .toString(),
              'price': (data['price'] as num?)?.toDouble() ?? 0,
              'category': (data['categoryName'] ?? data['category'] ?? 'Diğer')
                  .toString(),
              'portion': (data['portion'] ?? '').toString(),
              'sideDishes': (data['sideDishes'] ?? '').toString(),
              'isAvailable': data['isAvailable'] != false,
            };
          })
          .where((item) => item['isAvailable'] == true)
          .toList();
    }

    try {
      final dealSnapshot = await _db
          .collection('products')
          .where('vendorId', isEqualTo: vendorId)
          .get();
      final byId = <String, Map<String, dynamic>>{
        for (final item in menu) item['id'].toString(): item,
      };
      for (final doc in dealSnapshot.docs) {
        if (doc.data()['isMonthlyDeal'] != true) continue;
        final deal = _menuItemFromDoc(doc);
        if (_menuItemVisible(deal)) byId[doc.id] = deal;
      }
      menu = byId.values.toList();
    } catch (_) {}

    // Ekstraları "Ekstralar" kategorisi olarak menüye dahil ediyoruz
    try {
      final extrasSnap = await restaurantRef.collection('extras').get();
      for (final doc in extrasSnap.docs) {
        final data = doc.data();
        menu.add({
          'id': doc.id,
          'name': (data['name'] ?? data['title'] ?? 'Ekstra').toString(),
          'price': (data['price'] as num?)?.toDouble() ?? 0,
          'originalPrice': (data['price'] as num?)?.toDouble() ?? 0,
          'category': 'Ekstralar',
          'portion': '',
          'sideDishes': '',
          'isAvailable': true,
        });
      }
    } catch (_) {}

    menu.sort(
      (a, b) {
        final aDeal = a['isMonthlyDeal'] == true;
        final bDeal = b['isMonthlyDeal'] == true;
        if (aDeal != bDeal) return aDeal ? -1 : 1;
        return a['category'].toString().compareTo(b['category'].toString());
      },
    );

    await prefs.setString(cacheKey, jsonEncode(menu));
    await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    return menu;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      todayClosedOrders() async {
    final start = DateTime.now();
    final dayStart = DateTime(start.year, start.month, start.day);
    final snapshot = await ordersRef
        .where('closedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .get();
    return snapshot.docs
        .where((doc) => doc.data()['status'] == 'closed')
        .toList();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      todayClosedOrdersStream() {
    final start = DateTime.now();
    final dayStart = DateTime(start.year, start.month, start.day);
    return ordersRef
        .where('closedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['status'] == 'closed')
            .toList());
  }

  String money(dynamic value) =>
      '${((value as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ₺';

  String quantity(dynamic value) {
    final q = (value as num?)?.toDouble() ?? 1;
    return q.toStringAsFixed(q % 1 == 0 ? 0 : 1);
  }

  double lineTotal(Map<String, dynamic> item) {
    if (item['cancelled'] == true || item['comped'] == true) return 0;
    final q = (item['quantity'] as num?)?.toDouble() ?? 1;
    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
    final extraPrice = (item['extraPrice'] as num?)?.toDouble() ?? 0;
    return (unitPrice + extraPrice) * q;
  }

  Future<void> printReceipt(
    Map<String, dynamic> order, {
    String restaurantName = 'Pazarcık Portal',
  }) async {
    final pdf = pw.Document();
    final regular = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final items = List<Map<String, dynamic>>.from(
      ((order['items'] as List?) ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final payments = List<Map<String, dynamic>>.from(
      ((order['payments'] as List?) ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final openedAt = order['openedAt'] is Timestamp
        ? (order['openedAt'] as Timestamp).toDate()
        : DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(10),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Column(children: [
              pw.Text(restaurantName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('ADİSYON',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text((order['tableName'] ?? 'Masa').toString()),
              pw.Text(
                '${openedAt.day.toString().padLeft(2, '0')}.${openedAt.month.toString().padLeft(2, '0')}.${openedAt.year} '
                '${openedAt.hour.toString().padLeft(2, '0')}:${openedAt.minute.toString().padLeft(2, '0')}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ]),
          ),
          pw.Divider(),
          ...items.map((item) {
            final modifiers = ((item['modifiers'] as List?) ?? const [])
                .map((e) => e.toString())
                .where((value) => value.isNotEmpty)
                .join(', ');
            final note = (item['note'] ?? '').toString();
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${quantity(item['quantity'])} x ${item['name'] ?? 'Ürün'}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Text(money(lineTotal(item))),
                    ],
                  ),
                  if (modifiers.isNotEmpty)
                    pw.Text(modifiers, style: const pw.TextStyle(fontSize: 8)),
                  if (note.isNotEmpty)
                    pw.Text('Not: $note',
                        style: const pw.TextStyle(fontSize: 8)),
                  if (item['comped'] == true)
                    pw.Text('İKRAM', style: const pw.TextStyle(fontSize: 8)),
                  if (item['cancelled'] == true)
                    pw.Text('İPTAL', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            );
          }),
          pw.Divider(),
          _receiptTotalRow('Ara Toplam', money(order['subtotal'])),
          _receiptTotalRow('İkram/İndirim', money(order['discountTotal'])),
          _receiptTotalRow('Toplam', money(order['grandTotal']), bold: true),
          _receiptTotalRow('Ödenen', money(order['paidTotal'])),
          _receiptTotalRow('Kalan', money(order['balance']), bold: true),
          if (payments.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Ödemeler',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...payments.map(
              (payment) => _receiptTotalRow(
                (payment['method'] ?? 'Ödeme').toString(),
                money(payment['amount']),
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text('Teşekkür ederiz',
                style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'adisyon_${(order['tableName'] ?? 'masa').toString()}',
      onLayout: (_) => pdf.save(),
    );
  }

  pw.Widget _receiptTotalRow(String label, String value, {bool bold = false}) {
    final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(value, style: style),
      ]),
    );
  }

  String receiptText(Map<String, dynamic> order) {
    final buffer = StringBuffer()
      ..writeln('PAZARCIK PORTAL - ADİSYON')
      ..writeln(order['tableName'] ?? 'Masa')
      ..writeln('------------------------------');
    for (final raw in (order['items'] as List?) ?? const []) {
      final item = Map<String, dynamic>.from(raw as Map);
      if (item['cancelled'] == true) continue;
      final q = (item['quantity'] as num?)?.toDouble() ?? 1;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final extraPrice = (item['extraPrice'] as num?)?.toDouble() ?? 0;
      final total = item['comped'] == true ? 0 : (unitPrice + extraPrice) * q;
      buffer.writeln(
          '${q.toStringAsFixed(q % 1 == 0 ? 0 : 1)} x ${item['name']}  ${total.toStringAsFixed(2)} ₺');
      final modifiers = (item['modifiers'] as List?)?.join(', ') ?? '';
      if (modifiers.isNotEmpty) buffer.writeln('  $modifiers');
      if ((item['note'] ?? '').toString().isNotEmpty)
        buffer.writeln('  Not: ${item['note']}');
      if (item['comped'] == true) buffer.writeln('  İKRAM');
    }
    buffer
      ..writeln('------------------------------')
      ..writeln(
          'TOPLAM: ${((order['grandTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ₺');
    return buffer.toString();
  }
}
