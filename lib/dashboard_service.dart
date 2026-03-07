import 'api_client.dart';
import 'data_utils.dart';

class DashboardService {
  DashboardService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> summary() async {
    final response = await _api.get('/reports/dashboard/');
    return readMap(response);
  }
}
