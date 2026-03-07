import 'dart:convert';

import 'package:flutter/material.dart';

import '../billing_service.dart';
import '../data_utils.dart';
import '../mobile_actions.dart';
import '../session_store.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.service});

  final BillingService service;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  static const _stateKey = 'mobile_pos_state_v1';
  final search = TextEditingController();
  final cartDiscount = TextEditingController(text: '0');
  final roundOff = TextEditingController(text: '0');

  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> catalog = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> paymentMethods = [];
  final List<_CartLine> cart = [];
  final List<_HeldBill> heldBills = [];

  int? storeId;
  int? customerId;
  String category = '';
  bool loading = true;
  bool lookingUp = false;
  bool autoOpenReceipt = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    search.dispose();
    cartDiscount.dispose();
    roundOff.dispose();
    super.dispose();
  }

  double clampPercent(double value) => value.clamp(0, 100).toDouble();

  double get cartDiscountValue => clampPercent(numberValue(cartDiscount.text));
  double get roundOffValue => numberValue(roundOff.text);
  double get subtotal =>
      cart.fold(0, (sum, item) => sum + item.quantity * item.unitPrice);
  double get discount => cart.fold(0, (sum, item) {
        final gross = item.quantity * item.unitPrice;
        return sum +
            gross *
                clampPercent(item.discountPercent + cartDiscountValue) /
                100;
      });
  double get tax => cart.fold(0, (sum, item) {
        final gross = item.quantity * item.unitPrice;
        final discounted = gross *
            (1 - clampPercent(item.discountPercent + cartDiscountValue) / 100);
        return sum + discounted * clampPercent(item.taxPercent) / 100;
      });
  double get grandTotal =>
      (subtotal - discount + tax + roundOffValue).clamp(0, double.infinity);
  List<_CartLine> get stockWarnings =>
      cart.where((item) => item.quantity > item.available).toList();

  Future<void> initialize() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final results = await Future.wait([
        widget.service.stores(),
        widget.service.customers(),
        widget.service.paymentMethods(),
      ]);
      stores = results[0];
      customers = results[1];
      paymentMethods = results[2];

      final sessionStoreUuid = SessionStore.current?.storeUuid;
      final selected = stores.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['uuid']?.toString() == sessionStoreUuid,
            orElse: () => stores.isEmpty ? null : stores.first,
          );
      storeId = int.tryParse(selected?['id']?.toString() ?? '');
      await restoreState();
      if (storeId != null) await loadCatalog();
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> restoreState() async {
    final raw = await MobileActions.getPreference(_stateKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final state = jsonDecode(raw) as Map<String, dynamic>;
      final savedStore = int.tryParse(state['store_id']?.toString() ?? '');
      if (stores
          .any((item) => int.tryParse(item['id'].toString()) == savedStore)) {
        storeId = savedStore;
      }
      customerId = int.tryParse(state['customer_id']?.toString() ?? '');
      cartDiscount.text = state['cart_discount']?.toString() ?? '0';
      roundOff.text = state['round_off']?.toString() ?? '0';
      autoOpenReceipt = state['auto_open_receipt'] == true;
      cart
        ..clear()
        ..addAll(readList(state['cart']).map(_CartLine.fromJson));
      heldBills
        ..clear()
        ..addAll(readList(state['held_bills']).map(_HeldBill.fromJson));
    } catch (_) {
      await MobileActions.removePreference(_stateKey);
    }
  }

  Future<void> persistState() {
    return MobileActions.setPreference(
      _stateKey,
      jsonEncode({
        'store_id': storeId,
        'customer_id': customerId,
        'cart_discount': cartDiscountValue,
        'round_off': roundOffValue,
        'auto_open_receipt': autoOpenReceipt,
        'cart': cart.map((item) => item.toJson()).toList(),
        'held_bills': heldBills.map((item) => item.toJson()).toList(),
      }),
    );
  }

  void updatePersistentState(VoidCallback change) {
    setState(change);
    persistState();
  }

  Future<void> loadCatalog() async {
    final selectedStore = storeId;
    if (selectedStore == null) return;
    catalog = await widget.service.products(storeId: selectedStore);
  }

  Future<void> changeStore(int? value) async {
    if (value == null || value == storeId) return;
    setState(() {
      storeId = value;
      cart.clear();
      catalog = [];
      category = '';
      message = '';
      loading = true;
    });
    try {
      await loadCatalog();
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
    await persistState();
  }

  Future<Map<String, dynamic>> resolveProduct(String value,
      {String? preferredMode}) async {
    final selectedStore = storeId;
    if (selectedStore == null)
      throw Exception('No accessible store is available.');
    final modes = preferredMode == null
        ? ['barcode', 'code', 'sku', 'q']
        : [preferredMode];
    Object? lastError;
    for (final mode in modes) {
      try {
        return await widget.service
            .lookupProduct(storeId: selectedStore, query: value, mode: mode);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Product not found.');
  }

  Future<void> lookupAndAdd(String value, {String? mode}) async {
    final term = value.trim();
    if (term.isEmpty) return;
    setState(() {
      lookingUp = true;
      message = '';
    });
    persistState();
    try {
      addProduct(await resolveProduct(term, preferredMode: mode));
      search.clear();
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => lookingUp = false);
    }
  }

  void addProduct(Map<String, dynamic> product) {
    final id = int.tryParse(product['product_id']?.toString() ?? '') ?? 0;
    if (id == 0) return;
    final index = cart.indexWhere((item) => item.productId == id);
    setState(() {
      if (index >= 0) {
        cart[index].quantity += 1;
      } else {
        cart.add(_CartLine.fromProduct(product));
      }
      message = '';
    });
  }

  List<Map<String, dynamic>> get visibleProducts {
    final term = search.text.trim().toLowerCase();
    return catalog
        .where((product) {
          final matchesCategory = category.isEmpty ||
              textValue(product, ['category_name'], fallback: '') == category;
          if (!matchesCategory) return false;
          if (term.isEmpty) return true;
          return ['name', 'code', 'sku'].any((key) =>
              product[key]?.toString().toLowerCase().contains(term) == true);
        })
        .take(20)
        .toList();
  }

  List<String> get categories {
    final values = catalog
        .map((item) => textValue(item, ['category_name'], fallback: ''))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  void clearBill() {
    setState(() {
      cart.clear();
      customerId = null;
      cartDiscount.text = '0';
      roundOff.text = '0';
      message = 'Bill cleared.';
    });
    persistState();
  }

  Future<void> holdBill() async {
    if (cart.isEmpty) return;
    final controller = TextEditingController(
        text: selectedCustomerName ?? 'Bill ${heldBills.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hold Bill'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Bill name or token')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Hold')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() {
      heldBills.insert(
        0,
        _HeldBill(
          name: name,
          storeId: storeId!,
          customerId: customerId,
          items: cart.map((item) => item.copy()).toList(),
          cartDiscount: cartDiscountValue,
          roundOff: roundOffValue,
        ),
      );
      cart.clear();
      customerId = null;
      cartDiscount.text = '0';
      roundOff.text = '0';
      message = 'Bill held.';
    });
    await persistState();
  }

  Future<void> showHeldBills() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Held Bills', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (heldBills.isEmpty)
                const Text('No held bills in this app session.'),
              ...heldBills.map((bill) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(bill.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        '${bill.items.length} item(s) / Rs. ${bill.total.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () {
                        setState(() {
                          cart
                            ..clear()
                            ..addAll(bill.items.map((item) => item.copy()));
                          storeId = bill.storeId;
                          customerId = bill.customerId;
                          cartDiscount.text =
                              bill.cartDiscount.toStringAsFixed(2);
                          roundOff.text = bill.roundOff.toStringAsFixed(2);
                          heldBills.remove(bill);
                        });
                        persistState();
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  String? get selectedCustomerName {
    final match = customers
        .where((item) => int.tryParse(item['id'].toString()) == customerId);
    return match.isEmpty ? null : textValue(match.first, ['name']);
  }

  Future<void> editLine(_CartLine line) async {
    final quantity =
        TextEditingController(text: line.quantity.toStringAsFixed(3));
    final price =
        TextEditingController(text: line.unitPrice.toStringAsFixed(2));
    final discountValue =
        TextEditingController(text: line.discountPercent.toStringAsFixed(2));
    final taxValue =
        TextEditingController(text: line.taxPercent.toStringAsFixed(2));
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(line.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
                controller: quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantity')),
            const SizedBox(height: 10),
            TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit price')),
            const SizedBox(height: 10),
            TextField(
                controller: discountValue,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Discount %')),
            const SizedBox(height: 10),
            TextField(
                controller: taxValue,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tax %')),
            const SizedBox(height: 14),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update Item')),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        line.quantity = numberValue(quantity.text);
        line.unitPrice = numberValue(price.text);
        line.discountPercent = clampPercent(numberValue(discountValue.text));
        line.taxPercent = clampPercent(numberValue(taxValue.text));
        if (line.quantity <= 0) cart.remove(line);
      });
      await persistState();
    }
    quantity.dispose();
    price.dispose();
    discountValue.dispose();
    taxValue.dispose();
  }

  Future<void> openPayment() async {
    if (cart.isEmpty || grandTotal <= 0 || stockWarnings.isNotEmpty) return;
    if (paymentMethods.isEmpty) {
      setState(() => message = 'No active payment methods are configured.');
      return;
    }
    final defaultMethod = paymentMethods.firstWhere(
      (item) => item['is_default'] == true,
      orElse: () => paymentMethods.first,
    );
    final entries = [
      _PaymentEntry(
        methodId: int.tryParse(defaultMethod['id'].toString()),
        amount: grandTotal,
      ),
    ];
    final confirmed = await showModalBottomSheet<List<_PaymentEntry>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PaymentSheet(
        total: grandTotal,
        methods: paymentMethods,
        entries: entries,
      ),
    );
    if (confirmed != null) await completeCheckout(confirmed);
  }

  Future<void> completeCheckout(List<_PaymentEntry> payments) async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final normalizedPayments =
          payments.map((payment) => payment.toPayload()).toList();
      final response = await widget.service.checkout({
        'store': storeId,
        'customer': customerId,
        'items': cart.map((item) => item.toPayload(cartDiscountValue)).toList(),
        'payment': normalizedPayments.first,
        'payments': normalizedPayments,
        'round_off': roundOffValue.toStringAsFixed(2),
        'remarks': 'Mobile POS checkout',
      });
      if (!mounted) return;
      if (autoOpenReceipt) {
        final sale = readMap(response['sale']);
        final invoiceNumber = textValue(sale, ['invoice_number'], fallback: '');
        if (invoiceNumber.isNotEmpty) {
          final invoice = await widget.service.invoice(invoiceNumber);
          final receiptUrl =
              textValue(invoice, ['public_receipt_url'], fallback: '');
          if (receiptUrl.isNotEmpty) await MobileActions.openUrl(receiptUrl);
        }
      }
      await showCheckoutSuccess(response);
      setState(() {
        cart.clear();
        customerId = null;
        cartDiscount.text = '0';
        roundOff.text = '0';
        search.clear();
      });
      await persistState();
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showCheckoutSuccess(Map<String, dynamic> response) async {
    final sale = readMap(response['sale']);
    final invoiceNumber = textValue(sale, ['invoice_number']);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon:
            const Icon(Icons.check_circle, size: 46, color: AppColors.success),
        title: const Text('Sale Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invoice $invoiceNumber',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                'Rs. ${textValue(sale, [
                      'grand_total'
                    ], fallback: grandTotal.toStringAsFixed(2))}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(textValue(sale, ['payment_status'], fallback: 'Completed')),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              try {
                final invoice = await widget.service.invoice(invoiceNumber);
                final receiptUrl =
                    textValue(invoice, ['public_receipt_url'], fallback: '');
                if (receiptUrl.isEmpty) {
                  throw Exception('Printable receipt is not available.');
                }
                await MobileActions.openUrl(receiptUrl);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final invoice = await widget.service.invoice(invoiceNumber);
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (context) => _InvoicePreview(invoice: invoice),
                );
              } catch (error) {
                if (context.mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: const Text('Receipt Preview'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('New Bill')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'POS',
      route: '/pos',
      actions: [
        IconButton(
            onPressed: heldBills.isEmpty ? null : showHeldBills,
            tooltip: 'Held bills',
            icon: Badge(
                label: Text('${heldBills.length}'),
                child: const Icon(Icons.pause_circle_outline))),
        IconButton(
            onPressed: cart.isEmpty ? null : holdBill,
            tooltip: 'Hold bill',
            icon: const Icon(Icons.pause)),
        IconButton(
            onPressed: cart.isEmpty ? null : clearBill,
            tooltip: 'Clear bill',
            icon: const Icon(Icons.delete_sweep_outlined)),
      ],
      child: loading && stores.isEmpty
          ? const LoadingBlock()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Quick Bill',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                    'Scan, search, or select products for the current store.'),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: storeId,
                  decoration: const InputDecoration(
                      labelText: 'Store',
                      prefixIcon: Icon(Icons.store_outlined)),
                  items: stores
                      .map((item) => DropdownMenuItem<int>(
                            value: int.tryParse(item['id'].toString()),
                            child:
                                Text(textValue(item, ['display_name', 'name'])),
                          ))
                      .toList(),
                  onChanged: stores.length > 1 ? changeStore : null,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Barcode, SKU, code, or product name',
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    suffixIcon: lookingUp
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            onPressed: () => lookupAndAdd(search.text),
                            icon: const Icon(Icons.search)),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: lookupAndAdd,
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                            label: const Text('All'),
                            selected: category.isEmpty,
                            onSelected: (_) => setState(() => category = '')),
                        const SizedBox(width: 7),
                        ...categories.map((item) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                  label: Text(item),
                                  selected: category == item,
                                  onSelected: (_) =>
                                      setState(() => category = item)),
                            )),
                      ],
                    ),
                  ),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InfoCard(
                      child: Text(message,
                          style: TextStyle(
                              color: message.toLowerCase().contains('fail') ||
                                      message.toLowerCase().contains('error')
                                  ? AppColors.danger
                                  : AppColors.ink))),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Products',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('${visibleProducts.length} shown',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                if (catalog.isEmpty)
                  const InfoCard(
                      child: Text('No products are available for this store.'))
                else
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      itemCount: visibleProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        return InfoCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(textValue(product, ['name']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            subtitle: Text('${textValue(product, [
                                  'code'
                                ])} / ${textValue(product, ['sku'])}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    'Rs. ${textValue(product, [
                                          'selling_price'
                                        ], fallback: '0')}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(width: 6),
                                const Icon(Icons.add_circle,
                                    color: AppColors.primary),
                              ],
                            ),
                            onTap: () => lookupAndAdd(
                                textValue(product, ['code']),
                                mode: 'code'),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Bill',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('${cart.length} item(s)',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                if (cart.isEmpty)
                  const InfoCard(
                      child: Text('Select or scan a product to start billing.'))
                else
                  ...cart.map((line) => _cartCard(line)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: customerId,
                  decoration: const InputDecoration(
                      labelText: 'Customer',
                      prefixIcon: Icon(Icons.person_outline)),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Walk-in Customer')),
                    ...customers.map((item) => DropdownMenuItem<int?>(
                          value: int.tryParse(item['id'].toString()),
                          child: Text(textValue(item, ['name'])),
                        )),
                  ],
                  onChanged: (value) =>
                      updatePersistentState(() => customerId = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: cartDiscount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Cart Discount %'),
                            onChanged: (_) => updatePersistentState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: roundOff,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration:
                                const InputDecoration(labelText: 'Round Off'),
                            onChanged: (_) => updatePersistentState(() {}))),
                  ],
                ),
                const SizedBox(height: 12),
                _summary(),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: autoOpenReceipt,
                  onChanged: (value) => updatePersistentState(
                    () => autoOpenReceipt = value ?? false,
                  ),
                  title: const Text('Open receipt automatically after sale'),
                ),
                if (stockWarnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InfoCard(
                      child: Text(
                          '${stockWarnings.length} item(s) exceed available stock.',
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w800))),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: cart.isEmpty ||
                          grandTotal <= 0 ||
                          stockWarnings.isNotEmpty ||
                          loading
                      ? null
                      : openPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text('PAY Rs. ${grandTotal.toStringAsFixed(2)}'),
                ),
              ],
            ),
    );
  }

  Widget _cartCard(_CartLine line) {
    final warning = line.quantity > line.available;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InfoCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink)),
                      Text(
                          '${line.code} / Stock ${line.available.toStringAsFixed(3)}',
                          style: TextStyle(
                              color: warning
                                  ? AppColors.danger
                                  : AppColors.muted)),
                    ],
                  ),
                ),
                IconButton(
                    onPressed: () => editLine(line),
                    tooltip: 'Edit line',
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    onPressed: () =>
                        updatePersistentState(() => cart.remove(line)),
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline)),
              ],
            ),
            Row(
              children: [
                IconButton(
                    onPressed: () => updatePersistentState(() =>
                        line.quantity <= 1
                            ? cart.remove(line)
                            : line.quantity -= 1),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text(line.quantity.toStringAsFixed(3),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(
                    onPressed: () =>
                        updatePersistentState(() => line.quantity += 1),
                    icon: const Icon(Icons.add_circle_outline)),
                const Spacer(),
                Text('Rs. ${line.total(cartDiscountValue).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return InfoCard(
      child: Column(
        children: [
          _SummaryRow('Subtotal', subtotal),
          _SummaryRow('Discount', -discount),
          _SummaryRow('Tax', tax),
          _SummaryRow('Round Off', roundOffValue),
          const Divider(),
          _SummaryRow('Grand Total', grandTotal, strong: true),
        ],
      ),
    );
  }
}

class _CartLine {
  _CartLine({
    required this.productId,
    required this.name,
    required this.code,
    required this.available,
    required this.quantity,
    required this.unitPrice,
    required this.discountPercent,
    required this.taxPercent,
  });

  factory _CartLine.fromProduct(Map<String, dynamic> product) => _CartLine(
        productId: int.tryParse(product['product_id'].toString()) ?? 0,
        name: textValue(product, ['name']),
        code: textValue(product, ['code', 'sku']),
        available: numberValue(product['available_quantity']),
        quantity: 1,
        unitPrice: numberValue(product['selling_price']),
        discountPercent: 0,
        taxPercent: 0,
      );

  factory _CartLine.fromJson(Map<String, dynamic> value) => _CartLine(
        productId: int.tryParse(value['product_id'].toString()) ?? 0,
        name: value['name']?.toString() ?? '',
        code: value['code']?.toString() ?? '',
        available: numberValue(value['available']),
        quantity: numberValue(value['quantity']),
        unitPrice: numberValue(value['unit_price']),
        discountPercent: numberValue(value['discount_percent']),
        taxPercent: numberValue(value['tax_percent']),
      );

  final int productId;
  final String name;
  final String code;
  final double available;
  double quantity;
  double unitPrice;
  double discountPercent;
  double taxPercent;

  _CartLine copy() => _CartLine(
        productId: productId,
        name: name,
        code: code,
        available: available,
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discountPercent,
        taxPercent: taxPercent,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'code': code,
        'available': available,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percent': discountPercent,
        'tax_percent': taxPercent,
      };

  double total(double cartDiscount) {
    final gross = quantity * unitPrice;
    final discount = (discountPercent + cartDiscount).clamp(0, 100);
    final taxable = gross * (1 - discount / 100);
    return taxable + taxable * taxPercent.clamp(0, 100) / 100;
  }

  Map<String, dynamic> toPayload(double cartDiscount) => {
        'product': productId,
        'quantity': quantity.toStringAsFixed(3),
        'unit_price': unitPrice.toStringAsFixed(2),
        'discount_percent':
            (discountPercent + cartDiscount).clamp(0, 100).toStringAsFixed(2),
        'tax_percent': taxPercent.clamp(0, 100).toStringAsFixed(2),
        'remarks': '',
      };
}

class _HeldBill {
  _HeldBill(
      {required this.name,
      required this.storeId,
      required this.customerId,
      required this.items,
      required this.cartDiscount,
      required this.roundOff});

  factory _HeldBill.fromJson(Map<String, dynamic> value) => _HeldBill(
        name: value['name']?.toString() ?? 'Held Bill',
        storeId: int.tryParse(value['store_id'].toString()) ?? 0,
        customerId: int.tryParse(value['customer_id']?.toString() ?? ''),
        items: readList(value['items']).map(_CartLine.fromJson).toList(),
        cartDiscount: numberValue(value['cart_discount']),
        roundOff: numberValue(value['round_off']),
      );

  final String name;
  final int storeId;
  final int? customerId;
  final List<_CartLine> items;
  final double cartDiscount;
  final double roundOff;
  double get total =>
      items.fold(0.0, (sum, item) => sum + item.total(cartDiscount)) + roundOff;

  Map<String, dynamic> toJson() => {
        'name': name,
        'store_id': storeId,
        'customer_id': customerId,
        'items': items.map((item) => item.toJson()).toList(),
        'cart_discount': cartDiscount,
        'round_off': roundOff,
      };
}

class _PaymentEntry {
  _PaymentEntry({this.methodId, this.amount = 0});

  int? methodId;
  double amount;
  String reference = '';
  String remarks = '';

  Map<String, dynamic> toPayload() => {
        'payment_method': methodId,
        'amount': amount.toStringAsFixed(2),
        'reference_number': reference.trim(),
        'remarks':
            remarks.trim().isEmpty ? 'Mobile POS payment' : remarks.trim(),
      };
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet(
      {required this.total, required this.methods, required this.entries});

  final double total;
  final List<Map<String, dynamic>> methods;
  final List<_PaymentEntry> entries;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String error = '';
  double get paid => widget.entries.fold(0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Payment', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Total Rs. ${widget.total.toStringAsFixed(2)}'),
              const SizedBox(height: 14),
              ...widget.entries
                  .asMap()
                  .entries
                  .map((row) => _paymentRow(row.key, row.value)),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => widget.entries.add(_PaymentEntry())),
                icon: const Icon(Icons.call_split),
                label: const Text('Split Payment'),
              ),
              const SizedBox(height: 10),
              InfoCard(
                  child: _SummaryRow('Balance', widget.total - paid,
                      strong: true)),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(error, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (widget.entries.any(
                      (item) => item.methodId == null || item.amount < 0)) {
                    setState(() => error =
                        'Select a method and enter a valid amount for every payment.');
                    return;
                  }
                  if ((paid - widget.total).abs() > 0.01) {
                    setState(() => error =
                        'Payment total must equal Rs. ${widget.total.toStringAsFixed(2)}.');
                    return;
                  }
                  Navigator.pop(context, widget.entries);
                },
                child: const Text('Complete Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentRow(int index, _PaymentEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Payment ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900))),
                if (widget.entries.length > 1)
                  IconButton(
                      onPressed: () =>
                          setState(() => widget.entries.removeAt(index)),
                      icon: const Icon(Icons.close)),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: entry.methodId,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: widget.methods
                  .map((item) => DropdownMenuItem<int>(
                        value: int.tryParse(item['id'].toString()),
                        child: Text(textValue(item, ['display_name', 'name'])),
                      ))
                  .toList(),
              onChanged: (value) => entry.methodId = value,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: entry.amount.toStringAsFixed(2),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              onChanged: (value) =>
                  setState(() => entry.amount = numberValue(value)),
            ),
            const SizedBox(height: 8),
            TextFormField(
                initialValue: entry.reference,
                decoration: const InputDecoration(labelText: 'Reference'),
                onChanged: (value) => entry.reference = value),
            const SizedBox(height: 8),
            TextFormField(
                initialValue: entry.remarks,
                decoration: const InputDecoration(labelText: 'Remarks'),
                onChanged: (value) => entry.remarks = value),
          ],
        ),
      ),
    );
  }
}

class _InvoicePreview extends StatelessWidget {
  const _InvoicePreview({required this.invoice});

  final Map<String, dynamic> invoice;

  @override
  Widget build(BuildContext context) {
    final items = readList(invoice['items']);
    final invoiceNumber = textValue(invoice, ['invoice_number']);
    final receiptUrl = textValue(invoice, ['public_receipt_url'], fallback: '');
    final phone = textValue(invoice, ['customer_phone'], fallback: '')
        .replaceAll(RegExp(r'[^0-9]'), '');
    final shareText = [
      'Invoice $invoiceNumber',
      textValue(invoice, ['store_name', 'organization_name']),
      'Total: Rs. ${textValue(invoice, ['grand_total'])}',
      if (receiptUrl.isNotEmpty) receiptUrl,
    ].join('\n');
    return AlertDialog(
      title: Text('Invoice $invoiceNumber'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(textValue(invoice, ['store_name', 'organization_name']),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(textValue(invoice, ['customer_name'],
                  fallback: 'Walk-in Customer')),
              const Divider(),
              ...items.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(textValue(item, ['product_name'])),
                    subtitle: Text('${textValue(item, [
                          'quantity'
                        ])} x ${textValue(item, ['unit_price'])}'),
                    trailing: Text(textValue(item, ['line_total'])),
                  )),
              const Divider(),
              _SummaryRow('Grand Total', numberValue(invoice['grand_total']),
                  strong: true),
              _SummaryRow('Paid', numberValue(invoice['paid_amount'])),
              _SummaryRow('Balance', numberValue(invoice['balance_amount'])),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => MobileActions.shareText(
            subject: 'Invoice $invoiceNumber',
            text: shareText,
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share'),
        ),
        if (phone.isNotEmpty)
          TextButton.icon(
            onPressed: () => MobileActions.openUrl(
              'https://wa.me/$phone?text=${Uri.encodeComponent(shareText)}',
            ),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp'),
          ),
        if (receiptUrl.isNotEmpty)
          TextButton.icon(
            onPressed: () => MobileActions.openUrl(receiptUrl),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Receipt / Print'),
          ),
        FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
        color: AppColors.ink,
        fontSize: strong ? 17 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('Rs. ${value.toStringAsFixed(2)}', style: style)
        ],
      ),
    );
  }
}
