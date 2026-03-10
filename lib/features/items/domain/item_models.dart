class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.code,
    required this.sku,
    required this.name,
    required this.categoryName,
    required this.unitName,
    required this.sellingPrice,
    required this.isActive,
  });

  final int id;
  final String code;
  final String sku;
  final String name;
  final String categoryName;
  final String unitName;
  final double sellingPrice;
  final bool isActive;

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      id: json['id'] as int,
      code: '${json['code'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      name: '${json['name'] ?? ''}',
      categoryName: '${json['category_name'] ?? 'None'}',
      unitName: '${json['unit_name'] ?? ''}',
      sellingPrice: double.tryParse('${json['selling_price'] ?? 0}') ?? 0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class StockBalance {
  const StockBalance({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.productId,
    required this.productCode,
    required this.productSku,
    required this.productName,
    required this.unitName,
    required this.quantity,
    required this.availableQuantity,
    required this.minimumStock,
    required this.averageCost,
  });

  final int id;
  final int storeId;
  final String storeName;
  final int productId;
  final String productCode;
  final String productSku;
  final String productName;
  final String unitName;
  final double quantity;
  final double availableQuantity;
  final double minimumStock;
  final double averageCost;

  bool get isLowStock => availableQuantity <= minimumStock;

  factory StockBalance.fromJson(Map<String, dynamic> json) {
    return StockBalance(
      id: json['id'] as int,
      storeId: json['store'] as int,
      storeName: '${json['store_name'] ?? ''}',
      productId: json['product'] as int,
      productCode: '${json['product_code'] ?? ''}',
      productSku: '${json['product_sku'] ?? ''}',
      productName: '${json['product_name'] ?? ''}',
      unitName: '${json['unit_name'] ?? ''}',
      quantity: double.tryParse('${json['quantity'] ?? 0}') ?? 0,
      availableQuantity:
          double.tryParse('${json['available_quantity'] ?? 0}') ?? 0,
      minimumStock: double.tryParse('${json['minimum_stock'] ?? 0}') ?? 0,
      averageCost: double.tryParse('${json['average_cost'] ?? 0}') ?? 0,
    );
  }
}
