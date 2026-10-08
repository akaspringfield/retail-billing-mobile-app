import 'api_client.dart';
import 'data_utils.dart';

class CatalogService {
  CatalogService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> products({String search = ''}) async {
    return readList(await _api.get('/v1/products/', query: {'search': search}));
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
