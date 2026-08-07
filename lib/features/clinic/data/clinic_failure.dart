import 'package:dio/dio.dart';

import 'clinic_models.dart';

/// How a clinic operation failed, expressed in terms the UI can act on.
enum ClinicFailureKind {
  /// Transport problem. Always retryable, never a membership decision.
  network,

  /// The response could not be trusted (malformed payload, unknown role...).
  contract,

  /// The account may not use this clinic workspace.
  accessDenied,

  /// The membership itself is suspended, ended or missing.
  membershipUnavailable,

  /// The clinic is not usable (inactive, unknown, context unavailable).
  clinicUnavailable,

  /// The authentication session is gone. Owned by the auth pipeline.
  sessionExpired,

  /// Anything else, including server errors.
  unexpected,
}

/// A safe, user-presentable clinic failure.
///
/// [message] never contains backend `detail`, `instance`, `requestId`,
/// `errorCode` or any clinic identifier. [diagnosticCode] is kept only for
/// internal decisions and tests and must never be rendered.
class ClinicFailure {
  const ClinicFailure({
    required this.kind,
    required this.message,
    required this.retryable,
    this.diagnosticCode,
  });

  final ClinicFailureKind kind;
  final String message;
  final bool retryable;
  final String? diagnosticCode;

  bool get isTerminalAccessProblem =>
      kind == ClinicFailureKind.accessDenied ||
      kind == ClinicFailureKind.membershipUnavailable ||
      kind == ClinicFailureKind.clinicUnavailable;

  static const ClinicFailure notAClinicAccount = ClinicFailure(
    kind: ClinicFailureKind.accessDenied,
    message: 'This account does not have clinic access on mobile.',
    retryable: false,
    diagnosticCode: 'CLINIC_ACCESS_FAMILY_MISMATCH',
  );

  static const ClinicFailure noActiveMembership = ClinicFailure(
    kind: ClinicFailureKind.membershipUnavailable,
    message: 'You do not have an active clinic membership right now.',
    retryable: false,
    diagnosticCode: 'CLINIC_MEMBERSHIP_REQUIRED',
  );

  static const ClinicFailure roleMismatch = ClinicFailure(
    kind: ClinicFailureKind.accessDenied,
    message: 'Your clinic access could not be confirmed for this workspace.',
    retryable: false,
    diagnosticCode: 'CLINIC_ROLE_MISMATCH',
  );

  static const ClinicFailure invalidResponse = ClinicFailure(
    kind: ClinicFailureKind.contract,
    message: 'Clinic information could not be loaded safely.',
    retryable: true,
    diagnosticCode: 'CLINIC_RESPONSE_INVALID',
  );

  static const ClinicFailure networkUnavailable = ClinicFailure(
    kind: ClinicFailureKind.network,
    message: 'Connection unavailable. Check your network and try again.',
    retryable: true,
    diagnosticCode: 'CLINIC_NETWORK_UNAVAILABLE',
  );

  static const ClinicFailure sessionExpired = ClinicFailure(
    kind: ClinicFailureKind.sessionExpired,
    message: 'Your session has expired. Please sign in again.',
    retryable: false,
    diagnosticCode: 'CLINIC_SESSION_EXPIRED',
  );

  static const ClinicFailure unexpected = ClinicFailure(
    kind: ClinicFailureKind.unexpected,
    message: 'Clinic services are temporarily unavailable. Please try again.',
    retryable: true,
    diagnosticCode: 'CLINIC_UNEXPECTED',
  );

  /// Maps any thrown object into a safe failure.
  static ClinicFailure from(Object error) {
    if (error is ClinicFailure) return error;
    if (error is ClinicContractException) return invalidResponse;
    if (error is DioException) return _fromDio(error);
    if (error is FormatException) return invalidResponse;
    return unexpected;
  }

  static ClinicFailure _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return networkUnavailable;
      case DioExceptionType.cancel:
        return const ClinicFailure(
          kind: ClinicFailureKind.unexpected,
          message: 'Clinic information could not be loaded. Please try again.',
          retryable: true,
          diagnosticCode: 'CLINIC_REQUEST_CANCELLED',
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (error.response == null) return networkUnavailable;
        break;
      case DioExceptionType.badResponse:
        break;
    }

    final response = error.response;
    if (response == null) return networkUnavailable;

    final status = response.statusCode ?? 0;
    if (status == 401) return sessionExpired;

    final problem = _problemErrorCode(response.data);
    final mapped = _fromProblemCode(problem);
    if (mapped != null) return mapped;

    if (status == 403) {
      return const ClinicFailure(
        kind: ClinicFailureKind.accessDenied,
        message: 'You do not have access to this clinic workspace.',
        retryable: false,
        diagnosticCode: 'CLINIC_SCOPE_FORBIDDEN',
      );
    }
    if (status == 404 || status == 409 || status == 410) {
      return const ClinicFailure(
        kind: ClinicFailureKind.clinicUnavailable,
        message: 'This clinic workspace is not available right now.',
        retryable: false,
        diagnosticCode: 'CLINIC_CONTEXT_UNAVAILABLE',
      );
    }
    if (status == 400 || status == 422) return invalidResponse;
    return unexpected;
  }

  /// RFC 9457 ProblemDetail `errorCode` mapping. The backend `detail`,
  /// `instance` and `requestId` fields are deliberately ignored.
  static ClinicFailure? _fromProblemCode(String? errorCode) {
    switch (errorCode) {
      case 'CLINIC_CONTEXT_UNAVAILABLE':
        return const ClinicFailure(
          kind: ClinicFailureKind.clinicUnavailable,
          message: 'Your clinic workspace is not available right now.',
          retryable: false,
          diagnosticCode: 'CLINIC_CONTEXT_UNAVAILABLE',
        );
      case 'CLINIC_SCOPE_FORBIDDEN':
        return const ClinicFailure(
          kind: ClinicFailureKind.accessDenied,
          message: 'You do not have access to this clinic workspace.',
          retryable: false,
          diagnosticCode: 'CLINIC_SCOPE_FORBIDDEN',
        );
      case 'CLINIC_MEMBERSHIP_SUSPENDED':
        return const ClinicFailure(
          kind: ClinicFailureKind.membershipUnavailable,
          message: 'Access to this clinic is currently suspended.',
          retryable: false,
          diagnosticCode: 'CLINIC_MEMBERSHIP_SUSPENDED',
        );
      case 'CLINIC_MEMBERSHIP_ENDED':
        return const ClinicFailure(
          kind: ClinicFailureKind.membershipUnavailable,
          message: 'Your membership in this clinic has ended.',
          retryable: false,
          diagnosticCode: 'CLINIC_MEMBERSHIP_ENDED',
        );
      case 'CLINIC_MEMBERSHIP_REQUIRED':
        return noActiveMembership;
      case 'CLINIC_NOT_ACTIVE':
        return const ClinicFailure(
          kind: ClinicFailureKind.clinicUnavailable,
          message: 'This clinic is not active.',
          retryable: false,
          diagnosticCode: 'CLINIC_NOT_ACTIVE',
        );
      case 'CLINIC_PROFESSIONAL_ROLE_INVALID':
        return const ClinicFailure(
          kind: ClinicFailureKind.accessDenied,
          message: 'Your professional role is not available on mobile.',
          retryable: false,
          diagnosticCode: 'CLINIC_PROFESSIONAL_ROLE_INVALID',
        );
      case 'CLINIC_CAPABILITY_FORBIDDEN':
        return const ClinicFailure(
          kind: ClinicFailureKind.accessDenied,
          message: 'You do not have permission for this clinic action.',
          retryable: false,
          diagnosticCode: 'CLINIC_CAPABILITY_FORBIDDEN',
        );
      default:
        return null;
    }
  }

  static String? _problemErrorCode(Object? data) {
    if (data is! Map) return null;
    final value = data['errorCode'];
    if (value is! String) return null;
    final normalized = value.trim().toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }

  @override
  String toString() => 'ClinicFailure(${kind.name}, $diagnosticCode)';
}
