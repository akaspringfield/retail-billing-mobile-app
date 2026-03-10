import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../items/presentation/items_controller.dart';
import '../../pos/presentation/pos_controller.dart';
import '../../reports/presentation/reports_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final pos = ref.watch(posControllerProvider);
    final items = ref.watch(itemsControllerProvider);
    final reports = ref.watch(reportsControllerProvider);
    final metrics = reports.summary?.metrics ?? {};
    final salesAmount = _number(metrics['sales_amount']);
    final salesCount = _number(metrics['sales_count']).round();
    final products = items.products.length;
    final lowStock = reports.summary?.lowStock.length ?? 0;
    final outOfStock = items.stocks
        .where((stock) => _number(stock.availableQuantity) <= 0)
        .length;
    final inStock = (products - outOfStock).clamp(0, products);

    return Scaffold(
      backgroundColor: const Color(0xfff8f9ff),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(posControllerProvider.notifier).load();
            await ref.read(itemsControllerProvider.notifier).load();
            await ref.read(reportsControllerProvider.notifier).load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            children: [
              _TopIdentityBar(
                businessName:
                    auth.user?.organizationName ?? 'BAPU\'S OVEN Retail',
                storeName: pos.selectedStore?.name ?? 'Terminal 04',
              ),
              const SizedBox(height: 14),
              _NewSaleButton(onTap: () => context.go('/pos')),
              const SizedBox(height: 14),
              _SalesCard(
                salesAmount: salesAmount,
                salesCount: salesCount,
              ),
              const SizedBox(height: 12),
              _ActionGrid(
                productCount: products,
                outOfStock: outOfStock,
                onNewSale: () => context.go('/pos'),
                onItems: () => context.go('/items'),
                onCustomers: () => context.go('/settings'),
                onStock: () => context.go('/items'),
              ),
              const SizedBox(height: 18),
              _InventoryStatus(
                total: products,
                inStock: inStock,
                lowStock: lowStock,
                outOfStock: outOfStock,
                onViewAll: () => context.go('/items'),
              ),
              const SizedBox(height: 18),
              _RecentInvoices(
                invoiceCount: salesCount,
                onViewAll: () => context.go('/bills'),
              ),
              if (pos.errorMessage != null || items.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: pos.errorMessage ?? items.errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

double _number(Object? value) => double.tryParse('$value') ?? 0;

class _TopIdentityBar extends StatelessWidget {
  const _TopIdentityBar({
    required this.businessName,
    required this.storeName,
  });

  final String businessName;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xffdce9ff),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_outlined, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff0b1c30),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _SmallPill(label: 'POS 4'),
                ],
              ),
              const SizedBox(height: 3),
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
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '$storeName - Cloud Synced',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff545f73),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _IconSquare(
          icon: Icons.notifications_none,
          showDot: true,
          onTap: () {},
        ),
        const SizedBox(width: 8),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xffc7a866),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: Text(
              'B',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewSaleButton extends StatelessWidget {
  const _NewSaleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: AppTheme.primary.withValues(alpha: 0.25),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+ New Sale / Start Billing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Instant barcode scan - Quick checkout',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xffeef2ff),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.qr_code_scanner, size: 21),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 24),
          ],
        ),
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({
    required this.salesAmount,
    required this.salesCount,
  });

  final double salesAmount;
  final int salesCount;

  @override
  Widget build(BuildContext context) {
    final avgBasket = salesCount == 0 ? 0 : salesAmount / salesCount;
    return _Panel(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 22, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Today's Sales",
                  style: TextStyle(
                    color: Color(0xff0b1c30),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SmallPill(label: 'TODAY'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rs. ${money(salesAmount)}',
                      style: const TextStyle(
                        color: Color(0xff0b1c30),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.arrow_upward,
                            size: 16, color: Color(0xff007f36)),
                        Text(
                          '12.4%',
                          style: TextStyle(
                            color: Color(0xff007f36),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'vs yesterday',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xff545f73),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _Sparkline(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'Invoices',
                  value: '$salesCount Bills',
                  detail: 'live/hr',
                  valueColor: const Color(0xff0b1c30),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MetricTile(
                  title: 'Avg Basket',
                  value: 'Rs. ${money(avgBasket)}',
                  detail: '+3.2 items',
                  valueColor: const Color(0xff0b1c30),
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: _MetricTile(
                  title: 'Cash / Dig',
                  value: '40% / 60%',
                  detail: 'cash / online',
                  valueColor: Color(0xff0b1c30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.productCount,
    required this.outOfStock,
    required this.onNewSale,
    required this.onItems,
    required this.onCustomers,
    required this.onStock,
  });

  final int productCount;
  final int outOfStock;
  final VoidCallback onNewSale;
  final VoidCallback onItems;
  final VoidCallback onCustomers;
  final VoidCallback onStock;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.78,
      children: [
        _ActionTile(
          icon: Icons.add_shopping_cart,
          title: 'New Sale',
          subtitle: 'Open Register',
          badge: 'POS #4',
          badgeColor: const Color(0xffdbe1ff),
          onTap: onNewSale,
        ),
        _ActionTile(
          icon: Icons.inventory_2_outlined,
          title: 'Items Catalog',
          subtitle: '$productCount SKUs',
          badge: 'Active',
          badgeColor: Colors.transparent,
          onTap: onItems,
        ),
        _ActionTile(
          icon: Icons.groups_2_outlined,
          title: 'Customers',
          subtitle: 'Loyalty & Balance',
          badge: 'VIP Club',
          badgeColor: const Color(0xffd5e0f8),
          onTap: onCustomers,
        ),
        _ActionTile(
          icon: Icons.qr_code_scanner,
          title: 'Stock Count',
          subtitle: 'Barcode Audits',
          badge: '$outOfStock Out',
          badgeColor: const Color(0xffffdad6),
          onTap: onStock,
        ),
      ],
    );
  }
}

class _InventoryStatus extends StatelessWidget {
  const _InventoryStatus({
    required this.total,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.onViewAll,
  });

  final int total;
  final int inStock;
  final int lowStock;
  final int outOfStock;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Inventory Status',
              style: TextStyle(
                color: Color(0xff0b1c30),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xff007f36),
                shape: BoxShape.circle,
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ),
        _Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _InventoryCounter(title: 'Total', value: total)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _InventoryCounter(
                      title: 'In Stock',
                      value: inStock,
                      color: const Color(0xff007f36),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                      child: _InventoryCounter(
                          title: 'Low Stock', value: lowStock)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _InventoryCounter(
                      title: 'Out',
                      value: outOfStock,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xffd5e0f8).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        size: 18, color: Color(0xff586377)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Fast-moving items reached threshold',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xff586377),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onViewAll,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(64, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'REORDER',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentInvoices extends StatelessWidget {
  const _RecentInvoices({
    required this.invoiceCount,
    required this.onViewAll,
  });

  final int invoiceCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final invoices = [
      const _InvoiceData(
        number: '#INV-2024-1082',
        time: '4m ago',
        customer: 'Customer: Walk-in Customer',
        amount: 'Rs. 142.50',
        status: 'Paid (Card)',
        items: '5 items - Cashier 042',
      ),
      const _InvoiceData(
        number: '#INV-2024-1081',
        time: '18m ago',
        customer: 'Robert Harris (VIP #190)',
        amount: 'Rs. 89.20',
        status: 'Paid (Cash)',
        items: '3 items - Cashier 042',
      ),
      const _InvoiceData(
        number: '#INV-2024-1080',
        time: '34m ago',
        customer: 'Customer: Sarah Miller',
        amount: 'Rs. 320.00',
        status: 'Paid (QR/UPI)',
        items: '11 items - Cashier 042',
      ),
      const _InvoiceData(
        number: '#INV-2024-1079',
        time: '52m ago',
        customer: 'Metro Cafe Ltd (Wholesale)',
        amount: 'Rs. 512.75',
        status: 'Split Pay',
        items: '18 items - Cashier 042',
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Recent Invoices',
              style: TextStyle(
                color: Color(0xff0b1c30),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            const _SmallPill(label: 'Live'),
            const Spacer(),
            TextButton(
              onPressed: onViewAll,
              child: Text('View All ($invoiceCount)'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ...invoices.map(
          (invoice) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InvoiceCard(invoice: invoice, onView: onViewAll),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffe8edf8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xffdce9ff),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppTheme.primary, size: 23),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: badgeColor == const Color(0xffffdad6)
                            ? AppTheme.danger
                            : const Color(0xff586377),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff0b1c30),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff545f73),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.detail,
    required this.valueColor,
  });

  final String title;
  final String value;
  final String detail;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffeff4ff),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff545f73),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff545f73),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCounter extends StatelessWidget {
  const _InventoryCounter({
    required this.title,
    required this.value,
    this.color = const Color(0xff0b1c30),
  });

  final String title;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xffeff4ff),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color == const Color(0xff0b1c30)
                  ? const Color(0xff545f73)
                  : color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.onView,
  });

  final _InvoiceData invoice;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            invoice.number,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff0b1c30),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '- ${invoice.time}',
                          style: const TextStyle(
                            color: Color(0xff545f73),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      invoice.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff36445f),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    invoice.amount,
                    style: const TextStyle(
                      color: Color(0xff0b1c30),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: invoice.status == 'Split Pay'
                          ? const Color(0xffdbe1ff)
                          : const Color(0xffc7ffca),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      invoice.status.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: invoice.status == 'Split Pay'
                            ? AppTheme.primary
                            : const Color(0xff007f36),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(height: 1, color: const Color(0xffdce9ff)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 15, color: Color(0xff545f73)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  invoice.items,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff545f73),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xffeff4ff),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('View'),
              ),
              const SizedBox(width: 6),
              _IconSquare(icon: Icons.print_outlined, onTap: onView),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 48,
      child: CustomPaint(painter: _SparklinePainter()),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      const Offset(0, 0.70),
      const Offset(0.18, 0.60),
      const Offset(0.36, 0.76),
      const Offset(0.54, 0.36),
      const Offset(0.72, 0.42),
      const Offset(0.88, 0.18),
      const Offset(1, 0.12),
    ]
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList();
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = AppTheme.primary.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xff334155), size: 21),
          ),
          if (showDot)
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xffd5e0f8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.18)),
      ),
      child: Text(message, style: const TextStyle(color: AppTheme.danger)),
    );
  }
}

class _InvoiceData {
  const _InvoiceData({
    required this.number,
    required this.time,
    required this.customer,
    required this.amount,
    required this.status,
    required this.items,
  });

  final String number;
  final String time;
  final String customer;
  final String amount;
  final String status;
  final String items;
}
