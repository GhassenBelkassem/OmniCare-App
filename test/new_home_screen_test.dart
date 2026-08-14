import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/features/home/new_home_screen.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home recovers after the login keyboard inset closes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final userProvider = UserProvider()
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
          primaryEmail: VerifiedContact(
            value: 'sarah@example.tn',
            verified: true,
          ),
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
    final bottomInset = ValueNotifier<double>(420);
    addTearDown(bottomInset.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
          ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ],
        child: MaterialApp(
          builder: (context, child) {
            return ValueListenableBuilder<double>(
              valueListenable: bottomInset,
              builder: (context, inset, _) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
                  child: child!,
                );
              },
            );
          },
          routes: {
            '/notifications': (_) => const _Placeholder(),
            '/provider-selection': (_) => const _Placeholder(),
            '/medical-documents': (_) => const _Placeholder(),
          },
          home: const NewHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Sarah'), findsOneWidget);
    expect(find.text('Votre rendez-vous santé'), findsOneWidget);
    expect(find.bySemanticsLabel('Accueil'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final scaffoldContext = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.viewInsetsOf(scaffoldContext).bottom, 0);
    expect(tester.getSize(find.byType(NewHomeScreen)).height, 844);
    expect(tester.getSize(find.byType(Scaffold).first).height, 844);
    final initialNav = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation')),
    );
    expect(initialNav.top, greaterThan(770));

    bottomInset.value = 0;
    await tester.pumpAndSettle();
    final homeNav = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation')),
    );
    expect(homeNav.bottom, greaterThan(780));
  });
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}
