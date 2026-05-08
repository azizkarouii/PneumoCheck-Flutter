import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../scan/data/scan_provider.dart';
import '../data/profile_provider.dart';
import '../domain/profile_model.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileNotifierProvider);
    return state.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Erreur : $e')),
      ),
      data: (profile) => _ProfileContent(profile: profile),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final ProfileModel profile;

  const _ProfileContent({required this.profile});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  late final _nameCtrl = TextEditingController(text: widget.profile.name);
  late final _emailCtrl = TextEditingController(text: widget.profile.email);
  late final _phoneCtrl = TextEditingController(text: widget.profile.phone);
  late final _specialityCtrl =
      TextEditingController(text: widget.profile.speciality);
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();

  Uint8List? _newAvatarBytes;
  bool _loadingProfile = false;
  bool _loadingPassword = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _specialityCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 400,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _newAvatarBytes = bytes);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loadingProfile = true);
    final avatarB64 =
        _newAvatarBytes != null ? base64Encode(_newAvatarBytes!) : null;

    final ok = await ref.read(profileNotifierProvider.notifier).update(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          speciality: _specialityCtrl.text.trim(),
          avatarB64: avatarB64,
        );

    setState(() => _loadingProfile = false);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profil mis à jour' : 'Erreur mise à jour'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _savePassword() async {
    if (_newPwdCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe trop court (min 6 caractères)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loadingPassword = true);
    final ok = await ref
        .read(profileNotifierProvider.notifier)
        .updatePassword(_oldPwdCtrl.text, _newPwdCtrl.text);
    setState(() => _loadingPassword = false);

    if (!mounted) {
      return;
    }

    if (ok) {
      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Mot de passe mis à jour' : 'Ancien mot de passe incorrect',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final avatarB64 = profile.avatarB64;

    Widget avatarWidget;
    if (_newAvatarBytes != null) {
      avatarWidget = CircleAvatar(
        radius: 55,
        backgroundImage: MemoryImage(_newAvatarBytes!),
      );
    } else if (avatarB64.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: 55,
        backgroundImage: MemoryImage(base64Decode(avatarB64)),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 55,
        backgroundColor: const Color(0xFF185FA5).withOpacity(0.15),
        child: Text(
          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'M',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Color(0xFF185FA5),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185FA5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              ref.read(scanNotifierProvider.notifier).reset();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  avatarWidget,
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF185FA5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Email du compte',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            Center(
              child: Text(
                profile.createdAt.isNotEmpty
                    ? 'Membre depuis ${profile.createdAt.substring(0, 10)}'
                    : 'Membre',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Informations personnelles'),
            const SizedBox(height: 12),
            _buildField('Nom complet', _nameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            _buildField(
              'Email',
              _emailCtrl,
              Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildField(
              'Téléphone',
              _phoneCtrl,
              Icons.phone_outlined,
              type: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildField(
              'Spécialité',
              _specialityCtrl,
              Icons.medical_services_outlined,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loadingProfile ? null : _saveProfile,
                icon: _loadingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined, color: Colors.white),
                label: const Text(
                  'Enregistrer le profil',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionTitle('Changer le mot de passe'),
            const SizedBox(height: 12),
            _buildField(
              'Ancien mot de passe',
              _oldPwdCtrl,
              Icons.lock_outline,
              obscure: true,
            ),
            const SizedBox(height: 12),
            _buildField(
              'Nouveau mot de passe',
              _newPwdCtrl,
              Icons.lock_reset_outlined,
              obscure: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _loadingPassword ? null : _savePassword,
                icon: _loadingPassword
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.lock_reset_outlined,
                        color: Color(0xFF185FA5),
                      ),
                label: const Text(
                  'Mettre à jour le mot de passe',
                  style: TextStyle(color: Color(0xFF185FA5), fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF185FA5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionTitle('Activité'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem('Email', profile.email, Icons.email_outlined),
                  _StatItem(
                    'Téléphone',
                    profile.phone.isEmpty ? 'Non renseigné' : profile.phone,
                    Icons.phone_outlined,
                  ),
                  _StatItem(
                    'Spécialité',
                    profile.speciality.isEmpty
                        ? 'Non renseignée'
                        : profile.speciality,
                    Icons.medical_services_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF185FA5)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF185FA5)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF185FA5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF185FA5),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF185FA5), size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
