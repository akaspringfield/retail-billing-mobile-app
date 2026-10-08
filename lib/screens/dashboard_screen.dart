import 'package:flutter/material.dart';

import '../dashboard_service.dart';
import '../data_utils.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.service});

  final DashboardService service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> future = widget.service.summary();

  void reload() => setState(() => future = widget.service.summary());

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Dashboard',
      route: '/dashboard',
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snapshot.hasError) return ErrorBlock(message: snapshot.error.toString(), onRetry: reload);

          final data = snapshot.data ?? {};
          final metrics = readMap(data['metrics']);
          final recentSales = readList(data['recent_sales']);
          final lowStock = readList(data['low_stock']);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today at a glance', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _Metric(label: 'Sales', value: textValue(metrics, ['sales_total', 'total_sales', 'net_sales'], fallback: '0')),
                  _Metric(label: 'Purchases', value: textValue(metrics, ['purchase_total', 'total_purchases'], fallback: '0')),
                  _Metric(label: 'Receipts', value: textValue(metrics, ['customer_receipts'], fallback: '0')),
                  _Metric(label: 'Due', value: textValue(metrics, ['outstanding_receivables', 'balance_amount'], fallback: '0')),
                ],
              ),
              const SizedBox(height: 18),
              _SectionList(title: 'Recent Sales', records: recentSales, primaryKeys: const ['invoice_number'], secondaryKeys: const ['customer_name', 'payment_status'], amountKeys: const ['grand_total']),
              const SizedBox(height: 14),
              _SectionList(title: 'Low Stock', records: lowStock, primaryKeys: const ['product_name'], secondaryKeys: const ['store_name', 'unit_name'], amountKeys: const ['available_quantity', 'stock_quantity']),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.title,
    required this.records,
    required this.primaryKeys,
    required this.secondaryKeys,
    required this.amountKeys,
  });

  final String title;
  final List<Map<String, dynamic>> records;
  final List<String> primaryKeys;
  final List<String> secondaryKeys;
  final List<String> amountKeys;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Text('No records found.')
          else
            ...records.take(5).map((record) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(textValue(record, primaryKeys), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(textValue(record, secondaryKeys)),
                trailing: Text(textValue(record, amountKeys, fallback: ''), style: const TextStyle(fontWeight: FontWeight.w900)),
              );
            }),
        ],
      ),
    );
  }
}
