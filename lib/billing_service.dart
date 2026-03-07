import 'api_client.dart';
import 'data_utils.dart';
import 'session_store.dart';

class BillingService {
  BillingService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> stores() async {
    final response = await _api.get('/stores/', query: {
      'organization': SessionStore.current?.organizationUuid,
      'active': 'true',
    });
    return readList(readMap(response)['data'] ?? response);
  }

  Future<List<Map<String, dynamic>>> customers() async {
    return readList(await _api.get('/customer/customers/'));
  }

  Future<List<Map<String, dynamic>>> products({required int storeId}) async {
    return readList(await _api.get('/v1/products/', query: {'store': storeId}));
  }

  Future<Map<String, dynamic>> lookupProduct({
    required int storeId,
    required String query,
    String mode = 'q',
  }) async {
    final response = await _api.get('/billing/products/lookup/', query: {
      'store': storeId,
      mode: query,
    });
    return readMap(response);
  }

  Future<List<Map<String, dynamic>>> paymentMethods() async {
    return readList(await _api.get('/v1/masters/payment-methods/'));
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> payload) {
    return _api.post('/billing/checkout/', payload, authorized: true);
  }

  Future<Map<String, dynamic>> invoice(String invoiceNumber) async {
    return readMap(await _api
        .get('/billing/invoices/${Uri.encodeComponent(invoiceNumber)}/'));
  }
}
