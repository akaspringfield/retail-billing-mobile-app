import 'package:flutter/material.dart';

import '../catalog_service.dart';
import '../data_utils.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

enum CatalogKind { products, stockBalances, inventoryLedger }

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.service, required this.kind});

  final CatalogService service;
  final CatalogKind kind;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogData {
  const _CatalogData({
    required this.records,
    this.products = const [],
    this.stores = const [],
    this.pendingAdjustments = const [],
  });

  final List<Map<String, dynamic>> records;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> pendingAdjustments;
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  bool lowStock = false;
  late Future<_CatalogData> future = load();
  _CatalogData? currentData;

  String get title => switch (widget.kind) {
        CatalogKind.products => 'Products',
        CatalogKind.stockBalances => 'Stock Balances',
        CatalogKind.inventoryLedger => 'Inventory Ledger',
      };

  String get route => switch (widget.kind) {
        CatalogKind.products => '/products',
        CatalogKind.stockBalances => '/stock-balances',
        CatalogKind.inventoryLedger => '/inventory-ledger',
      };

  Future<_CatalogData> load() async {
    final query = search.text.trim();
    if (widget.kind == CatalogKind.stockBalances) {
      final results = await Future.wait([
        widget.service.stockBalances(search: query, lowStock: lowStock),
        widget.service.products(),
        widget.service.stores(),
        widget.service.stockAdjustmentRequests(),
      ]);
      return _CatalogData(
        records: results[0],
        products: results[1],
        stores: results[2],
        pendingAdjustments: results[3],
      );
    }

    final records = switch (widget.kind) {
      CatalogKind.products => await widget.service.products(search: query),
      CatalogKind.inventoryLedger =>
        await widget.service.stockTransactions(product: query),
      CatalogKind.stockBalances => <Map<String, dynamic>>[],
    };
    return _CatalogData(records: records);
  }

  void reload() {
    setState(() {
      currentData = null;
      future = load();
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStock = widget.kind == CatalogKind.stockBalances;
    return AppShell(
      title: title,
      route: route,
      actions: [
        if (isStock)
          IconButton(
            tooltip: 'New stock adjustment',
            onPressed: () => _openAdjustment(),
            icon: const Icon(Icons.add),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.kind == CatalogKind.inventoryLedger
                  ? 'Product id'
                  : 'Search products',
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        search.clear();
                        reload();
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => reload(),
          ),
          if (isStock) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: lowStock,
                avatar: Icon(
                  lowStock ? Icons.warning_amber : Icons.inventory_outlined,
                  size: 18,
                ),
                label: const Text('Low stock only'),
                onSelected: (value) {
                  lowStock = value;
                  reload();
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<_CatalogData>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingBlock();
              }
              if (snapshot.hasError) {
                return ErrorBlock(
                  message: snapshot.error.toString(),
                  onRetry: reload,
                );
              }
              final data = snapshot.data ?? const _CatalogData(records: []);
              currentData = data;
              if (isStock) return _stockContent(data);
              if (data.records.isEmpty) {
                return const InfoCard(child: Text('No records found.'));
              }
              return Column(children: data.records.map(_tile).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _stockContent(_CatalogData data) {
    final total = data.records.length;
    final low = data.records.where(_isLowStock).length;
    final available = data.records.fold<double>(
      0,
      (sum, item) => sum + numberValue(item['available_quantity']),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              _metric('Products', '$total'),
              _metric('Low stock', '$low', danger: low > 0),
              _metric('Available', _quantity(available)),
            ],
          ),
        ),
        if (data.pendingAdjustments.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pending approvals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _countBadge(data.pendingAdjustments.length),
            ],
          ),
          const SizedBox(height: 10),
          ...data.pendingAdjustments.map(_adjustmentCard),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Current stock',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              '$total item${total == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.records.isEmpty)
          const InfoCard(child: Text('No stock balances found.'))
        else
          ...data.records.map(_stockCard),
      ],
    );
  }

  Widget _metric(String label, String value, {bool danger = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: danger ? AppColors.danger : AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Color(0xFF8A5B00),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _stockCard(Map<String, dynamic> record) {
    final low = _isLowStock(record);
    final available = numberValue(record['available_quantity']);
    final reserved = numberValue(record['reserved_quantity']);
    final onHand = numberValue(record['quantity']);
    final productName = textValue(record, ['product_name', 'name']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openAdjustment(stock: record),
        child: InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${textValue(record, [
                                'product_code'
                              ])} / ${textValue(record, ['store_name'])}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(low ? 'Low' : 'In stock', low),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _quantityLabel('On hand', onHand),
                  _quantityLabel('Reserved', reserved),
                  _quantityLabel('Available', available, emphasized: true),
                  IconButton(
                    tooltip: 'Adjust stock',
                    onPressed: () => _openAdjustment(stock: record),
                    icon: const Icon(Icons.tune, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quantityLabel(String label, double value, {bool emphasized = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            _quantity(value),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: emphasized ? AppColors.primary : AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, bool danger) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFE8E8) : const Color(0xFFE5F6EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: danger ? AppColors.danger : AppColors.success,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _adjustmentCard(Map<String, dynamic> record) {
    final incoming = record['direction'] == 'IN';
    final id = _intValue(record['id']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  incoming
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: incoming ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    textValue(record, ['product_name']),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  '${incoming ? '+' : '-'}${textValue(record, ['quantity'])}',
                  style: TextStyle(
                    color: incoming ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${textValue(record, ['store_name'])} / ${textValue(record, [
                    'reason'
                  ])}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: id == null ? null : () => _reject(id),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: AppColors.success,
                  ),
                  onPressed: id == null ? null : () => _approve(id),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isLowStock(Map<String, dynamic> record) {
    final available = numberValue(record['available_quantity']);
    final minimum = numberValue(record['minimum_stock']);
    return available <= minimum;
  }

  String _quantity(double value) => value.toStringAsFixed(3);

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _openAdjustment({Map<String, dynamic>? stock}) async {
    var data = currentData;
    if (data == null) {
      try {
        data = await future;
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    final adjustmentData = data;
    if (adjustmentData.products.isEmpty || adjustmentData.stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A product and active store are required.')),
      );
      return;
    }

    int? productId = _intValue(stock?['product']) ??
        _intValue(adjustmentData.products.first['id']);
    int? storeId = _intValue(stock?['store']) ??
        _intValue(adjustmentData.stores.first['id']);
    var direction = 'IN';
    var reason = 'SYSTEM_CORRECTION';
    var saving = false;
    String error = '';
    final quantity = TextEditingController();
    final unitCost = TextEditingController(
      text: stock == null
          ? ''
          : numberValue(stock['average_cost']).toStringAsFixed(2),
    );
    final reference = TextEditingController();
    final remarks = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final parsedQuantity = double.tryParse(quantity.text.trim());
            if (parsedQuantity == null || parsedQuantity <= 0) {
              setSheetState(
                  () => error = 'Quantity must be greater than zero.');
              return;
            }
            if (direction == 'OUT' && reference.text.trim().isEmpty) {
              setSheetState(
                  () => error = 'Reference number is required for stock out.');
              return;
            }
            final selectedStore = adjustmentData.stores.firstWhere(
              (item) => _intValue(item['id']) == storeId,
              orElse: () => adjustmentData.stores.first,
            );
            final organizationId = _intValue(selectedStore['organization']);
            if (organizationId == null ||
                productId == null ||
                storeId == null) {
              setSheetState(() =>
                  error = 'Product, store, and organization are required.');
              return;
            }

            setSheetState(() {
              saving = true;
              error = '';
            });
            try {
              await widget.service.createStockAdjustmentRequest({
                'organization': organizationId,
                'store': storeId,
                'product': productId,
                'direction': direction,
                'quantity': parsedQuantity.toStringAsFixed(3),
                'unit_cost': (double.tryParse(unitCost.text.trim()) ?? 0)
                    .toStringAsFixed(2),
                'reason': reason,
                'reference_number': reference.text.trim(),
                'remarks': remarks.text.trim(),
              });
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Stock adjustment submitted for approval.')),
              );
              reload();
            } catch (exception) {
              setSheetState(() {
                saving = false;
                error = exception.toString();
              });
            }
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Stock adjustment',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: adjustmentData.products.map((item) {
                    return DropdownMenuItem(
                      value: _intValue(item['id']),
                      child: Text(textValue(item, ['name'])),
                    );
                  }).toList(),
                  onChanged: (value) => setSheetState(() => productId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: storeId,
                  decoration: const InputDecoration(labelText: 'Store'),
                  items: adjustmentData.stores.map((item) {
                    return DropdownMenuItem(
                      value: _intValue(item['id']),
                      child: Text(textValue(item, ['name'])),
                    );
                  }).toList(),
                  onChanged: (value) => setSheetState(() => storeId = value),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'IN',
                      icon: Icon(Icons.add),
                      label: Text('Add stock'),
                    ),
                    ButtonSegment(
                      value: 'OUT',
                      icon: Icon(Icons.remove),
                      label: Text('Remove stock'),
                    ),
                  ],
                  selected: {direction},
                  onSelectionChanged: (value) =>
                      setSheetState(() => direction = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    helperText: 'Enter the amount to add or remove',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit cost'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(
                        value: 'SYSTEM_CORRECTION',
                        child: Text('System correction')),
                    DropdownMenuItem(
                        value: 'STOCK_COUNT', child: Text('Stock count')),
                    DropdownMenuItem(
                        value: 'DAMAGE', child: Text('Damaged stock')),
                    DropdownMenuItem(
                        value: 'EXPIRED', child: Text('Expired stock')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reference,
                  decoration: InputDecoration(
                    labelText: 'Reference number',
                    helperText: direction == 'OUT'
                        ? 'Required for stock out'
                        : 'Optional',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarks,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(saving ? 'Submitting...' : 'Submit for approval'),
                ),
              ],
            ),
          );
        },
      ),
    );
    quantity.dispose();
    unitCost.dispose();
    reference.dispose();
    remarks.dispose();
  }

  Future<void> _approve(int id) async {
    try {
      await widget.service.approveStockAdjustmentRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustment approved and stock updated.')),
      );
      reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _reject(int id) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject adjustment'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Review notes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reviewNotes = notes.text.trim();
    notes.dispose();
    if (confirmed != true) return;

    try {
      await widget.service.rejectStockAdjustmentRequest(id, reviewNotes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustment rejected.')),
      );
      reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  void _showError(Object exception) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(exception.toString())),
    );
  }

  Widget _tile(Map<String, dynamic> record) {
    final product = widget.kind == CatalogKind.products;
    final ledger = widget.kind == CatalogKind.inventoryLedger;
    final titleText = product
        ? textValue(record, ['name'])
        : textValue(record, ['product_name', 'name']);
    final subtitle = product
        ? '${textValue(record, ['code', 'sku'])} / ${textValue(record, [
                'category_name',
                'unit_name'
              ])}'
        : '${textValue(record, ['transaction_type'])} / ${textValue(record, [
                'store_name'
              ])}';
    final trailing = product
        ? textValue(
            readMap(record['current_price']),
            ['selling_price'],
            fallback: textValue(record, ['selling_price'], fallback: ''),
          )
        : '${textValue(record, ['direction'])} ${textValue(record, [
                'quantity'
              ])}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  trailing,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(subtitle),
            if (ledger) ...[
              const SizedBox(height: 5),
              Text(
                textValue(
                  record,
                  ['reference_number', 'transaction_date'],
                  fallback: '',
                ),
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
