import 'api_client.dart';
import 'data_utils.dart';

class BillingService {
  BillingService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> lookupProducts({
    required String storeId,
    required String query,
  }) async {
    final response = await _api.get('/billing/products/lookup/', query: {
      'store': storeId,
      'q': query,
    });
    return readList(response);
  }

  Future<List<Map<String, dynamic>>> paymentMethods() async {
    return readList(await _api.get('/v1/masters/payment-methods/'));
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> payload) {
    return _api.post('/billing/checkout/', payload, authorized: true);
  }
}
