import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../scan/data/scan_provider.dart';
import '../data/history_provider.dart';
import '../domain/history_model.dart';
import 'scan_detail_page.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text(
          'Historique',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185FA5),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(historyNotifierProvider.notifier).load(),
          ),
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
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Aucune analyse effectuée',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final isPneumonia = item.label == 'PNEUMONIA';
                  final color = isPneumonia ? Colors.red : Colors.green;
                  Uint8List? originalBytes;
                  if (item.imageB64.isNotEmpty) {
                    originalBytes = base64Decode(item.imageB64);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => ScanDetailPage(
                            scan: item,
                            originalImageBytes: originalBytes,
                          ),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(
                          isPneumonia
                              ? Icons.warning_amber
                              : Icons.check_circle,
                          color: color,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      subtitle: Text(
                        'Confiance : ${item.confidence.toStringAsFixed(1)}%\n'
                        '${item.createdAt.substring(0, 10)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        onPressed: () => ref
                            .read(historyNotifierProvider.notifier)
                            .delete(item.id),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
