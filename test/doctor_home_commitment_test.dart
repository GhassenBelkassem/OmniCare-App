import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment_repository.dart';

final _now = DateTime.utc(2026, 10, 16, 11);
const _commitmentId = '11111111-1111-4111-8111-111111111111';
const _journeyId = '22222222-2222-4222-8222-222222222222';
const _offerId = '33333333-3333-4333-8333-333333333333';

Map<String, Object?> _commitmentJson({
  String commitmentId = _commitmentId,
  String status = 'ACTIVE',
  int revision = 4,
  num fee = 75,
}) => {
  'commitmentId': commitmentId,
  'journeyId': _journeyId,
  'selectedOfferId': _offerId,
  'status': status,
  'revision': revision,
  'quotedHomeFeeTnd': fee,
  'currency': 'TND',
  'committedAt': _now.subtract(const Duration(minutes: 5)).toIso8601String(),
  'terminalAt': status == 'ACTIVE' ? null : _now.toIso8601String(),
  'updatedAt': _now.toIso8601String(),
  'availableActions': <String>[],
  'evaluatedAt': _now.toIso8601String(),
};

DoctorHomeCommitment _commitment({String status = 'ACTIVE'}) =>
    parseDoctorHomeCommitment(_commitmentJson(status: status));

DoctorHomeActiveCommitment _active(DoctorHomeCommitment commitment) =>
    DoctorHomeActiveCommitment(
      result: DoctorHomeActiveCommitmentResult.activeCommitment,
      commitment: commitment,
      evaluatedAt: _now,
    );

DoctorHomeActiveCommitment _none() => DoctorHomeActiveCommitment(
  result: DoctorHomeActiveCommitmentResult.noActiveCommitment,
  evaluatedAt: _now,
);

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _CommitmentHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <Object>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = responses.removeAt(0);
    if (result is DioException) throw result;
    return ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        HttpHeaders.cacheControlHeader: ['no-store'],
      },
    );
  }
}

class _CommitmentRepository implements DoctorHomeCommitmentRepositoryContract {
  final activeResults = <Object>[];
  final detailResults = <Object>[];
  int activeCalls = 0;
  final detailCalls = <String>[];

  @override
  Future<DoctorHomeActiveCommitment> findActive({CancelToken? cancelToken}) {
    activeCalls++;
    final result = activeResults.removeAt(0);
    if (result is Future<DoctorHomeActiveCommitment>) return result;
    if (result is DoctorHomeActiveCommitment) return Future.value(result);
    return Future.error(result);
  }

  @override
  Future<DoctorHomeCommitment> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) {
    detailCalls.add(commitmentId);
    final result = detailResults.removeAt(0);
    if (result is Future<DoctorHomeCommitment>) return result;
    if (result is DoctorHomeCommitment) return Future.value(result);
    return Future.error(result);
  }
}

DioException _problem(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/me/urgent-home/commitments'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/me/urgent-home/commitments'),
    statusCode: status,
    data: {'code': code},
  ),
);

void main() {
  group('P4-08 Doctor HOME commitment contract', () {
    test('known rollout unavailability suppresses commitment HTTP reads', () async {
      final repository = _CommitmentRepository();
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachDoctor('doctor-a');
      controller.synchronizeRolloutAccess(available: false);

      await controller.refresh();

      expect(controller.state, DoctorHomeCommitmentState.unavailable);
      expect(repository.activeCalls, 0);
    });

    test('parses active, cancelled and invalidated exact response shapes', () {
      final active = _commitment();
      final cancelled = _commitment(status: 'CANCELLED');
      final invalidated = _commitment(status: 'INVALIDATED');

      expect(active.isActive, isTrue);
      expect(active.quotedHomeFeeTnd, '75.000');
      expect(cancelled.status, DoctorHomeCommitmentStatus.cancelled);
      expect(cancelled.terminalAt, isNotNull);
      expect(invalidated.status, DoctorHomeCommitmentStatus.invalidated);
    });

    test('rejects invented states, actions, scale and terminal shapes', () {
      expect(
        () => parseDoctorHomeCommitment({
          ..._commitmentJson(),
          'status': 'EN_ROUTE',
        }),
        throwsFormatException,
      );
      expect(
        () => parseDoctorHomeCommitment({
          ..._commitmentJson(),
          'availableActions': ['START_MISSION'],
        }),
        throwsFormatException,
      );
      expect(
        () => parseDoctorHomeCommitment({
          ..._commitmentJson(),
          'quotedHomeFeeTnd': 1.2345,
        }),
        throwsFormatException,
      );
      expect(
        () => parseDoctorHomeCommitment({
          ..._commitmentJson(),
          'terminalAt': _now.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('enforces ACTIVE_COMMITMENT and NO_ACTIVE_COMMITMENT shapes', () {
      final active = parseDoctorHomeActiveCommitment({
        'result': 'ACTIVE_COMMITMENT',
        'commitment': _commitmentJson(),
        'evaluatedAt': _now.toIso8601String(),
      });
      final none = parseDoctorHomeActiveCommitment({
        'result': 'NO_ACTIVE_COMMITMENT',
        'commitment': null,
        'evaluatedAt': _now.toIso8601String(),
      });
      expect(active.commitment?.isActive, isTrue);
      expect(none.commitment, isNull);
      expect(
        () => parseDoctorHomeActiveCommitment({
          'result': 'ACTIVE_COMMITMENT',
          'commitment': null,
          'evaluatedAt': _now.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test(
      'uses only authenticated active and exact-detail GET routes',
      () async {
        final adapter = _CommitmentHttpAdapter()
          ..responses.add({
            'result': 'ACTIVE_COMMITMENT',
            'commitment': _commitmentJson(),
            'evaluatedAt': _now.toIso8601String(),
          })
          ..responses.add(_commitmentJson());
        final dio = Dio()..httpClientAdapter = adapter;
        final client = AppHttpClient(
          tokenStore: SecureTokenStore(backend: _MemoryStorage()),
          baseUrl: 'https://api.test',
          dio: dio,
          refreshDio: Dio(),
        );
        addTearDown(() => client.close(force: true));
        final repository = DoctorHomeCommitmentRepository(client);

        await repository.findActive();
        await repository.get(_commitmentId);

        expect(adapter.requests.map((request) => request.method), [
          'GET',
          'GET',
        ]);
        expect(adapter.requests.map((request) => request.path), [
          '/me/urgent-home/commitments/active',
          '/me/urgent-home/commitments/$_commitmentId',
        ]);
        expect(
          adapter.requests.every(
            (request) =>
                request.data == null &&
                request.queryParameters.isEmpty &&
                request.headers['Cache-Control'] == 'no-store',
          ),
          isTrue,
        );
      },
    );

    test('maps exact 404, 503, session and network semantics', () {
      expect(
        DoctorHomeCommitmentFailure.from(
          _problem(404, 'HOME_COMMITMENT_NOT_FOUND'),
        ).kind,
        DoctorHomeCommitmentFailureKind.notFound,
      );
      expect(
        DoctorHomeCommitmentFailure.from(
          _problem(503, 'HOME_COMMITMENT_READ_UNAVAILABLE'),
        ).kind,
        DoctorHomeCommitmentFailureKind.unavailable,
      );
      expect(
        DoctorHomeCommitmentFailure.from(_problem(403, 'FORBIDDEN')).kind,
        DoctorHomeCommitmentFailureKind.sessionRejected,
      );
      expect(
        DoctorHomeCommitmentFailure.from(
          DioException(
            requestOptions: RequestOptions(path: '/active'),
            type: DioExceptionType.connectionError,
          ),
        ).kind,
        DoctorHomeCommitmentFailureKind.unavailable,
      );
    });
  });

  group('account-scoped HOME commitment recovery', () {
    test('authoritative empty is distinct from unavailable', () async {
      final repository = _CommitmentRepository()
        ..activeResults.add(_none())
        ..activeResults.add(_problem(503, 'HOME_COMMITMENT_READ_UNAVAILABLE'));
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load('doctor-a');
      expect(controller.state, DoctorHomeCommitmentState.noActiveCommitment);
      await controller.refresh();
      expect(controller.state, DoctorHomeCommitmentState.unavailable);
      expect(controller.commitment, isNull);
    });

    test('restores active responsibility independently on startup', () async {
      final repository = _CommitmentRepository()
        ..activeResults.add(_active(_commitment()));
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load('doctor-a');

      expect(controller.state, DoctorHomeCommitmentState.activeCommitment);
      expect(controller.commitment?.commitmentId, _commitmentId);
      expect(controller.hasVisibleResponsibility, isTrue);
    });

    test(
      'reconciles a known active ID to cancellation and invalidation',
      () async {
        final repository = _CommitmentRepository()
          ..activeResults.add(_active(_commitment()))
          ..activeResults.add(_none())
          ..detailResults.add(_commitment(status: 'CANCELLED'))
          ..activeResults.add(_none())
          ..detailResults.add(_commitment(status: 'INVALIDATED'));
        final controller = DoctorHomeCommitmentController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        await controller.load('doctor-a');
        await controller.refresh();
        expect(controller.state, DoctorHomeCommitmentState.terminalCommitment);
        expect(
          controller.commitment?.status,
          DoctorHomeCommitmentStatus.cancelled,
        );
        await controller.refresh();
        expect(
          controller.commitment?.status,
          DoctorHomeCommitmentStatus.invalidated,
        );
      },
    );

    test('foreign or deleted known detail becomes safe empty', () async {
      final repository = _CommitmentRepository()
        ..activeResults.add(_active(_commitment()))
        ..activeResults.add(_none())
        ..detailResults.add(_problem(404, 'HOME_COMMITMENT_NOT_FOUND'));
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load('doctor-a');
      await controller.refresh();

      expect(controller.state, DoctorHomeCommitmentState.noActiveCommitment);
      expect(controller.commitment, isNull);
    });

    test('newer refresh wins over an older delayed response', () async {
      final delayed = Completer<DoctorHomeActiveCommitment>();
      final newer = _commitment(status: 'ACTIVE');
      final repository = _CommitmentRepository()
        ..activeResults.add(delayed.future)
        ..activeResults.add(_active(newer));
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);

      controller.attachDoctor('doctor-a');
      final old = controller.refresh();
      await controller.refresh();
      delayed.complete(_none());
      await old;

      expect(controller.state, DoctorHomeCommitmentState.activeCommitment);
      expect(controller.commitment?.commitmentId, _commitmentId);
    });

    test('account switch fences the previous Doctor response', () async {
      final delayed = Completer<DoctorHomeActiveCommitment>();
      final doctorB = parseDoctorHomeCommitment(
        _commitmentJson(commitmentId: '44444444-4444-4444-8444-444444444444'),
      );
      final repository = _CommitmentRepository()
        ..activeResults.add(delayed.future)
        ..activeResults.add(_active(doctorB));
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);

      final old = controller.load('doctor-a');
      await controller.load('doctor-b');
      delayed.complete(_active(_commitment()));
      await old;

      expect(controller.commitment?.commitmentId, doctorB.commitmentId);
      expect(controller.state, DoctorHomeCommitmentState.activeCommitment);
    });

    test(
      'logout clear fences a delayed response and removes memory state',
      () async {
        final delayed = Completer<DoctorHomeActiveCommitment>();
        final repository = _CommitmentRepository()
          ..activeResults.add(delayed.future);
        final controller = DoctorHomeCommitmentController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        final request = controller.load('doctor-a');
        controller.clear();
        delayed.complete(_active(_commitment()));
        await request;

        expect(controller.state, DoctorHomeCommitmentState.initial);
        expect(controller.commitment, isNull);
        expect(controller.hasVisibleResponsibility, isFalse);
      },
    );
  });

  group('safe frozen Doctor presentation', () {
    testWidgets(
      'active responsibility survives capability removal without mission actions',
      (tester) async {
        final repository = _CommitmentRepository()
          ..activeResults.add(_active(_commitment()));
        final controller = DoctorHomeCommitmentController(
          repository: repository,
        );
        addTearDown(controller.dispose);
        await controller.load('doctor-a');

        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: DoctorAppShell(
              profile: DoctorDemoProfile.current,
              onLogout: () async {},
              authoritativeCapabilities: const {},
              homeCommitmentController: controller,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
        await tester.pumpAndSettle();

        expect(find.text('Engagement confirmé'), findsOneWidget);
        expect(find.text('75.000 TND'), findsOneWidget);
        expect(find.text('Amina Chaari'), findsNothing);
        expect(find.textContaining('Avenue Habib Bourguiba'), findsNothing);
        expect(find.textContaining('Douleur thoracique'), findsNothing);
        expect(find.text('Démarrer le trajet'), findsNothing);
        expect(find.text('Je suis arrivé'), findsNothing);
        expect(find.textContaining('Scanner le QR'), findsNothing);
      },
    );

    testWidgets('terminal state is explicit and never re-enables runtime', (
      tester,
    ) async {
      final repository = _CommitmentRepository()
        ..activeResults.add(_active(_commitment()))
        ..activeResults.add(_none())
        ..detailResults.add(_commitment(status: 'CANCELLED'));
      final controller = DoctorHomeCommitmentController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load('doctor-a');
      await controller.refresh();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: DoctorAppShell(
            profile: DoctorDemoProfile.current,
            onLogout: () async {},
            authoritativeCapabilities: const {},
            homeCommitmentController: controller,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
      await tester.pumpAndSettle();

      expect(find.text('Engagement annulé'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Activer ma position HOME'), findsNothing);
    });
  });
}
