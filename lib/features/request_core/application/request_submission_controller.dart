import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/family_models.dart';
import '../data/request_failure.dart';
import '../data/request_models.dart';
import '../data/request_repository.dart';
import '../domain/clinic_request_intent.dart';
import '../domain/pickup_location.dart';
import '../domain/request_subject.dart';
import '../domain/request_vocabulary.dart';
import '../identity/in_flight_request_store.dart';
import '../identity/request_operation_id.dart';

/// Lifecycle of the one submission the controller currently owns.
enum RequestSubmissionStatus {
  /// No logical request has been started.
  idle,

  /// A request exists and is being described. Not sent yet.
  draft,

  /// A call is in flight.
  submitting,

  /// The server created (`201`) or replayed (`200`) the request.
  succeeded,

  /// The last attempt failed. See [RequestSubmissionController.failure] for
  /// whether retrying the same operation id is allowed.
  failed,
}

/// Owns exactly one logical CLINIC submission.
///
/// Modelled on `ClinicContextController` and reusing its proven mechanics: a
/// generation counter, a `CancelToken` per operation, a stale-response guard, a
/// disposed guard and single-flight protection.
///
/// # Why the operation id lives here
///
/// The operation id is not a per-call detail, it is the identity of the whole
/// submission the patient is trying to make. Keeping it in the controller (and
/// mirrored in secure storage) is what makes "press retry" safe: the same id
/// goes out every time, so a request that already landed is replayed rather
/// than duplicated.
///
/// # What it never does
///
/// It does not extend, wrap or consult `ReservationProvider`, it does not fetch
/// the request list after a submit, it does not poll, and it does not fabricate
/// success. It also holds no medical data — the whole intent is a clinic id and
/// a subject.
class RequestSubmissionController extends ChangeNotifier {
  RequestSubmissionController({
    required RequestRepository repository,
    InFlightRequestStore? inFlightStore,
    RequestOperationIdFactory operationIdFactory =
        const SecureRequestOperationIdFactory(),
  }) : _repository = repository,
       _inFlightStore = inFlightStore ?? InFlightRequestStore(),
       _operationIdFactory = operationIdFactory;

  final RequestRepository _repository;
  final InFlightRequestStore _inFlightStore;
  final RequestOperationIdFactory _operationIdFactory;

  RequestOperationId? _operationId;
  String? _clinicId;
  RequestSubject _subject = const RequestSubject.self();
  RequestSituation? _situation;
  PickupLocationSelection? _pickup;
  RequestSubmissionStatus _status = RequestSubmissionStatus.idle;
  RequestFailure? _failure;
  SubmitClinicRequestResult? _result;

  /// True once this operation id has actually been sent. Until then, changing
  /// the intent is free; afterwards it forces a new operation id.
  bool _attempted = false;

  int _generation = 0;
  CancelToken? _inFlightToken;
  bool _disposed = false;

  RequestSubmissionStatus get status => _status;
  RequestFailure? get failure => _failure;
  SubmitClinicRequestResult? get result => _result;
  bool get isSubmitting => _status == RequestSubmissionStatus.submitting;
  bool get hasSucceeded => _status == RequestSubmissionStatus.succeeded;
  RequestSubject get subject => _subject;
  String? get selectedClinicId => _clinicId;

  /// The patient-selected operational situation, or `null` until chosen.
  RequestSituation? get selectedSituation => _situation;

  /// The frozen, confirmed ambulance pickup, or `null` before selection.
  PickupLocationSelection? get selectedPickup => _pickup;

  /// Exposed for tests and for the future resume UI. Never rendered.
  RequestOperationId? get operationId => _operationId;

  /// The typed intent, or `null` until the request is fully described.
  ///
  /// [situation] is required; for an [RequestSituation.ambulance] situation the
  /// confirmed [pickupLocation] is required too. Until both are present the
  /// intent is `null`, so [canSubmit] is `false` and the wire never sees a
  /// half-described request.
  ClinicRequestIntent? get intent {
    final clinicId = _clinicId;
    final situation = _situation;
    if (clinicId == null || situation == null) return null;
    if (situation == RequestSituation.ambulance && _pickup == null) {
      return null;
    }
    return ClinicRequestIntent(
      clinicId: clinicId,
      subject: _subject,
      situation: situation,
      pickupLocation: _pickup,
    );
  }

  bool get canSubmit =>
      intent != null &&
      _status != RequestSubmissionStatus.submitting &&
      _status != RequestSubmissionStatus.succeeded;

  /// True when the last failure may be retried with the same operation id.
  bool get canRetry =>
      _status == RequestSubmissionStatus.failed &&
      (_failure?.retryable ?? false);

  /// Starts a new logical request and mints a new operation id.
  ///
  /// Any previous operation — including one that ended in an idempotency
  /// conflict — is abandoned here, explicitly, never implicitly.
  Future<void> beginNewRequest({
    RequestSubject subject = const RequestSubject.self(),
    String? clinicId,
  }) async {
    _beginOperation();
    _operationId = _operationIdFactory.next();
    final target = clinicId?.trim();
    _clinicId = (target == null || target.isEmpty) ? null : target;
    _subject = subject;
    _situation = null;
    _pickup = null;
    _status = RequestSubmissionStatus.draft;
    _failure = null;
    _result = null;
    _attempted = false;
    _notify();
    await _inFlightStore.clear();
  }

  /// Sets or changes the target clinic.
  ///
  /// The clinic id must come from the (future) patient clinic directory API.
  /// Nothing in this module invents, hardcodes or infers one.
  void selectClinic(String clinicId) {
    final id = clinicId.trim();
    if (id.isEmpty || id == _clinicId) return;
    _updateIntent(() => _clinicId = id);
  }

  /// Sends the request for the account holder.
  void selectSelfSubject() {
    if (_subject.isSelf) return;
    _updateIntent(() => _subject = const RequestSubject.self());
  }

  /// Sends the request for an owned family member.
  ///
  /// Only `FamilyMember.id` is used. `patientId`, `mrsPatientId` and
  /// `accountHolderId` are never read here, and the backend re-resolves
  /// ownership regardless of what the client claims.
  void selectFamilyMemberSubject(FamilyMember member) {
    final next = RequestSubject.forFamilyMember(member);
    if (next == _subject) return;
    _updateIntent(() => _subject = next);
  }

  /// Sets the patient-chosen operational situation.
  ///
  /// The situation is always explicit; it is never inferred. Changing away
  /// from [RequestSituation.ambulance] drops any previously confirmed pickup,
  /// because an appointment or urgent request must not carry coordinates.
  void selectSituation(RequestSituation situation) {
    if (_situation == situation) return;
    _updateIntent(() {
      _situation = situation;
      if (situation != RequestSituation.ambulance) _pickup = null;
    });
  }

  /// Records the frozen, patient-confirmed ambulance pickup.
  ///
  /// Once set it is reused verbatim on every retry, so a resend never
  /// reacquires GPS or drifts the coordinates. Replacing it after the first
  /// attempt rotates the operation id.
  void setPickupLocation(PickupLocationSelection pickup) {
    if (_pickup == pickup) return;
    _updateIntent(() => _pickup = pickup);
  }

  /// Removes a confirmed pickup (e.g. when backing out of the ambulance step).
  void clearPickupLocation() {
    if (_pickup == null) return;
    _updateIntent(() => _pickup = null);
  }

  /// Submits, or retries, the current logical request.
  ///
  /// The same operation id is used for every attempt, so a timeout, a dropped
  /// connection or a 401-refresh-retry can never produce a second request.
  Future<void> submit() async {
    if (_disposed) return;
    // Single-flight: a double tap must not open a second call.
    if (_status == RequestSubmissionStatus.submitting) return;
    // A finished submission is not resubmitted; the caller starts a new one.
    if (_status == RequestSubmissionStatus.succeeded) return;

    final operationId = _operationId;
    final intent = this.intent;
    if (operationId == null || intent == null) {
      _failure = RequestFailure.intentIncomplete;
      _status = RequestSubmissionStatus.failed;
      _notify();
      return;
    }

    final generation = _beginOperation();
    _attempted = true;
    _status = RequestSubmissionStatus.submitting;
    _failure = null;
    _notify();

    // Persisted *before* the call: if the process dies mid-flight, the next
    // launch can retry this exact operation instead of creating a duplicate.
    await _inFlightStore.save(
      InFlightRequestOperation(operationId: operationId, intent: intent),
    );
    if (generation != _generation) return;

    try {
      final result = await _repository.submitClinicRequest(
        requestId: operationId,
        intent: intent,
        cancelToken: _inFlightToken,
      );
      if (generation != _generation) return;

      // The response is captured before the persisted intent is dropped, so a
      // crash between the two leaves a retryable record rather than nothing.
      _result = result;
      _failure = null;
      _status = RequestSubmissionStatus.succeeded;
      _notify();
      await _inFlightStore.clear();
    } catch (error) {
      final failure = RequestFailure.from(error);
      if (generation != _generation) return;

      _failure = failure;
      _status = RequestSubmissionStatus.failed;
      _notify();

      // A retryable failure keeps the record: the same id must go out again.
      // A terminal one drops it, so no later resume can reuse a burned id.
      if (!failure.retryable) {
        await _inFlightStore.clear();
      }
    }
  }

  /// Retries the current operation with the same id.
  ///
  /// Refuses when the failure is not retryable — in particular after
  /// `REQUEST_IDEMPOTENCY_CONFLICT`, where the only correct move is an
  /// explicit [beginNewRequest].
  Future<void> retry() async {
    if (!canRetry) return;
    await submit();
  }

  /// Restores an operation that was in flight when the process died.
  ///
  /// Returns `true` when a usable operation was restored. It only restores
  /// state; it never submits by itself, and it is never called from `build()`.
  Future<bool> restoreInFlightOperation() async {
    if (_disposed) return false;
    if (_status == RequestSubmissionStatus.submitting) return false;

    final stored = await _inFlightStore.read();
    if (_disposed || stored == null) return false;

    _beginOperation();
    _operationId = stored.operationId;
    _clinicId = stored.intent.clinicId;
    _subject = stored.intent.subject;
    _situation = stored.intent.situation;
    _pickup = stored.intent.pickupLocation;
    _result = null;
    // Presented as a retryable failure so the UI offers "try again" rather
    // than silently re-sending something the patient may no longer want.
    _failure = RequestFailure.interrupted;
    _status = RequestSubmissionStatus.failed;
    _attempted = true;
    _notify();
    return true;
  }

  /// Clears every trace of this patient's submission.
  ///
  /// Called on logout and on session invalidation: in-memory operation,
  /// `CancelToken`, pending state and the persisted in-flight record all go.
  /// Nothing about one patient's request may survive into another session.
  Future<void> clear() async {
    _beginOperation();
    _operationId = null;
    _clinicId = null;
    _subject = const RequestSubject.self();
    _situation = null;
    _pickup = null;
    _status = RequestSubmissionStatus.idle;
    _failure = null;
    _result = null;
    _attempted = false;
    _notify();
    await _inFlightStore.clear();
  }

  /// Applies an intent change.
  ///
  /// If the current operation id has already been sent, the change makes this
  /// a *different* logical submission, so the id is rotated. Reusing it would
  /// earn a `REQUEST_IDEMPOTENCY_CONFLICT` if the first attempt actually
  /// landed — and, worse, would leave the patient believing the new intent had
  /// been recorded.
  void _updateIntent(VoidCallback mutate) {
    if (_status == RequestSubmissionStatus.submitting) return;
    if (_status == RequestSubmissionStatus.succeeded) return;

    mutate();

    if (_attempted) {
      _beginOperation();
      _operationId = _operationIdFactory.next();
      _attempted = false;
      _result = null;
      // Fire-and-forget: the stale record describes an abandoned operation and
      // its removal must not block the UI.
      unawaited(_inFlightStore.clear());
    }

    _failure = null;
    if (_operationId != null) _status = RequestSubmissionStatus.draft;
    _notify();
  }

  /// Invalidates every in-flight response and cancels the outstanding call.
  int _beginOperation() {
    _generation++;
    final previous = _inFlightToken;
    if (previous != null && !previous.isCancelled) {
      previous.cancel('request-submission-superseded');
    }
    _inFlightToken = CancelToken();
    return _generation;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final token = _inFlightToken;
    if (token != null && !token.isCancelled) {
      token.cancel('request-submission-disposed');
    }
    super.dispose();
  }
}
