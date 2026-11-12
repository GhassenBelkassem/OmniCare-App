import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/uuid_v4.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_submission_activation_gate.dart';
import 'urgent_cabinet_submission_coordinator.dart';
import 'urgent_cabinet_targeted_request_models.dart';
import 'urgent_cabinet_targeted_request_repository.dart';

enum UrgentCabinetPatientLifecyclePhase {
  idle,
  recovering,
  pending,
  cancelling,
  withdrawing,
  issuingArrivalHandoff,
  accepted,
  arrivedWaitingForDoctor,
  consultationInProgress,
  careCompleted,
  declined,
  cancelled,
  expired,
  unavailable,
}

enum UrgentCabinetPatientCancellationResult {
  cancelled,
  expired,
  acceptedWon,
  reconciled,
  rejected,
  obsolete,
}

/// Owns server-authoritative Patient request reconciliation.
///
/// Submission is available only through [submitAuthorized], which enforces the
/// four-authority activation gate before delegating to the existing submission
/// coordinator. Recovery and subsequent reads remain server-authoritative.
class UrgentCabinetPatientLifecycleController extends ChangeNotifier {
  UrgentCabinetPatientLifecycleController({
    required UrgentCabinetTargetedRequestRepository repository,
    required UrgentCabinetSubmissionCoordinator submissionCoordinator,
    Duration pollingInterval = const Duration(seconds: 20),
    DateTime Function() clock = DateTime.now,
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) : assert(
         pollingInterval >= const Duration(seconds: 5) &&
             pollingInterval <= const Duration(minutes: 2),
       ),
       _repository = repository,
       _submissionCoordinator = submissionCoordinator,
       _pollingInterval = pollingInterval,
       _clock = clock,
       _idempotencyKeyFactory = idempotencyKeyFactory;

  final UrgentCabinetTargetedRequestRepository _repository;
  final UrgentCabinetSubmissionCoordinator _submissionCoordinator;
  final Duration _pollingInterval;
  final DateTime Function() _clock;
  final String Function() _idempotencyKeyFactory;

  UrgentCabinetPatientLifecyclePhase _phase =
      UrgentCabinetPatientLifecyclePhase.idle;
  UrgentCabinetTargetedRequestSnapshot? _snapshot;
  UrgentCabinetPatientRequestFailure? _failure;
  String? _accountId;
  UrgentCabinetCareSubject? _subject;
  DateTime? _receivedAt;
  int _generation = 0;
  bool _disposed = false;
  bool _waitingRouteActive = false;
  Timer? _pollTimer;
  Timer? _deadlineTimer;
  CancelToken? _readToken;
  CancelToken? _cancelToken;
  CancelToken? _operationalToken;
  Future<bool>? _refreshInFlight;
  Future<UrgentCabinetPatientCancellationResult>? _cancelInFlight;
  String? _cancellationRequestId;
  String? _cancellationIdempotencyKey;
  String? _withdrawalRequestId;
  String? _withdrawalIdempotencyKey;
  String? _handoffRequestId;
  String? _handoffIdempotencyKey;
  UrgentCabinetArrivalHandoff? _arrivalHandoff;

  UrgentCabinetPatientLifecyclePhase get phase => _phase;
  UrgentCabinetTargetedRequestSnapshot? get snapshot => _snapshot;
  UrgentCabinetPatientRequestFailure? get failure => _failure;
  bool get hasTransientReadFailure =>
      _snapshot != null &&
      _phase == UrgentCabinetPatientLifecyclePhase.unavailable &&
      _failure != null &&
      _isTransientReadFailure(_failure!.kind);
  bool get isPending =>
      _snapshot?.responseStatus == UrgentCabinetPatientResponseStatus.pending;
  bool get hasAcceptedJourney =>
      _snapshot?.responseStatus == UrgentCabinetPatientResponseStatus.accepted;
  bool get canCancel =>
      isPending &&
      _phase != UrgentCabinetPatientLifecyclePhase.cancelling &&
      _snapshot!.allowedActions.contains('CANCEL');
  bool get canWithdraw =>
      _snapshot?.responseStatus ==
          UrgentCabinetPatientResponseStatus.accepted &&
      _snapshot?.arrivalVerifiedAt == null &&
      _snapshot!.allowedActions.contains('WITHDRAW') &&
      _phase != UrgentCabinetPatientLifecyclePhase.withdrawing;
  bool get canIssueArrivalHandoff =>
      _snapshot?.responseStatus ==
          UrgentCabinetPatientResponseStatus.accepted &&
      _snapshot?.arrivalVerifiedAt == null &&
      _snapshot!.allowedActions.contains('ISSUE_ARRIVAL_QR') &&
      _phase != UrgentCabinetPatientLifecyclePhase.issuingArrivalHandoff;
  UrgentCabinetArrivalHandoff? get arrivalHandoff => _arrivalHandoff;

  Duration? get approximateRemainingResponseWindow {
    final current = _snapshot;
    final received = _receivedAt;
    if (current == null || received == null || !isPending) return null;
    final serverWindow = current.responseDeadlineAt.difference(
      current.evaluatedAt,
    );
    final elapsed = _clock().difference(received);
    final remaining = serverWindow - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<UrgentCabinetSubmissionResult> submitAuthorized({
    required UrgentCabinetSubmissionActivationGate activationGate,
    required String? authenticatedAccountId,
    required UrgentCabinetCareSubject subject,
    required UrgentCabinetTargetedSubmissionValidation submissionValidation,
    required bool currentAuthoritativeTargetAndQuote,
  }) async {
    if (!activationGate.allows(
      authenticatedAccountId: authenticatedAccountId,
      submission: submissionValidation,
      currentAuthoritativeTargetAndQuote: currentAuthoritativeTargetAndQuote,
    )) {
      return const UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.rolloutUnavailable,
          message: 'Les demandes CABINET synthétiques ne sont pas activées.',
        ),
      );
    }

    final submission = submissionValidation.submission!;
    if (_disposed || submission.careSubject != subject) {
      return const UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.invalidResponse,
          message: 'La demande CABINET ne correspond plus au bénéficiaire.',
        ),
      );
    }
    final normalizedAccount = _requireAccount(authenticatedAccountId!);
    if (_accountId != null && _accountId != normalizedAccount) {
      return const UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.sessionRejected,
          message: 'Le compte Patient a changé.',
        ),
      );
    }

    final generation = ++_generation;
    _cancelNetwork('urgent-cabinet-submission-started');
    _clearOperationalState();
    _stopTimers();
    _accountId = normalizedAccount;
    _subject = subject;
    _snapshot = null;
    _failure = null;
    _phase = UrgentCabinetPatientLifecyclePhase.recovering;
    notifyListeners();

    UrgentCabinetSubmissionResult result;
    try {
      result = await _submissionCoordinator.submit(
        accountId: normalizedAccount,
        submission: submission,
      );
    } catch (error) {
      result = UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure.from(error),
      );
    }
    if (!_isCurrent(generation, normalizedAccount, subject)) {
      return const UrgentCabinetSubmissionResult.obsolete();
    }
    final snapshot = result.snapshot;
    if (snapshot == null) {
      _failure = result.failure;
      _phase = result.kind == UrgentCabinetSubmissionResultKind.unknownOutcome
          ? UrgentCabinetPatientLifecyclePhase.unavailable
          : UrgentCabinetPatientLifecyclePhase.idle;
      notifyListeners();
      return result;
    }
    if (!_matchesSubmission(snapshot, submission) ||
        !_acceptSnapshot(snapshot, generation: generation)) {
      const failure = UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.invalidResponse,
        message: 'La réponse CABINET ne correspond pas à la demande envoyée.',
      );
      _failure = failure;
      _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
      _stopTimers();
      notifyListeners();
      return const UrgentCabinetSubmissionResult.unknownOutcome(failure);
    }
    return result;
  }

  Future<bool> recover({
    required String accountId,
    required UrgentCabinetCareSubject subject,
  }) async {
    final normalizedAccount = _requireAccount(accountId);
    if (_disposed) return false;
    final generation = ++_generation;
    _cancelNetwork('urgent-cabinet-recovery-started');
    _clearOperationalState();
    _accountId = normalizedAccount;
    _subject = subject;
    _snapshot = null;
    _failure = null;
    _phase = UrgentCabinetPatientLifecyclePhase.recovering;
    _stopTimers();
    notifyListeners();

    UrgentCabinetSubmissionResult result;
    try {
      result = await _submissionCoordinator.recoverAfterRestart(
        accountId: normalizedAccount,
        subject: subject,
      );
    } catch (error) {
      result = UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure.from(error),
      );
    }
    if (!_isCurrent(generation, normalizedAccount, subject)) return false;
    final recovered = result.snapshot;
    if (recovered == null) {
      _failure = result.failure;
      _phase =
          result.kind == UrgentCabinetSubmissionResultKind.obsolete ||
              result.kind == UrgentCabinetSubmissionResultKind.noActiveRequest
          ? UrgentCabinetPatientLifecyclePhase.idle
          : UrgentCabinetPatientLifecyclePhase.unavailable;
      notifyListeners();
      return false;
    }
    return _acceptSnapshot(recovered, generation: generation);
  }

  /// Restores the account-scoped request during authenticated application
  /// bootstrap, before the Patient has selected a subject in the new process.
  ///
  /// The opaque submission receipt is tried first by the coordinator. Its
  /// backend response supplies the authoritative SELF/family subject; the
  /// SELF argument is only the safe fallback for the subject-scoped active
  /// endpoint when no receipt exists. No submission is performed here.
  Future<bool> recoverAfterAuthentication({required String accountId}) async {
    final normalizedAccount = _requireAccount(accountId);
    if (_disposed) return false;
    final generation = ++_generation;
    _cancelNetwork('urgent-cabinet-authenticated-recovery-started');
    _clearOperationalState();
    _accountId = normalizedAccount;
    _subject = null;
    _snapshot = null;
    _failure = null;
    _phase = UrgentCabinetPatientLifecyclePhase.recovering;
    _stopTimers();
    notifyListeners();

    UrgentCabinetSubmissionResult result;
    try {
      result = await _submissionCoordinator.recoverAfterRestart(
        accountId: normalizedAccount,
        subject: const UrgentCabinetCareSubject.self(),
      );
    } catch (error) {
      result = UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure.from(error),
      );
    }
    if (!_isCurrentAccountRecovery(generation, normalizedAccount)) {
      return false;
    }
    final recovered = result.snapshot;
    if (recovered == null) {
      _failure = result.failure;
      _phase =
          result.kind == UrgentCabinetSubmissionResultKind.obsolete ||
              result.kind == UrgentCabinetSubmissionResultKind.noActiveRequest
          ? UrgentCabinetPatientLifecyclePhase.idle
          : UrgentCabinetPatientLifecyclePhase.unavailable;
      notifyListeners();
      return false;
    }

    // The backend recovery receipt is account-bound and revalidates current
    // ownership. Only that authoritative response may establish the subject
    // after a browser restart.
    _subject = recovered.careSubject;
    return _acceptSnapshot(recovered, generation: generation);
  }

  /// Resolves a notification reference through the authenticated, Patient-owned
  /// status endpoint. The notification payload is never treated as lifecycle
  /// authority and this method never submits a request.
  Future<bool> recoverFromNotification({
    required String accountId,
    required String requestId,
  }) async {
    final normalizedAccount = _requireAccount(accountId);
    if (_disposed) return false;
    final generation = ++_generation;
    _cancelNetwork('urgent-cabinet-notification-recovery-started');
    _clearOperationalState();
    _accountId = normalizedAccount;
    _subject = null;
    _snapshot = null;
    _failure = null;
    _phase = UrgentCabinetPatientLifecyclePhase.recovering;
    _stopTimers();
    notifyListeners();

    try {
      final token = _readToken = CancelToken();
      final recovered = await _repository.status(requestId, cancelToken: token);
      if (!_isCurrentAccountRecovery(generation, normalizedAccount) ||
          token.isCancelled ||
          recovered.requestId != requestId.toLowerCase()) {
        return false;
      }
      _readToken = null;
      _subject = recovered.careSubject;
      return _acceptSnapshot(recovered, generation: generation);
    } catch (error) {
      if (!_isCurrentAccountRecovery(generation, normalizedAccount)) {
        return false;
      }
      _readToken = null;
      _failure = UrgentCabinetPatientRequestFailure.from(error);
      _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
      notifyListeners();
      return false;
    }
  }

  /// Accepts a snapshot produced by the authorized submission path. It is also
  /// the non-network seam used by the lifecycle unit tests.
  bool adopt({
    required String accountId,
    required UrgentCabinetCareSubject subject,
    required UrgentCabinetTargetedRequestSnapshot snapshot,
  }) {
    if (_disposed) return false;
    final normalizedAccount = _requireAccount(accountId);
    if (_accountId != null && _accountId != normalizedAccount) return false;
    _accountId = normalizedAccount;
    _subject ??= subject;
    return _acceptSnapshot(snapshot, generation: _generation);
  }

  Future<bool> refresh() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final snapshot = _snapshot;
    final account = _accountId;
    final subject = _subject;
    if (_disposed || snapshot == null || account == null || subject == null) {
      return SynchronousFuture(false);
    }
    final generation = _generation;
    final token = CancelToken();
    _readToken?.cancel('urgent-cabinet-read-replaced');
    _readToken = token;
    final started = _refresh(
      requestId: snapshot.requestId,
      generation: generation,
      accountId: account,
      subject: subject,
      token: token,
    );
    _refreshInFlight = started;
    started.whenComplete(() {
      if (identical(_refreshInFlight, started)) _refreshInFlight = null;
      if (identical(_readToken, token)) _readToken = null;
    });
    return started;
  }

  Future<bool> _refresh({
    required String requestId,
    required int generation,
    required String accountId,
    required UrgentCabinetCareSubject subject,
    required CancelToken token,
  }) async {
    try {
      final refreshed = await _repository.status(requestId, cancelToken: token);
      if (!_isCurrent(generation, accountId, subject)) return false;
      return _acceptSnapshot(refreshed, generation: generation);
    } on UrgentCabinetPatientRequestFailure catch (failure) {
      if (!_isCurrent(generation, accountId, subject) ||
          failure.kind == UrgentCabinetPatientRequestFailureKind.cancelled) {
        return false;
      }
      _failure = failure;
      if (failure.kind ==
          UrgentCabinetPatientRequestFailureKind.sessionRejected) {
        await invalidateSession(accountId);
        return false;
      }
      _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
      if (!_isTransientReadFailure(failure.kind)) _stopTimers();
      notifyListeners();
      return false;
    } catch (error) {
      if (!_isCurrent(generation, accountId, subject)) return false;
      _failure = UrgentCabinetPatientRequestFailure.from(error);
      _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
      _stopTimers();
      notifyListeners();
      return false;
    }
  }

  Future<UrgentCabinetPatientCancellationResult> cancel() {
    final active = _cancelInFlight;
    if (active != null) return active;
    final snapshot = _snapshot;
    final account = _accountId;
    final subject = _subject;
    if (_disposed ||
        snapshot == null ||
        account == null ||
        subject == null ||
        !canCancel) {
      return SynchronousFuture(UrgentCabinetPatientCancellationResult.rejected);
    }
    if (_cancellationRequestId != snapshot.requestId) {
      _cancellationRequestId = snapshot.requestId;
      _cancellationIdempotencyKey = _requireCancellationKey(
        _idempotencyKeyFactory(),
      );
    }
    final generation = _generation;
    final token = CancelToken();
    _cancelToken = token;
    _phase = UrgentCabinetPatientLifecyclePhase.cancelling;
    _failure = null;
    notifyListeners();
    final started = _cancel(
      snapshot: snapshot,
      generation: generation,
      accountId: account,
      subject: subject,
      token: token,
    );
    _cancelInFlight = started;
    started.whenComplete(() {
      if (identical(_cancelInFlight, started)) _cancelInFlight = null;
      if (identical(_cancelToken, token)) _cancelToken = null;
    });
    return started;
  }

  Future<UrgentCabinetPatientCancellationResult> _cancel({
    required UrgentCabinetTargetedRequestSnapshot snapshot,
    required int generation,
    required String accountId,
    required UrgentCabinetCareSubject subject,
    required CancelToken token,
  }) async {
    try {
      final result = await _repository.cancel(
        requestId: snapshot.requestId,
        command: UrgentCabinetPatientCancellation(
          expectedResponseRevision: snapshot.responseRevision,
          expectedRequestRevision: snapshot.requestRevision,
          expectedJourneyRevision: snapshot.journeyRevision,
        ),
        idempotencyKey: _cancellationIdempotencyKey!,
        cancelToken: token,
      );
      if (!_isCurrent(generation, accountId, subject)) {
        return UrgentCabinetPatientCancellationResult.obsolete;
      }
      if (!_acceptSnapshot(result, generation: generation)) {
        return UrgentCabinetPatientCancellationResult.rejected;
      }
      return result.responseStatus == UrgentCabinetPatientResponseStatus.expired
          ? UrgentCabinetPatientCancellationResult.expired
          : UrgentCabinetPatientCancellationResult.cancelled;
    } on UrgentCabinetPatientRequestFailure catch (failure) {
      if (!_isCurrent(generation, accountId, subject) ||
          failure.kind == UrgentCabinetPatientRequestFailureKind.cancelled) {
        return UrgentCabinetPatientCancellationResult.obsolete;
      }
      _failure = failure;
      // A failed/ambiguous cancellation is never projected locally. Refetch
      // first so Doctor acceptance wins visibly when it won in PostgreSQL.
      final reconciled = await _reconcileAfterCancellation(
        requestId: snapshot.requestId,
        generation: generation,
        accountId: accountId,
        subject: subject,
      );
      if (!_isCurrent(generation, accountId, subject)) {
        return UrgentCabinetPatientCancellationResult.obsolete;
      }
      if (reconciled?.responseStatus ==
          UrgentCabinetPatientResponseStatus.accepted) {
        return UrgentCabinetPatientCancellationResult.acceptedWon;
      }
      return reconciled != null
          ? UrgentCabinetPatientCancellationResult.reconciled
          : UrgentCabinetPatientCancellationResult.rejected;
    } catch (error) {
      if (!_isCurrent(generation, accountId, subject)) {
        return UrgentCabinetPatientCancellationResult.obsolete;
      }
      _failure = UrgentCabinetPatientRequestFailure.from(error);
      final reconciled = await _reconcileAfterCancellation(
        requestId: snapshot.requestId,
        generation: generation,
        accountId: accountId,
        subject: subject,
      );
      if (reconciled?.responseStatus ==
          UrgentCabinetPatientResponseStatus.accepted) {
        return UrgentCabinetPatientCancellationResult.acceptedWon;
      }
      return reconciled != null
          ? UrgentCabinetPatientCancellationResult.reconciled
          : UrgentCabinetPatientCancellationResult.rejected;
    }
  }

  Future<bool> withdrawAcceptedCommitment() async {
    final snapshot = _snapshot;
    final account = _accountId;
    final subject = _subject;
    if (_disposed ||
        snapshot == null ||
        account == null ||
        subject == null ||
        !canWithdraw ||
        snapshot.commitmentRevision == null) {
      return false;
    }
    if (_withdrawalRequestId != snapshot.requestId) {
      _withdrawalRequestId = snapshot.requestId;
      _withdrawalIdempotencyKey = _requireCancellationKey(
        _idempotencyKeyFactory(),
      );
    }
    final generation = _generation;
    final token = CancelToken();
    _operationalToken?.cancel('urgent-cabinet-operation-replaced');
    _operationalToken = token;
    _phase = UrgentCabinetPatientLifecyclePhase.withdrawing;
    _failure = null;
    notifyListeners();
    try {
      final result = await _repository.withdraw(
        requestId: snapshot.requestId,
        command: UrgentCabinetPatientWithdrawal(
          expectedResponseRevision: snapshot.responseRevision,
          expectedRequestRevision: snapshot.requestRevision,
          expectedJourneyRevision: snapshot.journeyRevision,
          expectedCommitmentRevision: snapshot.commitmentRevision!,
        ),
        idempotencyKey: _withdrawalIdempotencyKey!,
        cancelToken: token,
      );
      if (!_isCurrent(generation, account, subject)) return false;
      _arrivalHandoff = null;
      return _acceptSnapshot(result, generation: generation);
    } catch (error) {
      if (!_isCurrent(generation, account, subject)) return false;
      _failure = UrgentCabinetPatientRequestFailure.from(error);
      // Never infer withdrawal from a failed command. Reconcile the exact
      // request before exposing another action.
      return await _refresh(
        requestId: snapshot.requestId,
        generation: generation,
        accountId: account,
        subject: subject,
        token: CancelToken(),
      );
    } finally {
      if (identical(_operationalToken, token)) _operationalToken = null;
    }
  }

  Future<UrgentCabinetArrivalHandoff?> issueArrivalHandoff() async {
    final snapshot = _snapshot;
    final account = _accountId;
    final subject = _subject;
    if (_disposed ||
        snapshot == null ||
        account == null ||
        subject == null ||
        !canIssueArrivalHandoff ||
        snapshot.commitmentRevision == null) {
      return null;
    }
    if (_handoffRequestId != snapshot.requestId) {
      _handoffRequestId = snapshot.requestId;
      _handoffIdempotencyKey = _requireCancellationKey(
        _idempotencyKeyFactory(),
      );
    }
    final generation = _generation;
    final token = CancelToken();
    _operationalToken?.cancel('urgent-cabinet-operation-replaced');
    _operationalToken = token;
    _phase = UrgentCabinetPatientLifecyclePhase.issuingArrivalHandoff;
    _failure = null;
    notifyListeners();
    try {
      final handoff = await _repository.issueArrivalHandoff(
        requestId: snapshot.requestId,
        expectedResponseRevision: snapshot.responseRevision,
        expectedCommitmentRevision: snapshot.commitmentRevision!,
        idempotencyKey: _handoffIdempotencyKey!,
        cancelToken: token,
      );
      if (!_isCurrent(generation, account, subject) ||
          handoff.commitmentId != snapshot.commitmentId) {
        return null;
      }
      _arrivalHandoff = handoff;
      _phase = UrgentCabinetPatientLifecyclePhase.accepted;
      notifyListeners();
      return handoff;
    } catch (error) {
      if (_isCurrent(generation, account, subject)) {
        _failure = UrgentCabinetPatientRequestFailure.from(error);
        _phase = UrgentCabinetPatientLifecyclePhase.accepted;
        notifyListeners();
      }
      return null;
    } finally {
      if (identical(_operationalToken, token)) _operationalToken = null;
    }
  }

  Future<UrgentCabinetTargetedRequestSnapshot?> _reconcileAfterCancellation({
    required String requestId,
    required int generation,
    required String accountId,
    required UrgentCabinetCareSubject subject,
  }) async {
    final token = CancelToken();
    _readToken?.cancel('urgent-cabinet-cancellation-reconciliation');
    _readToken = token;
    try {
      final result = await _repository.status(requestId, cancelToken: token);
      if (!_isCurrent(generation, accountId, subject) ||
          !_acceptSnapshot(result, generation: generation)) {
        return null;
      }
      return result;
    } on UrgentCabinetPatientRequestFailure catch (failure) {
      if (_isCurrent(generation, accountId, subject)) {
        _failure = failure;
        if (failure.kind ==
            UrgentCabinetPatientRequestFailureKind.sessionRejected) {
          await invalidateSession(accountId);
          return null;
        }
        _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
        if (!_isTransientReadFailure(failure.kind)) _stopTimers();
        notifyListeners();
      }
      return null;
    } catch (error) {
      if (_isCurrent(generation, accountId, subject)) {
        _failure = UrgentCabinetPatientRequestFailure.from(error);
        _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
        _stopTimers();
        notifyListeners();
      }
      return null;
    } finally {
      if (identical(_readToken, token)) _readToken = null;
    }
  }

  void setWaitingRouteActive(bool active) {
    if (_disposed || _waitingRouteActive == active) return;
    _waitingRouteActive = active;
    if (active && (isPending || hasAcceptedJourney)) {
      _startTimers();
      if (isPending) unawaited(refresh());
    } else {
      _stopTimers();
    }
  }

  void applicationResumed() {
    if (_waitingRouteActive && isPending) {
      _startTimers();
      unawaited(refresh());
      return;
    }
    if (_snapshot?.responseStatus ==
        UrgentCabinetPatientResponseStatus.accepted) {
      unawaited(refresh());
      return;
    }
    final account = _accountId;
    final subject = _subject;
    if (_snapshot == null &&
        account != null &&
        subject != null &&
        _phase != UrgentCabinetPatientLifecyclePhase.recovering) {
      unawaited(recover(accountId: account, subject: subject));
    }
  }

  void applicationBackgrounded() {
    _stopTimers();
  }

  void networkReconnected() {
    if ((_waitingRouteActive && isPending) ||
        _snapshot?.responseStatus ==
            UrgentCabinetPatientResponseStatus.accepted) {
      unawaited(refresh());
    }
  }

  Future<bool> beginNewJourneyAfterTerminal() async {
    final account = _accountId;
    final status = _snapshot?.responseStatus;
    if (_disposed ||
        account == null ||
        (status != UrgentCabinetPatientResponseStatus.declined &&
            status != UrgentCabinetPatientResponseStatus.cancelled &&
            status != UrgentCabinetPatientResponseStatus.expired)) {
      return false;
    }
    final generation = ++_generation;
    _cancelNetwork('urgent-cabinet-new-journey');
    _stopTimers();
    try {
      await _submissionCoordinator.releaseTerminalForNewJourney(account);
    } catch (error) {
      if (_disposed || generation != _generation || account != _accountId) {
        return false;
      }
      _failure = UrgentCabinetPatientRequestFailure.from(error);
      _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
      notifyListeners();
      return false;
    }
    if (_disposed || generation != _generation || account != _accountId) {
      return false;
    }
    _snapshot = null;
    _failure = null;
    _subject = null;
    _receivedAt = null;
    _cancellationRequestId = null;
    _cancellationIdempotencyKey = null;
    _clearOperationalState();
    _phase = UrgentCabinetPatientLifecyclePhase.idle;
    notifyListeners();
    return true;
  }

  Future<void> invalidateSession(String accountId) async {
    final normalized = _requireAccount(accountId);
    _generation++;
    _cancelNetwork('urgent-cabinet-session-invalidated');
    _stopTimers();
    _waitingRouteActive = false;
    _snapshot = null;
    _failure = null;
    _accountId = null;
    _subject = null;
    _receivedAt = null;
    _cancellationRequestId = null;
    _cancellationIdempotencyKey = null;
    _clearOperationalState();
    _phase = UrgentCabinetPatientLifecyclePhase.idle;
    notifyListeners();
    await _submissionCoordinator.invalidateSession(normalized);
  }

  bool _acceptSnapshot(
    UrgentCabinetTargetedRequestSnapshot next, {
    required int generation,
  }) {
    if (_disposed ||
        generation != _generation ||
        next.careSubject != _subject) {
      return false;
    }
    final previous = _snapshot;
    if (previous != null && !_isValidSuccessor(previous, next)) {
      _failure = const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.invalidResponse,
        message: 'État CABINET incohérent avec la demande récupérée.',
      );
      _phase = UrgentCabinetPatientLifecyclePhase.unavailable;
      _stopTimers();
      notifyListeners();
      return false;
    }
    _snapshot = next;
    if (next.responseStatus != UrgentCabinetPatientResponseStatus.accepted ||
        next.arrivalVerifiedAt != null) {
      _clearOperationalState();
    }
    _receivedAt = _clock();
    _failure = null;
    _phase = _phaseFor(next);
    if (next.isTerminal) {
      _stopTimers();
    } else if (_waitingRouteActive) {
      _startTimers();
    }
    notifyListeners();
    return true;
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

  bool _isValidSuccessor(
    UrgentCabinetTargetedRequestSnapshot previous,
    UrgentCabinetTargetedRequestSnapshot next,
  ) {
    if (previous.requestId != next.requestId ||
        previous.journeyId != next.journeyId ||
        previous.careSubject != next.careSubject ||
        previous.doctorId != next.doctorId ||
        previous.practiceLocationId != next.practiceLocationId ||
        previous.quotedFeeMilliTnd != next.quotedFeeMilliTnd ||
        previous.configurationRevision != next.configurationRevision ||
        previous.runtimeRevision != next.runtimeRevision ||
        previous.practiceLocationVersion != next.practiceLocationVersion ||
        next.responseRevision < previous.responseRevision ||
        next.requestRevision < previous.requestRevision ||
        next.journeyRevision < previous.journeyRevision) {
      return false;
    }
    if (previous.isTerminal) {
      return previous.responseStatus == next.responseStatus &&
          previous.commitmentId == next.commitmentId;
    }
    return true;
  }

  void _startTimers() {
    if (!_waitingRouteActive ||
        (!isPending && !hasAcceptedJourney) ||
        _disposed) {
      return;
    }
    _pollTimer ??= Timer.periodic(_pollingInterval, (_) {
      if (_waitingRouteActive && (isPending || hasAcceptedJourney)) {
        unawaited(refresh());
      }
    });
    _deadlineTimer?.cancel();
    if (!isPending) return;
    final remaining = approximateRemainingResponseWindow ?? Duration.zero;
    _deadlineTimer = Timer(remaining + const Duration(milliseconds: 100), () {
      if (_waitingRouteActive && isPending) unawaited(refresh());
    });
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
  }

  void _cancelNetwork(String reason) {
    _readToken?.cancel(reason);
    _readToken = null;
    _cancelToken?.cancel(reason);
    _cancelToken = null;
    _operationalToken?.cancel(reason);
    _operationalToken = null;
    _refreshInFlight = null;
    _cancelInFlight = null;
  }

  bool _isCurrent(
    int generation,
    String accountId,
    UrgentCabinetCareSubject subject,
  ) =>
      !_disposed &&
      generation == _generation &&
      accountId == _accountId &&
      subject == _subject;

  bool _isCurrentAccountRecovery(int generation, String accountId) =>
      !_disposed &&
      generation == _generation &&
      accountId == _accountId &&
      _subject == null;

  static UrgentCabinetPatientLifecyclePhase _phaseFor(
    UrgentCabinetTargetedRequestSnapshot snapshot,
  ) {
    final clinical = snapshot.clinicalPhase;
    if (clinical != null) {
      return switch (clinical) {
        UrgentCabinetPatientClinicalPhase.confirmedTravelToCabinet =>
          UrgentCabinetPatientLifecyclePhase.accepted,
        UrgentCabinetPatientClinicalPhase.arrivedWaitingForDoctor =>
          UrgentCabinetPatientLifecyclePhase.arrivedWaitingForDoctor,
        UrgentCabinetPatientClinicalPhase.consultationInProgress =>
          UrgentCabinetPatientLifecyclePhase.consultationInProgress,
        UrgentCabinetPatientClinicalPhase.careCompleted =>
          UrgentCabinetPatientLifecyclePhase.careCompleted,
        // Unreachable: the repository rejects unrecognized snapshots.
        UrgentCabinetPatientClinicalPhase.unknown =>
          UrgentCabinetPatientLifecyclePhase.unavailable,
      };
    }
    return switch (snapshot.responseStatus) {
      UrgentCabinetPatientResponseStatus.pending =>
        UrgentCabinetPatientLifecyclePhase.pending,
      UrgentCabinetPatientResponseStatus.accepted =>
        UrgentCabinetPatientLifecyclePhase.accepted,
      UrgentCabinetPatientResponseStatus.declined =>
        UrgentCabinetPatientLifecyclePhase.declined,
      UrgentCabinetPatientResponseStatus.cancelled =>
        UrgentCabinetPatientLifecyclePhase.cancelled,
      UrgentCabinetPatientResponseStatus.expired =>
        UrgentCabinetPatientLifecyclePhase.expired,
      UrgentCabinetPatientResponseStatus.unknown =>
        UrgentCabinetPatientLifecyclePhase.unavailable,
    };
  }

  static bool _isTransientReadFailure(
    UrgentCabinetPatientRequestFailureKind kind,
  ) =>
      kind == UrgentCabinetPatientRequestFailureKind.timeout ||
      kind == UrgentCabinetPatientRequestFailureKind.network ||
      kind == UrgentCabinetPatientRequestFailureKind.serverUnavailable;

  void _clearOperationalState() {
    _withdrawalRequestId = null;
    _withdrawalIdempotencyKey = null;
    _handoffRequestId = null;
    _handoffIdempotencyKey = null;
    _arrivalHandoff = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _cancelNetwork('urgent-cabinet-lifecycle-disposed');
    _stopTimers();
    _submissionCoordinator.dispose();
    super.dispose();
  }
}

String _requireAccount(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError('Patient account is required.');
  return normalized;
}

String _requireCancellationKey(String value) {
  final normalized = value.trim();
  if (normalized.length < 32 || normalized.length > 128) {
    throw StateError('Invalid urgent CABINET cancellation key.');
  }
  return normalized;
}
