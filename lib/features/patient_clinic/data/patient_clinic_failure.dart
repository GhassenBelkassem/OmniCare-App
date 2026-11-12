import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../l10n/omni_localizations.dart';

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
/// Its text comes from [message] (French, `app_fr.arb`): never a backend
/// `detail`, `title`, `instance` or correlation id, never `error.toString()`.
class PatientClinicFailure implements Exception {
  const PatientClinicFailure({
    required this.kind,
    required this.diagnosticCode,
    this.api,
  });

  final PatientClinicFailureKind kind;
  final String diagnosticCode;

  /// The parsed backend failure, when there was one. Never holds server text.
  final ApiFailure? api;

  static const PatientClinicFailure networkUnavailable = PatientClinicFailure(
    kind: PatientClinicFailureKind.network,
    diagnosticCode: 'CLINIC_NETWORK_UNAVAILABLE',
  );

  static const PatientClinicFailure timedOut = PatientClinicFailure(
    kind: PatientClinicFailureKind.timeout,
    diagnosticCode: 'CLINIC_TIMEOUT',
  );

  static const PatientClinicFailure invalidResponse = PatientClinicFailure(
    kind: PatientClinicFailureKind.contract,
    diagnosticCode: 'CLINIC_RESPONSE_INVALID',
  );

  static const PatientClinicFailure sessionExpired = PatientClinicFailure(
    kind: PatientClinicFailureKind.sessionExpired,
    diagnosticCode: 'CLINIC_SESSION_EXPIRED',
  );

  static const PatientClinicFailure serverUnavailable = PatientClinicFailure(
    kind: PatientClinicFailureKind.server,
    diagnosticCode: 'CLINIC_SERVER_ERROR',
  );

  static const PatientClinicFailure unexpected = PatientClinicFailure(
    kind: PatientClinicFailureKind.unexpected,
    diagnosticCode: 'CLINIC_UNEXPECTED',
  );

  static PatientClinicFailure from(Object error) {
    if (error is PatientClinicFailure) return error;
    if (error is PatientClinicContractException) return invalidResponse;
    if (error is DioException) return _fromDio(error);
    return unexpected;
  }

  /// Backend errors are read once, by [ApiFailure.fromDio].
  static PatientClinicFailure _fromDio(DioException error) {
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
    final failure = status == 401
        ? sessionExpired
        : status >= 500
        ? serverUnavailable
        : invalidResponse;
    return failure._with(api);
  }

  PatientClinicFailure _with(ApiFailure api) => PatientClinicFailure(
    kind: kind,
    diagnosticCode: diagnosticCode,
    api: api,
  );

  /// The French text for this failure.
  String message(OmniLocalizations l10n) => switch (kind) {
    PatientClinicFailureKind.network => l10n.apiErrorNetwork,
    PatientClinicFailureKind.timeout => l10n.clinicListTimeout,
    PatientClinicFailureKind.contract => l10n.clinicListInvalid,
    PatientClinicFailureKind.sessionExpired => l10n.apiErrorUnauthorized,
    PatientClinicFailureKind.server => l10n.clinicListUnavailable,
    PatientClinicFailureKind.unexpected => l10n.apiErrorUnknown,
  };

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
