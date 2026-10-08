import 'api_client.dart';
import 'data_utils.dart';

class PeopleService {
  PeopleService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> customers() async {
    return readList(await _api.get('/customer/customers/'));
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> payload) {
    return _api.post('/customer/customers/', payload, authorized: true);
  }

  Future<List<Map<String, dynamic>>> suppliers() async {
    return readList(await _api.get('/v1/supplier/'));
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> payload) {
    return _api.post('/v1/supplier/', payload, authorized: true);
  }

  Future<List<Map<String, dynamic>>> users() async {
    return readList(await _api.get('/users/'));
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) {
    return _api.post('/users/', payload, authorized: true);
  }

  Future<void> setUserActive(int id, bool active) async {
    await _api.post('/users/$id/${active ? 'activate' : 'deactivate'}/', {}, authorized: true);
  }
}
