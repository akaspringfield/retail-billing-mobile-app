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

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  bool lowStock = false;
  late Future<List<Map<String, dynamic>>> future = load();

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

  Future<List<Map<String, dynamic>>> load() {
    final query = search.text.trim();
    return switch (widget.kind) {
      CatalogKind.products => widget.service.products(search: query),
      CatalogKind.stockBalances => widget.service.stockBalances(search: query, lowStock: lowStock),
      CatalogKind.inventoryLedger => widget.service.stockTransactions(product: query),
    };
  }

  void reload() => setState(() => future = load());

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      route: route,
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.kind == CatalogKind.inventoryLedger ? 'Product id' : 'Search',
            ),
            onSubmitted: (_) => reload(),
          ),
          if (widget.kind == CatalogKind.stockBalances)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: lowStock,
              onChanged: (value) {
                lowStock = value ?? false;
                reload();
              },
              title: const Text('Low stock only'),
            ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const LoadingBlock();
              if (snapshot.hasError) return ErrorBlock(message: snapshot.error.toString(), onRetry: reload);
              final records = snapshot.data ?? [];
              if (records.isEmpty) return const InfoCard(child: Text('No records found.'));
              return Column(children: records.map(_tile).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> record) {
    final product = widget.kind == CatalogKind.products;
    final ledger = widget.kind == CatalogKind.inventoryLedger;
    final titleText = product
        ? textValue(record, ['name'])
        : textValue(record, ['product_name', 'name']);
    final subtitle = product
        ? '${textValue(record, ['code', 'sku'])} / ${textValue(record, ['category_name', 'unit_name'])}'
        : ledger
            ? '${textValue(record, ['transaction_type'])} / ${textValue(record, ['store_name'])}'
            : '${textValue(record, ['product_code'])} / ${textValue(record, ['store_name'])}';
    final trailing = product
        ? textValue(readMap(record['current_price']), ['selling_price'], fallback: textValue(record, ['selling_price'], fallback: ''))
        : ledger
            ? '${textValue(record, ['direction'])} ${textValue(record, ['quantity'])}'
            : textValue(record, ['available_quantity', 'quantity']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(titleText, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink))),
                Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 5),
            Text(subtitle),
            if (ledger) ...[
              const SizedBox(height: 5),
              Text(textValue(record, ['reference_number', 'transaction_date'], fallback: ''), style: const TextStyle(color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
