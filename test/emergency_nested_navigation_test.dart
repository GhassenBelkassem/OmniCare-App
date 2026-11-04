import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/home/new_home_screen.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step0.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step1.dart';
import 'package:omnicare_mobile/features/emergency/urgent_care_mode_selection_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject_screen.dart';
import 'package:omnicare_mobile/features/request_flow/screens/doctor_cabinet_entry_screen.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() {
  group('Médecin emergency navigation from patient nested navigator', () {
    testWidgets(
      'tapping Médecin from provider selection renders EmergencyRequestStep0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final userProvider = _createTestUserProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
              ChangeNotifierProvider(create: (_) => FamilyProvider()),
              ChangeNotifierProvider(
                create: (_) => RequestSubmissionController(
                  repository: _FakeRequestRepository(),
                ),
              ),
            ],
            child: MaterialApp(
              routes: {
                '/medical-documents': (_) =>
                    const Scaffold(body: Text('medical-docs')),
                '/notifications': (_) =>
                    const Scaffold(body: Text('notifications')),
              },
              home: const NewHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the center nav button to open provider selection in nested nav.
        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();

        // Verify provider selection screen is shown.
        expect(find.text('Quel service\navez-vous besoin ?'), findsOneWidget);

        // Tap Médecin.
        await tester.tap(find.text('Médecin'));
        await tester.pumpAndSettle();

        // EmergencyRequestStep0 must be rendered — not another home tab.
        expect(find.byType(EmergencyRequestStep0), findsOneWidget);
        expect(
          find.text('Comment souhaitez-vous\nconsulter ?'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'urgent home selection preserves context and opens EmergencyRequestStep1',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final userProvider = _createTestUserProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
              ChangeNotifierProvider(create: (_) => FamilyProvider()),
              ChangeNotifierProvider(
                create: (_) => RequestSubmissionController(
                  repository: _FakeRequestRepository(),
                ),
              ),
            ],
            child: MaterialApp(
              routes: {
                '/medical-documents': (_) =>
                    const Scaffold(body: Text('medical-docs')),
                '/notifications': (_) =>
                    const Scaffold(body: Text('notifications')),
              },
              home: const NewHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open provider selection → tap Médecin.
        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Médecin'));
        await tester.pumpAndSettle();

        expect(find.byType(EmergencyRequestStep0), findsOneWidget);

        expect(find.text('Demande urgente'), findsOneWidget);
        expect(find.text('Consultation au cabinet'), findsOneWidget);

        await tester.tap(find.text('Demande urgente'));
        await tester.pumpAndSettle();

        expect(find.byType(UrgentCareModeSelectionScreen), findsOneWidget);
        expect(find.text('Urgence à domicile'), findsOneWidget);
        expect(find.text('Urgence au cabinet'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-bottom-navigation')),
          findsOneWidget,
        );

        await tester.tap(find.text('Urgence à domicile'));
        await tester.pumpAndSettle();

        expect(find.byType(EmergencyRequestStep1), findsOneWidget);
        final step1Context = tester.element(find.byType(EmergencyRequestStep1));
        expect(ModalRoute.of(step1Context)?.settings.arguments, {
          'consultationType': 'home',
          'providerType': 'doctor',
        });
      },
    );

    testWidgets(
      'urgent cabinet opens P4 selector and never opens P3 cabinet flow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final userProvider = _createTestUserProvider();

        final requestController = RequestSubmissionController(
          repository: _FakeRequestRepository(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
              ChangeNotifierProvider(create: (_) => FamilyProvider()),
              ChangeNotifierProvider<RequestSubmissionController>.value(
                value: requestController,
              ),
            ],
            child: MaterialApp(
              routes: {
                '/medical-documents': (_) =>
                    const Scaffold(body: Text('medical-docs')),
                '/notifications': (_) =>
                    const Scaffold(body: Text('notifications')),
              },
              home: const NewHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Médecin'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Demande urgente'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Urgence au cabinet'));
        await tester.pumpAndSettle();

        expect(find.byType(UrgentCabinetCareSubjectScreen), findsOneWidget);
        expect(find.text('Qui a besoin de soins ?'), findsOneWidget);
        expect(find.byType(DoctorCabinetEntryScreen), findsNothing);
        expect(requestController.status, RequestSubmissionStatus.idle);
        expect(requestController.operationId, isNull);

        expect(find.byType(DoctorCabinetEntryScreen), findsNothing);
        expect(
          find.byKey(const ValueKey('home-bottom-navigation')),
          findsOneWidget,
        );
        expect(requestController.status, RequestSubmissionStatus.idle);

        await tester.tap(find.byTooltip('Fermer'));
        await tester.pumpAndSettle();
        expect(find.byType(UrgentCareModeSelectionScreen), findsOneWidget);

        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        expect(find.byType(EmergencyRequestStep0), findsOneWidget);
      },
    );

    testWidgets('normal cabinet option still opens its frozen P3 entry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final userProvider = _createTestUserProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
            ChangeNotifierProvider(create: (_) => FamilyProvider()),
            ChangeNotifierProvider(
              create: (_) => RequestSubmissionController(
                repository: _FakeRequestRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            routes: {
              '/medical-documents': (_) =>
                  const Scaffold(body: Text('medical-docs')),
              '/notifications': (_) =>
                  const Scaffold(body: Text('notifications')),
            },
            home: const NewHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('patient-care-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Médecin'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.descendant(
          of: find.byType(EmergencyRequestStep0),
          matching: find.byType(ListView),
        ),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultation au cabinet'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorCabinetEntryScreen), findsOneWidget);
      expect(find.text('Who needs care?'), findsOneWidget);
    });

    testWidgets(
      'tapping Clinique from provider selection still opens M05 request flow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final userProvider = _createTestUserProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
              ChangeNotifierProvider(create: (_) => FamilyProvider()),
              ChangeNotifierProvider(
                create: (_) => RequestSubmissionController(
                  repository: _FakeRequestRepository(),
                ),
              ),
            ],
            child: MaterialApp(
              routes: {
                '/medical-documents': (_) =>
                    const Scaffold(body: Text('medical-docs')),
                '/notifications': (_) =>
                    const Scaffold(body: Text('notifications')),
              },
              home: const NewHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open provider selection → tap Clinique.
        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Clinique'), 200);
        await tester.tap(find.text('Clinique'));
        await tester.pump();
        await tester.pump();

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // M05 WhoNeedsCareScreen must be rendered (request flow entry).
        expect(find.text('Who needs care?'), findsOneWidget);
        expect(find.text('Choose who this request is for.'), findsOneWidget);
      },
    );
  });
}

/// Minimal fake to satisfy RequestSubmissionController's repository dependency.
class _FakeRequestRepository implements RequestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

UserProvider _createTestUserProvider() {
  return UserProvider()..setPatientProfile(
    const PatientProfile(
      userId: 'patient-user-1',
      firstName: 'Sarah',
      lastName: 'Martin',
      displayName: 'Sarah Martin',
      dateOfBirth: null,
      gender: null,
      photoUrl: null,
      primaryPhone: VerifiedContact(value: '+21698123456', verified: true),
      primaryEmail: VerifiedContact(value: 'sarah@example.tn', verified: true),
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
}
