import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/auth/application/auth_controller.dart';
import 'package:omnicare_mobile/features/auth/application/auth_flow_models.dart';
import 'package:omnicare_mobile/features/auth/data/auth_repository.dart';
import 'package:omnicare_mobile/features/auth/data/models/auth_dtos.dart';
import 'package:omnicare_mobile/features/doctor/doctor_auth_shell_screen.dart';
import 'package:omnicare_mobile/features/doctor/onboarding/doctor_onboarding_screen.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_commitment_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_dispatch_context.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_dispatch_context_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_workspace_screen.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_repository.dart';
import 'package:provider/provider.dart';

const _commitmentId = '11111111-1111-4111-8111-111111111111';

class _AuthRepository implements AuthRepositoryContract {
  const _AuthRepository();

  @override
  Future<AuthenticatedPatientSession?> restoreSession() async =>
      const AuthenticatedPatientSession(
        user: CurrentUserDto(
          id: 'doctor-a',
          role: 'DOCTOR',
          sessionId: 'session-a',
          mustChangePassword: false,
        ),
        profile: null,
      );

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BootstrapRepository
    implements DoctorWorkspaceBootstrapRepositoryContract {
  final completer = Completer<DoctorWorkspaceBootstrap>();
  final calls = <String>[];

  @override
  Future<DoctorWorkspaceBootstrap> load(
    String doctorId, {
    CancelToken? cancelToken,
  }) {
    calls.add(doctorId);
    return completer.future;
  }
}

class _QueuedBootstrapRepository
    implements DoctorWorkspaceBootstrapRepositoryContract {
  final calls = <String>[];
  final requests = <Completer<DoctorWorkspaceBootstrap>>[];

  @override
  Future<DoctorWorkspaceBootstrap> load(
    String doctorId, {
    CancelToken? cancelToken,
  }) {
    calls.add(doctorId);
    final completer = Completer<DoctorWorkspaceBootstrap>();
    requests.add(completer);
    return completer.future;
  }
}

class _CommitmentRepository implements DoctorHomeCommitmentRepositoryContract {
  int activeCalls = 0;

  @override
  Future<DoctorHomeActiveCommitment> findActive({
    CancelToken? cancelToken,
  }) async {
    activeCalls++;
    return DoctorHomeActiveCommitment(
      result: DoctorHomeActiveCommitmentResult.activeCommitment,
      commitment: DoctorHomeCommitment(
        commitmentId: _commitmentId,
        journeyId: '22222222-2222-4222-8222-222222222222',
        selectedOfferId: '33333333-3333-4333-8333-333333333333',
        status: DoctorHomeCommitmentStatus.active,
        revision: 4,
        quotedHomeFeeTnd: '75.000',
        currency: 'TND',
        committedAt: DateTime.utc(2026, 10, 16),
        updatedAt: DateTime.utc(2026, 10, 16),
        evaluatedAt: DateTime.utc(2026, 10, 16),
        availableActions: const [],
      ),
      evaluatedAt: DateTime.utc(2026, 10, 16),
    );
  }

  @override
  Future<DoctorHomeCommitment> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _DispatchContextRepository
    implements DoctorHomeDispatchContextRepositoryContract {
  final calls = <String>[];

  @override
  Future<DoctorHomeDispatchContext> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) async {
    calls.add(commitmentId);
    return DoctorHomeDispatchContext(
      commitmentId: commitmentId,
      commitmentRevision: 4,
      evaluatedAt: DateTime.utc(2026, 10, 16),
      destination: DoctorHomeDispatchDestination(
        latitude: 36.8065,
        longitude: 10.1815,
        confirmedAddress: '15 Synthetic Avenue',
        acquisitionMode: DoctorHomeDestinationAcquisitionMode.mapPin,
        provenance: DoctorHomeDestinationProvenance.patientMovedPin,
        confirmedAt: DateTime.utc(2026, 10, 16),
      ),
    );
  }
}

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _UnavailableAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":"UNAVAILABLE"}',
    503,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

DoctorWorkspaceBootstrap _homeWorkspace() => DoctorWorkspaceBootstrap(
  doctorId: 'doctor-a',
  serverCapabilities: const {DoctorServerCareCapability.urgentHome},
  capabilityRevision: 7,
  configuration: const DoctorUrgentConfigurationSnapshot(
    revision: 7,
    homeFeeConfigured: true,
    homeTravelDistanceConfigured: true,
    cabinetFeeConfigured: false,
  ),
  readiness: DoctorUrgentReadinessSnapshot(
    revision: 7,
    professionalEligible: true,
    home: const DoctorUrgentModeReadiness(
      capabilityEnabled: true,
      configurationReady: true,
      runtimeAvailabilityIntent: false,
      effectiveCurrentEligibility: false,
      blockingReasons: [DoctorUrgentReadinessReason.runtimeHomeIntentDisabled],
    ),
    cabinet: const DoctorUrgentModeReadiness(
      capabilityEnabled: false,
      configurationReady: false,
      runtimeAvailabilityIntent: false,
      effectiveCurrentEligibility: false,
      blockingReasons: [DoctorUrgentReadinessReason.capabilityDisabled],
    ),
    completeLiveMatchingEligibilityEvaluated: false,
    evaluatedAt: DateTime.utc(2026, 10, 16),
  ),
  activeCabinets: const [],
  runtime: const DoctorUrgentRuntimeSnapshot(
    revision: 2,
    homeEnabled: false,
    cabinetEnabled: false,
  ),
);

DoctorWorkspaceBootstrap _combinedWorkspace() => DoctorWorkspaceBootstrap(
  doctorId: 'doctor-a',
  serverCapabilities: const {
    DoctorServerCareCapability.cabinet,
    DoctorServerCareCapability.urgentHome,
    DoctorServerCareCapability.urgentCabinet,
  },
  capabilityRevision: 7,
  configuration: const DoctorUrgentConfigurationSnapshot(
    revision: 7,
    homeFeeConfigured: true,
    homeTravelDistanceConfigured: true,
    cabinetFeeConfigured: true,
  ),
  readiness: DoctorUrgentReadinessSnapshot(
    revision: 7,
    professionalEligible: true,
    home: const DoctorUrgentModeReadiness(
      capabilityEnabled: true,
      configurationReady: true,
      runtimeAvailabilityIntent: false,
      effectiveCurrentEligibility: false,
      blockingReasons: [DoctorUrgentReadinessReason.runtimeHomeIntentDisabled],
    ),
    cabinet: const DoctorUrgentModeReadiness(
      capabilityEnabled: true,
      configurationReady: true,
      runtimeAvailabilityIntent: false,
      effectiveCurrentEligibility: false,
      blockingReasons: [
        DoctorUrgentReadinessReason.runtimeCabinetIntentDisabled,
      ],
    ),
    completeLiveMatchingEligibilityEvaluated: false,
    evaluatedAt: DateTime.utc(2026, 10, 16),
  ),
  activeCabinets: const [
    DoctorPracticeLocationSnapshot(
      id: 'cabinet-a',
      name: 'Cabinet Lac 2',
      governorate: 'Tunis',
      city: 'Les Berges du Lac',
      address: '1, rue de la Santé',
      active: true,
      primary: true,
    ),
  ],
  runtime: const DoctorUrgentRuntimeSnapshot(
    revision: 2,
    homeEnabled: false,
    cabinetEnabled: false,
  ),
);

Future<
  ({
    AuthController auth,
    AppHttpClient client,
    _QueuedBootstrapRepository repository,
    _CommitmentRepository commitmentRepository,
    _DispatchContextRepository dispatchContextRepository,
  })
>
_pumpCombinedDoctorShell(WidgetTester tester) async {
  final auth = AuthController(repository: const _AuthRepository());
  await auth.initialize();
  final repository = _QueuedBootstrapRepository();
  final commitmentRepository = _CommitmentRepository();
  final dispatchContextRepository = _DispatchContextRepository();
  final dio = Dio()..httpClientAdapter = _UnavailableAdapter();
  final refreshDio = Dio()..httpClientAdapter = _UnavailableAdapter();
  final client = AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryStorage()),
    baseUrl: 'http://api.test',
    dio: dio,
    refreshDio: refreshDio,
  );
  addTearDown(auth.dispose);
  addTearDown(() => client.close(force: true));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<AppHttpClient>.value(value: client),
      ],
      child: MaterialApp(
        theme: buildOmniTheme(),
        routes: {'/login': (_) => const Scaffold(body: Text('Connexion'))},
        home: DoctorAuthShellScreen(
          bootstrapRepository: repository,
          homeCommitmentRepository: commitmentRepository,
          homeDispatchContextRepository: dispatchContextRepository,
        ),
      ),
    ),
  );
  await tester.pump();
  repository.requests.single.complete(_combinedWorkspace());
  await tester.pumpAndSettle();
  return (
    auth: auth,
    client: client,
    repository: repository,
    commitmentRepository: commitmentRepository,
    dispatchContextRepository: dispatchContextRepository,
  );
}

void main() {
  testWidgets(
    'authenticated Doctor waits for server bootstrap and never enters local onboarding',
    (tester) async {
      final auth = AuthController(repository: const _AuthRepository());
      await auth.initialize();
      addTearDown(auth.dispose);
      final repository = _BootstrapRepository();
      final commitmentRepository = _CommitmentRepository();
      final dispatchContextRepository = _DispatchContextRepository();
      final dio = Dio()..httpClientAdapter = _UnavailableAdapter();
      final refreshDio = Dio()..httpClientAdapter = _UnavailableAdapter();
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryStorage()),
        baseUrl: 'http://api.test',
        dio: dio,
        refreshDio: refreshDio,
      );
      addTearDown(() => client.close(force: true));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            Provider<AppHttpClient>.value(value: client),
          ],
          child: MaterialApp(
            theme: buildOmniTheme(),
            routes: {'/login': (_) => const Scaffold(body: Text('Connexion'))},
            home: DoctorAuthShellScreen(
              bootstrapRepository: repository,
              homeCommitmentRepository: commitmentRepository,
              homeDispatchContextRepository: dispatchContextRepository,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(repository.calls, ['doctor-a']);
      expect(commitmentRepository.activeCalls, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DoctorOnboardingScreen), findsNothing);
      expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsNothing);

      repository.completer.complete(_homeWorkspace());
      await tester.pumpAndSettle();

      expect(commitmentRepository.activeCalls, 1);
      expect(dispatchContextRepository.calls, [_commitmentId]);

      expect(find.byType(DoctorOnboardingScreen), findsNothing);
      expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsOneWidget);
      expect(find.byKey(const ValueKey('doctor-tab-agenda')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-home-backend-gate')),
        findsOneWidget,
      );
      expect(find.text('Engagement confirmé'), findsOneWidget);
      expect(find.text('15 Synthetic Avenue'), findsOneWidget);
      expect(find.text('Intention désactivée côté serveur'), findsOneWidget);
      expect(find.text('Passer en ligne'), findsNothing);
    },
  );

  testWidgets(
    'Urgences HOME and active responsibility survive background refresh',
    (tester) async {
      final setup = await _pumpCombinedDoctorShell(tester);
      await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
      await tester.pumpAndSettle();

      expect(find.text('Engagement confirmé'), findsOneWidget);
      expect(find.text('15 Synthetic Avenue'), findsOneWidget);
      expect(setup.dispatchContextRepository.calls, [_commitmentId]);
      expect(
        tester
            .widget<SegmentedButton<DoctorUrgentMode>>(
              find.byKey(const ValueKey('doctor-urgent-mode-selector')),
            )
            .selected,
        {DoctorUrgentMode.home},
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(setup.repository.requests, hasLength(2));
      expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsOneWidget);
      expect(find.text('Engagement confirmé'), findsOneWidget);
      expect(find.text('15 Synthetic Avenue'), findsNothing);

      setup.repository.requests.last.complete(_combinedWorkspace());
      await tester.pumpAndSettle();

      expect(setup.repository.calls, ['doctor-a', 'doctor-a']);
      expect(setup.dispatchContextRepository.calls, [
        _commitmentId,
        _commitmentId,
      ]);
      expect(find.text('Engagement confirmé'), findsOneWidget);
      expect(find.text('15 Synthetic Avenue'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<DoctorUrgentMode>>(
              find.byKey(const ValueKey('doctor-urgent-mode-selector')),
            )
            .selected,
        {DoctorUrgentMode.home},
      );
    },
  );

  testWidgets('Urgences CABINET survives background refresh', (tester) async {
    final setup = await _pumpCombinedDoctorShell(tester);
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Au cabinet'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<DoctorUrgentMode>>(
            find.byKey(const ValueKey('doctor-urgent-mode-selector')),
          )
          .selected,
      {DoctorUrgentMode.cabinet},
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(setup.repository.requests, hasLength(2));
    expect(
      tester
          .widget<SegmentedButton<DoctorUrgentMode>>(
            find.byKey(const ValueKey('doctor-urgent-mode-selector')),
          )
          .selected,
      {DoctorUrgentMode.cabinet},
    );

    setup.repository.requests.last.complete(_combinedWorkspace());
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<DoctorUrgentMode>>(
            find.byKey(const ValueKey('doctor-urgent-mode-selector')),
          )
          .selected,
      {DoctorUrgentMode.cabinet},
    );
  });

  testWidgets('Agenda survives background workspace refresh', (tester) async {
    final setup = await _pumpCombinedDoctorShell(tester);
    await tester.tap(find.byKey(const ValueKey('doctor-tab-agenda')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorAgendaScreen), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(setup.repository.requests, hasLength(2));
    expect(find.byType(DoctorAgendaScreen), findsOneWidget);

    setup.repository.requests.last.complete(_combinedWorkspace());
    await tester.pumpAndSettle();
    expect(find.byType(DoctorAgendaScreen), findsOneWidget);
  });
}
