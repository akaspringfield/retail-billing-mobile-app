import 'package:flutter/material.dart';

import '../data_utils.dart';
import '../mobile_actions.dart';
import '../sales_service.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.service});

  final SalesService service;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesData {
  const _SalesData({
    required this.sales,
    required this.stores,
    required this.customers,
  });

  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> customers;
}

class _SalesScreenState extends State<SalesScreen> {
  final search = TextEditingController();
  String status = '';
  String paymentStatus = '';
  int? storeId;
  int? customerId;
  DateTime? dateFrom;
  DateTime? dateTo;
  late Future<_SalesData> future = load();

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<_SalesData> load() async {
    final results = await Future.wait([
      widget.service.sales(
        search: search.text.trim(),
        status: status,
        paymentStatus: paymentStatus,
        startDate: _date(dateFrom),
        endDate: _date(dateTo),
        store: storeId,
        customer: customerId,
      ),
      widget.service.stores(),
      widget.service.customers(),
    ]);
    return _SalesData(
      sales: results[0],
      stores: results[1],
      customers: results[2],
    );
  }

  void reload() => setState(() => future = load());

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Sales History',
      route: '/sales',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sales History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Invoices created from POS and sales.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search invoice, customer, or store',
            ),
            onSubmitted: (_) => reload(),
          ),
          const SizedBox(height: 10),
          FutureBuilder<_SalesData>(
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
              final data = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filters(data),
                  const SizedBox(height: 14),
                  _summary(data.sales),
                  const SizedBox(height: 16),
                  if (data.sales.isEmpty)
                    const InfoCard(child: Text('No sales found.'))
                  else
                    ...data.sales.map(_saleCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _filters(_SalesData data) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: const Icon(Icons.filter_list, color: AppColors.primary),
      title: const Text(
        'Filters',
        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _dropdown<String>(
                'Status',
                status,
                const {
                  '': 'All statuses',
                  'DRAFT': 'Draft',
                  'COMPLETED': 'Completed',
                  'CANCELLED': 'Cancelled',
                },
                (value) => status = value,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdown<String>(
                'Payment',
                paymentStatus,
                const {
                  '': 'All payments',
                  'UNPAID': 'Unpaid',
                  'PARTIAL': 'Partial',
                  'PAID': 'Paid',
                },
                (value) => paymentStatus = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          initialValue: storeId,
          decoration: const InputDecoration(labelText: 'Store'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All stores')),
            ...data.stores.map(
              (item) => DropdownMenuItem(
                value: _id(item['id']),
                child: Text(textValue(item, ['display_name', 'name'])),
              ),
            ),
          ],
          onChanged: (value) => storeId = value,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          initialValue: customerId,
          decoration: const InputDecoration(labelText: 'Customer'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All customers')),
            ...data.customers.map(
              (item) => DropdownMenuItem(
                value: _id(item['id']),
                child: Text(textValue(item, ['name'])),
              ),
            ),
          ],
          onChanged: (value) => customerId = value,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _dateFilter('From date', dateFrom, (v) => dateFrom = v)),
            const SizedBox(width: 10),
            Expanded(child: _dateFilter('To date', dateTo, (v) => dateTo = v)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    status = '';
                    paymentStatus = '';
                    storeId = null;
                    customerId = null;
                    dateFrom = null;
                    dateTo = null;
                    future = load();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary(List<Map<String, dynamic>> sales) {
    final total = sales.fold<double>(
        0, (sum, row) => sum + numberValue(row['grand_total']));
    final paid = sales.fold<double>(
        0, (sum, row) => sum + numberValue(row['paid_amount']));
    final balance = sales.fold<double>(
        0, (sum, row) => sum + numberValue(row['balance_amount']));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _metric('Invoices', '${sales.length}'),
          _metric('Total', 'Rs. ${total.toStringAsFixed(2)}'),
          _metric('Paid', 'Rs. ${paid.toStringAsFixed(2)}'),
          _metric('Balance', 'Rs. ${balance.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _saleCard(Map<String, dynamic> sale) {
    final statusValue = textValue(sale, ['status'], fallback: '');
    final completed = statusValue == 'COMPLETED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openDetail(sale),
        borderRadius: BorderRadius.circular(8),
        child: InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textValue(sale, ['invoice_number']),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink),
                        ),
                        Text(
                          '${textValue(sale, [
                                'customer_name'
                              ], fallback: 'Walk-in')} / ${textValue(sale, [
                                'store_name'
                              ])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _badge(statusValue, completed),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _detailValue(
                          'Date', _shortDate(sale['invoice_date']))),
                  Expanded(
                      child: _detailValue(
                          'Payment', textValue(sale, ['payment_status']))),
                  Expanded(
                      child: _detailValue(
                          'Total', 'Rs. ${textValue(sale, ['grand_total'])}',
                          strong: true)),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, bool success) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: success ? const Color(0xFFE5F6EA) : const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: success ? AppColors.success : const Color(0xFF8A5B00),
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _detailValue(String label, String value, {bool strong = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: strong ? AppColors.primary : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final id = _id(row['id']);
    if (id == null) return;
    try {
      final sale = await widget.service.sale(id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (sheetContext) => _SaleDetailSheet(
          sale: sale,
          service: widget.service,
          onChanged: reload,
        ),
      );
    } catch (error) {
      _error(error);
    }
  }

  Widget _dateFilter(
      String label, DateTime? value, ValueChanged<DateTime?> changed) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => changed(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Any date' : _date(value)),
      ),
    );
  }

  Widget _dropdown<T>(
      String label, T value, Map<T, String> options, ValueChanged<T> changed) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map((entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)))
          .toList(),
      onChanged: (next) {
        if (next != null) changed(next);
      },
    );
  }

  int? _id(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  String _shortDate(Object? value) {
    final text = value?.toString() ?? '';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }
}

class _SaleDetailSheet extends StatelessWidget {
  const _SaleDetailSheet(
      {required this.sale, required this.service, required this.onChanged});

  final Map<String, dynamic> sale;
  final SalesService service;
  final VoidCallback onChanged;

  int? get id => sale['id'] is num
      ? (sale['id'] as num).toInt()
      : int.tryParse('${sale['id']}');

  @override
  Widget build(BuildContext context) {
    final items = readList(sale['items']);
    final completed = sale['status'] == 'COMPLETED';
    final draft = sale['status'] == 'DRAFT';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(textValue(sale, ['invoice_number']),
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          Text(
            '${textValue(sale, [
                  'customer_name'
                ], fallback: 'Walk-in Customer')} / ${textValue(sale, [
                  'store_name'
                ])}',
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                _row('Status', textValue(sale, ['status'])),
                _row('Payment', textValue(sale, ['payment_status'])),
                _row('Sale type', textValue(sale, ['sale_type'])),
                _row('Invoice date', textValue(sale, ['invoice_date'])),
                _row('Subtotal', 'Rs. ${textValue(sale, ['subtotal'])}'),
                _row('Discount', 'Rs. ${textValue(sale, ['discount_amount'])}'),
                _row('Tax', 'Rs. ${textValue(sale, ['tax_amount'])}'),
                _row('Round off', 'Rs. ${textValue(sale, ['round_off'])}'),
                _row('Total', 'Rs. ${textValue(sale, ['grand_total'])}',
                    strong: true),
                _row('Paid', 'Rs. ${textValue(sale, ['paid_amount'])}'),
                _row('Balance', 'Rs. ${textValue(sale, ['balance_amount'])}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(textValue(item, ['product_name']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          Text('${textValue(item, [
                                'quantity'
                              ])} x Rs. ${textValue(item, ['unit_price'])}'),
                        ],
                      ),
                    ),
                    Text('Rs. ${textValue(item, ['line_total'])}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ),
          if (completed) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openReceipt(context),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print / Open Receipt'),
            ),
          ],
          if (draft) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _cancel(context),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Sale'),
            ),
          ],
          if (!completed) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              label: const Text('Delete Sale',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: TextStyle(
                color: strong ? AppColors.primary : AppColors.ink,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Future<void> _openReceipt(BuildContext context) async {
    try {
      final invoice =
          await service.invoice(textValue(sale, ['invoice_number']));
      final url = textValue(invoice, ['public_receipt_url'], fallback: '');
      if (url.isEmpty) throw Exception('Printable receipt is not available.');
      await MobileActions.openUrl(url);
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel sale'),
        content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Cancel reason')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Back')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Cancel sale')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || id == null) return;
    try {
      await service.cancelSale(id!, reason);
      onChanged();
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete sale'),
        content: Text('Delete ${textValue(sale, ['invoice_number'])}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deleteSale(id!);
      onChanged();
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
