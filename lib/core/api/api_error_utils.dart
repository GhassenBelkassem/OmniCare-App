import 'package:dio/dio.dart';

String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      final msg2 = data['error']?.toString();
      if (msg2 != null && msg2.isNotEmpty) {
        return msg2;
      }
    }
    return error.message ?? 'Network error';
  }

  return error.toString();
}
