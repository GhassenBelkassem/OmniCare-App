import 'package:flutter/foundation.dart';

import '../emergency_symptom_intake_value.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_clinical_intake_draft.dart';
import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_doctor_list_item.dart';
import 'urgent_cabinet_request_decision_source.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_source.dart';
import 'urgent_cabinet_request_state.dart';
import 'urgent_cabinet_targeted_request_models.dart';

enum UrgentCabinetSubmitTransition { pending, failed, rejected, obsolete }

enum UrgentCabinetDecisionTransition {
  accepted,
  declined,
  unavailable,
  rejected,
  obsolete,
}

enum UrgentCabinetDoctorRetryTransition { prepared, rejected, obsolete }

enum UrgentCabinetIntakeTransition { saved, rejected, obsolete }

/// Owns the draft state for one P4 urgent CABINET journey.
///
/// Route registration creates and disposes this controller with the flow. It
/// does not initialize or delegate to any P3 booking controller.
class UrgentCabinetFlowController extends ChangeNotifier {
  UrgentCabinetFlowController({String? accountId})
    : _accountId = _normalizeAccountId(accountId);

  String? _accountId;
  UrgentCabinetCareSubject? _selectedSubject;
  String? _selectedDoctorId;
  String? _selectedCabinetId;
  UrgentCabinetClinicalIntakeDraft? _clinicalIntakeDraft;
  EmergencySymptomIntakeValue? _symptomIntakeValue;
  UrgentCabinetFeeQuote? _quoteSnapshot;
  UrgentCabinetRequestState _requestState = const UrgentCabinetRequestDraft();
  int _attemptGeneration = 0;
  final Set<String> _excludedDoctorIds = <String>{};
  bool _disposed = false;

  String? get accountId => _accountId;
  UrgentCabinetCareSubject? get selectedSubject => _selectedSubject;
  String? get selectedDoctorId => _selectedDoctorId;
  String? get selectedCabinetId => _selectedCabinetId;
  UrgentCabinetClinicalIntakeDraft? get clinicalIntakeDraft =>
      _clinicalIntakeDraft;
  EmergencySymptomIntakeValue? get symptomIntakeValue => _symptomIntakeValue;
  UrgentCabinetFeeQuote? get quoteSnapshot => _quoteSnapshot;
  bool get hasSelectedSubject => _selectedSubject != null;
  UrgentCabinetRequestState get requestState => _requestState;
  UrgentCabinetRequestPhase get requestPhase => _requestState.phase;
  UrgentCabinetRequestReview? get frozenReview => _requestState.review;
  Set<String> get excludedDoctorIds => Set.unmodifiable(_excludedDoctorIds);
  bool get isSubmitting =>
      _requestState.phase == UrgentCabinetRequestPhase.submitting;
  bool get hasActiveSimulation =>
      (_requestState is UrgentCabinetRequestSubmitting ||
          _requestState is UrgentCabinetRequestPendingDoctorResponse) &&
      (_requestState as UrgentCabinetRequestAttemptState)
          .isDevelopmentSimulation;

  bool get hasAuthoritativeRequest =>
      _requestState is UrgentCabinetRequestAttemptState &&
      (_requestState as UrgentCabinetRequestAttemptState).isAuthoritative;

  void selectSelf() {
    updateSubject(const UrgentCabinetCareSubject.self());
  }

  void selectFamilyMember(String familyMemberId) {
    updateSubject(UrgentCabinetCareSubject.familyMember(familyMemberId));
  }

  void updateSubject(UrgentCabinetCareSubject subject) {
    if (_disposed || _requestState is! UrgentCabinetRequestDraft) return;
    if (_selectedSubject == subject) return;
    _selectedSubject = subject;
    _selectedDoctorId = null;
    _selectedCabinetId = null;
    _clinicalIntakeDraft = null;
    _symptomIntakeValue = null;
    _quoteSnapshot = null;
    notifyListeners();
  }

  void selectDoctor({required String doctorId, required String cabinetId}) {
    if (_disposed || _requestState is! UrgentCabinetRequestDraft) return;
    final normalizedDoctorId = doctorId.trim();
    final normalizedCabinetId = cabinetId.trim();
    if (normalizedDoctorId.isEmpty || normalizedCabinetId.isEmpty) {
      throw ArgumentError('A P4 doctor and active cabinet ID are required.');
    }
    if (_excludedDoctorIds.contains(normalizedDoctorId)) return;
    if (_selectedDoctorId == normalizedDoctorId &&
        _selectedCabinetId == normalizedCabinetId) {
      return;
    }
    _selectedDoctorId = normalizedDoctorId;
    _selectedCabinetId = normalizedCabinetId;
    _clinicalIntakeDraft = null;
    _quoteSnapshot = null;
    notifyListeners();
  }

  bool captureQuoteSnapshot(UrgentCabinetDoctorDetail detail) {
    if (_disposed || _requestState is! UrgentCabinetRequestDraft) return false;
    final doctorId = _selectedDoctorId;
    final cabinetId = _selectedCabinetId;
    final fee = detail.urgentCabinetFeeMilliTnd;
    final configurationRevision = detail.configurationRevision;
    final runtimeRevision = detail.runtimeRevision;
    final practiceLocationVersion = detail.practiceLocationVersion;
    if (doctorId == null ||
        cabinetId == null ||
        detail.doctorId != doctorId ||
        detail.cabinetById(cabinetId) == null ||
        fee == null ||
        fee < 0 ||
        configurationRevision == null ||
        configurationRevision < 0 ||
        runtimeRevision == null ||
        runtimeRevision < 0 ||
        practiceLocationVersion == null ||
        practiceLocationVersion < 0) {
      _quoteSnapshot = null;
      notifyListeners();
      return false;
    }
    _quoteSnapshot = UrgentCabinetFeeQuote(
      doctorId: doctorId,
      cabinetId: cabinetId,
      amountMilliTnd: fee,
      currencyCode: 'TND',
      provenance: detail.isDevelopmentFixture
          ? UrgentCabinetFeeProvenance.developmentFixture
          : UrgentCabinetFeeProvenance.service,
      quotedAt: detail.evaluatedAt,
      configurationRevision: configurationRevision,
      runtimeRevision: runtimeRevision,
      practiceLocationVersion: practiceLocationVersion,
    );
    notifyListeners();
    return true;
  }

  void invalidateQuoteSnapshot() {
    if (_disposed || _quoteSnapshot == null) return;
    _quoteSnapshot = null;
    notifyListeners();
  }

  UrgentCabinetIntakeTransition saveClinicalIntake(
    UrgentCabinetClinicalIntakeDraft draft,
  ) {
    if (_disposed) return UrgentCabinetIntakeTransition.obsolete;
    if (_requestState is! UrgentCabinetRequestDraft ||
        !draft.isValid ||
        !draft.belongsTo(
          subject: _selectedSubject,
          selectedDoctorId: _selectedDoctorId,
          selectedCabinetId: _selectedCabinetId,
        ) ||
        _quoteSnapshot == null) {
      return UrgentCabinetIntakeTransition.rejected;
    }
    _clinicalIntakeDraft = draft;
    notifyListeners();
    return UrgentCabinetIntakeTransition.saved;
  }

  UrgentCabinetIntakeTransition saveSymptomIntake(
    EmergencySymptomIntakeValue value,
  ) {
    if (_disposed) return UrgentCabinetIntakeTransition.obsolete;
    final subject = _selectedSubject;
    if (_requestState is! UrgentCabinetRequestDraft || subject == null) {
      return UrgentCabinetIntakeTransition.rejected;
    }
    final validation = UrgentCabinetClinicalIntakeDraft(
      careSubject: subject,
      doctorId: 'pending-target',
      cabinetId: 'pending-target',
      rawAnatomicalRegionIds: value.rawAnatomicalRegionIds,
      painScore: value.painScore,
      shortDescription: value.shortDescription,
    );
    if (!validation.isValid) {
      return UrgentCabinetIntakeTransition.rejected;
    }
    _symptomIntakeValue = value;
    _clinicalIntakeDraft = null;
    notifyListeners();
    return UrgentCabinetIntakeTransition.saved;
  }

  UrgentCabinetIntakeTransition bindSymptomIntakeToSelectedTarget() {
    final value = _symptomIntakeValue;
    final subject = _selectedSubject;
    final doctorId = _selectedDoctorId;
    final cabinetId = _selectedCabinetId;
    if (value == null ||
        subject == null ||
        doctorId == null ||
        cabinetId == null) {
      return UrgentCabinetIntakeTransition.rejected;
    }
    return saveClinicalIntake(
      UrgentCabinetClinicalIntakeDraft.fromPresentation(
        careSubject: subject,
        doctorId: doctorId,
        cabinetId: cabinetId,
        value: value,
      ),
    );
  }

  bool get canReviewCurrentDraft {
    final intake = _clinicalIntakeDraft;
    final quote = _quoteSnapshot;
    return intake != null &&
        quote != null &&
        quote.hasCompleteAuthority &&
        intake.isValid &&
        intake.belongsTo(
          subject: _selectedSubject,
          selectedDoctorId: _selectedDoctorId,
          selectedCabinetId: _selectedCabinetId,
        ) &&
        quote.doctorId == _selectedDoctorId &&
        quote.cabinetId == _selectedCabinetId;
  }

  void invalidateFamilySubjectIfMissing(Set<String> availableMemberIds) {
    if (_disposed || _selectedSubject?.isSelf != false) return;
    final familyMemberId = _selectedSubject!.familyMemberId;
    if (familyMemberId != null && availableMemberIds.contains(familyMemberId)) {
      return;
    }
    _invalidateAttempt();
    _clearDraftSelection();
    _excludedDoctorIds.clear();
    notifyListeners();
  }

  void clearSelection() {
    if (_disposed) return;
    if (_selectedSubject == null &&
        _selectedDoctorId == null &&
        _selectedCabinetId == null &&
        _excludedDoctorIds.isEmpty) {
      return;
    }
    _invalidateAttempt();
    _clearDraftSelection();
    _excludedDoctorIds.clear();
    notifyListeners();
  }

  /// Starts one static P4 submission attempt.
  ///
  /// The submitting state is published before the source is invoked. Further
  /// calls are rejected until the attempt is explicitly reset, so rapid taps
  /// can never create multiple source calls.
  Future<UrgentCabinetSubmitTransition> submitReview({
    required UrgentCabinetRequestReview review,
    required UrgentCabinetRequestSource source,
    DateTime? now,
  }) {
    if (_disposed ||
        _requestState is! UrgentCabinetRequestDraft ||
        !_isCurrentValidReview(review, source, now ?? DateTime.now())) {
      return SynchronousFuture(UrgentCabinetSubmitTransition.rejected);
    }

    final generation = ++_attemptGeneration;
    _requestState = UrgentCabinetRequestSubmitting(
      review: review,
      localAttemptGeneration: generation,
      isDevelopmentSimulation: source.isDevelopmentFixture,
    );
    notifyListeners();

    return _completeSubmission(
      review: review,
      source: source,
      generation: generation,
    );
  }

  Future<UrgentCabinetSubmitTransition> _completeSubmission({
    required UrgentCabinetRequestReview review,
    required UrgentCabinetRequestSource source,
    required int generation,
  }) async {
    UrgentCabinetSubmissionOutcome outcome;
    try {
      outcome = await source.submit(review);
    } catch (_) {
      outcome = const UrgentCabinetSubmissionRejected(
        kind: UrgentCabinetSubmissionFailureKind.unknownOutcome,
        message:
            "Le résultat de cette tentative locale ne peut pas être vérifié. N'envoyez pas une nouvelle demande.",
      );
    }

    if (_disposed ||
        generation != _attemptGeneration ||
        _requestState is! UrgentCabinetRequestSubmitting) {
      return UrgentCabinetSubmitTransition.obsolete;
    }

    switch (outcome) {
      case UrgentCabinetSubmissionAcknowledged():
        _requestState = UrgentCabinetRequestPendingDoctorResponse(
          review: review,
          localAttemptGeneration: generation,
          isDevelopmentSimulation: source.isDevelopmentFixture,
        );
        notifyListeners();
        return UrgentCabinetSubmitTransition.pending;
      case UrgentCabinetSubmissionRejected(:final kind, :final message):
        _requestState = UrgentCabinetRequestSubmissionFailed(
          review: review,
          localAttemptGeneration: generation,
          isDevelopmentSimulation: source.isDevelopmentFixture,
          kind: kind,
          message: message,
        );
        notifyListeners();
        return UrgentCabinetSubmitTransition.failed;
    }
  }

  /// Applies one identity-bound decision to the currently pending attempt.
  ///
  UrgentCabinetDecisionTransition applyDoctorDecision(
    UrgentCabinetDoctorDecisionEvent event, {
    bool developmentAcceptanceAuthorized = false,
  }) {
    if (_disposed) return UrgentCabinetDecisionTransition.obsolete;
    final current = _requestState;
    if (current is! UrgentCabinetRequestPendingDoctorResponse) {
      return UrgentCabinetDecisionTransition.rejected;
    }

    final eventAccountId = _normalizeAccountId(event.accountId);
    final doctorId = event.doctorId.trim();
    final cabinetId = event.cabinetId.trim();
    final review = current.review;
    if (_accountId == null ||
        eventAccountId != _accountId ||
        event.localAttemptGeneration != _attemptGeneration ||
        event.localAttemptGeneration != current.localAttemptGeneration ||
        doctorId != review.doctorId ||
        cabinetId != review.cabinetId ||
        doctorId != _selectedDoctorId ||
        cabinetId != _selectedCabinetId ||
        event.isDevelopmentFixture != current.isDevelopmentSimulation ||
        (event.type == UrgentCabinetDoctorDecisionType.accepted &&
            (!developmentAcceptanceAuthorized ||
                !current.isDevelopmentSimulation ||
                !event.isDevelopmentFixture))) {
      return UrgentCabinetDecisionTransition.rejected;
    }

    switch (event.type) {
      case UrgentCabinetDoctorDecisionType.accepted:
        _requestState = UrgentCabinetRequestAccepted(
          review: review,
          localAttemptGeneration: current.localAttemptGeneration,
          isDevelopmentSimulation: current.isDevelopmentSimulation,
        );
        notifyListeners();
        return UrgentCabinetDecisionTransition.accepted;
      case UrgentCabinetDoctorDecisionType.declined:
        _requestState = UrgentCabinetRequestDeclined(
          review: review,
          localAttemptGeneration: current.localAttemptGeneration,
          isDevelopmentSimulation: current.isDevelopmentSimulation,
        );
        notifyListeners();
        return UrgentCabinetDecisionTransition.declined;
      case UrgentCabinetDoctorDecisionType.unavailable:
        _requestState = UrgentCabinetRequestUnavailable(
          review: review,
          localAttemptGeneration: current.localAttemptGeneration,
          isDevelopmentSimulation: current.isDevelopmentSimulation,
        );
        notifyListeners();
        return UrgentCabinetDecisionTransition.unavailable;
    }
  }

  /// Applies a strictly parsed backend snapshot to the existing frozen
  /// presentation. No local timer or decision source can call this method.
  bool applyAuthoritativeSnapshot({
    required UrgentCabinetTargetedRequestSnapshot snapshot,
    required String patientDisplayName,
  }) {
    if (_disposed || _accountId == null) return false;
    final current = _requestState;
    final currentSnapshot = current is UrgentCabinetRequestAttemptState
        ? current.authoritativeSnapshot
        : null;
    if (currentSnapshot != null &&
        (currentSnapshot.requestId != snapshot.requestId ||
            currentSnapshot.journeyId != snapshot.journeyId ||
            currentSnapshot.careSubject != snapshot.careSubject ||
            currentSnapshot.doctorId != snapshot.doctorId ||
            currentSnapshot.practiceLocationId !=
                snapshot.practiceLocationId)) {
      return false;
    }
    if (_selectedSubject != null && _selectedSubject != snapshot.careSubject) {
      return false;
    }

    final review = UrgentCabinetRequestReview.authoritative(
      careSubject: snapshot.careSubject,
      patientDisplayName: patientDisplayName,
      doctorId: snapshot.doctorId,
      doctorDisplayName: snapshot.doctorDisplayName,
      specialty: snapshot.specialty,
      cabinetId: snapshot.practiceLocationId,
      cabinetName: snapshot.cabinetName,
      cabinetCity: snapshot.city,
      cabinetGovernorate: snapshot.governorate,
      cabinetAddress: snapshot.cabinetAddress,
      cabinetLatitude: snapshot.cabinetLatitude,
      cabinetLongitude: snapshot.cabinetLongitude,
      amountMilliTnd: snapshot.quotedFeeMilliTnd,
      evaluatedAt: snapshot.evaluatedAt,
      configurationRevision: snapshot.configurationRevision,
      runtimeRevision: snapshot.runtimeRevision,
      practiceLocationVersion: snapshot.practiceLocationVersion,
    );
    if (currentSnapshot == null) _attemptGeneration++;
    _selectedSubject = snapshot.careSubject;
    _selectedDoctorId = snapshot.doctorId;
    _selectedCabinetId = snapshot.practiceLocationId;
    _quoteSnapshot = review.feeQuote;
    if (_clinicalIntakeDraft != null &&
        !_clinicalIntakeDraft!.belongsTo(
          subject: snapshot.careSubject,
          selectedDoctorId: snapshot.doctorId,
          selectedCabinetId: snapshot.practiceLocationId,
        )) {
      _clinicalIntakeDraft = null;
    }
    _requestState = switch (snapshot.responseStatus) {
      UrgentCabinetPatientResponseStatus.pending =>
        UrgentCabinetRequestPendingDoctorResponse(
          review: review,
          localAttemptGeneration: _attemptGeneration,
          isDevelopmentSimulation: false,
          authoritativeSnapshot: snapshot,
        ),
      UrgentCabinetPatientResponseStatus.accepted =>
        UrgentCabinetRequestAccepted(
          review: review,
          localAttemptGeneration: _attemptGeneration,
          isDevelopmentSimulation: false,
          authoritativeSnapshot: snapshot,
        ),
      UrgentCabinetPatientResponseStatus.declined =>
        UrgentCabinetRequestDeclined(
          review: review,
          localAttemptGeneration: _attemptGeneration,
          isDevelopmentSimulation: false,
          authoritativeSnapshot: snapshot,
        ),
      UrgentCabinetPatientResponseStatus.cancelled =>
        UrgentCabinetRequestCancelled(
          review: review,
          localAttemptGeneration: _attemptGeneration,
          isDevelopmentSimulation: false,
          authoritativeSnapshot: snapshot,
        ),
      UrgentCabinetPatientResponseStatus.expired => UrgentCabinetRequestExpired(
        review: review,
        localAttemptGeneration: _attemptGeneration,
        isDevelopmentSimulation: false,
        authoritativeSnapshot: snapshot,
      ),
      // Unreachable: the repository rejects unrecognized snapshots.
      UrgentCabinetPatientResponseStatus.unknown =>
        const UrgentCabinetRequestAuthorityUnavailable(
          message: 'Réponse CABINET incompatible avec cette application.',
        ),
    };
    notifyListeners();
    return true;
  }

  void markAuthoritativeUnavailable(String message) {
    if (_disposed) return;
    final current = _requestState;
    if (current is! UrgentCabinetRequestAttemptState ||
        !current.isAuthoritative) {
      return;
    }
    _requestState = UrgentCabinetRequestSubmissionFailed(
      review: current.review,
      localAttemptGeneration: current.localAttemptGeneration,
      isDevelopmentSimulation: false,
      authoritativeSnapshot: current.authoritativeSnapshot,
      kind: UrgentCabinetSubmissionFailureKind.unknownOutcome,
      message: message,
    );
    notifyListeners();
  }

  void markAuthorityRecoveryUnavailable(String message) {
    if (_disposed || _requestState is UrgentCabinetRequestAttemptState) return;
    _requestState = UrgentCabinetRequestAuthorityUnavailable(message: message);
    notifyListeners();
  }

  /// Discards one terminal doctor attempt while retaining its care subject.
  UrgentCabinetDoctorRetryTransition prepareDoctorRetry() {
    if (_disposed) return UrgentCabinetDoctorRetryTransition.obsolete;
    final current = _requestState;
    if (current is! UrgentCabinetRequestDeclined &&
        current is! UrgentCabinetRequestUnavailable &&
        current is! UrgentCabinetRequestCancelled &&
        current is! UrgentCabinetRequestExpired) {
      return UrgentCabinetDoctorRetryTransition.rejected;
    }

    final attempt = current as UrgentCabinetRequestAttemptState;
    final review = attempt.review;
    if (attempt.localAttemptGeneration != _attemptGeneration ||
        _selectedSubject != review.careSubject ||
        _selectedDoctorId != review.doctorId ||
        _selectedCabinetId != review.cabinetId) {
      return UrgentCabinetDoctorRetryTransition.rejected;
    }

    _excludedDoctorIds.add(review.doctorId);
    _invalidateAttempt();
    _selectedDoctorId = null;
    _selectedCabinetId = null;
    notifyListeners();
    return UrgentCabinetDoctorRetryTransition.prepared;
  }

  bool _isCurrentValidReview(
    UrgentCabinetRequestReview review,
    UrgentCabinetRequestSource source,
    DateTime now,
  ) {
    final fee = review.feeQuote;
    return _selectedSubject == review.careSubject &&
        _selectedDoctorId == review.doctorId &&
        _selectedCabinetId == review.cabinetId &&
        review.patientDisplayName.trim().isNotEmpty &&
        review.doctorDisplayName.trim().isNotEmpty &&
        review.cabinetName.trim().isNotEmpty &&
        review.eligibility == UrgentCabinetEligibility.eligible &&
        review.availability == UrgentCabinetAvailability.availableNow &&
        fee.doctorId == review.doctorId &&
        fee.cabinetId == review.cabinetId &&
        fee.isStructurallyValid() &&
        !fee.isExpiredAt(now) &&
        review.isDevelopmentFixture == fee.isDevelopmentFixture &&
        (!review.isDevelopmentFixture || source.isDevelopmentFixture);
  }

  /// Starts a genuinely new urgent CABINET draft.
  void beginNewJourney({String? accountId}) {
    if (_disposed) return;
    final nextAccountId = _normalizeAccountId(accountId);
    final changed =
        _accountId != nextAccountId ||
        _selectedSubject != null ||
        _selectedDoctorId != null ||
        _selectedCabinetId != null ||
        _requestState is! UrgentCabinetRequestDraft ||
        _excludedDoctorIds.isNotEmpty;
    _accountId = nextAccountId;
    _invalidateAttempt();
    _clearDraftSelection();
    _excludedDoctorIds.clear();
    if (changed) notifyListeners();
  }

  /// Clears the draft if the authenticated patient changes while it is alive.
  void ensureAccount(String? accountId) {
    if (_disposed) return;
    final nextAccountId = _normalizeAccountId(accountId);
    if (_accountId == nextAccountId) return;
    _accountId = nextAccountId;
    _invalidateAttempt();
    _clearDraftSelection();
    _excludedDoctorIds.clear();
    notifyListeners();
  }

  /// Ends only the local development simulation and clears this P4 journey.
  /// It is not a medical-request cancellation operation.
  void endDevelopmentSimulation() {
    if (_disposed) return;
    final current = _requestState;
    if (current is UrgentCabinetRequestAttemptState &&
        !current.isDevelopmentSimulation) {
      return;
    }
    _invalidateAttempt();
    _clearDraftSelection();
    _excludedDoctorIds.clear();
    notifyListeners();
  }

  void clearAuthoritativeSession() {
    if (_disposed) return;
    _invalidateAttempt();
    _clearDraftSelection();
    _excludedDoctorIds.clear();
    notifyListeners();
  }

  void _invalidateAttempt() {
    _attemptGeneration++;
    _requestState = const UrgentCabinetRequestDraft();
  }

  void _clearDraftSelection() {
    _selectedSubject = null;
    _selectedDoctorId = null;
    _selectedCabinetId = null;
    _clinicalIntakeDraft = null;
    _symptomIntakeValue = null;
    _quoteSnapshot = null;
  }

  static String? _normalizeAccountId(String? accountId) {
    final normalized = accountId?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
