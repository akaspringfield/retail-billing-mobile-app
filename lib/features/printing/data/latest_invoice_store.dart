import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LatestInvoiceStore {
  static const _key = 'latest_invoice_number';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> save(String invoiceNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, invoiceNumber);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final latestInvoiceStoreProvider = Provider<LatestInvoiceStore>(
  (ref) => LatestInvoiceStore(),
);
