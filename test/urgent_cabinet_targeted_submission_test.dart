import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_anatomical_mapping.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_clinical_intake_draft.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_submission_activation_gate.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_submission_coordinator.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_repository.dart';
import 'package:omnicare_mobile/features/emergency/widgets/body_map_widget.dart';

const _accountId = 'patient-account-1';
const _doctorId = '11111111-1111-4111-8111-111111111111';
const _cabinetId = '22222222-2222-4222-8222-222222222222';
const _familyId = '33333333-3333-4333-8333-333333333333';
const _requestId = '44444444-4444-4444-8444-444444444444';
const _journeyId = '55555555-5555-4555-8555-555555555555';
const _commitmentId = '66666666-6666-4666-8666-666666666666';
const _idempotencyKey = '77777777-7777-4777-8777-777777777777';

UrgentCabinetClinicalIntakeDraft _draft({
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  Iterable<String> areas = const ['front-head', 'back-lumbar', 'front-head'],
  int painScore = 6,
  String description = ' Douleur aiguë depuis ce matin. ',
  String doctorId = _doctorId,
  String cabinetId = _cabinetId,
}) => UrgentCabinetClinicalIntakeDraft(
  careSubject: subject,
  doctorId: doctorId,
  cabinetId: cabinetId,
  rawAnatomicalRegionIds: areas,
  painScore: painScore,
  shortDescription: description,
);

UrgentCabinetFeeQuote _quote({
  int amountMilliTnd = 75000,
  String doctorId = _doctorId,
  String cabinetId = _cabinetId,
  int? configurationRevision = 7,
  int? runtimeRevision = 8,
  int? practiceLocationVersion = 9,
  UrgentCabinetFeeProvenance provenance = UrgentCabinetFeeProvenance.service,
}) => UrgentCabinetFeeQuote(
  doctorId: doctorId,
  cabinetId: cabinetId,
  amountMilliTnd: amountMilliTnd,
  currencyCode: 'TND',
  provenance: provenance,
  configurationRevision: configurationRevision,
  runtimeRevision: runtimeRevision,
  practiceLocationVersion: practiceLocationVersion,
);

UrgentCabinetTargetedSubmission _submission({
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  Iterable<String> areas = const ['front-head', 'back-lumbar', 'front-head'],
  int fee = 75000,
}) => prepareUrgentCabinetTargetedSubmission(
  clinicalIntake: _draft(subject: subject, areas: areas),
  quote: _quote(amountMilliTnd: fee),
).submission!;

Map<String, Object?> _snapshotJson({
  String responseStatus = 'PENDING',
  String state = 'CABINET_PENDING',
  String subjectType = 'SELF',
  String? familyMemberId,
  String? respondedAt,
  String? commitmentId,
  String? commitmentStatus,
  int? commitmentRevision,
  String? committedAt,
  String? terminalAt,
  String? terminalReason,
  List<String> allowedActions = const ['CANCEL'],
  bool replayed = false,
  Object quotedFeeTnd = 75.000,
  Object? cabinetLatitude,
  Object? cabinetLongitude,
}) => <String, Object?>{
  'requestId': _requestId,
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
  'cabinetLatitude': cabinetLatitude,
  'cabinetLongitude': cabinetLongitude,
  'quotedFeeTnd': quotedFeeTnd,
  'currency': 'TND',
  'configurationRevision': 7,
  'runtimeRevision': 8,
  'practiceLocationVersion': 9,
  'responseStatus': responseStatus,
  'responseRevision': responseStatus == 'PENDING' ? 0 : 1,
  'respondedAt': respondedAt,
  'commitmentId': commitmentId,
  'commitmentStatus': commitmentStatus,
  'commitmentRevision': commitmentRevision,
  'committedAt': committedAt,
  'state': state,
  'requestRevision': responseStatus == 'PENDING' ? 1 : 2,
  'journeyRevision': responseStatus == 'PENDING' ? 1 : 2,
  'createdAt': '2026-10-18T10:00:00Z',
  'responseDeadlineAt': '2026-10-18T10:05:00Z',
  'terminalAt': terminalAt,
  'terminalReason': terminalReason,
  'allowedActions': allowedActions,
  'replayed': replayed,
  'evaluatedAt': '2026-10-18T10:00:01Z',
};

UrgentCabinetTargetedRequestSnapshot _pendingSnapshot({
  bool replayed = false,
}) => UrgentCabinetTargetedRequestSnapshot.fromJson(
  _snapshotJson(replayed: replayed),
);

void main() {
  group('anatomical mapping', () {
    test('explicit inventory covers all 54 frozen identifiers', () {
      expect(urgentCabinetAnatomicalRegionMapping, hasLength(54));
      expect(
        urgentCabinetAnatomicalRegionMapping.keys.toSet(),
        muscleParts.keys.toSet(),
      );
      expect(
        urgentCabinetAnatomicalRegionMapping.entries
            .where((entry) => entry.value == null)
            .map((entry) => entry.key),
        ['back-trap-upper'],
      );
      expect(
        urgentCabinetAnatomicalRegionMapping.values,
        isNot(contains(UrgentCabinetBodyAreaCode.general)),
      );
    });

    test('all 53 classified identifiers have the reviewed exact category', () {
      Set<String> identifiersFor(UrgentCabinetBodyAreaCode code) =>
          urgentCabinetAnatomicalRegionMapping.entries
              .where((entry) => entry.value == code)
              .map((entry) => entry.key)
              .toSet();

      expect(identifiersFor(UrgentCabinetBodyAreaCode.head), {'front-head'});
      expect(identifiersFor(UrgentCabinetBodyAreaCode.neck), {
        'front-neck',
        'back-neck',
      });
      expect(identifiersFor(UrgentCabinetBodyAreaCode.chest), {
        'front-chest-pectoral-left',
        'front-chest-pectoral-right',
        'front-serratus-left',
        'front-serratus-right',
      });
      expect(identifiersFor(UrgentCabinetBodyAreaCode.abdomen), {
        'front-abs-upper',
        'front-abs-middle',
        'front-abs-lower',
        'front-oblique-left',
        'front-oblique-right',
      });
      expect(identifiersFor(UrgentCabinetBodyAreaCode.back), {
        'back-lat-left',
        'back-lat-right',
        'back-spine-upper',
        'back-spine-middle',
        'back-lumbar',
      });
      expect(identifiersFor(UrgentCabinetBodyAreaCode.pelvis), {
        'back-glute-left',
        'back-glute-right',
      });
      expect(identifiersFor(UrgentCabinetBodyAreaCode.upperLimb), {
        'front-shoulder-deltoid-left',
        'front-shoulder-deltoid-right',
        'back-shoulder-deltoid-left',
        'back-shoulder-deltoid-right',
        'front-bicep-left',
        'front-bicep-right',
        'back-tricep-left',
        'back-tricep-right',
        'front-forearm-left',
        'front-forearm-right',
        'back-forearm-left',
        'back-forearm-right',
        'front-hand-left',
        'front-hand-right',
        'back-hand-left',
        'back-hand-right',
      });
      expect(identifiersFor(UrgentCabinetBodyAreaCode.lowerLimb), {
        'front-thigh-quad-left',
        'front-thigh-quad-right',
        'back-thigh-hamstring-left',
        'back-thigh-hamstring-right',
        'front-knee-left',
        'front-knee-right',
        'back-knee-left',
        'back-knee-right',
        'front-shin-left',
        'front-shin-right',
        'front-calf-left',
        'front-calf-right',
        'back-calf-left',
        'back-calf-right',
        'front-foot-left',
        'front-foot-right',
        'back-foot-left',
        'back-foot-right',
      });
    });

    test('deduplicates categories in first-selection order', () {
      final result = mapUrgentCabinetAnatomy([
        'front-hand-left',
        'front-bicep-right',
        'front-head',
        'back-lumbar',
        'front-head',
      ]);

      expect(result.isComplete, isTrue);
      expect(result.bodyAreaCodes, [
        UrgentCabinetBodyAreaCode.upperLimb,
        UrgentCabinetBodyAreaCode.head,
        UrgentCabinetBodyAreaCode.back,
      ]);
    });

    test('unknown and unresolved identifiers fail closed separately', () {
      final unknown = mapUrgentCabinetAnatomy(['front-head ', 'unknown']);
      final unresolved = mapUrgentCabinetAnatomy(['back-trap-upper']);

      expect(unknown.isComplete, isFalse);
      expect(unknown.unknownIdentifiers, ['front-head ', 'unknown']);
      expect(unresolved.isComplete, isFalse);
      expect(unresolved.unresolvedIdentifiers, ['back-trap-upper']);
    });
  });

  group('submission DTO', () {
    test('serializes exact SELF payload and three quote revisions', () {
      final submission = _submission(fee: 0);

      expect(submission.toJson(), {
        'subjectType': 'SELF',
        'doctorId': _doctorId,
        'practiceLocationId': _cabinetId,
        'intent': 'URGENT_CABINET_TARGETED',
        'bodyAreaCodes': ['HEAD', 'BACK'],
        'painScore': 6,
        'shortDescription': 'Douleur aiguë depuis ce matin.',
        'acknowledgedQuote': {
          'amountTnd': 0.0,
          'currency': 'TND',
          'configurationRevision': 7,
          'runtimeRevision': 8,
          'practiceLocationVersion': 9,
        },
      });
      expect(submission.toJson(), isNot(contains('patientId')));
      expect(submission.toJson(), isNot(contains('mrsPatientId')));
    });

    test('serializes only the explicitly selected FAMILY_MEMBER', () {
      final submission = _submission(
        subject: UrgentCabinetCareSubject.familyMember(_familyId),
      );

      expect(submission.toJson()['subjectType'], 'FAMILY_MEMBER');
      expect(submission.toJson()['familyMemberId'], _familyId);
    });

    test('unresolved and unknown anatomy never create a payload', () {
      final unresolved = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: _draft(areas: ['back-trap-upper']),
        quote: _quote(),
      );
      final unknown = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: _draft(areas: ['future-body-zone']),
        quote: _quote(),
      );

      expect(
        unresolved.issue,
        UrgentCabinetSubmissionIssue.unresolvedAnatomicalIdentifier,
      );
      expect(unresolved.identifiers, ['back-trap-upper']);
      expect(
        unknown.issue,
        UrgentCabinetSubmissionIssue.unknownAnatomicalIdentifier,
      );
    });

    test('rejects missing fields, bad pain and over-500 code points', () {
      expect(
        prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(areas: const []),
          quote: _quote(),
        ).issue,
        UrgentCabinetSubmissionIssue.invalidClinicalIntake,
      );
      expect(
        prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(painScore: 11),
          quote: _quote(),
        ).issue,
        UrgentCabinetSubmissionIssue.invalidClinicalIntake,
      );
      expect(
        prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(description: List.filled(501, 'é').join()),
          quote: _quote(),
        ).issue,
        UrgentCabinetSubmissionIssue.invalidClinicalIntake,
      );
    });

    test('rejects changed target, incomplete quote and fixture authority', () {
      expect(
        prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(),
          quote: _quote(doctorId: _journeyId),
        ).issue,
        UrgentCabinetSubmissionIssue.targetMismatch,
      );
      expect(
        prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(),
          quote: _quote(runtimeRevision: null),
        ).issue,
        UrgentCabinetSubmissionIssue.incompleteQuoteAuthority,
      );
      expect(
        prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(),
          quote: _quote(
            provenance: UrgentCabinetFeeProvenance.developmentFixture,
          ),
        ).issue,
        UrgentCabinetSubmissionIssue.developmentFixture,
      );
    });
  });

  group('strict response parsing', () {
    test('retains exact pending authority and server deadline', () {
      final value = _pendingSnapshot();

      expect(value.requestId, _requestId);
      expect(
        value.attemptState,
        UrgentCabinetPatientAttemptState.cabinetPending,
      );
      expect(value.requestRevision, 1);
      expect(value.journeyRevision, 1);
      expect(value.responseRevision, 0);
      expect(value.allowedActions, ['CANCEL']);
      expect(value.quotedFeeMilliTnd, 75000);
      expect(value.responseDeadlineAt, DateTime.utc(2026, 10, 18, 10, 5));
    });

    test(
      'retains a valid cabinet coordinate pair and rejects partial data',
      () {
        final value = UrgentCabinetTargetedRequestSnapshot.fromJson(
          _snapshotJson(cabinetLatitude: 36.8065, cabinetLongitude: 10.1815),
        );

        expect(value.cabinetLatitude, 36.8065);
        expect(value.cabinetLongitude, 10.1815);
        expect(
          () => UrgentCabinetTargetedRequestSnapshot.fromJson(
            _snapshotJson(cabinetLatitude: 36.8065),
          ),
          throwsFormatException,
        );
        expect(
          () => UrgentCabinetTargetedRequestSnapshot.fromJson(
            _snapshotJson(cabinetLatitude: 91, cabinetLongitude: 10.1815),
          ),
          throwsFormatException,
        );
      },
    );

    test('accepts only a complete commitment shape', () {
      final accepted = UrgentCabinetTargetedRequestSnapshot.fromJson(
        _snapshotJson(
          responseStatus: 'ACCEPTED',
          state: 'CABINET_COMMITTED',
          respondedAt: '2026-10-18T10:02:00Z',
          commitmentId: _commitmentId,
          commitmentStatus: 'ACTIVE',
          commitmentRevision: 0,
          committedAt: '2026-10-18T10:02:00Z',
          terminalAt: '2026-10-18T10:02:00Z',
          allowedActions: const [],
        ),
      );
      expect(accepted.commitmentId, _commitmentId);

      expect(
        () => UrgentCabinetTargetedRequestSnapshot.fromJson(
          _snapshotJson(
            responseStatus: 'ACCEPTED',
            state: 'CABINET_COMMITTED',
            respondedAt: '2026-10-18T10:02:00Z',
            terminalAt: '2026-10-18T10:02:00Z',
            allowedActions: const [],
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects unsupported enums and impossible terminal combinations', () {
      expect(
        () => UrgentCabinetTargetedRequestSnapshot.fromJson(
          _snapshotJson(responseStatus: 'WAITING'),
        ),
        throwsFormatException,
      );
      expect(
        () => UrgentCabinetTargetedRequestSnapshot.fromJson(
          _snapshotJson(
            responseStatus: 'DECLINED',
            state: 'CABINET_CANCELLED',
            respondedAt: '2026-10-18T10:02:00Z',
            terminalAt: '2026-10-18T10:02:00Z',
            terminalReason: 'PATIENT_CANCELLED',
            allowedActions: const [],
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('activation gate', () {
    test('production gate admits valid SELF and FAMILY_MEMBER authority', () {
      for (final subject in <UrgentCabinetCareSubject>[
        const UrgentCabinetCareSubject.self(),
        UrgentCabinetCareSubject.familyMember(_familyId),
      ]) {
        final validation = prepareUrgentCabinetTargetedSubmission(
          clinicalIntake: _draft(subject: subject),
          quote: _quote(),
        );
        expect(
          UrgentCabinetSubmissionActivationGate.p4Production.allows(
            authenticatedAccountId: _accountId,
            submission: validation,
            currentAuthoritativeTargetAndQuote: true,
          ),
          isTrue,
        );
      }
    });

    test('production gate retains account, payload and target fences', () {
      final valid = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: _draft(),
        quote: _quote(),
      );
      final invalid = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: _draft(doctorId: 'invalid'),
        quote: _quote(),
      );

      expect(
        UrgentCabinetSubmissionActivationGate.p4Production.allows(
          authenticatedAccountId: null,
          submission: valid,
          currentAuthoritativeTargetAndQuote: true,
        ),
        isFalse,
      );
      expect(
        UrgentCabinetSubmissionActivationGate.p4Production.allows(
          authenticatedAccountId: _accountId,
          submission: invalid,
          currentAuthoritativeTargetAndQuote: true,
        ),
        isFalse,
      );
      expect(
        UrgentCabinetSubmissionActivationGate.p4Production.allows(
          authenticatedAccountId: _accountId,
          submission: valid,
          currentAuthoritativeTargetAndQuote: false,
        ),
        isFalse,
      );
    });

    test('checked-in milestone gate cannot activate submission', () {
      final validation = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: _draft(),
        quote: _quote(),
      );
      expect(
        UrgentCabinetSubmissionActivationGate.p4Cab03C01Closed.allows(
          authenticatedAccountId: _accountId,
          submission: validation,
          currentAuthoritativeTargetAndQuote: true,
        ),
        isFalse,
      );
    });

    test('each of the four authorities is independently required', () {
      final validation = prepareUrgentCabinetTargetedSubmission(
        clinicalIntake: _draft(),
        quote: _quote(),
      );
      const authoritySets = [
        [false, true, true, true],
        [true, false, true, true],
        [true, true, false, true],
        [true, true, true, false],
      ];

      for (final authorities in authoritySets) {
        final gate = UrgentCabinetSubmissionActivationGate(
          explicitSyntheticDevelopmentAuthorization: authorities[0],
          backendLifecycleReady: authorities[1],
          authorizedIsolatedApplicationDatabase: authorities[2],
          waitingRecoveryIntegrated: authorities[3],
        );
        expect(
          gate.allows(
            authenticatedAccountId: _accountId,
            submission: validation,
            currentAuthoritativeTargetAndQuote: true,
          ),
          isFalse,
        );
      }
    });
  });

  group('authenticated repository', () {
    test('posts the exact payload and idempotency header', () async {
      final adapter = _QueueAdapter([_QueuedResponse(201, _snapshotJson())]);
      final repository = AppUrgentCabinetTargetedRequestRepository(
        _client(adapter),
      );
      final submission = _submission();

      final result = await repository.submit(
        submission: submission,
        idempotencyKey: _idempotencyKey,
      );

      expect(result.requestId, _requestId);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/me/urgent-cabinet/requests');
      expect(
        adapter.requests.single.headers['Idempotency-Key'],
        _idempotencyKey,
      );
      expect(adapter.bodies.single, submission.toJson());
    });

    test('uses exact status, recovery and active endpoints', () async {
      final adapter = _QueueAdapter([
        _QueuedResponse(200, _snapshotJson()),
        _QueuedResponse(200, _snapshotJson(replayed: true)),
        _QueuedResponse(
          200,
          _snapshotJson(
            subjectType: 'FAMILY_MEMBER',
            familyMemberId: _familyId,
          ),
        ),
      ]);
      final repository = AppUrgentCabinetTargetedRequestRepository(
        _client(adapter),
      );

      await repository.status(_requestId);
      await repository.recover(_idempotencyKey);
      await repository.active(UrgentCabinetCareSubject.familyMember(_familyId));

      expect(
        adapter.requests[0].path,
        '/me/urgent-cabinet/requests/$_requestId',
      );
      expect(adapter.requests[1].path, '/me/urgent-cabinet/requests/recovery');
      expect(adapter.requests[1].headers['Idempotency-Key'], _idempotencyKey);
      expect(adapter.requests[2].path, '/me/urgent-cabinet/requests/active');
      expect(adapter.requests[2].queryParameters, {
        'subjectType': 'FAMILY_MEMBER',
        'familyMemberId': _familyId,
      });
    });

    test('preserves the exact authoritative active-absence response', () async {
      final adapter = _QueueAdapter([
        const _QueuedResponse(404, {
          'code': 'URGENT_CABINET_REQUEST_NOT_FOUND',
        }),
      ]);
      final repository = AppUrgentCabinetTargetedRequestRepository(
        _client(adapter),
      );

      await expectLater(
        repository.active(const UrgentCabinetCareSubject.self()),
        throwsA(
          isA<UrgentCabinetPatientRequestFailure>()
              .having(
                (failure) => failure.isAuthoritativeRequestAbsence,
                'authoritative absence',
                isTrue,
              )
              .having((failure) => failure.statusCode, 'status', 404),
        ),
      );
    });

    test('does not classify an arbitrary active 404 as empty', () async {
      final adapter = _QueueAdapter([
        const _QueuedResponse(404, {'code': 'ROUTE_NOT_FOUND'}),
      ]);
      final repository = AppUrgentCabinetTargetedRequestRepository(
        _client(adapter),
      );

      await expectLater(
        repository.active(const UrgentCabinetCareSubject.self()),
        throwsA(
          isA<UrgentCabinetPatientRequestFailure>().having(
            (failure) => failure.isAuthoritativeRequestAbsence,
            'authoritative absence',
            isFalse,
          ),
        ),
      );
    });

    test(
      'serializes cancellation revisions using backend field names',
      () async {
        final adapter = _QueueAdapter([
          _QueuedResponse(
            200,
            _snapshotJson(
              responseStatus: 'CANCELLED',
              state: 'CABINET_CANCELLED',
              terminalAt: '2026-10-18T10:02:00Z',
              terminalReason: 'PATIENT_CANCELLED',
              allowedActions: const [],
              replayed: true,
            ),
          ),
        ]);
        final repository = AppUrgentCabinetTargetedRequestRepository(
          _client(adapter),
        );

        await repository.cancel(
          requestId: _requestId,
          command: const UrgentCabinetPatientCancellation(
            expectedResponseRevision: 0,
            expectedRequestRevision: 1,
            expectedJourneyRevision: 1,
          ),
          idempotencyKey: _idempotencyKey,
        );

        expect(
          adapter.requests.single.path,
          '/me/urgent-cabinet/requests/$_requestId/cancel',
        );
        expect(adapter.bodies.single, {
          'expectedResponseRevision': 0,
          'expectedAttemptRevision': 1,
          'expectedJourneyRevision': 1,
        });
      },
    );

    test(
      'maps backend Problem Details codes without trusting detail text',
      () async {
        final adapter = _QueueAdapter([
          const _QueuedResponse(409, {
            'type':
                'https://api.omnicare.tn/problems/care-capability/urgent-cabinet-requote-required',
            'title': 'changed',
            'detail': 'untrusted localized detail',
            'code': 'URGENT_CABINET_REQUOTE_REQUIRED',
          }),
        ]);
        final repository = AppUrgentCabinetTargetedRequestRepository(
          _client(adapter),
        );

        await expectLater(
          repository.submit(
            submission: _submission(),
            idempotencyKey: _idempotencyKey,
          ),
          throwsA(
            isA<UrgentCabinetPatientRequestFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  UrgentCabinetPatientRequestFailureKind.requoteRequired,
                )
                .having(
                  (failure) => failure.code,
                  'code',
                  'URGENT_CABINET_REQUOTE_REQUIRED',
                ),
          ),
        );
      },
    );

    test('maps the backend development gate to rollout unavailable', () async {
      final adapter = _QueueAdapter([
        const _QueuedResponse(404, {
          'code': 'URGENT_CABINET_REQUEST_UNAVAILABLE',
        }),
      ]);
      final repository = AppUrgentCabinetTargetedRequestRepository(
        _client(adapter),
      );

      await expectLater(
        repository.submit(
          submission: _submission(),
          idempotencyKey: _idempotencyKey,
        ),
        throwsA(
          isA<UrgentCabinetPatientRequestFailure>().having(
            (failure) => failure.kind,
            'kind',
            UrgentCabinetPatientRequestFailureKind.rolloutUnavailable,
          ),
        ),
      );
    });
  });

  group('submission coordinator', () {
    test(
      'secure receipt persistence contains no clinical or target data',
      () async {
        final backend = _MemoryReceiptStorageBackend();
        final store = SecureUrgentCabinetRecoveryReceiptStore(backend: backend);

        await store.save(
          const UrgentCabinetRecoveryReceipt(
            accountId: _accountId,
            idempotencyKey: _idempotencyKey,
          ),
        );

        final persisted = jsonDecode(backend.value!) as Map<String, dynamic>;
        expect(persisted.keys.toSet(), {
          'schemaVersion',
          'accountScope',
          'receiptKey',
        });
        expect(backend.value, isNot(contains('front-head')));
        expect(backend.value, isNot(contains(_doctorId)));
        expect(backend.value, isNot(contains(_familyId)));
        expect(backend.value, isNot(contains('Douleur')));
      },
    );

    test('duplicate taps share exactly one in-flight submission', () async {
      final repository = _FakeRequestRepository();
      final store = _MemoryReceiptStore();
      final coordinator = UrgentCabinetSubmissionCoordinator(
        repository: repository,
        receiptStore: store,
        idempotencyKeyFactory: () => _idempotencyKey,
      );
      addTearDown(coordinator.dispose);
      final submission = _submission();

      final first = coordinator.submit(
        accountId: _accountId,
        submission: submission,
      );
      final second = coordinator.submit(
        accountId: _accountId,
        submission: submission,
      );
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(repository.submitCalls, 1);
      expect(store.receipt?.idempotencyKey, _idempotencyKey);

      repository.submitCompleter.complete(_pendingSnapshot());
      expect(
        (await first).kind,
        UrgentCabinetSubmissionResultKind.acknowledged,
      );
    });

    test('ambiguous POST performs receipt recovery before returning', () async {
      final repository = _FakeRequestRepository(
        submitFailure: const UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.network,
          message: 'network',
        ),
        recovered: _pendingSnapshot(replayed: true),
      );
      final coordinator = UrgentCabinetSubmissionCoordinator(
        repository: repository,
        receiptStore: _MemoryReceiptStore(),
        idempotencyKeyFactory: () => _idempotencyKey,
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.submit(
        accountId: _accountId,
        submission: _submission(),
      );

      expect(result.kind, UrgentCabinetSubmissionResultKind.recovered);
      expect(repository.submitCalls, 1);
      expect(repository.recoverCalls, 1);
      expect(repository.lastRecoveryKey, _idempotencyKey);
    });

    test('an uncertain retry never sends a second POST blindly', () async {
      final notFound = const UrgentCabinetPatientRequestFailure(
        kind: UrgentCabinetPatientRequestFailureKind.notFound,
        message: 'not found',
      );
      final repository = _FakeRequestRepository(
        submitFailure: const UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.timeout,
          message: 'timeout',
        ),
        recoverFailure: notFound,
      );
      final coordinator = UrgentCabinetSubmissionCoordinator(
        repository: repository,
        receiptStore: _MemoryReceiptStore(),
        idempotencyKeyFactory: () => _idempotencyKey,
      );
      addTearDown(coordinator.dispose);

      final first = await coordinator.submit(
        accountId: _accountId,
        submission: _submission(),
      );
      final second = await coordinator.submit(
        accountId: _accountId,
        submission: _submission(),
      );

      expect(first.kind, UrgentCabinetSubmissionResultKind.unknownOutcome);
      expect(second.kind, UrgentCabinetSubmissionResultKind.unknownOutcome);
      expect(repository.submitCalls, 1);
      expect(repository.recoverCalls, 2);
    });

    test(
      'changed clinical content cannot bypass an uncertain request',
      () async {
        final repository = _FakeRequestRepository(
          submitFailure: const UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.timeout,
            message: 'timeout',
          ),
          recoverFailure: const UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.notFound,
            message: 'not found',
          ),
        );
        final coordinator = UrgentCabinetSubmissionCoordinator(
          repository: repository,
          receiptStore: _MemoryReceiptStore(),
          idempotencyKeyFactory: () => _idempotencyKey,
        );
        addTearDown(coordinator.dispose);

        await coordinator.submit(
          accountId: _accountId,
          submission: _submission(),
        );
        final changed = await coordinator.submit(
          accountId: _accountId,
          submission: _submission(areas: const ['front-hand-left']),
        );

        expect(changed.kind, UrgentCabinetSubmissionResultKind.unknownOutcome);
        expect(repository.submitCalls, 1);
        expect(repository.recoverCalls, 1);
      },
    );

    test('changed immutable content receives a new logical key', () async {
      final repository = _FakeRequestRepository(
        submitFailure: const UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.targetUnavailable,
          message: 'unavailable',
        ),
      );
      final keys = <String>[
        _idempotencyKey,
        '88888888-8888-4888-8888-888888888888',
      ].iterator;
      final coordinator = UrgentCabinetSubmissionCoordinator(
        repository: repository,
        receiptStore: _MemoryReceiptStore(),
        idempotencyKeyFactory: () {
          keys.moveNext();
          return keys.current;
        },
      );
      addTearDown(coordinator.dispose);

      await coordinator.submit(
        accountId: _accountId,
        submission: _submission(),
      );
      await coordinator.submit(
        accountId: _accountId,
        submission: _submission(areas: const ['front-hand-left']),
      );

      expect(repository.submissionKeys, [
        _idempotencyKey,
        '88888888-8888-4888-8888-888888888888',
      ]);
    });

    test('logout clears receipt and fences a stale async result', () async {
      final repository = _FakeRequestRepository();
      final store = _MemoryReceiptStore();
      final coordinator = UrgentCabinetSubmissionCoordinator(
        repository: repository,
        receiptStore: store,
        idempotencyKeyFactory: () => _idempotencyKey,
      );
      addTearDown(coordinator.dispose);
      final result = coordinator.submit(
        accountId: _accountId,
        submission: _submission(),
      );
      await Future<void>.delayed(Duration.zero);

      await coordinator.invalidateSession(_accountId);
      repository.submitCompleter.complete(_pendingSnapshot());

      expect((await result).kind, UrgentCabinetSubmissionResultKind.obsolete);
      expect(store.receipt, isNull);
    });

    test('restart recovery reads only an opaque receipt key', () async {
      final store = _MemoryReceiptStore()
        ..receipt = const UrgentCabinetRecoveryReceipt(
          accountId: _accountId,
          idempotencyKey: _idempotencyKey,
        );
      final repository = _FakeRequestRepository(
        recovered: _pendingSnapshot(replayed: true),
      );
      final coordinator = UrgentCabinetSubmissionCoordinator(
        repository: repository,
        receiptStore: store,
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.recoverAfterRestart(
        accountId: _accountId,
        subject: const UrgentCabinetCareSubject.self(),
      );

      expect(result.kind, UrgentCabinetSubmissionResultKind.recovered);
      expect(repository.recoverCalls, 1);
      expect(repository.activeCalls, 0);
    });

    test(
      'restart without a receipt uses the subject-scoped active read',
      () async {
        final repository = _FakeRequestRepository(
          recovered: _pendingSnapshot(),
        );
        final coordinator = UrgentCabinetSubmissionCoordinator(
          repository: repository,
          receiptStore: _MemoryReceiptStore(),
        );
        addTearDown(coordinator.dispose);

        final result = await coordinator.recoverAfterRestart(
          accountId: _accountId,
          subject: const UrgentCabinetCareSubject.self(),
        );

        expect(result.kind, UrgentCabinetSubmissionResultKind.recovered);
        expect(repository.recoverCalls, 0);
        expect(repository.activeCalls, 1);
      },
    );
  });
}

class _MemoryTokenStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _QueuedResponse {
  const _QueuedResponse(this.statusCode, this.body);
  final int statusCode;
  final Object body;
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<_QueuedResponse> responses;
  final List<RequestOptions> requests = [];
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream == null) {
      bodies.add(null);
    } else {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      bodies.add(jsonDecode(utf8.decode(bytes)));
    }
    final next = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(next.body),
      next.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        HttpHeaders.cacheControlHeader: ['no-store'],
      },
    );
  }
}

AppHttpClient _client(_QueueAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  final refreshDio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenStorage()),
    baseUrl: 'https://example.test',
    dio: dio,
    refreshDio: refreshDio,
  );
}

class _MemoryReceiptStore implements UrgentCabinetRecoveryReceiptStore {
  UrgentCabinetRecoveryReceipt? receipt;

  @override
  Future<void> clearForAccount(String accountId) async {
    if (receipt?.accountId == accountId) receipt = null;
  }

  @override
  Future<UrgentCabinetRecoveryReceipt?> readForAccount(String accountId) async {
    return receipt?.accountId == accountId ? receipt : null;
  }

  @override
  Future<void> save(UrgentCabinetRecoveryReceipt value) async {
    receipt = value;
  }
}

class _MemoryReceiptStorageBackend
    implements UrgentCabinetReceiptStorageBackend {
  String? value;

  @override
  Future<void> delete({required String key}) async => value = null;

  @override
  Future<String?> read({required String key}) async => value;

  @override
  Future<void> write({required String key, required String value}) async {
    this.value = value;
  }
}

class _FakeRequestRepository implements UrgentCabinetTargetedRequestRepository {
  _FakeRequestRepository({
    this.submitFailure,
    this.recoverFailure,
    this.recovered,
  });

  final UrgentCabinetPatientRequestFailure? submitFailure;
  final UrgentCabinetPatientRequestFailure? recoverFailure;
  final UrgentCabinetTargetedRequestSnapshot? recovered;
  final Completer<UrgentCabinetTargetedRequestSnapshot> submitCompleter =
      Completer<UrgentCabinetTargetedRequestSnapshot>();
  int submitCalls = 0;
  int recoverCalls = 0;
  int activeCalls = 0;
  String? lastRecoveryKey;
  final List<String> submissionKeys = [];

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> submit({
    required UrgentCabinetTargetedSubmission submission,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    submitCalls++;
    submissionKeys.add(idempotencyKey);
    final failure = submitFailure;
    if (failure != null) return Future.error(failure);
    return submitCompleter.future;
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> recover(
    String idempotencyKey, {
    CancelToken? cancelToken,
  }) {
    recoverCalls++;
    lastRecoveryKey = idempotencyKey;
    final failure = recoverFailure;
    if (failure != null) return Future.error(failure);
    final value = recovered;
    if (value == null) {
      return Future.error(
        const UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.notFound,
          message: 'not found',
        ),
      );
    }
    return Future.value(value);
  }

  @override
  Future<UrgentCabinetTargetedRequestSnapshot> active(
    UrgentCabinetCareSubject subject, {
    CancelToken? cancelToken,
  }) {
    activeCalls++;
    final value = recovered;
    if (value == null) {
      return Future.error(
        const UrgentCabinetPatientRequestFailure(
          kind: UrgentCabinetPatientRequestFailureKind.notFound,
          message: 'not found',
        ),
      );
    }
    return Future.value(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
