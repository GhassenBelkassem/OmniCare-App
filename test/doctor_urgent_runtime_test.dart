import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_runtime_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_runtime_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_workspace_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_api.dart';

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _RuntimeAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({
        'revision': 8,
        'homeEnabled': true,
        'cabinetEnabled': false,
        'capacityState': 'FREE',
        'home': {
          'runtimeIntentEnabled': true,
          'activationPrerequisitesSatisfied': true,
          'capacityAvailable': true,
          'operationalPresenceReady': false,
          'runtimeFoundationReady': false,
          'requestSpecificEligibilityEvaluated': false,
          'effectiveCurrentEligibility': false,
          'blockingReasons': [
            'LOCATION_MISSING',
            'REQUEST_SPECIFIC_ELIGIBILITY_NOT_EVALUATED',
          ],
        },
        'cabinet': {
          'runtimeIntentEnabled': false,
          'activationPrerequisitesSatisfied': true,
          'capacityAvailable': true,
          'operationalPresenceReady': true,
          'runtimeFoundationReady': false,
          'requestSpecificEligibilityEvaluated': false,
          'effectiveCurrentEligibility': false,
          'blockingReasons': [
            'RUNTIME_CABINET_INTENT_DISABLED',
            'REQUEST_SPECIFIC_ELIGIBILITY_NOT_EVALUATED',
          ],
        },
        'homeLocationPresence': {
          'status': 'MISSING',
          'updateId': null,
          'observedAt': null,
          'receivedAt': null,
          'expiresAt': null,
        },
        'completeRequestSpecificEligibilityEvaluated': false,
        'evaluatedAt': '2026-10-16T09:00:00Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _ReplaceCall {
  const _ReplaceCall({
    required this.expectedRevision,
    required this.homeEnabled,
    required this.cabinetEnabled,
  });

  final int expectedRevision;
  final bool homeEnabled;
  final bool cabinetEnabled;
}

class _RuntimeRepository implements DoctorUrgentRuntimeRepositoryContract {
  DoctorUrgentRuntimeSnapshot? getResult;
  DoctorUrgentRuntimeSnapshot? replaceResult;
  Object? getError;
  Object? replaceError;
  Completer<DoctorUrgentRuntimeSnapshot>? getCompleter;
  Completer<DoctorUrgentRuntimeSnapshot>? replaceCompleter;
  final replaceCalls = <_ReplaceCall>[];
  int getCalls = 0;

  @override
  Future<DoctorUrgentRuntimeSnapshot> get({CancelToken? cancelToken}) {
    getCalls++;
    final completer = getCompleter;
    if (completer != null) return completer.future;
    final error = getError;
    if (error != null) return Future.error(error);
    return Future.value(getResult!);
  }

  @override
  Future<DoctorUrgentRuntimeSnapshot> replace({
    required int expectedRevision,
    required bool homeEnabled,
    required bool cabinetEnabled,
  }) {
    replaceCalls.add(
      _ReplaceCall(
        expectedRevision: expectedRevision,
        homeEnabled: homeEnabled,
        cabinetEnabled: cabinetEnabled,
      ),
    );
    final completer = replaceCompleter;
    if (completer != null) return completer.future;
    final error = replaceError;
    if (error != null) return Future.error(error);
    return Future.value(replaceResult!);
  }
}

DoctorUrgentRuntimeModeStatus _modeStatus({
  required bool enabled,
  bool prerequisites = true,
  bool capacity = true,
  bool presence = true,
  List<DoctorUrgentReadinessReason> reasons = const [],
}) => DoctorUrgentRuntimeModeStatus(
  runtimeIntentEnabled: enabled,
  activationPrerequisitesSatisfied: prerequisites,
  capacityAvailable: capacity,
  operationalPresenceReady: presence,
  runtimeFoundationReady: enabled && prerequisites && capacity && presence,
  requestSpecificEligibilityEvaluated: false,
  effectiveCurrentEligibility: false,
  blockingReasons: reasons,
);

DoctorUrgentRuntimeSnapshot _runtime({
  int revision = 2,
  bool home = false,
  bool cabinet = false,
  DoctorUrgentCapacityState capacity = DoctorUrgentCapacityState.free,
  bool homePresence = true,
  List<DoctorUrgentReadinessReason> homeReasons = const [],
  List<DoctorUrgentReadinessReason> cabinetReasons = const [],
}) => DoctorUrgentRuntimeSnapshot(
  revision: revision,
  homeEnabled: home,
  cabinetEnabled: cabinet,
  capacityState: capacity,
  home: _modeStatus(
    enabled: home,
    capacity: capacity == DoctorUrgentCapacityState.free,
    presence: homePresence,
    reasons: homeReasons,
  ),
  cabinet: _modeStatus(
    enabled: cabinet,
    capacity: capacity == DoctorUrgentCapacityState.free,
    reasons: cabinetReasons,
  ),
  homeLocationPresence: DoctorHomeLocationPresence(
    status: homePresence
        ? DoctorLocationPresenceStatus.available
        : DoctorLocationPresenceStatus.missing,
  ),
  evaluatedAt: DateTime.utc(2026, 10, 16),
);

DoctorWorkspaceBootstrap _workspace({
  String doctorId = 'doctor-a',
  Set<DoctorServerCareCapability> capabilities = const {
    DoctorServerCareCapability.urgentHome,
    DoctorServerCareCapability.urgentCabinet,
  },
  bool homeConfigured = true,
  bool cabinetConfigured = true,
  bool professionalEligible = true,
  DoctorUrgentRuntimeSnapshot? runtime,
  DoctorUrgentRuntimeBootstrapAccess? runtimeAccess,
}) {
  final hasHome = capabilities.contains(DoctorServerCareCapability.urgentHome);
  final hasCabinet = capabilities.contains(
    DoctorServerCareCapability.urgentCabinet,
  );
  return DoctorWorkspaceBootstrap(
    doctorId: doctorId,
    serverCapabilities: capabilities,
    capabilityRevision: 8,
    configuration: DoctorUrgentConfigurationSnapshot(
      revision: 8,
      homeFeeConfigured: homeConfigured,
      homeTravelDistanceConfigured: homeConfigured,
      cabinetFeeConfigured: cabinetConfigured,
    ),
    readiness: DoctorUrgentReadinessSnapshot(
      revision: 8,
      professionalEligible: professionalEligible,
      home: DoctorUrgentModeReadiness(
        capabilityEnabled: hasHome,
        configurationReady: hasHome && homeConfigured,
        runtimeAvailabilityIntent: runtime?.homeEnabled ?? false,
        effectiveCurrentEligibility: false,
        blockingReasons: hasHome && homeConfigured
            ? const [DoctorUrgentReadinessReason.runtimeHomeIntentDisabled]
            : const [DoctorUrgentReadinessReason.homeFeeNotConfigured],
      ),
      cabinet: DoctorUrgentModeReadiness(
        capabilityEnabled: hasCabinet,
        configurationReady: hasCabinet && cabinetConfigured,
        runtimeAvailabilityIntent: runtime?.cabinetEnabled ?? false,
        effectiveCurrentEligibility: false,
        blockingReasons: hasCabinet && cabinetConfigured
            ? const [DoctorUrgentReadinessReason.runtimeCabinetIntentDisabled]
            : const [DoctorUrgentReadinessReason.noActiveCabinet],
      ),
      completeLiveMatchingEligibilityEvaluated: false,
      evaluatedAt: DateTime.utc(2026, 10, 16),
    ),
    activeCabinets: cabinetConfigured
        ? const [
            DoctorPracticeLocationSnapshot(
              id: 'cabinet-a',
              name: 'Cabinet A',
              governorate: 'Tunis',
              city: 'Tunis',
              address: '1 rue de Tunis',
              active: true,
              primary: true,
            ),
          ]
        : const [],
    runtime: runtime,
    runtimeAccess: runtimeAccess,
  );
}

DioException _problem(int status, String code, {List<String>? reasons}) {
  final options = RequestOptions(path: '/me/urgent-runtime');
  final data = <String, Object>{'code': code};
  if (reasons != null) data['blockingReasons'] = reasons;
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  test('runtime API sends the exact full-replacement contract', () async {
    final adapter = _RuntimeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final refreshDio = Dio()..httpClientAdapter = _RuntimeAdapter();
    final client = AppHttpClient(
      tokenStore: SecureTokenStore(backend: _MemoryStorage()),
      baseUrl: 'http://api.test',
      dio: dio,
      refreshDio: refreshDio,
    );
    addTearDown(() => client.close(force: true));
    final api = DoctorWorkspaceBootstrapApi(client);

    final result = await api.replaceUrgentRuntime(
      expectedRevision: 7,
      homeEnabled: true,
      cabinetEnabled: false,
    );

    expect(adapter.lastRequest?.method, 'PUT');
    expect(adapter.lastRequest?.uri.path, '/api/v1/me/urgent-runtime');
    expect(adapter.lastRequest?.data, {
      'expectedRevision': 7,
      'homeEnabled': true,
      'cabinetEnabled': false,
    });
    expect(result.revision, 8);
    expect(result.homeEnabled, isTrue);
    expect(result.cabinetEnabled, isFalse);
    expect(result.capacityState, DoctorUrgentCapacityState.free);
    expect(result.home?.operationalPresenceReady, isFalse);
    expect(
      result.homeLocationPresence?.status,
      DoctorLocationPresenceStatus.missing,
    );
  });

  test(
    'HOME toggle preserves authoritative CABINET and is not optimistic',
    () async {
      final repository = _RuntimeRepository();
      final completer = repository.replaceCompleter =
          Completer<DoctorUrgentRuntimeSnapshot>();
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(_workspace(runtime: _runtime(cabinet: true)));

      final pending = controller.setEnabled(DoctorUrgentRuntimeMode.home, true);
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isFalse);
      expect(controller.isSaving(DoctorUrgentRuntimeMode.home), isTrue);
      expect(repository.replaceCalls.single.expectedRevision, 2);
      expect(repository.replaceCalls.single.homeEnabled, isTrue);
      expect(repository.replaceCalls.single.cabinetEnabled, isTrue);

      completer.complete(_runtime(revision: 3, home: true, cabinet: true));
      await pending;
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isTrue);
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.cabinet), isTrue);
    },
  );

  test('HOME-only runtime works with zero registered Cabinets', () async {
    final repository = _RuntimeRepository()
      ..replaceResult = _runtime(revision: 3, home: true);
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);
    controller.attachWorkspace(
      _workspace(
        capabilities: const {DoctorServerCareCapability.urgentHome},
        cabinetConfigured: false,
        runtime: _runtime(),
      ),
    );

    await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);

    expect(repository.replaceCalls.single.homeEnabled, isTrue);
    expect(repository.replaceCalls.single.cabinetEnabled, isFalse);
    expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isTrue);
  });

  test('CABINET toggles independently without HOME GPS', () async {
    final repository = _RuntimeRepository()
      ..replaceResult = _runtime(
        revision: 3,
        cabinet: true,
        homePresence: false,
        homeReasons: const [DoctorUrgentReadinessReason.locationMissing],
      );
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);
    controller.attachWorkspace(
      _workspace(runtime: _runtime(homePresence: false)),
    );

    await controller.setEnabled(DoctorUrgentRuntimeMode.cabinet, true);

    expect(repository.replaceCalls.single.homeEnabled, isFalse);
    expect(repository.replaceCalls.single.cabinetEnabled, isTrue);
    expect(controller.isEnabled(DoctorUrgentRuntimeMode.cabinet), isTrue);
  });

  test(
    'HOME intent can be ON while missing GPS remains non-matchable',
    () async {
      final repository = _RuntimeRepository()
        ..replaceResult = _runtime(
          revision: 3,
          home: true,
          homePresence: false,
          homeReasons: const [DoctorUrgentReadinessReason.locationMissing],
        );
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(
        _workspace(runtime: _runtime(homePresence: false)),
      );

      await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);

      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isTrue);
      expect(
        controller.modeMessage(DoctorUrgentRuntimeMode.home),
        contains('pas géographiquement admissible'),
      );
    },
  );

  test(
    'missing permanent HOME and CABINET configuration cannot activate',
    () async {
      final repository = _RuntimeRepository();
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(
        _workspace(
          homeConfigured: false,
          cabinetConfigured: false,
          runtime: _runtime(),
        ),
      );

      await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);
      await controller.setEnabled(DoctorUrgentRuntimeMode.cabinet, true);

      expect(repository.replaceCalls, isEmpty);
      expect(controller.canChange(DoctorUrgentRuntimeMode.home), isFalse);
      expect(controller.canChange(DoctorUrgentRuntimeMode.cabinet), isFalse);
    },
  );

  test('a missing permanent capability cannot be activated', () async {
    final repository = _RuntimeRepository();
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);
    controller.attachWorkspace(
      _workspace(
        capabilities: const {DoctorServerCareCapability.urgentHome},
        runtime: _runtime(),
      ),
    );

    await controller.setEnabled(DoctorUrgentRuntimeMode.cabinet, true);

    expect(repository.replaceCalls, isEmpty);
  });

  test(
    'clinical-busy activation rejection refetches server authority',
    () async {
      final busy = _runtime(
        revision: 2,
        capacity: DoctorUrgentCapacityState.clinicalBusy,
        homeReasons: const [DoctorUrgentReadinessReason.clinicalBusy],
      );
      final repository = _RuntimeRepository()
        ..replaceError = _problem(
          409,
          'URGENT_RUNTIME_ACTIVATION_BLOCKED',
          reasons: const ['CLINICAL_BUSY'],
        )
        ..getResult = busy;
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(_workspace(runtime: _runtime()));

      await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);

      expect(repository.getCalls, 1);
      expect(
        controller.snapshot?.capacityState,
        DoctorUrgentCapacityState.clinicalBusy,
      );
      expect(controller.feedback, contains('activité clinique'));
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isFalse);
    },
  );

  test(
    'stale revision conflict refetches and preserves the winning state',
    () async {
      final repository = _RuntimeRepository()
        ..replaceError = _problem(409, 'RESOURCE_STATE_CONFLICT')
        ..getResult = _runtime(revision: 5, cabinet: true);
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(_workspace(runtime: _runtime(revision: 4)));

      await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);

      expect(controller.snapshot?.revision, 5);
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isFalse);
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.cabinet), isTrue);
      expect(controller.feedback, contains('état actuel a été rechargé'));
    },
  );

  test('a stale refresh cannot overwrite a newer toggle response', () async {
    final repository = _RuntimeRepository()
      ..getCompleter = Completer<DoctorUrgentRuntimeSnapshot>()
      ..replaceResult = _runtime(revision: 4, home: true);
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);
    controller.attachWorkspace(_workspace(runtime: _runtime(revision: 3)));

    final refresh = controller.refresh();
    final toggle = controller.setEnabled(DoctorUrgentRuntimeMode.home, true);
    await toggle;
    repository.getCompleter!.complete(_runtime(revision: 3));
    await refresh;

    expect(controller.snapshot?.revision, 4);
    expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isTrue);
  });

  test('development-gate 404 is explicit and never falls back', () async {
    final repository = _RuntimeRepository()
      ..getError = _problem(404, 'URGENT_RUNTIME_UNAVAILABLE');
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);
    controller.attachWorkspace(_workspace(runtime: null));
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, DoctorUrgentRuntimeState.unavailable);
    expect(controller.snapshot, isNull);
    expect(
      controller.modeMessage(DoctorUrgentRuntimeMode.home),
      contains('environnement'),
    );
  });

  test('known bootstrap rollout 404 is not requested a second time', () {
    final repository = _RuntimeRepository();
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);

    controller.attachWorkspace(
      _workspace(
        runtime: null,
        runtimeAccess: DoctorUrgentRuntimeBootstrapAccess.rolloutUnavailable,
      ),
    );

    expect(controller.state, DoctorUrgentRuntimeState.unavailable);
    expect(controller.snapshot, isNull);
    expect(repository.getCalls, 0);
  });

  test(
    'network failure disables mutation until authority can be reloaded',
    () async {
      final request = RequestOptions(path: '/me/urgent-runtime');
      final failure = DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
      final repository = _RuntimeRepository()
        ..replaceError = failure
        ..getError = failure;
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(_workspace(runtime: _runtime()));

      await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);

      expect(controller.state, DoctorUrgentRuntimeState.failure);
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isFalse);
      expect(controller.canChange(DoctorUrgentRuntimeMode.home), isFalse);
      expect(controller.feedback, contains('Connexion au serveur impossible'));
    },
  );

  test(
    'a gated resume clears the previously loaded runtime snapshot',
    () async {
      final repository = _RuntimeRepository()
        ..getError = _problem(404, 'URGENT_RUNTIME_UNAVAILABLE');
      final controller = DoctorUrgentRuntimeController(repository: repository);
      addTearDown(controller.dispose);
      controller.attachWorkspace(_workspace(runtime: _runtime(home: true)));
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isTrue);

      controller.attachWorkspace(_workspace(runtime: null));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, DoctorUrgentRuntimeState.unavailable);
      expect(controller.snapshot, isNull);
      expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isFalse);
    },
  );

  test('401 and 403 use the existing session rejection boundary', () async {
    for (final status in [401, 403]) {
      var rejected = 0;
      final repository = _RuntimeRepository()
        ..replaceError = _problem(status, 'FORBIDDEN');
      final controller = DoctorUrgentRuntimeController(
        repository: repository,
        onSessionRejected: () => rejected++,
      );
      controller.attachWorkspace(_workspace(runtime: _runtime()));

      await controller.setEnabled(DoctorUrgentRuntimeMode.home, true);

      expect(rejected, 1, reason: 'HTTP $status');
      controller.dispose();
    }
  });

  test('account switch ignores an old Doctor command response', () async {
    final repository = _RuntimeRepository();
    final completer = repository.replaceCompleter =
        Completer<DoctorUrgentRuntimeSnapshot>();
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);
    controller.attachWorkspace(_workspace(runtime: _runtime()));

    final oldCommand = controller.setEnabled(
      DoctorUrgentRuntimeMode.home,
      true,
    );
    controller.attachWorkspace(
      _workspace(
        doctorId: 'doctor-b',
        runtime: _runtime(revision: 9, cabinet: true),
      ),
    );
    completer.complete(_runtime(revision: 3, home: true));
    await oldCommand;

    expect(controller.snapshot?.revision, 9);
    expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isFalse);
    expect(controller.isEnabled(DoctorUrgentRuntimeMode.cabinet), isTrue);
    controller.clear();
    expect(controller.snapshot, isNull);
    expect(controller.state, DoctorUrgentRuntimeState.detached);
  });

  test('restart restores backend state and never activates automatically', () {
    final repository = _RuntimeRepository();
    final controller = DoctorUrgentRuntimeController(repository: repository);
    addTearDown(controller.dispose);

    controller.attachWorkspace(
      _workspace(runtime: _runtime(revision: 7, home: true)),
    );

    expect(controller.isEnabled(DoctorUrgentRuntimeMode.home), isTrue);
    expect(controller.isEnabled(DoctorUrgentRuntimeMode.cabinet), isFalse);
    expect(repository.replaceCalls, isEmpty);
  });

  testWidgets('frozen HOME gate exposes only the server runtime intention', (
    tester,
  ) async {
    final repository = _RuntimeRepository()
      ..replaceResult = _runtime(
        revision: 3,
        home: true,
        homePresence: false,
        homeReasons: const [DoctorUrgentReadinessReason.locationMissing],
      );
    final runtimeController = DoctorUrgentRuntimeController(
      repository: repository,
    );
    final homeController = DoctorUrgentController();
    final cabinetController = DoctorUrgentCabinetController(
      developmentSimulationEnabled: false,
    );
    addTearDown(runtimeController.dispose);
    addTearDown(homeController.dispose);
    addTearDown(cabinetController.dispose);
    final workspace = _workspace(
      capabilities: const {DoctorServerCareCapability.urgentHome},
      runtime: _runtime(homePresence: false),
    );
    runtimeController.attachWorkspace(workspace);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: DoctorUrgentWorkspaceScreen(
            capabilities: workspace.navigationCapabilities,
            workspaceConfig: workspace.presentationConfig,
            selectedMode: DoctorUrgentMode.home,
            onModeChanged: (_) {},
            homeController: homeController,
            urgentCabinetController: cabinetController,
            homeOperationalMessage: workspace.homeOperationalMessage,
            runtimeController: runtimeController,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('doctor-urgent-home-runtime-switch')),
      findsOneWidget,
    );
    expect(find.text('Passer en ligne'), findsNothing);
    expect(find.text('Voir la demande de démonstration'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('doctor-urgent-home-runtime-switch')),
    );
    await tester.pumpAndSettle();

    expect(repository.replaceCalls, hasLength(1));
    expect(
      find.textContaining('pas géographiquement admissible'),
      findsOneWidget,
    );
    expect(find.textContaining('ni GPS'), findsOneWidget);
  });
}
