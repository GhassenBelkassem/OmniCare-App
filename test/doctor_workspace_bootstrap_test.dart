import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_api.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_repository.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

DoctorWorkspaceBootstrap _workspace(
  String doctorId,
  Set<DoctorServerCareCapability> capabilities, {
  List<DoctorUrgentReadinessReason> homeReasons = const [],
  List<DoctorUrgentReadinessReason> cabinetReasons = const [],
  bool runtimeHome = false,
  bool runtimeCabinet = false,
  bool includeCabinet = false,
}) {
  DoctorUrgentModeReadiness mode(
    bool enabled,
    List<DoctorUrgentReadinessReason> reasons,
    bool runtime,
  ) => DoctorUrgentModeReadiness(
    capabilityEnabled: enabled,
    configurationReady: reasons.isEmpty,
    runtimeAvailabilityIntent: runtime,
    effectiveCurrentEligibility: false,
    blockingReasons: reasons,
  );

  final homeEnabled = capabilities.contains(
    DoctorServerCareCapability.urgentHome,
  );
  final cabinetEnabled = capabilities.contains(
    DoctorServerCareCapability.urgentCabinet,
  );
  return DoctorWorkspaceBootstrap(
    doctorId: doctorId,
    serverCapabilities: capabilities,
    capabilityRevision: 4,
    configuration: const DoctorUrgentConfigurationSnapshot(
      revision: 4,
      homeFeeConfigured: true,
      homeTravelDistanceConfigured: true,
      cabinetFeeConfigured: true,
    ),
    readiness: DoctorUrgentReadinessSnapshot(
      revision: 4,
      professionalEligible: true,
      home: mode(homeEnabled, homeReasons, runtimeHome),
      cabinet: mode(cabinetEnabled, cabinetReasons, runtimeCabinet),
      completeLiveMatchingEligibilityEvaluated: false,
      evaluatedAt: DateTime.utc(2026, 10, 16),
    ),
    activeCabinets: includeCabinet
        ? const [
            DoctorPracticeLocationSnapshot(
              id: 'cabinet-1',
              name: 'Cabinet Lac 2',
              governorate: 'Tunis',
              city: 'Les Berges du Lac',
              address: '1, rue de la Santé',
              active: true,
              primary: true,
            ),
          ]
        : const [],
    runtime: DoctorUrgentRuntimeSnapshot(
      revision: 2,
      homeEnabled: runtimeHome,
      cabinetEnabled: runtimeCabinet,
    ),
  );
}

class _QueuedRepository implements DoctorWorkspaceBootstrapRepositoryContract {
  final requests =
      <
        ({
          String doctorId,
          CancelToken? cancelToken,
          Completer<DoctorWorkspaceBootstrap> completer,
        })
      >[];

  @override
  Future<DoctorWorkspaceBootstrap> load(
    String doctorId, {
    CancelToken? cancelToken,
  }) {
    final completer = Completer<DoctorWorkspaceBootstrap>();
    requests.add((
      doctorId: doctorId,
      cancelToken: cancelToken,
      completer: completer,
    ));
    return completer.future;
  }
}

class _FailingRepository implements DoctorWorkspaceBootstrapRepositoryContract {
  @override
  Future<DoctorWorkspaceBootstrap> load(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    throw DioException(requestOptions: RequestOptions(path: '/bootstrap'));
  }
}

class _BootstrapApi implements DoctorWorkspaceBootstrapApiContract {
  _BootstrapApi({
    this.configurationRevision = 4,
    this.runtimeUnavailable = false,
  });

  final int configurationRevision;
  final bool runtimeUnavailable;
  static const capabilities = {DoctorServerCareCapability.urgentHome};

  @override
  Future<({Set<DoctorServerCareCapability> capabilities, int revision})>
  getCapabilities({CancelToken? cancelToken}) async =>
      (revision: 4, capabilities: capabilities);

  @override
  Future<List<DoctorPracticeLocationSnapshot>> getPracticeLocations({
    CancelToken? cancelToken,
  }) async => const [];

  @override
  Future<DoctorUrgentConfigurationSnapshot> getUrgentConfiguration({
    CancelToken? cancelToken,
  }) async => DoctorUrgentConfigurationSnapshot(
    revision: configurationRevision,
    homeFeeConfigured: true,
    homeTravelDistanceConfigured: true,
    cabinetFeeConfigured: false,
  );

  @override
  Future<DoctorUrgentReadinessSnapshot> getUrgentReadiness({
    CancelToken? cancelToken,
  }) async => DoctorUrgentReadinessSnapshot(
    revision: 4,
    professionalEligible: true,
    home: DoctorUrgentModeReadiness(
      capabilityEnabled: capabilities.contains(
        DoctorServerCareCapability.urgentHome,
      ),
      configurationReady: true,
      runtimeAvailabilityIntent: false,
      effectiveCurrentEligibility: false,
      blockingReasons: const [
        DoctorUrgentReadinessReason.runtimeHomeIntentDisabled,
      ],
    ),
    cabinet: DoctorUrgentModeReadiness(
      capabilityEnabled: capabilities.contains(
        DoctorServerCareCapability.urgentCabinet,
      ),
      configurationReady: false,
      runtimeAvailabilityIntent: false,
      effectiveCurrentEligibility: false,
      blockingReasons: const [DoctorUrgentReadinessReason.capabilityDisabled],
    ),
    completeLiveMatchingEligibilityEvaluated: false,
    evaluatedAt: DateTime.utc(2026, 10, 16),
  );

  @override
  Future<DoctorUrgentRuntimeSnapshot> getUrgentRuntime({
    CancelToken? cancelToken,
  }) async {
    if (runtimeUnavailable) {
      final request = RequestOptions(path: '/me/urgent-runtime');
      throw DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 404),
      );
    }
    return const DoctorUrgentRuntimeSnapshot(
      revision: 1,
      homeEnabled: false,
      cabinetEnabled: false,
    );
  }
}

void main() {
  test('server capabilities drive the complete V1 navigation matrix', () {
    final home = _workspace('home', {DoctorServerCareCapability.urgentHome});
    final urgentCabinet = _workspace('urgent-cabinet', {
      DoctorServerCareCapability.urgentCabinet,
    }, includeCabinet: true);
    final bothUrgent = _workspace('both', {
      DoctorServerCareCapability.urgentHome,
      DoctorServerCareCapability.urgentCabinet,
    }, includeCabinet: true);
    final normalCabinet = _workspace('cabinet', {
      DoctorServerCareCapability.cabinet,
    }, includeCabinet: true);
    final none = _workspace('none', const {});

    expect(home.navigationCapabilities, {
      DoctorCapability.urgentRequests,
      DoctorCapability.urgentHomeRequests,
      DoctorCapability.urgentWorkspace,
      DoctorCapability.patientManagement,
      DoctorCapability.workQueue,
    });
    expect(
      urgentCabinet.navigationCapabilities,
      containsAll({
        DoctorCapability.urgentCabinetRequests,
        DoctorCapability.urgentWorkspace,
      }),
    );
    expect(
      urgentCabinet.navigationCapabilities,
      isNot(contains(DoctorCapability.agenda)),
    );
    expect(
      bothUrgent.navigationCapabilities,
      containsAll({
        DoctorCapability.urgentHomeRequests,
        DoctorCapability.urgentCabinetRequests,
        DoctorCapability.urgentWorkspace,
      }),
    );
    expect(
      normalCabinet.navigationCapabilities,
      contains(DoctorCapability.agenda),
    );
    expect(
      normalCabinet.navigationCapabilities,
      isNot(contains(DoctorCapability.urgentWorkspace)),
    );
    expect(none.navigationCapabilities, isEmpty);
  });

  test('HOME_VISIT stays outside the visible V1 service mapping', () {
    final workspace = _workspace('doctor-a', {
      DoctorServerCareCapability.homeVisit,
    });

    expect(workspace.navigationCapabilities, isEmpty);
    expect(workspace.presentationConfig.practiceModes, isEmpty);
    expect(workspace.presentationConfig.services, isEmpty);
  });

  test('HOME-only works without a cabinet and readiness never removes it', () {
    final workspace = _workspace(
      'doctor-a',
      {DoctorServerCareCapability.urgentHome},
      homeReasons: const [
        DoctorUrgentReadinessReason.homeFeeNotConfigured,
        DoctorUrgentReadinessReason.homeTravelDistanceNotConfigured,
      ],
    );

    expect(workspace.activeCabinets, isEmpty);
    expect(
      workspace.navigationCapabilities,
      contains(DoctorCapability.urgentHomeRequests),
    );
    expect(workspace.presentationConfig.cabinet, isNull);
    expect(workspace.homeOperationalMessage, contains('tarif HOME'));
    expect(workspace.homeOperationalMessage, contains('distance routière'));
  });

  test('runtime OFF explains the block but preserves configured modes', () {
    final workspace = _workspace('doctor-a', {
      DoctorServerCareCapability.urgentHome,
      DoctorServerCareCapability.urgentCabinet,
    }, includeCabinet: true);

    expect(
      workspace.navigationCapabilities,
      containsAll({
        DoctorCapability.urgentHomeRequests,
        DoctorCapability.urgentCabinetRequests,
      }),
    );
    expect(workspace.homeOperationalMessage, contains('désactivée'));
    expect(workspace.cabinetOperationalMessage, contains('désactivée'));
  });

  test('runtime ON opens the authoritative urgent CABINET inbox', () {
    final workspace = _workspace(
      'doctor-a',
      {DoctorServerCareCapability.urgentCabinet},
      runtimeCabinet: true,
      includeCabinet: true,
    );

    expect(workspace.cabinetOperationalMessage, isNull);
    expect(
      workspace.navigationCapabilities,
      contains(DoctorCapability.urgentCabinetRequests),
    );
  });

  test('urgent CABINET requires its own capability and reports no cabinet', () {
    final normalCabinet = _workspace('doctor-a', {
      DoctorServerCareCapability.cabinet,
    }, includeCabinet: true);
    final urgentCabinet = _workspace(
      'doctor-b',
      {DoctorServerCareCapability.urgentCabinet},
      cabinetReasons: const [DoctorUrgentReadinessReason.noActiveCabinet],
    );

    expect(
      normalCabinet.navigationCapabilities,
      isNot(contains(DoctorCapability.urgentCabinetRequests)),
    );
    expect(
      urgentCabinet.navigationCapabilities,
      contains(DoctorCapability.urgentCabinetRequests),
    );
    expect(urgentCabinet.cabinetOperationalMessage, contains('Aucun cabinet'));
  });

  test('account switching discards slow stale workspace responses', () async {
    final repository = _QueuedRepository();
    final controller = DoctorWorkspaceBootstrapController(
      repository: repository,
    );
    addTearDown(controller.dispose);

    final first = controller.load('doctor-a');
    expect(controller.workspace, isNull);
    final second = controller.load('doctor-b');
    expect(repository.requests.first.cancelToken?.isCancelled, isTrue);

    repository.requests.first.completer.complete(
      _workspace('doctor-a', {DoctorServerCareCapability.urgentHome}),
    );
    await first;
    expect(controller.workspace, isNull);
    expect(controller.doctorId, 'doctor-b');

    repository.requests.last.completer.complete(
      _workspace('doctor-b', {DoctorServerCareCapability.cabinet}),
    );
    await second;
    expect(controller.state, DoctorWorkspaceBootstrapState.ready);
    expect(controller.workspace?.doctorId, 'doctor-b');
  });

  test('refresh replaces Angular configuration and clear removes it', () async {
    final repository = _QueuedRepository();
    final controller = DoctorWorkspaceBootstrapController(
      repository: repository,
    );
    addTearDown(controller.dispose);

    final initial = controller.load('doctor-a');
    repository.requests.single.completer.complete(
      _workspace('doctor-a', {DoctorServerCareCapability.cabinet}),
    );
    await initial;
    final initialWorkspace = controller.workspace;
    expect(
      controller.workspace?.navigationCapabilities,
      isNot(contains(DoctorCapability.urgentWorkspace)),
    );

    final refresh = controller.refresh();
    expect(controller.state, DoctorWorkspaceBootstrapState.loading);
    expect(controller.workspace, same(initialWorkspace));
    repository.requests.last.completer.complete(
      _workspace('doctor-a', {DoctorServerCareCapability.urgentHome}),
    );
    await refresh;
    expect(
      controller.workspace?.navigationCapabilities,
      contains(DoctorCapability.urgentHomeRequests),
    );

    controller.clear();
    expect(controller.state, DoctorWorkspaceBootstrapState.initial);
    expect(controller.doctorId, isNull);
    expect(controller.workspace, isNull);
  });

  test(
    'same-account refresh failure retains the last safe workspace',
    () async {
      final repository = _QueuedRepository();
      final controller = DoctorWorkspaceBootstrapController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      final initial = controller.load('doctor-a');
      repository.requests.single.completer.complete(
        _workspace('doctor-a', {DoctorServerCareCapability.urgentHome}),
      );
      await initial;
      final retained = controller.workspace;

      final refresh = controller.refresh();
      repository.requests.last.completer.completeError(
        DioException(requestOptions: RequestOptions(path: '/bootstrap')),
      );
      await refresh;

      expect(controller.state, DoctorWorkspaceBootstrapState.failure);
      expect(controller.workspace, same(retained));
      expect(controller.doctorId, 'doctor-a');
    },
  );

  test('authorization failure clears a retained workspace', () async {
    final repository = _QueuedRepository();
    final controller = DoctorWorkspaceBootstrapController(
      repository: repository,
    );
    addTearDown(controller.dispose);

    final initial = controller.load('doctor-a');
    repository.requests.single.completer.complete(
      _workspace('doctor-a', {DoctorServerCareCapability.urgentHome}),
    );
    await initial;

    final request = RequestOptions(path: '/bootstrap');
    final refresh = controller.refresh();
    repository.requests.last.completer.completeError(
      DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 401),
      ),
    );
    await refresh;

    expect(controller.state, DoctorWorkspaceBootstrapState.failure);
    expect(controller.workspace, isNull);
  });

  test('network failure fails closed without restoring local state', () async {
    final controller = DoctorWorkspaceBootstrapController(
      repository: _FailingRepository(),
    );
    addTearDown(controller.dispose);

    await controller.load('doctor-a');

    expect(controller.state, DoctorWorkspaceBootstrapState.failure);
    expect(controller.workspace, isNull);
    expect(controller.errorMessage, contains('connexion'));
  });

  test(
    'repository tolerates a gated runtime read but rejects mixed revisions',
    () async {
      final gatedRuntime = DoctorWorkspaceBootstrapRepository(
        _BootstrapApi(runtimeUnavailable: true),
      );

      final workspace = await gatedRuntime.load('doctor-a');
      expect(workspace.runtime, isNull);
      expect(
        workspace.runtimeAccess,
        DoctorUrgentRuntimeBootstrapAccess.rolloutUnavailable,
      );
      expect(
        workspace.navigationCapabilities,
        contains(DoctorCapability.urgentHomeRequests),
      );

      final mixedRevision = DoctorWorkspaceBootstrapRepository(
        _BootstrapApi(configurationRevision: 5),
      );
      await expectLater(
        mixedRevision.load('doctor-a'),
        throwsA(isA<DoctorWorkspaceBootstrapException>()),
      );
    },
  );
}
