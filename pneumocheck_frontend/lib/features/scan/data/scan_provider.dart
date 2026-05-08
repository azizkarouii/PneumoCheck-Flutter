import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../history/data/history_provider.dart';
import '../domain/scan_result_model.dart';
import 'scan_repository.dart';

enum ScanStatus { initial, loading, success, error }

class ScanState {
  final ScanStatus status;
  final ScanResultModel? result;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? error;

  static const Object _unset = Object();

  const ScanState({
    this.status = ScanStatus.initial,
    this.result,
    this.imagePath,
    this.imageBytes,
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    Object? result = _unset,
    Object? imagePath = _unset,
    Object? imageBytes = _unset,
    Object? error = _unset,
  }) {
    return ScanState(
      status: status ?? this.status,
      result:
          identical(result, _unset) ? this.result : result as ScanResultModel?,
      imagePath:
          identical(imagePath, _unset) ? this.imagePath : imagePath as String?,
      imageBytes: identical(imageBytes, _unset)
          ? this.imageBytes
          : imageBytes as Uint8List?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  final ScanRepository _repo;
  final Ref _ref;

  ScanNotifier(this._repo, this._ref) : super(const ScanState());

  void setImage(String path, {Uint8List? bytes}) {
    state = state.copyWith(
      imagePath: path,
      imageBytes: bytes,
      status: ScanStatus.initial,
      result: null,
      error: null,
    );
  }

  Future<void> predict() async {
    if (state.imagePath == null) {
      return;
    }

    state = state.copyWith(status: ScanStatus.loading);
    try {
      final result = await _repo.predict(
        state.imagePath!,
        bytes: state.imageBytes,
      );
      state = state.copyWith(status: ScanStatus.success, result: result);
      await _ref.read(historyNotifierProvider.notifier).load();
      _ref.invalidate(dashboardProvider);
    } catch (e) {
      state = state.copyWith(status: ScanStatus.error, error: e.toString());
    }
  }

  void reset() {
    state = const ScanState();
  }
}

final scanNotifierProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(ref.read(scanRepositoryProvider), ref),
);
