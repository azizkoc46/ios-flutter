// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccountBalanceScreen extends StatefulWidget {
  static const routeName = '/account_balance';
  const AccountBalanceScreen({Key? key}) : super(key: key);

  @override
  State<AccountBalanceScreen> createState() => _AccountBalanceScreenState();
}

class _AccountBalanceScreenState extends State<AccountBalanceScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedPeriod = 'Bugün';

  DateTime get _startDate {
    final now = DateTime.now();
    if (_selectedPeriod == 'Bugün')
      return DateTime(now.year, now.month, now.day);
    if (_selectedPeriod == 'Bu Hafta') {
      return now.subtract(const Duration(days: 7));
    }
    return DateTime(now.year, now.month);
  }

  DateTime get _endDate => DateTime.now();

  double _numValue(Map<String, dynamic> data, String key) {
    return (data[key] as num?)?.toDouble() ?? 0;
  }

  DateTime? _dateValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return null;
  }

  bool _inPeriod(Map<String, dynamic> data, List<String> dateKeys) {
    final date = _dateValue(data, dateKeys);
    if (date == null) return false;
    return !date.isBefore(_startDate) && !date.isAfter(_endDate);
  }

  bool _isCompletedFoodOrder(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    return status == 'Teslim Edildi';
  }

  bool _isClosedTableOrder(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    return status == 'closed';
  }

  String _money(double value) => '₺${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Kasa bilgileri için giriş yapmalısınız.')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Kasa ve Kazanç',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('sellerId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, foodSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('customers')
                      .doc(userId)
                      .collection('table_orders')
                      .snapshots(),
                  builder: (context, tableSnapshot) {
                    final loading = !foodSnapshot.hasData &&
                        !foodSnapshot.hasError &&
                        !tableSnapshot.hasData &&
                        !tableSnapshot.hasError;

                    if (loading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      );
                    }

                    final foodDocs = foodSnapshot.data?.docs ?? const [];
                    final tableDocs = tableSnapshot.data?.docs ?? const [];

                    final foodOrders = foodDocs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .where(_isCompletedFoodOrder)
                        .where((data) =>
                            _inPeriod(data, ['orderDate', 'createdAt']))
                        .toList();

                    final tableOrders = tableDocs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .where(_isClosedTableOrder)
                        .where((data) =>
                            _inPeriod(data, ['closedAt', 'updatedAt']))
                        .toList();

                    final foodTotal = foodOrders.fold<double>(
                      0,
                      (sum, data) => sum + _numValue(data, 'totalAmount'),
                    );
                    final tableTotal = tableOrders.fold<double>(
                      0,
                      (sum, data) =>
                          sum +
                          (_numValue(data, 'paidTotal') > 0
                              ? _numValue(data, 'paidTotal')
                              : _numValue(data, 'grandTotal')),
                    );
                    final total = foodTotal + tableTotal;

                    final tablePermissionIssue =
                        tableSnapshot.hasError && !tableSnapshot.hasData;

                    return Column(
                      children: [
                        _buildPeriodSelector(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMainBalanceCard(total),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMiniCard(
                                        title: 'Yemek Siparişleri',
                                        value: _money(foodTotal),
                                        subtitle:
                                            '${foodOrders.length} teslimat',
                                        icon: Icons.delivery_dining,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMiniCard(
                                        title: 'Masa Adisyonları',
                                        value: _money(tableTotal),
                                        subtitle:
                                            '${tableOrders.length} kapalı masa',
                                        icon: Icons.table_restaurant,
                                        color: Colors.lightBlueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                if (tablePermissionIssue) ...[
                                  const SizedBox(height: 14),
                                  _buildWarningTile(
                                    'Masa sistemi yetkisi kapalı görünüyor. Online sipariş kazancı gösterildi, masa toplamı 0 TL kabul edildi.',
                                  ),
                                ],
                                const SizedBox(height: 24),
                                _buildInfoTile(),
                                const SizedBox(height: 24),
                                const Text(
                                  'Son Kazanç Hareketleri',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._recentItems(foodOrders, tableOrders),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _recentItems(
    List<Map<String, dynamic>> foodOrders,
    List<Map<String, dynamic>> tableOrders,
  ) {
    final items = <_RevenueItem>[
      ...foodOrders.map((data) => _RevenueItem(
            title: (data['customerName'] ?? 'Müşteri').toString(),
            subtitle: 'Yemek siparişi',
            amount: _numValue(data, 'totalAmount'),
            date: _dateValue(data, ['orderDate', 'createdAt']),
          )),
      ...tableOrders.map((data) => _RevenueItem(
            title: (data['tableName'] ?? 'Masa').toString(),
            subtitle: 'Masa adisyonu',
            amount: _numValue(data, 'paidTotal') > 0
                ? _numValue(data, 'paidTotal')
                : _numValue(data, 'grandTotal'),
            date: _dateValue(data, ['closedAt', 'updatedAt']),
          )),
    ]..sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    if (items.isEmpty) return [_buildEmptyState()];

    return items.take(10).map(_buildTransactionItem).toList();
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: ['Bugün', 'Bu Hafta', 'Bu Ay'].map((period) {
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.greenAccent : Colors.white10,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainBalanceCard(double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.greenAccent.withOpacity(0.05), blurRadius: 30)
        ],
      ),
      child: Column(
        children: [
          Text(
            '$_selectedPeriod Toplam Getiri',
            style: const TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 10),
          FittedBox(
            child: Text(
              _money(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Teslim edilen siparişler ve kapanan masa adisyonları',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: Colors.blueAccent, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Bu ekran gerçek tahsilat kaydı değildir; işletmenin uygulama içindeki tamamlanan sipariş ve kapanan masa adisyonlarını özetler.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningTile(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amberAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(_RevenueItem item) {
    final dateText = item.date == null
        ? 'Tarih yok'
        : DateFormat('dd MMM, HH:mm', 'tr_TR').format(item.date!);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.subtitle} • $dateText',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '+ ${_money(item.amount)}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Center(
        child: Text(
          'Seçilen dönemde henüz tamamlanan kazanç yok.',
          style: TextStyle(color: Colors.white38),
        ),
      ),
    );
  }
}

class _RevenueItem {
  const _RevenueItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  final String title;
  final String subtitle;
  final double amount;
  final DateTime? date;
}
