import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../history/presentation/history_page.dart';
import '../../history/domain/history_model.dart';
import '../../history/presentation/scan_detail_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/scan_provider.dart';
import '../domain/scan_result_model.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  int _currentIndex = 0;

  final _pages = const [
    _ScanTab(),
    HistoryPage(),
    DashboardPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _ScanTab extends ConsumerWidget {
  const _ScanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanNotifierProvider);
    final notifier = ref.read(scanNotifierProvider.notifier);

    Future<void> applyPickedImage(XFile picked) async {
      final bytes = await picked.readAsBytes();
      if (kIsWeb) {
        notifier.setImage(picked.name, bytes: bytes);
      } else {
        notifier.setImage(picked.path, bytes: bytes);
      }
    }

    Future<void> pickImage(ImageSource source) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        await applyPickedImage(picked);
      }
    }

    Future<void> captureFromCamera() async {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune caméra détectée sur cet appareil.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final selected = cameras
                .where((c) => c.lensDirection == CameraLensDirection.back)
                .isNotEmpty
            ? cameras
                .firstWhere((c) => c.lensDirection == CameraLensDirection.back)
            : cameras.first;

        if (!context.mounted) {
          return;
        }

        final captured = await Navigator.push<XFile?>(
          context,
          MaterialPageRoute(
            builder: (_) => _CameraCapturePage(camera: selected),
          ),
        );

        if (captured != null) {
          await applyPickedImage(captured);
        }
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caméra non disponible. Utilise Galerie.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text(
          'PneumoCheck',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185FA5),
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
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF185FA5).withOpacity(0.3),
                ),
              ),
              child: state.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? Image.memory(
                              state.imageBytes!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 250,
                            )
                          : Image.file(
                              File(state.imagePath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 250,
                            ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 64,
                          color: Color(0xFF185FA5),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sélectionner une radiographie',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galerie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF185FA5),
                      side: const BorderSide(color: Color(0xFF185FA5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: captureFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Caméra'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF185FA5),
                      side: const BorderSide(color: Color(0xFF185FA5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: state.imagePath == null ||
                        state.status == ScanStatus.loading
                    ? null
                    : notifier.predict,
                icon: state.status == ScanStatus.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.white),
                label: Text(
                  state.status == ScanStatus.loading
                      ? 'Analyse en cours...'
                      : 'Analyser',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (state.status == ScanStatus.success && state.result != null)
              _ResultCard(
                result: state.result!,
                originalImageBytes: state.imageBytes,
              ),
            if (state.status == ScanStatus.error)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.error ?? 'Erreur',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraCapturePage extends StatefulWidget {
  final CameraDescription camera;

  const _CameraCapturePage({required this.camera});

  @override
  State<_CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<_CameraCapturePage> {
  late final CameraController _controller;
  late final Future<void> _initializeFuture;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      await _initializeFuture;
      final file = await _controller.takePicture();
      if (!mounted) {
        return;
      }
      Navigator.pop(context, file);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de capturer la photo.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Capture caméra'),
      ),
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            children: [
              Center(child: CameraPreview(_controller)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: FilledButton(
                    onPressed: _capturing ? null : _takePicture,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF185FA5),
                      minimumSize: const Size(160, 48),
                    ),
                    child: _capturing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Capturer'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ScanResultModel result;
  final Uint8List? originalImageBytes;

  const _ResultCard({required this.result, this.originalImageBytes});

  @override
  Widget build(BuildContext context) {
    final isPneumonia = result.label == 'PNEUMONIA';
    final color = isPneumonia ? Colors.red : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(
                isPneumonia ? Icons.warning_amber : Icons.check_circle,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                result.label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confiance : ${result.confidence.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: result.confidence / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.heatmap.isNotEmpty) ...[
          const Text(
            'Carte Grad-CAM - zones analysées',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(result.heatmap),
              fit: BoxFit.contain,
              width: double.infinity,
              height: 220,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScanDetailPage(
                  scan: HistoryModel(
                    id: result.scanId,
                    label: result.label,
                    confidence: result.confidence,
                    heatmap: result.heatmap,
                    imageB64: '',
                    createdAt: DateTime.now().toString(),
                  ),
                  originalImageBytes: originalImageBytes,
                ),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text(
              'Voir détail & Rapport PDF',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185FA5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
