class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.uuid,
    required this.name,
    required this.code,
  });

  final int id;
  final String uuid;
  final String name;
  final String code;

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['id'] as int,
      uuid: '${json['uuid']}',
      name: '${json['display_name'] ?? json['name'] ?? ''}',
      code: '${json['code'] ?? ''}',
    );
  }
}

class CustomerInfo {
  const CustomerInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
  });

  final int id;
  final String name;
  final String code;
  final String phone;

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      id: json['id'] as int,
      name: '${json['name'] ?? ''}',
      code: '${json['code'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
    );
  }
}

class PaymentMethodInfo {
  const PaymentMethodInfo({
    required this.id,
    required this.name,
    required this.requiresReference,
  });

  final int id;
  final String name;
  final bool requiresReference;

  factory PaymentMethodInfo.fromJson(Map<String, dynamic> json) {
    return PaymentMethodInfo(
      id: json['id'] as int,
      name: '${json['display_name'] ?? json['name'] ?? ''}',
      requiresReference: json['requires_reference'] as bool? ?? false,
    );
  }
}

class ProductInfo {
  const ProductInfo({
    required this.productId,
    required this.code,
    required this.sku,
    required this.name,
    required this.barcode,
    required this.unit,
    required this.sellingPrice,
    required this.availableQuantity,
    required this.isInStock,
  });

  final int productId;
  final String code;
  final String sku;
  final String name;
  final String barcode;
  final String unit;
  final double sellingPrice;
  final double availableQuantity;
  final bool isInStock;

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      productId: json['product_id'] as int,
      code: '${json['code'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      name: '${json['name'] ?? ''}',
      barcode: '${json['barcode'] ?? ''}',
      unit: '${json['unit_short_name'] ?? json['unit'] ?? ''}',
      sellingPrice: double.tryParse('${json['selling_price']}') ?? 0,
      availableQuantity: double.tryParse('${json['available_quantity']}') ?? 0,
      isInStock: json['is_in_stock'] as bool? ?? false,
    );
  }
}

class CartLine {
  CartLine({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
    this.discountPercent = 0,
    this.taxPercent = 0,
  }) : unitPrice = unitPrice ?? product.sellingPrice;

  final ProductInfo product;
  double quantity;
  double unitPrice;
  double discountPercent;
  double taxPercent;

  double get subtotal => quantity * unitPrice;
  double get discountAmount => subtotal * discountPercent / 100;
  double get taxableAmount => subtotal - discountAmount;
  double get taxAmount => taxableAmount * taxPercent / 100;
  double get total => taxableAmount + taxAmount;
}

class CheckoutResult {
  const CheckoutResult({
    required this.invoiceNumber,
    required this.grandTotal,
    required this.paymentStatus,
    required this.paymentMethodName,
  });

  final String invoiceNumber;
  final String grandTotal;
  final String paymentStatus;
  final String paymentMethodName;

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    final sale = json['sale'] as Map<String, dynamic>? ?? {};
    final payment = json['payment'] as Map<String, dynamic>? ?? {};
    return CheckoutResult(
      invoiceNumber: '${sale['invoice_number'] ?? ''}',
      grandTotal: '${sale['grand_total'] ?? ''}',
      paymentStatus: '${sale['payment_status'] ?? ''}',
      paymentMethodName: '${payment['payment_method_name'] ?? ''}',
    );
  }
}
