import 'package:dio/dio.dart';

import 'api_failure.dart';

enum TransportFailureKind {
  timeout,
  noConnection,
  dns,
  tls,
  cancelled,
  rateLimited,
  serverUnavailable,
  unauthorized,
  forbidden,
  conflict,
  notFound,
  invalidResponse,
  unknown,
}

/// Safe transport metadata. It deliberately retains no request/response body,
/// headers, credentials, uploaded bytes, or raw Dio exception.
class TransportFailure implements Exception {
  const TransportFailure({
    required this.kind,
    this.statusCode,
    this.problemCode,
    this.retryAfter,
  });

  const TransportFailure.invalidResponse({this.statusCode, this.problemCode})
    : kind = TransportFailureKind.invalidResponse,
      retryAfter = null;

  final TransportFailureKind kind;
  final int? statusCode;
  final String? problemCode;
  final Duration? retryAfter;

  factory TransportFailure.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final problemCode = apiErrorCodeOf(error.response?.data);
    final retryAfter = _retryAfter(error.response);

    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => TransportFailureKind.timeout,
      DioExceptionType.cancel => TransportFailureKind.cancelled,
      DioExceptionType.badCertificate => TransportFailureKind.tls,
      DioExceptionType.connectionError => _connectionKind(error.error),
      _ => _statusKind(status),
    };

    return TransportFailure(
      kind: kind,
      statusCode: status,
      problemCode: problemCode,
      retryAfter: retryAfter,
    );
  }

  @override
  String toString() =>
      'TransportFailure(kind: $kind, statusCode: $statusCode, problemCode: $problemCode)';
}

TransportFailureKind _statusKind(int? status) {
  if (status == null) return TransportFailureKind.unknown;
  return switch (status) {
    401 => TransportFailureKind.unauthorized,
    403 => TransportFailureKind.forbidden,
    404 => TransportFailureKind.notFound,
    409 => TransportFailureKind.conflict,
    429 => TransportFailureKind.rateLimited,
    >= 500 => TransportFailureKind.serverUnavailable,
    _ => TransportFailureKind.unknown,
  };
}

TransportFailureKind _connectionKind(Object? cause) {
  // Dio exposes DNS and TLS failures through adapter-specific causes. Inspect
  // only enough local text to classify; never retain or expose the cause.
  final type = cause.runtimeType.toString().toLowerCase();
  final description = cause?.toString().toLowerCase() ?? '';
  if (type.contains('handshake') ||
      type.contains('tls') ||
      type.contains('certificate') ||
      description.contains('handshake') ||
      description.contains('certificate')) {
    return TransportFailureKind.tls;
  }
  if (description.contains('failed host lookup') ||
      description.contains('name or service not known') ||
      description.contains('nodename nor servname')) {
    return TransportFailureKind.dns;
  }
  return TransportFailureKind.noConnection;
}

Duration? _retryAfter(Response<dynamic>? response) {
  final raw = response?.headers.value('retry-after')?.trim();
  final seconds = int.tryParse(raw ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}
