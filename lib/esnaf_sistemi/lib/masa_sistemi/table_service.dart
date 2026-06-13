import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    final cacheKey = 'table_menu_$vendorId';
    final cacheTimeKey = '${cacheKey}_time';
    final cachedAt = prefs.getInt(cacheTimeKey) ?? 0;
    final cacheFresh = DateTime.now().millisecondsSinceEpoch - cachedAt <
        const Duration(hours: 6).inMilliseconds;
    final cached = prefs.getString(cacheKey);
    if (!force && cacheFresh && cached != null) {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(cached) as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
    }

    final snapshot = await _db
        .collection('products')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final menu = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return <String, dynamic>{
            'id': doc.id,
            'name': (data['productName'] ?? 'İsimsiz Ürün').toString(),
            'price': (data['price'] as num?)?.toDouble() ?? 0,
            'category': (data['categoryName'] ?? 'Diğer').toString(),
            'portion': (data['portion'] ?? '').toString(),
            'sideDishes': (data['sideDishes'] ?? '').toString(),
            'isAvailable': data['isAvailable'] != false,
          };
        })
        .where((item) => item['isAvailable'] == true)
        .toList();
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

  String receiptText(Map<String, dynamic> order) {
    final buffer = StringBuffer()
      ..writeln('PAZARCIK PORTAL - ADİSYON')
      ..writeln(order['tableName'] ?? 'Masa')
      ..writeln('------------------------------');
    for (final raw in (order['items'] as List?) ?? const []) {
      final item = Map<String, dynamic>.from(raw as Map);
      if (item['cancelled'] == true) continue;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final extraPrice = (item['extraPrice'] as num?)?.toDouble() ?? 0;
      final total =
          item['comped'] == true ? 0 : (unitPrice + extraPrice) * quantity;
      buffer.writeln(
          '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} x ${item['name']}  ${total.toStringAsFixed(2)} TL');
      final modifiers = (item['modifiers'] as List?)?.join(', ') ?? '';
      if (modifiers.isNotEmpty) buffer.writeln('  $modifiers');
      if ((item['note'] ?? '').toString().isNotEmpty)
        buffer.writeln('  Not: ${item['note']}');
      if (item['comped'] == true) buffer.writeln('  İKRAM');
    }
    buffer
      ..writeln('------------------------------')
      ..writeln(
          'TOPLAM: ${((order['grandTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} TL');
    return buffer.toString();
  }
}
