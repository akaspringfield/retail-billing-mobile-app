import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_storage.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  const AuthRepository(this.apiClient);

  final ApiClient apiClient;

  Future<UserContext> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
        'remember_me': true,
      },
      options: Options(extra: {'skipAuth': true}),
    );
    final result = LoginResult.fromJson(response.data as Map<String, dynamic>);
    await authStorage.saveTokens(
      access: result.access,
      refresh: result.refresh,
    );
    await _saveUserContext(result.user);
    return result.user;
  }

  Future<UserContext> loadCurrentUser() async {
    final response = await apiClient.get(ApiEndpoints.me);
    final current = UserContext.fromMe(response.data as Map<String, dynamic>);
    final cached = await _readUserContext();
    return UserContext(
      userName: current.userName.isNotEmpty
          ? current.userName
          : cached?.userName ?? '',
      email: current.email.isNotEmpty ? current.email : cached?.email ?? '',
      organizationUuid: current.organizationUuid ?? cached?.organizationUuid,
      organizationName: cached?.organizationName,
      storeUuid: current.storeUuid ?? cached?.storeUuid,
      storeName: cached?.storeName,
    );
  }

  Future<bool> hasStoredSession() async {
    final access = await authStorage.readAccessToken();
    final refresh = await authStorage.readRefreshToken();
    return access != null && refresh != null;
  }

  Future<void> logout() async {
    await authStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('organization_uuid');
    await prefs.remove('organization_name');
    await prefs.remove('store_uuid');
    await prefs.remove('store_name');
  }

  Future<void> _saveUserContext(UserContext user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user.userName);
    await prefs.setString('user_email', user.email);
    if (user.organizationUuid != null) {
      await prefs.setString('organization_uuid', user.organizationUuid!);
    }
    if (user.organizationName != null) {
      await prefs.setString('organization_name', user.organizationName!);
    }
    if (user.storeUuid != null) {
      await prefs.setString('store_uuid', user.storeUuid!);
    }
    if (user.storeName != null) {
      await prefs.setString('store_name', user.storeName!);
    }
  }

  Future<UserContext?> _readUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name');
    final email = prefs.getString('user_email');
    if (userName == null && email == null) return null;
    return UserContext(
      userName: userName ?? '',
      email: email ?? '',
      organizationUuid: prefs.getString('organization_uuid'),
      organizationName: prefs.getString('organization_name'),
      storeUuid: prefs.getString('store_uuid'),
      storeName: prefs.getString('store_name'),
    );
  }
}
