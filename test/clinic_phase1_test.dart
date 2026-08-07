import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/auth/application/auth_controller.dart';
import 'package:omnicare_mobile/features/auth/application/auth_flow_models.dart';
import 'package:omnicare_mobile/features/auth/data/auth_repository.dart';
import 'package:omnicare_mobile/features/auth/data/models/auth_dtos.dart';
import 'package:omnicare_mobile/features/auth/splash_screen.dart';
import 'package:omnicare_mobile/features/clinic/application/clinic_context_controller.dart';
import 'package:omnicare_mobile/features/clinic/clinic_routes.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_failure.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_models.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_repository.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_professional_home_screen.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_selection_screen.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_web_workspace_screen.dart';
import 'package:omnicare_mobile/features/clinic/storage/clinic_selection_store.dart';
import 'package:omnicare_mobile/features/clinic/widgets/clinic_widgets.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';

// ---------------------------------------------------------------------------
// Minimal fakes. No mocking dependency, no production HTTP stack rewiring.
// ---------------------------------------------------------------------------

class FakeSecureBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class FakeClinicRepository implements ClinicRepository {
  ClinicAccessFamily accessFamily = ClinicAccessFamily.clinic;
  Object? accessError;
  ClinicMembershipDirectory directory = const ClinicMembershipDirectory(
    activeMemberships: [],
    unavailableMemberships: [],
  );
  Object? membershipsError;

  final Map<String, ClinicBootstrap> bootstraps = {};
  final Map<String, Object> bootstrapErrors = {};
  final Map<String, Completer<void>> bootstrapGates = {};

  int accessCalls = 0;
  int membershipCalls = 0;
  final List<String> bootstrapCalls = [];

  @override
  Future<ClinicAccessFamily> resolveAccessFamily({
    CancelToken? cancelToken,
  }) async {
    accessCalls++;
    final error = accessError;
    if (error != null) throw error;
    return accessFamily;
  }

  @override
  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) async {
    membershipCalls++;
    final error = membershipsError;
    if (error != null) throw error;
    return directory;
  }

  @override
  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    bootstrapCalls.add(clinicId);
    final gate = bootstrapGates[clinicId];
    if (gate != null) await gate.future;
    final error = bootstrapErrors[clinicId];
    if (error != null) throw error;
    final bootstrap = bootstraps[clinicId];
    if (bootstrap == null) throw ClinicFailure.invalidResponse;
    return bootstrap;
  }
}

class FakeAuthRepository implements AuthRepositoryContract {
  FakeAuthRepository(this.restoreResult);

  final AuthenticatedPatientSession? restoreResult;

  @override
  Future<AuthenticatedPatientSession?> restoreSession() async => restoreResult;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Contract fixtures (parsed through the real strict parsers).
// ---------------------------------------------------------------------------

Map<String, dynamic> _membershipJson({
  required String clinicId,
  String? clinicName,
  String role = 'CLINIC_MEDECIN',
  String membershipStatus = 'ACTIVE',
  String clinicStatus = 'ACTIVE',
  String? unavailabilityCode,
}) {
  return {
    'clinicId': clinicId,
    'clinicName': clinicName ?? 'Clinic $clinicId',
    'membershipId': 'membership-$clinicId',
    'professionalRole': role,
    'membershipStatus': membershipStatus,
    'clinicStatus': clinicStatus,
    'version': 1,
    'unavailabilityCode': ?unavailabilityCode,
  };
}

ClinicMembershipDirectory _directory({
  List<Map<String, dynamic>> active = const [],
  List<Map<String, dynamic>> unavailable = const [],
}) {
  return ClinicMembershipDirectory.fromJson({
    'contractVersion': '1.0',
    'activeMemberships': active,
    'unavailableMemberships': unavailable,
    'resolvedAt': '2026-08-06T10:00:00Z',
  });
}

ClinicBootstrap _bootstrap({
  required String clinicId,
  String role = 'CLINIC_MEDECIN',
  String? clinicName,
}) {
  return ClinicBootstrap.fromJson({
    'contractVersion': '1.0',
    'clinic': {
      'clinicId': clinicId,
      'clinicName': clinicName ?? 'Clinic $clinicId',
      'clinicStatus': 'ACTIVE',
    },
    'membership': {
      'membershipId': 'membership-$clinicId',
      'membershipStatus': 'ACTIVE',
      'professionalRole': role,
      'version': 1,
    },
    'capabilities': [
      'CLINIC_OVERVIEW_READ',
      'CLINIC_PROFILE_READ',
      'CLINIC_MEMBERSHIP_SELF_READ',
    ],
    'featureFlags': {
      'CLINIC_REQUESTS_ENABLED': false,
      'CLINIC_HOSPITALIZATION_ENABLED': false,
      'CLINIC_SURGERY_ENABLED': false,
      'CLINIC_URGENT_ENABLED': false,
      'CLINIC_MOBILE_TASKS_ENABLED': false,
      'CLINIC_PARTNERSHIP_ENABLED': false,
    },
    'resolvedAt': '2026-08-06T10:00:00Z',
  });
}

AuthenticatedPatientSession _session(String role) {
  return AuthenticatedPatientSession(
    user: CurrentUserDto(
      id: 'user-1',
      role: role,
      sessionId: 'session-1',
      mustChangePassword: false,
    ),
    profile: role == 'PATIENT'
        ? PatientProfile.fromJson({
            'userId': 'user-1',
            'firstName': 'Ahmed',
            'lastName': 'Ben Ali',
            'displayName': 'Ahmed Ben Ali',
            'dateOfBirth': '1998-04-20',
            'gender': 'M',
            'photoUrl': null,
            'primaryPhone': {'value': '+21698123456', 'verified': true},
            'primaryEmail': {'value': 'ahmed@example.tn', 'verified': true},
            'onboardingCompleted': true,
            'onboardingStep': 1,
            'preferredLanguage': 'fr',
            'notificationMedications': true,
            'notificationAppointments': true,
            'notificationPassport': true,
            'updatedAt': '2026-08-04T10:15:30Z',
          })
        : null,
  );
}

ClinicContextController _controller(
  FakeClinicRepository repository,
  ClinicSelectionStore store,
) {
  return ClinicContextController(repository: repository, selectionStore: store);
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 14}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _appUnderTest({
  required AuthController auth,
  required ClinicContextController clinic,
  Key? key,
}) {
  return MultiProvider(
    key: key,
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider<ClinicContextController>.value(value: clinic),
    ],
    child: MaterialApp(
      home: const SplashScreen(),
      routes: {
        '/home': (_) => const Text('home route'),
        '/conversational-onboarding': (_) => const Text('onboarding route'),
        // Placeholder only: doctor feature code is never imported by tests.
        '/doctor-dashboard': (_) => const Text('doctor route'),
        '/login': (_) => const Text('login route'),
        ...ClinicRoutes.builders(),
      },
    ),
  );
}

void main() {
  group('post-auth routing', () {
    testWidgets('PATIENT keeps its route and makes no clinic calls', (
      tester,
    ) async {
      final auth = AuthController(
        repository: FakeAuthRepository(_session('PATIENT')),
      );
      await auth.initialize();
      final repository = FakeClinicRepository();

      await tester.pumpWidget(
        _appUnderTest(
          auth: auth,
          clinic: _controller(
            repository,
            ClinicSelectionStore(backend: FakeSecureBackend()),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('home route'), findsOneWidget);
      expect(repository.accessCalls, 0);
      expect(repository.membershipCalls, 0);
    });

    testWidgets('DOCTOR keeps its route and makes no clinic calls', (
      tester,
    ) async {
      final auth = AuthController(
        repository: FakeAuthRepository(_session('DOCTOR')),
      );
      await auth.initialize();
      final repository = FakeClinicRepository();

      await tester.pumpWidget(
        _appUnderTest(
          auth: auth,
          clinic: _controller(
            repository,
            ClinicSelectionStore(backend: FakeSecureBackend()),
          ),
        ),
      );
      await _pumpFrames(tester);

      // No patient profile is required for the independent doctor flow.
      expect(auth.patientProfile, isNull);
      expect(find.text('doctor route'), findsOneWidget);
      expect(repository.accessCalls, 0);
      expect(repository.membershipCalls, 0);
    });

    testWidgets('CLINIC_* enters clinic access resolution', (tester) async {
      final auth = AuthController(
        repository: FakeAuthRepository(_session('CLINIC_MEDECIN')),
      );
      await auth.initialize();
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [_membershipJson(clinicId: 'clinic-a')],
        )
        ..bootstraps['clinic-a'] = _bootstrap(clinicId: 'clinic-a');

      await tester.pumpWidget(
        _appUnderTest(
          auth: auth,
          clinic: _controller(
            repository,
            ClinicSelectionStore(backend: FakeSecureBackend()),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(auth.nextRoute, ClinicRoutes.entry);
      expect(repository.accessCalls, 1);
      expect(repository.membershipCalls, 1);
      expect(repository.bootstrapCalls, ['clinic-a']);
      expect(find.byType(ClinicProfessionalHomeScreen), findsOneWidget);
    });
  });

  group('membership resolution', () {
    test('zero active memberships gives access unavailable', () async {
      final repository = FakeClinicRepository()
        ..directory = _directory(
          unavailable: [
            _membershipJson(
              clinicId: 'clinic-x',
              membershipStatus: 'SUSPENDED',
              unavailabilityCode: 'CLINIC_MEMBERSHIP_SUSPENDED',
            ),
          ],
        );
      final store = ClinicSelectionStore(backend: FakeSecureBackend());
      final controller = _controller(repository, store);

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );

      expect(controller.destination, ClinicDestination.accessUnavailable);
      expect(controller.activeMemberships, isEmpty);
      expect(controller.unavailableMemberships, hasLength(1));
      expect(repository.bootstrapCalls, isEmpty);
    });

    test(
      'single active membership auto-selects, bootstraps and stores the hint',
      () async {
        final repository = FakeClinicRepository()
          ..directory = _directory(
            active: [_membershipJson(clinicId: 'clinic-a')],
          )
          ..bootstraps['clinic-a'] = _bootstrap(clinicId: 'clinic-a');
        final backend = FakeSecureBackend();
        final store = ClinicSelectionStore(backend: backend);
        final controller = _controller(repository, store);

        await controller.initializeForAuthenticatedUser(
          globalRole: 'CLINIC_MEDECIN',
        );

        expect(controller.selectedClinicId, 'clinic-a');
        expect(controller.bootstrap, isNotNull);
        expect(repository.bootstrapCalls, ['clinic-a']);
        expect(controller.destination, ClinicDestination.professionalHome);
        // Only a small versioned clinic-id record is persisted.
        expect(await store.readSelectedClinicId(), 'clinic-a');
        expect(
          backend.values[ClinicSelectionStore.storageKey],
          '{"schemaVersion":1,"clinicId":"clinic-a"}',
        );
      },
    );

    test('multiple memberships without a hint show the selector', () async {
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [
            _membershipJson(clinicId: 'clinic-a'),
            _membershipJson(clinicId: 'clinic-b'),
          ],
        );
      final controller = _controller(
        repository,
        ClinicSelectionStore(backend: FakeSecureBackend()),
      );

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );

      expect(controller.destination, ClinicDestination.selection);
      expect(controller.selectedClinicId, isNull);
      expect(repository.bootstrapCalls, isEmpty);
    });

    test('a valid stored hint is restored and bootstrapped', () async {
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [
            _membershipJson(clinicId: 'clinic-a'),
            _membershipJson(clinicId: 'clinic-b'),
          ],
        )
        ..bootstraps['clinic-b'] = _bootstrap(clinicId: 'clinic-b');
      final store = ClinicSelectionStore(backend: FakeSecureBackend());
      await store.saveSelectedClinicId('clinic-b');
      final controller = _controller(repository, store);

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );

      expect(repository.bootstrapCalls, ['clinic-b']);
      expect(controller.selectedClinicId, 'clinic-b');
      expect(controller.destination, ClinicDestination.professionalHome);
    });

    test('an invalid stored hint is deleted and never trusted', () async {
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [
            _membershipJson(clinicId: 'clinic-a'),
            _membershipJson(clinicId: 'clinic-b'),
          ],
        );
      final backend = FakeSecureBackend();
      final store = ClinicSelectionStore(backend: backend);
      await store.saveSelectedClinicId('clinic-gone');
      final controller = _controller(repository, store);

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );

      expect(
        backend.values.containsKey(ClinicSelectionStore.storageKey),
        false,
      );
      expect(repository.bootstrapCalls, isEmpty);
      expect(controller.destination, ClinicDestination.selection);
    });

    test('a stale bootstrap cannot replace the latest selection', () async {
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [
            _membershipJson(clinicId: 'clinic-a'),
            _membershipJson(clinicId: 'clinic-b'),
          ],
        )
        ..bootstraps['clinic-a'] = _bootstrap(clinicId: 'clinic-a')
        ..bootstraps['clinic-b'] = _bootstrap(clinicId: 'clinic-b')
        ..bootstrapGates['clinic-a'] = Completer<void>();
      final store = ClinicSelectionStore(backend: FakeSecureBackend());
      final controller = _controller(repository, store);

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );
      expect(controller.destination, ClinicDestination.selection);

      final slow = controller.selectClinic('clinic-a');
      final fast = controller.switchClinic('clinic-b');
      await fast;
      // The older in-flight response resolves after the newer selection won.
      repository.bootstrapGates['clinic-a']!.complete();
      await slow;

      expect(controller.selectedClinicId, 'clinic-b');
      expect(controller.bootstrap!.clinic.clinicId, 'clinic-b');
      expect(await store.readSelectedClinicId(), 'clinic-b');
    });
  });

  group('role destinations', () {
    const cases = <String, ClinicDestination>{
      'CLINIC_MEDECIN': ClinicDestination.professionalHome,
      'CLINIC_INFIRMIERE': ClinicDestination.professionalHome,
      'CLINIC_KINE': ClinicDestination.professionalHome,
      'CLINIC_ADMIN': ClinicDestination.webWorkspace,
      'CLINIC_ASSISTANT': ClinicDestination.webWorkspace,
    };

    test('every clinic role lands on its Phase 1 destination', () async {
      for (final entry in cases.entries) {
        final repository = FakeClinicRepository()
          ..directory = _directory(
            active: [_membershipJson(clinicId: 'clinic-a', role: entry.key)],
          )
          ..bootstraps['clinic-a'] = _bootstrap(
            clinicId: 'clinic-a',
            role: entry.key,
          );
        final controller = _controller(
          repository,
          ClinicSelectionStore(backend: FakeSecureBackend()),
        );

        await controller.initializeForAuthenticatedUser(globalRole: entry.key);

        expect(
          controller.destination,
          entry.value,
          reason: 'role ${entry.key}',
        );
        expect(controller.bootstrap!.hasAnyEnabledModule, isFalse);
      }
    });

    testWidgets('landing screens render without enabled future modules', (
      tester,
    ) async {
      for (final role in const ['CLINIC_KINE', 'CLINIC_ADMIN']) {
        final auth = AuthController(
          repository: FakeAuthRepository(_session(role)),
        );
        await auth.initialize();
        final repository = FakeClinicRepository()
          ..directory = _directory(
            active: [_membershipJson(clinicId: 'clinic-a', role: role)],
          )
          ..bootstraps['clinic-a'] = _bootstrap(
            clinicId: 'clinic-a',
            role: role,
          );

        await tester.pumpWidget(
          _appUnderTest(
            key: ValueKey(role),
            auth: auth,
            clinic: _controller(
              repository,
              ClinicSelectionStore(backend: FakeSecureBackend()),
            ),
          ),
        );
        await _pumpFrames(tester);

        if (role == 'CLINIC_KINE') {
          expect(find.byType(ClinicProfessionalHomeScreen), findsOneWidget);
          expect(find.text('Physiotherapist'), findsWidgets);
          // All six future modules are inert, never tappable actions.
          expect(
            find.byType(ClinicUnavailableModuleTile),
            findsNWidgets(ClinicFeatureModule.values.length),
          );
        } else {
          expect(find.byType(ClinicWebWorkspaceScreen), findsOneWidget);
          expect(find.byType(ClinicUnavailableModuleTile), findsNothing);
          expect(
            find.textContaining('web portal', findRichText: true),
            findsWidgets,
          );
        }
      }
    });

    testWidgets('multiple active clinics can switch back to the selector', (
      tester,
    ) async {
      final auth = AuthController(
        repository: FakeAuthRepository(_session('CLINIC_MEDECIN')),
      );
      await auth.initialize();
      final store = ClinicSelectionStore(backend: FakeSecureBackend());
      await store.saveSelectedClinicId('clinic-a');
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [
            _membershipJson(clinicId: 'clinic-a'),
            _membershipJson(clinicId: 'clinic-b'),
          ],
        )
        ..bootstraps['clinic-a'] = _bootstrap(clinicId: 'clinic-a')
        ..bootstraps['clinic-b'] = _bootstrap(clinicId: 'clinic-b');

      await tester.pumpWidget(
        _appUnderTest(auth: auth, clinic: _controller(repository, store)),
      );
      await _pumpFrames(tester);

      expect(find.byType(ClinicProfessionalHomeScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Switch clinic'));
      await tester.pump();
      await tester.tap(find.text('Switch clinic'));
      await _pumpFrames(tester, frames: 4);

      expect(find.byType(ClinicSelectionScreen), findsOneWidget);
    });
  });

  group('safe failures and session lifecycle', () {
    test('access family other than CLINIC fails safely', () async {
      final repository = FakeClinicRepository()
        ..accessFamily = ClinicAccessFamily.doctor;
      final controller = _controller(
        repository,
        ClinicSelectionStore(backend: FakeSecureBackend()),
      );

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );

      expect(controller.destination, ClinicDestination.accessUnavailable);
      expect(controller.failure!.kind, ClinicFailureKind.accessDenied);
      expect(repository.membershipCalls, 0);
    });

    test('ProblemDetail maps to a safe non-retryable access error', () {
      final failure = ClinicFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/clinics/x/bootstrap'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/clinics/x/bootstrap'),
            statusCode: 403,
            data: const {
              'type': 'https://errors.omnicare/clinic-scope',
              'title': 'Forbidden',
              'status': 403,
              'detail': 'Membership 8f2 is not scoped to clinic 9a1.',
              'instance': '/api/v1/clinics/9a1/bootstrap',
              'errorCode': 'CLINIC_SCOPE_FORBIDDEN',
              'requestId': 'req-1234',
              'timestamp': '2026-08-06T10:00:00Z',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.kind, ClinicFailureKind.accessDenied);
      expect(failure.retryable, isFalse);
      for (final leak in const [
        '8f2',
        '9a1',
        'req-1234',
        'CLINIC_SCOPE_FORBIDDEN',
        '/api/v1',
      ]) {
        expect(failure.message.contains(leak), isFalse, reason: leak);
      }
    });

    test('network failure stays retryable and is not a suspension', () async {
      final repository = FakeClinicRepository()
        ..accessError = DioException(
          requestOptions: RequestOptions(path: '/me/access'),
          type: DioExceptionType.connectionError,
        );
      final controller = _controller(
        repository,
        ClinicSelectionStore(backend: FakeSecureBackend()),
      );

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );

      final failure = controller.failure!;
      expect(failure.kind, ClinicFailureKind.network);
      expect(failure.retryable, isTrue);
      expect(failure.message.toLowerCase().contains('suspend'), isFalse);
      expect(failure.message.toLowerCase().contains('ended'), isFalse);
      expect(controller.destination, ClinicDestination.error);
    });

    test('clear() removes the context and the secure clinic hint', () async {
      final repository = FakeClinicRepository()
        ..directory = _directory(
          active: [_membershipJson(clinicId: 'clinic-a')],
        )
        ..bootstraps['clinic-a'] = _bootstrap(clinicId: 'clinic-a');
      final backend = FakeSecureBackend();
      final store = ClinicSelectionStore(backend: backend);
      final controller = _controller(repository, store);

      await controller.initializeForAuthenticatedUser(
        globalRole: 'CLINIC_MEDECIN',
      );
      expect(controller.bootstrap, isNotNull);

      await controller.clear();

      expect(controller.bootstrap, isNull);
      expect(controller.selectedClinicId, isNull);
      expect(controller.accessFamily, isNull);
      expect(controller.activeMemberships, isEmpty);
      expect(controller.failure, isNull);
      expect(controller.isInitialized, isFalse);
      expect(
        backend.values.containsKey(ClinicSelectionStore.storageKey),
        false,
      );
    });

    test('non-clinic roles never reach the clinic network', () async {
      final repository = FakeClinicRepository();
      final controller = _controller(
        repository,
        ClinicSelectionStore(backend: FakeSecureBackend()),
      );

      await controller.initializeForAuthenticatedUser(globalRole: 'PATIENT');
      await controller.initializeForAuthenticatedUser(globalRole: 'DOCTOR');

      expect(repository.accessCalls, 0);
      expect(controller.destination, ClinicDestination.accessUnavailable);
    });
  });
}
