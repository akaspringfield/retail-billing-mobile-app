import 'package:flutter/material.dart';

import '../billing_service.dart';
import '../data_utils.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.service});

  final BillingService service;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final store = TextEditingController();
  final query = TextEditingController();
  final customer = TextEditingController();
  final paid = TextEditingController();
  final cart = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> methods = [];
  int? paymentMethod;
  bool loading = false;
  String message = '';

  double get total => cart.fold(0, (sum, item) {
        return sum + numberValue(item['selling_price']) * numberValue(item['quantity']);
      });

  Future<void> searchProducts() async {
    if (store.text.trim().isEmpty || query.text.trim().isEmpty) {
      setState(() => message = 'Enter store id and product search text.');
      return;
    }
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final results = await widget.service.lookupProducts(storeId: store.text.trim(), query: query.text.trim());
      final paymentResults = methods.isEmpty ? await widget.service.paymentMethods() : methods;
      setState(() {
        products = results;
        methods = paymentResults;
        if (paymentMethod == null && methods.isNotEmpty) {
          paymentMethod = int.tryParse(methods.first['id'].toString());
        }
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void addProduct(Map<String, dynamic> product) {
    setState(() {
      final existing = cart.where((item) => item['product_id'] == product['product_id']).toList();
      if (existing.isEmpty) {
        cart.add({...product, 'quantity': 1});
      } else {
        existing.first['quantity'] = numberValue(existing.first['quantity']) + 1;
      }
      paid.text = total.toStringAsFixed(2);
    });
  }

  Future<void> checkout() async {
    if (cart.isEmpty || paymentMethod == null) {
      setState(() => message = 'Add products and select a payment method.');
      return;
    }
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final response = await widget.service.checkout({
        'store': int.tryParse(store.text.trim()),
        'customer': int.tryParse(customer.text.trim()),
        'items': cart.map((item) {
          return {
            'product': item['product_id'],
            'quantity': numberValue(item['quantity']),
            'unit_price': numberValue(item['selling_price']),
            'discount_percent': 0,
            'tax_percent': 0,
          };
        }).toList(),
        'payment': {
          'payment_method': paymentMethod,
          'amount': numberValue(paid.text),
          'reference_number': '',
          'remarks': 'Mobile POS',
        },
      });
      setState(() {
        cart.clear();
        products.clear();
        message = response['message']?.toString() ?? 'Checkout completed.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'POS',
      route: '/pos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Point of Sale', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          InfoCard(
            child: Column(
              children: [
                TextField(controller: store, decoration: const InputDecoration(labelText: 'Store ID')),
                const SizedBox(height: 10),
                TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer ID (optional)')),
                const SizedBox(height: 10),
                TextField(controller: query, decoration: const InputDecoration(labelText: 'Barcode, SKU, or product name'), onSubmitted: (_) => searchProducts()),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: loading ? null : searchProducts, icon: const Icon(Icons.search), label: Text(loading ? 'Searching...' : 'Search Product')),
              ],
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            InfoCard(child: Text(message)),
          ],
          const SizedBox(height: 14),
          ...products.map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InfoCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(textValue(product, ['name']), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('Stock ${textValue(product, ['available_quantity', 'stock_quantity'])}'),
                  trailing: Text(textValue(product, ['selling_price'], fallback: '0'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  onTap: () => addProduct(product),
                ),
              ),
            );
          }),
          if (cart.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Cart', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            InfoCard(
              child: Column(
                children: [
                  ...cart.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(textValue(item, ['name'])),
                      subtitle: Text('Qty ${numberValue(item['quantity']).toStringAsFixed(0)}'),
                      trailing: Text((numberValue(item['quantity']) * numberValue(item['selling_price'])).toStringAsFixed(2)),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
                      Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: methods.map((method) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(method['id'].toString()),
                        child: Text(textValue(method, ['display_name', 'name'])),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => paymentMethod = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: paid, decoration: const InputDecoration(labelText: 'Paid Amount'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: loading ? null : checkout, icon: const Icon(Icons.check_circle_outline), label: const Text('Checkout')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
