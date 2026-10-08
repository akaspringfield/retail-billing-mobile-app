List<Map<String, dynamic>> readList(Object? payload) {
  if (payload is List) {
    return payload.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
  }
  if (payload is Map) {
    final data = payload.cast<String, dynamic>();
    final results = data['results'];
    final nestedData = data['data'];
    if (results is List) return readList(results);
    if (nestedData is List) return readList(nestedData);
    if (nestedData is Map) return readList(nestedData);
  }
  return [];
}

Map<String, dynamic> readMap(Object? payload) {
  if (payload is Map) {
    final map = payload.cast<String, dynamic>();
    final data = map['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return map;
  }
  return {};
}

String textValue(Map<String, dynamic> record, List<String> keys, {String fallback = '-'}) {
  for (final key in keys) {
    final value = record[key];
    if (value != null && value.toString().trim().isNotEmpty) return value.toString();
  }
  return fallback;
}

double numberValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
