import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../l10n/omni_localizations.dart';

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

/// A safe doctor directory failure. Patient screens show [patientMessage]
/// (French, `app_fr.arb`); [message] is kept for the doctor proposal screen,
/// which also uses this type. Neither is ever a backend `detail`, `title`,
/// `instance`, correlation id or `error.toString()`.
class DoctorDirectoryFailure implements Exception {
  const DoctorDirectoryFailure({
    required this.kind,
    required this.message,
    required this.diagnosticCode,
    this.api,
  });

  final DoctorDirectoryFailureKind kind;
  final String message;
  final String diagnosticCode;

  /// The parsed backend failure, when there was one. Never holds server text.
  final ApiFailure? api;

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

  /// Backend errors are read once, by [ApiFailure.fromDio].
  static DoctorDirectoryFailure _fromDio(DioException error) {
    // A stale request was cancelled on purpose; surface as a gentle error.
    if (error.type == DioExceptionType.cancel) return networkUnavailable;
    final api = ApiFailure.fromDio(error);
    if (api.statusCode == null) {
      return switch (api.kind) {
        ApiFailureKind.timeout => timedOut,
        ApiFailureKind.network => networkUnavailable,
        _ => invalidResponse,
      };
    }
    final status = api.statusCode!;
    final failure = switch (status) {
      401 => sessionExpired,
      404 => notFound,
      >= 500 => serverUnavailable,
      _ => invalidResponse,
    };
    return failure._with(api);
  }

  DoctorDirectoryFailure _with(ApiFailure api) => DoctorDirectoryFailure(
    kind: kind,
    message: message,
    diagnosticCode: diagnosticCode,
    api: api,
  );

  /// The French text patient screens show.
  String patientMessage(OmniLocalizations l10n) => switch (kind) {
    DoctorDirectoryFailureKind.network => l10n.apiErrorNetwork,
    DoctorDirectoryFailureKind.timeout => l10n.doctorDirectoryTimeout,
    DoctorDirectoryFailureKind.contract => l10n.doctorDirectoryInvalid,
    DoctorDirectoryFailureKind.sessionExpired => l10n.apiErrorUnauthorized,
    DoctorDirectoryFailureKind.notFound => l10n.doctorDirectoryNotFound,
    DoctorDirectoryFailureKind.server => l10n.doctorDirectoryUnavailable,
    DoctorDirectoryFailureKind.unexpected => l10n.apiErrorUnknown,
  };

  bool get isNotFound => kind == DoctorDirectoryFailureKind.notFound;
  bool get isSessionExpired => kind == DoctorDirectoryFailureKind.sessionExpired;

  @override
  String toString() => 'DoctorDirectoryFailure(${kind.name}, $diagnosticCode)';
}