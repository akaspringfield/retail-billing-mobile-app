import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/settings_controller.dart';
import '../auth/auth_storage.dart';
import '../errors/api_error.dart';
import 'api_endpoints.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return ApiClient(settings.apiBaseUrl);
});

class ApiClient {
  ApiClient(String baseUrl)
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl.replaceFirst(RegExp(r'/+$'), ''),
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await authStorage.readAccessToken();
          if (options.extra['skipAuth'] != true &&
              token != null &&
              token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['skipAuth'] != true &&
              error.requestOptions.extra['retried'] != true) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final retry = await _retry(error.requestOptions);
              handler.resolve(retry);
              return;
            }
          }
          handler.reject(error);
        },
      ),
    );
  }

  final Dio dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _toApiError(error);
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      return await dio.post(path, data: data, options: options);
    } on DioException catch (error) {
      throw _toApiError(error);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      responseType: requestOptions.responseType,
      extra: {...requestOptions.extra, 'retried': true},
    );
    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<bool> _refreshToken() async {
    final refresh = await authStorage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return false;
    }

    try {
      final response = await Dio(dio.options).post<dynamic>(
        ApiEndpoints.refresh,
        data: {'refresh': refresh},
      );
      final payload = _asMap(response.data);
      final data = _asMap(payload['data']);
      final access = data['access'] as String?;
      final nextRefresh = data['refresh'] as String?;
      if (access == null || nextRefresh == null) {
        return false;
      }
      await authStorage.saveTokens(access: access, refresh: nextRefresh);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Token refresh failed: ${error.runtimeType}');
      }
      await authStorage.clear();
      return false;
    }
  }

  ApiError _toApiError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiError('The server took too long to respond.',
          statusCode: statusCode);
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiError(
          'Cannot reach the backend. Check the API URL and network.');
    }

    final message = _messageFromData(error.response?.data);
    return ApiError(message, statusCode: statusCode);
  }

  String _messageFromData(Object? data) {
    if (data == null) {
      return 'Request failed.';
    }
    if (data is String) {
      if (data.contains('<html') || data.contains('<!DOCTYPE html')) {
        return 'Server error. Check backend logs.';
      }
      return data;
    }
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['detail'];
      if (message is String) return message;
      if (message is List && message.isNotEmpty) return '${message.first}';
      if (message is Map<String, dynamic>) return _firstFieldError(message);
      return _firstFieldError(data);
    }
    return 'Request failed.';
  }

  String _firstFieldError(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) return value;
      if (value is List && value.isNotEmpty) return '${value.first}';
    }
    return 'Please check the submitted details.';
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String) return jsonDecode(value) as Map<String, dynamic>;
    return {};
  }
}
