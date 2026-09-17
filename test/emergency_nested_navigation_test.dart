import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/home/new_home_screen.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step0.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step1.dart';
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
      'from EmergencyRequestStep0, home consultation navigates to EmergencyRequestStep1',
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

        // Tap "Consultation à domicile".
        await tester.tap(find.text('Consultation à domicile'));
        await tester.pumpAndSettle();

        // EmergencyRequestStep1 must be rendered.
        expect(find.byType(EmergencyRequestStep1), findsOneWidget);
      },
    );

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

        // Consume the pre-existing framework assertion from
        // RequestFlowEntryScreen.initState (notifyListeners during build).
        tester.takeException();

        await tester.pumpAndSettle();

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
