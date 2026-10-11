import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/home/new_home_screen.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step0.dart';
import 'package:omnicare_mobile/features/request/provider_selection_screen.dart';
import 'package:omnicare_mobile/features/request_flow/screens/who_needs_care_screen.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() {
  group('Patient nested-Navigator route transitions', () {
    testWidgets(
      'transition between two routes shows opaque background ColoredBox',
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

        // Tap center nav → provider selection.
        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();
        expect(find.byType(ProviderSelectionScreen), findsOneWidget);

        // Tap Médecin → triggers transition to EmergencyRequestStep0.
        await tester.tap(find.text('Médecin'));
        // Pump once to capture the transition mid-flight (do not settle).
        await tester.pump();

        // The incoming route is wrapped in an opaque ColoredBox by
        // _buildPatientPageRoute. Verify it exists in the tree during
        // the transition — it blocks the outgoing route's content.
        expect(find.byType(ColoredBox), findsWidgets);

        await tester.pumpAndSettle();
        expect(find.byType(EmergencyRequestStep0), findsOneWidget);
      },
    );

    testWidgets(
      'full navigation cycle: provider selection → emergency → back → clinic flow',
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

        // Open provider selection.
        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();

        // Navigate to EmergencyRequestStep0.
        await tester.tap(find.text('Médecin'));
        await tester.pumpAndSettle();
        expect(find.byType(EmergencyRequestStep0), findsOneWidget);

        // Navigate back to provider selection via close button.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(ProviderSelectionScreen), findsOneWidget);

        // Navigate to WhoNeedsCareScreen via Clinique.
        await tester.scrollUntilVisible(find.text('Clinique'), 200);
        await tester.tap(find.text('Clinique'));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();

        // WhoNeedsCareScreen should render without an extra background
        // ColoredBox wrapper (it was removed in favor of the route surface).
        expect(find.byType(WhoNeedsCareScreen), findsOneWidget);
        expect(find.text('Who needs care?'), findsOneWidget);
      },
    );

    testWidgets(
      'transition completes within expected duration and destination renders',
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

        // Open provider selection.
        await tester.tap(find.byKey(const ValueKey('patient-care-action')));
        await tester.pumpAndSettle();

        // Navigate to EmergencyRequestStep0.
        await tester.tap(find.text('Médecin'));

        // After 300ms the 250ms transition should be complete.
        await tester.pump(const Duration(milliseconds: 300));

        // The destination must be fully rendered.
        expect(find.byType(EmergencyRequestStep0), findsOneWidget);
        expect(
          find.text('Comment souhaitez-vous\nconsulter ?'),
          findsOneWidget,
        );
      },
    );
  });
}

class _FakeRequestRepository implements RequestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

UserProvider _createTestUserProvider() {
  return UserProvider()
    ..setPatientProfile(
      const PatientProfile(
        userId: 'patient-user-1',
        firstName: 'Sarah',
        lastName: 'Martin',
        displayName: 'Sarah Martin',
        dateOfBirth: null,
        gender: null,
        photoUrl: null,
        primaryPhone: VerifiedContact(value: '+21698123456', verified: true),
        primaryEmail:
            VerifiedContact(value: 'sarah@example.tn', verified: true),
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
