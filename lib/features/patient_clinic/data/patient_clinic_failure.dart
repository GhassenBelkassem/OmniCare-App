import 'package:dio/dio.dart';

/// Why a patient clinic directory operation failed, in UI-actionable terms.
enum PatientClinicFailureKind {
  network,
  timeout,
  contract,
  sessionExpired,
  server,
  unexpected,
}

/// A safe, patient-presentable clinic directory failure.
///
/// The message never contains a backend `detail`, `title`, `instance` or
/// correlation id, and is never `error.toString()`.
class PatientClinicFailure implements Exception {
  const PatientClinicFailure({
    required this.kind,
    required this.message,
    required this.diagnosticCode,
  });

  final PatientClinicFailureKind kind;
  final String message;
  final String diagnosticCode;

  static const PatientClinicFailure networkUnavailable = PatientClinicFailure(
    kind: PatientClinicFailureKind.network,
    message: 'Connection unavailable. Check your network and try again.',
    diagnosticCode: 'CLINIC_NETWORK_UNAVAILABLE',
  );

  static const PatientClinicFailure timedOut = PatientClinicFailure(
    kind: PatientClinicFailureKind.timeout,
    message: 'The clinic list is taking too long. Please try again.',
    diagnosticCode: 'CLINIC_TIMEOUT',
  );

  static const PatientClinicFailure invalidResponse = PatientClinicFailure(
    kind: PatientClinicFailureKind.contract,
    message: 'The clinic list could not be read safely. Please try again.',
    diagnosticCode: 'CLINIC_RESPONSE_INVALID',
  );

  static const PatientClinicFailure sessionExpired = PatientClinicFailure(
    kind: PatientClinicFailureKind.sessionExpired,
    message: 'Your session has expired. Please sign in again.',
    diagnosticCode: 'CLINIC_SESSION_EXPIRED',
  );

  static const PatientClinicFailure serverUnavailable = PatientClinicFailure(
    kind: PatientClinicFailureKind.server,
    message:
        'The clinic directory is temporarily unavailable. Please try again.',
    diagnosticCode: 'CLINIC_SERVER_ERROR',
  );

  static const PatientClinicFailure unexpected = PatientClinicFailure(
    kind: PatientClinicFailureKind.unexpected,
    message: 'Something went wrong. Please try again.',
    diagnosticCode: 'CLINIC_UNEXPECTED',
  );

  static PatientClinicFailure from(Object error) {
    if (error is PatientClinicFailure) return error;
    if (error is PatientClinicContractException) return invalidResponse;
    if (error is DioException) return _fromDio(error);
    return unexpected;
  }

  static PatientClinicFailure _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return timedOut;
      case DioExceptionType.connectionError:
        return networkUnavailable;
      case DioExceptionType.cancel:
        // A stale request was cancelled on purpose; surface as a gentle error.
        return networkUnavailable;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401) return sessionExpired;
        if (status >= 500) return serverUnavailable;
        return invalidResponse;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return error.response == null ? networkUnavailable : invalidResponse;
    }
  }

  @override
  String toString() => 'PatientClinicFailure(${kind.name}, $diagnosticCode)';
}

/// Thrown when a clinic directory payload cannot be trusted.
class PatientClinicContractException implements Exception {
  const PatientClinicContractException(this.reason);

  final String reason;

  @override
  String toString() => 'PatientClinicContractException: $reason';
}
