class AuthSession {
  const AuthSession({
    required this.access,
    required this.refresh,
    required this.userName,
    required this.email,
    this.organizationName,
    this.storeName,
  });

  final String access;
  final String refresh;
  final String userName;
  final String email;
  final String? organizationName;
  final String? storeName;
}

class SessionStore {
  static AuthSession? current;
  static String rememberedEmail = '';

  static void save(AuthSession session, {bool rememberEmail = false}) {
    current = session;
    if (rememberEmail) {
      SessionStore.rememberedEmail = session.email;
    } else {
      SessionStore.rememberedEmail = '';
    }
  }

  static void clear() {
    current = null;
  }
}
