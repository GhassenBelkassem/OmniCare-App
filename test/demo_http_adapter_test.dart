import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/demo/demo_http_adapter.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://static-demo.invalid/api/v1'));
    dio.httpClientAdapter = DemoHttpAdapter();
  });

  test('serves registered fixtures in memory', () async {
    final response = await dio.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );

    expect(response.data, {'unreadCount': 2});
    expect(response.headers.value('x-omnicare-demo'), 'static');
  });

  test('fails closed for an unregistered request', () async {
    expect(
      () => dio.get<Map<String, dynamic>>('/not-registered'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          501,
        ),
      ),
    );
  });
}
