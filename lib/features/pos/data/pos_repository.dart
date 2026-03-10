import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/pos_models.dart';

class PosRepository {
  const PosRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<StoreInfo>> loadStores({String? organizationUuid}) async {
    final response = await apiClient.get(
      ApiEndpoints.stores,
      queryParameters: {
        if (organizationUuid != null && organizationUuid.isNotEmpty)
          'organization': organizationUuid,
        'active': 'true',
      },
    );
    final payload = response.data as Map<String, dynamic>;
    final data = payload['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(StoreInfo.fromJson)
        .toList();
  }

  Future<List<CustomerInfo>> loadCustomers() async {
    final response = await apiClient.get(ApiEndpoints.customers);
    final data = response.data;
    final list =
        data is List ? data : (data as Map<String, dynamic>)['results'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerInfo.fromJson)
        .toList();
  }

  Future<List<PaymentMethodInfo>> loadPaymentMethods() async {
    final response = await apiClient.get(ApiEndpoints.paymentMethods);
    final data = response.data;
    final list =
        data is List ? data : (data as Map<String, dynamic>)['results'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethodInfo.fromJson)
        .where((method) => method.name.isNotEmpty)
        .toList();
  }

  Future<ProductInfo> lookupProduct({
    required int storeId,
    required String query,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.productLookup,
      queryParameters: {
        'store': storeId,
        'q': query,
      },
    );
    return ProductInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CheckoutResult> checkout({
    required int storeId,
    required CustomerInfo? customer,
    required List<CartLine> items,
    required PaymentMethodInfo paymentMethod,
    required double paymentAmount,
    required String referenceNumber,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.checkout,
      data: {
        'store': storeId,
        'customer': customer?.id,
        'items': items
            .map(
              (line) => {
                'product': line.product.productId,
                'quantity': line.quantity.toStringAsFixed(3),
                'unit_price': line.unitPrice.toStringAsFixed(2),
                'discount_percent': line.discountPercent.toStringAsFixed(2),
                'tax_percent': line.taxPercent.toStringAsFixed(2),
                'remarks': '',
              },
            )
            .toList(),
        'payment': {
          'payment_method': paymentMethod.id,
          'amount': paymentAmount.toStringAsFixed(2),
          'reference_number': referenceNumber.trim(),
          'remarks': 'Mobile POS payment',
        },
        'round_off': '0.00',
        'remarks': 'Mobile POS checkout',
      },
    );
    return CheckoutResult.fromJson(response.data as Map<String, dynamic>);
  }
}
