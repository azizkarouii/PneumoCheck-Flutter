import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/history_model.dart';
import 'history_repository.dart';

class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryModel>>> {
  final HistoryRepository _repo;

  HistoryNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _repo.getHistory();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(int scanId) async {
    await _repo.deleteScan(scanId);
    await load();
  }
}

final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryModel>>>(
  (ref) => HistoryNotifier(ref.read(historyRepositoryProvider)),
);
