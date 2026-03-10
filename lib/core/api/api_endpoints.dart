class ApiEndpoints {
  static const login = '/auth/login/';
  static const refresh = '/auth/refresh/';
  static const me = '/auth/me/';
  static const stores = '/stores/';
  static const customers = '/customer/customers/';
  static const paymentMethods = '/v1/masters/payment-methods/';
  static const products = '/v1/products/';
  static const stocks = '/v1/stocks/';
  static const stockAdjust = '/v1/stocks/adjust/';
  static const dashboardReport = '/reports/dashboard/';
  static const productLookup = '/billing/products/lookup/';
  static const checkout = '/billing/checkout/';

  static String invoicePdf(String invoiceNumber) {
    return '/billing/invoices/${Uri.encodeComponent(invoiceNumber)}/pdf/';
  }
}
