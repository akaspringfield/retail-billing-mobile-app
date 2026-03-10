import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.apiBaseUrl,
    required this.themeMode,
    required this.defaultPrintAction,
    required this.receiptWidth,
  });

  final String apiBaseUrl;
  final ThemeMode themeMode;
  final String defaultPrintAction;
  final String receiptWidth;

  AppSettings copyWith({
    String? apiBaseUrl,
    ThemeMode? themeMode,
    String? defaultPrintAction,
    String? receiptWidth,
  }) {
    return AppSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      themeMode: themeMode ?? this.themeMode,
      defaultPrintAction: defaultPrintAction ?? this.defaultPrintAction,
      receiptWidth: receiptWidth ?? this.receiptWidth,
    );
  }
}

class SettingsController extends StateNotifier<AppSettings> {
  static const defaultApiBaseUrl =
      'https://flint-elevation-wolverine.ngrok-free.dev/api';

  SettingsController()
      : super(
          const AppSettings(
            apiBaseUrl: defaultApiBaseUrl,
            themeMode: ThemeMode.system,
            defaultPrintAction: 'preview',
            receiptWidth: '80mm',
          ),
        ) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApiBaseUrl = prefs.getString('api_base_url');
    state = state.copyWith(
      apiBaseUrl: savedApiBaseUrl == null ||
              savedApiBaseUrl == 'http://10.0.2.2:8001/api'
          ? defaultApiBaseUrl
          : savedApiBaseUrl,
      themeMode: _themeFromName(prefs.getString('theme_mode')),
      defaultPrintAction:
          prefs.getString('default_print_action') ?? state.defaultPrintAction,
      receiptWidth: prefs.getString('receipt_width') ?? state.receiptWidth,
    );
  }

  Future<void> update(AppSettings next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', next.apiBaseUrl.trim());
    await prefs.setString('theme_mode', next.themeMode.name);
    await prefs.setString('default_print_action', next.defaultPrintAction);
    await prefs.setString('receipt_width', next.receiptWidth);
    state = next;
  }

  ThemeMode _themeFromName(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(),
);
