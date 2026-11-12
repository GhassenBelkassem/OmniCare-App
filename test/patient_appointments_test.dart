import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_appointments/application/patient_appointments_controller.dart';
import 'package:omnicare_mobile/features/patient_appointments/data/patient_appointment_models.dart';
import 'package:omnicare_mobile/features/patient_appointments/data/patient_appointment_mock_data.dart';
import 'package:omnicare_mobile/features/patient_appointments/presentation/patient_appointment_detail_screen.dart';
import 'package:omnicare_mobile/features/patient_appointments/presentation/patient_appointments_screen.dart';
import 'package:omnicare_mobile/features/profile/patient_profile_screen.dart';
import 'package:provider/provider.dart';

PatientAppointment _appointment({
  String id = 'test-1',
  PatientAppointmentProviderType providerType =
      PatientAppointmentProviderType.doctor,
  PatientAppointmentStatus status = PatientAppointmentStatus.confirmed,
  PatientAppointmentSubjectType subjectType =
      PatientAppointmentSubjectType.self,
  String provider = 'Dr. Sarah Mansour',
  String subject = 'Moi',
  DateTime? start,
  bool canCancel = false,
}) {
  final resolvedStart = start ?? DateTime.now().add(const Duration(days: 2));
  return PatientAppointment(
    appointmentId: id,
    providerType: providerType,
    providerId: 'provider-$id',
    providerDisplayName: provider,
    providerSubtitle: providerType == PatientAppointmentProviderType.doctor
        ? 'Médecin généraliste'
        : 'Consultation / service',
    providerImageAssetPath:
        providerType == PatientAppointmentProviderType.doctor
        ? 'assets/images/doctors/sarah_mansour.jpg'
        : 'assets/images/clinics/demo/clinic_exterior.jpg',
    subjectType: subjectType,
    subjectDisplayName: subject,
    startAt: resolvedStart,
    endAt: resolvedStart.add(const Duration(minutes: 30)),
    status: status,
    locationName: providerType == PatientAppointmentProviderType.doctor
        ? 'Cabinet Dr. Sarah Mansour'
        : 'Les Berges du Lac',
    address: 'Rue de démonstration',
    city: 'Alger',
    consultationType: 'Consultation générale',
    appointmentReference: 'OMN-$id',
    preparationInstructions: 'Apportez vos documents utiles.',
    canCancel: canCancel,
  );
}

Widget _host(PatientAppointmentsController controller) {
  return MaterialApp(
    theme: buildOmniTheme(),
    home: PatientAppointmentsScreen(controller: controller),
  );
}

PatientProfileScreen _profile({
  required VoidCallback onOpenAppointments,
  required VoidCallback onOpenRequests,
}) {
  return PatientProfileScreen(
    identity: const PatientProfileIdentity(
      firstName: 'Sarah',
      lastName: 'Martin',
      displayName: 'Sarah Martin',
      phoneNumber: '+216 98 123 456',
      phoneVerified: true,
      email: 'sarah@example.tn',
      emailVerified: true,
    ),
    familyMembers: const [],
    onLogout: () async {},
    isLoggingOut: false,
    isSaving: false,
    isAvatarUploading: false,
    onAvatarSourceSelected: (_) async {},
    onAvatarRemove: () async {},
    onPersonalInformationChanged:
        ({
          required firstName,
          required lastName,
          required dateOfBirth,
          required gender,
        }) async {},
    onLanguageChanged: (_) async {},
    onNotificationPreferencesChanged:
        ({medications, appointments, passport}) async {},
    onOpenAccountSecurity: () {},
    onOpenDevices: () {},
    onOpenLoginHistory: () {},
    onOpenAppointments: onOpenAppointments,
    onOpenRequests: onOpenRequests,
  );
}

void main() {
  test('upcoming appointments are ordered nearest first', () {
    final now = DateTime.now();
    final controller = PatientAppointmentsController(
      appointments: [
        _appointment(id: 'later', start: now.add(const Duration(days: 8))),
        _appointment(id: 'near', start: now.add(const Duration(days: 1))),
      ],
    );

    expect(controller.visibleAppointments().first.appointmentId, 'near');
  });

  testWidgets('Profile activity exposes appointments and requests', (
    tester,
  ) async {
    var appointmentsOpened = false;
    var requestsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: _profile(
          onOpenAppointments: () => appointmentsOpened = true,
          onOpenRequests: () => requestsOpened = true,
        ),
      ),
    );

    expect(find.text('ACTIVITÉ'), findsOneWidget);
    expect(find.text('Mes rendez-vous'), findsOneWidget);
    expect(find.text('Prochains rendez-vous et historique'), findsOneWidget);
    expect(find.text('Mes demandes'), findsOneWidget);
    expect(find.text('MON COMPTE'), findsOneWidget);

    await tester.tap(find.text('Mes rendez-vous'));
    await tester.tap(find.text('Mes demandes'));
    expect(appointmentsOpened, isTrue);
    expect(requestsOpened, isTrue);
  });

  testWidgets('appointment list renders doctor, clinic, and family subjects', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PatientAppointmentsController(
          appointments: createPatientAppointmentMocks(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes rendez-vous'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Dr. Sarah Mansour'), findsWidgets);
    expect(find.text('Pour : Aicha Mechergui'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Clinique Hannibal'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Clinique Hannibal'), findsOneWidget);
    expect(find.textContaining('DA'), findsNothing);
    expect(find.textContaining('TND'), findsNothing);
  });

  testWidgets('tabs, search, and filtered empty state work', (tester) async {
    await tester.pumpWidget(
      _host(
        PatientAppointmentsController(
          appointments: createPatientAppointmentMocks(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('Passés'), findsOneWidget);
    expect(find.text('${DateTime.now().year}'), findsOneWidget);

    final search = find.byKey(const ValueKey('appointment-search'));
    await tester.enterText(search, 'ce terme n’existe pas');
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun rendez-vous ne correspond à vos filtres.'),
      findsOneWidget,
    );
    expect(find.text('Réinitialiser les filtres'), findsOneWidget);
  });

  testWidgets(
    'filter sheet applies provider type and keeps a restrained size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          PatientAppointmentsController(
            appointments: createPatientAppointmentMocks(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('appointment-filter-button')));
      await tester.pumpAndSettle();
      expect(find.text('Filtrer les rendez-vous'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Filtrer les rendez-vous')).dy,
        greaterThan(250),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Clinique'));
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();

      expect(find.text('Clinique Hannibal'), findsOneWidget);
      expect(find.text('Dr. Sarah Mansour'), findsNothing);
    },
  );

  testWidgets('detail preserves list state after back', (tester) async {
    final controller = PatientAppointmentsController(
      appointments: [_appointment(id: 'first', provider: 'Dr. Sarah Mansour')],
    );
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('appointment-search')),
      'Sarah',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dr. Sarah Mansour').first);
    await tester.pumpAndSettle();
    expect(find.byType(PatientAppointmentDetailScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Cabinet Dr. Sarah Mansour'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Cabinet Dr. Sarah Mansour'), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(PatientAppointmentDetailScreen)),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PatientAppointmentsScreen), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('appointment-search')))
          .controller!
          .text,
      'Sarah',
    );
  });

  testWidgets('mock cancellation moves the record to Annulés', (tester) async {
    final appointment = _appointment(id: 'cancel-me', canCancel: true);
    final controller = PatientAppointmentsController(
      appointments: [appointment],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: buildOmniTheme(),
          home: PatientAppointmentDetailScreen(
            appointmentId: 'cancel-me',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cancel-appointment')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const ValueKey('cancel-appointment')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cancel-appointment')));
    await tester.pumpAndSettle();
    expect(find.text('Annuler ce rendez-vous ?'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Annuler le rendez-vous'),
    );
    await tester.pumpAndSettle();

    expect(
      controller.byId('cancel-me')!.status,
      PatientAppointmentStatus.cancelled,
    );
    controller.setTab(PatientAppointmentTab.cancelled);
    expect(controller.visibleAppointments().single.appointmentId, 'cancel-me');
    expect(find.byKey(const ValueKey('cancel-appointment')), findsNothing);
  });

  testWidgets('report problem sheet exposes static categories only', (
    tester,
  ) async {
    final controller = PatientAppointmentsController(
      appointments: [_appointment()],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: buildOmniTheme(),
          home: PatientAppointmentDetailScreen(
            appointmentId: 'test-1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-appointment-problem')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('report-appointment-problem')));
    await tester.pumpAndSettle();

    expect(find.text('Besoin d’aide ?'), findsOneWidget);
    expect(find.text('Informations incorrectes'), findsOneWidget);
    expect(find.text('Médecin ou clinique indisponible'), findsOneWidget);
  });

  test('mock dataset spans all required status and provider combinations', () {
    final appointments = createPatientAppointmentMocks();
    expect(
      appointments.map((item) => item.providerType).toSet(),
      containsAll(PatientAppointmentProviderType.values),
    );
    expect(
      appointments.map((item) => item.status).toSet(),
      containsAll(PatientAppointmentStatus.values),
    );
    expect(
      appointments.map((item) => item.subjectType).toSet(),
      containsAll(PatientAppointmentSubjectType.values),
    );
    expect(
      appointments.map((item) => item.startAt.year).toSet().length,
      greaterThan(1),
    );
  });
}
