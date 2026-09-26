import 'package:dio/dio.dart';

import 'doctor_directory_models.dart';

/// Why a patient doctor directory operation failed, in UI-actionable terms.
enum DoctorDirectoryFailureKind {
  network,
  timeout,
  contract,
  sessionExpired,
  notFound,
  server,
  unexpected,
}

/// A safe, patient-presentable doctor directory failure.
///
/// The message never contains a backend `detail`, `title`, `instance` or
/// correlation id, and is never `error.toString()`.
class DoctorDirectoryFailure implements Exception {
  const DoctorDirectoryFailure({
    required this.kind,
    required this.message,
    required this.diagnosticCode,
  });

  final DoctorDirectoryFailureKind kind;
  final String message;
  final String diagnosticCode;

  static const DoctorDirectoryFailure networkUnavailable = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.network,
    message: 'Connection unavailable. Check your network and try again.',
    diagnosticCode: 'DOCTOR_NETWORK_UNAVAILABLE',
  );

  static const DoctorDirectoryFailure timedOut = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.timeout,
    message: 'The doctor directory is taking too long. Please try again.',
    diagnosticCode: 'DOCTOR_TIMEOUT',
  );

  static const DoctorDirectoryFailure invalidResponse = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.contract,
    message: 'The doctor directory could not be read safely. Please try again.',
    diagnosticCode: 'DOCTOR_RESPONSE_INVALID',
  );

  static const DoctorDirectoryFailure sessionExpired = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.sessionExpired,
    message: 'Your session has expired. Please sign in again.',
    diagnosticCode: 'DOCTOR_SESSION_EXPIRED',
  );

  static const DoctorDirectoryFailure notFound = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.notFound,
    message: 'Ce médecin n\'existe plus ou n\'est plus disponible.',
    diagnosticCode: 'DOCTOR_NOT_FOUND',
  );

  static const DoctorDirectoryFailure serverUnavailable = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.server,
    message: 'The doctor directory is temporarily unavailable. Please try again.',
    diagnosticCode: 'DOCTOR_SERVER_ERROR',
  );

  static const DoctorDirectoryFailure unexpected = DoctorDirectoryFailure(
    kind: DoctorDirectoryFailureKind.unexpected,
    message: 'Something went wrong. Please try again.',
    diagnosticCode: 'DOCTOR_UNEXPECTED',
  );

  static DoctorDirectoryFailure from(Object error) {
    if (error is DoctorDirectoryFailure) return error;
    if (error is DoctorContractException) return invalidResponse;
    if (error is DioException) return _fromDio(error);
    return unexpected;
  }

  static DoctorDirectoryFailure _fromDio(DioException error) {
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
        if (status == 404) return notFound;
        if (status >= 500) return serverUnavailable;
        return invalidResponse;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return error.response == null ? networkUnavailable : invalidResponse;
    }
  }

  bool get isNotFound => kind == DoctorDirectoryFailureKind.notFound;
  bool get isSessionExpired => kind == DoctorDirectoryFailureKind.sessionExpired;

  @override
  String toString() => 'DoctorDirectoryFailure(${kind.name}, $diagnosticCode)';
}