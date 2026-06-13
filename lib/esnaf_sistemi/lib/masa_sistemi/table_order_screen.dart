import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'table_service.dart';

class TableOrderScreen extends StatefulWidget {
  const TableOrderScreen({
    super.key,
    required this.service,
    required this.tableId,
    required this.tableName,
    required this.orderId,
  });

  final RestaurantTableService service;
  final String tableId;
  final String tableName;
  final String orderId;

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  List<Map<String, dynamic>>? _menu;
  bool _menuLoading = true;
  String _selectedCategory = 'Tümü';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu({bool force = false}) async {
    setState(() => _menuLoading = true);
    final menu = await widget.service.loadMenu(force: force);
    if (mounted)
      setState(() {
        _menu = menu;
        _menuLoading = false;
      });
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> order) =>
      List<Map<String, dynamic>>.from(
        ((order['items'] as List?) ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

  Future<void> _addProduct(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> currentItems,
  ) async {
    var quantity = 1.0;
    var portion = (product['portion'] ?? '').toString();
    final selectedExtras = <String>{};
    final noteController = TextEditingController();
    final availableExtras = (product['sideDishes'] ?? '')
        .toString()
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(product['name'],
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: .5, label: Text('Yarım')),
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 1.5, label: Text('1,5')),
                  ButtonSegment(value: 2, label: Text('2')),
                ],
                selected: {quantity},
                onSelectionChanged: (value) =>
                    setSheetState(() => quantity = value.first),
              ),
              if (portion.isNotEmpty) ...[
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: portion,
                  decoration:
                      const InputDecoration(labelText: 'Porsiyon / varyasyon'),
                  onChanged: (value) => portion = value,
                ),
              ],
              if (availableExtras.isNotEmpty) ...[
                const SizedBox(height: 14),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ekstralar',
                        style: Theme.of(context).textTheme.titleMedium)),
                Wrap(
                  spacing: 6,
                  children: availableExtras
                      .map((extra) => FilterChip(
                            label: Text(extra),
                            selected: selectedExtras.contains(extra),
                            onSelected: (selected) => setSheetState(() =>
                                selected
                                    ? selectedExtras.add(extra)
                                    : selectedExtras.remove(extra)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Sipariş notu',
                    hintText: 'Soğansız, az pişmiş...'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add),
                  label: const Text('Adisyona Ekle'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (accepted != true) return;

    final updated = [
      ...currentItems,
      {
        'lineId': DateTime.now().microsecondsSinceEpoch.toString(),
        'productId': product['id'],
        'name': product['name'],
        'quantity': quantity,
        'unitPrice': (product['price'] as num?)?.toDouble() ?? 0,
        'extraPrice': 0.0,
        'modifiers': [if (portion.isNotEmpty) portion, ...selectedExtras],
        'note': noteController.text.trim(),
        'comped': false,
        'cancelled': false,
        'kitchenStatus': 'new',
        'addedAt': DateTime.now().toIso8601String(),
      }
    ];
    await widget.service.saveItems(widget.orderId, updated);
  }

  Future<void> _itemAction(List<Map<String, dynamic>> items, int index,
      Map<String, dynamic> order) async {
    final lineId = (items[index]['lineId'] ?? '').toString();
    final paidQuantity = widget.service.paidQuantities(order)[lineId] ?? 0;
    if (paidQuantity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Ödemesi alınmış ürün iptal veya ikram yapılamaz. Önce ödeme iadesi gerekir.'),
      ));
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: const Text('İkram yap / kaldır'),
            onTap: () => Navigator.pop(context, 'comp')),
        ListTile(
            leading: const Icon(Icons.cancel_outlined, color: Colors.red),
            title: const Text('Ürünü iptal et / geri al'),
            onTap: () => Navigator.pop(context, 'cancel')),
      ])),
    );
    if (action == null) return;
    final updated = [...items];
    final item = {...updated[index]};
    if (action == 'comp') item['comped'] = item['comped'] != true;
    if (action == 'cancel') item['cancelled'] = item['cancelled'] != true;
    updated[index] = item;
    await widget.service.saveItems(widget.orderId, updated);
  }

  Future<void> _paymentDialog(Map<String, dynamic> order) async {
    final total = (order['grandTotal'] as num?)?.toDouble() ?? 0;
    final paid = (order['paidTotal'] as num?)?.toDouble() ?? 0;
    final remaining = (total - paid).clamp(0, double.infinity);
    final items = _items(order)
        .where((item) => item['cancelled'] != true && item['comped'] != true)
        .toList();
    final paidQuantities = widget.service.paidQuantities(order);
    final selectedQuantities = <String, double>{};
    final amountController = TextEditingController();
    var method = 'Nakit';
    var mode = 'amount';

    double itemUnitPrice(Map<String, dynamic> item) =>
        ((item['unitPrice'] as num?)?.toDouble() ?? 0) +
        ((item['extraPrice'] as num?)?.toDouble() ?? 0);

    double selectedTotal() => items.fold<double>(0, (sum, item) {
          final lineId = (item['lineId'] ?? '').toString();
          return sum + (selectedQuantities[lineId] ?? 0) * itemUnitPrice(item);
        });

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        final selectedAmount = selectedTotal();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .82,
              child: Column(children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(
                    child: Text('Paylaşarak Öde',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Masada kalan'),
                    Text('${remaining.toStringAsFixed(2)} TL',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                  ]),
                ]),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'amount',
                        icon: Icon(Icons.payments_outlined),
                        label: Text('Tutar Gir')),
                    ButtonSegment(
                        value: 'items',
                        icon: Icon(Icons.restaurant_menu),
                        label: Text('Ürün Seç')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) =>
                      setSheetState(() => mode = value.first),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Ödeme yöntemi',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: const [
                    'Nakit',
                    'Kredi Kartı',
                    'Ticket',
                    'Sodexo',
                    'Multinet',
                    'Online'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => method = value ?? method),
                ),
                const SizedBox(height: 12),
                if (mode == 'amount')
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Bu kişinin ödediği tutar',
                      hintText: 'Örn. 200',
                      suffixText: 'TL',
                      helperText:
                          'Ödeme sonrası kalan tutar otomatik hesaplanır.',
                      prefixIcon: const Icon(Icons.currency_lira),
                      border: const OutlineInputBorder(),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final lineId = (item['lineId'] ?? '').toString();
                        final ordered =
                            (item['quantity'] as num?)?.toDouble() ?? 1;
                        final alreadyPaid = paidQuantities[lineId] ?? 0;
                        final available =
                            (ordered - alreadyPaid).clamp(0, double.infinity);
                        final selected = selectedQuantities[lineId] ?? 0;
                        final step = ordered % 1 == 0 ? 1.0 : .5;
                        final canAdd = available > selected &&
                            selectedAmount + itemUnitPrice(item) * step <=
                                remaining + .01;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          title: Text((item['name'] ?? 'Ürün').toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            '${itemUnitPrice(item).toStringAsFixed(2)} TL • Kalan ${available.toStringAsFixed(available % 1 == 0 ? 0 : 1)} adet',
                          ),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton.filledTonal(
                              onPressed: selected > 0
                                  ? () => setSheetState(() {
                                        final next = selected - step;
                                        selectedQuantities[lineId] =
                                            next < 0 ? 0 : next;
                                      })
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            SizedBox(
                              width: 42,
                              child: Text(
                                selected
                                    .toStringAsFixed(selected % 1 == 0 ? 0 : 1),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w900),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: canAdd
                                  ? () => setSheetState(() {
                                        selectedQuantities[lineId] =
                                            (selected + step)
                                                .clamp(0, available)
                                                .toDouble();
                                      })
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                if (mode == 'items') ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Seçilen ürün toplamı',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('${selectedAmount.toStringAsFixed(2)} TL',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: mode == 'items' && selectedAmount <= 0
                          ? null
                          : () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(mode == 'items'
                          ? '${selectedAmount.toStringAsFixed(2)} TL Tahsil Et'
                          : 'Ödemeyi Kaydet'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
    if (accepted != true) return;
    final allocations = <Map<String, dynamic>>[];
    final amount = mode == 'items'
        ? selectedTotal()
        : double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0 || amount > remaining + .01) return;
    if (mode == 'items') {
      for (final item in items) {
        final lineId = (item['lineId'] ?? '').toString();
        final quantity = selectedQuantities[lineId] ?? 0;
        if (quantity <= 0) continue;
        allocations.add({
          'lineId': lineId,
          'productId': item['productId'],
          'name': item['name'],
          'quantity': quantity,
          'unitPrice': itemUnitPrice(item),
          'amount': itemUnitPrice(item) * quantity,
        });
      }
    }
    await widget.service.addPayment(
        tableId: widget.tableId,
        orderId: widget.orderId,
        method: method,
        amount: amount,
        allocations: allocations);
    if (amount >= remaining - .01 && mounted) {
      final closeTable = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.task_alt, color: Colors.green, size: 48),
          title: const Text('Ödeme Tamamlandı'),
          content: const Text(
              'Adisyon tamamen ödendi. Masa kapatılıp boş duruma alınsın mı?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Açık Bırak')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.table_restaurant),
                label: const Text('Masayı Kapat')),
          ],
        ),
      );
      if (closeTable == true) {
        await widget.service.closeOrder(
          tableId: widget.tableId,
          orderId: widget.orderId,
        );
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _showReceipt(Map<String, dynamic> order) async {
    final text = widget.service.receiptText(order);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adisyon / Yazıcı Önizleme'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Kopyala')),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.service.orderStream(widget.orderId),
      builder: (context, snapshot) {
        final order = snapshot.data?.data() ?? const <String, dynamic>{};
        final items = _items(order);
        final total = (order['grandTotal'] as num?)?.toDouble() ?? 0;
        final paid = (order['paidTotal'] as num?)?.toDouble() ?? 0;
        final categories = <String>{
          'Tümü',
          ...?_menu?.map((item) => (item['category'] ?? 'Diğer').toString()),
        }.toList();
        final visibleMenu = (_menu ?? const <Map<String, dynamic>>[])
            .where((item) =>
                _selectedCategory == 'Tümü' ||
                (item['category'] ?? 'Diğer').toString() == _selectedCategory)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.tableName),
            actions: [
              IconButton(
                  tooltip: 'Adisyon önizleme',
                  onPressed: () => _showReceipt(order),
                  icon: const Icon(Icons.print_outlined)),
              IconButton(
                  tooltip: 'Hesap istendi',
                  onPressed: () => widget.service
                      .requestBill(widget.tableId, widget.orderId),
                  icon: const Icon(Icons.notifications_active_outlined)),
            ],
          ),
          body: Row(children: [
            Expanded(
              flex: 3,
              child: _menuLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Container(
                          height: 62,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border(
                              bottom: BorderSide(
                                  color: Theme.of(context).dividerColor),
                            ),
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              return ChoiceChip(
                                avatar: Icon(
                                  category == 'Tümü'
                                      ? Icons.apps
                                      : Icons.restaurant_menu,
                                  size: 18,
                                ),
                                label: Text(category),
                                selected: _selectedCategory == category,
                                onSelected: (_) => setState(
                                    () => _selectedCategory = category),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => _loadMenu(force: true),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.of(context).size.width > 900
                                        ? 4
                                        : 2,
                                childAspectRatio: 1.45,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: visibleMenu.length,
                              itemBuilder: (context, index) {
                                final product = visibleMenu[index];
                                return Card(
                                  child: InkWell(
                                    onTap: () => _addProduct(product, items),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(product['name'],
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            const Spacer(),
                                            Text(
                                                '${((product['price'] as num?) ?? 0).toStringAsFixed(2)} TL',
                                                style: const TextStyle(
                                                    color: Colors.deepOrange,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                          ]),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (MediaQuery.of(context).size.width > 700)
              SizedBox(
                  width: 390,
                  child: _buildOrderPanel(items, total, paid, order)),
          ]),
          bottomNavigationBar: MediaQuery.of(context).size.width <= 700
              ? SafeArea(
                  child: ListTile(
                  title: Text(
                      '${items.where((item) => item['cancelled'] != true).length} kalem'),
                  subtitle: Text('Toplam ${total.toStringAsFixed(2)} TL'),
                  trailing: FilledButton(
                      onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SizedBox(
                              height: MediaQuery.of(context).size.height * .8,
                              child:
                                  _buildOrderPanel(items, total, paid, order))),
                      child: const Text('Adisyon')),
                ))
              : null,
        );
      },
    );
  }

  Widget _buildOrderPanel(List<Map<String, dynamic>> items, double total,
      double paid, Map<String, dynamic> order) {
    final paidQuantities = widget.service.paidQuantities(order);
    final payments = List<Map<String, dynamic>>.from(
      ((order['payments'] as List?) ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Adisyon',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text('${total.toStringAsFixed(2)} TL',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ]),
        ),
        Expanded(
            child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final cancelled = item['cancelled'] == true;
            final comped = item['comped'] == true;
            final lineId = (item['lineId'] ?? '').toString();
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
            final linePaid = paidQuantities[lineId] ?? 0;
            final lineRemaining =
                (quantity - linePaid).clamp(0, double.infinity);
            return ListTile(
              enabled: !cancelled,
              onTap: () => _itemAction(items, index, order),
              title: Text('${item['quantity']} x ${item['name']}',
                  style: TextStyle(
                      decoration:
                          cancelled ? TextDecoration.lineThrough : null)),
              subtitle: Text([
                ...((item['modifiers'] as List?) ?? const [])
                    .map((e) => e.toString()),
                if ((item['note'] ?? '').toString().isNotEmpty)
                  'Not: ${item['note']}',
                if (comped) 'İKRAM',
                if (cancelled) 'İPTAL',
                if (linePaid > 0)
                  'Ödenen ${linePaid.toStringAsFixed(linePaid % 1 == 0 ? 0 : 1)} • Kalan ${lineRemaining.toStringAsFixed(lineRemaining % 1 == 0 ? 0 : 1)}',
              ].join(' • ')),
              trailing: Text(comped || cancelled
                  ? '0 TL'
                  : '${((((item['unitPrice'] as num?) ?? 0) + ((item['extraPrice'] as num?) ?? 0)) * ((item['quantity'] as num?) ?? 1)).toStringAsFixed(2)} TL'),
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Ödenen: ${paid.toStringAsFixed(2)} TL'),
              Text(
                  'Kalan: ${(total - paid).clamp(0, double.infinity).toStringAsFixed(2)} TL')
            ]),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('${payments.length} ödeme alındı',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                children: payments.reversed.map((payment) {
                  final allocations =
                      (payment['allocations'] as List?) ?? const [];
                  final detail = allocations.isEmpty
                      ? 'Tutar ödemesi'
                      : allocations.map((raw) {
                          final allocation =
                              Map<String, dynamic>.from(raw as Map);
                          return '${allocation['quantity']} x ${allocation['name']}';
                        }).join(', ');
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.check_circle, color: Colors.green),
                    title: Text((payment['method'] ?? 'Ödeme').toString()),
                    subtitle: Text(detail,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                        '${((payment['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} TL',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => widget.service
                          .updateOrderStatus(widget.orderId, 'sent'),
                      icon: const Icon(Icons.soup_kitchen_outlined),
                      label: const Text('Mutfağa Gönder'))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton.icon(
                      onPressed:
                          total > paid ? () => _paymentDialog(order) : null,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Paylaşarak Öde'))),
            ]),
            if (total <= paid + .01) ...[
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await widget.service.closeOrder(
                            tableId: widget.tableId, orderId: widget.orderId);
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Adisyonu Kapat'))),
            ],
          ]),
        ),
      ]),
    );
  }
}
