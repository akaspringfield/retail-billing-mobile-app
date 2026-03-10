import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_error.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

class AuthState {
  const AuthState({
    required this.isRestoring,
    required this.isLoading,
    required this.user,
    this.errorMessage,
  });

  const AuthState.initial()
      : isRestoring = true,
        isLoading = false,
        user = null,
        errorMessage = null;

  final bool isRestoring;
  final bool isLoading;
  final UserContext? user;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isRestoring,
    bool? isLoading,
    UserContext? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      isRestoring: isRestoring ?? this.isRestoring,
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.repository) : super(const AuthState.initial()) {
    restore();
  }

  final AuthRepository repository;

  Future<void> restore() async {
    try {
      final hasSession = await repository.hasStoredSession();
      if (!hasSession) {
        state = state.copyWith(isRestoring: false, clearUser: true);
        return;
      }
      final user = await repository.loadCurrentUser();
      state = state.copyWith(isRestoring: false, user: user, clearError: true);
    } catch (_) {
      await repository.logout();
      state = state.copyWith(isRestoring: false, clearUser: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await repository.login(email: email, password: password);
      state = state.copyWith(isLoading: false, user: user, clearError: true);
      return true;
    } on ApiError catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await repository.logout();
    state = state.copyWith(clearUser: true, clearError: true);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
