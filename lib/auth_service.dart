import 'api_client.dart';
import 'session_store.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AuthSession> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final payload = await _api.post('/auth/login/', {
      'email': email,
      'password': password,
      'remember_me': rememberMe,
    });
    final session = _sessionFromResponse(payload);
    SessionStore.save(session, rememberEmail: rememberMe);
    return session;
  }

  Future<AuthSession> register(Map<String, dynamic> form) async {
    final payload = await _api.post('/auth/register/', form);
    final session = _sessionFromResponse(payload);
    SessionStore.save(session);
    return session;
  }

  Future<String> forgotPassword(String email) async {
    final response = await _api.post('/auth/forgot-password/', {'email': email});
    return response['message']?.toString() ?? 'OTP sent to registered email.';
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _api.post('/auth/reset-password/', {
      'email': email,
      'otp': otp,
      'password': password,
      'confirm_password': confirmPassword,
    });
    return response['message']?.toString() ?? 'Password reset successfully.';
  }

  Future<Map<String, dynamic>> currentUser() async {
    final response = await _api.get('/auth/me/');
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      return response;
    }
    throw ApiException('Unable to load account details.');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) async {
    final response = await _api.patch('/auth/profile/', payload);
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return response;
  }

  AuthSession _sessionFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Login response is missing session data.');
    }

    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final organization = (data['organization'] as Map?)?.cast<String, dynamic>() ?? {};
    final store = (data['store'] as Map?)?.cast<String, dynamic>() ?? {};
    final access = data['access']?.toString() ?? '';
    final refresh = data['refresh']?.toString() ?? '';

    if (access.isEmpty || refresh.isEmpty) {
      throw ApiException('Login response did not include tokens.');
    }

    return AuthSession(
      access: access,
      refresh: refresh,
      userName: user['display_name']?.toString().trim().isNotEmpty == true
          ? user['display_name'].toString()
          : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
      email: user['email']?.toString() ?? '',
      organizationName: organization['name']?.toString(),
      storeName: store['name']?.toString(),
    );
  }
}
