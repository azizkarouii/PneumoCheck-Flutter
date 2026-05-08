import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

enum AuthStatus { initial, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthNotifier(this._repo) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _repo.login(email, password);
      state = const AuthState(status: AuthStatus.success);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String speciality,
    String? avatarB64,
    required String password,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _repo.register(
        name: name,
        email: email,
        phone: phone,
        speciality: speciality,
        avatarB64: avatarB64,
        password: password,
      );
      state = const AuthState(status: AuthStatus.success);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  Future<String?> forgotPassword(String email) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final token = await _repo.forgotPassword(email);
      state = const AuthState(status: AuthStatus.success);
      return token.isEmpty ? null : token;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
      return null;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _repo.resetPassword(
        token: token,
        newPassword: newPassword,
      );
      state = const AuthState(status: AuthStatus.success);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
      return false;
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

final isLoggedInProvider = FutureProvider<bool>(
  (ref) => ref.read(authRepositoryProvider).isLoggedIn(),
);
