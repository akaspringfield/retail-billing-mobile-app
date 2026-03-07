import 'package:flutter/services.dart';

class MobileActions {
  static const _channel = MethodChannel('retail_billing/actions');

  static Future<void> openUrl(String url) async {
    if (url.trim().isEmpty) return;
    await _channel.invokeMethod<void>('openUrl', {'url': url});
  }

  static Future<void> shareText(
      {required String subject, required String text}) async {
    await _channel.invokeMethod<void>('shareText', {
      'subject': subject,
      'text': text,
    });
  }

  static Future<String?> getPreference(String key) {
    return _channel.invokeMethod<String>('getPreference', {'key': key});
  }

  static Future<void> setPreference(String key, String value) {
    return _channel.invokeMethod<void>('setPreference', {
      'key': key,
      'value': value,
    });
  }

  static Future<void> removePreference(String key) {
    return _channel.invokeMethod<void>('removePreference', {'key': key});
  }
}
