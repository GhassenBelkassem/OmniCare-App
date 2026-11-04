import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_detail.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_filter_sheet.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_list_item.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_result_card.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

class _FakeFamilyRepository extends FamilyRepository {
  _FakeFamilyRepository({this.members = const []}) : super(api: FamilyApi());

  final List<FamilyMember> members;

  @override
  Future<List<FamilyMember>> getFamilyMembers() async => members;
}

class _CountingDoctorSource extends UrgentCabinetDoctorSource {
  _CountingDoctorSource(this.doctors);

  final List<UrgentCabinetDoctorListItem> doctors;
  int calls = 0;
  int detailCalls = 0;

  @override
  bool get isDevelopmentFixture => true;

  @override
  Future<List<UrgentCabinetDoctorListItem>> loadDoctors() async {
    calls++;
    return doctors;
  }

  @override
  Future<UrgentCabinetDoctorDetail?> loadDoctorDetail(String doctorId) async {
    detailCalls++;
    return const UrgentCabinetDoctorFixtureSource().loadDoctorDetail(doctorId);
  }
}

PatientProfile _profile(String userId) {
  return PatientProfile(
    userId: userId,
    firstName: 'Sarah',
    lastName: 'Martin',
    displayName: 'Sarah Martin',
    dateOfBirth: null,
    gender: null,
    photoUrl: null,
    primaryPhone: const VerifiedContact(value: '+21698123456', verified: true),
    primaryEmail: const VerifiedContact(
      value: 'sarah@example.tn',
      verified: true,
    ),
    onboardingCompleted: true,
    onboardingStep: 4,
    preferredLanguage: 'fr',
    notifications: const ProfileNotificationPreferences(
      medications: true,
      appointments: true,
      passport: true,
    ),
    updatedAt: null,
  );
}

FamilyMember _familyMember() {
  return FamilyMember(
    id: 'family-1',
    accountHolderId: 'patient-user-1',
    firstName: 'Aicha',
    lastName: 'Martin',
    dateOfBirth: DateTime(2014, 6, 15),
    gender: 'F',
    relationship: FamilyRelationships.parent,
    graduated: false,
  );
}

Widget _buildFlow({
  UrgentCabinetDoctorSource? source,
  UserProvider? userProvider,
  List<FamilyMember> familyMembers = const [],
  Key? shellKey,
  double textScale = 1,
}) {
  final user =
      userProvider ??
      (UserProvider()..setPatientProfile(_profile('patient-user-1')));
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: user),
      ChangeNotifierProvider(
        create: (_) => FamilyProvider(
          repository: _FakeFamilyRepository(members: familyMembers),
        ),
      ),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: UrgentCabinetFlowShell(key: shellKey, doctorSource: source),
      ),
    ),
  );
}

Future<UrgentCabinetFlowController> _selectSelfAndContinue(
  WidgetTester tester,
) async {
  if (find.text('Sarah Martin').evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text('Sarah Martin'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.tap(find.text('Sarah Martin'));
  await tester.pump();
  final selectorContext = tester.element(
    find.byType(UrgentCabinetCareSubjectScreen),
  );
  final controller = selectorContext.read<UrgentCabinetFlowController>();
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('urgent-cabinet-filter-action')));
  await tester.pumpAndSettle();
  expect(find.byType(UrgentCabinetDoctorFilterSheet), findsOneWidget);
}

Future<void> _completeSymptomIntake(WidgetTester tester) async {
  final body = find.byKey(const ValueKey('emergency-body-front'));
  await tester.ensureVisible(body);
  final bodyRect = tester.getRect(body);
  await tester.tapAt(
    Offset(
      bodyRect.left + bodyRect.width * .42,
      bodyRect.top + bodyRect.height * .2,
    ),
  );
  await tester.pump();
  final painSlider = find.byType(Slider);
  await tester.ensureVisible(painSlider);
  await tester.drag(painSlider, const Offset(24, 0));
  await tester.pump();
  final description = find.byKey(const ValueKey('emergency-description'));
  await tester.ensureVisible(description);
  await tester.enterText(description, 'Douleur aiguë depuis ce matin.');
  await tester.pump();
  final continueButton = find.byKey(const ValueKey('emergency-continue'));
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

Finder _filterSheetScrollable() {
  return find.descendant(
    of: find.byType(UrgentCabinetDoctorFilterSheet),
    matching: find.byType(Scrollable),
  );
}

Future<void> _scrollFilterIntoView(
  WidgetTester tester,
  Finder target, {
  double delta = 180,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: _filterSheetScrollable().first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'P4 model keeps eligibility, availability and request decision distinct',
    () {
      const doctor = UrgentCabinetDoctorListItem(
        doctorId: 'doctor-1',
        displayName: 'Dr. Test',
        specialty: 'Médecine générale',
        eligibility: UrgentCabinetEligibility.eligible,
        availability: UrgentCabinetAvailability.availableNow,
        activeCabinetId: 'cabinet-1',
        cabinetName: 'Cabinet Test',
        cabinetLocality: 'Tunis',
        cabinetGovernorate: 'Tunis',
        cabinetCity: 'Tunis',
        requestDecision: UrgentCabinetRequestDecision.pending,
      );

      expect(doctor.eligibility, UrgentCabinetEligibility.eligible);
      expect(doctor.availability, UrgentCabinetAvailability.availableNow);
      expect(doctor.requestDecision, UrgentCabinetRequestDecision.pending);
      expect(doctor.canReceiveUrgentRequest, isFalse);
    },
  );

  testWidgets(
    'Continue opens the P4 directory with shared cards and no P3 screen',
    (tester) async {
      final source = _CountingDoctorSource(
        UrgentCabinetDoctorFixtureSource.developmentDoctors,
      );
      await tester.pumpWidget(_buildFlow(source: source));
      await tester.pumpAndSettle();

      final controller = await _selectSelfAndContinue(tester);

      expect(find.byType(UrgentCabinetDoctorDirectoryScreen), findsOneWidget);
      expect(find.byType(DoctorResultCard), findsNWidgets(3));
      expect(find.byType(DoctorDirectoryScreen), findsNothing);
      expect(find.byType(DoctorDetailScreen), findsNothing);
      expect(source.calls, 1);
      expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
      expect(find.text('Données de démonstration'), findsOneWidget);
      expect(find.text('Disponible · démo'), findsNWidgets(3));
    },
  );

  testWidgets('SELF and family-member selections survive forward and back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFlow(
        source: const UrgentCabinetDoctorFixtureSource(),
        familyMembers: [_familyMember()],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aicha Martin'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    final controller = tester
        .element(find.byType(UrgentCabinetDoctorDirectoryScreen))
        .read<UrgentCabinetFlowController>();
    expect(
      controller.selectedSubject,
      UrgentCabinetCareSubject.familyMember('family-1'),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(UrgentCabinetCareSubjectScreen), findsOneWidget);
    expect(
      controller.selectedSubject,
      UrgentCabinetCareSubject.familyMember('family-1'),
    );
  });

  testWidgets('system back returns to the selector with SELF preserved', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
    );
    await tester.pumpAndSettle();
    final controller = await _selectSelfAndContinue(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(UrgentCabinetCareSubjectScreen), findsOneWidget);
    expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
  });

  testWidgets(
    'new journey starts clean and account switch returns to selector',
    (tester) async {
      final userProvider = UserProvider()
        ..setPatientProfile(_profile('patient-user-1'));
      await tester.pumpWidget(
        _buildFlow(
          source: const UrgentCabinetDoctorFixtureSource(),
          userProvider: userProvider,
          shellKey: const ValueKey('journey-1'),
        ),
      );
      await tester.pumpAndSettle();
      final oldController = await _selectSelfAndContinue(tester);

      userProvider.setPatientProfile(_profile('patient-user-2'));
      await tester.pumpAndSettle();

      expect(find.byType(UrgentCabinetCareSubjectScreen), findsOneWidget);
      expect(oldController.accountId, 'patient-user-2');
      expect(oldController.selectedSubject, isNull);

      await tester.pumpWidget(
        _buildFlow(
          source: const UrgentCabinetDoctorFixtureSource(),
          shellKey: const ValueKey('journey-2'),
        ),
      );
      await tester.pumpAndSettle();
      final newController = tester
          .element(find.byType(UrgentCabinetCareSubjectScreen))
          .read<UrgentCabinetFlowController>();
      expect(newController.selectedSubject, isNull);
      expect(identical(newController, oldController), isFalse);
    },
  );

  testWidgets('local search filters names and specialties', (tester) async {
    await tester.pumpWidget(
      _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
    );
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);

    await tester.enterText(find.byType(TextField), 'interne');
    await tester.pump();
    expect(find.text('Dr. Inès Trabelsi'), findsOneWidget);
    expect(find.text('Dr. Amine Ben Salah'), findsNothing);

    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-directory-empty-search')),
      findsOneWidget,
    );
  });

  testWidgets(
    'specialty filters support multi-select, clear, badge, and no reload',
    (tester) async {
      final source = _CountingDoctorSource(
        UrgentCabinetDoctorFixtureSource.developmentDoctors,
      );
      await tester.pumpWidget(_buildFlow(source: source));
      await tester.pumpAndSettle();
      await _selectSelfAndContinue(tester);

      await _openFilters(tester);
      final sheetFinder = find.byType(UrgentCabinetDoctorFilterSheet);
      final sheetHeight = tester.getSize(sheetFinder).height;
      final screenHeight = MediaQuery.sizeOf(
        tester.element(sheetFinder),
      ).height;
      expect(sheetHeight, lessThanOrEqualTo(screenHeight * 0.60 + 0.1));

      await tester.tap(
        find.byKey(const ValueKey('urgent-filter-specialty-Médecine générale')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('urgent-filter-specialty-Médecine interne')),
      );
      await tester.pump();
      await tester.tap(find.text('Afficher 2 médecins'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
      expect(find.text('Dr. Inès Trabelsi'), findsOneWidget);
      expect(find.text('Dr. Youssef Gharbi'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('urgent-cabinet-filter-count')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(source.calls, 1);

      await _openFilters(tester);
      await tester.tap(
        find.byKey(const ValueKey('urgent-filter-specialty-all')),
      );
      await tester.pump();
      await tester.tap(find.text('Afficher 3 médecins'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorResultCard), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('urgent-cabinet-filter-count')),
        findsNothing,
      );
      expect(source.calls, 1);
    },
  );

  testWidgets('city clears when a newly selected governorate is incompatible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
    );
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);
    await _openFilters(tester);

    final tunisGovernorate = find.byKey(
      const ValueKey('urgent-filter-Tous-Tunis'),
    );
    await _scrollFilterIntoView(tester, tunisGovernorate);
    await tester.tap(tunisGovernorate);
    await tester.pump();

    final tunisCity = find.byKey(const ValueKey('urgent-filter-Toutes-Tunis'));
    await _scrollFilterIntoView(tester, tunisCity);
    await tester.tap(tunisCity);
    await tester.pump();

    final arianaGovernorate = find.byKey(
      const ValueKey('urgent-filter-Tous-Ariana'),
    );
    await _scrollFilterIntoView(tester, arianaGovernorate, delta: -180);
    await tester.tap(arianaGovernorate);
    await tester.pump();

    final allCities = find.byKey(const ValueKey('urgent-filter-Toutes-all'));
    await _scrollFilterIntoView(tester, allCities);
    final allCitiesChip = find.descendant(
      of: allCities,
      matching: find.byType(FilterChip),
    );
    expect(tester.widget<FilterChip>(allCitiesChip).selected, isTrue);

    await tester.tap(find.text('Afficher 1 médecin'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Inès Trabelsi'), findsOneWidget);
    expect(find.text('Dr. Amine Ben Salah'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('urgent-cabinet-filter-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('detail back preserves applied filters and directory state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
    );
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);

    await tester.enterText(find.byType(TextField), 'amine');
    await tester.pump();

    await _openFilters(tester);
    await tester.tap(
      find.byKey(const ValueKey('urgent-filter-specialty-Médecine générale')),
    );
    await tester.pump();
    await tester.tap(find.text('Afficher 1 médecin'));
    await tester.pumpAndSettle();

    await _openFilters(tester);
    await tester.tap(
      find.byKey(const ValueKey('urgent-filter-specialty-Médecine interne')),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
    expect(find.text('Dr. Inès Trabelsi'), findsNothing);

    await tester.tap(find.text('Dr. Amine Ben Salah'));
    await tester.pumpAndSettle();
    expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
    );
    await tester.pumpAndSettle();
    await _completeSymptomIntake(tester);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-request-confirmation-screen')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('urgent-cabinet-detail-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-filter-count')),
      findsOneWidget,
    );
    expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'amine',
    );
  });

  testWidgets('directory scroll position survives detail navigation', (
    tester,
  ) async {
    final doctors = <UrgentCabinetDoctorListItem>[
      for (var index = 0; index < 10; index++)
        UrgentCabinetDoctorListItem(
          doctorId: 'scroll-doctor-$index',
          displayName: 'Dr. Défilement $index',
          specialty: 'Médecine générale',
          eligibility: UrgentCabinetEligibility.eligible,
          availability: UrgentCabinetAvailability.availableNow,
          activeCabinetId: 'scroll-cabinet-$index',
          cabinetName: 'Cabinet $index',
          cabinetLocality: 'Tunis',
          cabinetGovernorate: 'Tunis',
          cabinetCity: 'Tunis',
          distanceKm: index + 1,
        ),
      const UrgentCabinetDoctorListItem(
        doctorId: 'p4-demo-doctor-amine-ben-salah',
        displayName: 'Dr. Amine Ben Salah',
        specialty: 'Médecine générale',
        eligibility: UrgentCabinetEligibility.eligible,
        availability: UrgentCabinetAvailability.availableNow,
        activeCabinetId: 'p4-demo-cabinet-lac-1',
        cabinetName: 'Cabinet Les Berges du Lac',
        cabinetLocality: 'Les Berges du Lac, Tunis',
        cabinetGovernorate: 'Tunis',
        cabinetCity: 'Tunis',
        distanceKm: 99,
      ),
    ];
    final source = _CountingDoctorSource(doctors);
    await tester.pumpWidget(_buildFlow(source: source));
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);

    final list = find.byKey(const ValueKey('urgent-cabinet-doctor-list'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Dr. Amine Ben Salah'),
      240,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.text('Dr. Amine Ben Salah'));
    await tester.pumpAndSettle();
    expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
    );
    await tester.pumpAndSettle();
    await _completeSymptomIntake(tester);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-request-confirmation-screen')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('urgent-cabinet-detail-back')));
    await tester.pumpAndSettle();

    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, closeTo(before, 0.1));
    expect(source.calls, 1);
    expect(source.detailCalls, 2);
  });

  testWidgets('reset plus Apply clears filters without clearing search', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
    );
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);

    await tester.enterText(find.byType(TextField), 'gharbi');
    await tester.pump();
    await _openFilters(tester);
    await tester.tap(
      find.byKey(const ValueKey('urgent-filter-specialty-Médecine générale')),
    );
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-directory-empty-filters')),
      findsOneWidget,
    );

    await _openFilters(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(UrgentCabinetDoctorFilterSheet),
        matching: find.text('Réinitialiser'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Afficher 1 médecin'));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Youssef Gharbi'), findsOneWidget);
    expect(find.text('Dr. Amine Ben Salah'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'gharbi',
    );
    expect(
      find.byKey(const ValueKey('urgent-cabinet-filter-count')),
      findsNothing,
    );
  });

  testWidgets('loading, error, empty and disabled-source states are explicit', (
    tester,
  ) async {
    Future<void> pumpScenario(UrgentCabinetDoctorSource source, Key key) async {
      await tester.pumpWidget(_buildFlow(source: source, shellKey: key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarah Martin'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pump();
    }

    await pumpScenario(
      const UrgentCabinetDoctorFixtureSource(
        scenario: UrgentCabinetDoctorFixtureScenario.loading,
      ),
      const ValueKey('loading'),
    );
    expect(
      find.byKey(const ValueKey('urgent-cabinet-directory-loading')),
      findsOneWidget,
    );

    await pumpScenario(
      const UrgentCabinetDoctorFixtureSource(
        scenario: UrgentCabinetDoctorFixtureScenario.error,
      ),
      const ValueKey('error'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-directory-error')),
      findsOneWidget,
    );

    await pumpScenario(
      const UrgentCabinetDoctorFixtureSource(
        scenario: UrgentCabinetDoctorFixtureScenario.noEligibleDoctors,
      ),
      const ValueKey('empty'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-directory-no-eligible')),
      findsOneWidget,
    );

    await pumpScenario(
      const UrgentCabinetDoctorUnavailableSource(),
      const ValueKey('unavailable'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-directory-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Données de démonstration'), findsNothing);
  });

  testWidgets('missing distance is omitted without hiding cabinet locality', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
    );
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);

    final card = find.byKey(
      const ValueKey(
        'urgent-cabinet-doctor-p4-demo-doctor-youssef-gharbi-p4-demo-cabinet-lafayette-1',
      ),
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Centre médical Lafayette · Lafayette, Tunis'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('km')),
      findsNothing,
    );
  });

  testWidgets(
    'doctor selection remains in P4 and stores doctor and cabinet IDs',
    (tester) async {
      await tester.pumpWidget(
        _buildFlow(source: const UrgentCabinetDoctorFixtureSource()),
      );
      await tester.pumpAndSettle();
      final controller = await _selectSelfAndContinue(tester);

      await tester.tap(find.text('Dr. Amine Ben Salah'));
      await tester.pumpAndSettle();

      expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);
      expect(controller.selectedDoctorId, 'p4-demo-doctor-amine-ben-salah');
      expect(controller.selectedCabinetId, 'p4-demo-cabinet-lac-1');
      expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
      expect(find.byType(DoctorDetailScreen), findsNothing);
    },
  );

  testWidgets('small screen and larger text remain overflow-free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildFlow(
        source: const UrgentCabinetDoctorFixtureSource(),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    await _selectSelfAndContinue(tester);

    expect(find.byType(DoctorResultCard), findsWidgets);
    await _openFilters(tester);
    await _scrollFilterIntoView(tester, find.text('Trier par'));
    expect(find.text('Réinitialiser'), findsOneWidget);
    expect(find.text('Afficher 3 médecins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
