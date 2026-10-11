import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_screen.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';

import 'support/doctor_scheduled_care_test_support.dart';

Widget _screen(DoctorScheduledCareTestHarness harness) => MaterialApp(
  theme: buildOmniTheme(),
  locale: const Locale('fr'),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('fr')],
  home: Scaffold(
    body: DoctorAgendaScreen(controller: harness.coordinator.agenda),
  ),
);

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  test(
    'Agenda loads the bounded production projection and accepts by identity',
    () async {
      final harness = DoctorScheduledCareTestHarness();
      addTearDown(harness.dispose);
      await harness.start();

      final agenda = harness.coordinator.agenda;
      expect(agenda.selectedDate, DateTime(2026, 10, 6));
      expect(harness.repository.lastAgendaFrom, DateTime.utc(2026, 10));
      expect(harness.repository.lastAgendaTo, DateTime.utc(2026, 11));
      expect(agenda.records, hasLength(2));

      final request = agenda.records.singleWhere(
        (item) => item.resourceType == ScheduledCareResourceType.bookingRequest,
      );
      expect(await agenda.accept(request), isTrue);
      expect(
        harness.repository.request?.status,
        BookingRequestStatus.fulfilled,
      );
      expect(
        agenda.records.any(
          (item) => item.appointmentId == 'appointment-from-request',
        ),
        isTrue,
      );
      expect(harness.repository.lastIdempotencyKey, isNotEmpty);
    },
  );

  testWidgets(
    'pending request detail is server-backed and contains no fake symptoms',
    (tester) async {
      final harness = DoctorScheduledCareTestHarness();
      addTearDown(harness.dispose);
      await harness.start();
      harness.coordinator.agenda.selectDate(DateTime(2026, 10, 8));

      await tester.pumpWidget(_screen(harness));
      await tester.pumpAndSettle();
      expect(find.text('Mariem Ben Amor'), findsOneWidget);
      expect(find.text('Cabinet Lac 2'), findsOneWidget);
      await tester.tap(find.text('Mariem Ben Amor'));
      await tester.pumpAndSettle();
      expect(find.text('Enfant'), findsOneWidget);
      expect(find.text('30 min'), findsWidgets);
      expect(find.textContaining('Douleur apparue'), findsNothing);
      expect(harness.repository.requestReads, 1);
    },
  );

  testWidgets('proposal uses real same-cabinet availability over 21 days', (
    tester,
  ) async {
    final harness = DoctorScheduledCareTestHarness();
    addTearDown(harness.dispose);
    await harness.start();
    harness.coordinator.agenda.selectDate(DateTime(2026, 10, 8));
    await tester.pumpWidget(_screen(harness));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mariem Ben Amor'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Proposer un autre créneau'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('doctor-appointment-detail-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Proposer un autre créneau'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('disponibilités des 21 prochains jours'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('doctor-controlled-reason')),
      findsNothing,
    );
    expect(harness.repository.availabilityReads, 1);
    expect(
      harness.repository.lastAvailabilityTo!.difference(
        harness.repository.lastAvailabilityFrom!,
      ),
      const Duration(days: 21),
    );

    final tile = find.byKey(
      ValueKey(
        'doctor-proposal-slot-${DateTime.utc(2026, 10, 8, 10).toIso8601String()}',
      ),
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Proposer'));
    await tester.pumpAndSettle();
    expect(
      harness.repository.request?.status,
      BookingRequestStatus.pendingPatientTimeConfirmation,
    );
  });

  testWidgets('decline uses a controlled backend reason', (tester) async {
    final harness = DoctorScheduledCareTestHarness();
    addTearDown(harness.dispose);
    await harness.start();
    harness.coordinator.agenda.selectDate(DateTime(2026, 10, 8));
    await tester.pumpWidget(_screen(harness));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mariem Ben Amor'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Refuser'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('doctor-appointment-detail-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('doctor-controlled-reason')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Refuser'));
    await tester.pumpAndSettle();
    expect(
      harness.repository.request?.cancellation?.reasonCode,
      DoctorDeclineReason.cabinetUnavailable.wireName,
    );
  });

  testWidgets(
    'confirmed appointment cannot be rescheduled and exposes no intake body',
    (tester) async {
      final harness = DoctorScheduledCareTestHarness();
      addTearDown(harness.dispose);
      await harness.start();
      harness.coordinator.agenda.selectDate(DateTime(2026, 10, 7));
      await tester.pumpWidget(_screen(harness));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahmed Gharbi'));
      await tester.pumpAndSettle();
      expect(find.text('Préparation envoyée par le patient'), findsOneWidget);
      expect(find.textContaining('informations cliniques'), findsOneWidget);
      expect(find.text('Proposer un autre créneau'), findsNothing);
      expect(find.text('Annuler le rendez-vous'), findsOneWidget);
    },
  );

  testWidgets('Agenda fits supported phone dimensions without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DoctorScheduledCareTestHarness();
    addTearDown(harness.dispose);
    await harness.start();
    for (final size in const [Size(360, 568), Size(390, 844), Size(430, 932)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_screen(harness));
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size: $size');
    }
  });
}
