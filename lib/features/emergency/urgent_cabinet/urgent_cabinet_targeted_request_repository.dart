import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_replay_policy.dart';
import '../../../core/utils/uuid_v4.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_targeted_request_models.dart';

enum UrgentCabinetPatientRequestFailureKind {
  cancelled,
  sessionRejected,
  rolloutUnavailable,
  notFound,
  subjectUnavailable,
  activeJourneyExists,
  targetUnavailable,
  targetChanged,
  requoteRequired,
  triageInvalid,
  cancelNotActionable,
  idempotencyConflict,
  commandInProgress,
  commitmentReadUnavailable,
  timeout,
  network,
  serverUnavailable,
  invalidResponse,
  rejected,
}

class UrgentCabinetPatientRequestFailure implements Exception {
  const UrgentCabinetPatientRequestFailure({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
  });

  final UrgentCabinetPatientRequestFailureKind kind;
  final String message;
  final String? code;
  final int? statusCode;

  bool get isNotFound =>
      kind == UrgentCabinetPatientRequestFailureKind.notFound;

  /// The active/recovery contract's authoritative "no request" response.
  ///
  /// A generic 404 must not be treated as an empty active-request result:
  /// proxies, route mismatches and other resources can also return 404.
  bool get isAuthoritativeRequestAbsence =>
      statusCode == 404 && code == 'URGENT_CABINET_REQUEST_NOT_FOUND';

  bool get hasAmbiguousSubmissionOutcome => switch (kind) {
    UrgentCabinetPatientRequestFailureKind.commandInProgress ||
    UrgentCabinetPatientRequestFailureKind.timeout ||
    UrgentCabinetPatientRequestFailureKind.network ||
    UrgentCabinetPatientRequestFailureKind.serverUnavailable ||
    UrgentCabinetPatientRequestFailureKind.commitmentReadUnavailable ||
    UrgentCabinetPatientRequestFailureKind.invalidResponse => true,
    _ => false,
  };

  static UrgentCabinetPatientRequestFailure from(Object error) {
    if (error is UrgentCabinetPatientRequestFailure) return error;
    if (error is FormatException) {
      return const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.invalidResponse,
        message: 'Réponse CABINET incompatible avec cette application.',
      );
    }
    if (error is! DioException) {
      return const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.rejected,
        message: 'La demande CABINET a été refusée.',
      );
    }
    if (CancelToken.isCancel(error)) {
      return const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.cancelled,
        message: 'Opération CABINET annulée localement.',
      );
    }
    final status = error.response?.statusCode;
    final code = _problemCode(error.response?.data);
    if (status == 401 || status == 403) {
      return UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.sessionRejected,
        message: 'La session Patient ne permet plus cette opération.',
        code: code,
        statusCode: status,
      );
    }
    final mapped = switch (code) {
      'URGENT_CABINET_REQUEST_UNAVAILABLE' ||
      'URGENT_CABINET_REQUEST_NOT_AUTHORIZED' ||
      'URGENT_RUNTIME_UNAVAILABLE' => (
        UrgentCabinetPatientRequestFailureKind.rolloutUnavailable,
        'Les demandes CABINET synthétiques ne sont pas activées.',
      ),
      'URGENT_CABINET_REQUEST_NOT_FOUND' => (
        UrgentCabinetPatientRequestFailureKind.notFound,
        'Cette demande CABINET est introuvable.',
      ),
      'URGENT_CABINET_SUBJECT_NOT_AVAILABLE' => (
        UrgentCabinetPatientRequestFailureKind.subjectUnavailable,
        'Le bénéficiaire sélectionné n’est plus disponible.',
      ),
      'URGENT_CABINET_ACTIVE_JOURNEY_EXISTS' => (
        UrgentCabinetPatientRequestFailureKind.activeJourneyExists,
        'Ce bénéficiaire possède déjà une demande urgente active.',
      ),
      'URGENT_CABINET_TARGET_NOT_AVAILABLE' => (
        UrgentCabinetPatientRequestFailureKind.targetUnavailable,
        'Ce médecin ou ce cabinet n’est plus disponible.',
      ),
      'URGENT_CABINET_TARGET_CHANGED' => (
        UrgentCabinetPatientRequestFailureKind.targetChanged,
        'Le médecin ou le cabinet a changé. Rechargez sa fiche.',
      ),
      'URGENT_CABINET_REQUOTE_REQUIRED' => (
        UrgentCabinetPatientRequestFailureKind.requoteRequired,
        'Le tarif a changé et doit être confirmé à nouveau.',
      ),
      'URGENT_CABINET_TRIAGE_INVALID' || 'VALIDATION_FAILED' => (
        UrgentCabinetPatientRequestFailureKind.triageInvalid,
        'Les informations cliniques sont invalides.',
      ),
      'URGENT_CABINET_IDEMPOTENCY_CONFLICT' => (
        UrgentCabinetPatientRequestFailureKind.idempotencyConflict,
        'La clé de demande ne correspond plus à ce contenu.',
      ),
      'URGENT_CABINET_COMMAND_IN_PROGRESS' => (
        UrgentCabinetPatientRequestFailureKind.commandInProgress,
        'La même demande est encore en cours sur le serveur.',
      ),
      'URGENT_CABINET_CANCEL_NOT_ACTIONABLE' => (
        UrgentCabinetPatientRequestFailureKind.cancelNotActionable,
        'Cette demande ne peut plus être annulée.',
      ),
      'URGENT_CABINET_CANCEL_IDEMPOTENCY_CONFLICT' => (
        UrgentCabinetPatientRequestFailureKind.idempotencyConflict,
        'La clé d’annulation ne correspond plus à cette commande.',
      ),
      'URGENT_CABINET_CANCEL_COMMAND_IN_PROGRESS' => (
        UrgentCabinetPatientRequestFailureKind.commandInProgress,
        'La même annulation est encore en cours sur le serveur.',
      ),
      'URGENT_CABINET_COMMITMENT_READ_UNAVAILABLE' => (
        UrgentCabinetPatientRequestFailureKind.commitmentReadUnavailable,
        'La confirmation CABINET ne peut pas être relue de façon sûre.',
      ),
      'URGENT_CABINET_WITHDRAWAL_NOT_ACTIONABLE' => (
        UrgentCabinetPatientRequestFailureKind.cancelNotActionable,
        "Cet engagement ne peut plus être retiré.",
      ),
      'URGENT_CABINET_ARRIVAL_HANDOFF_NOT_ACTIONABLE' => (
        UrgentCabinetPatientRequestFailureKind.rejected,
        "Le QR de présence n'est plus disponible pour cet engagement.",
      ),
      'URGENT_CABINET_OPERATION_IDEMPOTENCY_CONFLICT' => (
        UrgentCabinetPatientRequestFailureKind.idempotencyConflict,
        "La clé de cette opération ne correspond plus à son contenu.",
      ),
      'URGENT_CABINET_OPERATION_IN_PROGRESS' => (
        UrgentCabinetPatientRequestFailureKind.commandInProgress,
        'La même opération est encore en cours sur le serveur.',
      ),
      _ => null,
    };
    if (mapped != null) {
      return UrgentCabinetPatientRequestFailure(
        kind: mapped.$1,
        message: mapped.$2,
        code: code,
        statusCode: status,
      );
    }
    if (status == 404) {
      return UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.notFound,
        message: 'Cette demande CABINET est indisponible.',
        code: code,
        statusCode: status,
      );
    }
    if (status != null && status >= 500) {
      return UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.serverUnavailable,
        message: 'Le service CABINET est temporairement indisponible.',
        code: code,
        statusCode: status,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.timeout,
        message:
            'Le résultat doit être récupéré avant toute nouvelle tentative.',
        code: code,
        statusCode: status,
      );
    }
    if (error.response == null ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate) {
      return UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.network,
        message:
            'Le résultat doit être récupéré avant toute nouvelle tentative.',
        code: code,
        statusCode: status,
      );
    }
    return UrgentCabinetPatientRequestFailure(
      kind: UrgentCabinetPatientRequestFailureKind.rejected,
      message: 'La demande CABINET a été refusée.',
      code: code,
      statusCode: status,
    );
  }

  @override
  String toString() => message;
}

abstract interface class UrgentCabinetTargetedRequestRepository {
  Future<UrgentCabinetTargetedRequestSnapshot> submit({
    required UrgentCabinetTargetedSubmission submission,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetTargetedRequestSnapshot> status(
    String requestId, {
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetTargetedRequestSnapshot> recover(
    String idempotencyKey, {
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetTargetedRequestSnapshot> active(
    UrgentCabinetCareSubject subject, {
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetTargetedRequestSnapshot> cancel({
    required String requestId,
    required UrgentCabinetPatientCancellation command,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetTargetedRequestSnapshot> withdraw({
    required String requestId,
    required UrgentCabinetPatientWithdrawal command,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetArrivalHandoff> issueArrivalHandoff({
    required String requestId,
    required int expectedResponseRevision,
    required int expectedCommitmentRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });
}

class AppUrgentCabinetTargetedRequestRepository
    implements UrgentCabinetTargetedRequestRepository {
  const AppUrgentCabinetTargetedRequestRepository(this._httpClient);

  static const path = '/me/urgent-cabinet/requests';

  final AppHttpClient _httpClient;

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> submit({
    required UrgentCabinetTargetedSubmission submission,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final key = _requireKey(idempotencyKey);
    try {
      final response = await _httpClient.dio.post<dynamic>(
        path,
        data: submission.toJson(),
        cancelToken: cancelToken,
        options: _options(key),
      );
      final snapshot = _parse(response.data);
      if (!_matchesSubmission(snapshot, submission)) {
        throw const FormatException('CABINET submission authority mismatch.');
      }
      if ((response.statusCode == 201 && snapshot.replayed) ||
          (response.statusCode == 200 && !snapshot.replayed)) {
        throw const FormatException('CABINET replay metadata mismatch.');
      }
      return snapshot;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> status(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(requestId, 'requestId');
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$path/$normalized',
        cancelToken: cancelToken,
        options: _options(),
      );
      final snapshot = _parse(response.data);
      if (snapshot.requestId != normalized) {
        throw const FormatException('CABINET request identity mismatch.');
      }
      return snapshot;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> recover(
    String idempotencyKey, {
    CancelToken? cancelToken,
  }) async {
    final key = _requireKey(idempotencyKey);
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$path/recovery',
        cancelToken: cancelToken,
        options: _options(key),
      );
      final snapshot = _parse(response.data);
      if (!snapshot.replayed) {
        throw const FormatException('CABINET recovery must be a replay.');
      }
      return snapshot;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> active(
    UrgentCabinetCareSubject subject, {
    CancelToken? cancelToken,
  }) async {
    final familyMemberId = subject.familyMemberId;
    if (!subject.isSelf &&
        (familyMemberId == null ||
            !isCanonicalUuid(familyMemberId.toLowerCase()))) {
      throw const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.subjectUnavailable,
        message: 'Le bénéficiaire sélectionné n’est pas valide.',
      );
    }
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$path/active',
        queryParameters: <String, Object>{
          'subjectType': subject.isSelf ? 'SELF' : 'FAMILY_MEMBER',
          if (!subject.isSelf) 'familyMemberId': familyMemberId!,
        },
        cancelToken: cancelToken,
        options: _options(),
      );
      final snapshot = _parse(response.data);
      if (snapshot.careSubject != subject) {
        throw const FormatException('CABINET active subject mismatch.');
      }
      return snapshot;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> cancel({
    required String requestId,
    required UrgentCabinetPatientCancellation command,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(requestId, 'requestId');
    final key = _requireKey(idempotencyKey, minimumLength: 32);
    if (command.expectedResponseRevision < 0 ||
        command.expectedRequestRevision < 0 ||
        command.expectedJourneyRevision < 0) {
      throw const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.rejected,
        message: 'Les révisions d’annulation sont invalides.',
      );
    }
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$path/$normalized/cancel',
        data: command.toJson(),
        cancelToken: cancelToken,
        options: _options(key),
      );
      final snapshot = _parse(response.data);
      if (snapshot.requestId != normalized ||
          (snapshot.responseStatus !=
                  UrgentCabinetPatientResponseStatus.cancelled &&
              snapshot.responseStatus !=
                  UrgentCabinetPatientResponseStatus.expired)) {
        throw const FormatException('Invalid CABINET cancellation result.');
      }
      return snapshot;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> withdraw({
    required String requestId,
    required UrgentCabinetPatientWithdrawal command,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(requestId, 'requestId');
    final key = _requireKey(idempotencyKey, minimumLength: 32);
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$path/$normalized/withdraw',
        data: command.toJson(),
        cancelToken: cancelToken,
        options: _options(key),
      );
      final snapshot = _parse(response.data);
      if (snapshot.requestId != normalized ||
          snapshot.responseStatus !=
              UrgentCabinetPatientResponseStatus.cancelled ||
          snapshot.terminalReason !=
              UrgentCabinetPatientTerminalReason
                  .patientWithdrewAfterAcceptance) {
        throw const FormatException('Invalid CABINET withdrawal result.');
      }
      return snapshot;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  @override
  Future<UrgentCabinetArrivalHandoff> issueArrivalHandoff({
    required String requestId,
    required int expectedResponseRevision,
    required int expectedCommitmentRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(requestId, 'requestId');
    final key = _requireKey(idempotencyKey, minimumLength: 32);
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$path/$normalized/arrival-handoffs',
        data: <String, Object>{
          'expectedResponseRevision': expectedResponseRevision,
          'expectedCommitmentRevision': expectedCommitmentRevision,
        },
        cancelToken: cancelToken,
        options: _options(key),
      );
      if (response.data is! Map) {
        throw const FormatException('Invalid CABINET arrival handoff.');
      }
      final handoff = UrgentCabinetArrivalHandoff.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
      if (handoff.requestId != normalized) {
        throw const FormatException('CABINET handoff request mismatch.');
      }
      return handoff;
    } catch (error) {
      throw UrgentCabinetPatientRequestFailure.from(error);
    }
  }

  static UrgentCabinetTargetedRequestSnapshot _parse(Object? value) {
    if (value is! Map) {
      throw const FormatException('Expected an urgent CABINET response.');
    }
    return UrgentCabinetTargetedRequestSnapshot.fromJson(
      value.cast<String, dynamic>(),
    );
  }

  static bool _matchesSubmission(
    UrgentCabinetTargetedRequestSnapshot snapshot,
    UrgentCabinetTargetedSubmission submission,
  ) =>
      snapshot.careSubject == submission.careSubject &&
      snapshot.doctorId == submission.doctorId &&
      snapshot.practiceLocationId == submission.practiceLocationId &&
      snapshot.quotedFeeMilliTnd == submission.amountMilliTnd &&
      snapshot.configurationRevision == submission.configurationRevision &&
      snapshot.runtimeRevision == submission.runtimeRevision &&
      snapshot.practiceLocationVersion == submission.practiceLocationVersion;

  static Options _options([String? idempotencyKey]) => Options(
    headers: <String, String>{
      'Cache-Control': 'no-store',
      'Idempotency-Key': ?idempotencyKey,
    },
    extra: idempotencyKey == null
        ? null
        : requestReplayExtra(RequestReplayPolicy.declaredIdempotentWrite),
  );
}

String _requireKey(String value, {int minimumLength = 1}) {
  final normalized = value.trim();
  if (normalized.length < minimumLength || normalized.length > 128) {
    throw const UrgentCabinetPatientRequestFailure(
      kind: UrgentCabinetPatientRequestFailureKind.rejected,
      message: 'Clé d’idempotence CABINET invalide.',
    );
  }
  return normalized;
}

String _requireUuid(String value, String field) {
  final normalized = value.trim().toLowerCase();
  if (!isCanonicalUuid(normalized)) {
    throw UrgentCabinetPatientRequestFailure(
      kind: UrgentCabinetPatientRequestFailureKind.rejected,
      message: 'Identifiant CABINET $field invalide.',
    );
  }
  return normalized;
}

String? _problemCode(Object? data) {
  if (data is! Map) return null;
  final value = data['code'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}
