import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Entre ton email', false);
      return;
    }

    final token =
        await ref.read(authNotifierProvider.notifier).forgotPassword(email);
    if (!mounted) {
      return;
    }

    if (token != null) {
      _tokenCtrl.text = token;
    }

    _showMessage(
      token != null
          ? 'Token de réinitialisation généré'
          : (ref.read(authNotifierProvider).error ?? 'Erreur envoi du code'),
      token != null,
    );
  }

  Future<void> _resetPassword() async {
    final token = _tokenCtrl.text.trim();
    final newPassword = _newPwdCtrl.text;

    if (token.isEmpty || newPassword.isEmpty) {
      _showMessage('Complète token et nouveau mot de passe', false);
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('Mot de passe trop court (min 6 caractères)', false);
      return;
    }

    final ok = await ref.read(authNotifierProvider.notifier).resetPassword(
          token: token,
          newPassword: newPassword,
        );

    if (!mounted) {
      return;
    }

    _showMessage(
      ok
          ? 'Mot de passe réinitialisé avec succès'
          : (ref.read(authNotifierProvider).error ??
              'Erreur de réinitialisation'),
      ok,
    );

    if (ok) {
      Navigator.pop(context);
    }
  }

  void _showMessage(String message, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final loading = state.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text(
          'Mot de passe oublié',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185FA5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Entre ton email pour générer un token de réinitialisation.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('Email', Icons.email_outlined),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: loading ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Générer le token',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '2. Colle le token puis saisis le nouveau mot de passe.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenCtrl,
              decoration:
                  _inputDeco('Token de réinitialisation', Icons.vpn_key),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPwdCtrl,
              obscureText: _obscure,
              decoration: _inputDeco('Nouveau mot de passe', Icons.lock_outline)
                  .copyWith(
                suffixIcon: IconButton(
                  icon:
                      Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: loading ? null : _resetPassword,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF185FA5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Réinitialiser le mot de passe',
                  style: TextStyle(color: Color(0xFF185FA5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
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
      );
}
