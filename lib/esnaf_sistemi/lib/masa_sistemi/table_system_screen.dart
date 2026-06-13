import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'table_order_screen.dart';
import 'table_service.dart';

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
          appBar: AppBar(
            title: const Text('Masa ve Adisyon Yönetimi'),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.table_restaurant), text: 'Masalar'),
                Tab(icon: Icon(Icons.soup_kitchen), text: 'Mutfak'),
                Tab(icon: Icon(Icons.bar_chart), text: 'Gün Sonu'),
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

class _TableAccessRequired extends StatelessWidget {
  const _TableAccessRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masa Yönetimi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              const Text('Bu özellik restoranınız için henüz aktif değil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const Text(
                  'Masa ve adisyon sistemini aktif etmek için Pazarcık Portal ile iletişime geçin.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Esnaf Paneline Dön')),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TablesTab extends StatelessWidget {
  const _TablesTab({required this.service});

  final RestaurantTableService service;

  Color _statusColor(String status) => switch (status) {
        'occupied' => Colors.red,
        'reserved' => Colors.amber.shade700,
        'bill_requested' => Colors.blue,
        _ => Colors.green,
      };

  String _statusLabel(String status) => switch (status) {
        'occupied' => 'Dolu',
        'reserved' => 'Rezerve',
        'bill_requested' => 'Hesap İstendi',
        _ => 'Boş',
      };

  String _elapsed(dynamic raw) {
    if (raw is! Timestamp) return '';
    final minutes = DateTime.now().difference(raw.toDate()).inMinutes;
    if (minutes < 60) return '$minutes dk';
    return '${minutes ~/ 60} sa ${minutes % 60} dk';
  }

  Future<void> _addTable(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Masa'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Masa adı', hintText: 'Masa 1, Bahçe 3...')),
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
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.event_seat),
            title: const Text('Rezerve yap'),
            onTap: () => Navigator.pop(context, 'reserved')),
        ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Boş olarak işaretle'),
            onTap: () => Navigator.pop(context, 'empty')),
        ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Adını değiştir'),
            onTap: () => Navigator.pop(context, 'rename')),
        ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Masayı sil'),
            onTap: () => Navigator.pop(context, 'delete')),
      ])),
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
                  title: const Text('Masa adını değiştir'),
                  content: TextField(controller: controller, autofocus: true),
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
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addTable(context),
          icon: const Icon(Icons.add),
          label: const Text('Masa Ekle')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.tablesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final tables = snapshot.data!.docs;
          if (tables.isEmpty)
            return const Center(child: Text('Henüz masa eklenmedi.'));
          final width = MediaQuery.of(context).size.width;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: width > 1000
                    ? 5
                    : width > 650
                        ? 3
                        : 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              final data = table.data();
              final status = (data['status'] ?? 'empty').toString();
              final color = _statusColor(status);
              return Card(
                color: color.withValues(alpha: .09),
                child: InkWell(
                  onTap: () => _openTable(context, table),
                  onLongPress: () => _manageTable(context, table),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text((data['name'] ?? 'Masa').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900))),
                            IconButton(
                                tooltip: 'Masa ayarları',
                                onPressed: () => _manageTable(context, table),
                                icon: const Icon(Icons.more_horiz))
                          ]),
                          const Spacer(),
                          Text(_statusLabel(status),
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w900)),
                          if (_elapsed(data['openedAt']).isNotEmpty)
                            Text(_elapsed(data['openedAt']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                        ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _KitchenTab extends StatelessWidget {
  const _KitchenTab({required this.service});
  final RestaurantTableService service;

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
          return const Center(child: Text('Mutfağa gönderilmiş sipariş yok.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data();
            final items = ((data['items'] as List?) ?? const [])
                .where((raw) => (raw as Map)['cancelled'] != true)
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text((data['tableName'] ?? 'Masa').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('Durum: ${data['kitchenStatus'] ?? 'sent'}'),
                children: [
                  ...items.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    return ListTile(
                        title: Text('${item['quantity']} x ${item['name']}'),
                        subtitle: Text([
                          ...(item['modifiers'] as List? ?? const []),
                          if ((item['note'] ?? '').toString().isNotEmpty)
                            item['note']
                        ].join(' • ')));
                  }),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'sent', label: Text('Yeni')),
                        ButtonSegment(
                            value: 'preparing', label: Text('Hazırlanıyor')),
                        ButtonSegment(value: 'ready', label: Text('Hazır'))
                      ],
                      selected: {(data['kitchenStatus'] ?? 'sent').toString()},
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

class _DailyReportTab extends StatefulWidget {
  const _DailyReportTab({required this.service});
  final RestaurantTableService service;

  @override
  State<_DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<_DailyReportTab> {
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.service.todayClosedOrders();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _future,
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
            setState(() => _future = widget.service.todayClosedOrders());
            await _future;
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Z Raporu - Bugün',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          Text('${turnover.toStringAsFixed(2)} TL',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          Text('${snapshot.data!.length} kapatılan adisyon')
                        ]))),
            const SizedBox(height: 12),
            const Text('Ödeme Dağılımı',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ...payments.entries.map((entry) => ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(entry.key),
                trailing: Text('${entry.value.toStringAsFixed(2)} TL'))),
            const Divider(),
            const Text('En Çok Satılanlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ...topProducts.take(10).map((entry) => ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: Text(entry.key),
                trailing: Text('${entry.value} adet'))),
          ]),
        );
      },
    );
  }
}
