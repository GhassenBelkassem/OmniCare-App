import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../workspace/doctor_workspace_config.dart';
import 'doctor_urgent_cabinet_commitment.dart';
import 'doctor_urgent_cabinet_arrival.dart';
import 'doctor_urgent_cabinet_commitment_source.dart';
import 'doctor_urgent_cabinet_decision.dart';
import 'doctor_urgent_cabinet_decision_source.dart';
import 'doctor_urgent_cabinet_request.dart';
import 'doctor_urgent_cabinet_request_source.dart';

enum DoctorUrgentCabinetDecisionTransition {
  accepted,
  declined,
  unavailable,
  failed,
  unknown,
  rejected,
  obsolete,
}

enum DoctorUrgentCabinetSimulationTransition {
  created,
  blocked,
  activeRequestExists,
}

@immutable
class DoctorUrgentCabinetNotificationOpenIntent {
  const DoctorUrgentCabinetNotificationOpenIntent({
    required this.requestIdentity,
    required this.state,
  });

  final String requestIdentity;
  final DoctorUrgentCabinetNotificationTargetState state;
}

/// Authenticated Doctor/CABINET-scoped owner for authoritative requests,
/// commitments, and explicitly isolated development fixtures.
class DoctorUrgentCabinetController extends ChangeNotifier {
  DoctorUrgentCabinetController({bool developmentSimulationEnabled = true})
    : _developmentSimulationEnabled = developmentSimulationEnabled,
      _fallbackRequestSource =
          DoctorUrgentCabinetRequestSources.forCurrentBuild() {
    _manualDecisionSource = DoctorUrgentCabinetDevelopmentDecisionSource(
      authorizeRequest: (request) =>
          _manualSimulationIdentities.contains(request.stableIdentity),
    );
  }

  static const maximumPreviewRequests = 3;

  final DoctorUrgentCabinetRequestSource _fallbackRequestSource;
  final bool _developmentSimulationEnabled;
  final DoctorUrgentCabinetDecisionSource _fallbackDecisionSource =
      const DoctorUrgentCabinetUnavailableDecisionSource();
  late final DoctorUrgentCabinetDevelopmentDecisionSource _manualDecisionSource;

  DoctorUrgentCabinetRequestSource? _requestSource;
  DoctorUrgentCabinetDecisionSource? _decisionSource;
  DoctorUrgentCabinetCommitmentSource? _commitmentSource;
  DoctorUrgentCabinetDecisionContext? _context;
  String? _configurationFingerprint;
  DoctorUrgentCabinetFeedState _feedState =
      const DoctorUrgentCabinetFeedLoading();
  final Map<String, DoctorUrgentCabinetDecisionState> _entries = {};
  final Set<String> _manualSimulationIdentities = {};
  final Set<String> _feedValidatedIdentities = {};
  List<DoctorUrgentCabinetCommitment> _activeCommitments = const [];
  int _contextEpoch = 0;
  int _feedGeneration = 0;
  int _decisionGeneration = 0;
  int _manualSimulationSequence = 0;
  CancelToken? _feedToken;
  CancelToken? _detailToken;
  CancelToken? _commitmentToken;
  CancelToken? _arrivalToken;
  final Set<String> _arrivalInProgress = {};
  Future<bool>? _refreshInFlight;
  DoctorUrgentCabinetNotificationOpenIntent? _notificationOpenIntent;
  final Map<String, CancelToken> _decisionTokens = {};
  bool _disposed = false;

  DoctorUrgentCabinetFeedState get feedState => _feedState;

  DoctorUrgentCabinetDecisionContext? get context => _context;

  bool get canReconcileInForeground =>
      !_disposed && _context?.hasCommitmentRecoveryContext == true;

  List<DoctorUrgentCabinetDecisionState> get entries =>
      UnmodifiableListView(_entries.values);

  List<DoctorUrgentCabinetRequest> get visibleNewRequests =>
      UnmodifiableListView(
        _entries.values
            .where(
              (state) =>
                  !state.isTerminal &&
                  _hasCurrentDecisionAuthority(state.request.stableIdentity),
            )
            .map((state) => state.request),
      );

  List<DoctorUrgentCabinetDecisionState> get terminalDecisions =>
      UnmodifiableListView(_entries.values.where((state) => state.isTerminal));

  bool get isDevelopmentSimulationAvailable =>
      kDebugMode &&
      _developmentSimulationEnabled &&
      _context?.isComplete == true;

  bool get usesDevelopmentPresentation =>
      _requestSource is DoctorUrgentCabinetDevelopmentRequestSource ||
      _manualSimulationIdentities.isNotEmpty ||
      (_entries.isNotEmpty &&
          _entries.values.every((entry) => entry.request.isDevelopmentFixture));

  bool get canSimulateDevelopmentRequest =>
      isDevelopmentSimulationAvailable && visibleNewRequests.isEmpty;

  bool get hasVisibleResponsibility =>
      _entries.values.any((state) => state is DoctorUrgentCabinetAccepted);

  DoctorUrgentCabinetDecisionState? stateFor(String stableIdentity) =>
      _entries[stableIdentity];

  bool containsCurrentRequest(String stableIdentity) {
    final state = _entries[stableIdentity];
    return state != null &&
        !state.isTerminal &&
        _hasCurrentDecisionAuthority(stableIdentity);
  }

  String? takeNotificationOpenRequestIdentity() {
    return takeNotificationOpenIntent()?.requestIdentity;
  }

  DoctorUrgentCabinetNotificationOpenIntent? takeNotificationOpenIntent() {
    final value = _notificationOpenIntent;
    _notificationOpenIntent = null;
    return value;
  }

  /// Resolves the notification against authenticated Doctor-owned backend
  /// state. A payload identifier can never manufacture an actionable row.
  Future<bool> openFromNotification(String requestIdentity) async {
    final normalized = requestIdentity.trim().toLowerCase();
    if (_disposed ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(normalized)) {
      return false;
    }
    await refresh(showLoading: false);
    if (_disposed) return false;

    final refreshed = _entries[normalized];
    if (refreshed is DoctorUrgentCabinetAccepted) {
      return _exposeNotificationTarget(
        normalized,
        DoctorUrgentCabinetNotificationTargetState.accepted,
      );
    }
    if (containsCurrentRequest(normalized)) {
      return _exposeNotificationTarget(
        normalized,
        DoctorUrgentCabinetNotificationTargetState.pending,
      );
    }

    final currentContext = _context;
    final source = _requestSource;
    if (currentContext == null ||
        source is! DoctorUrgentCabinetNotificationTargetSource) {
      if (!containsCurrentRequest(normalized)) return false;
      return _exposeNotificationTarget(
        normalized,
        DoctorUrgentCabinetNotificationTargetState.pending,
      );
    }
    final targetSource = source as DoctorUrgentCabinetNotificationTargetSource;

    final contextEpoch = _contextEpoch;
    _detailToken?.cancel('Doctor CABINET notification detail replaced.');
    final token = _detailToken = CancelToken();
    try {
      final target = await targetSource.resolveNotificationTarget(
        normalized,
        currentContext.requestContext,
        cancelToken: token,
      );
      if (_disposed ||
          contextEpoch != _contextEpoch ||
          !identical(_detailToken, token) ||
          token.isCancelled ||
          target.requestId != normalized ||
          currentContext.fingerprint != _context?.fingerprint) {
        return false;
      }

      if (target.state == DoctorUrgentCabinetNotificationTargetState.pending) {
        final request = target.pendingRequest;
        if (request == null || !currentContext.validates(request)) return false;
        _entries[normalized] = DoctorUrgentCabinetAwaitingDecision(request);
        _feedValidatedIdentities.add(normalized);
      } else if (target.state ==
          DoctorUrgentCabinetNotificationTargetState.accepted) {
        if (!await _recoverNotificationCommitment(
          target,
          currentContext,
          contextEpoch,
          token,
        )) {
          return false;
        }
      }
      return _exposeNotificationTarget(normalized, target.state);
    } catch (_) {
      return false;
    } finally {
      if (identical(_detailToken, token)) _detailToken = null;
    }
  }

  Future<bool> _recoverNotificationCommitment(
    DoctorUrgentCabinetNotificationTarget target,
    DoctorUrgentCabinetDecisionContext currentContext,
    int contextEpoch,
    CancelToken token,
  ) async {
    if (_entries[target.requestId] is DoctorUrgentCabinetAccepted) return true;
    final source = _commitmentSource;
    final commitmentId = target.commitmentId;
    if (source == null || commitmentId == null) return false;
    final commitment = await source.getCommitment(
      commitmentId,
      cancelToken: token,
    );
    if (_disposed ||
        contextEpoch != _contextEpoch ||
        token.isCancelled ||
        commitment.requestId != target.requestId ||
        !commitment.isActive) {
      return false;
    }
    _applyCommitments(<DoctorUrgentCabinetCommitment>[
      ..._activeCommitments.where(
        (item) => item.requestId != commitment.requestId,
      ),
      commitment,
    ], currentContext);
    return _entries[target.requestId] is DoctorUrgentCabinetAccepted;
  }

  bool _exposeNotificationTarget(
    String requestIdentity,
    DoctorUrgentCabinetNotificationTargetState state,
  ) {
    if (_disposed) return false;
    _notificationOpenIntent = DoctorUrgentCabinetNotificationOpenIntent(
      requestIdentity: requestIdentity,
      state: state,
    );
    notifyListeners();
    return true;
  }

  DoctorUrgentCabinetCommitment? commitmentFor(String requestIdentity) {
    for (final commitment in _activeCommitments) {
      if (commitment.requestId == requestIdentity) return commitment;
    }
    return null;
  }

  bool canVerifyArrival(String requestIdentity) =>
      !_arrivalInProgress.contains(requestIdentity) &&
      commitmentFor(requestIdentity)?.canVerifyArrival == true &&
      _commitmentSource is DoctorUrgentCabinetArrivalSource;

  bool canStartConsultation(String requestIdentity) =>
      commitmentFor(requestIdentity)?.canStartConsultation == true;

  bool isArrivalVerificationInProgress(String requestIdentity) =>
      _arrivalInProgress.contains(requestIdentity);

  Future<bool> verifyArrival(String requestIdentity, String token) async {
    final source = _commitmentSource;
    final commitment = commitmentFor(requestIdentity);
    if (_disposed ||
        source is! DoctorUrgentCabinetArrivalSource ||
        commitment == null ||
        !canVerifyArrival(requestIdentity)) {
      return false;
    }
    final arrivalSource = source as DoctorUrgentCabinetArrivalSource;
    final contextEpoch = _contextEpoch;
    final cancelToken = CancelToken();
    _arrivalToken?.cancel('Doctor CABINET arrival verification replaced.');
    _arrivalToken = cancelToken;
    _arrivalInProgress.add(requestIdentity);
    notifyListeners();
    try {
      final result = await arrivalSource.verifyArrival(
        commitment: commitment,
        token: token,
        cancelToken: cancelToken,
      );
      if (_disposed ||
          contextEpoch != _contextEpoch ||
          cancelToken.isCancelled ||
          result.requestId != requestIdentity ||
          result.commitmentId != commitment.commitmentId) {
        return false;
      }
      await refresh(showLoading: false);
      return true;
    } catch (_) {
      if (!_disposed && contextEpoch == _contextEpoch) {
        await refresh(showLoading: false);
      }
      return false;
    } finally {
      _arrivalInProgress.remove(requestIdentity);
      if (identical(_arrivalToken, cancelToken)) _arrivalToken = null;
      if (!_disposed) notifyListeners();
    }
  }

  bool _hasCurrentDecisionAuthority(String stableIdentity) =>
      _manualSimulationIdentities.contains(stableIdentity) ||
      _feedValidatedIdentities.contains(stableIdentity);

  void configure({
    required String authenticatedDoctorId,
    required DoctorWorkspaceConfig? workspaceConfig,
    DoctorUrgentCabinetRequestSource? requestSource,
    DoctorUrgentCabinetDecisionSource? decisionSource,
    DoctorUrgentCabinetCommitmentSource? commitmentSource,
  }) {
    if (_disposed) return;
    final nextContext = DoctorUrgentCabinetDecisionContext(
      authenticatedDoctorId: authenticatedDoctorId,
      workspace: workspaceConfig,
    );
    final nextRequestSource = requestSource ?? _fallbackRequestSource;
    final nextDecisionSource = decisionSource ?? _fallbackDecisionSource;
    final nextFingerprint = nextContext.fingerprint;
    if (_configurationFingerprint == nextFingerprint &&
        identical(_requestSource, nextRequestSource) &&
        identical(_decisionSource, nextDecisionSource) &&
        identical(_commitmentSource, commitmentSource)) {
      return;
    }

    final previousContext = _context;
    final retainsKnownResponsibility =
        previousContext != null &&
        previousContext.authenticatedDoctorId ==
            nextContext.authenticatedDoctorId &&
        previousContext.requestContext.cabinet?.normalizedFingerprint ==
            nextContext.requestContext.cabinet?.normalizedFingerprint;
    final retainedAccepted = retainsKnownResponsibility
        ? Map<String, DoctorUrgentCabinetDecisionState>.fromEntries(
            _entries.entries.where(
              (entry) =>
                  entry.value is DoctorUrgentCabinetAccepted &&
                  !entry.value.request.isDevelopmentFixture,
            ),
          )
        : const <String, DoctorUrgentCabinetDecisionState>{};

    _cancelRequests('Doctor CABINET context changed.');
    _refreshInFlight = null;
    _contextEpoch++;
    _feedGeneration++;
    _decisionGeneration++;
    _configurationFingerprint = nextFingerprint;
    _context = nextContext;
    _requestSource = nextRequestSource;
    _decisionSource = nextDecisionSource;
    _commitmentSource = commitmentSource;
    _entries
      ..clear()
      ..addAll(retainedAccepted);
    _manualSimulationIdentities.clear();
    _feedValidatedIdentities.clear();
    _activeCommitments = const [];
    _notificationOpenIntent = null;
    _arrivalInProgress.clear();

    if (!nextContext.hasCommitmentRecoveryContext) {
      _feedState = const DoctorUrgentCabinetFeedEmpty();
      _notifyConfigurationChange(_contextEpoch);
      return;
    }

    _feedState = nextContext.isComplete
        ? const DoctorUrgentCabinetFeedLoading()
        : const DoctorUrgentCabinetFeedEmpty();
    _notifyConfigurationChange(_contextEpoch);
    unawaited(refresh(showLoading: false));
  }

  void _notifyConfigurationChange(int contextEpoch) {
    scheduleMicrotask(() {
      if (!_disposed && contextEpoch == _contextEpoch) notifyListeners();
    });
  }

  /// Returns whether every authoritative read completed successfully for the
  /// current authenticated context. Callers use this only to select the next
  /// foreground reconciliation delay; server state remains authoritative.
  Future<bool> refresh({bool showLoading = true}) {
    final active = _refreshInFlight;
    if (active != null) return active;
    if (_disposed) return SynchronousFuture<bool>(false);
    final current = _context;
    if (current == null || !current.hasCommitmentRecoveryContext) {
      return SynchronousFuture<bool>(false);
    }
    if (showLoading) {
      _feedValidatedIdentities.clear();
      _feedState = current.isComplete
          ? const DoctorUrgentCabinetFeedLoading()
          : const DoctorUrgentCabinetFeedEmpty();
      notifyListeners();
    }
    final contextEpoch = _contextEpoch;
    final started = Future.wait<bool>([
      if (current.isComplete)
        _loadFeed(current, contextEpoch, ++_feedGeneration),
      _loadCommitments(current, contextEpoch),
    ]).then((results) => results.every((succeeded) => succeeded));
    _refreshInFlight = started;
    started.whenComplete(() {
      if (identical(_refreshInFlight, started)) _refreshInFlight = null;
    });
    return started;
  }

  Future<bool> _loadFeed(
    DoctorUrgentCabinetDecisionContext decisionContext,
    int contextEpoch,
    int generation,
  ) async {
    _feedToken?.cancel('Doctor CABINET feed replaced.');
    final token = _feedToken = CancelToken();
    DoctorUrgentCabinetFeedState next;
    try {
      next = await _requestSource!.load(
        decisionContext.requestContext,
        cancelToken: token,
      );
    } catch (_) {
      next = const DoctorUrgentCabinetFeedError(
        message:
            'La démonstration des demandes ne peut pas être chargée pour le moment.',
        canRetry: true,
      );
    }
    if (_disposed ||
        contextEpoch != _contextEpoch ||
        generation != _feedGeneration ||
        !identical(_feedToken, token) ||
        token.isCancelled ||
        decisionContext.fingerprint != _context?.fingerprint) {
      return false;
    }
    _feedToken = null;
    _applyFeed(next, decisionContext);
    notifyListeners();
    return next is DoctorUrgentCabinetFeedLoaded ||
        next is DoctorUrgentCabinetFeedEmpty;
  }

  Future<DoctorUrgentCabinetRequest?> loadAuthoritativeDetail(
    String stableIdentity,
  ) async {
    final current = _entries[stableIdentity]?.request;
    final currentContext = _context;
    final source = _requestSource;
    if (_disposed ||
        current == null ||
        currentContext == null ||
        source is! DoctorUrgentCabinetRequestDetailSource ||
        current.isDevelopmentFixture ||
        !containsCurrentRequest(stableIdentity)) {
      return current;
    }
    final detailSource = source as DoctorUrgentCabinetRequestDetailSource;
    final contextEpoch = _contextEpoch;
    _detailToken?.cancel('Doctor CABINET detail replaced.');
    final token = _detailToken = CancelToken();
    try {
      final detail = await detailSource.getRequest(
        stableIdentity,
        currentContext.requestContext,
        cancelToken: token,
      );
      if (_disposed ||
          contextEpoch != _contextEpoch ||
          !identical(_detailToken, token) ||
          token.isCancelled ||
          detail.stableIdentity != stableIdentity ||
          !currentContext.validates(detail)) {
        return null;
      }
      _entries[stableIdentity] = DoctorUrgentCabinetAwaitingDecision(detail);
      _feedValidatedIdentities.add(stableIdentity);
      notifyListeners();
      return detail;
    } catch (_) {
      if (!_disposed &&
          contextEpoch == _contextEpoch &&
          identical(_detailToken, token) &&
          !token.isCancelled) {
        await refresh();
      }
      return null;
    } finally {
      if (identical(_detailToken, token)) _detailToken = null;
    }
  }

  Future<bool> _loadCommitments(
    DoctorUrgentCabinetDecisionContext decisionContext,
    int contextEpoch,
  ) async {
    final source = _commitmentSource;
    if (source == null) return true;
    _commitmentToken?.cancel('Doctor CABINET commitment refresh replaced.');
    final token = _commitmentToken = CancelToken();
    try {
      final commitments = await source.listCommitments(
        limit: 20,
        cancelToken: token,
      );
      if (_disposed ||
          contextEpoch != _contextEpoch ||
          !identical(_commitmentToken, token) ||
          token.isCancelled ||
          decisionContext.fingerprint != _context?.fingerprint) {
        return false;
      }
      _applyCommitments(commitments, decisionContext);
      notifyListeners();
      return true;
    } catch (_) {
      // Keep any already recovered responsibility visible on transient read
      // failures. The feed state remains the existing safe retry surface.
      return false;
    } finally {
      if (identical(_commitmentToken, token)) _commitmentToken = null;
    }
  }

  void _applyCommitments(
    List<DoctorUrgentCabinetCommitment> commitments,
    DoctorUrgentCabinetDecisionContext decisionContext,
  ) {
    final active = commitments.where((item) => item.isActive).toList();
    _activeCommitments = List.unmodifiable(active);
    final activeRequestIds = active.map((item) => item.requestId).toSet();
    for (final commitment in commitments.where((item) => !item.isActive)) {
      final existing = _entries[commitment.requestId];
      if (existing is DoctorUrgentCabinetAccepted &&
          !existing.request.isDevelopmentFixture) {
        _entries[commitment.requestId] = DoctorUrgentCabinetUnavailable(
          existing.request,
        );
      }
    }
    for (final commitment in active) {
      final existing = _entries[commitment.requestId]?.request;
      final request = existing != null && decisionContext.validates(existing)
          ? existing
          : commitment.toRecoveredRequest(decisionContext.requestContext);
      _entries[commitment.requestId] = DoctorUrgentCabinetAccepted(
        request,
        commitment: commitment,
      );
      _feedValidatedIdentities.remove(commitment.requestId);
    }
    final hasActiveCommitment = active.isNotEmpty;
    for (final entry in _entries.entries.toList()) {
      if (activeRequestIds.contains(entry.key) ||
          entry.value.request.isDevelopmentFixture ||
          entry.value.isTerminal) {
        continue;
      }
      if (hasActiveCommitment && _feedValidatedIdentities.contains(entry.key)) {
        _entries[entry.key] = DoctorUrgentCabinetCapacityBlocked(
          entry.value.request,
          message:
              'Une responsabilité CABINET est déjà active. Cette demande reste en attente côté serveur.',
        );
      } else if (!hasActiveCommitment &&
          entry.value is DoctorUrgentCabinetCapacityBlocked) {
        _entries[entry.key] = DoctorUrgentCabinetAwaitingDecision(
          entry.value.request,
        );
      }
    }
  }

  void _applyFeed(
    DoctorUrgentCabinetFeedState next,
    DoctorUrgentCabinetDecisionContext decisionContext,
  ) {
    if (next is DoctorUrgentCabinetFeedLoaded) {
      final unique = <String, DoctorUrgentCabinetRequest>{};
      for (final request in next.requests) {
        if (decisionContext.validates(request)) {
          unique.putIfAbsent(request.stableIdentity, () => request);
        }
      }
      final visible = unique.values.take(maximumPreviewRequests).toList();
      _feedValidatedIdentities
        ..clear()
        ..addAll(
          visible
              .map((request) => request.stableIdentity)
              .where(
                (identity) => !_manualSimulationIdentities.contains(identity),
              ),
        );
      _mergeRequests(visible);
      if (_activeCommitments.isNotEmpty) {
        _applyCommitments(_activeCommitments, decisionContext);
      }
      _feedState = visible.isEmpty
          ? const DoctorUrgentCabinetFeedEmpty()
          : DoctorUrgentCabinetFeedLoaded(visible);
      return;
    }
    if (next is DoctorUrgentCabinetFeedEmpty) {
      _feedValidatedIdentities.clear();
      _markMissingActiveEntriesUnavailable(const <String>{});
      _feedState = next;
      return;
    }
    _feedValidatedIdentities.clear();
    _feedState = next;
  }

  void _mergeRequests(List<DoctorUrgentCabinetRequest> requests) {
    final incomingIds = requests
        .map((request) => request.stableIdentity)
        .toSet();
    _markMissingActiveEntriesUnavailable(incomingIds);
    for (final request in requests) {
      if (_manualSimulationIdentities.contains(request.stableIdentity)) {
        continue;
      }
      final existing = _entries[request.stableIdentity];
      if (existing == null ||
          existing is DoctorUrgentCabinetAwaitingDecision ||
          existing is DoctorUrgentCabinetDecisionFailed ||
          existing is DoctorUrgentCabinetDecisionOutcomeUnknown ||
          existing is DoctorUrgentCabinetCapacityBlocked) {
        _entries[request.stableIdentity] = DoctorUrgentCabinetAwaitingDecision(
          request,
        );
      }
    }
  }

  void _markMissingActiveEntriesUnavailable(Set<String> incomingIds) {
    for (final entry in _entries.entries.toList()) {
      if (!entry.value.isTerminal &&
          !_manualSimulationIdentities.contains(entry.key) &&
          !incomingIds.contains(entry.key)) {
        _entries[entry.key] = DoctorUrgentCabinetUnavailable(
          entry.value.request,
        );
      }
    }
  }

  DoctorUrgentCabinetSimulationTransition simulateDevelopmentRequest() {
    if (_disposed || !isDevelopmentSimulationAvailable) {
      return DoctorUrgentCabinetSimulationTransition.blocked;
    }
    if (visibleNewRequests.isNotEmpty) {
      return DoctorUrgentCabinetSimulationTransition.activeRequestExists;
    }
    final current = _context;
    final cabinet = current?.requestContext.cabinet;
    if (current == null || cabinet == null || !current.isComplete) {
      return DoctorUrgentCabinetSimulationTransition.blocked;
    }

    final sequence = ++_manualSimulationSequence;
    final request = DoctorUrgentCabinetRequest(
      developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(
        'd-ui-03a-manual-$_contextEpoch-$sequence',
      ),
      targetDoctorId: current.authenticatedDoctorId,
      targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
        DoctorUrgentCabinetDevelopmentCabinetKey(
          'd-ui-03a-local-cabinet-context',
        ),
      ),
      cabinet: cabinet,
      patient: const DoctorUrgentCabinetPatientProjection.masked(),
      fee: DoctorUrgentCabinetFeeSnapshot(
        amountMilliTnd: 75000,
        currencyCode: 'TND',
        provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
      ),
      dataProvenance: DoctorUrgentCabinetDataProvenance.developmentFixture,
      status: DoctorUrgentCabinetRequestStatus.newRequest,
    );
    if (!current.validates(request)) {
      return DoctorUrgentCabinetSimulationTransition.blocked;
    }

    _manualSimulationIdentities.add(request.stableIdentity);
    _entries[request.stableIdentity] = DoctorUrgentCabinetAwaitingDecision(
      request,
    );
    _feedState = DoctorUrgentCabinetFeedLoaded([request]);
    notifyListeners();
    return DoctorUrgentCabinetSimulationTransition.created;
  }

  Future<DoctorUrgentCabinetDecisionTransition> accept(String stableIdentity) =>
      _decide(stableIdentity, DoctorUrgentCabinetDecisionAction.accept);

  Future<DoctorUrgentCabinetDecisionTransition> refuse(String stableIdentity) =>
      _decide(stableIdentity, DoctorUrgentCabinetDecisionAction.refuse);

  Future<DoctorUrgentCabinetDecisionTransition> _decide(
    String stableIdentity,
    DoctorUrgentCabinetDecisionAction action,
  ) async {
    if (_disposed) return DoctorUrgentCabinetDecisionTransition.obsolete;
    final currentState = _entries[stableIdentity];
    final currentContext = _context;
    final source = _manualSimulationIdentities.contains(stableIdentity)
        ? _manualDecisionSource
        : _decisionSource;
    if (currentState == null ||
        currentContext == null ||
        source == null ||
        !_hasCurrentDecisionAuthority(stableIdentity) ||
        !_canStart(currentState, action) ||
        !_canDecide(currentState.request, action, currentContext, source)) {
      return DoctorUrgentCabinetDecisionTransition.rejected;
    }

    final contextEpoch = _contextEpoch;
    final operationGeneration = ++_decisionGeneration;
    final token = CancelToken();
    _decisionTokens[stableIdentity]?.cancel(
      'Doctor CABINET decision replaced.',
    );
    _decisionTokens[stableIdentity] = token;
    _entries[stableIdentity] = DoctorUrgentCabinetDecisionInProgress(
      currentState.request,
      action: action,
      operationGeneration: operationGeneration,
    );
    notifyListeners();

    DoctorUrgentCabinetDecisionResult result;
    try {
      result = await source.decide(
        request: currentState.request,
        action: action,
        context: currentContext,
        cancelToken: token,
      );
    } catch (_) {
      result = DoctorUrgentCabinetDecisionUnknownResult(
        requestIdentity: stableIdentity,
        action: action,
        contextFingerprint: currentContext.fingerprint,
        message:
            'Le résultat de cette décision ne peut pas être vérifié pour le moment.',
      );
    }

    if (_disposed ||
        contextEpoch != _contextEpoch ||
        !identical(_decisionTokens[stableIdentity], token) ||
        token.isCancelled ||
        currentContext.fingerprint != _context?.fingerprint) {
      return DoctorUrgentCabinetDecisionTransition.obsolete;
    }
    final pending = _entries[stableIdentity];
    if (pending is! DoctorUrgentCabinetDecisionInProgress ||
        pending.operationGeneration != operationGeneration) {
      return DoctorUrgentCabinetDecisionTransition.obsolete;
    }
    if (result.requestIdentity != stableIdentity ||
        result.action != action ||
        result.contextFingerprint != currentContext.fingerprint) {
      _entries[stableIdentity] = DoctorUrgentCabinetDecisionOutcomeUnknown(
        pending.request,
        action: action,
        message:
            'Le résultat de cette décision ne peut pas être vérifié pour le moment.',
      );
      notifyListeners();
      return DoctorUrgentCabinetDecisionTransition.unknown;
    }

    final transition = switch (result) {
      DoctorUrgentCabinetAcceptedResult(:final commitment) => _accept(
        pending.request,
        commitment,
      ),
      DoctorUrgentCabinetDeclinedResult() => _decline(pending.request),
      DoctorUrgentCabinetUnavailableResult() => _unavailable(pending.request),
      DoctorUrgentCabinetDecisionDefiniteFailureResult(:final message) => _fail(
        pending.request,
        action,
        message,
      ),
      DoctorUrgentCabinetDecisionUnknownResult(:final message) => _unknown(
        pending.request,
        action,
        message,
      ),
    };
    _decisionTokens.remove(stableIdentity);
    notifyListeners();
    if (!pending.request.isDevelopmentFixture) {
      await refresh(showLoading: false);
    }
    return transition;
  }

  bool _canStart(
    DoctorUrgentCabinetDecisionState state,
    DoctorUrgentCabinetDecisionAction action,
  ) => switch (state) {
    DoctorUrgentCabinetAwaitingDecision() => true,
    DoctorUrgentCabinetDecisionFailed(action: final previousAction) =>
      previousAction == action,
    _ => false,
  };

  bool _canDecide(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionAction action,
    DoctorUrgentCabinetDecisionContext decisionContext,
    DoctorUrgentCabinetDecisionSource source,
  ) =>
      decisionContext.validates(request) &&
      request.status == DoctorUrgentCabinetRequestStatus.newRequest &&
      (switch (action) {
        DoctorUrgentCabinetDecisionAction.accept => request.canAccept,
        DoctorUrgentCabinetDecisionAction.refuse => request.canDecline,
      }) &&
      !_entries.values.any(
        (state) =>
            state is DoctorUrgentCabinetAccepted &&
            !state.request.isDevelopmentFixture &&
            state.request.stableIdentity != request.stableIdentity,
      ) &&
      request.isDevelopmentFixture == source.isDevelopmentFixture &&
      (request.isDevelopmentFixture
          ? request.developmentFixtureKey != null &&
                request.serverRequestReference == null &&
                request.fee.provenance ==
                    DoctorUrgentCabinetFeeProvenance.developmentFixture
          : request.serverRequestReference != null &&
                request.fee.provenance ==
                    DoctorUrgentCabinetFeeProvenance.service);

  DoctorUrgentCabinetDecisionTransition _accept(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetCommitment? commitment,
  ) {
    _entries[request.stableIdentity] = DoctorUrgentCabinetAccepted(
      request,
      commitment: commitment,
    );
    return DoctorUrgentCabinetDecisionTransition.accepted;
  }

  DoctorUrgentCabinetDecisionTransition _decline(
    DoctorUrgentCabinetRequest request,
  ) {
    _entries[request.stableIdentity] = DoctorUrgentCabinetDeclined(request);
    return DoctorUrgentCabinetDecisionTransition.declined;
  }

  DoctorUrgentCabinetDecisionTransition _unavailable(
    DoctorUrgentCabinetRequest request,
  ) {
    _entries[request.stableIdentity] = DoctorUrgentCabinetUnavailable(request);
    return DoctorUrgentCabinetDecisionTransition.unavailable;
  }

  DoctorUrgentCabinetDecisionTransition _fail(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionAction action,
    String message,
  ) {
    _entries[request.stableIdentity] = DoctorUrgentCabinetDecisionFailed(
      request,
      action: action,
      message: message,
    );
    return DoctorUrgentCabinetDecisionTransition.failed;
  }

  DoctorUrgentCabinetDecisionTransition _unknown(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionAction action,
    String message,
  ) {
    _entries[request.stableIdentity] =
        DoctorUrgentCabinetDecisionOutcomeUnknown(
          request,
          action: action,
          message: message,
        );
    return DoctorUrgentCabinetDecisionTransition.unknown;
  }

  void resetDevelopmentSimulation() {
    if (_disposed) return;
    _contextEpoch++;
    _feedGeneration++;
    _decisionGeneration++;
    _entries.clear();
    _manualSimulationIdentities.clear();
    _feedValidatedIdentities.clear();
    _activeCommitments = const [];
    _notificationOpenIntent = null;
    _arrivalInProgress.clear();
    final current = _context;
    if (current == null || !current.isComplete) {
      _feedState = const DoctorUrgentCabinetFeedEmpty();
      notifyListeners();
      return;
    }
    _feedState = const DoctorUrgentCabinetFeedLoading();
    notifyListeners();
    unawaited(_loadFeed(current, _contextEpoch, ++_feedGeneration));
  }

  void clear() {
    if (_disposed) return;
    _cancelRequests('Doctor CABINET session cleared.');
    _refreshInFlight = null;
    final sessionSource = _requestSource;
    if (sessionSource is DoctorUrgentCabinetSessionStateSource) {
      (sessionSource as DoctorUrgentCabinetSessionStateSource)
          .clearSessionState();
    }
    _contextEpoch++;
    _feedGeneration++;
    _decisionGeneration++;
    _configurationFingerprint = null;
    _context = null;
    _requestSource = null;
    _decisionSource = null;
    _commitmentSource = null;
    _entries.clear();
    _manualSimulationIdentities.clear();
    _feedValidatedIdentities.clear();
    _activeCommitments = const [];
    _notificationOpenIntent = null;
    _feedState = const DoctorUrgentCabinetFeedEmpty();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRequests('Doctor CABINET controller disposed.');
    _refreshInFlight = null;
    final sessionSource = _requestSource;
    if (sessionSource is DoctorUrgentCabinetSessionStateSource) {
      (sessionSource as DoctorUrgentCabinetSessionStateSource)
          .clearSessionState();
    }
    _contextEpoch++;
    _feedGeneration++;
    _decisionGeneration++;
    _entries.clear();
    _manualSimulationIdentities.clear();
    _feedValidatedIdentities.clear();
    super.dispose();
  }

  void _cancelRequests(String reason) {
    _feedToken?.cancel(reason);
    _detailToken?.cancel(reason);
    _commitmentToken?.cancel(reason);
    _arrivalToken?.cancel(reason);
    for (final token in _decisionTokens.values) {
      token.cancel(reason);
    }
    _feedToken = null;
    _detailToken = null;
    _commitmentToken = null;
    _arrivalToken = null;
    _arrivalInProgress.clear();
    _decisionTokens.clear();
  }
}
