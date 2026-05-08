import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/scan_result_model.dart';

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(ref.read(dioClientProvider)),
);

class ScanRepository {
  final DioClient _client;
  ScanRepository(this._client);

  Future<ScanResultModel> predict(String imagePath, {Uint8List? bytes}) async {
    try {
      FormData formData;
      if (kIsWeb && bytes != null) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: imagePath),
        });
      } else {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(imagePath),
        });
      }

      final res = await _client.dio.post(
        ApiConstants.predict,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return ScanResultModel.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException('Erreur prédiction : $e');
    }
  }
}
