import 'package:dio/dio.dart';

import '../domain/scheduled_care_models.dart';

enum ScheduledCareFailureKind {
  validation,
  subjectUnavailable,
  bookingContextUnavailable,
  slotNoLongerAvailable,
  versionConflict,
  requestStateConflict,
  actionNotAllowed,
  requestExpired,
  idempotencyConflict,
  unauthenticated,
  forbidden,
  notFound,
  unknownOutcome,
  network,
  server,
  contract,
  unexpected,
}

class ScheduledCareFailure implements Exception {
  const ScheduledCareFailure({
    required this.kind,
    required this.message,
    required this.diagnosticCode,
    this.retryable = false,
  });

  final ScheduledCareFailureKind kind;
  final String message;
  final String diagnosticCode;
  final bool retryable;

  bool get requiresAvailabilityRefresh =>
      kind == ScheduledCareFailureKind.slotNoLongerAvailable;
  bool get requiresSubjectRefresh =>
      kind == ScheduledCareFailureKind.subjectUnavailable;
  bool get requiresContextRefresh =>
      kind == ScheduledCareFailureKind.bookingContextUnavailable;
  bool get requiresAuthoritativeRefresh => switch (kind) {
    ScheduledCareFailureKind.versionConflict ||
    ScheduledCareFailureKind.requestStateConflict ||
    ScheduledCareFailureKind.actionNotAllowed ||
    ScheduledCareFailureKind.requestExpired => true,
    _ => false,
  };

  static ScheduledCareFailure from(Object error) {
    if (error is ScheduledCareFailure) return error;
    if (error is ScheduledCareContractException) {
      return const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.contract,
        message: 'La réponse reçue ne peut pas être vérifiée.',
        diagnosticCode: 'SCHEDULED_CARE_RESPONSE_INVALID',
      );
    }
    if (error is DioException) return _fromDio(error);
    return const ScheduledCareFailure(
      kind: ScheduledCareFailureKind.unexpected,
      message: 'Une erreur est survenue. Veuillez réessayer.',
      diagnosticCode: 'SCHEDULED_CARE_UNEXPECTED',
    );
  }

  static ScheduledCareFailure _fromDio(DioException error) {
    if (hasUnknownHttpOutcome(error)) {
      return const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.unknownOutcome,
        message:
            'Le résultat de l’envoi est incertain. Vérifiez votre connexion '
            'puis réessayez.',
        diagnosticCode: 'BOOKING_REQUEST_OUTCOME_UNKNOWN',
        retryable: true,
      );
    }
    final status = error.response?.statusCode;
    final code = _errorCode(error.response?.data);
    switch (code) {
      case 'VALIDATION_FAILED':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.validation,
          message: 'Certaines informations ne sont plus valides.',
          diagnosticCode: 'VALIDATION_FAILED',
        );
      case 'SUBJECT_NOT_AVAILABLE':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.subjectUnavailable,
          message: 'Cette personne n’est plus disponible pour cette demande.',
          diagnosticCode: 'SUBJECT_NOT_AVAILABLE',
        );
      case 'BOOKING_CONTEXT_NOT_AVAILABLE':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.bookingContextUnavailable,
          message: 'Ce médecin ou ce Cabinet n’est plus disponible.',
          diagnosticCode: 'BOOKING_CONTEXT_NOT_AVAILABLE',
        );
      case 'SLOT_NO_LONGER_AVAILABLE':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.slotNoLongerAvailable,
          message: 'Ce créneau n’est plus disponible. Choisissez-en un autre.',
          diagnosticCode: 'SLOT_NO_LONGER_AVAILABLE',
        );
      case 'VERSION_CONFLICT':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.versionConflict,
          message: 'La demande a changé. Son état a été actualisé.',
          diagnosticCode: 'VERSION_CONFLICT',
        );
      case 'REQUEST_STATE_CONFLICT':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.requestStateConflict,
          message: 'Cette action n’est plus disponible pour cette demande.',
          diagnosticCode: 'REQUEST_STATE_CONFLICT',
        );
      case 'ACTION_NOT_ALLOWED':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.actionNotAllowed,
          message: 'Cette action n’est plus disponible.',
          diagnosticCode: 'ACTION_NOT_ALLOWED',
        );
      case 'REQUEST_EXPIRED':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.requestExpired,
          message: 'Le délai de réponse est terminé.',
          diagnosticCode: 'REQUEST_EXPIRED',
        );
      case 'IDEMPOTENCY_CONFLICT':
        return const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.idempotencyConflict,
          message:
              'Cette demande ne correspond plus à l’envoi initial. '
              'Recommencez depuis les disponibilités.',
          diagnosticCode: 'IDEMPOTENCY_CONFLICT',
        );
    }
    if (status == 401) {
      return const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.unauthenticated,
        message: 'Votre session a expiré. Veuillez vous reconnecter.',
        diagnosticCode: 'SCHEDULED_CARE_UNAUTHENTICATED',
      );
    }
    if (status == 403) {
      return const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.forbidden,
        message: 'Cette action n’est pas autorisée.',
        diagnosticCode: 'SCHEDULED_CARE_FORBIDDEN',
      );
    }
    if (status == 404) {
      return const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.notFound,
        message: 'Cette demande est introuvable.',
        diagnosticCode: 'SCHEDULED_CARE_NOT_FOUND',
      );
    }
    if (status != null && status >= 500) {
      return const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.server,
        message: 'Le service est momentanément indisponible.',
        diagnosticCode: 'SCHEDULED_CARE_SERVER_ERROR',
        retryable: true,
      );
    }
    return const ScheduledCareFailure(
      kind: ScheduledCareFailureKind.contract,
      message: 'La demande n’a pas pu être traitée.',
      diagnosticCode: 'SCHEDULED_CARE_REQUEST_REJECTED',
    );
  }

  static bool isNotFoundResponse(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  static bool hasUnknownHttpOutcome(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.unknown => error.response == null,
    _ => false,
  };

  static String? _errorCode(Object? data) {
    if (data is! Map) return null;
    final value = data['errorCode'] ?? data['code'];
    return value is String ? value.trim() : null;
  }

  @override
  String toString() => 'ScheduledCareFailure($diagnosticCode)';
}
