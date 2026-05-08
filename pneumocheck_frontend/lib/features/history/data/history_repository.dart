import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/history_model.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.read(dioClientProvider)),
);

class HistoryRepository {
  final DioClient _client;
  HistoryRepository(this._client);

  Future<List<HistoryModel>> getHistory() async {
    try {
      final res = await _client.dio.get(ApiConstants.history);
      final data = res.data as Map<String, dynamic>;
      final list = data['history'] as List<dynamic>;
      return list
          .map((e) => HistoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException('Erreur historique : $e');
    }
  }

  Future<void> deleteScan(int scanId) async {
    try {
      await _client.dio.delete('${ApiConstants.history}/$scanId');
    } catch (e) {
      throw AppException('Erreur suppression : $e');
    }
  }
}
