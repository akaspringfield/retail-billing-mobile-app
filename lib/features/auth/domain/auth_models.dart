class UserContext {
  const UserContext({
    required this.userName,
    required this.email,
    this.organizationUuid,
    this.organizationName,
    this.storeUuid,
    this.storeName,
  });

  final String userName;
  final String email;
  final String? organizationUuid;
  final String? organizationName;
  final String? storeUuid;
  final String? storeName;

  factory UserContext.fromLogin(Map<String, dynamic> payload) {
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final organization = data['organization'] as Map<String, dynamic>? ?? {};
    final store = data['store'] as Map<String, dynamic>? ?? {};
    return UserContext(
      userName: '${user['display_name'] ?? user['email'] ?? ''}',
      email: '${user['email'] ?? ''}',
      organizationUuid: organization['uuid'] as String?,
      organizationName: organization['name'] as String?,
      storeUuid: store['uuid'] as String?,
      storeName: store['name'] as String?,
    );
  }

  factory UserContext.fromMe(Map<String, dynamic> payload) {
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    return UserContext(
      userName: '${data['display_name'] ?? data['email'] ?? ''}',
      email: '${data['email'] ?? ''}',
      organizationUuid: data['organization'] as String?,
      storeUuid: data['store'] as String?,
    );
  }
}

class LoginResult {
  const LoginResult({
    required this.access,
    required this.refresh,
    required this.user,
  });

  final String access;
  final String refresh;
  final UserContext user;

  factory LoginResult.fromJson(Map<String, dynamic> payload) {
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    return LoginResult(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
      user: UserContext.fromLogin(payload),
    );
  }
}
