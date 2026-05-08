import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.read(dioClientProvider)),
);

class ProfileRepository {
  final DioClient _client;

  ProfileRepository(this._client);

  Future<ProfileModel> getProfile() async {
    try {
      final res = await _client.dio.get('/profile');
      return ProfileModel.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException('Erreur chargement profil : $e');
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? speciality,
    String? avatarB64,
  }) async {
    try {
      await _client.dio.put('/profile', data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (speciality != null) 'speciality': speciality,
        if (avatarB64 != null) 'avatar_b64': avatarB64,
      });
    } catch (e) {
      throw AppException('Erreur mise à jour : $e');
    }
  }

  Future<void> updatePassword(String oldPwd, String newPwd) async {
    try {
      await _client.dio.put('/profile/password', queryParameters: {
        'old_password': oldPwd,
        'new_password': newPwd,
      });
    } catch (e) {
      throw AppException('Ancien mot de passe incorrect');
    }
  }
}
