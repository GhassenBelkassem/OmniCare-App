import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_appointments/application/patient_appointments_controller.dart';
import 'package:omnicare_mobile/features/patient_appointments/presentation/patient_appointments_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_booking_review_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_request_status_screen.dart';
import 'package:provider/provider.dart';

final _now = DateTime(2026, 10, 6, 8);

Widget _app(ScheduledCarePrototypeController controller, Widget home) =>
    ChangeNotifierProvider<ScheduledCarePrototypeController>.value(
      value: controller,
      child: MaterialApp(
        theme: buildOmniTheme(),
        locale: const Locale('fr'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fr')],
        home: home,
      ),
    );

void _prepareDraft(ScheduledCarePrototypeController controller) {
  const cabinet = CabinetPrototype(
    id: 'cabinet-review',
    name: 'Cabinet Les Berges du Lac',
    address: '5 rue du Lac',
    city: 'Tunis',
  );
  controller
    ..selectFamilyMember(
      familyMemberId: 'family-yasmine',
      displayName: 'Yasmine Ben Salem',
      relationshipLabel: 'Enfant',
    )
    ..selectDoctorAndCabinet(
      doctorId: 'doctor-review',
      doctorName: 'Dr Amine Ben Salah',
      doctorSpecialty: 'Médecine générale',
      consultationPriceTnd: 80,
      cabinet: cabinet,
    )
    ..selectSlot(
      SlotPrototype(
        id: 'slot-review',
        cabinetId: cabinet.id,
        start: _now.add(const Duration(days: 2, hours: 1)),
        end: _now.add(const Duration(days: 2, hours: 1, minutes: 30)),
      ),
    );
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  testWidgets(
    'booking review preserves family subject, Cabinet and exact slot',
    (tester) async {
      final controller = ScheduledCarePrototypeController(clock: () => _now);
      addTearDown(controller.dispose);
      _prepareDraft(controller);

      await tester.pumpWidget(
        _app(controller, const ScheduledBookingReviewScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Yasmine Ben Salem · Enfant'), findsOneWidget);
      expect(find.textContaining('Cabinet Les Berges du Lac'), findsOneWidget);
      expect(find.textContaining('09:00 – 09:30 · 30 min'), findsOneWidget);
      expect(find.text('80.00 TND'), findsOneWidget);
      expect(find.textContaining('médecin devra confirmer'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('submit-scheduled-request')));
      await tester.pumpAndSettle();
      expect(
        find.text('En attente de confirmation du médecin'),
        findsOneWidget,
      );
      final submitted = controller.records.first;
      expect(submitted.patient.familyMemberId, 'family-yasmine');
      expect(submitted.cabinet.id, 'cabinet-review');
      expect(submitted.status, ScheduledCareStatus.pendingDoctor);
    },
  );

  testWidgets('patient accepts or declines the one Doctor counterproposal', (
    tester,
  ) async {
    final acceptedStore = ScheduledCarePrototypeController.withFixtures(
      clock: () => _now,
    );
    addTearDown(acceptedStore.dispose);
    await tester.pumpWidget(
      _app(
        acceptedStore,
        const ScheduledRequestStatusScreen(recordId: 'fixture-request-sami'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Le médecin propose un autre créneau'), findsOneWidget);
    expect(find.text('Demande initiale'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('accept-counterproposal')),
    );
    await tester.tap(find.byKey(const ValueKey('accept-counterproposal')));
    await tester.pumpAndSettle();
    expect(
      acceptedStore.byId('fixture-request-sami')?.status,
      ScheduledCareStatus.confirmed,
    );
    expect(find.text('Rendez-vous confirmé'), findsOneWidget);

    final declinedStore = ScheduledCarePrototypeController.withFixtures(
      clock: () => _now,
    );
    addTearDown(declinedStore.dispose);
    await tester.pumpWidget(
      _app(
        declinedStore,
        const ScheduledRequestStatusScreen(recordId: 'fixture-request-sami'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('decline-counterproposal')),
    );
    await tester.tap(find.byKey(const ValueKey('decline-counterproposal')));
    await tester.pumpAndSettle();
    expect(
      declinedStore.byId('fixture-request-sami')?.status,
      ScheduledCareStatus.cancelledByPatient,
    );
  });

  testWidgets('optional intake can be skipped, then submitted in memory', (
    tester,
  ) async {
    final controller = ScheduledCarePrototypeController.withFixtures(
      clock: () => _now,
    )..acceptByDoctor('fixture-request-mariem');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        controller,
        const ScheduledRequestStatusScreen(recordId: 'fixture-request-mariem'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('prepare-consultation')),
    );
    await tester.tap(find.byKey(const ValueKey('prepare-consultation')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Facultatif'), findsOneWidget);
    expect(find.textContaining('Aucune écriture MRS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skip-intake')));
    await tester.pumpAndSettle();
    expect(
      controller.byId('fixture-request-mariem')?.intake.status,
      ScheduledIntakeStatus.notSubmitted,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('prepare-consultation')),
    );
    await tester.tap(find.byKey(const ValueKey('prepare-consultation')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('emergency-description')),
      'Douleur au genou depuis deux jours',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('submit-intake')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('submit-intake')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('submit-intake')));
    await tester.pumpAndSettle();
    final intake = controller.byId('fixture-request-mariem')?.intake;
    expect(intake?.status, ScheduledIntakeStatus.submitted);
    expect(intake?.description, 'Douleur au genou depuis deux jours');
  });

  testWidgets('late cancellation warns but remains available', (tester) async {
    var currentTime = _now;
    final controller = ScheduledCarePrototypeController.withFixtures(
      clock: () => currentTime,
    );
    addTearDown(controller.dispose);
    const recordId = 'fixture-appointment-ahmed';
    currentTime = _now.add(const Duration(hours: 3));

    await tester.pumpWidget(
      _app(controller, const ScheduledRequestStatusScreen(recordId: recordId)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annuler le rendez-vous'));
    await tester.tap(find.text('Annuler le rendez-vous'));
    await tester.pumpAndSettle();
    expect(find.textContaining('moins de 24 h'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('scheduled-cancellation-reason')),
      'Empêchement',
    );
    await tester.tap(find.text('Confirmer l’annulation'));
    await tester.pumpAndSettle();
    final cancelled = controller.byId(recordId);
    expect(cancelled?.status, ScheduledCareStatus.cancelledByPatient);
    expect(cancelled?.lateCancellation, isTrue);
  });

  testWidgets(
    'Mes rendez-vous presents pending, proposed and confirmed states',
    (tester) async {
      final prototype = ScheduledCarePrototypeController.withFixtures(
        clock: () => _now,
      );
      final appointments = PatientAppointmentsController(
        appointments: const [],
        prototypeController: prototype,
      );
      addTearDown(appointments.dispose);
      addTearDown(prototype.dispose);

      await tester.pumpWidget(
        _app(prototype, PatientAppointmentsScreen(controller: appointments)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Médecin à confirmer'), findsOneWidget);
      expect(find.text('Confirmé'), findsOneWidget);
      expect(find.textContaining('Cabinet Lac 2'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Votre réponse'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Votre réponse'), findsOneWidget);
      expect(find.textContaining('Cabinet Ariana'), findsOneWidget);
    },
  );
}
