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
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_location_provider.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_presence_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_presence_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_runtime_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_runtime_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_workspace_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap.dart';

final _now = DateTime.utc(2026, 10, 16, 9);

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _PresenceAdapter implements HttpClientAdapter {
  RequestOptions? request;
  int statusCode = 200;
  Object body = {
    'status': 'AVAILABLE',
    'updateId': '11111111-1111-4111-8111-111111111111',
    'observedAt': '2026-10-16T09:00:00Z',
    'receivedAt': '2026-10-16T09:00:01Z',
    'expiresAt': '2026-10-16T09:05:01Z',
  };

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _RuntimeRepository implements DoctorUrgentRuntimeRepositoryContract {
  DoctorUrgentRuntimeSnapshot result = _runtime(home: true);
  int getCalls = 0;

  @override
  Future<DoctorUrgentRuntimeSnapshot> get({CancelToken? cancelToken}) async {
    getCalls++;
    return result;
  }

  @override
  Future<DoctorUrgentRuntimeSnapshot> replace({
    required int expectedRevision,
    required bool homeEnabled,
    required bool cabinetEnabled,
  }) async => result;
}

class _PresenceRepository implements DoctorHomePresenceRepositoryContract {
  final calls = <DoctorHomePresenceUpdate>[];
  final results = <Object>[];
  Completer<DoctorHomeLocationPresence>? completer;

  @override
  Future<DoctorHomeLocationPresence> publish(
    DoctorHomePresenceUpdate update, {
    CancelToken? cancelToken,
  }) {
    calls.add(update);
    final pending = completer;
    if (pending != null) return pending.future;
    final result = results.removeAt(0);
    if (result is DoctorHomeLocationPresence) return Future.value(result);
    return Future.error(result);
  }
}

class _LocationProvider implements DoctorHomeLocationProvider {
  @override
  bool isSupported = true;
  bool serviceEnabled = true;
  DoctorForegroundLocationPermission permission =
      DoctorForegroundLocationPermission.granted;
  DoctorForegroundLocationPermission requestedPermission =
      DoctorForegroundLocationPermission.granted;
  final observations = <DoctorDeviceLocationObservation>[];
  Completer<DoctorDeviceLocationObservation>? completer;
  int serviceCalls = 0;
  int checkCalls = 0;
  int requestCalls = 0;
  int positionCalls = 0;

  @override
  Future<DoctorForegroundLocationPermission> checkPermission() async {
    checkCalls++;
    return permission;
  }

  @override
  Future<DoctorDeviceLocationObservation> currentObservation() {
    positionCalls++;
    final pending = completer;
    if (pending != null) return pending.future;
    return Future.value(observations.removeAt(0));
  }

  @override
  Future<bool> isServiceEnabled() async {
    serviceCalls++;
    return serviceEnabled;
  }

  @override
  Future<DoctorForegroundLocationPermission>
  requestForegroundPermission() async {
    requestCalls++;
    permission = requestedPermission;
    return requestedPermission;
  }
}

DoctorHomeLocationPresence _accepted({
  String updateId = '11111111-1111-4111-8111-111111111111',
  DateTime? observedAt,
}) => DoctorHomeLocationPresence(
  status: DoctorLocationPresenceStatus.available,
  updateId: updateId,
  observedAt: observedAt ?? _now,
  receivedAt: _now.add(const Duration(seconds: 1)),
  expiresAt: _now.add(const Duration(minutes: 5)),
);

DoctorDeviceLocationObservation _observation({
  DateTime? observedAt,
  double latitude = 35,
  double longitude = 10,
  double accuracy = 12.5,
  bool simulated = false,
}) => DoctorDeviceLocationObservation(
  latitude: latitude,
  longitude: longitude,
  horizontalAccuracyMeters: accuracy,
  observedAt: observedAt ?? _now,
  isSimulated: simulated,
);

DoctorUrgentRuntimeModeStatus _mode(bool enabled, {bool presence = true}) =>
    DoctorUrgentRuntimeModeStatus(
      runtimeIntentEnabled: enabled,
      activationPrerequisitesSatisfied: true,
      capacityAvailable: true,
      operationalPresenceReady: presence,
      runtimeFoundationReady: enabled && presence,
      requestSpecificEligibilityEvaluated: false,
      effectiveCurrentEligibility: false,
      blockingReasons: const [
        DoctorUrgentReadinessReason.requestSpecificEligibilityNotEvaluated,
      ],
    );

DoctorUrgentRuntimeSnapshot _runtime({
  required bool home,
  bool cabinet = false,
  DoctorHomeLocationPresence? presence,
}) => DoctorUrgentRuntimeSnapshot(
  revision: 4,
  homeEnabled: home,
  cabinetEnabled: cabinet,
  home: _mode(
    home,
    presence: presence?.status == DoctorLocationPresenceStatus.available,
  ),
  cabinet: _mode(cabinet),
  homeLocationPresence:
      presence ??
      const DoctorHomeLocationPresence(
        status: DoctorLocationPresenceStatus.missing,
      ),
  evaluatedAt: _now,
);

DoctorWorkspaceBootstrap _workspace({
  String doctorId = 'doctor-a',
  bool homeCapability = true,
  bool cabinetCapability = false,
  bool homeIntent = true,
}) {
  final capabilities = <DoctorServerCareCapability>{
    if (homeCapability) DoctorServerCareCapability.urgentHome,
    if (cabinetCapability) DoctorServerCareCapability.urgentCabinet,
  };
  return DoctorWorkspaceBootstrap(
    doctorId: doctorId,
    serverCapabilities: capabilities,
    capabilityRevision: 2,
    configuration: const DoctorUrgentConfigurationSnapshot(
      revision: 2,
      homeFeeConfigured: true,
      homeTravelDistanceConfigured: true,
      cabinetFeeConfigured: true,
    ),
    readiness: DoctorUrgentReadinessSnapshot(
      revision: 2,
      professionalEligible: true,
      home: DoctorUrgentModeReadiness(
        capabilityEnabled: homeCapability,
        configurationReady: homeCapability,
        runtimeAvailabilityIntent: homeIntent,
        effectiveCurrentEligibility: false,
        blockingReasons: const [],
      ),
      cabinet: DoctorUrgentModeReadiness(
        capabilityEnabled: cabinetCapability,
        configurationReady: cabinetCapability,
        runtimeAvailabilityIntent: false,
        effectiveCurrentEligibility: false,
        blockingReasons: const [],
      ),
      completeLiveMatchingEligibilityEvaluated: false,
      evaluatedAt: _now,
    ),
    activeCabinets: const [],
    runtime: _runtime(home: homeIntent, cabinet: cabinetCapability),
  );
}

DioException _problem(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/me/urgent-runtime/location-presence'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(
      path: '/me/urgent-runtime/location-presence',
    ),
    statusCode: status,
    data: {'code': code},
  ),
  type: DioExceptionType.badResponse,
);

DioException _timeout() => DioException(
  requestOptions: RequestOptions(path: '/me/urgent-runtime/location-presence'),
  type: DioExceptionType.receiveTimeout,
);

({
  DoctorHomePresenceController presence,
  DoctorUrgentRuntimeController runtime,
  _RuntimeRepository runtimeRepository,
})
_controller(
  _PresenceRepository repository,
  _LocationProvider provider, {
  DoctorWorkspaceBootstrap? workspace,
}) {
  final runtimeRepository = _RuntimeRepository();
  final runtime = DoctorUrgentRuntimeController(repository: runtimeRepository);
  final current = workspace ?? _workspace();
  runtimeRepository.result = current.runtime!;
  runtime.attachWorkspace(current);
  final presence = DoctorHomePresenceController(
    repository: repository,
    locationProvider: provider,
    runtimeController: runtime,
    publicationInterval: const Duration(hours: 1),
    retryDelay: Duration.zero,
    clock: () => _now,
  )..attachWorkspace(current);
  addTearDown(presence.dispose);
  addTearDown(runtime.dispose);
  return (
    presence: presence,
    runtime: runtime,
    runtimeRepository: runtimeRepository,
  );
}

void main() {
  group('location-presence HTTP contract', () {
    test('sends the exact DTO without Doctor or mission authority', () async {
      final adapter = _PresenceAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryStorage()),
        baseUrl: 'https://api.test',
        dio: dio,
        refreshDio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(() => client.close(force: true));
      final update = DoctorHomePresenceUpdate(
        updateId: '11111111-1111-4111-8111-111111111111',
        observedAt: _now,
        latitude: 35,
        longitude: 10,
        horizontalAccuracyMeters: 12.5,
      );

      final response = await DoctorHomePresenceRepository(
        client,
      ).publish(update);

      expect(adapter.request?.method, 'PUT');
      expect(
        adapter.request?.uri.path,
        '/api/v1/me/urgent-runtime/location-presence',
      );
      expect(adapter.request?.data, update.toJson());
      expect((adapter.request?.data as Map).keys, {
        'updateId',
        'observedAt',
        'latitude',
        'longitude',
        'horizontalAccuracyMeters',
      });
      expect(response.status, DoctorLocationPresenceStatus.available);
      expect(response.expiresAt, DateTime.utc(2026, 10, 16, 9, 5, 1));
    });

    test('maps altered duplicate and Redis failures without raw data', () {
      expect(
        DoctorHomePresenceFailure.from(
          _problem(409, 'LOCATION_OBSERVATION_OUT_OF_ORDER'),
        ).kind,
        DoctorHomePresenceFailureKind.outOfOrder,
      );
      expect(
        DoctorHomePresenceFailure.from(
          _problem(503, 'LOCATION_PRESENCE_UNAVAILABLE'),
        ).kind,
        DoctorHomePresenceFailureKind.dependencyUnavailable,
      );
    });
  });

  group('Doctor HOME foreground presence', () {
    test('never asks permission before explicit Doctor action', () {
      final repository = _PresenceRepository();
      final provider = _LocationProvider();
      final value = _controller(repository, provider);

      expect(value.presence.canStart, isTrue);
      expect(provider.checkCalls, 0);
      expect(provider.requestCalls, 0);
      expect(provider.positionCalls, 0);
      expect(repository.calls, isEmpty);
    });

    test('HOME-only Doctor with zero Cabinets can publish', () async {
      final repository = _PresenceRepository()..results.add(_accepted());
      final provider = _LocationProvider()..observations.add(_observation());
      final value = _controller(repository, provider);

      await value.presence.startOrRefresh();

      expect(repository.calls, hasLength(1));
      expect(value.presence.state, DoctorHomePresenceState.updated);
      expect(value.presence.statusLabel, 'Position actualisée');
    });

    test('CABINET-only Doctor never invokes GPS', () async {
      final repository = _PresenceRepository();
      final provider = _LocationProvider();
      final value = _controller(
        repository,
        provider,
        workspace: _workspace(
          homeCapability: false,
          cabinetCapability: true,
          homeIntent: false,
        ),
      );

      await value.presence.startOrRefresh();

      expect(value.presence.canStart, isFalse);
      expect(provider.serviceCalls, 0);
      expect(repository.calls, isEmpty);
    });

    test('both urgent modes still use HOME alone for GPS', () async {
      final repository = _PresenceRepository()..results.add(_accepted());
      final provider = _LocationProvider()..observations.add(_observation());
      final value = _controller(
        repository,
        provider,
        workspace: _workspace(cabinetCapability: true),
      );

      await value.presence.startOrRefresh();

      expect(provider.positionCalls, 1);
      expect(repository.calls, hasLength(1));
    });

    test('HOME intent OFF prevents permission and acquisition', () async {
      final repository = _PresenceRepository();
      final provider = _LocationProvider();
      final value = _controller(
        repository,
        provider,
        workspace: _workspace(homeIntent: false),
      );

      await value.presence.startOrRefresh();

      expect(value.presence.state, DoctorHomePresenceState.inactive);
      expect(provider.checkCalls, 0);
      expect(repository.calls, isEmpty);
    });

    test(
      'denied permission remains recoverable without changing intent',
      () async {
        final repository = _PresenceRepository();
        final provider = _LocationProvider()
          ..permission = DoctorForegroundLocationPermission.denied
          ..requestedPermission = DoctorForegroundLocationPermission.denied;
        final value = _controller(repository, provider);

        await value.presence.startOrRefresh();

        expect(provider.requestCalls, 1);
        expect(
          value.presence.state,
          DoctorHomePresenceState.permissionRequired,
        );
        expect(value.runtime.snapshot?.homeEnabled, isTrue);
        expect(repository.calls, isEmpty);
      },
    );

    test(
      'permanently denied and unavailable permissions fail closed',
      () async {
        for (final permission in [
          DoctorForegroundLocationPermission.deniedForever,
          DoctorForegroundLocationPermission.unavailable,
        ]) {
          final repository = _PresenceRepository();
          final provider = _LocationProvider()..permission = permission;
          final value = _controller(repository, provider);

          await value.presence.startOrRefresh();

          expect(
            value.presence.state,
            DoctorHomePresenceState.permissionDenied,
          );
          expect(repository.calls, isEmpty);
        }
      },
    );

    test('disabled location services fail before permission lookup', () async {
      final repository = _PresenceRepository();
      final provider = _LocationProvider()..serviceEnabled = false;
      final value = _controller(repository, provider);

      await value.presence.startOrRefresh();

      expect(value.presence.state, DoctorHomePresenceState.serviceDisabled);
      expect(provider.checkCalls, 0);
      expect(repository.calls, isEmpty);
    });

    test(
      'invalid stale inaccurate and simulated measurements stay local',
      () async {
        final cases =
            <(DoctorDeviceLocationObservation, DoctorHomePresenceState)>[
              (
                _observation(latitude: double.nan),
                DoctorHomePresenceState.invalid,
              ),
              (
                _observation(
                  observedAt: _now.subtract(const Duration(minutes: 2)),
                ),
                DoctorHomePresenceState.expired,
              ),
              (_observation(accuracy: 101), DoctorHomePresenceState.inaccurate),
              (_observation(simulated: true), DoctorHomePresenceState.invalid),
            ];
        for (final entry in cases) {
          final repository = _PresenceRepository();
          final provider = _LocationProvider()..observations.add(entry.$1);
          final value = _controller(repository, provider);

          await value.presence.startOrRefresh();

          expect(value.presence.state, entry.$2);
          expect(repository.calls, isEmpty);
        }
      },
    );

    test(
      'newer measurements replace older and older fixes are suppressed',
      () async {
        final first = _now.subtract(const Duration(seconds: 20));
        final second = _now.subtract(const Duration(seconds: 5));
        final repository = _PresenceRepository()
          ..results.addAll([
            _accepted(observedAt: first),
            _accepted(observedAt: second),
          ]);
        final provider = _LocationProvider()
          ..observations.addAll([
            _observation(observedAt: first),
            _observation(observedAt: second),
            _observation(observedAt: first),
          ]);
        final value = _controller(repository, provider);

        await value.presence.startOrRefresh();
        await value.presence.startOrRefresh();
        await value.presence.startOrRefresh();

        expect(repository.calls, hasLength(2));
        expect(value.presence.state, DoctorHomePresenceState.outOfOrder);
      },
    );

    test('503 retries once with the exact same update payload', () async {
      final repository = _PresenceRepository()
        ..results.addAll([
          _problem(503, 'LOCATION_PRESENCE_UNAVAILABLE'),
          _accepted(),
        ]);
      final provider = _LocationProvider()..observations.add(_observation());
      final value = _controller(repository, provider);

      await value.presence.startOrRefresh();

      expect(repository.calls, hasLength(2));
      expect(repository.calls[1].updateId, repository.calls[0].updateId);
      expect(repository.calls[1].toJson(), repository.calls[0].toJson());
      expect(value.presence.state, DoctorHomePresenceState.updated);
    });

    test('network timeout is bounded and never fabricates freshness', () async {
      final repository = _PresenceRepository()
        ..results.addAll([_timeout(), _timeout()]);
      final provider = _LocationProvider()..observations.add(_observation());
      final value = _controller(repository, provider);

      await value.presence.startOrRefresh();

      expect(repository.calls, hasLength(2));
      expect(value.presence.state, DoctorHomePresenceState.failure);
      expect(
        value.presence.serverPresence?.status,
        DoctorLocationPresenceStatus.missing,
      );
    });

    test(
      'out-of-order 409 reconciles rather than overwriting authority',
      () async {
        final repository = _PresenceRepository()
          ..results.add(_problem(409, 'LOCATION_OBSERVATION_OUT_OF_ORDER'));
        final provider = _LocationProvider()..observations.add(_observation());
        final value = _controller(repository, provider);

        await value.presence.startOrRefresh();

        expect(value.presence.state, DoctorHomePresenceState.outOfOrder);
        expect(value.runtimeRepository.getCalls, 1);
      },
    );

    test('rollout 404 and session rejection stop publication', () async {
      final rolloutRepository = _PresenceRepository()
        ..results.add(_problem(404, 'URGENT_RUNTIME_UNAVAILABLE'));
      final rolloutProvider = _LocationProvider()
        ..observations.add(_observation());
      final rollout = _controller(rolloutRepository, rolloutProvider);
      await rollout.presence.startOrRefresh();
      expect(rollout.presence.state, DoctorHomePresenceState.unavailable);
      expect(rollout.presence.isForegroundPublicationActive, isFalse);

      var rejected = 0;
      final sessionRepository = _PresenceRepository()
        ..results.add(_problem(401, 'UNAUTHORIZED'));
      final sessionProvider = _LocationProvider()
        ..observations.add(_observation());
      final runtimeRepository = _RuntimeRepository();
      final runtime = DoctorUrgentRuntimeController(
        repository: runtimeRepository,
      )..attachWorkspace(_workspace());
      final session = DoctorHomePresenceController(
        repository: sessionRepository,
        locationProvider: sessionProvider,
        runtimeController: runtime,
        onSessionRejected: () => rejected++,
        publicationInterval: const Duration(hours: 1),
        retryDelay: Duration.zero,
        clock: () => _now,
      )..attachWorkspace(_workspace());
      addTearDown(session.dispose);
      addTearDown(runtime.dispose);
      await session.startOrRefresh();
      expect(rejected, 1);
      expect(session.isForegroundPublicationActive, isFalse);
    });

    test(
      'background pauses and foreground requires explicit restart',
      () async {
        final repository = _PresenceRepository()..results.add(_accepted());
        final provider = _LocationProvider()..observations.add(_observation());
        final value = _controller(repository, provider);
        await value.presence.startOrRefresh();

        value.presence.pauseForBackground();
        value.presence.resumeForeground();
        await Future<void>.delayed(Duration.zero);

        expect(value.presence.state, DoctorHomePresenceState.paused);
        expect(value.presence.isForegroundPublicationActive, isFalse);
        expect(repository.calls, hasLength(1));
      },
    );

    test('permission revocation stops the bounded foreground cycle', () async {
      final repository = _PresenceRepository()..results.add(_accepted());
      final provider = _LocationProvider()..observations.add(_observation());
      final runtimeRepository = _RuntimeRepository();
      final runtime = DoctorUrgentRuntimeController(
        repository: runtimeRepository,
      )..attachWorkspace(_workspace());
      final presence = DoctorHomePresenceController(
        repository: repository,
        locationProvider: provider,
        runtimeController: runtime,
        publicationInterval: const Duration(milliseconds: 5),
        retryDelay: Duration.zero,
        clock: () => _now,
      )..attachWorkspace(_workspace());
      addTearDown(presence.dispose);
      addTearDown(runtime.dispose);

      await presence.startOrRefresh();
      provider.permission = DoctorForegroundLocationPermission.denied;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(presence.state, DoctorHomePresenceState.permissionRequired);
      expect(presence.isForegroundPublicationActive, isFalse);
      expect(repository.calls, hasLength(1));
    });

    test('account switch discards an in-flight native GPS result', () async {
      final repository = _PresenceRepository();
      final provider = _LocationProvider()
        ..completer = Completer<DoctorDeviceLocationObservation>();
      final value = _controller(repository, provider);
      final pending = value.presence.startOrRefresh();
      await Future<void>.delayed(Duration.zero);

      value.presence.attachWorkspace(_workspace(doctorId: 'doctor-b'));
      provider.completer!.complete(_observation());
      await pending;

      expect(repository.calls, isEmpty);
      expect(value.presence.serverPresence?.updateId, isNull);
    });

    test(
      'runtime OFF cancels an in-flight upload and keeps response inert',
      () async {
        final repository = _PresenceRepository()
          ..completer = Completer<DoctorHomeLocationPresence>();
        final provider = _LocationProvider()..observations.add(_observation());
        final value = _controller(repository, provider);
        final pending = value.presence.startOrRefresh();
        while (repository.calls.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }

        value.presence.stopForRuntimeOff();
        repository.completer!.complete(_accepted());
        await pending;

        expect(value.presence.state, DoctorHomePresenceState.inactive);
        expect(value.presence.serverPresence?.updateId, isNull);
        expect(value.presence.isForegroundPublicationActive, isFalse);
      },
    );

    test('unsupported platform fails closed without touching GPS', () async {
      final repository = _PresenceRepository();
      final provider = _LocationProvider()..isSupported = false;
      final value = _controller(repository, provider);

      await value.presence.startOrRefresh();

      expect(value.presence.state, DoctorHomePresenceState.unsupported);
      expect(provider.serviceCalls, 0);
      expect(repository.calls, isEmpty);
    });

    test(
      'presence package has no persistence logging offer or realtime dependency',
      () {
        final source = [
          'lib/features/doctor/urgent/doctor_home_location_provider.dart',
          'lib/features/doctor/urgent/doctor_home_presence_controller.dart',
          'lib/features/doctor/urgent/doctor_home_presence_repository.dart',
        ].map((path) => File(path).readAsStringSync()).join('\n');

        expect(source, isNot(contains('shared_preferences')));
        expect(source, isNot(contains('flutter_secure_storage')));
        expect(source, isNot(contains('debugPrint')));
        expect(source, isNot(contains('print(')));
        expect(source, isNot(contains('offer')));
        expect(source, isNot(contains('websocket')));
        expect(source, isNot(contains('missionId')));
      },
    );

    testWidgets(
      'frozen HOME workspace adds one explicit foreground action without eligibility claim',
      (tester) async {
        final repository = _PresenceRepository()..results.add(_accepted());
        final provider = _LocationProvider()..observations.add(_observation());
        final value = _controller(repository, provider);
        final homeController = DoctorUrgentController();
        final cabinetController = DoctorUrgentCabinetController();
        addTearDown(homeController.dispose);
        addTearDown(cabinetController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Scaffold(
              body: DoctorUrgentWorkspaceScreen(
                capabilities: const {DoctorCapability.urgentHomeRequests},
                workspaceConfig: null,
                selectedMode: DoctorUrgentMode.home,
                onModeChanged: (_) {},
                homeController: homeController,
                urgentCabinetController: cabinetController,
                homeOperationalMessage:
                    'Les demandes réelles restent désactivées.',
                runtimeController: value.runtime,
                homePresenceController: value.presence,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('doctor-home-presence-card')),
          findsOneWidget,
        );
        expect(find.text('Position requise'), findsOneWidget);
        expect(
          find.text('Disponible pour recevoir des demandes'),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('doctor-home-presence-action')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Position actualisée'), findsOneWidget);
        expect(repository.calls, hasLength(1));
        value.presence.clear();
        await tester.pump();
      },
    );
  });
}
