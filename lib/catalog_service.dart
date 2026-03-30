import 'api_client.dart';
import 'data_utils.dart';
import 'session_store.dart';

class CatalogService {
  CatalogService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> products({String search = ''}) async {
    return readList(await _api.get('/v1/products/', query: {'search': search}));
  }

  Future<Map<String, dynamic>> product(int id) async {
    return readMap(await _api.get('/v1/products/$id/'));
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) {
    return _api.post('/v1/products/', payload, authorized: true);
  }

  Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> payload,
  ) {
    return _api.put('/v1/products/$id/', payload);
  }

  Future<void> deleteProduct(int id) {
    return _api.delete('/v1/products/$id/');
  }

  Future<List<Map<String, dynamic>>> masterRecords(String resource) async {
    return readList(await _api.get('/v1/masters/$resource/'));
  }

  Future<List<Map<String, dynamic>>> stockBalances({
    String search = '',
    bool lowStock = false,
  }) async {
    return readList(await _api.get('/v1/stocks/', query: {
      'search': search,
      'low_stock': lowStock ? 'true' : null,
    }));
  }

  Future<List<Map<String, dynamic>>> stores() async {
    final response = await _api.get('/stores/', query: {
      'organization': SessionStore.current?.organizationUuid,
      'active': 'true',
    });
    return readList(readMap(response)['data'] ?? response);
  }

  Future<List<Map<String, dynamic>>> stockAdjustmentRequests({
    String status = 'PENDING',
    int? store,
  }) async {
    return readList(await _api.get('/inventory/adjustment-requests/', query: {
      'status': status,
      'store': store,
    }));
  }

  Future<Map<String, dynamic>> createStockAdjustmentRequest(
    Map<String, dynamic> payload,
  ) {
    return _api.post(
      '/inventory/adjustment-requests/',
      payload,
      authorized: true,
    );
  }

  Future<Map<String, dynamic>> approveStockAdjustmentRequest(int id) {
    return _api.post(
      '/inventory/adjustment-requests/$id/approve/',
      {'review_notes': 'Approved from mobile stock review.'},
      authorized: true,
    );
  }

  Future<Map<String, dynamic>> rejectStockAdjustmentRequest(
    int id,
    String notes,
  ) {
    return _api.post(
      '/inventory/adjustment-requests/$id/reject/',
      {'review_notes': notes},
      authorized: true,
    );
  }

  Future<List<Map<String, dynamic>>> stockTransactions({
    String product = '',
    String direction = '',
  }) async {
    return readList(await _api.get('/inventory/transactions/', query: {
      'product': product,
      'direction': direction,
    }));
  }
}
