import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_dispatch_context.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_dispatch_context_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_dispatch_context_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_offer.dart';

const _commitmentA = '11111111-1111-4111-8111-111111111111';
const _commitmentB = '44444444-4444-4444-8444-444444444444';
const _journeyId = '22222222-2222-4222-8222-222222222222';
const _offerId = '33333333-3333-4333-8333-333333333333';
final _now = DateTime.utc(2026, 10, 16, 12);

Map<String, Object?> _contextJson({
  String commitmentId = _commitmentA,
  int revision = 4,
  Object? latitude = 36.8065,
  Object? longitude = 10.1815,
  String mode = 'MAP_PIN',
  String provenance = 'PATIENT_MOVED_PIN',
  String? evaluatedAt,
}) => {
  'commitmentId': commitmentId,
  'commitmentRevision': revision,
  'evaluatedAt': evaluatedAt ?? _now.toIso8601String(),
  'destination': {
    'latitude': latitude,
    'longitude': longitude,
    'confirmedAddress': '15 Synthetic Avenue',
    'acquisitionMode': mode,
    'provenance': provenance,
    'confirmedAt': _now.subtract(const Duration(minutes: 2)).toIso8601String(),
  },
};

DoctorHomeDispatchContext _context({
  String commitmentId = _commitmentA,
  int revision = 4,
  String address = '15 Synthetic Avenue',
}) => DoctorHomeDispatchContext(
  commitmentId: commitmentId,
  commitmentRevision: revision,
  evaluatedAt: _now,
  destination: DoctorHomeDispatchDestination(
    latitude: 36.8065,
    longitude: 10.1815,
    confirmedAddress: address,
    acquisitionMode: DoctorHomeDestinationAcquisitionMode.mapPin,
    provenance: DoctorHomeDestinationProvenance.patientMovedPin,
    confirmedAt: _now.subtract(const Duration(minutes: 2)),
  ),
);

DoctorHomeCommitment _commitment({
  String commitmentId = _commitmentA,
  int revision = 4,
  DoctorHomeCommitmentStatus status = DoctorHomeCommitmentStatus.active,
}) => DoctorHomeCommitment(
  commitmentId: commitmentId,
  journeyId: _journeyId,
  selectedOfferId: _offerId,
  status: status,
  revision: revision,
  quotedHomeFeeTnd: '75.000',
  currency: 'TND',
  committedAt: _now.subtract(const Duration(minutes: 5)),
  terminalAt: status == DoctorHomeCommitmentStatus.active ? null : _now,
  updatedAt: _now,
  evaluatedAt: _now,
  availableActions: const [],
);

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _HttpAdapter implements HttpClientAdapter {
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
        HttpHeaders.cacheControlHeader: ['no-store', 'private'],
      },
    );
  }
}

class _DispatchRepository
    implements DoctorHomeDispatchContextRepositoryContract {
  final results = <Object>[];
  final calls = <String>[];

  @override
  Future<DoctorHomeDispatchContext> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) {
    calls.add(commitmentId);
    final result = results.removeAt(0);
    if (result is Future<DoctorHomeDispatchContext>) return result;
    if (result is DoctorHomeDispatchContext) return Future.value(result);
    return Future.error(result);
  }
}

class _CommitmentRepository implements DoctorHomeCommitmentRepositoryContract {
  _CommitmentRepository(this.value);

  final DoctorHomeCommitment value;

  @override
  Future<DoctorHomeActiveCommitment> findActive({CancelToken? cancelToken}) =>
      Future.value(
        DoctorHomeActiveCommitment(
          result: DoctorHomeActiveCommitmentResult.activeCommitment,
          commitment: value,
          evaluatedAt: _now,
        ),
      );

  @override
  Future<DoctorHomeCommitment> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) => Future.value(value);
}

DioException _problem(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/dispatch-context'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/dispatch-context'),
    statusCode: status,
    data: {'code': code},
  ),
);

void main() {
  group('P4-08 Doctor HOME dispatch-context contract', () {
    test('parses the exact destination projection and closed enums', () {
      final context = parseDoctorHomeDispatchContext(_contextJson());

      expect(context.commitmentId, _commitmentA);
      expect(context.commitmentRevision, 4);
      expect(context.destination.latitude, 36.8065);
      expect(context.destination.longitude, 10.1815);
      expect(context.destination.confirmedAddress, '15 Synthetic Avenue');
      expect(
        context.destination.acquisitionMode,
        DoctorHomeDestinationAcquisitionMode.mapPin,
      );
      expect(
        context.destination.provenance,
        DoctorHomeDestinationProvenance.patientMovedPin,
      );
      expect(context.destination.confirmedAt.isUtc, isTrue);
    });

    test('accepts every backend-supported mode and provenance pair', () {
      const pairs = {
        'CURRENT_GPS': 'DEVICE_GPS',
        'ADDRESS_SEARCH': 'ADDRESS_RESULT',
        'MAP_PIN': 'PATIENT_MOVED_PIN',
        'MANUAL_ADDRESS': 'MANUAL_ENTRY',
      };

      for (final entry in pairs.entries) {
        expect(
          () => parseDoctorHomeDispatchContext(
            _contextJson(mode: entry.key, provenance: entry.value),
          ),
          returnsNormally,
        );
      }
    });

    test('rejects invalid coordinates, revisions, enums and timestamps', () {
      for (final payload in [
        _contextJson(latitude: 90.1),
        _contextJson(longitude: -180.1),
        _contextJson(latitude: double.nan),
        _contextJson(revision: -1),
        _contextJson(mode: 'LIVE_TRACKING'),
        _contextJson(provenance: 'PATIENT_MOVED_PIN', mode: 'CURRENT_GPS'),
        _contextJson(evaluatedAt: 'not-an-instant'),
      ]) {
        expect(
          () => parseDoctorHomeDispatchContext(payload),
          throwsFormatException,
        );
      }
    });

    test('uses the authenticated exact GET with no request payload', () async {
      final adapter = _HttpAdapter()..responses.add(_contextJson());
      final dio = Dio()..httpClientAdapter = adapter;
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryStorage()),
        baseUrl: 'https://api.test',
        dio: dio,
        refreshDio: Dio(),
      );
      addTearDown(() => client.close(force: true));

      final result = await DoctorHomeDispatchContextRepository(
        client,
      ).get(_commitmentA);

      expect(result.commitmentId, _commitmentA);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.path,
        '/me/urgent-home/commitments/$_commitmentA/dispatch-context',
      );
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(adapter.requests.single.data, isNull);
      expect(adapter.requests.single.headers['Cache-Control'], 'no-store');
    });

    test('maps non-enumerating 404, 503, session and offline failures', () {
      expect(
        DoctorHomeDispatchContextFailure.from(
          _problem(404, 'HOME_DISPATCH_CONTEXT_NOT_FOUND'),
        ).kind,
        DoctorHomeDispatchContextFailureKind.notFound,
      );
      expect(
        DoctorHomeDispatchContextFailure.from(
          _problem(503, 'HOME_DISPATCH_CONTEXT_UNAVAILABLE'),
        ).kind,
        DoctorHomeDispatchContextFailureKind.unavailable,
      );
      expect(
        DoctorHomeDispatchContextFailure.from(_problem(403, 'FORBIDDEN')).kind,
        DoctorHomeDispatchContextFailureKind.sessionRejected,
      );
      expect(
        DoctorHomeDispatchContextFailure.from(
          DioException(
            requestOptions: RequestOptions(path: '/dispatch-context'),
            type: DioExceptionType.connectionError,
          ),
        ).kind,
        DoctorHomeDispatchContextFailureKind.unavailable,
      );
    });
  });

  group('account-scoped dispatch authorization', () {
    test('no active commitment or accepted hold causes no request', () async {
      final acceptedHold = DoctorHomeOffer(
        offerId: _offerId,
        status: DoctorHomeOfferStatus.acceptedHeld,
        revision: 3,
        responseDeadlineAt: _now.subtract(const Duration(minutes: 4)),
        holdExpiresAt: _now.add(const Duration(minutes: 2)),
        holdCurrentlyValid: true,
        quotedHomeFeeTnd: '75.000',
        currency: 'TND',
        replayed: false,
        updatedAt: _now,
        evaluatedAt: _now,
      );
      final repository = _DispatchRepository();
      final controller = DoctorHomeDispatchContextController(
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.attachDoctor('doctor-a');

      expect(acceptedHold.isAcceptedHold, isTrue);

      await controller.synchronizeCommitment(
        commitmentState: DoctorHomeCommitmentState.noActiveCommitment,
        commitment: null,
      );

      expect(repository.calls, isEmpty);
      expect(controller.dispatchContext, isNull);
      expect(controller.state, DoctorHomeDispatchContextState.initial);
    });

    test('active commitment requests and binds the exact revision', () async {
      final repository = _DispatchRepository()..results.add(_context());
      final controller = DoctorHomeDispatchContextController(
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.attachDoctor('doctor-a');

      await controller.synchronizeCommitment(
        commitmentState: DoctorHomeCommitmentState.activeCommitment,
        commitment: _commitment(),
      );

      expect(repository.calls, [_commitmentA]);
      expect(controller.state, DoctorHomeDispatchContextState.available);
      expect(
        controller.dispatchContext?.destination.confirmedAddress,
        '15 Synthetic Avenue',
      );
    });

    test('stale revision fails closed and exposes no destination', () async {
      final repository = _DispatchRepository()
        ..results.add(_context(revision: 3));
      final controller = DoctorHomeDispatchContextController(
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.attachDoctor('doctor-a');

      await controller.synchronizeCommitment(
        commitmentState: DoctorHomeCommitmentState.activeCommitment,
        commitment: _commitment(revision: 4),
      );

      expect(controller.state, DoctorHomeDispatchContextState.failure);
      expect(controller.dispatchContext, isNull);
    });

    test(
      'cancellation and invalidation immediately clear destination',
      () async {
        for (final terminalState in [
          DoctorHomeCommitmentStatus.cancelled,
          DoctorHomeCommitmentStatus.invalidated,
        ]) {
          final repository = _DispatchRepository()..results.add(_context());
          final controller = DoctorHomeDispatchContextController(
            repository: repository,
          );
          controller.attachDoctor('doctor-a');
          await controller.synchronizeCommitment(
            commitmentState: DoctorHomeCommitmentState.activeCommitment,
            commitment: _commitment(),
          );
          await controller.synchronizeCommitment(
            commitmentState: DoctorHomeCommitmentState.terminalCommitment,
            commitment: _commitment(status: terminalState),
          );

          expect(controller.dispatchContext, isNull);
          expect(controller.state, DoctorHomeDispatchContextState.initial);
          expect(repository.calls, [_commitmentA]);
          controller.dispose();
        }
      },
    );

    test(
      '404, 503 and offline failures remain distinct and fail closed',
      () async {
        final failures = <Object, DoctorHomeDispatchContextState>{
          _problem(404, 'HOME_DISPATCH_CONTEXT_NOT_FOUND'):
              DoctorHomeDispatchContextState.notFound,
          _problem(503, 'HOME_DISPATCH_CONTEXT_UNAVAILABLE'):
              DoctorHomeDispatchContextState.unavailable,
          DioException(
            requestOptions: RequestOptions(path: '/dispatch-context'),
            type: DioExceptionType.connectionError,
          ): DoctorHomeDispatchContextState.unavailable,
        };

        for (final entry in failures.entries) {
          final repository = _DispatchRepository()..results.add(entry.key);
          final controller = DoctorHomeDispatchContextController(
            repository: repository,
          );
          controller.attachDoctor('doctor-a');
          await controller.synchronizeCommitment(
            commitmentState: DoctorHomeCommitmentState.activeCommitment,
            commitment: _commitment(),
          );

          expect(controller.state, entry.value);
          expect(controller.dispatchContext, isNull);
          controller.dispose();
        }
      },
    );

    test(
      'duplicate active notifications share one in-flight request',
      () async {
        final delayed = Completer<DoctorHomeDispatchContext>();
        final repository = _DispatchRepository()..results.add(delayed.future);
        final controller = DoctorHomeDispatchContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);
        controller.attachDoctor('doctor-a');

        final first = controller.synchronizeCommitment(
          commitmentState: DoctorHomeCommitmentState.activeCommitment,
          commitment: _commitment(),
        );
        final duplicate = controller.synchronizeCommitment(
          commitmentState: DoctorHomeCommitmentState.activeCommitment,
          commitment: _commitment(),
        );

        expect(repository.calls, [_commitmentA]);
        delayed.complete(_context());
        await Future.wait([first, duplicate]);
        expect(controller.state, DoctorHomeDispatchContextState.available);
      },
    );

    test(
      'rapid account switch discards the preceding account response',
      () async {
        final delayed = Completer<DoctorHomeDispatchContext>();
        final repository = _DispatchRepository()
          ..results.add(delayed.future)
          ..results.add(
            _context(
              commitmentId: _commitmentB,
              revision: 9,
              address: '22 Synthetic Street',
            ),
          );
        final controller = DoctorHomeDispatchContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        controller.attachDoctor('doctor-a');
        final old = controller.synchronizeCommitment(
          commitmentState: DoctorHomeCommitmentState.activeCommitment,
          commitment: _commitment(),
        );
        controller.attachDoctor('doctor-b');
        await controller.synchronizeCommitment(
          commitmentState: DoctorHomeCommitmentState.activeCommitment,
          commitment: _commitment(commitmentId: _commitmentB, revision: 9),
        );
        delayed.complete(_context());
        await old;

        expect(repository.calls, [_commitmentA, _commitmentB]);
        expect(controller.dispatchContext?.commitmentId, _commitmentB);
        expect(
          controller.dispatchContext?.destination.confirmedAddress,
          '22 Synthetic Street',
        );
      },
    );

    test(
      'logout during fetch clears memory and rejects the late response',
      () async {
        final delayed = Completer<DoctorHomeDispatchContext>();
        final repository = _DispatchRepository()..results.add(delayed.future);
        final controller = DoctorHomeDispatchContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);
        controller.attachDoctor('doctor-a');

        final request = controller.synchronizeCommitment(
          commitmentState: DoctorHomeCommitmentState.activeCommitment,
          commitment: _commitment(),
        );
        controller.clear();
        delayed.complete(_context());
        await request;

        expect(controller.state, DoctorHomeDispatchContextState.initial);
        expect(controller.dispatchContext, isNull);
      },
    );
  });

  testWidgets(
    'authenticated responsibility uses only the existing address slot',
    (tester) async {
      final commitmentController = DoctorHomeCommitmentController(
        repository: _CommitmentRepository(_commitment()),
      );
      final dispatchRepository = _DispatchRepository()..results.add(_context());
      final dispatchController = DoctorHomeDispatchContextController(
        repository: dispatchRepository,
      );
      addTearDown(commitmentController.dispose);
      addTearDown(dispatchController.dispose);
      await commitmentController.load('doctor-a');
      dispatchController.attachDoctor('doctor-a');
      await dispatchController.synchronizeCommitment(
        commitmentState: commitmentController.state,
        commitment: commitmentController.commitment,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: DoctorAppShell(
            profile: DoctorDemoProfile.current,
            onLogout: () async {},
            authoritativeCapabilities: const {},
            homeCommitmentController: commitmentController,
            homeDispatchContextController: dispatchController,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
      await tester.pumpAndSettle();

      expect(find.text('15 Synthetic Avenue'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('doctor-home-dispatch-destination')),
        findsOneWidget,
      );
      expect(find.text('Amina Chaari'), findsNothing);
      expect(find.textContaining('Habib Bourguiba'), findsNothing);
      expect(find.textContaining('Douleur thoracique'), findsNothing);
      expect(find.text('Visites récentes'), findsNothing);
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.text('Démarrer le trajet'), findsNothing);
      expect(find.text('Je suis arrivé'), findsNothing);
      expect(find.textContaining('Scanner le QR'), findsNothing);
    },
  );
}
