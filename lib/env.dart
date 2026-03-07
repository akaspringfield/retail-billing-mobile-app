import 'package:flutter/services.dart';

class AppEnv {
  static String apiBaseUrl = 'http://127.0.0.1:8001/api';

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('.env');
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final index = trimmed.indexOf('=');
        if (index <= 0) continue;
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        if (key == 'API_BASE_URL' && value.isNotEmpty) {
          apiBaseUrl = value.replaceAll(RegExp(r'/+$'), '');
        }
      }
    } catch (_) {
      // Keep the development fallback when .env is not bundled.
    }
  }
}
