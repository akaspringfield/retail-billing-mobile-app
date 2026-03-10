import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/report_models.dart';

class ReportsRepository {
  const ReportsRepository(this.apiClient);

  final ApiClient apiClient;

  Future<DashboardSummary> loadDashboard({
    int? storeId,
    String? startDate,
    String? endDate,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.dashboardReport,
      queryParameters: {
        if (storeId != null) 'store': storeId,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return DashboardSummary.fromJson(response.data as Map<String, dynamic>);
  }
}
