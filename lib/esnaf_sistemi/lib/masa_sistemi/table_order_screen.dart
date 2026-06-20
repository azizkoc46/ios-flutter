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
  String? _menuError;
  String _selectedCategory = 'Tümü';
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu({bool force = false}) async {
    setState(() {
      _menuLoading = true;
      _menuError = null;
    });
    try {
      final menu = await widget.service.loadMenu(force: force);
      if (mounted) {
        setState(() {
          _menu = menu;
          _menuLoading = false;
          if (menu.isEmpty) {
            _menuError =
                'Menüde ürün bulunamadı. Yayınlanan ürünlerin "Mevcut" durumda olduğundan emin olun.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _menuLoading = false;
          _menuError = 'Menü yüklenemedi: $e';
        });
      }
    }
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
    if (!mounted) return;

    var quantity = 1.0;

    // Porsiyon Dropdown Ayarları
    var portion = (product['portion'] ?? '').toString();
    if (portion.isEmpty || portion == 'null') portion = 'Standart Porsiyon';
    final portionOptions = [
      'Standart Porsiyon',
      'Yarım',
      'Tam',
      '1.5',
      '2',
      'Çift Ekmek'
    ];
    if (!portionOptions.contains(portion)) {
      portionOptions.add(portion);
    }

    final selectedSideDishes = <String>{};
    final noteController = TextEditingController();
    final sideDishes = (product['sideDishes'] ?? '')
        .toString()
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4)),
              ),
              Text(product['name'].toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              if (product['isMonthlyDeal'] == true) ...[
                const SizedBox(height: 6),
                const Chip(
                  avatar: Icon(Icons.local_offer_rounded, size: 17),
                  label: Text('Ayın İndirimli Menüsü'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${((product['price'] as num?) ?? 0).toStringAsFixed(2)} ₺',
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              // Miktar seçimi
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: .5, label: Text('½')),
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 1.5, label: Text('1½')),
                  ButtonSegment(value: 2, label: Text('2')),
                ],
                selected: {quantity},
                onSelectionChanged: (value) =>
                    setSheetState(() => quantity = value.first),
              ),
              const SizedBox(height: 14),
              // Porsiyon Açılır Menüsü (Dropdown)
              DropdownButtonFormField<String>(
                value: portion,
                decoration: InputDecoration(
                  labelText: 'Porsiyon / Özellik',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: portionOptions.map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSheetState(() => portion = val);
                  }
                },
              ),
              if (sideDishes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Yanında Gelenler',
                        style: Theme.of(context).textTheme.titleSmall)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sideDishes
                      .map((sideDish) => FilterChip(
                            label: Text(sideDish),
                            selected: selectedSideDishes.contains(sideDish),
                            onSelected: (selected) => setSheetState(() =>
                                selected
                                    ? selectedSideDishes.add(sideDish)
                                    : selectedSideDishes.remove(sideDish)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Sipariş notu',
                  hintText: 'Soğansız, az pişmiş...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    'Adisyona Ekle  •  ${(((product['price'] as num?) ?? 0) * quantity).toStringAsFixed(2)} ₺',
                  ),
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
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
        'extras': const [],
        'modifiers': [
          if (portion.isNotEmpty && portion != 'Standart Porsiyon') portion,
          ...selectedSideDishes,
        ],
        'isMonthlyDeal': product['isMonthlyDeal'] == true,
        'originalPrice': product['originalPrice'],
        'discount': product['discount'],
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4)),
          ),
          ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: const Text('İkram yap / kaldır'),
              onTap: () => Navigator.pop(context, 'comp')),
          ListTile(
              leading: const Icon(Icons.cancel_rounded, color: Colors.red),
              title: const Text('Ürünü iptal et / geri al',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'cancel')),
        ]),
      )),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(
                    child: Text('Paylaşarak Öde',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Masada kalan', style: TextStyle(fontSize: 12)),
                    Text('${remaining.toStringAsFixed(2)} ₺',
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
                        icon: Icon(Icons.restaurant_menu_rounded),
                        label: Text('Ürün Seç')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) =>
                      setSheetState(() => mode = value.first),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: InputDecoration(
                    labelText: 'Ödeme yöntemi',
                    prefixIcon:
                        const Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                      suffixText: '₺',
                      helperText:
                          'Ödeme sonrası kalan tutar otomatik hesaplanır.',
                      prefixIcon: const Icon(Icons.currency_lira),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${itemUnitPrice(item).toStringAsFixed(2)} ₺ • Kalan ${available.toStringAsFixed(available % 1 == 0 ? 0 : 1)} adet',
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
                      const Text('Seçilen toplam',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('${selectedAmount.toStringAsFixed(2)} ₺',
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
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
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
                          ? '${selectedAmount.toStringAsFixed(2)} ₺ Tahsil Et'
                          : 'Ödemeyi Kaydet'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
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

    // Masada borç kalmadıysa otomatik olarak masayı boş duruma getir
    if (amount >= remaining - .01 && mounted) {
      await widget.service.closeOrder(
        tableId: widget.tableId,
        orderId: widget.orderId,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showReceipt(Map<String, dynamic> order) async {
    final text = widget.service.receiptText(order);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Adisyon Önizleme',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Kopyalandı'),
                    duration: Duration(seconds: 1),
                  ));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Kopyala')),
          FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await widget.service.printReceipt(order);
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Yazdırma başlatılamadı: $error')));
                }
              },
              icon: const Icon(Icons.print_rounded),
              label: const Text('Yazdır')),
          TextButton(
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

        final visibleMenu =
            (_menu ?? const <Map<String, dynamic>>[]).where((item) {
          final matchCat = _selectedCategory == 'Tümü' ||
              (item['category'] ?? 'Diğer').toString() == _selectedCategory;
          final matchSearch = _search.isEmpty ||
              item['name']
                  .toString()
                  .toLowerCase()
                  .contains(_search.toLowerCase());
          return matchCat && matchSearch;
        }).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: Text(widget.tableName,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                  tooltip: 'Menüyü yenile',
                  onPressed: () => _loadMenu(force: true),
                  icon: const Icon(Icons.refresh_rounded)),
              IconButton(
                  tooltip: 'Adisyon yazdır',
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
                  : _menuError != null && ((_menu ?? []).isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_menu_rounded,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(.3)),
                                const SizedBox(height: 16),
                                Text(_menuError!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => _loadMenu(force: true),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Tekrar Dene'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Column(children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (v) =>
                                        setState(() => _search = v),
                                    decoration: InputDecoration(
                                      hintText: 'Ürün ara...',
                                      prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          size: 20),
                                      suffixIcon: _search.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.clear_rounded,
                                                  size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _search = '');
                                              })
                                          : null,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none),
                                      filled: true,
                                      fillColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 48,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    itemCount: categories.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 6),
                                    itemBuilder: (context, index) {
                                      final category = categories[index];
                                      return ChoiceChip(
                                        label: Text(category),
                                        selected: _selectedCategory == category,
                                        onSelected: (_) => setState(
                                            () => _selectedCategory = category),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                      );
                                    },
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    color: Theme.of(context).dividerColor),
                              ]),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () => _loadMenu(force: true),
                                child: visibleMenu.isEmpty
                                    ? Center(
                                        child: Text(
                                          _search.isNotEmpty
                                              ? '"$_search" için sonuç bulunamadı'
                                              : 'Bu kategoride ürün yok',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant),
                                        ),
                                      )
                                    : GridView.builder(
                                        padding: const EdgeInsets.all(12),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: MediaQuery.of(context)
                                                      .size
                                                      .width >
                                                  900
                                              ? 4
                                              : 2,
                                          childAspectRatio: 1.4,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                        itemCount: visibleMenu.length,
                                        itemBuilder: (context, index) {
                                          final product = visibleMenu[index];
                                          return _ProductCard(
                                            product: product,
                                            onTap: () =>
                                                _addProduct(product, items),
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
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      leading: Icon(Icons.receipt_long_rounded,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      title: Text(
                        '${items.where((item) => item['cancelled'] != true).length} kalem',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                      subtitle: Text(
                        'Toplam ${total.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(.75)),
                      ),
                      trailing: FilledButton(
                          onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24))),
                              builder: (_) => SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * .85,
                                  child: _buildOrderPanel(
                                      items, total, paid, order))),
                          child: const Text('Adisyon')),
                    ),
                  ),
                )
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
                bottom: BorderSide(color: colors.outlineVariant, width: .5)),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Adisyon',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${total.toStringAsFixed(2)} ₺',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.primary)),
          ]),
        ),
        Expanded(
            child: ListView.builder(
          padding: EdgeInsets.zero,
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
              dense: true,
              title: Text('${item['quantity']} x ${item['name']}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      decoration:
                          cancelled ? TextDecoration.lineThrough : null)),
              subtitle: Builder(builder: (context) {
                final parts = [
                  ...((item['modifiers'] as List?) ?? const [])
                      .map((e) => e.toString()),
                  if ((item['note'] ?? '').toString().isNotEmpty)
                    'Not: ${item['note']}',
                  if (comped) '🎁 İKRAM',
                  if (cancelled) '❌ İPTAL',
                  if (linePaid > 0)
                    'Ödenen ${linePaid.toStringAsFixed(linePaid % 1 == 0 ? 0 : 1)} • Kalan ${lineRemaining.toStringAsFixed(lineRemaining % 1 == 0 ? 0 : 1)}',
                ];
                return parts.isEmpty
                    ? const SizedBox.shrink()
                    : Text(parts.join(' • '),
                        style: const TextStyle(fontSize: 12));
              }),
              trailing: Text(
                comped || cancelled
                    ? '0 ₺'
                    : '${((((item['unitPrice'] as num?) ?? 0) + ((item['extraPrice'] as num?) ?? 0)) * ((item['quantity'] as num?) ?? 1)).toStringAsFixed(2)} ₺',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: comped || cancelled
                        ? colors.onSurfaceVariant
                        : colors.onSurface),
              ),
            );
          },
        )),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                  top: BorderSide(color: colors.outlineVariant, width: .5))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Ödenen: ${paid.toStringAsFixed(2)} ₺',
                  style: const TextStyle(fontSize: 13)),
              Text(
                  'Kalan: ${(total - paid).clamp(0, double.infinity).toStringAsFixed(2)} ₺',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: colors.primary)),
            ]),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 6),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('${payments.length} ödeme alındı',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
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
                    leading: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 18),
                    title: Text((payment['method'] ?? 'Ödeme').toString(),
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                        '${((payment['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
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
                      icon: const Icon(Icons.soup_kitchen_rounded, size: 18),
                      label: const Text('Mutfağa'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton.icon(
                      onPressed:
                          total > paid ? () => _paymentDialog(order) : null,
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text('Öde'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))))),
            ]),
            if (total <= paid + .01) ...[
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await widget.service.closeOrder(
                            tableId: widget.tableId, orderId: widget.orderId);
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Masayı Kapat'),
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))))),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withOpacity(.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product['name'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, height: 1.3),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${((product['price'] as num?) ?? 0).toStringAsFixed(2)} ₺',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_rounded,
                        size: 16, color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
