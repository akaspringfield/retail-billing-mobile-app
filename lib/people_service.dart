import 'api_client.dart';
import 'data_utils.dart';
import 'session_store.dart';

class PeopleService {
  PeopleService(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> stores() async {
    final response = await _api.get('/stores/', query: {
      'organization': SessionStore.current?.organizationUuid,
      'active': 'true',
    });
    return readList(readMap(response)['data'] ?? response);
  }

  Future<List<Map<String, dynamic>>> allStores() async {
    final response = await _api.get('/stores/', query: {
      'organization': SessionStore.current?.organizationUuid,
    });
    return readList(readMap(response)['data'] ?? response);
  }

  Future<List<Map<String, dynamic>>> organizations() async {
    final response = await _api.get('/organizations/');
    return readList(readMap(response)['data'] ?? response);
  }

  Future<List<Map<String, dynamic>>> masterRecords(String resource) async {
    return readList(await _api.get('/v1/masters/$resource/'));
  }

  Future<List<Map<String, dynamic>>> customers() async {
    return readList(await _api.get('/customer/customers/'));
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> payload) {
    return _api.post('/customer/customers/', payload, authorized: true);
  }

  Future<Map<String, dynamic>> customer(int id) async {
    return readMap(await _api.get('/customer/customers/$id/'));
  }

  Future<Map<String, dynamic>> updateCustomer(
    int id,
    Map<String, dynamic> payload,
  ) {
    return _api.put('/customer/customers/$id/', payload);
  }

  Future<void> deleteCustomer(int id) {
    return _api.delete('/customer/customers/$id/');
  }

  Future<List<Map<String, dynamic>>> suppliers() async {
    return readList(await _api.get('/v1/supplier/'));
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> payload) {
    return _api.post('/v1/supplier/', payload, authorized: true);
  }

  Future<Map<String, dynamic>> supplier(int id) async {
    return readMap(await _api.get('/v1/supplier/$id/'));
  }

  Future<Map<String, dynamic>> updateSupplier(
    int id,
    Map<String, dynamic> payload,
  ) {
    return _api.put('/v1/supplier/$id/', payload);
  }

  Future<void> deleteSupplier(int id) {
    return _api.delete('/v1/supplier/$id/');
  }

  Future<Map<String, dynamic>> createStore(Map<String, dynamic> payload) {
    return _api.post('/stores/', payload, authorized: true);
  }

  Future<Map<String, dynamic>> updateStore(
    String uuid,
    Map<String, dynamic> payload,
  ) {
    return _api.put('/stores/$uuid/', payload);
  }

  Future<void> deleteStore(String uuid) {
    return _api.delete('/stores/$uuid/');
  }

  Future<List<Map<String, dynamic>>> users() async {
    return readList(await _api.get('/users/'));
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) {
    return _api.post('/users/', payload, authorized: true);
  }

  Future<void> setUserActive(int id, bool active) async {
    await _api.post('/users/$id/${active ? 'activate' : 'deactivate'}/', {},
        authorized: true);
  }
}
