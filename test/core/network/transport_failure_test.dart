import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/transport_failure.dart';

void main() {
  RequestOptions request() => RequestOptions(path: '/protected');

  test('classifies timeout, cancellation, TLS, DNS, and connection loss', () {
    expect(
      TransportFailure.fromDio(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.sendTimeout,
        ),
      ).kind,
      TransportFailureKind.timeout,
    );
    expect(
      TransportFailure.fromDio(
        DioException(requestOptions: request(), type: DioExceptionType.cancel),
      ).kind,
      TransportFailureKind.cancelled,
    );
    expect(
      TransportFailure.fromDio(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.badCertificate,
        ),
      ).kind,
      TransportFailureKind.tls,
    );
    expect(
      TransportFailure.fromDio(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.connectionError,
          error: Exception('Failed host lookup'),
        ),
      ).kind,
      TransportFailureKind.dns,
    );
    expect(
      TransportFailure.fromDio(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.connectionError,
          error: Exception('Connection reset'),
        ),
      ).kind,
      TransportFailureKind.noConnection,
    );
  });

  test('classifies safe HTTP metadata and bounded retry-after', () {
    for (final entry in const <int, TransportFailureKind>{
      401: TransportFailureKind.unauthorized,
      403: TransportFailureKind.forbidden,
      404: TransportFailureKind.notFound,
      409: TransportFailureKind.conflict,
      429: TransportFailureKind.rateLimited,
      500: TransportFailureKind.serverUnavailable,
      503: TransportFailureKind.serverUnavailable,
    }.entries) {
      final response = Response<dynamic>(
        requestOptions: request(),
        statusCode: entry.key,
        data: {'code': 'SAFE_PROBLEM_CODE', 'clinical': 'must-not-retain'},
        headers: Headers.fromMap({
          'retry-after': ['12'],
        }),
      );
      final failure = TransportFailure.fromDio(
        DioException.badResponse(
          statusCode: entry.key,
          requestOptions: request(),
          response: response,
        ),
      );

      expect(failure.kind, entry.value);
      expect(failure.statusCode, entry.key);
      expect(failure.problemCode, 'SAFE_PROBLEM_CODE');
      expect(failure.retryAfter, const Duration(seconds: 12));
      expect(failure.toString(), isNot(contains('must-not-retain')));
    }
  });

  test('invalid responses can be represented without raw payloads', () {
    const failure = TransportFailure.invalidResponse(
      statusCode: 200,
      problemCode: 'MALFORMED_RESPONSE',
    );

    expect(failure.kind, TransportFailureKind.invalidResponse);
    expect(failure.retryAfter, isNull);
  });
}
