import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../items/domain/item_models.dart';
import '../../items/presentation/items_controller.dart';
import '../../printing/domain/print_service.dart';
import '../../printing/presentation/receipt_actions.dart';
import '../domain/pos_models.dart';
import 'pos_controller.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addProduct(String query) async {
    await ref.read(posControllerProvider.notifier).lookupAndAdd(query);
    _searchController.clear();
  }

  Future<void> _openPaymentSheet(PosState state) async {
    final referenceController = TextEditingController();
    final result = await showModalBottomSheet<CheckoutResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PaymentSheet(
        referenceController: referenceController,
        onConfirm: () async {
          final result =
              await ref.read(posControllerProvider.notifier).checkout(
                    referenceNumber: referenceController.text,
                  );
          if (context.mounted && result != null) {
            Navigator.of(context).pop(result);
          }
        },
      ),
    );
    referenceController.dispose();
    if (result != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _CheckoutSuccess(result: result),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posControllerProvider);
    final items = ref.watch(itemsControllerProvider);
    final controller = ref.read(posControllerProvider.notifier);
    final products = _filteredProducts(items.products);
    final categories = _categories(items.products);

    return Scaffold(
      backgroundColor: const Color(0xfff8f9ff),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(posControllerProvider.notifier).load();
            await ref.read(itemsControllerProvider.notifier).load();
          },
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _PosHeader(
                      state: state,
                      searchController: _searchController,
                      onReload: state.loading ? null : controller.load,
                      onSearch: () => _addProduct(_searchController.text),
                      onStoreTap: () => _pickStore(state),
                      onCartTap: state.cart.isEmpty
                          ? null
                          : () => _openPaymentSheet(state),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryChips(
                      categories: categories,
                      selected: _category,
                      onSelected: (value) => setState(() => _category = value),
                    ),
                  ),
                  if (state.errorMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ErrorBanner(message: state.errorMessage!),
                      ),
                    ),
                  if (items.errorMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ErrorBanner(message: items.errorMessage!),
                      ),
                    ),
                  if (items.loading && products.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (products.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: _EmptyCatalog(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        2,
                        16,
                        state.cart.isEmpty ? 88 : 152,
                      ),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final stock = _stockFor(items.stocks, product);
                          final line = _cartLineFor(state.cart, product);
                          return _ProductCard(
                            product: product,
                            stock: stock,
                            line: line,
                            loading: state.loading,
                            onAdd: () => _addProduct(
                              product.sku.isNotEmpty
                                  ? product.sku
                                  : product.code,
                            ),
                            onDecrease: line == null
                                ? null
                                : () => controller.changeQuantity(
                                      line,
                                      line.quantity - 1,
                                    ),
                            onIncrease: line == null
                                ? null
                                : () => controller.changeQuantity(
                                      line,
                                      line.quantity + 1,
                                    ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: products.length,
                      ),
                    ),
                ],
              ),
              if (state.cart.isNotEmpty)
                _ReviewBillBar(
                  state: state,
                  onTap: () => _openPaymentSheet(state),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<ProductSummary> _filteredProducts(List<ProductSummary> products) {
    final query = _searchController.text.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory =
          _category == 'All' || product.categoryName == _category;
      final haystack =
          '${product.name} ${product.sku} ${product.code} ${product.categoryName}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesCategory && matchesQuery && product.isActive;
    }).toList();
  }

  List<String> _categories(List<ProductSummary> products) {
    final categories = products
        .map((product) => product.categoryName.trim().isEmpty
            ? 'None'
            : product.categoryName.trim())
        .toSet()
        .toList()
      ..sort();
    return ['All', ...categories];
  }

  StockBalance? _stockFor(List<StockBalance> stocks, ProductSummary product) {
    for (final stock in stocks) {
      if (stock.productId == product.id) return stock;
    }
    return null;
  }

  CartLine? _cartLineFor(List<CartLine> cart, ProductSummary product) {
    for (final line in cart) {
      if (line.product.productId == product.id) return line;
    }
    return null;
  }

  Future<void> _pickStore(PosState state) async {
    final selected = await showModalBottomSheet<StoreInfo>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Store',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...state.stores.map(
                (store) => ListTile(
                  leading: const Icon(Icons.store_outlined),
                  title: Text(store.name),
                  subtitle: Text(store.code.isEmpty ? 'Store' : store.code),
                  trailing: state.selectedStore?.id == store.id
                      ? const Icon(Icons.check_circle, color: AppTheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(store),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      ref.read(posControllerProvider.notifier).selectStore(selected);
      await ref.read(itemsControllerProvider.notifier).load();
    }
  }
}

class _PosHeader extends StatefulWidget {
  const _PosHeader({
    required this.state,
    required this.searchController,
    required this.onReload,
    required this.onSearch,
    required this.onStoreTap,
    required this.onCartTap,
  });

  final PosState state;
  final TextEditingController searchController;
  final VoidCallback? onReload;
  final VoidCallback onSearch;
  final VoidCallback onStoreTap;
  final VoidCallback? onCartTap;

  @override
  State<_PosHeader> createState() => _PosHeaderState();
}

class _PosHeaderState extends State<_PosHeader> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _PosHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_refresh);
      widget.searchController.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0f000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: widget.onStoreTap,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xffeff4ff),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child:
                      const Icon(Icons.point_of_sale, color: Color(0xff0b1c30)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POS / Quick Bill',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xff0b1c30),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xff007f36),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.state.selectedStore?.name ??
                                'Select store before billing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff36445f),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _CartBadge(
                count: widget.state.cart.length,
                onTap: widget.onCartTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xffeff4ff),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: TextField(
                    controller: widget.searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => widget.onSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Scan barcode or search item',
                      prefixIcon: Icon(Icons.search, color: Color(0xff545f73)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 52,
                child: FilledButton(
                  onPressed: widget.state.loading ? null : widget.onSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: widget.state.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_scanner, size: 25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 15, color: Color(0xff545f73)),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Supports: Name - SKU - Barcode (UPC/EAN) - Code',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xff36445f),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/items/add-stock'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Quick Add'),
                    Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = categories[index];
          final active = category == selected;
          return ChoiceChip(
            selected: active,
            label: Text(category),
            showCheckmark: false,
            onSelected: (_) => onSelected(category),
            selectedColor: AppTheme.primary,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xff36445f),
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: active ? AppTheme.primary : const Color(0xffe8edf8),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.stock,
    required this.line,
    required this.loading,
    required this.onAdd,
    required this.onDecrease,
    required this.onIncrease,
  });

  final ProductSummary product;
  final StockBalance? stock;
  final CartLine? line;
  final bool loading;
  final VoidCallback onAdd;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final available = stock?.availableQuantity ?? 0;
    final minimum = stock?.minimumStock ?? 0;
    final out = available <= 0;
    final low = !out && minimum > 0 && available <= minimum;

    return Opacity(
      opacity: out ? 0.68 : 1,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffe8edf8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StockPill(out: out, low: low),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${product.categoryName} - ${product.unitName.isEmpty ? 'Unit' : product.unitName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff36445f),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff0b1c30),
                fontSize: 17,
                height: 1.18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'SKU-${product.sku.isEmpty ? product.code : product.sku} - Barcode: ${product.code}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff36445f),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unit Price',
                        style: TextStyle(
                          color: Color(0xff36445f),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Rs. ${money(product.sellingPrice)}',
                        style: TextStyle(
                          color: out ? const Color(0xff737686) : Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          decoration: out ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        'Available: ${available.toStringAsFixed(3)} Units',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: out || low
                              ? AppTheme.danger
                              : const Color(0xff007f36),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (out)
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.block, size: 17),
                    label: const Text('Unavailable'),
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: const Color(0xffe5eeff),
                      disabledForegroundColor: const Color(0xff737686),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(132, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else if (line == null)
                  FilledButton.icon(
                    onPressed: loading ? null : onAdd,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      minimumSize: const Size(108, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else
                  _QuantityStepper(
                    quantity: line!.quantity,
                    onDecrease: onDecrease,
                    onIncrease: onIncrease,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffdce9ff),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove, onTap: onDecrease, light: true),
          SizedBox(
            width: 42,
            child: Text(
              quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff0b1c30),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.light = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: light ? Colors.white : AppTheme.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          color: light ? const Color(0xff0b1c30) : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _ReviewBillBar extends StatelessWidget {
  const _ReviewBillBar({
    required this.state,
    required this.onTap,
  });

  final PosState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemCount = state.cart.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xff213145),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long,
                  color: Color(0xffb4c5ff), size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${itemCount.toStringAsFixed(itemCount % 1 == 0 ? 0 : 2)} ITEMS SCANNED',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffb4c5ff),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total: Rs. ${money(state.grandTotal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: state.checkingOut ? null : onTap,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Review Bill'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(138, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xffdbe1ff),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: AppTheme.primary, size: 25),
          ),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({
    required this.out,
    required this.low,
  });

  final bool out;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final label = out
        ? 'OUT OF STOCK'
        : low
            ? 'LOW STOCK'
            : 'IN STOCK';
    final bg = out
        ? const Color(0xffffdad6)
        : low
            ? const Color(0xffd5e0f8)
            : const Color(0xffc7ffca);
    final fg = out
        ? AppTheme.danger
        : low
            ? const Color(0xff111c2d)
            : const Color(0xff007f36);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerWidget {
  const _PaymentSheet({
    required this.referenceController,
    required this.onConfirm,
  });

  final TextEditingController referenceController;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(posControllerProvider);
    final controller = ref.read(posControllerProvider.notifier);
    final totalUnits = current.cart.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.96,
        child: Column(
          children: [
            _BillingAppBar(
              itemCount: current.cart.length,
              storeName: current.selectedStore?.name ?? 'Apex Supermarket',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 132,
                ),
                children: [
                  _BillingCustomerCard(state: current),
                  const SizedBox(height: 18),
                  const _BillingSectionHeader(),
                  const SizedBox(height: 10),
                  ...current.cart.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BillingCartLine(
                        line: line,
                        onDecrease: () =>
                            controller.changeQuantity(line, line.quantity - 1),
                        onIncrease: () =>
                            controller.changeQuantity(line, line.quantity + 1),
                        onDelete: () => controller.removeLine(line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('+ Add More Items (Scan / Search)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd5e0f8),
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BillingBreakdown(
                    state: current,
                    itemCount: current.cart.length,
                    totalUnits: totalUnits,
                  ),
                  const SizedBox(height: 14),
                  _PaymentMethodSelector(
                    current: current,
                    referenceController: referenceController,
                  ),
                  const SizedBox(height: 14),
                  _QuickCash(total: current.grandTotal),
                ],
              ),
            ),
            _BillingActionFooter(
              total: current.grandTotal,
              checkingOut: current.checkingOut,
              onHold: () => Navigator.of(context).pop(),
              onClear: () {
                controller.newSale();
                Navigator.of(context).pop();
              },
              onPay:
                  current.cart.isEmpty || current.selectedPaymentMethod == null
                      ? null
                      : onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingAppBar extends StatelessWidget {
  const _BillingAppBar({
    required this.itemCount,
    required this.storeName,
    required this.onBack,
  });

  final int itemCount;
  final String storeName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0f000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xffeff4ff),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.arrow_back, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Current Bill',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xff0b1c30),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _BillingPill(
                      label: 'LANE 04',
                      background: const Color(0xffd5e0f8),
                      foreground: const Color(0xff586377),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$itemCount items - $storeName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff545f73),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xffeff4ff),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long, size: 17, color: AppTheme.primary),
                SizedBox(width: 5),
                Text(
                  '#ORD-8921',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingCustomerCard extends ConsumerWidget {
  const _BillingCustomerCard({required this.state});

  final PosState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = state.selectedCustomer;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe8edf8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xffdbe1ff),
                foregroundColor: const Color(0xff00174b),
                child: Text(
                  _initials(customer?.name ?? 'Walk-in'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer?.name ?? 'Walk-in Customer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff0b1c30),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _BillingPill(
                          label: customer == null ? 'OPEN' : 'VIP',
                          background: const Color(0xff7ffc97),
                          foreground: const Color(0xff002109),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer?.phone ?? 'No customer selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff545f73),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _pickCustomer(context, ref),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.expand_more, size: 17),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xffeff4ff),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xffeff4ff),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, size: 18, color: Color(0xff007f36)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Loyalty balance: ',
                      children: [
                        TextSpan(
                          text: '240 pts',
                          style: TextStyle(
                            color: Color(0xff0b1c30),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: Color(0xff545f73),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_note, size: 17),
                  label: const Text('ADD NOTE'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(82, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomer(BuildContext context, WidgetRef ref) async {
    final queryController = TextEditingController();
    final selected = await showModalBottomSheet<CustomerInfo?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _CustomerSheet(
        customers: state.customers,
        queryController: queryController,
      ),
    );
    queryController.dispose();
    ref.read(posControllerProvider.notifier).selectCustomer(selected);
  }
}

class _BillingSectionHeader extends StatelessWidget {
  const _BillingSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Scanned Cart Line\nItems',
            style: TextStyle(
              color: Color(0xff0b1c30),
              fontSize: 19,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          'SWIPE RIGHT FOR\nDISCOUNTS',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Color(0xff36445f),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _BillingCartLine extends StatelessWidget {
  const _BillingCartLine({
    required this.line,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDelete,
  });

  final CartLine line;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe8edf8)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xffeff4ff),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _initials(line.product.name),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff0b1c30),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          line.product.unit.isEmpty
                              ? 'Unit'
                              : line.product.unit,
                          style: const TextStyle(
                            color: Color(0xff545f73),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _BillingPill(
                          label:
                              '${line.product.code} - SKU-${line.product.sku}',
                          background: const Color(0xffdce9ff),
                          foreground: const Color(0xff36445f),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                onPressed: onDelete,
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xff36445f)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xffeff4ff),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _BillingQtyButton(icon: Icons.remove, onTap: onDecrease),
                    SizedBox(
                      width: 58,
                      child: Text(
                        line.quantity.toStringAsFixed(3),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff0b1c30),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _BillingQtyButton(icon: Icons.add, onTap: onIncrease),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${money(line.unitPrice)} each',
                    style: const TextStyle(
                      color: Color(0xff36445f),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Rs. ${money(line.total)}',
                    style: const TextStyle(
                      color: Color(0xff0b1c30),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BillingPill(
                label:
                    'Tax (GST): ${line.taxPercent.toStringAsFixed(0)}% - Disc: ${line.discountPercent.toStringAsFixed(0)}%',
                background: const Color(0xffdce9ff),
                foreground: const Color(0xff36445f),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 14, color: Color(0xff007f36)),
                  const SizedBox(width: 3),
                  Text(
                    'In Stock (${line.product.availableQuantity.toStringAsFixed(0)})',
                    style: const TextStyle(
                      color: Color(0xff007f36),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillingQtyButton extends StatelessWidget {
  const _BillingQtyButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xff0b1c30)),
      ),
    );
  }
}

class _BillingBreakdown extends StatelessWidget {
  const _BillingBreakdown({
    required this.state,
    required this.itemCount,
    required this.totalUnits,
  });

  final PosState state;
  final int itemCount;
  final double totalUnits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe8edf8)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Bill Breakdown',
                  style: TextStyle(
                    color: Color(0xff0b1c30),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'INR CURRENCY',
                style: TextStyle(
                  color: Color(0xff36445f),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BillingAmountRow(label: 'Subtotal', value: state.subtotal),
          _BillingAmountRow(
            label: 'Discount (Promo)',
            value: -state.discount,
            actionLabel: '+ Apply Coupon',
            valueColor: const Color(0xff007f36),
          ),
          _BillingAmountRow(
            label: 'Tax (GST Breakdown)',
            value: state.tax,
            icon: Icons.info_outline,
          ),
          const _BillingAmountRow(label: 'Round Off', value: 0),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xffeff4ff),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL PAYABLE',
                        style: TextStyle(
                          color: Color(0xff545f73),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$itemCount items - ${totalUnits.toStringAsFixed(3)} Units',
                        style: const TextStyle(
                          color: Color(0xff36445f),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs. ${money(state.grandTotal)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingAmountRow extends StatelessWidget {
  const _BillingAmountRow({
    required this.label,
    required this.value,
    this.actionLabel,
    this.icon,
    this.valueColor = const Color(0xff0b1c30),
  });

  final String label;
  final double value;
  final String? actionLabel;
  final IconData? icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff36445f),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, size: 15, color: const Color(0xff737686)),
                ],
                if (actionLabel != null) ...[
                  const SizedBox(width: 6),
                  _BillingPill(
                    label: actionLabel!,
                    background: const Color(0xffdbe1ff),
                    foreground: AppTheme.primary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${value < 0 ? '-' : ''}Rs. ${money(value.abs())}',
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSelector extends ConsumerWidget {
  const _PaymentMethodSelector({
    required this.current,
    required this.referenceController,
  });

  final PosState current;
  final TextEditingController referenceController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe8edf8)),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<PaymentMethodInfo>(
            initialValue: current.selectedPaymentMethod,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: current.paymentMethods
                .map(
                  (method) => DropdownMenuItem(
                    value: method,
                    child: Text(method.name),
                  ),
                )
                .toList(),
            onChanged: (method) {
              if (method != null) {
                ref
                    .read(posControllerProvider.notifier)
                    .selectPaymentMethod(method);
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: referenceController,
            decoration: InputDecoration(
              labelText:
                  current.selectedPaymentMethod?.requiresReference == true
                      ? 'Reference number'
                      : 'Reference number optional',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCash extends StatelessWidget {
  const _QuickCash({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final rounded = (total / 50).ceil() * 50;
    final values = [rounded, 1000, 2000].where((value) => value > 0).toList();
    return Row(
      children: [
        const Text(
          'QUICK CASH:',
          style: TextStyle(
            color: Color(0xff36445f),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const Spacer(),
        ...values.map(
          (value) => Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rs. $value',
                style: const TextStyle(
                  color: Color(0xff0b1c30),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingActionFooter extends StatelessWidget {
  const _BillingActionFooter({
    required this.total,
    required this.checkingOut,
    required this.onHold,
    required this.onClear,
    required this.onPay,
  });

  final double total;
  final bool checkingOut;
  final VoidCallback onHold;
  final VoidCallback onClear;
  final Future<void> Function()? onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1a000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onHold,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Hold Bill'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffeff4ff),
                    foregroundColor: const Color(0xff545f73),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.remove_shopping_cart_outlined),
                  label: const Text('Clear Cart'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffffdad6),
                    foregroundColor: const Color(0xff93000a),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: checkingOut || onPay == null ? null : () => onPay!(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: checkingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(Icons.point_of_sale, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'Pay Bill',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Rs. ${money(total)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 22),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingPill extends StatelessWidget {
  const _BillingPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'RB';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
      .toUpperCase();
}

class _CustomerSheet extends StatefulWidget {
  const _CustomerSheet({
    required this.customers,
    required this.queryController,
  });

  final List<CustomerInfo> customers;
  final TextEditingController queryController;

  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((customer) {
      final text =
          '${customer.name} ${customer.code} ${customer.phone}'.toLowerCase();
      return text.contains(query.toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.queryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search customer',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Walk-in Customer'),
              onTap: () => Navigator.of(context).pop(null),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: Text(
                      [customer.code, customer.phone]
                          .where((v) => v.isNotEmpty)
                          .join(' - '),
                    ),
                    onTap: () => Navigator.of(context).pop(customer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSuccess extends ConsumerWidget {
  const _CheckoutSuccess({required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printService = ref.watch(printServiceProvider);
    return AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xffc7ffca),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Color(0xff007f36), size: 38),
      ),
      title: const Text('Bill Created Successfully'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SuccessRow(label: 'Invoice', value: result.invoiceNumber),
          _SuccessRow(label: 'Total Amount', value: 'Rs. ${result.grandTotal}'),
          _SuccessRow(label: 'Payment', value: result.paymentMethodName),
          _SuccessRow(label: 'Status', value: result.paymentStatus),
          const SizedBox(height: 12),
          const Text(
            'Invoice is ready for print, PDF preview, or sharing.',
            style: TextStyle(color: Color(0xff545f73)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/bills');
          },
          child: const Text('View Invoice'),
        ),
        TextButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            try {
              await printService.shareInvoice(result.invoiceNumber);
            } catch (_) {
              messenger?.showSnackBar(
                const SnackBar(content: Text('Unable to share invoice PDF.')),
              );
            }
          },
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF'),
        ),
        ReceiptPrintButton(invoiceNumber: result.invoiceNumber),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(posControllerProvider.notifier).newSale();
          },
          child: const Text('New Sale'),
        ),
      ],
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff545f73),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff0b1c30),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: AppTheme.danger)),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe8edf8)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: Color(0xff545f73)),
          SizedBox(height: 10),
          Text(
            'No products found',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Add products or change the selected category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff545f73)),
          ),
        ],
      ),
    );
  }
}
