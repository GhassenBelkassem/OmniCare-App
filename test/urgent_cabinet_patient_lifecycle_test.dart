import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/features/auth/application/auth_controller.dart';
import 'package:omnicare_mobile/features/auth/application/auth_flow_models.dart';
import 'package:omnicare_mobile/features/auth/application/post_auth_navigation.dart';
import 'package:omnicare_mobile/features/auth/data/auth_repository.dart';
import 'package:omnicare_mobile/features/auth/data/models/auth_dtos.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_arrival_instructions_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_clinical_intake_draft.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_patient_lifecycle_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_accepted_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_decision_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_submission_activation_gate.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_submission_coordinator.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_repository.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

const _accountId = 'patient-account';
const _doctorId = '11111111-1111-4111-8111-111111111111';
const _cabinetId = '22222222-2222-4222-8222-222222222222';
const _requestId = '33333333-3333-4333-8333-333333333333';
const _journeyId = '44444444-4444-4444-8444-444444444444';
const _commitmentId = '55555555-5555-4555-8555-555555555555';
const _cancelKey = '66666666-6666-4666-8666-666666666666';
const _familyId = '88888888-8888-4888-8888-888888888888';
const _authoritativeAbsence = UrgentCabinetPatientRequestFailure(
  kind: UrgentCabinetPatientRequestFailureKind.notFound,
  message: 'missing',
  code: 'URGENT_CABINET_REQUEST_NOT_FOUND',
  statusCode: 404,
);

Map<String, Object?> _snapshotJson({
  String status = 'PENDING',
  String state = 'CABINET_PENDING',
  String requestId = _requestId,
  int responseRevision = 2,
  int requestRevision = 3,
  int journeyRevision = 4,
  bool replayed = false,
  String subjectType = 'SELF',
  String? familyMemberId,
  List<String>? allowedActions,
  String? arrivalVerifiedAt,
  bool withdrawnAfterAcceptance = false,
  int commitmentRevision = 1,
}) {
  final accepted = status == 'ACCEPTED';
  final declined = status == 'DECLINED';
  final cancelled = status == 'CANCELLED';
  final expired = status == 'EXPIRED';
  final terminal = accepted || declined || cancelled || expired;
  return <String, Object?>{
    'requestId': requestId,
    'journeyId': _journeyId,
    'subjectType': subjectType,
    'familyMemberId': familyMemberId,
    'doctorId': _doctorId,
    'practiceLocationId': _cabinetId,
    'doctorDisplayName': 'Dr Synthétique',
    'specialty': 'Médecine générale',
    'cabinetName': 'Cabinet synthétique',
    'cabinetAddress': '1 rue synthétique',
    'governorate': 'Tunis',
    'city': 'Tunis',
    'quotedFeeTnd': 75.000,
    'currency': 'TND',
    'configurationRevision': 7,
    'runtimeRevision': 8,
    'practiceLocationVersion': 9,
    'responseStatus': status,
    'responseRevision': responseRevision,
    'respondedAt': accepted || declined || withdrawnAfterAcceptance
        ? '2026-10-18T10:02:00Z'
        : null,
    'commitmentId': accepted || withdrawnAfterAcceptance ? _commitmentId : null,
    'commitmentStatus': accepted
        ? 'ACTIVE'
        : withdrawnAfterAcceptance
        ? 'CANCELLED'
        : null,
    'commitmentRevision': accepted || withdrawnAfterAcceptance
        ? commitmentRevision
        : null,
    'committedAt': accepted || withdrawnAfterAcceptance
        ? '2026-10-18T10:02:00Z'
        : null,
    'arrivalVerifiedAt': arrivalVerifiedAt,
    'state': state,
    'requestRevision': requestRevision,
    'journeyRevision': journeyRevision,
    'createdAt': '2026-10-18T10:00:00Z',
    'responseDeadlineAt': '2026-10-18T10:05:00Z',
    'terminalAt': terminal ? '2026-10-18T10:02:00Z' : null,
    'terminalReason': withdrawnAfterAcceptance
        ? 'PATIENT_WITHDREW_AFTER_ACCEPTANCE'
        : declined
        ? 'DOCTOR_DECLINED'
        : cancelled
        ? 'PATIENT_CANCELLED'
        : expired
        ? 'RESPONSE_DEADLINE_ELAPSED'
        : null,
    'allowedActions':
        allowedActions ??
        (status == 'PENDING' ? <String>['CANCEL'] : <String>[]),
    'replayed': replayed,
    'evaluatedAt': '2026-10-18T10:00:30Z',
  };
}

UrgentCabinetTargetedRequestSnapshot _snapshot({
  String status = 'PENDING',
  String state = 'CABINET_PENDING',
  String requestId = _requestId,
  int responseRevision = 2,
  int requestRevision = 3,
  int journeyRevision = 4,
  bool replayed = false,
  String subjectType = 'SELF',
  String? familyMemberId,
  List<String>? allowedActions,
  String? arrivalVerifiedAt,
  bool withdrawnAfterAcceptance = false,
  int commitmentRevision = 1,
}) => UrgentCabinetTargetedRequestSnapshot.fromJson(
  _snapshotJson(
    status: status,
    state: state,
    requestId: requestId,
    responseRevision: responseRevision,
    requestRevision: requestRevision,
    journeyRevision: journeyRevision,
    replayed: replayed,
    subjectType: subjectType,
    familyMemberId: familyMemberId,
    allowedActions: allowedActions,
    arrivalVerifiedAt: arrivalVerifiedAt,
    withdrawnAfterAcceptance: withdrawnAfterAcceptance,
    commitmentRevision: commitmentRevision,
  ),
);

final class _MemoryReceiptStore implements UrgentCabinetRecoveryReceiptStore {
  UrgentCabinetRecoveryReceipt? receipt;
  int clears = 0;

  @override
  Future<void> clearForAccount(String accountId) async {
    if (receipt?.accountId == accountId) receipt = null;
    clears++;
  }

  @override
  Future<UrgentCabinetRecoveryReceipt?> readForAccount(String accountId) async {
    return receipt?.accountId == accountId ? receipt : null;
  }

  @override
  Future<void> save(UrgentCabinetRecoveryReceipt receipt) async {
    this.receipt = receipt;
  }
}

final class _FakeRepository implements UrgentCabinetTargetedRequestRepository {
  Future<UrgentCabinetTargetedRequestSnapshot> Function(
    UrgentCabinetTargetedSubmission submission,
    String key,
  )?
  onSubmit;
  Future<UrgentCabinetTargetedRequestSnapshot> Function(String requestId)?
  onStatus;
  Future<UrgentCabinetTargetedRequestSnapshot> Function(String key)? onRecover;
  Future<UrgentCabinetTargetedRequestSnapshot> Function(
    UrgentCabinetCareSubject subject,
  )?
  onActive;
  Future<UrgentCabinetTargetedRequestSnapshot> Function(
    String requestId,
    UrgentCabinetPatientCancellation command,
    String key,
  )?
  onCancel;
  Future<UrgentCabinetTargetedRequestSnapshot> Function(
    String requestId,
    UrgentCabinetPatientWithdrawal command,
    String key,
  )?
  onWithdraw;
  Future<UrgentCabinetArrivalHandoff> Function(
    String requestId,
    int responseRevision,
    int commitmentRevision,
    String key,
  )?
  onIssueHandoff;

  int statusCalls = 0;
  int recoverCalls = 0;
  int activeCalls = 0;
  int cancelCalls = 0;
  int submitCalls = 0;
  int withdrawalCalls = 0;
  int handoffCalls = 0;
  UrgentCabinetPatientCancellation? lastCancellation;
  String? lastCancellationKey;
  UrgentCabinetPatientWithdrawal? lastWithdrawal;
  String? lastWithdrawalKey;
  String? lastHandoffKey;

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> active(
    UrgentCabinetCareSubject subject, {
    CancelToken? cancelToken,
  }) {
    activeCalls++;
    return onActive!(subject);
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> cancel({
    required String requestId,
    required UrgentCabinetPatientCancellation command,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    cancelCalls++;
    lastCancellation = command;
    lastCancellationKey = idempotencyKey;
    return onCancel!(requestId, command, idempotencyKey);
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> withdraw({
    required String requestId,
    required UrgentCabinetPatientWithdrawal command,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    withdrawalCalls++;
    lastWithdrawal = command;
    lastWithdrawalKey = idempotencyKey;
    return onWithdraw!(requestId, command, idempotencyKey);
  }

  @override
  Future<UrgentCabinetArrivalHandoff> issueArrivalHandoff({
    required String requestId,
    required int expectedResponseRevision,
    required int expectedCommitmentRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    handoffCalls++;
    lastHandoffKey = idempotencyKey;
    return onIssueHandoff!(
      requestId,
      expectedResponseRevision,
      expectedCommitmentRevision,
      idempotencyKey,
    );
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> recover(
    String idempotencyKey, {
    CancelToken? cancelToken,
  }) {
    recoverCalls++;
    return onRecover!(idempotencyKey);
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> status(
    String requestId, {
    CancelToken? cancelToken,
  }) {
    statusCalls++;
    return onStatus!(requestId);
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> submit({
    required UrgentCabinetTargetedSubmission submission,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    submitCalls++;
    return onSubmit!(submission, idempotencyKey);
  }
}

final class _RestoredPatientAuthRepository implements AuthRepositoryContract {
  const _RestoredPatientAuthRepository();

  @override
  Future<AuthenticatedPatientSession?> restoreSession() async =>
      const AuthenticatedPatientSession(
        user: CurrentUserDto(
          id: _accountId,
          role: 'PATIENT',
          sessionId: 'patient-session',
          mustChangePassword: false,
        ),
        profile: PatientProfile(
          userId: _accountId,
          firstName: 'Sarah',
          lastName: 'Martin',
          displayName: 'Sarah Martin',
          dateOfBirth: null,
          gender: null,
          photoUrl: null,
          primaryPhone: null,
          primaryEmail: null,
          onboardingCompleted: true,
          onboardingStep: 4,
          preferredLanguage: 'fr',
          notifications: ProfileNotificationPreferences(
            medications: true,
            appointments: true,
            passport: true,
          ),
          updatedAt: null,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _EmptyFamilyRepository extends FamilyRepository {
  _EmptyFamilyRepository() : super(api: FamilyApi());

  @override
  Future<List<FamilyMember>> getFamilyMembers() async => const [];
}

UrgentCabinetTargetedSubmissionValidation _validSubmission() =>
    prepareUrgentCabinetTargetedSubmission(
      clinicalIntake: UrgentCabinetClinicalIntakeDraft(
        careSubject: const UrgentCabinetCareSubject.self(),
        doctorId: _doctorId,
        cabinetId: _cabinetId,
        rawAnatomicalRegionIds: const ['front-head'],
        painScore: 6,
        shortDescription: 'Douleur synthétique',
      ),
      quote: UrgentCabinetFeeQuote(
        doctorId: _doctorId,
        cabinetId: _cabinetId,
        amountMilliTnd: 75000,
        currencyCode: 'TND',
        provenance: UrgentCabinetFeeProvenance.service,
        quotedAt: DateTime.parse('2026-10-18T10:00:00Z'),
        configurationRevision: 7,
        runtimeRevision: 8,
        practiceLocationVersion: 9,
      ),
    );

const _openGate = UrgentCabinetSubmissionActivationGate(
  explicitSyntheticDevelopmentAuthorization: true,
  backendLifecycleReady: true,
  authorizedIsolatedApplicationDatabase: true,
  waitingRecoveryIntegrated: true,
);

UrgentCabinetPatientLifecycleController _controller(
  _FakeRepository repository,
  _MemoryReceiptStore receipts, {
  DateTime Function()? clock,
}) => UrgentCabinetPatientLifecycleController(
  repository: repository,
  submissionCoordinator: UrgentCabinetSubmissionCoordinator(
    repository: repository,
    receiptStore: receipts,
  ),
  clock: clock ?? DateTime.now,
  idempotencyKeyFactory: () => _cancelKey,
);

void main() {
  group('closed-gate submission integration', () {
    test('checked-in gate prevents every repository submission', () async {
      final repository = _FakeRepository();
      final controller = _controller(repository, _MemoryReceiptStore());

      final result = await controller.submitAuthorized(
        activationGate: UrgentCabinetSubmissionActivationGate.p4Cab03C01Closed,
        authenticatedAccountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        submissionValidation: _validSubmission(),
        currentAuthoritativeTargetAndQuote: true,
      );

      expect(result.kind, UrgentCabinetSubmissionResultKind.definiteFailure);
      expect(
        result.failure?.kind,
        UrgentCabinetPatientRequestFailureKind.rolloutUnavailable,
      );
      expect(repository.submitCalls, 0);
      expect(controller.snapshot, isNull);
      controller.dispose();
    });

    test(
      'all four injected authorities submit and adopt server truth',
      () async {
        final repository = _FakeRepository()
          ..onSubmit = (_, _) async => _snapshot();
        final controller = _controller(repository, _MemoryReceiptStore());

        final result = await controller.submitAuthorized(
          activationGate: _openGate,
          authenticatedAccountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          submissionValidation: _validSubmission(),
          currentAuthoritativeTargetAndQuote: true,
        );

        expect(result.kind, UrgentCabinetSubmissionResultKind.acknowledged);
        expect(repository.submitCalls, 1);
        expect(controller.snapshot?.requestId, _requestId);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);
        controller.dispose();
      },
    );

    test('unresolved anatomy remains blocked before the repository', () async {
      final repository = _FakeRepository();
      final controller = _controller(repository, _MemoryReceiptStore());
      final unresolved = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: UrgentCabinetClinicalIntakeDraft(
          careSubject: const UrgentCabinetCareSubject.self(),
          doctorId: _doctorId,
          cabinetId: _cabinetId,
          rawAnatomicalRegionIds: const ['back-trap-upper'],
          painScore: 6,
          shortDescription: 'Douleur synthétique',
        ),
        quote: UrgentCabinetFeeQuote(
          doctorId: _doctorId,
          cabinetId: _cabinetId,
          amountMilliTnd: 75000,
          currencyCode: 'TND',
          provenance: UrgentCabinetFeeProvenance.service,
          configurationRevision: 7,
          runtimeRevision: 8,
          practiceLocationVersion: 9,
        ),
      );

      final result = await controller.submitAuthorized(
        activationGate: _openGate,
        authenticatedAccountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        submissionValidation: unresolved,
        currentAuthoritativeTargetAndQuote: true,
      );

      expect(
        unresolved.issue,
        UrgentCabinetSubmissionIssue.unresolvedAnatomicalIdentifier,
      );
      expect(result.kind, UrgentCabinetSubmissionResultKind.definiteFailure);
      expect(repository.submitCalls, 0);
      controller.dispose();
    });
  });

  group('authoritative lifecycle mapping', () {
    test('maps every backend terminal reason without conflation', () {
      final repository = _FakeRepository();
      final controller = _controller(repository, _MemoryReceiptStore());

      expect(
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(),
        ),
        isTrue,
      );
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);

      for (final expected in [
        (
          _snapshot(
            status: 'DECLINED',
            state: 'CABINET_CANCELLED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
          UrgentCabinetPatientLifecyclePhase.declined,
        ),
      ]) {
        expect(
          controller.adopt(
            accountId: _accountId,
            subject: const UrgentCabinetCareSubject.self(),
            snapshot: expected.$1,
          ),
          isTrue,
        );
        expect(controller.phase, expected.$2);
      }
      controller.dispose();

      for (final expected in [
        (
          _snapshot(
            status: 'CANCELLED',
            state: 'CABINET_CANCELLED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
          UrgentCabinetPatientLifecyclePhase.cancelled,
        ),
        (
          _snapshot(
            status: 'EXPIRED',
            state: 'CABINET_CANCELLED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
          UrgentCabinetPatientLifecyclePhase.expired,
        ),
        (
          _snapshot(
            status: 'ACCEPTED',
            state: 'CABINET_COMMITTED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
          UrgentCabinetPatientLifecyclePhase.accepted,
        ),
      ]) {
        final fresh = _controller(repository, _MemoryReceiptStore());
        expect(
          fresh.adopt(
            accountId: _accountId,
            subject: const UrgentCabinetCareSubject.self(),
            snapshot: expected.$1,
          ),
          isTrue,
        );
        expect(fresh.phase, expected.$2);
        fresh.dispose();
      }
    });

    test('rejects request identity and revision rollback', () {
      final controller = _controller(_FakeRepository(), _MemoryReceiptStore());
      controller.adopt(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        snapshot: _snapshot(),
      );

      expect(
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(
            requestId: '77777777-7777-4777-8777-777777777777',
          ),
        ),
        isFalse,
      );
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.unavailable);
      expect(
        controller.failure?.kind,
        UrgentCabinetPatientRequestFailureKind.invalidResponse,
      );
      controller.dispose();
    });

    test('client clock reaching zero never invents EXPIRED', () {
      var now = DateTime.parse('2026-10-18T12:00:00Z');
      final controller = _controller(
        _FakeRepository(),
        _MemoryReceiptStore(),
        clock: () => now,
      );
      controller.adopt(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        snapshot: _snapshot(),
      );
      expect(
        controller.approximateRemainingResponseWindow,
        const Duration(minutes: 4, seconds: 30),
      );

      now = now.add(const Duration(minutes: 10));
      expect(controller.approximateRemainingResponseWindow, Duration.zero);
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);
      expect(
        controller.snapshot!.responseStatus,
        UrgentCabinetPatientResponseStatus.pending,
      );
      controller.dispose();
    });
  });

  group('refresh and cancellation fencing', () {
    test('route entry, resume and reconnect share one bounded GET', () async {
      final repository = _FakeRepository();
      final completion = Completer<UrgentCabinetTargetedRequestSnapshot>();
      repository.onStatus = (_) => completion.future;
      final controller = _controller(repository, _MemoryReceiptStore());
      controller.adopt(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        snapshot: _snapshot(),
      );

      controller.setWaitingRouteActive(true);
      controller.applicationResumed();
      controller.networkReconnected();
      expect(repository.statusCalls, 1);
      completion.complete(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      repository.onStatus = (_) async => _snapshot();
      controller.networkReconnected();
      await Future<void>.delayed(Duration.zero);
      expect(repository.statusCalls, 2);
      controller.setWaitingRouteActive(false);
      controller.dispose();
    });

    test(
      'deduplicates overlapping refresh and applies accepted authority',
      () async {
        final repository = _FakeRepository();
        final completion = Completer<UrgentCabinetTargetedRequestSnapshot>();
        repository.onStatus = (_) => completion.future;
        final controller = _controller(repository, _MemoryReceiptStore());
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(),
        );

        final first = controller.refresh();
        final second = controller.refresh();
        expect(identical(first, second), isTrue);
        expect(repository.statusCalls, 1);
        completion.complete(
          _snapshot(
            status: 'ACCEPTED',
            state: 'CABINET_COMMITTED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
        );
        expect(await first, isTrue);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.accepted);
        controller.dispose();
      },
    );

    test(
      'accepted transient read failure retains recoverable server authority',
      () async {
        final repository = _FakeRepository()
          ..onStatus = (_) => Future.error(
            const UrgentCabinetPatientRequestFailure(
              kind: UrgentCabinetPatientRequestFailureKind.network,
              message: 'offline',
            ),
          );
        final controller = _controller(repository, _MemoryReceiptStore());
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(status: 'ACCEPTED', state: 'CABINET_COMMITTED'),
        );

        expect(await controller.refresh(), isFalse);
        expect(
          controller.phase,
          UrgentCabinetPatientLifecyclePhase.unavailable,
        );
        expect(controller.hasTransientReadFailure, isTrue);
        expect(
          controller.snapshot?.responseStatus,
          UrgentCabinetPatientResponseStatus.accepted,
        );

        repository.onStatus = (_) async =>
            _snapshot(status: 'ACCEPTED', state: 'CABINET_COMMITTED');
        expect(await controller.refresh(), isTrue);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.accepted);
        expect(controller.hasTransientReadFailure, isFalse);
        controller.dispose();
      },
    );

    test('cancellation sends exact revisions and one dedicated key', () async {
      final repository = _FakeRepository();
      final completion = Completer<UrgentCabinetTargetedRequestSnapshot>();
      repository.onCancel = (_, _, _) => completion.future;
      final controller = _controller(repository, _MemoryReceiptStore());
      controller.adopt(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        snapshot: _snapshot(),
      );

      final first = controller.cancel();
      final second = controller.cancel();
      expect(identical(first, second), isTrue);
      expect(repository.cancelCalls, 1);
      expect(repository.lastCancellation!.expectedResponseRevision, 2);
      expect(repository.lastCancellation!.expectedRequestRevision, 3);
      expect(repository.lastCancellation!.expectedJourneyRevision, 4);
      expect(repository.lastCancellationKey, _cancelKey);
      completion.complete(
        _snapshot(
          status: 'CANCELLED',
          state: 'CABINET_CANCELLED',
          responseRevision: 3,
          requestRevision: 4,
          journeyRevision: 5,
        ),
      );
      expect(await first, UrgentCabinetPatientCancellationResult.cancelled);
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.cancelled);
      controller.dispose();
    });

    test(
      'acceptance wins a cancellation conflict after mandatory refetch',
      () async {
        final repository = _FakeRepository();
        repository.onCancel = (_, _, _) => Future.error(
          const UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.cancelNotActionable,
            message: 'conflict',
          ),
        );
        repository.onStatus = (_) async => _snapshot(
          status: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          responseRevision: 3,
          requestRevision: 4,
          journeyRevision: 5,
        );
        final controller = _controller(repository, _MemoryReceiptStore());
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(),
        );

        expect(
          await controller.cancel(),
          UrgentCabinetPatientCancellationResult.acceptedWon,
        );
        expect(repository.statusCalls, 1);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.accepted);
        controller.dispose();
      },
    );

    test(
      'session invalidation discards stale refresh and clears receipt',
      () async {
        final repository = _FakeRepository();
        final receipts = _MemoryReceiptStore()
          ..receipt = const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _cancelKey,
          );
        final completion = Completer<UrgentCabinetTargetedRequestSnapshot>();
        repository.onStatus = (_) => completion.future;
        final controller = _controller(repository, receipts);
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(),
        );
        final refresh = controller.refresh();

        await controller.invalidateSession(_accountId);
        completion.complete(
          _snapshot(
            status: 'ACCEPTED',
            state: 'CABINET_COMMITTED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
        );
        expect(await refresh, isFalse);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.idle);
        expect(controller.snapshot, isNull);
        expect(receipts.receipt, isNull);
        controller.dispose();
      },
    );

    test('ambiguous cancellation retry reuses the same command key', () async {
      final repository = _FakeRepository();
      final keys = <String>[];
      var cancelAttempt = 0;
      repository.onCancel = (_, _, key) {
        keys.add(key);
        cancelAttempt++;
        if (cancelAttempt == 1) {
          return Future.error(
            const UrgentCabinetPatientRequestFailure(
              kind: UrgentCabinetPatientRequestFailureKind.network,
              message: 'ambiguous',
            ),
          );
        }
        return Future.value(
          _snapshot(
            status: 'CANCELLED',
            state: 'CABINET_CANCELLED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
          ),
        );
      };
      repository.onStatus = (_) async => _snapshot();
      final controller = _controller(repository, _MemoryReceiptStore());
      controller.adopt(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        snapshot: _snapshot(),
      );

      expect(
        await controller.cancel(),
        UrgentCabinetPatientCancellationResult.reconciled,
      );
      expect(
        await controller.cancel(),
        UrgentCabinetPatientCancellationResult.cancelled,
      );
      expect(keys, [_cancelKey, _cancelKey]);
      controller.dispose();
    });
  });

  group('post-acceptance operational lifecycle', () {
    test(
      'withdrawal is revision-bound and rapid taps create one command',
      () async {
        final repository = _FakeRepository();
        final completion = Completer<UrgentCabinetTargetedRequestSnapshot>();
        repository.onWithdraw = (_, _, _) => completion.future;
        final controller = _controller(repository, _MemoryReceiptStore());
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(
            status: 'ACCEPTED',
            state: 'CABINET_COMMITTED',
            allowedActions: const ['WITHDRAW', 'ISSUE_ARRIVAL_QR'],
          ),
        );

        final first = controller.withdrawAcceptedCommitment();
        final second = controller.withdrawAcceptedCommitment();
        expect(await second, isFalse);
        expect(repository.withdrawalCalls, 1);
        expect(repository.lastWithdrawal!.expectedResponseRevision, 2);
        expect(repository.lastWithdrawal!.expectedRequestRevision, 3);
        expect(repository.lastWithdrawal!.expectedJourneyRevision, 4);
        expect(repository.lastWithdrawal!.expectedCommitmentRevision, 1);
        expect(repository.lastWithdrawalKey, _cancelKey);

        completion.complete(
          _snapshot(
            status: 'CANCELLED',
            state: 'CABINET_CANCELLED',
            responseRevision: 3,
            requestRevision: 4,
            journeyRevision: 5,
            withdrawnAfterAcceptance: true,
            commitmentRevision: 2,
          ),
        );
        expect(await first, isTrue);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.cancelled);
        expect(
          controller.snapshot?.terminalReason,
          UrgentCabinetPatientTerminalReason.patientWithdrewAfterAcceptance,
        );
        controller.dispose();
      },
    );

    test('QR issuance is deduplicated and retained only in memory', () async {
      final repository = _FakeRepository();
      final completion = Completer<UrgentCabinetArrivalHandoff>();
      repository.onIssueHandoff = (_, _, _, _) => completion.future;
      final controller = _controller(repository, _MemoryReceiptStore());
      controller.adopt(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        snapshot: _snapshot(
          status: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          allowedActions: const ['WITHDRAW', 'ISSUE_ARRIVAL_QR'],
        ),
      );

      final first = controller.issueArrivalHandoff();
      final second = controller.issueArrivalHandoff();
      expect(await second, isNull);
      expect(repository.handoffCalls, 1);
      expect(repository.lastHandoffKey, _cancelKey);
      completion.complete(
        UrgentCabinetArrivalHandoff(
          handoffId: '99999999-9999-4999-8999-999999999999',
          commitmentId: _commitmentId,
          requestId: _requestId,
          token: 'OCAB1.payload.signature',
          issuedAt: DateTime.parse('2026-10-18T10:03:00Z'),
          expiresAt: DateTime.parse('2026-10-18T10:08:00Z'),
          replayed: false,
        ),
      );
      expect((await first)?.token, 'OCAB1.payload.signature');
      expect(controller.arrivalHandoff, isNotNull);

      await controller.invalidateSession(_accountId);
      expect(controller.arrivalHandoff, isNull);
      expect(controller.snapshot, isNull);
      controller.dispose();
    });

    test(
      'authoritative arrival refresh removes operational actions and token',
      () async {
        final repository = _FakeRepository();
        repository.onIssueHandoff = (_, _, _, _) async =>
            UrgentCabinetArrivalHandoff(
              handoffId: '99999999-9999-4999-8999-999999999999',
              commitmentId: _commitmentId,
              requestId: _requestId,
              token: 'OCAB1.payload.signature',
              issuedAt: DateTime.parse('2026-10-18T10:03:00Z'),
              expiresAt: DateTime.parse('2026-10-18T10:08:00Z'),
              replayed: false,
            );
        repository.onStatus = (_) async => _snapshot(
          status: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          responseRevision: 2,
          requestRevision: 3,
          journeyRevision: 4,
          commitmentRevision: 2,
          arrivalVerifiedAt: '2026-10-18T10:04:00Z',
        );
        final controller = _controller(repository, _MemoryReceiptStore());
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(
            status: 'ACCEPTED',
            state: 'CABINET_COMMITTED',
            allowedActions: const ['WITHDRAW', 'ISSUE_ARRIVAL_QR'],
          ),
        );
        expect(await controller.issueArrivalHandoff(), isNotNull);

        expect(await controller.refresh(), isTrue);
        expect(controller.arrivalHandoff, isNull);
        expect(controller.canIssueArrivalHandoff, isFalse);
        expect(controller.canWithdraw, isFalse);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.accepted);
        controller.dispose();
      },
    );
  });

  group('receipt recovery and frozen presentation', () {
    test(
      'authenticated refresh restores a pending receipt without POST',
      () async {
        final repository = _FakeRepository();
        final receipts = _MemoryReceiptStore()
          ..receipt = const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _cancelKey,
          );
        repository.onRecover = (_) async => _snapshot(replayed: true);
        repository.onActive = (_) async => throw StateError('must not run');
        final controller = _controller(repository, receipts);

        expect(
          await controller.recoverAfterAuthentication(accountId: _accountId),
          isTrue,
        );
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);
        expect(controller.snapshot?.requestId, _requestId);
        expect(repository.recoverCalls, 1);
        expect(repository.activeCalls, 0);
        expect(repository.submitCalls, 0);
        controller.dispose();
      },
    );

    test(
      'authenticated refresh restores accepted commitment presentation',
      () async {
        final repository = _FakeRepository();
        final receipts = _MemoryReceiptStore()
          ..receipt = const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _cancelKey,
          );
        repository.onRecover = (_) async => _snapshot(
          status: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          replayed: true,
        );
        final controller = _controller(repository, receipts);

        expect(
          await controller.recoverAfterAuthentication(accountId: _accountId),
          isTrue,
        );

        final restored = controller.snapshot!;
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.accepted);
        expect(restored.commitmentId, _commitmentId);
        expect(restored.doctorId, _doctorId);
        expect(restored.practiceLocationId, _cabinetId);
        expect(restored.doctorDisplayName, 'Dr Synthétique');
        expect(restored.cabinetName, 'Cabinet synthétique');
        expect(restored.cabinetAddress, '1 rue synthétique');
        expect(restored.quotedFeeMilliTnd, 75000);
        expect(repository.submitCalls, 0);
        controller.dispose();
      },
    );

    test(
      'receipt authority establishes the recovered family subject',
      () async {
        final repository = _FakeRepository();
        final receipts = _MemoryReceiptStore()
          ..receipt = const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _cancelKey,
          );
        repository.onRecover = (_) async => _snapshot(
          status: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          replayed: true,
          subjectType: 'FAMILY_MEMBER',
          familyMemberId: _familyId,
        );
        final controller = _controller(repository, receipts);

        expect(
          await controller.recoverAfterAuthentication(accountId: _accountId),
          isTrue,
        );
        expect(
          controller.snapshot?.careSubject,
          UrgentCabinetCareSubject.familyMember(_familyId),
        );
        expect(repository.activeCalls, 0);
        expect(repository.submitCalls, 0);
        controller.dispose();
      },
    );

    test('account mismatch cannot consume another Patient receipt', () async {
      final repository = _FakeRepository()
        ..onActive = (_) => Future.error(_authoritativeAbsence);
      final receipts = _MemoryReceiptStore()
        ..receipt = const UrgentCabinetRecoveryReceipt(
          accountId: 'different-patient',
          idempotencyKey: _cancelKey,
        );
      final controller = _controller(repository, receipts);

      expect(
        await controller.recoverAfterAuthentication(accountId: _accountId),
        isFalse,
      );
      expect(repository.recoverCalls, 0);
      expect(repository.activeCalls, 1);
      expect(repository.submitCalls, 0);
      expect(controller.snapshot, isNull);
      controller.dispose();
    });

    test('recovery failure never fabricates accepted authority', () async {
      final repository = _FakeRepository();
      final receipts = _MemoryReceiptStore()
        ..receipt = const UrgentCabinetRecoveryReceipt(
          accountId: _accountId,
          idempotencyKey: _cancelKey,
        );
      repository.onRecover = (_) => Future.error(
        const UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.serverUnavailable,
          message: 'unavailable',
          statusCode: 500,
        ),
      );
      final controller = _controller(repository, receipts);

      expect(
        await controller.recoverAfterAuthentication(accountId: _accountId),
        isFalse,
      );
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.unavailable);
      expect(controller.snapshot, isNull);
      expect(repository.submitCalls, 0);
      controller.dispose();
    });

    test(
      'notification tap recovers authoritative accepted family request without POST',
      () async {
        final repository = _FakeRepository()
          ..onStatus = (requestId) async {
            expect(requestId, _requestId);
            return _snapshot(
              status: 'ACCEPTED',
              state: 'CABINET_COMMITTED',
              subjectType: 'FAMILY_MEMBER',
              familyMemberId: _familyId,
            );
          };
        final controller = _controller(repository, _MemoryReceiptStore());

        expect(
          await controller.recoverFromNotification(
            accountId: _accountId,
            requestId: _requestId,
          ),
          isTrue,
        );
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.accepted);
        expect(
          controller.snapshot?.careSubject,
          UrgentCabinetCareSubject.familyMember(_familyId),
        );
        expect(repository.statusCalls, 1);
        expect(repository.submitCalls, 0);
        controller.dispose();
      },
    );

    test('notification recovery failure never fabricates accepted', () async {
      final repository = _FakeRepository()
        ..onStatus = (_) => Future.error(
          const UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.sessionRejected,
            message: 'forbidden',
            statusCode: 403,
          ),
        );
      final controller = _controller(repository, _MemoryReceiptStore());

      expect(
        await controller.recoverFromNotification(
          accountId: _accountId,
          requestId: _requestId,
        ),
        isFalse,
      );
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.unavailable);
      expect(controller.snapshot, isNull);
      expect(repository.submitCalls, 0);
      controller.dispose();
    });

    testWidgets(
      'post-auth recovery keeps Home below accepted and allows explicit reopen',
      (tester) async {
        final auth = AuthController(
          repository: const _RestoredPatientAuthRepository(),
        );
        await auth.initialize();
        final repository = _FakeRepository();
        final receipts = _MemoryReceiptStore()
          ..receipt = const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _cancelKey,
          );
        repository.onRecover = (_) async => _snapshot(
          status: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          replayed: true,
        );
        final lifecycle = _controller(repository, receipts);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: auth),
              ChangeNotifierProvider<UserProvider>(
                create: (_) => UserProvider(),
              ),
              ChangeNotifierProvider<FamilyProvider>(
                create: (_) =>
                    FamilyProvider(repository: _EmptyFamilyRepository()),
              ),
              ChangeNotifierProvider<
                UrgentCabinetPatientLifecycleController
              >.value(value: lifecycle),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => navigateAfterAuthentication(context, auth),
                    child: const Text('Restore session'),
                  ),
                ),
              ),
              routes: {
                '/home': (homeContext) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Patient Home'),
                      TextButton(
                        onPressed: () => Navigator.of(
                          homeContext,
                        ).pushNamed('/urgent-cabinet/care-subject'),
                        child: const Text('Open existing request'),
                      ),
                    ],
                  ),
                ),
                '/urgent-cabinet/care-subject': (_) =>
                    const UrgentCabinetFlowShell(),
              },
            ),
          ),
        );

        await tester.tap(find.text('Restore session'));
        await tester.pumpAndSettle();
        expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsOneWidget);
        expect(lifecycle.phase, UrgentCabinetPatientLifecyclePhase.accepted);

        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('urgent-cabinet-confirm-accepted-exit')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Patient Home'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsNothing);
        expect(repository.recoverCalls, 1);
        expect(repository.submitCalls, 0);

        await tester.tap(find.text('Open existing request'));
        await tester.pumpAndSettle();
        expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsOneWidget);
        expect(repository.recoverCalls, 1);
        expect(repository.submitCalls, 0);

        lifecycle.dispose();
        auth.dispose();
      },
    );

    test('receipt recovery runs before active-subject fallback', () async {
      final repository = _FakeRepository();
      final receipts = _MemoryReceiptStore()
        ..receipt = const UrgentCabinetRecoveryReceipt(
          accountId: _accountId,
          idempotencyKey: _cancelKey,
        );
      repository.onRecover = (_) async => _snapshot(replayed: true);
      repository.onActive = (_) async => throw StateError('must not run');
      final controller = _controller(repository, receipts);

      expect(
        await controller.recover(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
        ),
        isTrue,
      );
      expect(repository.recoverCalls, 1);
      expect(repository.activeCalls, 0);
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);
      controller.dispose();
    });

    test('exact no-active 404 permits a subsequent valid submission', () async {
      final repository = _FakeRepository();
      repository.onActive = (_) => Future.error(_authoritativeAbsence);
      repository.onSubmit = (_, _) async => _snapshot();
      final controller = _controller(repository, _MemoryReceiptStore());

      expect(
        await controller.recover(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
        ),
        isFalse,
      );
      expect(repository.activeCalls, 1);
      expect(controller.snapshot, isNull);
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.idle);

      final submitted = await controller.submitAuthorized(
        activationGate: _openGate,
        authenticatedAccountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
        submissionValidation: _validSubmission(),
        currentAuthoritativeTargetAndQuote: true,
      );
      expect(submitted.kind, UrgentCabinetSubmissionResultKind.acknowledged);
      expect(repository.submitCalls, 1);
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);
      controller.dispose();
    });

    test('unauthorized active recovery remains fail-closed', () async {
      final repository = _FakeRepository()
        ..onActive = (_) => Future.error(
          const UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.sessionRejected,
            message: 'forbidden',
            code: 'FORBIDDEN',
            statusCode: 403,
          ),
        );
      final controller = _controller(repository, _MemoryReceiptStore());

      expect(
        await controller.recover(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
        ),
        isFalse,
      );
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.unavailable);
      expect(
        controller.failure?.kind,
        UrgentCabinetPatientRequestFailureKind.sessionRejected,
      );
      expect(repository.submitCalls, 0);
      controller.dispose();
    });

    test('an unrelated 404 is not treated as an empty active result', () async {
      final repository = _FakeRepository()
        ..onActive = (_) => Future.error(
          const UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.notFound,
            message: 'route missing',
            code: 'ROUTE_NOT_FOUND',
            statusCode: 404,
          ),
        );
      final controller = _controller(repository, _MemoryReceiptStore());

      expect(
        await controller.recover(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
        ),
        isFalse,
      );
      expect(controller.phase, UrgentCabinetPatientLifecyclePhase.unavailable);
      expect(controller.failure?.code, 'ROUTE_NOT_FOUND');
      expect(repository.submitCalls, 0);
      controller.dispose();
    });

    test(
      'resume retries exact-subject recovery after authoritative absence',
      () async {
        final repository = _FakeRepository()
          ..onActive = (_) => Future.error(_authoritativeAbsence);
        final controller = _controller(repository, _MemoryReceiptStore());

        expect(
          await controller.recover(
            accountId: _accountId,
            subject: const UrgentCabinetCareSubject.self(),
          ),
          isFalse,
        );
        repository.onActive = (_) async => _snapshot();
        controller.applicationResumed();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(repository.activeCalls, 2);
        expect(
          controller.snapshot?.careSubject,
          const UrgentCabinetCareSubject.self(),
        );
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.pending);
        controller.dispose();
      },
    );

    test('authoritative accepted projection can open arrival handoff', () {
      final flow = UrgentCabinetFlowController(accountId: _accountId);
      expect(
        flow.applyAuthoritativeSnapshot(
          snapshot: _snapshot(status: 'ACCEPTED', state: 'CABINET_COMMITTED'),
          patientDisplayName: 'Patient synthétique',
        ),
        isTrue,
      );
      expect(flow.requestState, isA<UrgentCabinetRequestAccepted>());
      expect(
        (flow.requestState as UrgentCabinetRequestAccepted).isAuthoritative,
        isTrue,
      );
      expect(canOpenUrgentCabinetArrivalInstructions(flow), isTrue);
      final accepted = flow.requestState as UrgentCabinetRequestAccepted;
      expect(
        flow.applyDoctorDecision(
          UrgentCabinetDoctorDecisionEvent(
            accountId: _accountId,
            localAttemptGeneration: accepted.localAttemptGeneration,
            doctorId: _doctorId,
            cabinetId: _cabinetId,
            type: UrgentCabinetDoctorDecisionType.declined,
            provenance: UrgentCabinetDecisionProvenance.developmentFixture,
          ),
          developmentAcceptanceAuthorized: true,
        ),
        UrgentCabinetDecisionTransition.rejected,
      );
      flow.dispose();
    });

    test('revoked family ownership clears every route projection', () {
      final flow = UrgentCabinetFlowController(accountId: _accountId);
      expect(
        flow.applyAuthoritativeSnapshot(
          snapshot: _snapshot(
            subjectType: 'FAMILY_MEMBER',
            familyMemberId: _familyId,
          ),
          patientDisplayName: 'Membre synthétique',
        ),
        isTrue,
      );

      flow.invalidateFamilySubjectIfMissing(const <String>{});
      expect(flow.requestState, isA<UrgentCabinetRequestDraft>());
      expect(flow.selectedSubject, isNull);
      expect(flow.selectedDoctorId, isNull);
      expect(flow.selectedCabinetId, isNull);
      expect(flow.quoteSnapshot, isNull);
      expect(flow.clinicalIntakeDraft, isNull);
      flow.dispose();
    });

    test(
      'deliberate retry clears terminal receipt without cancelling',
      () async {
        final repository = _FakeRepository();
        final receipts = _MemoryReceiptStore()
          ..receipt = const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _cancelKey,
          );
        final controller = _controller(repository, receipts);
        controller.adopt(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
          snapshot: _snapshot(status: 'DECLINED', state: 'CABINET_CANCELLED'),
        );

        expect(await controller.beginNewJourneyAfterTerminal(), isTrue);
        expect(controller.phase, UrgentCabinetPatientLifecyclePhase.idle);
        expect(controller.snapshot, isNull);
        expect(receipts.receipt, isNull);
        expect(repository.cancelCalls, 0);
        controller.dispose();
      },
    );
  });
}
