import 'package:dio/dio.dart';

import '../workspace/doctor_workspace_bootstrap.dart';
import '../workspace/doctor_workspace_bootstrap_api.dart';

abstract interface class DoctorUrgentRuntimeRepositoryContract {
  Future<DoctorUrgentRuntimeSnapshot> get({CancelToken? cancelToken});

  Future<DoctorUrgentRuntimeSnapshot> replace({
    required int expectedRevision,
    required bool homeEnabled,
    required bool cabinetEnabled,
  });
}

class DoctorUrgentRuntimeRepository
    implements DoctorUrgentRuntimeRepositoryContract {
  const DoctorUrgentRuntimeRepository(this._api);

  final DoctorUrgentRuntimeApiContract _api;

  @override
  Future<DoctorUrgentRuntimeSnapshot> get({CancelToken? cancelToken}) =>
      _api.getUrgentRuntime(cancelToken: cancelToken);

  @override
  Future<DoctorUrgentRuntimeSnapshot> replace({
    required int expectedRevision,
    required bool homeEnabled,
    required bool cabinetEnabled,
  }) => _api.replaceUrgentRuntime(
    expectedRevision: expectedRevision,
    homeEnabled: homeEnabled,
    cabinetEnabled: cabinetEnabled,
  );
}

enum DoctorUrgentRuntimeFailureKind {
  conflict,
  activationBlocked,
  unavailable,
  sessionRejected,
  network,
  invalidResponse,
  unknown,
}

class DoctorUrgentRuntimeFailure implements Exception {
  DoctorUrgentRuntimeFailure({
    required this.kind,
    required this.message,
    this.blockingReasons = const [],
  });

  final DoctorUrgentRuntimeFailureKind kind;
  final String message;
  final List<DoctorUrgentReadinessReason> blockingReasons;

  static DoctorUrgentRuntimeFailure from(Object error) {
    if (error is FormatException) {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.invalidResponse,
        message:
            'La réponse de disponibilité est incompatible avec cette version.',
      );
    }
    if (error is! DioException) {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.unknown,
        message: 'La disponibilité urgente est momentanément indisponible.',
      );
    }
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final json = body is Map ? body.cast<Object?, Object?>() : null;
    final code = json?['code'] as String?;
    final reasons = <DoctorUrgentReadinessReason>[];
    final rawReasons = json?['blockingReasons'];
    if (rawReasons is List) {
      for (final value in rawReasons) {
        if (value is! String) continue;
        try {
          reasons.add(DoctorUrgentReadinessReason.parse(value));
        } on FormatException {
          // Unknown server reasons remain fail-closed without exposing raw data.
        }
      }
    }
    if (status == 401 || status == 403) {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.sessionRejected,
        message: 'Votre session ne permet plus cette opération.',
      );
    }
    if (status == 404 || code == 'URGENT_RUNTIME_UNAVAILABLE') {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.unavailable,
        message:
            'La disponibilité urgente n’est pas activée sur cet environnement.',
      );
    }
    if (status == 409 && code == 'RESOURCE_STATE_CONFLICT') {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.conflict,
        message:
            'La disponibilité a changé sur le serveur. L’état actuel a été rechargé.',
      );
    }
    if (status == 409 && code == 'URGENT_RUNTIME_ACTIVATION_BLOCKED') {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.activationBlocked,
        message: reasons.isEmpty
            ? 'Le serveur bloque actuellement cette activation.'
            : reasons.map((reason) => reason.frenchLabel).join(' '),
        blockingReasons: List.unmodifiable(reasons),
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return DoctorUrgentRuntimeFailure(
        kind: DoctorUrgentRuntimeFailureKind.network,
        message:
            'Connexion au serveur impossible. La disponibilité locale n’a pas été modifiée.',
      );
    }
    return DoctorUrgentRuntimeFailure(
      kind: DoctorUrgentRuntimeFailureKind.unknown,
      message: 'La disponibilité urgente est momentanément indisponible.',
    );
  }

  @override
  String toString() => message;
}
