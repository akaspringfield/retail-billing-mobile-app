import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_card.dart';
import '../../pos/presentation/pos_controller.dart';
import '../data/latest_invoice_store.dart';
import 'receipt_actions.dart';

class LatestBillScreen extends ConsumerStatefulWidget {
  const LatestBillScreen({super.key});

  @override
  ConsumerState<LatestBillScreen> createState() => _LatestBillScreenState();
}

class _LatestBillScreenState extends ConsumerState<LatestBillScreen> {
  late Future<String?> _latestInvoiceFuture;

  @override
  void initState() {
    super.initState();
    _latestInvoiceFuture = ref.read(latestInvoiceStoreProvider).read();
  }

  @override
  Widget build(BuildContext context) {
    final inMemoryInvoice =
        ref.watch(posControllerProvider).latestCheckout?.invoiceNumber;

    return Scaffold(
      appBar: AppBar(title: const Text('Bills / Print')),
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: _latestInvoiceFuture,
          builder: (context, snapshot) {
            final invoiceNumber = inMemoryInvoice ?? snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: invoiceNumber == null || invoiceNumber.isEmpty
                      ? const _NoRecentBill()
                      : ReceiptActionPanel(invoiceNumber: invoiceNumber),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoRecentBill extends StatelessWidget {
  const _NoRecentBill();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 44),
          SizedBox(height: 12),
          Text('No completed invoice yet.'),
          SizedBox(height: 4),
          Text('Complete a sale from POS to print the latest bill.'),
        ],
      ),
    );
  }
}
