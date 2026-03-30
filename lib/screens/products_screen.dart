import 'package:flutter/material.dart';

import '../catalog_service.dart';
import '../data_utils.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.service});

  final CatalogService service;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductData {
  const _ProductData(this.products, this.stocks);
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> stocks;
}

class _ProductsScreenState extends State<ProductsScreen> {
  final search = TextEditingController();
  String stockFilter = '';
  late Future<_ProductData> future = load();

  Future<_ProductData> load() async {
    final result = await Future.wait([
      widget.service.products(),
      widget.service.stockBalances(),
    ]);
    return _ProductData(result[0], result[1]);
  }

  void reload() => setState(() => future = load());

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> openForm([Map<String, dynamic>? product]) async {
    Map<String, dynamic>? detail;
    if (product != null) {
      final id = _id(product['id']);
      if (id == null) return;
      try {
        detail = await widget.service.product(id);
      } catch (error) {
        _error(error);
        return;
      }
    }
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (_) => _ProductForm(service: widget.service, product: detail),
    );
    if (saved == true) reload();
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Products',
        route: '/products',
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: reload,
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: 'Add product',
              onPressed: () => openForm(),
              icon: const Icon(Icons.add)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Products', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search name, code, SKU, or category'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: stockFilter,
              decoration: const InputDecoration(labelText: 'Stock status'),
              items: const [
                DropdownMenuItem(value: '', child: Text('All products')),
                DropdownMenuItem(value: 'IN_STOCK', child: Text('In stock')),
                DropdownMenuItem(value: 'LOW_STOCK', child: Text('Low stock')),
                DropdownMenuItem(
                    value: 'OUT_OF_STOCK', child: Text('Out of stock')),
              ],
              onChanged: (value) => setState(() => stockFilter = value ?? ''),
            ),
            const SizedBox(height: 14),
            FutureBuilder<_ProductData>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const LoadingBlock();
                if (snapshot.hasError)
                  return ErrorBlock(
                      message: snapshot.error.toString(), onRetry: reload);
                final data = snapshot.data!;
                final query = search.text.trim().toLowerCase();
                final visible = data.products.where((product) {
                  final matches = query.isEmpty ||
                      product.values.any(
                          (value) => '$value'.toLowerCase().contains(query));
                  final available = _stockFor(product, data.stocks);
                  final minimum = numberValue(product['minimum_stock']);
                  final statusMatches = stockFilter.isEmpty ||
                      (stockFilter == 'OUT_OF_STOCK' && available <= 0) ||
                      (stockFilter == 'LOW_STOCK' &&
                          available > 0 &&
                          available <= minimum) ||
                      (stockFilter == 'IN_STOCK' && available > minimum);
                  return matches && statusMatches;
                }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(data.products, data.stocks),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      const InfoCard(child: Text('No products found.'))
                    else
                      ...visible
                          .map((product) => _productCard(product, data.stocks)),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Widget _summary(
      List<Map<String, dynamic>> products, List<Map<String, dynamic>> stocks) {
    var low = 0;
    var out = 0;
    for (final product in products) {
      final available = _stockFor(product, stocks);
      if (available <= 0) {
        out++;
      } else if (available <= numberValue(product['minimum_stock'])) {
        low++;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.border))),
      child: Row(children: [
        _metric('Products', '${products.length}'),
        _metric('In stock', '${products.length - low - out}'),
        _metric('Low', '$low'),
        _metric('Out', '$out')
      ]),
    );
  }

  Widget _metric(String label, String value) => Expanded(
          child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w900)),
        Text(label, style: Theme.of(context).textTheme.bodySmall)
      ]));

  Widget _productCard(
      Map<String, dynamic> product, List<Map<String, dynamic>> stocks) {
    final available = _stockFor(product, stocks);
    final minimum = numberValue(product['minimum_stock']);
    final stockLabel = available <= 0
        ? 'Out of stock'
        : available <= minimum
            ? 'Low stock'
            : 'In stock';
    final danger = available <= minimum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openForm(product),
        child: InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(textValue(product, ['name']),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink)),
                      Text('${textValue(product, [
                            'code'
                          ])} / ${textValue(product, ['sku'], fallback: '-')}')
                    ])),
                _badge(product['is_active'] == true ? 'Active' : 'Inactive',
                    product['is_active'] == true),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _value(
                        'Category', textValue(product, ['category_name']))),
                Expanded(
                    child: _value('Unit', textValue(product, ['unit_name']))),
                Expanded(
                    child: _value('Price',
                        'Rs. ${numberValue(product['selling_price']).toStringAsFixed(2)}',
                        primary: true)),
                Expanded(
                    child: _value(stockLabel, available.toStringAsFixed(3),
                        danger: danger)),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _value(String label, String value,
          {bool primary = false, bool danger = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: danger
                    ? AppColors.danger
                    : primary
                        ? AppColors.primary
                        : AppColors.ink,
                fontWeight: FontWeight.w800))
      ]);

  Widget _badge(String label, bool active) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: active ? const Color(0xFFE5F6EA) : const Color(0xFFFFE8E8),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: active ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w800)));

  double _stockFor(
      Map<String, dynamic> product, List<Map<String, dynamic>> stocks) {
    final id = _id(product['id']);
    return stocks.where((stock) => _id(stock['product']) == id).fold<double>(
        0, (sum, stock) => sum + numberValue(stock['available_quantity']));
  }

  int? _id(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  void _error(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
  }
}

class _ProductLookups {
  const _ProductLookups(
      this.stores, this.categories, this.brands, this.units, this.taxes);
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> brands;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> taxes;
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.service, this.product});
  final CatalogService service;
  final Map<String, dynamic>? product;
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final name = TextEditingController(
      text: textValue(widget.product ?? {}, ['name'], fallback: ''));
  late final shortName = TextEditingController(
      text: textValue(widget.product ?? {}, ['short_name'], fallback: ''));
  late final sku = TextEditingController(
      text: textValue(widget.product ?? {}, ['sku'], fallback: ''));
  late final barcode = TextEditingController(text: _barcode(widget.product));
  late final description = TextEditingController(
      text: textValue(widget.product ?? {}, ['description'], fallback: ''));
  late final currentStock = TextEditingController(
      text: _available(widget.product).toStringAsFixed(3));
  late final minimumStock = TextEditingController(
      text: textValue(widget.product ?? {}, ['minimum_stock'], fallback: '0'));
  late final maximumStock = TextEditingController(
      text: textValue(widget.product ?? {}, ['maximum_stock'], fallback: '0'));
  late final purchasePrice =
      TextEditingController(text: _price(widget.product, 'purchase_price'));
  late final sellingPrice =
      TextEditingController(text: _price(widget.product, 'selling_price'));
  late final mrp = TextEditingController(text: _price(widget.product, 'mrp'));
  late final wholesalePrice =
      TextEditingController(text: _price(widget.product, 'wholesale_price'));
  late int? store = _id(widget.product?['store']);
  late int? category = _id(widget.product?['category']);
  late int? brand = _id(widget.product?['brand']);
  late int? unit = _id(widget.product?['unit']);
  late int? tax = _id(widget.product?['tax']);
  late String barcodeType = _barcodeType(widget.product);
  late bool trackStock = widget.product?['track_stock'] ?? true;
  late bool allowNegative = widget.product?['allow_negative_stock'] ?? false;
  late bool isActive = widget.product?['is_active'] ?? true;
  late final Future<_ProductLookups> lookups = _load();
  bool saving = false;
  String error = '';

  static int? _id(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  static List<Map<String, dynamic>> _nested(Object? value) => readList(value);
  static double _available(Map<String, dynamic>? product) =>
      _nested(product?['stocks']).fold<double>(
          0, (sum, stock) => sum + numberValue(stock['available_quantity']));
  static String _barcode(Map<String, dynamic>? product) {
    final rows = _nested(product?['barcodes']);
    return rows.isEmpty ? '' : textValue(rows.first, ['barcode'], fallback: '');
  }

  static String _barcodeType(Map<String, dynamic>? product) {
    final rows = _nested(product?['barcodes']);
    return rows.isEmpty
        ? 'CODE128'
        : textValue(rows.first, ['barcode_type'], fallback: 'CODE128');
  }

  static String _price(Map<String, dynamic>? product, String key) {
    final current = readMap(product?['current_price']);
    return textValue(current, [key],
        fallback: key == 'selling_price'
            ? textValue(product ?? {}, ['selling_price'], fallback: '0.00')
            : '0.00');
  }

  Future<_ProductLookups> _load() async {
    final result = await Future.wait([
      widget.service.stores(),
      widget.service.masterRecords('categories'),
      widget.service.masterRecords('brands'),
      widget.service.masterRecords('units'),
      widget.service.masterRecords('taxes'),
    ]);
    return _ProductLookups(
        result[0], result[1], result[2], result[3], result[4]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ProductLookups>(
        future: lookups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Padding(
                padding: EdgeInsets.all(40), child: LoadingBlock());
          if (snapshot.hasError)
            return Padding(
                padding: const EdgeInsets.all(18),
                child: ErrorBlock(
                    message: snapshot.error.toString(),
                    onRetry: () => Navigator.pop(context)));
          final data = snapshot.data!;
          store ??= data.stores.isEmpty ? null : _id(data.stores.first['id']);
          category ??=
              data.categories.isEmpty ? null : _id(data.categories.first['id']);
          unit ??= data.units.isEmpty ? null : _id(data.units.first['id']);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            widget.product == null
                                ? 'New Product'
                                : 'Edit Product',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))
                  ]),
                  const SizedBox(height: 12),
                  _field(name, 'Name'),
                  _field(shortName, 'Short Name'),
                  _field(sku, 'SKU'),
                  Row(children: [
                    Expanded(child: _field(barcode, 'Barcode')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _options(
                            'Barcode Type',
                            barcodeType,
                            const {
                              'CODE128': 'CODE128',
                              'EAN13': 'EAN-13',
                              'EAN8': 'EAN-8',
                              'UPC': 'UPC'
                            },
                            (v) => barcodeType = v))
                  ]),
                  _select('Store', store, data.stores,
                      (v) => setState(() => store = v),
                      optional: true),
                  _select('Category', category, data.categories,
                      (v) => setState(() => category = v)),
                  _select('Brand', brand, data.brands,
                      (v) => setState(() => brand = v),
                      optional: true),
                  _select('Unit', unit, data.units,
                      (v) => setState(() => unit = v)),
                  _select(
                      'Tax', tax, data.taxes, (v) => setState(() => tax = v),
                      optional: true),
                  _field(description, 'Description', lines: 3),
                  _field(currentStock, 'Current Stock', number: true),
                  Row(children: [
                    Expanded(
                        child: _field(minimumStock, 'Minimum Stock',
                            number: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            _field(maximumStock, 'Maximum Stock', number: true))
                  ]),
                  Row(children: [
                    Expanded(
                        child: _field(purchasePrice, 'Purchase Price',
                            number: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            _field(sellingPrice, 'Selling Price', number: true))
                  ]),
                  Row(children: [
                    Expanded(child: _field(mrp, 'MRP', number: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _field(wholesalePrice, 'Wholesale Price',
                            number: true))
                  ]),
                  _toggle('Track stock', trackStock, (v) => trackStock = v),
                  _toggle('Allow negative stock', allowNegative,
                      (v) => allowNegative = v),
                  _toggle('Active', isActive, (v) => isActive = v),
                  if (error.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(error,
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700))),
                  FilledButton.icon(
                      onPressed: saving ? null : () => save(data),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Saving...' : 'Save Product')),
                  if (widget.product != null)
                    TextButton.icon(
                        onPressed: saving ? null : delete,
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        label: const Text('Delete Product',
                            style: TextStyle(color: AppColors.danger))),
                ]),
          );
        },
      );

  Future<void> save(_ProductLookups data) async {
    if (name.text.trim().isEmpty ||
        category == null ||
        unit == null ||
        store == null) {
      setState(() => error = 'Name, store, category, and unit are required.');
      return;
    }
    if ((double.tryParse(sellingPrice.text) ?? 0) <= 0) {
      setState(() => error = 'Selling price must be greater than zero.');
      return;
    }
    final selectedStore =
        data.stores.firstWhere((item) => _id(item['id']) == store);
    final organization = _id(selectedStore['organization']);
    if (organization == null) {
      setState(() => error = 'Store organization is unavailable.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final desiredStock = double.tryParse(currentStock.text.trim()) ?? 0;
    final existingStock = _available(widget.product);
    final payload = <String, dynamic>{
      'organization': organization,
      'store': store,
      'sku': sku.text.trim(),
      'barcode': barcode.text.trim(),
      'barcode_type': barcodeType,
      'name': name.text.trim(),
      'short_name': shortName.text.trim(),
      'description': description.text.trim(),
      'category': category,
      'brand': brand,
      'unit': unit,
      'tax': tax,
      'opening_stock': '0.000',
      'minimum_stock':
          (double.tryParse(minimumStock.text) ?? 0).toStringAsFixed(3),
      'maximum_stock':
          (double.tryParse(maximumStock.text) ?? 0).toStringAsFixed(3),
      'track_stock': trackStock,
      'allow_negative_stock': allowNegative,
      'purchase_price':
          (double.tryParse(purchasePrice.text) ?? 0).toStringAsFixed(2),
      'selling_price':
          (double.tryParse(sellingPrice.text) ?? 0).toStringAsFixed(2),
      'mrp': (double.tryParse(mrp.text) ?? 0).toStringAsFixed(2),
      'wholesale_price':
          (double.tryParse(wholesalePrice.text) ?? 0).toStringAsFixed(2),
      'is_active': isActive,
    };
    try {
      final productId = _id(widget.product?['id']);
      final saved = productId == null
          ? await widget.service.createProduct(payload)
          : await widget.service.updateProduct(productId, payload);
      final savedId = _id(saved['id']) ?? productId;
      final delta = desiredStock - existingStock;
      if (trackStock && savedId != null && delta.abs() >= 0.001) {
        await widget.service.createStockAdjustmentRequest({
          'organization': organization,
          'store': store,
          'product': savedId,
          'direction': delta >= 0 ? 'IN' : 'OUT',
          'quantity': delta.abs().toStringAsFixed(3),
          'unit_cost':
              (double.tryParse(purchasePrice.text) ?? 0).toStringAsFixed(2),
          'reason': 'SYSTEM_CORRECTION',
          'reference_number': '${textValue(saved, [
                'code'
              ], fallback: textValue(widget.product ?? {}, [
                    'code'
                  ], fallback: 'PRODUCT'))}-${productId == null ? 'INITIAL-STOCK' : 'STOCK-UPDATE'}',
          'remarks':
              'Requested from mobile product form to change current stock from ${existingStock.toStringAsFixed(3)} to ${desiredStock.toStringAsFixed(3)}.',
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(() {
          saving = false;
          error = '$exception';
        });
    }
  }

  Future<void> delete() async {
    final id = _id(widget.product?['id']);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Delete product'),
                content: Text('Delete ${name.text}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true) return;
    try {
      await widget.service.deleteProduct(id);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    }
  }

  Widget _field(TextEditingController controller, String label,
          {int lines = 1, bool number = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: controller,
              maxLines: lines,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              decoration: InputDecoration(labelText: label)));
  Widget _options(String label, String value, Map<String, String> options,
          ValueChanged<String> changed) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: options.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => changed(v));
              }));
  Widget _select(String label, int? value, List<Map<String, dynamic>> records,
          ValueChanged<int?> changed,
          {bool optional = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<int?>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: [
                if (optional)
                  const DropdownMenuItem(value: null, child: Text('None')),
                ...records.map((item) => DropdownMenuItem(
                    value: _id(item['id']),
                    child: Text(
                        textValue(item, ['display_name', 'name', 'code']))))
              ],
              onChanged: changed));
  Widget _toggle(String label, bool value, ValueChanged<bool> changed) =>
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value,
          onChanged: (v) => setState(() => changed(v)));
}
