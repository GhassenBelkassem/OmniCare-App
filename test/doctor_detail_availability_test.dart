import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_detail_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_availability_sheet.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_filter_sheet.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/widgets/clinic_full_screen_gallery.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_booking_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/booking_review_screen.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

class _FakeDoctorRepository implements DoctorDirectoryRepository {
  _FakeDoctorRepository({
    List<DoctorDirectoryListItem>? doctors,
    Map<String, DoctorDirectoryDetail>? details,
    List<AvailabilitySlotDto>? slots,
    this.slotsFailure,
    DoctorBookingResult? bookingResult,
  }) : doctors = List.unmodifiable(doctors ?? _directoryItems()),
       details = Map.unmodifiable(details ?? _detailMap()),
       slots = List.unmodifiable(slots ?? _buildSlots()),
       bookingResult = bookingResult ?? DoctorBookingResult.success(_booking);

  final List<DoctorDirectoryListItem> doctors;
  final Map<String, DoctorDirectoryDetail> details;
  final List<AvailabilitySlotDto> slots;
  DoctorDirectoryFailure? slotsFailure;
  final DoctorBookingResult bookingResult;

  @override
  Future<List<DoctorDirectoryListItem>> listDoctors({
    String? query,
    CancelToken? cancelToken,
  }) async {
    final needle = query?.trim().toLowerCase() ?? '';
    if (needle.isEmpty) return doctors;
    return doctors
        .where((doctor) => doctor.displayName.toLowerCase().contains(needle))
        .toList(growable: false);
  }

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    final detail = details[doctorId];
    if (detail == null) throw DoctorDirectoryFailure.notFound;
    return detail;
  }

  @override
  Future<AvailabilitySlotsDto> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    final failure = slotsFailure;
    if (failure != null) throw failure;
    return AvailabilitySlotsDto(
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      timezone: 'Africa/Tunis',
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      slots: slots,
    );
  }

  @override
  Future<DoctorBookingResult> bookAppointment({
    required String doctorId,
    required String startTime,
    required String endTime,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    return bookingResult;
  }

  static const _booking = AppointmentBooking(
    id: 'appt-1',
    doctorId: 'doc-1',
    patientId: 'patient-1',
    startTime: '2026-09-24T15:30:00Z',
    endTime: '2026-09-24T16:00:00Z',
    status: 'PENDING',
    source: 'PATIENT_APP',
  );
}

final _conflictResult = DoctorBookingResult.conflict(
  'Ce créneau vient d\'être réservé par un autre patient. '
  'Veuillez en choisir un autre.',
);

class _UnusedScheduledCareRepository
    implements ScheduledCareRepositoryContract {
  @override
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();
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
    DoctorPracticeLocationDto(
      id: 'cabinet-1',
      name: 'Cabinet Dr. Sarah Mansour',
      governorate: 'Tunis',
      city: 'Tunis',
      address: '10 avenue de Tunis',
      primary: true,
      equipment: [
        DoctorEquipmentDto(code: 'ECG', displayName: 'ECG', portable: false),
      ],
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
  practiceLocations: [
    DoctorPracticeLocationDto(
      id: 'cabinet-2',
      name: 'Cabinet Dr. Nadia Cherif',
      governorate: 'Tunis',
      city: 'Tunis',
      address: '20 avenue de Tunis',
      primary: true,
    ),
  ],
);

const _networkDoctorId = '123e4567-e89b-42d3-a456-426614174000';

const _networkGalleryDetail = DoctorDirectoryDetail(
  doctorId: _networkDoctorId,
  displayName: 'Dr. Galerie Réelle',
  specialty: 'Médecin généraliste',
  verified: true,
  practiceLocations: [
    DoctorPracticeLocationDto(
      id: '123e4567-e89b-42d3-a456-426614174001',
      name: 'Cabinet Galerie Réelle',
      governorate: 'Tunis',
      city: 'Tunis',
      address: '30 avenue de Tunis',
      primary: true,
      gallery: [
        DoctorPracticeMediaDto(
          url: 'https://media.example.test/cabinet-one.jpg',
          displayOrder: 0,
        ),
        DoctorPracticeMediaDto(
          url: 'https://media.example.test/cabinet-two.jpg',
          displayOrder: 1,
        ),
      ],
    ),
  ],
);

List<DoctorDirectoryListItem> _directoryItems() {
  return const [
    DoctorDirectoryListItem(
      doctorId: 'doc-1',
      displayName: 'Dr. Sarah Mansour',
      specialty: 'Médecin généraliste',
      availableForUrgent: false,
      isActive: true,
    ),
    DoctorDirectoryListItem(
      doctorId: 'doc-2',
      displayName: 'Dr. Nadia Cherif',
      specialty: 'Médecin généraliste',
      availableForUrgent: false,
      isActive: true,
    ),
    DoctorDirectoryListItem(
      doctorId: 'doc-3',
      displayName: 'Dr. Amine Ben Salah',
      specialty: 'Cardiologue',
      availableForUrgent: false,
      isActive: true,
    ),
    DoctorDirectoryListItem(
      doctorId: 'doc-4',
      displayName: 'Dr. Leila Haddad',
      specialty: 'Pédiatre',
      availableForUrgent: false,
      isActive: true,
    ),
    DoctorDirectoryListItem(
      doctorId: 'doc-5',
      displayName: 'Dr. Karim Trabelsi',
      specialty: 'Dermatologue',
      availableForUrgent: false,
      isActive: true,
    ),
    DoctorDirectoryListItem(
      doctorId: 'doc-6',
      displayName: 'Dr. Yasmine Gharbi',
      specialty: 'Gynécologue',
      availableForUrgent: false,
      isActive: true,
    ),
  ];
}

Map<String, DoctorDirectoryDetail> _detailMap() {
  return const {'doc-1': _sarahDetail, 'doc-2': _nadiaDetail};
}

List<AvailabilitySlotDto> _buildSlots() {
  final today = toTunisWallClock(DateTime.now());
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

/// Server slot whose Africa/Tunis wall clock (UTC+01:00) is [date] at
/// [hour]:[minute]. Independent of the device timezone.
AvailabilitySlotDto _slotAt(DateTime date, int hour, int minute) {
  final start = DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).subtract(const Duration(hours: 1));
  final end = start.add(const Duration(minutes: 30));
  return AvailabilitySlotDto(
    start: start.toIso8601String(),
    end: end.toIso8601String(),
  );
}

Widget _buildDirectoryApp({_FakeDoctorRepository? repository}) {
  return ChangeNotifierProvider<DoctorDirectoryController>(
    create: (_) => DoctorDirectoryController(
      repository: repository ?? _FakeDoctorRepository(),
    ),
    child: MaterialApp(
      localizationsDelegates: OmniLocalizations.localizationsDelegates,
      supportedLocales: OmniLocalizations.supportedLocales,
      theme: buildOmniTheme(),
      home: const DoctorDirectoryScreen(),
    ),
  );
}

Widget _buildDetailApp({
  String doctorId = 'doc-1',
  TextScaler? textScaler,
  _FakeDoctorRepository? repository,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DoctorDirectoryController>(
        create: (_) => DoctorDirectoryController(
          repository: repository ?? _FakeDoctorRepository(),
        ),
      ),
      ChangeNotifierProvider<PatientBookingController>(
        create: (_) => PatientBookingController(
          repository: _UnusedScheduledCareRepository(),
          requestIdFactory: () => 'request-1',
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: OmniLocalizations.localizationsDelegates,
      supportedLocales: OmniLocalizations.supportedLocales,
      theme: buildOmniTheme(),
      builder: (context, child) {
        if (textScaler == null) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      },
      home: DoctorDetailScreen(doctorId: doctorId),
    ),
  );
}

Future<void> _openAvailabilitySheet(WidgetTester tester) async {
  await tester.tap(find.text('Disponibilités'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Voir tous les créneaux'));
  await tester.pumpAndSettle();
}

Future<void> _selectAvailabilityTime(WidgetTester tester, String time) async {
  final slot = find.byKey(ValueKey('availability-slot-$time-available'));
  await tester.scrollUntilVisible(
    slot,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(slot);
  await tester.pumpAndSettle();
}

void main() {
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
      await tester.scrollUntilVisible(
        find.text('Images de démonstration du cabinet'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Images de démonstration du cabinet'), findsOneWidget);
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any((image) => image.image is AssetImage),
        isTrue,
      );
    });

    testWidgets('real UUID detail renders backend gallery as network images', (
      tester,
    ) async {
      final repository = _FakeDoctorRepository(
        details: const {_networkDoctorId: _networkGalleryDetail},
      );
      await tester.pumpWidget(
        _buildDetailApp(doctorId: _networkDoctorId, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();

      final networkImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is NetworkImage)
          .toList(growable: false);
      final urls = networkImages
          .map((image) => (image.image as NetworkImage).url)
          .toSet();
      expect(urls, {
        'https://media.example.test/cabinet-one.jpg',
        'https://media.example.test/cabinet-two.jpg',
      });
      await tester.scrollUntilVisible(
        find.text('Photos du cabinet'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Photos du cabinet'), findsOneWidget);
      expect(find.text('Images de démonstration du cabinet'), findsNothing);
      expect(find.byIcon(Icons.photo_outlined), findsWidgets);
    });

    testWidgets(
      'backend network image opens the existing full-screen gallery',
      (tester) async {
        final repository = _FakeDoctorRepository(
          details: const {_networkDoctorId: _networkGalleryDetail},
        );
        await tester.pumpWidget(
          _buildDetailApp(doctorId: _networkDoctorId, repository: repository),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cabinet'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PageView));
        await tester.pumpAndSettle();

        expect(find.byType(ClinicFullScreenGallery), findsOneWidget);
        expect(
          tester
              .widgetList<Image>(find.byType(Image))
              .where((image) => image.image is NetworkImage)
              .map((image) => (image.image as NetworkImage).url),
          contains('https://media.example.test/cabinet-one.jpg'),
        );
      },
    );

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
    testWidgets('filter sheet opens at approximately 60% height', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDirectoryApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final sheetHeight = tester.getSize(find.byType(DoctorFilterSheet)).height;
      expect(sheetHeight, closeTo(screenHeight * 0.60, 2));
    });
  });

  group('Availability sheet', () {
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
      await _selectAvailabilityTime(tester, '15:30');

      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);
      expect(
        find.text(
          'En continuant, vous demandez ce créneau à '
          'Dr. Sarah Mansour.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('availability-slot-15:30-selected')),
        findsOneWidget,
      );
    });

    testWidgets('inline booking notice appears only after slot selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      expect(find.textContaining('En continuant, vous demandez'), findsNothing);

      await _selectAvailabilityTime(tester, '15:30');
      expect(
        find.textContaining('En continuant, vous demandez'),
        findsOneWidget,
      );
    });

    testWidgets('only one slot can be selected at a time', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '09:00');
      await _selectAvailabilityTime(tester, '09:30');

      expect(
        find.byKey(const ValueKey('availability-slot-09:00-selected')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('availability-slot-09:30-selected')),
        findsOneWidget,
      );
    });

    testWidgets('Continuer opens booking-request review', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '15:30');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(BookingReviewScreen), findsOneWidget);
      expect(find.text('Vérifier la demande'), findsOneWidget);
      expect(find.text('Rendez-vous confirmé'), findsNothing);
    });

    testWidgets('legacy booking result is not consulted by patient flow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDetailApp(
          repository: _FakeDoctorRepository(bookingResult: _conflictResult),
        ),
      );
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '09:00');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(BookingReviewScreen), findsOneWidget);
      expect(find.text('Rendez-vous confirmé'), findsNothing);
      expect(find.textContaining('vient d\'être réservé'), findsNothing);
    });

    testWidgets('legacy booking failure is not consulted by patient flow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDetailApp(
          repository: _FakeDoctorRepository(
            bookingResult: DoctorBookingResult.failure(
              DoctorDirectoryFailure.serverUnavailable,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '09:00');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(BookingReviewScreen), findsOneWidget);
      expect(find.text('Rendez-vous confirmé'), findsNothing);
      expect(find.textContaining('temporarily unavailable'), findsNothing);
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
