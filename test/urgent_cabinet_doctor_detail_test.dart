import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_clinical_intake_draft.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_detail.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_list_item.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_routes.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/widgets/clinic_full_screen_gallery.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_availability_sheet.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_detail_screen.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

class _StaticDetailSource extends UrgentCabinetDoctorSource {
  const _StaticDetailSource({
    required this.detail,
    this.developmentFixture = true,
    this.error,
  });

  final UrgentCabinetDoctorDetail? detail;
  final bool developmentFixture;
  final Object? error;

  @override
  bool get isDevelopmentFixture => developmentFixture;

  @override
  Future<List<UrgentCabinetDoctorListItem>> loadDoctors() async => const [];

  @override
  Future<UrgentCabinetDoctorDetail?> loadDoctorDetail(String doctorId) async {
    final failure = error;
    if (failure != null) throw failure;
    return detail;
  }
}

UrgentCabinetFlowController _selectedController({
  String doctorId = 'p4-demo-doctor-amine-ben-salah',
  String cabinetId = 'p4-demo-cabinet-lac-1',
}) {
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1')
    ..selectSelf()
    ..selectDoctor(doctorId: doctorId, cabinetId: cabinetId);
  final detail = UrgentCabinetDoctorFixtureSource.developmentDoctorDetails
      .where((candidate) => candidate.doctorId == doctorId)
      .firstOrNull;
  if (detail != null && detail.cabinetById(cabinetId) != null) {
    controller.captureQuoteSnapshot(detail);
    controller.saveClinicalIntake(
      UrgentCabinetClinicalIntakeDraft(
        careSubject: const UrgentCabinetCareSubject.self(),
        doctorId: doctorId,
        cabinetId: cabinetId,
        rawAnatomicalRegionIds: const ['front-head'],
        painScore: 6,
        shortDescription: 'Douleur aiguë depuis ce matin.',
      ),
    );
  }
  return controller;
}

Widget _buildDetail({
  required UrgentCabinetFlowController controller,
  UrgentCabinetDoctorSource source = const UrgentCabinetDoctorFixtureSource(),
  double textScale = 1,
}) {
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      localizationsDelegates: OmniLocalizations.localizationsDelegates,
      supportedLocales: OmniLocalizations.supportedLocales,
      theme: buildOmniTheme(),
      routes: {
        UrgentCabinetFlowRoutes.requestConfirmation: (_) => const Scaffold(
          body: Center(
            child: Text(
              'P4 request confirmation',
              key: ValueKey('p4-request-confirmation-route'),
            ),
          ),
        ),
      },
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: UrgentCabinetDoctorDetailScreen(source: source),
    ),
  );
}

Future<void> _openCabinetTab(WidgetTester tester) async {
  await tester.tap(find.text('Cabinet'));
  await tester.pumpAndSettle();
}

void main() {
  test('typed detail resolves the exact selected cabinet ID', () {
    final detail =
        UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;

    expect(detail.cabinets.first.cabinetId, 'p4-demo-cabinet-annexe');
    expect(
      detail.cabinetById('p4-demo-cabinet-lac-1')?.name,
      'Cabinet Les Berges du Lac',
    );
    expect(detail.cabinetById('unknown-cabinet'), isNull);
    expect(
      detail.provenance,
      UrgentCabinetDoctorDetailProvenance.developmentFixture,
    );
  });

  test('development fixtures are disabled when the build flag is false', () {
    expect(
      UrgentCabinetDoctorSources.forBuild(enableDevelopmentFixtures: false),
      isA<UrgentCabinetDoctorUnavailableSource>(),
    );
    expect(
      UrgentCabinetDoctorSources.forBuild(enableDevelopmentFixtures: true),
      isA<UrgentCabinetDoctorFixtureSource>(),
    );
  });

  testWidgets(
    'renders selected P4 identity and exactly two non-scheduled tabs',
    (tester) async {
      final controller = _selectedController();
      await tester.pumpWidget(_buildDetail(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);
      expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
      expect(find.text('Médecine générale'), findsOneWidget);
      expect(find.text('Soins de premier recours'), findsOneWidget);
      expect(find.text('Arabe · Français'), findsOneWidget);
      expect(find.text('Profil de démonstration'), findsOneWidget);
      expect(find.text('À propos'), findsOneWidget);
      expect(find.text('Cabinet'), findsOneWidget);
      await tester.drag(
        find.byKey(const PageStorageKey('urgent-cabinet-detail-about-scroll')),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voir plus'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('urgent-cabinet-detail-tabs')),
          matching: find.byKey(const ValueKey('urgent-cabinet-detail-tab-0')),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-detail-tab-2')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('urgent-cabinet-detail-tabs')),
          matching: find.byKey(const ValueKey('urgent-cabinet-detail-tab-1')),
        ),
        findsOneWidget,
      );
      expect(find.text('Disponibilités'), findsNothing);
      expect(find.textContaining('créneau'), findsNothing);
      expect(find.byType(DoctorAvailabilitySheet), findsNothing);
      expect(find.byType(DoctorDetailScreen), findsNothing);
      expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
    },
  );

  testWidgets('uses exact cabinet, opens gallery, and returns to details', (
    tester,
  ) async {
    final controller = _selectedController();
    await tester.pumpWidget(_buildDetail(controller: controller));
    await tester.pumpAndSettle();
    await _openCabinetTab(tester);

    expect(
      find.byKey(const ValueKey('urgent-cabinet-detail-gallery')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-gallery-image-0')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClinicFullScreenGallery), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);

    await tester.drag(
      find.byKey(const PageStorageKey('urgent-cabinet-detail-cabinet-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cabinet Les Berges du Lac'), findsOneWidget);
    expect(find.text('Cabinet annexe de démonstration'), findsNothing);
    expect(find.text('Rue du Lac Victoria'), findsOneWidget);
  });

  testWidgets('continue opens the P4 confirmation route and preserves IDs', (
    tester,
  ) async {
    final controller = _selectedController();
    await tester.pumpWidget(_buildDetail(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('p4-request-confirmation-route')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('urgent-cabinet-confirmation-next-dialog')),
      findsNothing,
    );
    expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
    expect(controller.selectedDoctorId, 'p4-demo-doctor-amine-ben-salah');
    expect(controller.selectedCabinetId, 'p4-demo-cabinet-lac-1');
    expect(find.byType(DoctorDetailScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);
  });

  testWidgets('missing optional profile and gallery use safe omissions', (
    tester,
  ) async {
    final controller = _selectedController(
      doctorId: 'p4-demo-doctor-youssef-gharbi',
      cabinetId: 'p4-demo-cabinet-lafayette-1',
    );
    await tester.pumpWidget(_buildDetail(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Youssef Gharbi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-doctor-initials')),
      findsOneWidget,
    );
    expect(
      find.text('Aucune information de profil supplémentaire.'),
      findsOneWidget,
    );

    await _openCabinetTab(tester);
    expect(find.text('Aucune photo du cabinet disponible.'), findsOneWidget);
    expect(find.text('Centre médical Lafayette'), findsOneWidget);
  });

  testWidgets('invalid portrait and gallery assets fall back safely', (
    tester,
  ) async {
    const detail = UrgentCabinetDoctorDetail(
      doctorId: 'doctor-broken-image',
      displayName: 'Dr. Image Test',
      specialty: 'Médecine générale',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      provenance: UrgentCabinetDoctorDetailProvenance.developmentFixture,
      portrait: UrgentCabinetDoctorImage.asset('assets/missing-doctor.jpg'),
      cabinets: [
        UrgentCabinetLocationDetail(
          cabinetId: 'cabinet-broken-image',
          name: 'Cabinet Test',
          locality: 'Tunis',
          city: 'Tunis',
          governorate: 'Tunis',
          gallery: [
            UrgentCabinetDoctorImage.asset('assets/missing-cabinet.jpg'),
          ],
        ),
      ],
    );
    final controller = _selectedController(
      doctorId: detail.doctorId,
      cabinetId: detail.cabinets.single.cabinetId,
    );
    await tester.pumpWidget(
      _buildDetail(
        controller: controller,
        source: const _StaticDetailSource(detail: detail),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('urgent-cabinet-doctor-initials')),
      findsOneWidget,
    );
    await _openCabinetTab(tester);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-detail-gallery')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing selection, doctor, cabinet, disabled, and error states',
    (tester) async {
      Future<void> pump(
        UrgentCabinetFlowController controller,
        UrgentCabinetDoctorSource source,
        Key expected,
      ) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _buildDetail(controller: controller, source: source),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(expected), findsOneWidget);
      }

      await pump(
        UrgentCabinetFlowController(accountId: 'patient-user-1'),
        const UrgentCabinetDoctorFixtureSource(),
        const ValueKey('urgent-cabinet-detail-missing-selection'),
      );
      await pump(
        _selectedController(doctorId: 'missing-doctor'),
        const UrgentCabinetDoctorFixtureSource(),
        const ValueKey('urgent-cabinet-detail-missing-doctor'),
      );
      await pump(
        _selectedController(cabinetId: 'missing-cabinet'),
        const UrgentCabinetDoctorFixtureSource(),
        const ValueKey('urgent-cabinet-detail-unknown-cabinet'),
      );
      await pump(
        _selectedController(),
        const UrgentCabinetDoctorUnavailableSource(),
        const ValueKey('urgent-cabinet-detail-unavailable'),
      );
      await pump(
        _selectedController(),
        _StaticDetailSource(
          detail:
              UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first,
          developmentFixture: false,
        ),
        const ValueKey('urgent-cabinet-detail-unavailable'),
      );
      await pump(
        _selectedController(),
        const _StaticDetailSource(
          detail: null,
          error: UrgentCabinetDoctorFixtureException(),
        ),
        const ValueKey('urgent-cabinet-detail-error'),
      );
    },
  );

  testWidgets('fixture detail loading state is explicit', (tester) async {
    await tester.pumpWidget(
      _buildDetail(
        controller: _selectedController(),
        source: const UrgentCabinetDoctorFixtureSource(
          scenario: UrgentCabinetDoctorFixtureScenario.loading,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('urgent-cabinet-detail-loading')),
      findsOneWidget,
    );
  });

  testWidgets('narrow screen and large text remain overflow-free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildDetail(controller: _selectedController(), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
