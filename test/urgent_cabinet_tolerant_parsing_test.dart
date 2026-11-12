// G-2 1a-3 (C4, C5, C6, C8, C9). Logic only (CTO testing rule): server JSON
// shaped like `UrgentCabinetTargetedRequestResponse`, parsed by the real
// models and repositories behind the real AppHttpClient.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_models.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_repository.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_repository.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';
const _journeyId = '22222222-2222-4222-8222-222222222222';
const _doctorId = '33333333-3333-4333-8333-333333333333';
const _cabinetId = '44444444-4444-4444-8444-444444444444';
const _commitmentId = '55555555-5555-4555-8555-555555555555';
const _consultationId = '99999999-9999-4999-8999-999999999999';

/// Pending request, as `UrgentCabinetTargetedService.patientResponse` sends it.
Map<String, Object?> _pending() => {
  'requestId': _requestId,
  'journeyId': _journeyId,
  'subjectType': 'SELF',
  'familyMemberId': null,
  'doctorId': _doctorId,
  'practiceLocationId': _cabinetId,
  'doctorDisplayName': 'Dr Synthétique',
  'specialty': 'Médecine générale',
  'cabinetName': 'Cabinet synthétique',
  'cabinetAddress': '1 rue synthétique',
  'governorate': 'Tunis',
  'city': 'Tunis',
  'cabinetLatitude': null,
  'cabinetLongitude': null,
  'quotedFeeTnd': 75.000,
  'currency': 'TND',
  'configurationRevision': 7,
  'runtimeRevision': 8,
  'practiceLocationVersion': 9,
  'responseStatus': 'PENDING',
  'responseRevision': 0,
  'respondedAt': null,
  'commitmentId': null,
  'commitmentStatus': null,
  'commitmentRevision': null,
  'committedAt': null,
  'arrivalVerifiedAt': null,
  'state': 'CABINET_PENDING',
  'requestRevision': 1,
  'journeyRevision': 1,
  'createdAt': '2026-10-18T10:00:00Z',
  'responseDeadlineAt': '2026-10-18T10:05:00Z',
  'terminalAt': null,
  'terminalReason': null,
  'allowedActions': ['CANCEL'],
  'replayed': false,
  'evaluatedAt': '2026-10-18T10:00:30Z',
  'clinicalPhase': null,
  'consultationId': null,
  'consultationStatus': null,
};

/// Request cancelled before any answer (shape of DB check `0530`).
Map<String, Object?> _cancelledBeforeAnswer(String reason) => {
  ..._pending(),
  'responseStatus': 'CANCELLED',
  'responseRevision': 1,
  'state': 'CABINET_CANCELLED',
  'terminalAt': '2026-10-18T10:02:00Z',
  'terminalReason': reason,
  'allowedActions': <String>[],
};

/// Accepted request whose patient arrival was verified.
Map<String, Object?> _arrived({
  String clinicalPhase = 'ARRIVED_WAITING_FOR_DOCTOR',
  String? consultationStatus,
  String commitmentStatus = 'ACTIVE',
}) => {
  ..._pending(),
  'responseStatus': 'ACCEPTED',
  'responseRevision': 1,
  'respondedAt': '2026-10-18T10:01:00Z',
  'commitmentId': _commitmentId,
  'commitmentStatus': commitmentStatus,
  'commitmentRevision': 2,
  'committedAt': '2026-10-18T10:01:00Z',
  'arrivalVerifiedAt': '2026-10-18T10:20:00Z',
  'state': 'CABINET_COMMITTED',
  'terminalAt': '2026-10-18T10:01:00Z',
  'allowedActions': <String>[],
  'clinicalPhase': clinicalPhase,
  'consultationId': consultationStatus == null ? null : _consultationId,
  'consultationStatus': consultationStatus,
};

UrgentCabinetTargetedRequestSnapshot _parse(Map<String, Object?> json) =>
    UrgentCabinetTargetedRequestSnapshot.fromJson(json.cast());

void main() {
  group('server enums: every known value, unknown fallback', () {
    test('responseStatus', () {
      const known = {
        'PENDING': UrgentCabinetPatientResponseStatus.pending,
        'ACCEPTED': UrgentCabinetPatientResponseStatus.accepted,
        'DECLINED': UrgentCabinetPatientResponseStatus.declined,
        'CANCELLED': UrgentCabinetPatientResponseStatus.cancelled,
        'EXPIRED': UrgentCabinetPatientResponseStatus.expired,
      };
      known.forEach((wire, value) {
        expect(UrgentCabinetPatientResponseStatus.parse(wire), value);
      });
      expect(
        UrgentCabinetPatientResponseStatus.parse('ON_HOLD'),
        UrgentCabinetPatientResponseStatus.unknown,
      );
    });

    test('state (backend UrgentAttemptState)', () {
      const known = {
        'CABINET_CREATED': UrgentCabinetPatientAttemptState.cabinetCreated,
        'CABINET_PENDING': UrgentCabinetPatientAttemptState.cabinetPending,
        'CABINET_COMMITTED': UrgentCabinetPatientAttemptState.cabinetCommitted,
        'CABINET_CANCELLED': UrgentCabinetPatientAttemptState.cabinetCancelled,
      };
      known.forEach((wire, value) {
        expect(UrgentCabinetPatientAttemptState.parse(wire), value);
      });
      for (final home in [
        'HOME_CREATED',
        'HOME_MATCHING',
        'HOME_HELD',
        'HOME_COMMITTED',
        'HOME_EXHAUSTED',
        'HOME_CANCELLED',
      ]) {
        expect(
          UrgentCabinetPatientAttemptState.parse(home),
          UrgentCabinetPatientAttemptState.unknown,
          reason: home,
        );
      }
    });

    test('terminalReason (backend UrgentCabinetTerminalReason)', () {
      const known = {
        'DOCTOR_DECLINED': UrgentCabinetPatientTerminalReason.doctorDeclined,
        'PATIENT_CANCELLED':
            UrgentCabinetPatientTerminalReason.patientCancelled,
        'PATIENT_WITHDREW_AFTER_ACCEPTANCE':
            UrgentCabinetPatientTerminalReason.patientWithdrewAfterAcceptance,
        'RESPONSE_DEADLINE_ELAPSED':
            UrgentCabinetPatientTerminalReason.responseDeadlineElapsed,
        'LEGACY_LIFECYCLE_REMEDIATION':
            UrgentCabinetPatientTerminalReason.legacyLifecycleRemediation,
      };
      known.forEach((wire, value) {
        expect(UrgentCabinetPatientTerminalReason.parse(wire), value);
      });
      expect(
        UrgentCabinetPatientTerminalReason.parse('NEW_REASON'),
        UrgentCabinetPatientTerminalReason.unknown,
      );
    });

    test('commitmentStatus', () {
      const known = {
        'ACTIVE': UrgentCabinetPatientCommitmentStatus.active,
        'CANCELLED': UrgentCabinetPatientCommitmentStatus.cancelled,
        'INVALIDATED': UrgentCabinetPatientCommitmentStatus.invalidated,
        'COMPLETED': UrgentCabinetPatientCommitmentStatus.completed,
      };
      known.forEach((wire, value) {
        expect(UrgentCabinetPatientCommitmentStatus.parse(wire), value);
      });
      expect(
        UrgentCabinetPatientCommitmentStatus.parse('SUSPENDED'),
        UrgentCabinetPatientCommitmentStatus.unknown,
      );
    });

    test('clinicalPhase', () {
      const known = {
        'CONFIRMED_TRAVEL_TO_CABINET':
            UrgentCabinetPatientClinicalPhase.confirmedTravelToCabinet,
        'ARRIVED_WAITING_FOR_DOCTOR':
            UrgentCabinetPatientClinicalPhase.arrivedWaitingForDoctor,
        'CONSULTATION_IN_PROGRESS':
            UrgentCabinetPatientClinicalPhase.consultationInProgress,
        'CARE_COMPLETED': UrgentCabinetPatientClinicalPhase.careCompleted,
      };
      known.forEach((wire, value) {
        expect(UrgentCabinetPatientClinicalPhase.parseNullable(wire), value);
      });
      expect(UrgentCabinetPatientClinicalPhase.parseNullable(null), isNull);
      expect(
        UrgentCabinetPatientClinicalPhase.parseNullable('NEW_PHASE'),
        UrgentCabinetPatientClinicalPhase.unknown,
      );
    });

    test('the literal "UNKNOWN" is not a known value either', () {
      expect(
        UrgentCabinetPatientResponseStatus.parse('UNKNOWN'),
        UrgentCabinetPatientResponseStatus.unknown,
      );
    });
  });

  group('one unknown value never fails the whole snapshot', () {
    test('baseline pending snapshot is recognized', () {
      final snapshot = _parse(_pending());
      expect(snapshot.isRecognized, isTrue);
      expect(snapshot.allowedActions, ['CANCEL']);
    });

    final unknownCases = <String, Map<String, Object?>>{
      'HOME_* state': {..._pending(), 'state': 'HOME_MATCHING'},
      'unknown state': {..._pending(), 'state': 'CABINET_PAUSED'},
      'unknown responseStatus': {..._pending(), 'responseStatus': 'ON_HOLD'},
      'unknown terminalReason': _cancelledBeforeAnswer('OPERATOR_CLOSED'),
      'unknown clinicalPhase': _arrived(clinicalPhase: 'NEW_PHASE'),
      'unknown commitmentStatus': _arrived(commitmentStatus: 'SUSPENDED'),
      'unknown consultationStatus': _arrived(
        clinicalPhase: 'CONSULTATION_IN_PROGRESS',
        consultationStatus: 'PAUSED',
      ),
    };
    unknownCases.forEach((name, json) {
      test('$name: parses, not recognized', () {
        final snapshot = _parse(json);
        expect(snapshot.isRecognized, isFalse);
        expect(snapshot.requestId, _requestId);
      });
    });

    test('unknown server action is ignored, the rest is validated', () {
      final snapshot = _parse({
        ..._pending(),
        'allowedActions': ['CANCEL', 'RESCHEDULE'],
      });
      expect(snapshot.isRecognized, isTrue);
      expect(snapshot.allowedActions, ['CANCEL']);
    });

    test('duplicate actions remain a contract violation', () {
      expect(
        () => _parse({
          ..._pending(),
          'allowedActions': ['CANCEL', 'CANCEL'],
        }),
        throwsFormatException,
      );
    });

    test('an incoherent combination of KNOWN values still fails', () {
      expect(
        () => _parse({..._pending(), 'state': 'CABINET_COMMITTED'}),
        throwsFormatException,
      );
    });

    test('a malformed structural field still fails', () {
      expect(
        () => _parse({..._pending(), 'requestId': 'not-a-uuid'}),
        throwsFormatException,
      );
    });
  });

  group('C4: CABINET_CREATED (pre-pending) is shown as pending', () {
    test('pending + CABINET_CREATED + no action parses as pending', () {
      final snapshot = _parse({
        ..._pending(),
        'state': 'CABINET_CREATED',
        'allowedActions': <String>[],
      });
      expect(snapshot.isRecognized, isTrue);
      expect(
        snapshot.responseStatus,
        UrgentCabinetPatientResponseStatus.pending,
      );
      expect(
        snapshot.attemptState,
        UrgentCabinetPatientAttemptState.cabinetCreated,
      );
      expect(snapshot.allowedActions, isEmpty);
      expect(snapshot.isTerminal, isFalse);
    });

    test(
      'CABINET_CREATED offering CANCEL is incoherent (backend never does)',
      () {
        expect(
          () => _parse({..._pending(), 'state': 'CABINET_CREATED'}),
          throwsFormatException,
        );
      },
    );
  });

  group('C5: LEGACY_LIFECYCLE_REMEDIATION is a closed (cancelled) request', () {
    test('cancelled before answer with the legacy reason parses', () {
      final snapshot = _parse(
        _cancelledBeforeAnswer('LEGACY_LIFECYCLE_REMEDIATION'),
      );
      expect(snapshot.isRecognized, isTrue);
      expect(
        snapshot.responseStatus,
        UrgentCabinetPatientResponseStatus.cancelled,
      );
      expect(
        snapshot.terminalReason,
        UrgentCabinetPatientTerminalReason.legacyLifecycleRemediation,
      );
      expect(snapshot.isTerminal, isTrue);
    });

    test('legacy reason after an acceptance is incoherent (DB forbids it)', () {
      expect(
        () => _parse({
          ..._cancelledBeforeAnswer('LEGACY_LIFECYCLE_REMEDIATION'),
          'respondedAt': '2026-10-18T10:01:00Z',
          'commitmentId': _commitmentId,
          'commitmentStatus': 'CANCELLED',
          'commitmentRevision': 2,
          'committedAt': '2026-10-18T10:01:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('C6: arrived, consultation aborted', () {
    test('ARRIVED_WAITING_FOR_DOCTOR with an ABORTED consultation parses', () {
      final snapshot = _parse(_arrived(consultationStatus: 'ABORTED'));
      expect(snapshot.isRecognized, isTrue);
      expect(
        snapshot.clinicalPhase,
        UrgentCabinetPatientClinicalPhase.arrivedWaitingForDoctor,
      );
      expect(snapshot.consultationId, _consultationId);
      expect(snapshot.consultationStatus, 'ABORTED');
    });

    test('ARRIVED_WAITING_FOR_DOCTOR without consultation still parses', () {
      final snapshot = _parse(_arrived());
      expect(snapshot.consultationId, isNull);
    });

    for (final status in ['IN_PROGRESS', 'FINALIZING', 'COMPLETED']) {
      test('ARRIVED_WAITING_FOR_DOCTOR with $status is still incoherent', () {
        expect(
          () => _parse(_arrived(consultationStatus: status)),
          throwsFormatException,
        );
      });
    }
  });

  group('repository: unrecognized snapshot → existing « indisponible »', () {
    test('HOME_* state is reported like an unreadable response', () async {
      final server = _Server(200, {..._pending(), 'state': 'HOME_HELD'});
      await expectLater(
        _requests(server).status(_requestId),
        throwsA(
          isA<UrgentCabinetPatientRequestFailure>().having(
            (f) => f.kind,
            'kind',
            UrgentCabinetPatientRequestFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('same failure kind as a malformed response', () async {
      final unknown = _Server(200, {..._pending(), 'state': 'HOME_HELD'});
      final malformed = _Server(200, {'nope': true});
      Future<UrgentCabinetPatientRequestFailureKind> kindOf(_Server s) async {
        try {
          await _requests(s).status(_requestId);
        } on UrgentCabinetPatientRequestFailure catch (failure) {
          return failure.kind;
        }
        fail('expected a failure');
      }

      expect(await kindOf(unknown), await kindOf(malformed));
    });

    test('mapped values come through as snapshots', () async {
      final legacy = await _requests(
        _Server(200, _cancelledBeforeAnswer('LEGACY_LIFECYCLE_REMEDIATION')),
      ).status(_requestId);
      expect(
        legacy.responseStatus,
        UrgentCabinetPatientResponseStatus.cancelled,
      );

      final aborted = await _requests(
        _Server(200, _arrived(consultationStatus: 'ABORTED')),
      ).status(_requestId);
      expect(
        aborted.clinicalPhase,
        UrgentCabinetPatientClinicalPhase.arrivedWaitingForDoctor,
      );
    });
  });

  group('C9: one « indisponible » mapping for search and detail', () {
    const featureCodes = [
      'URGENT_CABINET_REQUEST_UNAVAILABLE',
      'URGENT_CABINET_REQUEST_NOT_AUTHORIZED',
    ];
    for (final code in featureCodes) {
      test('404 $code: search and detail → featureUnavailable', () async {
        final search = await _discoveryFailure(
          (repo) => repo.search(const UrgentCabinetDiscoveryCriteria()),
          _Server(404, _problem(code)),
        );
        final detail = await _discoveryFailure(
          (repo) =>
              repo.detail(doctorId: _doctorId, practiceLocationId: _cabinetId),
          _Server(404, _problem(code)),
        );
        final facets = await _discoveryFailure(
          (repo) => repo.facets(),
          _Server(404, _problem(code)),
        );
        for (final failure in [search, detail, facets]) {
          expect(
            failure.kind,
            UrgentCabinetDiscoveryFailureKind.featureUnavailable,
          );
          expect(failure.isFeatureUnavailable, isTrue);
          expect(failure.isNotFound, isFalse);
        }
      });
    }

    test(
      'detail 404 URGENT_CABINET_DIRECTORY_ENTRY_NOT_FOUND → notFound',
      () async {
        final failure = await _discoveryFailure(
          (repo) =>
              repo.detail(doctorId: _doctorId, practiceLocationId: _cabinetId),
          _Server(404, _problem('URGENT_CABINET_DIRECTORY_ENTRY_NOT_FOUND')),
        );
        expect(failure.kind, UrgentCabinetDiscoveryFailureKind.notFound);
      },
    );

    test(
      'search 404 without code (collection route) → featureUnavailable',
      () async {
        final failure = await _discoveryFailure(
          (repo) => repo.search(const UrgentCabinetDiscoveryCriteria()),
          _Server(404, const {}),
        );
        expect(
          failure.kind,
          UrgentCabinetDiscoveryFailureKind.featureUnavailable,
        );
      },
    );

    test(
      '403 (any code) → forbidden; the dead development-gate branch is gone',
      () async {
        for (final code in [
          'URGENT_RUNTIME_DEVELOPMENT_ONLY',
          'URGENT_RUNTIME_ACCESS_DISABLED',
          'OTHER',
        ]) {
          final failure = await _discoveryFailure(
            (repo) => repo.detail(
              doctorId: _doctorId,
              practiceLocationId: _cabinetId,
            ),
            _Server(403, _problem(code)),
          );
          expect(failure.kind, UrgentCabinetDiscoveryFailureKind.forbidden);
        }
      },
    );
  });

  group('C8: search query limited to 120', () {
    final formatter = urgentCabinetSearchInputFormatters.single;
    TextEditingValue edit(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('typing or pasting past 120 is truncated to 120', () {
      final result = formatter.formatEditUpdate(
        edit('a' * 119),
        edit('a' * 200),
      );
      expect(result.text.length, urgentCabinetSearchQueryMaxLength);
      expect(urgentCabinetSearchQueryMaxLength, 120);
    });

    test('120 or fewer characters pass unchanged', () {
      final result = formatter.formatEditUpdate(edit(''), edit('b' * 120));
      expect(result.text, 'b' * 120);
    });

    test('request body never carries more than 120 UTF-16 units', () {
      final body = UrgentCabinetDiscoveryCriteria(query: 'c' * 300).toJson();
      expect((body['query']! as String).length, 120);
    });

    test('clamp never splits a character (emoji = 2 UTF-16 units)', () {
      final clamped = clampToUtf16Length('${'d' * 119}😀', 120);
      expect(clamped, 'd' * 119);
      expect(clampToUtf16Length('😀😀', 4), '😀😀');
    });

    test('short queries are only trimmed', () {
      final body = const UrgentCabinetDiscoveryCriteria(
        query: '  cardio ',
      ).toJson();
      expect(body['query'], 'cardio');
    });
  });
}

Map<String, Object?> _problem(String code) => {
  'type': 'about:blank',
  'title': 'Resource not found',
  'status': 404,
  'detail': 'The requested resource is not available.',
  'code': code,
};

AppHttpClient _client(_Server server) => AppHttpClient(
  tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
  baseUrl: 'https://api.test',
  dio: Dio()..httpClientAdapter = server,
  refreshDio: Dio(),
);

AppUrgentCabinetTargetedRequestRepository _requests(_Server server) =>
    AppUrgentCabinetTargetedRequestRepository(_client(server));

Future<UrgentCabinetDiscoveryFailure> _discoveryFailure(
  Future<Object?> Function(AppUrgentCabinetDiscoveryRepository repo) call,
  _Server server,
) async {
  try {
    await call(AppUrgentCabinetDiscoveryRepository(_client(server)));
  } on UrgentCabinetDiscoveryFailure catch (failure) {
    return failure;
  }
  fail('expected an UrgentCabinetDiscoveryFailure');
}

class _Server implements HttpClientAdapter {
  _Server(this.status, this.body);

  final int status;
  final Map<String, Object?> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
