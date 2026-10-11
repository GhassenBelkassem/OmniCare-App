import 'package:dio/dio.dart';

class ScheduledCareFailure implements Exception {
  const ScheduledCareFailure({
    required this.message,
    this.errorCode,
    this.statusCode,
    this.unknownOutcome = false,
    this.versionConflict = false,
  });

  const ScheduledCareFailure.sessionChanged()
    : message = 'La session active a changé. Reconnexion en cours…',
      errorCode = 'SESSION_CHANGED',
      statusCode = null,
      unknownOutcome = false,
      versionConflict = false;

  final String message;
  final String? errorCode;
  final int? statusCode;
  final bool unknownOutcome;
  final bool versionConflict;

  bool get isUnauthorized => statusCode == 401 || errorCode == 'UNAUTHORIZED';
  bool get isForbidden => statusCode == 403 || errorCode == 'FORBIDDEN';
  bool get isSessionChanged => errorCode == 'SESSION_CHANGED';
  bool get isSessionBoundary =>
      isUnauthorized || isForbidden || isSessionChanged;

  factory ScheduledCareFailure.from(Object error, {bool command = false}) {
    if (error is ScheduledCareFailure) return error;
    if (error is FormatException) {
      return const ScheduledCareFailure(
        message: 'La réponse du serveur est invalide.',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    if (error is DioException) {
      final response = error.response;
      final body = response?.data;
      final problem = body is Map ? body.cast<String, dynamic>() : null;
      final code =
          _string(problem?['errorCode']) ??
          _string(problem?['code']) ??
          _string(problem?['type'])?.split('/').last;
      final unknown =
          command &&
          response == null &&
          (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.unknown);
      final conflict =
          response?.statusCode == 409 &&
          (code == null ||
              code.contains('VERSION') ||
              code.contains('CONFLICT') ||
              code.contains('STALE'));
      final status = response?.statusCode;
      final resolvedCode =
          code ??
          switch (status) {
            401 => 'UNAUTHORIZED',
            403 => 'FORBIDDEN',
            _ => null,
          };
      return ScheduledCareFailure(
        message: unknown
            ? 'Résultat incertain. Vérification auprès du serveur…'
            : _messageFor(resolvedCode, status),
        errorCode: resolvedCode,
        statusCode: status,
        unknownOutcome: unknown,
        versionConflict: conflict,
      );
    }
    return const ScheduledCareFailure(
      message: 'Une erreur inattendue est survenue.',
      errorCode: 'UNEXPECTED_ERROR',
    );
  }

  static String _messageFor(String? code, int? status) => switch (code) {
    'SLOT_NO_LONGER_AVAILABLE' || 'SLOT_NOT_AVAILABLE' =>
      'Ce créneau n’est plus disponible. Actualisez les disponibilités.',
    'REQUEST_EXPIRED' || 'PROPOSAL_EXPIRED' =>
      'Cette action a expiré. Les informations ont été actualisées.',
    'VERSION_CONFLICT' || 'STALE_VERSION' =>
      'Ces informations ont changé. Elles ont été actualisées.',
    'REQUEST_IDEMPOTENCY_CONFLICT' ||
    'IDEMPOTENCY_KEY_CONFLICT' ||
    'IDEMPOTENCY_CONFLICT' =>
      'Cette opération ne peut pas être rejouée avec des données différentes.',
    'REQUEST_STATE_CONFLICT' || 'ACTION_NOT_ALLOWED' =>
      'Cette action n’est plus disponible. Les informations ont été actualisées.',
    'SUBJECT_NOT_AVAILABLE' =>
      'Le patient sélectionné n’est plus disponible pour cette demande.',
    'BOOKING_CONTEXT_NOT_AVAILABLE' =>
      'Ce médecin ou ce cabinet n’est plus disponible.',
    'FORBIDDEN' => 'Vous n’êtes pas autorisé à effectuer cette action.',
    'UNAUTHORIZED' => 'Votre session a expiré. Reconnectez-vous.',
    'SESSION_CHANGED' => 'La session active a changé. Reconnexion en cours…',
    _ when status == 401 => 'Votre session a expiré. Reconnectez-vous.',
    _ when status == 403 =>
      'Vous n’êtes pas autorisé à effectuer cette action.',
    _ when status == 404 => 'Cette ressource n’existe plus.',
    _ => 'Impossible de terminer cette opération. Réessayez.',
  };

  @override
  String toString() => 'ScheduledCareFailure($errorCode, $statusCode)';
}

String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
