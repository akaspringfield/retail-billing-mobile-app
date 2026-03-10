import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../pos/presentation/pos_controller.dart';
import '../domain/item_models.dart';
import 'items_controller.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(itemsControllerProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Item'),
        actions: [
          IconButton(
            tooltip: 'Add stock',
            onPressed: () => context.push('/items/add-stock'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: const InputDecoration(
                  labelText: 'Search item, code, or SKU',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  _FilterChipButton(
                    label: 'ALL',
                    selected: !state.lowStockOnly,
                    onTap: () => ref
                        .read(itemsControllerProvider.notifier)
                        .toggleLowStock(false),
                  ),
                  const SizedBox(width: 10),
                  _FilterChipButton(
                    label: 'LOW STOCK',
                    selected: state.lowStockOnly,
                    onTap: () => ref
                        .read(itemsControllerProvider.notifier)
                        .toggleLowStock(true),
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: 'Refresh',
                    onPressed: state.loading
                        ? null
                        : ref.read(itemsControllerProvider.notifier).load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InlineMessage(
                  message: state.errorMessage!,
                  danger: true,
                ),
              ),
            if (state.successMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InlineMessage(message: state.successMessage!),
              ),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      children: [
                        _SectionHeading(
                          title: state.lowStockOnly ? 'Low Stock' : 'All Items',
                        ),
                        for (final stock in state.stocks)
                          _StockRow(
                            stock: stock,
                            onAddStock: () => context.push('/items/add-stock'),
                          ),
                        if (state.stocks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: Text('No stock items found.')),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 96,
        child: FilledButton.icon(
          onPressed: () => context.push('/items/add-stock'),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Add Stock'),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor:
            selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
        foregroundColor: selected ? AppTheme.primary : AppTheme.ink,
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.border,
        ),
      ),
      child: Text(label),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.stock,
    required this.onAddStock,
  });

  final StockBalance stock;
  final VoidCallback onAddStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffedf1f7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.productName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${stock.productCode} · ${stock.storeName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Stock ${stock.availableQuantity.toStringAsFixed(3)} ${stock.unitName}',
                  style: TextStyle(
                    color: stock.isLowStock ? AppTheme.danger : AppTheme.muted,
                    fontWeight:
                        stock.isLowStock ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text('₹${money(stock.averageCost)}'),
              const SizedBox(height: 10),
              IconButton.filledTonal(
                tooltip: 'Add stock',
                onPressed: onAddStock,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key});

  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();
  ProductSummary? _product;
  String _direction = 'IN';

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool saveAndNew}) async {
    if (!_formKey.currentState!.validate() || _product == null) return;
    final ok = await ref.read(itemsControllerProvider.notifier).addStock(
          product: _product!,
          direction: _direction,
          quantity: double.parse(_quantityController.text),
          unitCost: double.tryParse(_unitCostController.text) ?? 0,
          referenceNumber: _referenceController.text,
          remarks: _remarksController.text,
        );
    if (!ok || !mounted) return;
    if (saveAndNew) {
      _quantityController.clear();
      _unitCostController.clear();
      _referenceController.clear();
      _remarksController.clear();
      setState(() => _product = null);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsControllerProvider);
    final stores = ref.watch(posControllerProvider).stores;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Menu Item'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (stores.isNotEmpty)
                Text(
                  'Store: ${ref.watch(posControllerProvider).selectedStore?.name ?? stores.first.name}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductSummary>(
                initialValue: _product,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'Tap to Enter',
                ),
                items: state.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product,
                        child: Text(product.name),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? 'Select an item.' : null,
                onChanged: (value) => setState(() => _product = value),
              ),
              const SizedBox(height: 22),
              const Text('Item Image'),
              const SizedBox(height: 8),
              Container(
                height: 132,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 34),
                      SizedBox(height: 12),
                      Text('Upload Item Image'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                initialValue: _product?.categoryName ?? 'None',
                enabled: false,
                decoration: const InputDecoration(labelText: 'Item Category'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue:
                    _product == null ? '' : money(_product!.sellingPrice),
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Sale Price',
                  suffixText: 'Without Tax',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _direction,
                decoration: const InputDecoration(labelText: 'Stock Direction'),
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('Stock In')),
                  DropdownMenuItem(value: 'OUT', child: Text('Stock Out')),
                ],
                onChanged: (value) =>
                    setState(() => _direction = value ?? 'IN'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current Stock *',
                  hintText: 'Tap to Enter',
                ),
                validator: (value) {
                  final number = double.tryParse(value ?? '');
                  if (number == null || number <= 0) {
                    return 'Enter quantity greater than zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unit Cost'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration:
                    const InputDecoration(labelText: 'Reference Number'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineMessage(message: state.errorMessage!, danger: true),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          state.saving ? null : () => _save(saveAndNew: true),
                      child: const Text('Save & New'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          state.saving ? null : () => _save(saveAndNew: false),
                      child: state.saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Item'),
                    ),
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    this.danger = false,
  });

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.danger : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
