import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_routes.dart';
import 'package:omnicare_mobile/features/home/add_family_member_screen.dart';
import 'package:omnicare_mobile/features/request_flow/widgets/care_subject_card.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

class _FakeFamilyRepository extends FamilyRepository {
  _FakeFamilyRepository({this.members = const [], this.createError})
    : super(api: FamilyApi());

  final List<FamilyMember> members;
  final Object? createError;
  int createCalls = 0;

  @override
  Future<Result<List<FamilyMember>>> getFamilyMembers() async => Ok(members);

  @override
  Future<Result<FamilyMember>> createFamilyMember({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) async {
    createCalls++;
    final error = createError;
    if (error != null) return Err(ApiFailure.from(error));
    return Ok(
      FamilyMember(
        id: 'created-$createCalls',
        accountHolderId: 'holder',
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        relationship: relationship,
        graduated: false,
        photoUrl: photoUrl,
      ),
    );
  }
}

FamilyMember _member(String id) {
  return FamilyMember(
    id: id,
    accountHolderId: 'holder',
    firstName: 'Aicha',
    lastName: 'Martin $id',
    dateOfBirth: DateTime(2014, 6, 15),
    gender: 'F',
    relationship: FamilyRelationships.parent,
    graduated: false,
  );
}

UserProvider _userProvider() {
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

Widget _buildApp({
  required UrgentCabinetFlowController controller,
  _FakeFamilyRepository? repository,
  String nextRoute = UrgentCabinetFlowRoutes.doctorDirectory,
}) {
  final family = FamilyProvider(
    repository: repository ?? _FakeFamilyRepository(),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: _userProvider()),
      ChangeNotifierProvider<FamilyProvider>.value(value: family),
      ChangeNotifierProvider<UrgentCabinetFlowController>.value(
        value: controller,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: OmniLocalizations.localizationsDelegates,
      supportedLocales: OmniLocalizations.supportedLocales,
      theme: buildOmniTheme(),
      routes: {
        UrgentCabinetFlowRoutes.doctorDirectory: (_) =>
            const UrgentCabinetDoctorDirectoryScreen(
              source: UrgentCabinetDoctorFixtureSource(),
            ),
        UrgentCabinetFlowRoutes.symptomIntake: (_) => const Scaffold(
          body: Text(
            'Symptom intake route',
            key: ValueKey('normal-symptom-intake-route'),
          ),
        ),
      },
      home: Scaffold(
        body: UrgentCabinetCareSubjectScreen(nextRoute: nextRoute),
      ),
    ),
  );
}

Future<void> _openOther(WidgetTester tester) async {
  await tester.tap(find.text('Autre personne'));
  await tester.pumpAndSettle();
}

Future<void> _fillFamilyForm(WidgetTester tester) async {
  final textFields = find.byType(TextFormField);
  await tester.enterText(textFields.at(0), 'Leila');
  await tester.enterText(textFields.at(1), 'Martin');
  await tester.tap(find.text('Choisir une date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('7').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Femme'));
  final form = find.byKey(const ValueKey('family-member-form-scroll'));
  for (var index = 0; index < 5; index++) {
    await tester.fling(form, const Offset(0, -900), 5000);
    await tester.pump();
  }
  final relationship = find.byWidgetPredicate(
    (widget) => widget is DropdownButtonFormField<String>,
    description: 'family relationship dropdown',
  );
  await tester.ensureVisible(relationship);
  await tester.tap(relationship);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parent').last);
  await tester.pump();
}

Future<void> _submitFamilyForm(WidgetTester tester) async {
  final add = find.text('Ajouter', skipOffstage: false);
  await tester.ensureVisible(add);
  await tester.tap(add);
  await tester.pumpAndSettle();
}

void main() {
  group('UrgentCabinetCareSubject', () {
    test('enforces typed SELF and FAMILY_MEMBER invariants', () {
      const self = UrgentCabinetCareSubject.self();
      final family = UrgentCabinetCareSubject.familyMember(' family-1 ');

      expect(self.type, UrgentCabinetCareSubjectType.self);
      expect(self.familyMemberId, isNull);
      expect(family.type, UrgentCabinetCareSubjectType.familyMember);
      expect(family.familyMemberId, 'family-1');
      expect(
        () => UrgentCabinetCareSubject.familyMember('  '),
        throwsArgumentError,
      );
    });

    test('controller clears its draft for a new journey or account', () {
      final controller = UrgentCabinetFlowController(accountId: 'account-1');
      controller.selectFamilyMember('family-1');
      controller.beginNewJourney(accountId: 'account-1');
      expect(controller.selectedSubject, isNull);

      controller.selectSelf();
      controller.selectDoctor(doctorId: 'doctor-1', cabinetId: 'cabinet-1');
      controller.ensureAccount('account-2');
      expect(controller.accountId, 'account-2');
      expect(controller.selectedSubject, isNull);
      expect(controller.selectedDoctorId, isNull);
      expect(controller.selectedCabinetId, isNull);
    });
  });

  group('UrgentCabinetCareSubjectScreen', () {
    testWidgets('requires explicit selection and renders real provider data', (
      tester,
    ) async {
      final controller = UrgentCabinetFlowController(
        accountId: 'patient-user-1',
      );
      await tester.pumpWidget(
        _buildApp(
          controller: controller,
          repository: _FakeFamilyRepository(members: [_member('family-1')]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Qui a besoin de soins ?'), findsOneWidget);
      expect(find.text('Sarah Martin'), findsOneWidget);
      expect(find.text('Aicha Martin family-1'), findsOneWidget);
      expect(find.text('Autre personne'), findsOneWidget);
      expect(controller.selectedSubject, isNull);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });

    testWidgets(
      'SELF is typed and retained after visiting the doctor directory',
      (tester) async {
        final controller = UrgentCabinetFlowController(
          accountId: 'patient-user-1',
        );
        await tester.pumpWidget(_buildApp(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sarah Martin'));
        await tester.pump();
        expect(
          controller.selectedSubject,
          const UrgentCabinetCareSubject.self(),
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );

        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(find.byType(UrgentCabinetDoctorDirectoryScreen), findsOneWidget);
        expect(find.text('Médecins disponibles au cabinet'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(
          controller.selectedSubject,
          const UrgentCabinetCareSubject.self(),
        );
        final selectedCards = tester
            .widgetList<CareSubjectCard>(find.byType(CareSubjectCard))
            .where((card) => card.selected);
        expect(selectedCards.single.title, 'Sarah Martin');
      },
    );

    testWidgets('normal flow routes from care subject to symptom intake', (
      tester,
    ) async {
      final controller = UrgentCabinetFlowController(
        accountId: 'patient-user-1',
      );
      await tester.pumpWidget(
        _buildApp(
          controller: controller,
          nextRoute: UrgentCabinetFlowRoutes.symptomIntake,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sarah Martin'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('normal-symptom-intake-route')),
        findsOneWidget,
      );
      expect(find.byType(UrgentCabinetDoctorDirectoryScreen), findsNothing);
    });

    testWidgets('family selection stores only the persisted family-member ID', (
      tester,
    ) async {
      final controller = UrgentCabinetFlowController(
        accountId: 'patient-user-1',
      );
      await tester.pumpWidget(
        _buildApp(
          controller: controller,
          repository: _FakeFamilyRepository(members: [_member('family-1')]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aicha Martin family-1'));
      await tester.pump();

      expect(
        controller.selectedSubject,
        UrgentCabinetCareSubject.familyMember('family-1'),
      );
    });

    testWidgets(
      'Autre personne reuses the family form and cancel preserves selection',
      (tester) async {
        final controller = UrgentCabinetFlowController(
          accountId: 'patient-user-1',
        )..selectSelf();
        await tester.pumpWidget(_buildApp(controller: controller));
        await tester.pumpAndSettle();

        await _openOther(tester);
        expect(find.byType(AddFamilyMemberScreen), findsOneWidget);
        expect(find.text('Ajouter un proche'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(
          controller.selectedSubject,
          const UrgentCabinetCareSubject.self(),
        );
      },
    );

    testWidgets(
      'successful family creation persists and selects the new member',
      (tester) async {
        final controller = UrgentCabinetFlowController(
          accountId: 'patient-user-1',
        );
        final repository = _FakeFamilyRepository();
        await tester.pumpWidget(
          _buildApp(controller: controller, repository: repository),
        );
        await tester.pumpAndSettle();
        await _openOther(tester);
        await _fillFamilyForm(tester);
        await _submitFamilyForm(tester);

        expect(repository.createCalls, 1);
        expect(find.text('Leila Martin'), findsOneWidget);
        expect(
          controller.selectedSubject,
          UrgentCabinetCareSubject.familyMember('created-1'),
        );
      },
    );

    testWidgets(
      'failed family creation preserves the previous valid selection',
      (tester) async {
        final controller = UrgentCabinetFlowController(
          accountId: 'patient-user-1',
        )..selectSelf();
        final repository = _FakeFamilyRepository(
          createError: StateError('create failed'),
        );
        await tester.pumpWidget(
          _buildApp(controller: controller, repository: repository),
        );
        await tester.pumpAndSettle();
        await _openOther(tester);
        await _fillFamilyForm(tester);
        await _submitFamilyForm(tester);

        expect(repository.createCalls, 1);
        expect(find.byType(AddFamilyMemberScreen), findsOneWidget);
        expect(
          controller.selectedSubject,
          const UrgentCabinetCareSubject.self(),
        );
      },
    );

    testWidgets('long family lists remain scrollable on a small screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = UrgentCabinetFlowController(
        accountId: 'patient-user-1',
      );
      await tester.pumpWidget(
        _buildApp(
          controller: controller,
          repository: _FakeFamilyRepository(
            members: List.generate(10, (index) => _member('family-$index')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Autre personne'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Autre personne'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
