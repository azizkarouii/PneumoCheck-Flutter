import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/profile_model.dart';
import 'profile_repository.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel>> {
  final ProfileRepository _repo;

  ProfileNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _repo.getProfile();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> update({
    String? name,
    String? email,
    String? phone,
    String? speciality,
    String? avatarB64,
  }) async {
    try {
      await _repo.updateProfile(
        name: name,
        email: email,
        phone: phone,
        speciality: speciality,
        avatarB64: avatarB64,
      );
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePassword(String oldPwd, String newPwd) async {
    try {
      await _repo.updatePassword(oldPwd, newPwd);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel>>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});
