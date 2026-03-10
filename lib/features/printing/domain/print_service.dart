import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class PrintService {
  const PrintService(this.apiClient);

  final ApiClient apiClient;

  Future<Uint8List> loadInvoicePdf(String invoiceNumber) async {
    final response = await apiClient.get(
      ApiEndpoints.invoicePdf(invoiceNumber),
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes is Uint8List) return bytes;
    if (bytes is List<int>) return Uint8List.fromList(bytes);
    return Uint8List(0);
  }

  Future<void> printInvoice(String invoiceNumber) async {
    final bytes = await loadInvoicePdf(invoiceNumber);
    await Printing.layoutPdf(
      name: 'Invoice $invoiceNumber',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> shareInvoice(String invoiceNumber) async {
    final bytes = await loadInvoicePdf(invoiceNumber);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '$invoiceNumber.pdf',
    );
  }
}

final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService(ref.watch(apiClientProvider));
});
