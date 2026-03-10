import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../domain/report_models.dart';
import 'reports_controller.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.loading
                ? null
                : ref.read(reportsControllerProvider.notifier).load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  if (state.errorMessage != null)
                    _ErrorMessage(message: state.errorMessage!),
                  _ReportTile(
                    title: 'Item Reports',
                    onTap: () => _shareReport(
                      context,
                      state.summary,
                      kind: 'items',
                    ),
                  ),
                  _ReportTile(
                    title: 'Order Reports',
                    onTap: () => _shareReport(
                      context,
                      state.summary,
                      kind: 'orders',
                    ),
                  ),
                  _ReportTile(
                    title: 'Stock Summary',
                    onTap: () => _shareReport(
                      context,
                      state.summary,
                      kind: 'stock',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _shareReport(
    BuildContext context,
    DashboardSummary? summary, {
    required String kind,
  }) async {
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report data is not loaded.')),
      );
      return;
    }

    final csv = _csvFor(summary, kind);
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(csv)),
          mimeType: 'text/csv',
          name: '$kind-report.csv',
        ),
      ],
      text: '$kind report',
    );
  }

  String _csvFor(DashboardSummary summary, String kind) {
    final rows = <List<String>>[];
    rows.add(['section', 'name', 'value_1', 'value_2', 'value_3']);
    rows.add(['Range', 'Start Date', '${summary.range['start_date']}', '', '']);
    rows.add(['Range', 'End Date', '${summary.range['end_date']}', '', '']);

    if (kind == 'items') {
      for (final item in summary.topProducts) {
        rows.add([
          'Top Products',
          '${item['product_name']}',
          '${item['product_code']}',
          '${item['quantity']}',
          '${item['amount']}',
        ]);
      }
    } else if (kind == 'stock') {
      for (final item in summary.lowStock) {
        rows.add([
          'Low Stock',
          '${item['product_name']}',
          '${item['product_code']}',
          '${item['available_quantity']}',
          '${item['minimum_stock']}',
        ]);
      }
    } else {
      final metrics = summary.metrics;
      rows.add(
          ['Orders', 'Sales Count', '${metrics['sales_count'] ?? 0}', '', '']);
      rows.add([
        'Orders',
        'Sales Amount',
        '${metrics['sales_amount'] ?? 0}',
        '',
        ''
      ]);
      rows.add(
          ['Orders', 'Receivables', '${metrics['receivables'] ?? 0}', '', '']);
    }

    return rows.map((row) => row.map(_escape).join(',')).join('\n');
  }

  String _escape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      title: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        child: Text(message, style: const TextStyle(color: AppTheme.danger)),
      ),
    );
  }
}
