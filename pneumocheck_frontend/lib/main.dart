import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/data/auth_provider.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/scan/presentation/scan_page.dart';

void main() {
  runApp(const ProviderScope(child: PneumoCheckApp()));
}

class PneumoCheckApp extends StatelessWidget {
  const PneumoCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PneumoCheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF185FA5),
        useMaterial3: true,
      ),
      home: const _Splash(),
    );
  }
}

class _Splash extends ConsumerWidget {
  const _Splash();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    return isLoggedIn.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginPage(),
      data: (logged) => logged ? const ScanPage() : const LoginPage(),
    );
  }
}
