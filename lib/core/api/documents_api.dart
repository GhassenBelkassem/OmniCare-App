import 'package:dio/dio.dart';

import 'dio_client.dart';

class DocumentsApi {
  final Dio _dio;

  DocumentsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String type,
    String? issueDate,
    required String fileUrl,
    String? filePublicId,
    String? fileProvider,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'type': type,
      'fileUrl': fileUrl,
    };
    if (filePublicId != null && filePublicId.trim().isNotEmpty) {
      payload['filePublicId'] = filePublicId;
    }
    if (fileProvider != null && fileProvider.trim().isNotEmpty) {
      payload['fileProvider'] = fileProvider;
    }
    if (issueDate != null && issueDate.trim().isNotEmpty) {
      payload['issueDate'] = issueDate;
    }

    final res = await _dio.post('/documents', data: payload);
    final data = res.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Unexpected POST /documents response: $data');
  }
}
