import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_replay_policy.dart';
import '../../../core/utils/uuid_v4.dart';
import 'doctor_urgent_cabinet_commitment.dart';
import 'doctor_urgent_cabinet_arrival.dart';
import 'doctor_urgent_cabinet_commitment_source.dart';
import 'doctor_urgent_cabinet_decision.dart';
import 'doctor_urgent_cabinet_decision_source.dart';
import 'doctor_urgent_cabinet_request.dart';
import 'doctor_urgent_cabinet_request_source.dart';

enum DoctorUrgentCabinetFailureKind {
  sessionRejected,
  rolloutUnavailable,
  notFound,
  notActionable,
  eligibilityChanged,
  capacityConflict,
  idempotencyConflict,
  commandInProgress,
  network,
  serverUnavailable,
  invalidResponse,
  rejected,
}

class DoctorUrgentCabinetFailure implements Exception {
  const DoctorUrgentCabinetFailure({
    required this.kind,
    required this.message,
    this.code,
  });

  final DoctorUrgentCabinetFailureKind kind;
  final String message;
  final String? code;

  bool get hasAmbiguousCommandOutcome =>
      kind == DoctorUrgentCabinetFailureKind.commandInProgress ||
      kind == DoctorUrgentCabinetFailureKind.network ||
      kind == DoctorUrgentCabinetFailureKind.serverUnavailable ||
      kind == DoctorUrgentCabinetFailureKind.invalidResponse;

  static DoctorUrgentCabinetFailure from(Object error) {
    if (error is DoctorUrgentCabinetFailure) return error;
    if (error is FormatException) {
      return const DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.invalidResponse,
        message:
            'La réponse CABINET est incompatible avec cette version de l’application.',
      );
    }
    if (error is! DioException) {
      return const DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.rejected,
        message: 'Les demandes CABINET sont momentanément indisponibles.',
      );
    }
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final json = data is Map ? data.cast<Object?, Object?>() : null;
    final code = json?['code'] is String ? json!['code'] as String : null;
    if (status == 401 || status == 403) {
      return DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.sessionRejected,
        code: code,
        message:
            'Votre session ne permet plus de consulter les demandes CABINET.',
      );
    }
    final mapped = switch (code) {
      'URGENT_CABINET_REQUEST_UNAVAILABLE' || 'URGENT_RUNTIME_UNAVAILABLE' => (
        DoctorUrgentCabinetFailureKind.rolloutUnavailable,
        'Les demandes CABINET synthétiques ne sont pas activées sur cet environnement.',
      ),
      'URGENT_CABINET_REQUEST_NOT_FOUND' ||
      'URGENT_CABINET_COMMITMENT_NOT_FOUND' => (
        DoctorUrgentCabinetFailureKind.notFound,
        'Cette demande CABINET n’est plus disponible.',
      ),
      'URGENT_CABINET_RESPONSE_NOT_ACTIONABLE' => (
        DoctorUrgentCabinetFailureKind.notActionable,
        'Cette demande ne peut plus recevoir de réponse.',
      ),
      'URGENT_CABINET_RESPONSE_ELIGIBILITY_CHANGED' ||
      'PROFESSIONAL_NOT_ELIGIBLE' => (
        DoctorUrgentCabinetFailureKind.eligibilityChanged,
        'Votre éligibilité actuelle ne permet plus cette acceptation.',
      ),
      'URGENT_CABINET_RESPONSE_CAPACITY_CONFLICT' => (
        DoctorUrgentCabinetFailureKind.capacityConflict,
        'Une autre responsabilité opérationnelle empêche cette acceptation.',
      ),
      'URGENT_CABINET_RESPONSE_IDEMPOTENCY_CONFLICT' => (
        DoctorUrgentCabinetFailureKind.idempotencyConflict,
        'La commande ne correspond plus à cette décision. Le statut a été rechargé.',
      ),
      'URGENT_CABINET_RESPONSE_COMMAND_IN_PROGRESS' => (
        DoctorUrgentCabinetFailureKind.commandInProgress,
        'La même décision est encore en cours sur le serveur.',
      ),
      'URGENT_CABINET_COMMITMENT_READ_UNAVAILABLE' => (
        DoctorUrgentCabinetFailureKind.serverUnavailable,
        'La responsabilité CABINET ne peut pas être relue de façon sûre.',
      ),
      'URGENT_CABINET_ARRIVAL_HANDOFF_NOT_ACTIONABLE' ||
      'URGENT_CABINET_ARRIVAL_TOKEN_CONSUMED' => (
        DoctorUrgentCabinetFailureKind.notActionable,
        "Cette arrivée ne peut plus être vérifiée avec ce code.",
      ),
      'URGENT_CABINET_ARRIVAL_TOKEN_INVALID' ||
      'URGENT_CABINET_ARRIVAL_CONTEXT_MISMATCH' => (
        DoctorUrgentCabinetFailureKind.rejected,
        "Ce code ne correspond pas à cet engagement CABINET.",
      ),
      'URGENT_CABINET_ARRIVAL_TOKEN_EXPIRED' => (
        DoctorUrgentCabinetFailureKind.notActionable,
        'Ce code de présence a expiré. Le patient doit en afficher un nouveau.',
      ),
      'URGENT_CABINET_OPERATION_IDEMPOTENCY_CONFLICT' => (
        DoctorUrgentCabinetFailureKind.idempotencyConflict,
        'La commande ne correspond plus à cette vérification.',
      ),
      'URGENT_CABINET_OPERATION_IN_PROGRESS' => (
        DoctorUrgentCabinetFailureKind.commandInProgress,
        'La même vérification est encore en cours sur le serveur.',
      ),
      _ => null,
    };
    if (mapped != null) {
      return DoctorUrgentCabinetFailure(
        kind: mapped.$1,
        code: code,
        message: mapped.$2,
      );
    }
    if (status == 404) {
      return DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.notFound,
        code: code,
        message: 'Cette demande CABINET n’est plus disponible.',
      );
    }
    if (status != null && status >= 500) {
      return DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.serverUnavailable,
        code: code,
        message: 'Le service CABINET est temporairement indisponible.',
      );
    }
    if (error.response == null ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.network,
        code: code,
        message:
            'Connexion impossible. Le statut CABINET doit être vérifié avant de réessayer.',
      );
    }
    return DoctorUrgentCabinetFailure(
      kind: DoctorUrgentCabinetFailureKind.rejected,
      code: code,
      message: 'La commande CABINET a été refusée.',
    );
  }

  @override
  String toString() => message;
}

abstract interface class DoctorUrgentCabinetRepositoryContract
    implements
        DoctorUrgentCabinetRequestSource,
        DoctorUrgentCabinetRequestDetailSource,
        DoctorUrgentCabinetNotificationTargetSource,
        DoctorUrgentCabinetDecisionSource,
        DoctorUrgentCabinetCommitmentSource,
        DoctorUrgentCabinetArrivalSource,
        DoctorUrgentCabinetSessionStateSource {}

class DoctorUrgentCabinetRepository
    implements DoctorUrgentCabinetRepositoryContract {
  DoctorUrgentCabinetRepository(
    this._httpClient, {
    this.onSessionRejected,
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) : _idempotencyKeyFactory = idempotencyKeyFactory;

  static const requestPath = '/me/urgent-cabinet/targeted-requests';
  static const commitmentPath = '/me/urgent-cabinet/commitments';

  final AppHttpClient _httpClient;
  final VoidCallback? onSessionRejected;
  final String Function() _idempotencyKeyFactory;
  final Map<String, String> _decisionKeys = {};
  final Map<String, String> _arrivalKeys = {};

  @override
  bool get isDevelopmentFixture => false;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    if (!context.isComplete) return const DoctorUrgentCabinetFeedEmpty();
    try {
      final response = await _httpClient.dio.get<dynamic>(
        requestPath,
        queryParameters: const {'limit': 20},
        cancelToken: cancelToken,
        options: _readOptions(),
      );
      if (response.data is! List) {
        throw const FormatException('Expected a CABINET request list.');
      }
      final raw = response.data! as List;
      if (raw.length > 20) {
        throw const FormatException('Oversized CABINET request list.');
      }
      final requests = raw
          .map((item) => _parsePendingRequest(item, context))
          .toList(growable: false);
      final identities = requests.map((item) => item.stableIdentity).toSet();
      if (identities.length != requests.length) {
        throw const FormatException('Duplicate CABINET request identity.');
      }
      return requests.isEmpty
          ? const DoctorUrgentCabinetFeedEmpty()
          : DoctorUrgentCabinetFeedLoaded(requests);
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      if (failure.kind == DoctorUrgentCabinetFailureKind.rolloutUnavailable) {
        return DoctorUrgentCabinetFeedUnavailable(message: failure.message);
      }
      return DoctorUrgentCabinetFeedError(
        message: failure.message,
        canRetry:
            failure.kind != DoctorUrgentCabinetFailureKind.sessionRejected,
      );
    }
  }

  @override
  Future<DoctorUrgentCabinetRequest> getRequest(
    String requestId,
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(requestId, 'requestId');
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$requestPath/$normalized',
        cancelToken: cancelToken,
        options: _readOptions(),
      );
      final target = _parseNotificationTarget(response.data, context);
      final request = target.pendingRequest;
      if (target.requestId != normalized || request == null) {
        throw const FormatException('Mismatched CABINET request identity.');
      }
      return request;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      throw failure;
    }
  }

  @override
  Future<DoctorUrgentCabinetNotificationTarget> resolveNotificationTarget(
    String requestId,
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(requestId, 'requestId');
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$requestPath/$normalized',
        cancelToken: cancelToken,
        options: _readOptions(),
      );
      final target = _parseNotificationTarget(response.data, context);
      if (target.requestId != normalized) {
        throw const FormatException('Mismatched CABINET request identity.');
      }
      return target;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      throw failure;
    }
  }

  @override
  Future<DoctorUrgentCabinetDecisionResult> decide({
    required DoctorUrgentCabinetRequest request,
    required DoctorUrgentCabinetDecisionAction action,
    required DoctorUrgentCabinetDecisionContext context,
    CancelToken? cancelToken,
  }) async {
    final actionAuthorized = switch (action) {
      DoctorUrgentCabinetDecisionAction.accept => request.canAccept,
      DoctorUrgentCabinetDecisionAction.refuse => request.canDecline,
    };
    if (!context.validates(request) ||
        request.isDevelopmentFixture ||
        request.status != DoctorUrgentCabinetRequestStatus.newRequest ||
        request.serverRequestRevision == null ||
        !actionAuthorized) {
      return _definiteFailure(
        request,
        action,
        context,
        'Cette demande CABINET ne possède plus une autorité de décision valide.',
      );
    }
    final logicalIdentity = [
      request.stableIdentity,
      action.name,
      request.serverRequestRevision,
    ].join('|');
    final key = _decisionKeys.putIfAbsent(
      logicalIdentity,
      () => _newIdempotencyKey(),
    );
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$requestPath/${request.stableIdentity}/${_actionPath(action)}',
        data: {'expectedRequestRevision': request.serverRequestRevision},
        cancelToken: cancelToken,
        options: Options(
          headers: {'Cache-Control': 'no-store', 'Idempotency-Key': key},
          extra: requestReplayExtra(
            RequestReplayPolicy.declaredIdempotentWrite,
          ),
        ),
      );
      final outcome = _parseDecision(response.data, request, action);
      _decisionKeys.remove(logicalIdentity);
      if (outcome.commitmentId != null) {
        DoctorUrgentCabinetCommitment? commitment;
        try {
          commitment = await getCommitment(
            outcome.commitmentId!,
            cancelToken: cancelToken,
          );
        } catch (_) {
          // The accepted command response remains authoritative. The
          // controller performs a fenced commitment reconciliation next.
        }
        return DoctorUrgentCabinetAcceptedResult(
          requestIdentity: request.stableIdentity,
          action: action,
          contextFingerprint: context.fingerprint,
          commitment: commitment,
        );
      }
      return DoctorUrgentCabinetDeclinedResult(
        requestIdentity: request.stableIdentity,
        action: action,
        contextFingerprint: context.fingerprint,
      );
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      if (failure.kind == DoctorUrgentCabinetFailureKind.sessionRejected ||
          failure.kind == DoctorUrgentCabinetFailureKind.notFound) {
        return DoctorUrgentCabinetUnavailableResult(
          requestIdentity: request.stableIdentity,
          action: action,
          contextFingerprint: context.fingerprint,
        );
      }
      if (failure.hasAmbiguousCommandOutcome) {
        return DoctorUrgentCabinetDecisionUnknownResult(
          requestIdentity: request.stableIdentity,
          action: action,
          contextFingerprint: context.fingerprint,
          message: failure.message,
        );
      }
      return _definiteFailure(request, action, context, failure.message);
    }
  }

  @override
  Future<List<DoctorUrgentCabinetCommitment>> listCommitments({
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit');
    }
    try {
      final response = await _httpClient.dio.get<dynamic>(
        commitmentPath,
        queryParameters: {'limit': limit},
        cancelToken: cancelToken,
        options: _readOptions(),
      );
      return parseDoctorUrgentCabinetCommitmentList(
        response.data,
        limit: limit,
      );
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      throw failure;
    }
  }

  @override
  Future<DoctorUrgentCabinetCommitment> getCommitment(
    String commitmentId, {
    CancelToken? cancelToken,
  }) async {
    final normalized = _requireUuid(commitmentId, 'commitmentId');
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$commitmentPath/$normalized',
        cancelToken: cancelToken,
        options: _readOptions(),
      );
      final commitment = parseDoctorUrgentCabinetCommitment(response.data);
      if (commitment.commitmentId != normalized) {
        throw const FormatException(
          'Mismatched urgent CABINET commitment identity.',
        );
      }
      return commitment;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      throw failure;
    }
  }

  @override
  Future<DoctorUrgentCabinetArrivalVerification> verifyArrival({
    required DoctorUrgentCabinetCommitment commitment,
    required String token,
    CancelToken? cancelToken,
  }) async {
    final normalizedToken = token.trim();
    if (!commitment.canVerifyArrival ||
        normalizedToken.isEmpty ||
        normalizedToken.length > 2048) {
      throw const FormatException('Invalid CABINET arrival verification.');
    }
    final logicalIdentity =
        '${commitment.commitmentId}|${commitment.revision}|$normalizedToken';
    final key = _arrivalKeys.putIfAbsent(
      logicalIdentity,
      () => _newIdempotencyKey(),
    );
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$commitmentPath/${commitment.commitmentId}/arrival-verifications',
        data: <String, Object>{
          'token': normalizedToken,
          'expectedCommitmentRevision': commitment.revision,
        },
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            'Cache-Control': 'no-store',
            'Idempotency-Key': key,
          },
          extra: requestReplayExtra(
            RequestReplayPolicy.declaredIdempotentWrite,
          ),
        ),
      );
      final value = response.data;
      if (value is! Map) {
        throw const FormatException('Invalid CABINET arrival result.');
      }
      final json = value.cast<Object?, Object?>();
      final replayed = json['replayed'];
      final result = DoctorUrgentCabinetArrivalVerification(
        commitmentId: _requiredUuid(json, 'commitmentId'),
        requestId: _requiredUuid(json, 'requestId'),
        commitmentRevision: _nonnegativeInt(json, 'commitmentRevision'),
        arrivalVerifiedAt: _requiredDateTime(json, 'arrivalVerifiedAt'),
        replayed: replayed is bool
            ? replayed
            : throw const FormatException('Invalid CABINET replay result.'),
      );
      if (result.commitmentId != commitment.commitmentId ||
          result.requestId != commitment.requestId ||
          result.commitmentRevision <= commitment.revision ||
          json['consultationStarted'] != false ||
          json['mrsAccessGranted'] != false) {
        throw const FormatException('Unsafe CABINET arrival result.');
      }
      _arrivalKeys.remove(logicalIdentity);
      return result;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      final failure = DoctorUrgentCabinetFailure.from(error);
      _handleSessionFailure(failure);
      throw failure;
    }
  }

  @override
  void clearSessionState() {
    _decisionKeys.clear();
    _arrivalKeys.clear();
  }

  DoctorUrgentCabinetRequest _parsePendingRequest(
    Object? value,
    DoctorUrgentCabinetRequestContext context,
  ) {
    if (value is! Map || !context.isComplete || context.cabinet == null) {
      throw const FormatException('Invalid CABINET request context.');
    }
    final json = value.cast<Object?, Object?>();
    if (_requiredString(json, 'responseStatus') != 'PENDING' ||
        _requiredString(json, 'state') != 'CABINET_PENDING' ||
        json['respondedAt'] != null ||
        json['commitmentId'] != null ||
        json['commitmentStatus'] != null ||
        json['commitmentRevision'] != null ||
        json['committedAt'] != null) {
      throw const FormatException('Invalid pending CABINET request shape.');
    }
    final actions = _stringList(json, 'allowedActions');
    final allowedActions = _parsePendingActions(actions);
    final rawAreas = json['bodyAreaCodes'];
    if (rawAreas is! List || rawAreas.isEmpty || rawAreas.length > 9) {
      throw const FormatException('Invalid CABINET structured triage.');
    }
    final areas = rawAreas
        .map((value) {
          if (value is! String) {
            throw const FormatException('Invalid CABINET body area.');
          }
          return DoctorUrgentCabinetBodyArea.parse(value);
        })
        .toList(growable: false);
    if (areas.toSet().length != areas.length) {
      throw const FormatException('Duplicate CABINET body area.');
    }
    final painScore = _nonnegativeInt(json, 'painScore');
    final shortDescription = _requiredString(json, 'shortDescription');
    if (painScore > 10 || _nonnegativeInt(json, 'responseRevision') != 0) {
      throw const FormatException('Invalid CABINET request revision or pain.');
    }
    final request = DoctorUrgentCabinetRequest(
      developmentFixtureKey: null,
      targetDoctorId: context.doctorId,
      targetCabinetIdentity: DoctorUrgentCabinetServerTargetIdentity(
        _requiredUuid(json, 'practiceLocationId'),
      ),
      cabinet: context.cabinet!,
      patient: const DoctorUrgentCabinetPatientProjection.masked(),
      fee: DoctorUrgentCabinetFeeSnapshot(
        amountMilliTnd: parseUrgentCabinetFeeMilliTnd(json['quotedFeeTnd']),
        currencyCode: _requiredTnd(json),
        provenance: DoctorUrgentCabinetFeeProvenance.service,
      ),
      dataProvenance: DoctorUrgentCabinetDataProvenance.service,
      status: DoctorUrgentCabinetRequestStatus.newRequest,
      serverRequestReference: _requiredUuid(json, 'requestId'),
      serverRequestRevision: _nonnegativeInt(json, 'requestRevision'),
      bodyAreas: areas,
      painScore: painScore,
      shortDescription: shortDescription,
      createdAt: _requiredDateTime(json, 'createdAt'),
      responseDeadlineAt: _nullableDateTime(json, 'responseDeadlineAt'),
      evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
      allowedActions: allowedActions,
    );
    if (!doctorUrgentCabinetRequestMatchesContext(request, context)) {
      throw const FormatException('CABINET request context mismatch.');
    }
    return request;
  }

  DoctorUrgentCabinetNotificationTarget _parseNotificationTarget(
    Object? value,
    DoctorUrgentCabinetRequestContext context,
  ) {
    if (value is! Map || !context.isComplete) {
      throw const FormatException('Invalid CABINET notification target.');
    }
    final json = value.cast<Object?, Object?>();
    final requestId = _requiredUuid(json, 'requestId');
    final responseStatus = _requiredString(json, 'responseStatus');
    final state = _requiredString(json, 'state');
    _requiredUuid(json, 'practiceLocationId');
    _nonnegativeInt(json, 'responseRevision');
    _nonnegativeInt(json, 'requestRevision');
    _requiredDateTime(json, 'evaluatedAt');

    if (responseStatus == 'PENDING') {
      final request = _parsePendingRequest(value, context);
      return DoctorUrgentCabinetNotificationTarget(
        requestId: requestId,
        state: DoctorUrgentCabinetNotificationTargetState.pending,
        pendingRequest: request,
      );
    }

    if (_stringList(json, 'allowedActions').isNotEmpty ||
        json['respondedAt'] == null) {
      throw const FormatException('Invalid terminal CABINET target.');
    }
    _requiredDateTime(json, 'respondedAt');

    if (responseStatus == 'ACCEPTED' &&
        json['commitmentStatus'] == 'ACTIVE' &&
        state == 'CABINET_COMMITTED') {
      _nonnegativeInt(json, 'commitmentRevision');
      _requiredDateTime(json, 'committedAt');
      if (json['terminalAt'] != null) {
        throw const FormatException('Invalid active CABINET commitment.');
      }
      return DoctorUrgentCabinetNotificationTarget(
        requestId: requestId,
        state: DoctorUrgentCabinetNotificationTargetState.accepted,
        commitmentId: _requiredUuid(json, 'commitmentId'),
      );
    }

    final terminalState = switch (responseStatus) {
      'DECLINED' => DoctorUrgentCabinetNotificationTargetState.declined,
      'EXPIRED' => DoctorUrgentCabinetNotificationTargetState.expired,
      'CANCELLED' => DoctorUrgentCabinetNotificationTargetState.cancelled,
      'ACCEPTED'
          when json['commitmentStatus'] == 'CANCELLED' ||
              json['commitmentStatus'] == 'INVALIDATED' =>
        DoctorUrgentCabinetNotificationTargetState.cancelled,
      _ => throw const FormatException('Unknown CABINET target state.'),
    };
    if (state != 'CABINET_CANCELLED' || json['terminalAt'] == null) {
      throw const FormatException('Invalid terminal CABINET lifecycle.');
    }
    _requiredDateTime(json, 'terminalAt');
    return DoctorUrgentCabinetNotificationTarget(
      requestId: requestId,
      state: terminalState,
    );
  }

  Set<DoctorUrgentCabinetAllowedAction> _parsePendingActions(
    List<String> actions,
  ) {
    if (actions.toSet().length != actions.length) {
      throw const FormatException('Duplicate CABINET request action.');
    }
    final parsed = actions.map((action) {
      return switch (action) {
        'ACCEPT' => DoctorUrgentCabinetAllowedAction.accept,
        'DECLINE' => DoctorUrgentCabinetAllowedAction.decline,
        _ => throw const FormatException('Unknown CABINET request action.'),
      };
    }).toSet();
    final both = parsed.length == 2;
    final declineOnly =
        parsed.length == 1 &&
        parsed.contains(DoctorUrgentCabinetAllowedAction.decline);
    if (!both && !declineOnly) {
      throw const FormatException('Invalid CABINET request actions.');
    }
    return Set.unmodifiable(parsed);
  }

  _DoctorUrgentCabinetDecisionOutcome _parseDecision(
    Object? value,
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionAction action,
  ) {
    if (value is! Map) {
      throw const FormatException('Expected a CABINET decision response.');
    }
    final json = value.cast<Object?, Object?>();
    if (_requiredUuid(json, 'requestId') != request.stableIdentity ||
        _requiredUuid(json, 'practiceLocationId') !=
            (request.targetCabinetIdentity
                    as DoctorUrgentCabinetServerTargetIdentity)
                .cabinetId ||
        parseUrgentCabinetFeeMilliTnd(json['quotedFeeTnd']) !=
            request.fee.amountMilliTnd ||
        _requiredTnd(json) != request.fee.currencyCode ||
        _nonnegativeInt(json, 'requestRevision') <=
            request.serverRequestRevision! ||
        _stringList(json, 'allowedActions').isNotEmpty ||
        json['replayed'] is! bool) {
      throw const FormatException('Invalid CABINET decision authority.');
    }
    _requiredDateTime(json, 'respondedAt');
    _requiredDateTime(json, 'evaluatedAt');
    if (action == DoctorUrgentCabinetDecisionAction.accept) {
      if (_requiredString(json, 'responseStatus') != 'ACCEPTED' ||
          _requiredString(json, 'requestState') != 'CABINET_COMMITTED' ||
          _requiredString(json, 'commitmentStatus') != 'ACTIVE' ||
          json['commitmentRevision'] is! int ||
          (json['commitmentRevision'] as int) < 0) {
        throw const FormatException('Invalid CABINET acceptance result.');
      }
      _requiredDateTime(json, 'committedAt');
      return _DoctorUrgentCabinetDecisionOutcome(
        commitmentId: _requiredUuid(json, 'commitmentId'),
      );
    }
    if (_requiredString(json, 'responseStatus') != 'DECLINED' ||
        _requiredString(json, 'requestState') != 'CABINET_CANCELLED' ||
        json['commitmentId'] != null ||
        json['commitmentStatus'] != null ||
        json['commitmentRevision'] != null ||
        json['committedAt'] != null) {
      throw const FormatException('Invalid CABINET decline result.');
    }
    return const _DoctorUrgentCabinetDecisionOutcome();
  }

  DoctorUrgentCabinetDecisionDefiniteFailureResult _definiteFailure(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionAction action,
    DoctorUrgentCabinetDecisionContext context,
    String message,
  ) => DoctorUrgentCabinetDecisionDefiniteFailureResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
    message: message,
  );

  String _newIdempotencyKey() {
    final key = _idempotencyKeyFactory().trim();
    if (key.isEmpty || key.length > 128) {
      throw StateError('Invalid CABINET idempotency key factory result.');
    }
    return key;
  }

  void _handleSessionFailure(DoctorUrgentCabinetFailure failure) {
    if (failure.kind == DoctorUrgentCabinetFailureKind.sessionRejected) {
      onSessionRejected?.call();
    }
  }

  static Options _readOptions() =>
      Options(headers: const {'Cache-Control': 'no-store'});

  static String _actionPath(DoctorUrgentCabinetDecisionAction action) =>
      switch (action) {
        DoctorUrgentCabinetDecisionAction.accept => 'accept',
        DoctorUrgentCabinetDecisionAction.refuse => 'decline',
      };

  static bool _isCancellation(Object error) =>
      error is DioException && CancelToken.isCancel(error);
}

@immutable
class _DoctorUrgentCabinetDecisionOutcome {
  const _DoctorUrgentCabinetDecisionOutcome({this.commitmentId});

  final String? commitmentId;
}

String _requiredUuid(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  if (!isCanonicalUuid(value)) {
    throw FormatException('Invalid CABINET $field.');
  }
  return value;
}

String _requireUuid(String value, String field) {
  final normalized = value.trim();
  if (!isCanonicalUuid(normalized)) {
    throw ArgumentError.value(value, field);
  }
  return normalized;
}

String _requiredString(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing CABINET $field.');
  }
  return value.trim();
}

String _requiredTnd(Map<Object?, Object?> json) {
  if (json['currency'] != 'TND') {
    throw const FormatException('Invalid CABINET currency.');
  }
  return 'TND';
}

int _nonnegativeInt(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! int || value < 0) {
    throw FormatException('Invalid CABINET $field.');
  }
  return value;
}

DateTime _requiredDateTime(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Invalid CABINET $field.');
  }
  return parsed;
}

DateTime? _nullableDateTime(Map<Object?, Object?> json, String field) {
  if (json[field] == null) return null;
  return _requiredDateTime(json, field);
}

List<String> _stringList(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid CABINET $field.');
  }
  return List.unmodifiable(value.cast<String>());
}
