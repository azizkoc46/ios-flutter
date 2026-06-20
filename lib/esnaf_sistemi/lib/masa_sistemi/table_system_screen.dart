import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'table_order_screen.dart';
import 'table_service.dart';

// ── Renk & Stil Sabitleri ─────────────────────────────────────────────────────
const _kRadius = 16.0;
const _kCardRadius = BorderRadius.all(Radius.circular(_kRadius));

// ── Ana Ekran ─────────────────────────────────────────────────────────────────
class TableSystemScreen extends StatefulWidget {
  const TableSystemScreen({super.key});

  @override
  State<TableSystemScreen> createState() => _TableSystemScreenState();
}

class _TableSystemScreenState extends State<TableSystemScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final RestaurantTableService _service;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _service = RestaurantTableService(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.permissionStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final enabled = snapshot.data?.data()?['tableServiceEnabled'] == true;
        if (!enabled) return const _TableAccessRequired();
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: const Text('Masa & Adisyon',
                style: TextStyle(fontWeight: FontWeight.w800)),
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: TabBar(
              controller: _tabs,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                    icon: Icon(Icons.table_restaurant_rounded),
                    text: 'Masalar'),
                Tab(icon: Icon(Icons.soup_kitchen_rounded), text: 'Mutfak'),
                Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Gün Sonu'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _TablesTab(service: _service),
              _KitchenTab(service: _service),
              _DailyReportTab(service: _service),
            ],
          ),
        );
      },
    );
  }
}

// ── Erişim Gerekli Ekranı ─────────────────────────────────────────────────────
class _TableAccessRequired extends StatelessWidget {
  const _TableAccessRequired();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded,
                    size: 52, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 28),
              Text('Masa Sistemi Aktif Değil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface)),
              const SizedBox(height: 12),
              Text(
                'Masa ve adisyon sistemini aktif etmek için Pazarcık Portal ile iletişime geçin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: colors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Esnaf Paneline Dön'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Masalar Sekmesi ──────────────────────────────────────────────────────────
class _TablesTab extends StatelessWidget {
  const _TablesTab({required this.service});

  final RestaurantTableService service;

  Color _statusColor(String status) => switch (status) {
        'occupied' => const Color(0xFFE53935),
        'reserved' => const Color(0xFFFB8C00),
        'bill_requested' => const Color(0xFF1E88E5),
        _ => const Color(0xFF43A047),
      };

  IconData _statusIcon(String status) => switch (status) {
        'occupied' => Icons.people_rounded,
        'reserved' => Icons.event_seat_rounded,
        'bill_requested' => Icons.receipt_long_rounded,
        _ => Icons.check_circle_rounded,
      };

  String _statusLabel(String status) => switch (status) {
        'occupied' => 'Dolu',
        'reserved' => 'Rezerve',
        'bill_requested' => 'Hesap',
        _ => 'Boş',
      };

  String _elapsed(dynamic raw) {
    if (raw is! Timestamp) return '';
    final minutes = DateTime.now().difference(raw.toDate()).inMinutes;
    if (minutes < 60) return '$minutes dk';
    return '${minutes ~/ 60}s ${minutes % 60}dk';
  }

  Map<String, Map<String, dynamic>> _activeOrdersByTable(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final order in snapshot?.docs ?? const []) {
      final data = order.data();
      final tableId = (data['tableId'] ?? '').toString();
      if (tableId.isEmpty) continue;
      result[tableId] = {...data, '_id': order.id};
    }
    return result;
  }

  Future<void> _addTable(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Yeni Masa',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Masa adı',
              hintText: 'Masa 1, Bahçe 3...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ekle')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await service.addTable(controller.text);
    }
  }

  Future<void> _openTable(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> table) async {
    final data = table.data();
    final orderId = await service.openOrder(
        tableId: table.id, tableName: (data['name'] ?? 'Masa').toString());
    if (!context.mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TableOrderScreen(
                service: service,
                tableId: table.id,
                tableName: (data['name'] ?? 'Masa').toString(),
                orderId: orderId)));
  }

  Future<void> _manageTable(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> table) async {
    final data = table.data();
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4)),
          ),
          ListTile(
              leading: const Icon(Icons.event_seat_rounded),
              title: const Text('Rezerve yap'),
              onTap: () => Navigator.pop(context, 'reserved')),
          ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('Boş olarak işaretle'),
              onTap: () => Navigator.pop(context, 'empty')),
          ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Adını değiştir'),
              onTap: () => Navigator.pop(context, 'rename')),
          ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title:
                  const Text('Masayı sil', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete')),
        ]),
      )),
    );
    if (action == null) return;
    if (action == 'reserved' || action == 'empty')
      await service.setTableStatus(table.id, action);
    if (action == 'delete') {
      try {
        await service.deleteTable(table.id);
      } catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
    if (action == 'rename' && context.mounted) {
      final controller =
          TextEditingController(text: (data['name'] ?? '').toString());
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('Masa Adını Değiştir',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Kaydet'))
                  ]));
      if (ok == true && controller.text.trim().isNotEmpty)
        await service.renameTable(table.id, controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTable(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Masa Ekle',
            style: TextStyle(fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.tablesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final tables = snapshot.data!.docs;
          if (tables.isEmpty)
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.table_restaurant_rounded,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(.3)),
                const SizedBox(height: 16),
                const Text('Henüz masa eklenmedi.',
                    style: TextStyle(fontSize: 16)),
              ]),
            );
          final width = MediaQuery.of(context).size.width;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.activeOrdersStream(),
            builder: (context, ordersSnapshot) {
              final activeOrders = _activeOrdersByTable(ordersSnapshot.data);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width > 1000
                        ? 5
                        : width > 650
                            ? 3
                            : 2,
                    // FIX: Daha uzun aspect ratio — taşma önlendi
                    childAspectRatio: width > 650 ? 1.0 : 0.95,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final data = table.data();
                  final order = activeOrders[table.id];
                  final status =
                      (order?['tableStatus'] ?? data['status'] ?? 'empty')
                          .toString();
                  final color = _statusColor(status);
                  final total = (order?['grandTotal'] as num?)?.toDouble() ?? 0;
                  final paid = (order?['paidTotal'] as num?)?.toDouble() ?? 0;
                  final balance =
                      (order?['balance'] as num?)?.toDouble() ?? total - paid;
                  final itemCount = ((order?['items'] as List?) ?? const [])
                      .where((item) => (item as Map)['cancelled'] != true)
                      .length;
                  final elapsed =
                      _elapsed(order?['openedAt'] ?? data['openedAt']);
                  return _TableCard(
                    name: (data['name'] ?? 'Masa').toString(),
                    status: status,
                    statusColor: color,
                    statusLabel: _statusLabel(status),
                    statusIcon: _statusIcon(status),
                    elapsed: elapsed,
                    itemCount: itemCount,
                    total: total,
                    balance: balance,
                    hasOrder: order != null,
                    onTap: () => _openTable(context, table),
                    onLongPress: () => _manageTable(context, table),
                    onManage: () => _manageTable(context, table),
                    service: service,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Masa Kartı Widget ─────────────────────────────────────────────────────────
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.elapsed,
    required this.itemCount,
    required this.total,
    required this.balance,
    required this.hasOrder,
    required this.onTap,
    required this.onLongPress,
    required this.onManage,
    required this.service,
  });

  final String name;
  final String status;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final String elapsed;
  final int itemCount;
  final double total;
  final double balance;
  final bool hasOrder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onManage;
  final RestaurantTableService service;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = status == 'empty';
    return Card(
      elevation: isEmpty ? 0 : 2,
      color:
          isEmpty ? colors.surfaceContainerLow : statusColor.withOpacity(.08),
      shape: RoundedRectangleBorder(
        borderRadius: _kCardRadius,
        side: BorderSide(
          color: isEmpty
              ? colors.outlineVariant.withOpacity(.5)
              : statusColor.withOpacity(.35),
          width: isEmpty ? 1 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Masa ayarları',
                      onPressed: onManage,
                      icon: Icon(Icons.more_horiz,
                          size: 20, color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Durum badge — FIX: Flexible ile taşma önlendi
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        // FIX: ConstrainedBox ile badge genişliği sınırlandı
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 70),
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (elapsed.isNotEmpty)
                    Flexible(
                      child: Text(
                        elapsed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              // Sipariş bilgileri
              if (hasOrder) ...[
                const SizedBox(height: 8),
                Text(
                  '$itemCount kalem',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        service.money(total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Kalan ${service.money(balance)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mutfak Sekmesi ────────────────────────────────────────────────────────────
class _KitchenTab extends StatelessWidget {
  const _KitchenTab({required this.service});
  final RestaurantTableService service;

  Color _kitchenColor(String status) => switch (status) {
        'preparing' => const Color(0xFFFB8C00),
        'ready' => const Color(0xFF43A047),
        _ => const Color(0xFF1E88E5),
      };

  String _kitchenLabel(String status) => switch (status) {
        'preparing' => 'Hazırlanıyor',
        'ready' => 'Hazır',
        _ => 'Yeni Sipariş',
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.activeOrdersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!.docs
            .where((doc) => doc.data()['kitchenStatus'] != 'new')
            .toList();
        if (orders.isEmpty)
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.soup_kitchen_rounded,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(.3)),
              const SizedBox(height: 16),
              const Text('Mutfağa gönderilmiş sipariş yok.',
                  style: TextStyle(fontSize: 16)),
            ]),
          );
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data();
            final kitchenStatus = (data['kitchenStatus'] ?? 'sent').toString();
            final statusColor = _kitchenColor(kitchenStatus);
            final items = ((data['items'] as List?) ?? const [])
                .where((raw) => (raw as Map)['cancelled'] != true)
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: _kCardRadius,
                  side: BorderSide(
                      color: statusColor.withOpacity(.4), width: 1.5)),
              elevation: 0,
              color: statusColor.withOpacity(.05),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(borderRadius: _kCardRadius),
                collapsedShape:
                    const RoundedRectangleBorder(borderRadius: _kCardRadius),
                initiallyExpanded: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.soup_kitchen_rounded,
                      color: statusColor, size: 20),
                ),
                title: Text((data['tableName'] ?? 'Masa').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_kitchenLabel(kitchenStatus),
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.w600)),
                children: [
                  const Divider(height: 1),
                  ...items.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    final mods = [
                      ...(item['modifiers'] as List? ?? const []),
                      if ((item['note'] ?? '').toString().isNotEmpty)
                        item['note']
                    ].join(' • ');
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${item['quantity']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      title: Text(item['name'].toString()),
                      subtitle: mods.isNotEmpty ? Text(mods) : null,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'sent',
                            icon: Icon(Icons.fiber_new_rounded),
                            label: Text('Yeni')),
                        ButtonSegment(
                            value: 'preparing',
                            icon: Icon(Icons.local_fire_department_rounded),
                            label: Text('Hazırlanıyor')),
                        ButtonSegment(
                            value: 'ready',
                            icon: Icon(Icons.check_circle_rounded),
                            label: Text('Hazır'))
                      ],
                      selected: {kitchenStatus},
                      onSelectionChanged: (value) =>
                          service.updateOrderStatus(order.id, value.first),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Gün Sonu Sekmesi ──────────────────────────────────────────────────────────
class _DailyReportTab extends StatefulWidget {
  const _DailyReportTab({required this.service});
  final RestaurantTableService service;

  @override
  State<_DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<_DailyReportTab> {
  late Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = widget.service.todayClosedOrdersStream();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final payments = <String, double>{};
        final products = <String, double>{};
        var turnover = 0.0;
        for (final doc in snapshot.data!) {
          final data = doc.data();
          turnover += (data['grandTotal'] as num?)?.toDouble() ?? 0;
          for (final raw in (data['payments'] as List?) ?? const []) {
            final payment = Map<String, dynamic>.from(raw as Map);
            final method = (payment['method'] ?? 'Diğer').toString();
            payments[method] = (payments[method] ?? 0) +
                ((payment['amount'] as num?)?.toDouble() ?? 0);
          }
          for (final raw in (data['items'] as List?) ?? const []) {
            final item = Map<String, dynamic>.from(raw as Map);
            if (item['cancelled'] == true) continue;
            final name = (item['name'] ?? 'Ürün').toString();
            products[name] = (products[name] ?? 0) +
                ((item['quantity'] as num?)?.toDouble() ?? 0);
          }
        }
        final topProducts = products.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _stream = widget.service.todayClosedOrdersStream());
            await _stream.first;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Z Raporu Kartı
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withOpacity(.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: _kCardRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.summarize_rounded,
                          color: colors.onPrimary.withOpacity(.8), size: 18),
                      const SizedBox(width: 8),
                      Text('Z Raporu — Bugün',
                          style: TextStyle(
                              color: colors.onPrimary.withOpacity(.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ]),
                    const SizedBox(height: 12),
                    Text('${turnover.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: colors.onPrimary,
                            letterSpacing: -1)),
                    const SizedBox(height: 4),
                    Text('${snapshot.data!.length} kapatılan adisyon',
                        style: TextStyle(
                            color: colors.onPrimary.withOpacity(.75),
                            fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Ödeme dağılımı
              _SectionHeader(
                  icon: Icons.payments_outlined, title: 'Ödeme Dağılımı'),
              const SizedBox(height: 8),
              ...payments.entries.map((entry) => _ReportRow(
                    label: entry.key,
                    value: '${entry.value.toStringAsFixed(2)} ₺',
                    icon: _paymentIcon(entry.key),
                  )),
              const SizedBox(height: 20),
              _SectionHeader(
                  icon: Icons.trending_up_rounded, title: 'En Çok Satılanlar'),
              const SizedBox(height: 8),
              ...topProducts
                  .take(10)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => _ReportRow(
                        label: e.value.key,
                        value:
                            '${e.value.value.toStringAsFixed(e.value.value % 1 == 0 ? 0 : 1)} adet',
                        icon: Icons.restaurant_menu_rounded,
                        rank: e.key + 1,
                      )),
            ],
          ),
        );
      },
    );
  }

  IconData _paymentIcon(String method) => switch (method.toLowerCase()) {
        'nakit' => Icons.payments_rounded,
        'kredi kartı' || 'kart' => Icons.credit_card_rounded,
        'online' => Icons.phone_android_rounded,
        _ => Icons.account_balance_wallet_rounded,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(
      {required this.label,
      required this.value,
      required this.icon,
      this.rank});
  final String label;
  final String value;
  final IconData icon;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          if (rank != null)
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text('$rank',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer)),
              ),
            )
          else
            Icon(icon, size: 18, color: colors.primary),
          if (rank == null) const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: colors.primary)),
        ]),
      ),
    );
  }
}
