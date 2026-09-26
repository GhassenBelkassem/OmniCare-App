import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_controller.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_screen.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_demo_appointment.dart';

Widget _agenda(DoctorAgendaController controller) => MaterialApp(
  theme: buildOmniTheme(),
  locale: const Locale('fr'),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('fr')],
  home: Scaffold(body: DoctorAgendaScreen(controller: controller)),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  test('controller owns selection, status, and next appointment', () {
    final controller = DoctorAgendaController();
    expect(controller.selectedDate, DateTime(2026, 9, 23));
    expect(controller.appointmentsFor(controller.selectedDate), hasLength(3));
    expect(controller.nextAppointment?.patientName, 'Mohamed Trabelsi');
    controller.markArrived('mohamed-1030');
    expect(controller.nextAppointment?.status, DoctorAppointmentStatus.arrived);
    controller.selectDate(DateTime(2026, 9, 30));
    expect(controller.appointmentsFor(controller.selectedDate), isEmpty);
  });

  testWidgets(
    'month and day preserve the selected date and show an empty day',
    (tester) async {
      final controller = DoctorAgendaController();
      await tester.pumpWidget(_agenda(controller));
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Mois'), findsOneWidget);
      await tester.tap(find.text('Jour'));
      await tester.pumpAndSettle();
      expect(controller.view, DoctorAgendaView.day);
      expect(find.textContaining('23 septembre 2026'), findsOneWidget);
      controller.selectDate(DateTime(2026, 9, 30));
      await tester.pumpAndSettle();
      expect(find.text('Aucun rendez-vous'), findsOneWidget);
    },
  );

  testWidgets('selected, today, and event markers have distinct treatments', (
    tester,
  ) async {
    final controller = DoctorAgendaController();
    await tester.pumpWidget(_agenda(controller));
    await tester.pumpAndSettle();

    final selectedCell = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('agenda-day-2026-09-23')),
    );
    final selectedDecoration = selectedCell.decoration! as BoxDecoration;
    expect(selectedDecoration.color, OmniColors.primaryAction);
    expect(selectedDecoration.border, isNull);

    final todayCell = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('agenda-day-2026-09-24')),
    );
    final todayDecoration = todayCell.decoration! as BoxDecoration;
    expect(todayDecoration.color, Colors.transparent);
    expect(todayDecoration.border, isNotNull);

    final markerRow = find.byKey(const ValueKey('agenda-marker-2026-09-23'));
    expect(markerRow, findsOneWidget);
    expect(
      find.descendant(of: markerRow, matching: find.byType(Container)),
      findsNWidgets(3),
    );

    controller.selectDate(DateTime(2026, 9, 24));
    await tester.pumpAndSettle();
    final selectedTodayCell = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('agenda-day-2026-09-24')),
    );
    final selectedTodayDecoration =
        selectedTodayCell.decoration! as BoxDecoration;
    expect(selectedTodayDecoration.color, OmniColors.primaryAction);
    expect(selectedTodayDecoration.border, isNull);
  });

  testWidgets('Agenda fits the supported phone dimensions', (tester) async {
    const sizes = <Size>[
      Size(360, 568),
      Size(360, 700),
      Size(390, 844),
      Size(430, 932),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_agenda(DoctorAgendaController()));
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size: $size');
    }
  });

  testWidgets('arrival updates the local detail and QR remains a placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DoctorAgendaController();
    await tester.pumpWidget(_agenda(controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mohamed Trabelsi'));
    await tester.tap(find.text('Mohamed Trabelsi'));
    await tester.pumpAndSettle();
    expect(find.text('45 ans'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Patient arrivé'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('doctor-appointment-detail-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Patient arrivé'));
    await tester.pumpAndSettle();
    expect(find.text('Scanner le QR'), findsOneWidget);
    expect(controller.selectedDate, DateTime(2026, 9, 23));
    expect(controller.view, DoctorAgendaView.month);
    await tester.tap(find.text('Scanner le QR'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('La vérification QR sera ajoutée'),
      findsOneWidget,
    );
  });
}
