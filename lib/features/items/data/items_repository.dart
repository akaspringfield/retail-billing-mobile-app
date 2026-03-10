import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../pos/domain/pos_models.dart';
import '../domain/item_models.dart';

class ItemsRepository {
  const ItemsRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<ProductSummary>> loadProducts({int? storeId}) async {
    final response = await apiClient.get(
      ApiEndpoints.products,
      queryParameters: {if (storeId != null) 'store': storeId},
    );
    final data = response.data;
    final list =
        data is List ? data : (data as Map<String, dynamic>)['results'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ProductSummary.fromJson)
        .toList();
  }

  Future<List<StockBalance>> loadStocks({
    int? storeId,
    String? search,
    bool lowStock = false,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.stocks,
      queryParameters: {
        if (storeId != null) 'store': storeId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (lowStock) 'low_stock': 'true',
      },
    );
    final data = response.data;
    final list =
        data is List ? data : (data as Map<String, dynamic>)['results'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(StockBalance.fromJson)
        .toList();
  }

  Future<String> adjustStock({
    required StoreInfo store,
    required ProductSummary product,
    required String direction,
    required double quantity,
    required double unitCost,
    required String referenceNumber,
    required String remarks,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.stockAdjust,
      data: {
        'store': store.id,
        'product': product.id,
        'direction': direction,
        'quantity': quantity.toStringAsFixed(3),
        'unit_cost': unitCost.toStringAsFixed(2),
        'reference_number': referenceNumber.trim(),
        'remarks': remarks.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return '${data['detail'] ?? 'Stock adjusted successfully.'}';
  }
}
