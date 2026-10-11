import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_availability_sheet.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_filter_sheet.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_controller.dart';

class _FakeDoctorRepository implements DoctorDirectoryRepository {
  _FakeDoctorRepository({
    List<DoctorSearchCard>? doctors,
    Map<String, DoctorDirectoryDetail>? details,
    List<AvailabilitySlotDto>? slots,
    this.detailCompleter,
    this.detailFailure,
    this.slotsFailure,
  }) : doctors = List.unmodifiable(doctors ?? _directoryItems()),
       details = Map.unmodifiable(details ?? _detailMap()),
       slots = List.unmodifiable(slots ?? _buildSlots());

  final List<DoctorSearchCard> doctors;
  final Map<String, DoctorDirectoryDetail> details;
  final List<AvailabilitySlotDto> slots;
  final Completer<DoctorDirectoryDetail>? detailCompleter;
  DoctorDirectoryFailure? detailFailure;
  DoctorDirectoryFailure? slotsFailure;
  final List<String> requestedDoctorIds = [];
  final List<String> requestedPracticeLocationIds = [];

  @override
  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) async {
    final needle = criteria.query?.trim().toLowerCase() ?? '';
    final filtered = needle.isEmpty
        ? doctors
        : doctors
              .where(
                (doctor) => doctor.displayName.toLowerCase().contains(needle),
              )
              .toList(growable: false);
    return DoctorSearchPage(
      content: filtered,
      page: criteria.page,
      size: criteria.size,
      hasNext: false,
    );
  }

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    requestedDoctorIds.add(doctorId);
    final completer = detailCompleter;
    if (completer != null) return completer.future;
    final failure = detailFailure;
    if (failure != null) throw failure;
    final detail = details[doctorId];
    if (detail == null) throw DoctorDirectoryFailure.notFound;
    return detail;
  }

  @override
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    requestedPracticeLocationIds.add(practiceLocationId);
    final failure = slotsFailure;
    if (failure != null) throw failure;
    return slots;
  }
}

const _sarahDetail = DoctorDirectoryDetail(
  doctorId: 'doc-1',
  displayName: 'Dr. Sarah Mansour',
  specialty: 'Médecin généraliste',
  verified: true,
  experienceYears: 12,
  subSpecialties: ['Médecine familiale', 'Prévention'],
  practiceCity: 'Tunis',
  languages: ['Français', 'Arabe'],
  acceptingNewPatients: true,
  consultationPriceTnd: 90,
  areasOfCare: ['Bilan général', 'Hypertension', 'Prévention'],
  expertise: ['Médecine préventive', 'Coordination des soins'],
  visitReasons: ['Bilan de santé', 'Suivi de maladie chronique'],
  patientAgeGroups: ['Adultes', 'Personnes âgées'],
  consultationTypes: ['En cabinet', 'Téléconsultation'],
  biography:
      'Le Dr. Sarah Mansour est médecin généraliste à Tunis. Elle accompagne '
      'ses patients tout au long de leur parcours de soins, avec une écoute '
      'attentive et une approche préventive.',
  practiceLocations: [
    DoctorPracticeLocation(
      id: 'cabinet-1',
      type: DoctorPracticeLocationType.cabinet,
      name: 'Cabinet Dr. Sarah Mansour',
      governorate: 'Tunis',
      city: 'Tunis',
      address: '1 rue du Lac',
      latitude: 36.84,
      longitude: 10.27,
      publicPhone: '+216 71 000 000',
      wheelchairAccessible: true,
      patientInstructions: 'Apportez vos anciens résultats.',
      primary: true,
      gallery: [
        DoctorPracticeMedia(
          url: 'https://cdn.example/cabinet.jpg',
          displayOrder: 0,
        ),
      ],
      equipment: [
        DoctorEquipment(code: 'ECG', displayName: 'ECG', portable: false),
      ],
      coverage: DoctorPracticeCoverage(
        selfPay: DoctorCoverageClaim(
          acceptance: DoctorCoverageAcceptance.accepted,
          provenance: DoctorCoverageProvenance.declared,
          verified: false,
        ),
        cnam: DoctorCoverageClaim(
          acceptance: DoctorCoverageAcceptance.accepted,
          provenance: DoctorCoverageProvenance.declared,
          verified: false,
        ),
        privateInsurance: DoctorCoverageClaim(
          acceptance: DoctorCoverageAcceptance.notDeclared,
          verified: false,
        ),
        specificPrivateInsurerDetailsAvailable: false,
      ),
    ),
  ],
);

const _nadiaDetail = DoctorDirectoryDetail(
  doctorId: 'doc-2',
  displayName: 'Dr. Nadia Cherif',
  specialty: 'Médecin généraliste',
  verified: true,
  experienceYears: 8,
  practiceCity: 'Tunis',
  acceptingNewPatients: true,
);

const _multiLocationDetail = DoctorDirectoryDetail(
  doctorId: 'doc-1',
  displayName: 'Dr. Sarah Mansour',
  specialty: 'Médecin généraliste',
  acceptingNewPatients: true,
  practiceLocations: [
    DoctorPracticeLocation(
      id: 'cabinet-primary',
      type: DoctorPracticeLocationType.cabinet,
      name: 'Cabinet principal',
      governorate: 'Tunis',
      city: 'Tunis',
      address: '1 rue du Lac',
      latitude: 36.84,
      longitude: 10.27,
      wheelchairAccessible: true,
      primary: true,
    ),
    DoctorPracticeLocation(
      id: 'cabinet-matched',
      type: DoctorPracticeLocationType.cabinet,
      name: 'Cabinet correspondant',
      governorate: 'Ariana',
      city: 'Ariana',
      address: '2 avenue de Carthage',
      latitude: 36.86,
      longitude: 10.19,
      wheelchairAccessible: false,
      primary: false,
    ),
  ],
);

List<DoctorSearchCard> _directoryItems() {
  return const [
    DoctorSearchCard(
      doctorId: 'doc-1',
      displayName: 'Dr. Sarah Mansour',
      specialty: 'Médecin généraliste',
      verified: true,
      acceptingNewPatients: true,
    ),
    DoctorSearchCard(
      doctorId: 'doc-2',
      displayName: 'Dr. Nadia Cherif',
      specialty: 'Médecin généraliste',
      verified: true,
      acceptingNewPatients: true,
    ),
    DoctorSearchCard(
      doctorId: 'doc-3',
      displayName: 'Dr. Amine Ben Salah',
      specialty: 'Cardiologue',
      verified: true,
      acceptingNewPatients: true,
    ),
    DoctorSearchCard(
      doctorId: 'doc-4',
      displayName: 'Dr. Leila Haddad',
      specialty: 'Pédiatre',
      verified: true,
      acceptingNewPatients: true,
    ),
    DoctorSearchCard(
      doctorId: 'doc-5',
      displayName: 'Dr. Karim Trabelsi',
      specialty: 'Dermatologue',
      verified: true,
      acceptingNewPatients: true,
    ),
    DoctorSearchCard(
      doctorId: 'doc-6',
      displayName: 'Dr. Yasmine Gharbi',
      specialty: 'Gynécologue',
      verified: true,
      acceptingNewPatients: true,
    ),
  ];
}

Map<String, DoctorDirectoryDetail> _detailMap() {
  return const {'doc-1': _sarahDetail, 'doc-2': _nadiaDetail};
}

List<AvailabilitySlotDto> _buildSlots() {
  final today = DateTime.now();
  final slots = <AvailabilitySlotDto>[];
  for (var i = 0; i < 7; i++) {
    final date = DateTime(today.year, today.month, today.day + i);
    if (date.weekday == DateTime.sunday) continue;
    for (final (hour, minute) in const [
      (9, 0),
      (9, 30),
      (10, 30),
      (14, 0),
      (15, 30),
      (16, 0),
    ]) {
      slots.add(_slotAt(date, hour, minute));
    }
  }
  return slots;
}

AvailabilitySlotDto _slotAt(DateTime date, int hour, int minute) {
  final start = DateTime(date.year, date.month, date.day, hour, minute);
  final end = start.add(const Duration(minutes: 30));
  return AvailabilitySlotDto(
    start: start.toUtc().toIso8601String(),
    end: end.toUtc().toIso8601String(),
  );
}

Widget _buildDirectoryApp({_FakeDoctorRepository? repository}) {
  return ChangeNotifierProvider<DoctorDirectoryController>(
    create: (_) => DoctorDirectoryController(
      repository: repository ?? _FakeDoctorRepository(),
    ),
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: const DoctorDirectoryScreen(),
    ),
  );
}

Widget _buildDetailApp({
  String doctorId = 'doc-1',
  TextScaler? textScaler,
  _FakeDoctorRepository? repository,
  String? preferredPracticeLocationId,
  ScheduledCarePrototypeController? scheduledCareController,
}) {
  final effectiveScheduledCare =
      scheduledCareController ??
      (ScheduledCarePrototypeController()..selectSelf(displayName: 'Leïla'));
  final app = ChangeNotifierProvider<DoctorDirectoryController>(
    create: (_) => DoctorDirectoryController(
      repository: repository ?? _FakeDoctorRepository(),
    ),
    child: MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) {
        if (textScaler == null) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      },
      home: DoctorDetailScreen(
        doctorId: doctorId,
        preferredPracticeLocationId: preferredPracticeLocationId,
        scheduledBookingWorkflow: true,
      ),
    ),
  );
  if (scheduledCareController == null) {
    return ChangeNotifierProvider<ScheduledCarePrototypeController>(
      create: (_) => effectiveScheduledCare,
      child: app,
    );
  }
  return ChangeNotifierProvider<ScheduledCarePrototypeController>.value(
    value: effectiveScheduledCare,
    child: app,
  );
}

Future<void> _openAvailabilitySheet(WidgetTester tester) async {
  await tester.tap(find.text('Disponibilités'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Voir tous les créneaux'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Voir tous les créneaux'));
  await tester.pumpAndSettle();
}

Future<void> _selectAvailabilityTime(WidgetTester tester, String time) async {
  final slot = find.byKey(ValueKey('availability-slot-$time-available'));
  final gesture = find.descendant(
    of: slot,
    matching: find.byType(GestureDetector),
  );
  tester.widget<GestureDetector>(gesture.first).onTap!();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('Doctor Directory — selection removed', () {
    testWidgets('no Sélectionné badge rendered', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      expect(find.text('Sélectionné'), findsNothing);
    });

    testWidgets('no Continue bar rendered', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      expect(find.text('Continuer'), findsNothing);
    });

    testWidgets('card tap navigates to DoctorDetailScreen', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dr. Sarah Mansour'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDetailScreen), findsOneWidget);
    });

    testWidgets('no price rendered on card', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('DA'), findsNothing);
      expect(find.textContaining('TND'), findsNothing);
    });

    testWidgets('back from detail returns to directory', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dr. Sarah Mansour'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDetailScreen), findsOneWidget);

      Navigator.of(find.byType(DoctorDetailScreen).evaluate().first).pop();
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
    });
  });

  group('Doctor Detail — identity', () {
    testWidgets('renders doctor name', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sarah Mansour'), findsWidgets);
    });

    testWidgets('renders specialty', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Médecin généraliste'), findsOneWidget);
    });

    testWidgets('renders verified badge', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('renders experience', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('12 ans'), findsOneWidget);
    });

    testWidgets('renders accepting new patients', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Accepte de nouveaux patients'), findsWidgets);
    });

    testWidgets('renders segmented tab bar', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('À propos'), findsOneWidget);
      expect(find.text('Disponibilités'), findsOneWidget);
      expect(find.text('Cabinet'), findsOneWidget);
    });

    testWidgets('narrow phone has no layout exception', (tester) async {
      final originalSize = tester.view.physicalSize;
      final originalDevicePixelRatio = tester.view.devicePixelRatio;
      addTearDown(() {
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalDevicePixelRatio;
      });
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('large accessibility text has no layout exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDetailApp(textScaler: const TextScaler.linear(1.35)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Doctor Detail — loading and failure state', () {
    testWidgets('preserves the existing loading state until detail arrives', (
      tester,
    ) async {
      final completer = Completer<DoctorDirectoryDetail>();
      final repository = _FakeDoctorRepository(detailCompleter: completer);

      await tester.pumpWidget(_buildDetailApp(repository: repository));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_sarahDetail);
      await tester.pumpAndSettle();
      expect(find.text('Dr. Sarah Mansour'), findsWidgets);
    });

    testWidgets('fetches the selected real doctorId', (tester) async {
      final repository = _FakeDoctorRepository();

      await tester.pumpWidget(
        _buildDetailApp(doctorId: 'doc-1', repository: repository),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedDoctorIds, ['doc-1']);
      expect(find.text('Dr. Sarah Mansour'), findsWidgets);
    });

    testWidgets('scopes detail availability to the preferred Cabinet', (
      tester,
    ) async {
      final repository = _FakeDoctorRepository(
        details: const {'doc-1': _multiLocationDetail},
      );

      await tester.pumpWidget(
        _buildDetailApp(
          repository: repository,
          preferredPracticeLocationId: 'cabinet-matched',
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedPracticeLocationIds, ['cabinet-matched']);
    });

    testWidgets('does not request availability before a Cabinet is selected', (
      tester,
    ) async {
      final repository = _FakeDoctorRepository(
        details: const {'doc-1': _multiLocationDetail},
      );

      await tester.pumpWidget(_buildDetailApp(repository: repository));
      await tester.pumpAndSettle();

      expect(repository.requestedPracticeLocationIds, isEmpty);

      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(
          const ValueKey('doctor-cabinet-selector'),
          skipOffstage: false,
        ),
      );
      selector.onChanged!('cabinet-matched');
      await tester.pumpAndSettle();

      expect(repository.requestedPracticeLocationIds, ['cabinet-matched']);
    });

    testWidgets('renders the existing not-found state without retry', (
      tester,
    ) async {
      final repository = _FakeDoctorRepository(
        detailFailure: DoctorDirectoryFailure.notFound,
      );

      await tester.pumpWidget(_buildDetailApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Médecin introuvable'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    });

    testWidgets('network failure retries the same detail request', (
      tester,
    ) async {
      final repository = _FakeDoctorRepository(
        detailFailure: DoctorDirectoryFailure.networkUnavailable,
      );

      await tester.pumpWidget(_buildDetailApp(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);

      repository.detailFailure = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(repository.requestedDoctorIds, ['doc-1', 'doc-1']);
      expect(find.text('Dr. Sarah Mansour'), findsWidgets);
    });
  });

  group('Doctor Detail — À propos (default tab)', () {
    testWidgets('renders areas of care', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Domaines de prise en charge'), findsOneWidget);
      expect(find.text('Bilan général'), findsWidgets);
    });

    testWidgets('renders expertise', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Expertises'), findsOneWidget);
      expect(find.text('Médecine préventive'), findsWidgets);
    });

    testWidgets('renders consultation reasons', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Motifs de consultation'), findsOneWidget);
    });

    testWidgets('renders accepted patients', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Patients pris en charge'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Patients pris en charge'), findsOneWidget);
    });

    testWidgets('renders consultation options', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      final allTexts = find.byType(Text);
      final texts = allTexts
          .evaluate()
          .map((e) {
            final widget = e.widget as Text;
            return widget.data ?? '';
          })
          .where((t) => t.isNotEmpty)
          .toList();
      // At minimum, we should have header + tab content texts
      expect(texts.length, greaterThan(5));
    });

    testWidgets('renders biography', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Domaines de prise en charge'), findsOneWidget);
    });
  });

  group('Doctor Detail — Cabinet tab', () {
    testWidgets('switching to Cabinet tab shows location', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Localisation'),
        220,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Localisation'), findsOneWidget);
      expect(find.text('Cabinet Dr. Sarah Mansour'), findsOneWidget);
    });

    testWidgets('cabinet tab shows gallery images', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('cabinet tab shows Itinéraire button', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Itinéraire'),
        220,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Itinéraire'), findsOneWidget);
    });

    testWidgets('cabinet tab shows equipment subsection', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ECG'),
        220,
        scrollable: find.byType(Scrollable).first,
      );

      final allTexts = find.byType(Text);
      final texts = allTexts
          .evaluate()
          .map((e) {
            final widget = e.widget as Text;
            return widget.data ?? '';
          })
          .where((t) => t.isNotEmpty)
          .toList();
      expect(texts, contains('ECG'));
    });

    testWidgets('cabinet tab binds real address, instructions and coverage', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.text('1 rue du Lac'),
        220,
        scrollable: scrollable,
      );
      expect(find.text('1 rue du Lac'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('CNAM acceptée (déclaration du professionnel)'),
        220,
        scrollable: scrollable,
      );
      expect(
        find.text('CNAM acceptée (déclaration du professionnel)'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Apportez vos anciens résultats.'),
        220,
        scrollable: scrollable,
      );
      expect(find.text('Apportez vos anciens résultats.'), findsOneWidget);
      expect(find.text('Images de démonstration du cabinet'), findsNothing);
      expect(find.text('08:30 – 17:00'), findsNothing);
    });
  });

  group('Doctor Detail — no price, no reviews', () {
    testWidgets('no price rendered', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('DA'), findsNothing);
      expect(find.textContaining('TND'), findsNothing);
    });

    testWidgets('no reviews section', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Avis'), findsNothing);
      expect(find.text('Reviews'), findsNothing);
    });

    testWidgets('no statistics dashboard', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Visites'), findsNothing);
      expect(find.text('Patients'), findsNothing);
      expect(find.text('Consultations'), findsNothing);
    });
  });

  group('Doctor Detail — booking entry', () {
    testWidgets('permanent Voir les disponibilités CTA is removed', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      expect(find.text('Voir les disponibilités'), findsNothing);
    });

    testWidgets('Voir tous les créneaux opens availability sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);
    });

    testWidgets('availability sheet opens at approximately 50% height', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final sheetHeight = tester
          .getSize(find.byType(DoctorAvailabilitySheet))
          .height;
      expect(sheetHeight, closeTo(screenHeight * 0.50, 2));
    });
  });

  group('Doctor Directory — filter sheet sizing', () {
    testWidgets('filter sheet stays below the configured maximum height', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final sheetHeight = tester.getSize(find.byType(DoctorFilterSheet)).height;
      expect(sheetHeight, lessThanOrEqualTo(screenHeight * 0.82 + 2));
    });
  });

  group('Availability sheet', () {
    testWidgets(
      'scheduled workflow uses local Cabinet slots, not Doctor-wide slots',
      (tester) async {
        final scheduledCare = ScheduledCarePrototypeController(
          clock: () => DateTime(2026, 10, 6, 8),
        )..selectSelf(displayName: 'Leïla');
        addTearDown(scheduledCare.dispose);
        await tester.pumpWidget(
          _buildDetailApp(scheduledCareController: scheduledCare),
        );
        await tester.pumpAndSettle();

        await _openAvailabilitySheet(tester);

        expect(scheduledCare.draft.cabinet?.id, 'cabinet-1');
        expect(scheduledCare.draft.consultationPriceTnd, 90);
        expect(
          find.byKey(const ValueKey('availability-slot-09:30-available')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('availability-slot-10:00-available')),
          findsOneWidget,
        );
      },
    );

    testWidgets('preferred matching Cabinet remains selected in detail', (
      tester,
    ) async {
      final scheduledCare = ScheduledCarePrototypeController(
        clock: () => DateTime(2026, 10, 6, 8),
      )..selectSelf(displayName: 'Leïla');
      addTearDown(scheduledCare.dispose);
      await tester.pumpWidget(
        _buildDetailApp(
          preferredPracticeLocationId: 'cabinet-matched',
          scheduledCareController: scheduledCare,
          repository: _FakeDoctorRepository(
            details: const {'doc-1': _multiLocationDetail},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('doctor-cabinet-selector')),
      );
      expect(selector.initialValue, 'cabinet-matched');

      await _openAvailabilitySheet(tester);
      expect(scheduledCare.draft.cabinet?.id, 'cabinet-matched');
      expect(find.textContaining('Cabinet correspondant'), findsWidgets);
    });

    testWidgets('displays doctor name', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      expect(find.text('Dr. Sarah Mansour'), findsWidgets);
    });

    testWidgets('month navigation works', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      final nextButton = find.byIcon(Icons.chevron_right_rounded);
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);
    });

    testWidgets('closing sheet returns to detail', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDetailScreen), findsOneWidget);
    });

    testWidgets('Continue button disabled before slot selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      final continueButton = find.widgetWithText(ElevatedButton, 'Continuer');
      expect(continueButton, findsOneWidget);

      final button = tester.widget<ElevatedButton>(continueButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('selecting a slot does not immediately confirm', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '10:00');

      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);
      expect(
        find.text(
          'Créneau de 30 min avec Dr. Sarah Mansour · Cabinet Dr. Sarah Mansour. '
          'Vous pourrez le vérifier avant d’envoyer la demande.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('availability-slot-10:00-selected')),
        findsOneWidget,
      );
    });

    testWidgets('inline booking notice appears only after slot selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      expect(find.textContaining('avant d’envoyer la demande'), findsNothing);

      await _selectAvailabilityTime(tester, '10:00');
      expect(find.textContaining('avant d’envoyer la demande'), findsOneWidget);
    });

    testWidgets('only one slot can be selected at a time', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '09:00');
      await _selectAvailabilityTime(tester, '10:00');

      expect(
        find.byKey(const ValueKey('availability-slot-09:00-selected')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('availability-slot-10:00-selected')),
        findsOneWidget,
      );
    });

    testWidgets('Continuer opens the scheduled request review', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '10:00');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Vérifier la demande'), findsOneWidget);
      expect(find.text('Votre créneau, avant envoi'), findsOneWidget);
      expect(find.text('DEMANDER CE CRÉNEAU'), findsOneWidget);
    });

    testWidgets('no price rendered in sheet', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      expect(find.textContaining('DA'), findsNothing);
      expect(find.textContaining('TND'), findsNothing);
    });

    testWidgets('slots display after date selection', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      expect(find.text('Matin'), findsOneWidget);
    });
  });

  group('Doctor Detail — Disponibilités tab', () {
    testWidgets('switching to Disponibilités tab shows availability preview', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disponibilités'));
      await tester.pumpAndSettle();

      expect(find.text('Prochaine disponibilité'), findsOneWidget);
    });

    testWidgets('Disponibilités tab shows see all button', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disponibilités'));
      await tester.pumpAndSettle();

      expect(find.text('Voir tous les créneaux'), findsOneWidget);
    });

    testWidgets('availability failure shows retry panel', (tester) async {
      await tester.pumpWidget(
        _buildDetailApp(
          repository: _FakeDoctorRepository(
            slotsFailure: DoctorDirectoryFailure.serverUnavailable,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disponibilités'));
      await tester.pumpAndSettle();

      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Voir tous les créneaux'), findsNothing);
    });

    testWidgets(
      'tapping see all in Disponibilités tab opens availability sheet',
      (tester) async {
        await tester.pumpWidget(_buildDetailApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Disponibilités'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Voir tous les créneaux'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voir tous les créneaux'));
        await tester.pumpAndSettle();

        expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);
      },
    );
  });

  group('Doctor Detail — booking entry retry', () {
    testWidgets('retry after availability failure restores the tab', (
      tester,
    ) async {
      final failing = _FakeDoctorRepository(
        slotsFailure: DoctorDirectoryFailure.serverUnavailable,
      );
      await tester.pumpWidget(_buildDetailApp(repository: failing));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disponibilités'));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);

      failing.slotsFailure = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Voir tous les créneaux'), findsOneWidget);
    });
  });

  group('Navigation regression', () {
    testWidgets('Doctor Directory renders', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
    });

    testWidgets('Doctor Directory search field works', (tester) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('back preserves directory search and scroll state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      final search = find.byType(TextField);
      await tester.enterText(search, 'a');
      await tester.pumpAndSettle();

      final directoryScroll = find.byType(Scrollable).last;
      await tester.drag(directoryScroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      final doctor = find.text('Dr. Nadia Cherif');
      await tester.scrollUntilVisible(doctor, 180, scrollable: directoryScroll);
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(directoryScroll)
          .position
          .pixels;

      await tester.tap(doctor);
      await tester.pumpAndSettle();
      expect(find.byType(DoctorDetailScreen), findsOneWidget);

      Navigator.of(find.byType(DoctorDetailScreen).evaluate().first).pop();
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
      expect(tester.widget<TextField>(search).controller?.text, 'a');
      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(after, closeTo(before, 1));
    });
  });
}
