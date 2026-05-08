import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioClientProvider)),
);

class AuthRepository {
  final DioClient _client;
  final _storage = const FlutterSecureStorage();

  AuthRepository(this._client);

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String speciality,
    String? avatarB64,
    required String password,
  }) async {
    try {
      final res = await _client.dio.post(ApiConstants.register, data: {
        'name': name,
        'email': email,
        'phone': phone,
        'speciality': speciality,
        if (avatarB64 != null) 'avatar_b64': avatarB64,
        'password': password,
      });
      final user = UserModel.fromJson(res.data as Map<String, dynamic>);
      await _storage.write(key: 'jwt_token', value: user.token);
      return user;
    } catch (e) {
      throw AppException('Erreur inscription : $e');
    }
  }

  Future<String> login(String email, String password) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.login,
        data: 'username=$email&password=$password',
        options: _formOptions(),
      );
      final data = res.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      await _storage.write(key: 'jwt_token', value: token);
      return token;
    } catch (e) {
      throw AppException('Email ou mot de passe incorrect');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<String> forgotPassword(String email) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.forgotPassword,
        data: {'email': email},
      );
      final data = res.data as Map<String, dynamic>;
      return data['reset_token']?.toString() ?? '';
    } catch (e) {
      throw AppException('Impossible d\'envoyer le code de réinitialisation');
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _client.dio.post(
        ApiConstants.resetPassword,
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      throw AppException('Code invalide ou expiration du code');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null;
  }
}

Options _formOptions() => Options(
      contentType: 'application/x-www-form-urlencoded',
    );
