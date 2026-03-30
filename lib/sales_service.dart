import 'api_client.dart';
import 'data_utils.dart';
import 'session_store.dart';

class SalesService {
  SalesService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> sales({
    String search = '',
    String status = '',
    String paymentStatus = '',
    String startDate = '',
    String endDate = '',
    int? store,
    int? customer,
  }) async {
    return readList(await _api.get('/sales/', query: {
      'search': search,
      'status': status,
      'payment_status': paymentStatus,
      'start_date': startDate,
      'end_date': endDate,
      'store': store,
      'customer': customer,
    }));
  }

  Future<Map<String, dynamic>> sale(int id) async {
    return readMap(await _api.get('/sales/$id/'));
  }

  Future<Map<String, dynamic>> cancelSale(int id, String reason) {
    return _api.post(
      '/sales/$id/cancel/',
      {'reason': reason},
      authorized: true,
    );
  }

  Future<void> deleteSale(int id) => _api.delete('/sales/$id/');

  Future<Map<String, dynamic>> invoice(String invoiceNumber) async {
    return readMap(await _api.get(
      '/billing/invoices/${Uri.encodeComponent(invoiceNumber)}/',
    ));
  }

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
}
