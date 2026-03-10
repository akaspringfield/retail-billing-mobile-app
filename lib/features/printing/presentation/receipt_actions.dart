import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/theme.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/print_service.dart';

class ReceiptPrintButton extends ConsumerWidget {
  const ReceiptPrintButton({
    required this.invoiceNumber,
    super.key,
  });

  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        try {
          await ref.read(printServiceProvider).printInvoice(invoiceNumber);
        } catch (_) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('Unable to print invoice PDF.')),
          );
        }
      },
      icon: const Icon(Icons.print_outlined),
      label: const Text('Print Bill'),
    );
  }
}

class ReceiptActionPanel extends ConsumerWidget {
  const ReceiptActionPanel({
    required this.invoiceNumber,
    super.key,
  });

  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final printService = ref.watch(printServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          invoiceNumber,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Default: ${settings.defaultPrintAction} · Receipt ${settings.receiptWidth}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => printService.printInvoice(invoiceNumber),
          icon: const Icon(Icons.print_outlined),
          label: const Text('System Print'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PdfPreviewScreen(invoiceNumber: invoiceNumber),
              ),
            );
          },
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Preview PDF'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => printService.shareInvoice(invoiceNumber),
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Share PDF'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
          ),
          child: const Text(
            'Bluetooth thermal printing is prepared as a future integration. V1 uses the system print dialog.',
          ),
        ),
      ],
    );
  }
}

class PdfPreviewScreen extends ConsumerWidget {
  const PdfPreviewScreen({
    required this.invoiceNumber,
    super.key,
  });

  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(printServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Invoice $invoiceNumber')),
      body: PdfPreview(
        build: (_) => service.loadInvoicePdf(invoiceNumber),
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}
