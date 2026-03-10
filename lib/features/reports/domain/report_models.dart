class DashboardSummary {
  const DashboardSummary({
    required this.range,
    required this.metrics,
    required this.topProducts,
    required this.lowStock,
  });

  final Map<String, dynamic> range;
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> lowStock;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return DashboardSummary(
      range: data['range'] as Map<String, dynamic>? ?? {},
      metrics: data['metrics'] as Map<String, dynamic>? ?? {},
      topProducts: (data['top_products'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      lowStock: (data['low_stock'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}
