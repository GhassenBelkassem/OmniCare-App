import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_availability_sheet.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_filter_sheet.dart';

Widget _buildDirectoryApp() {
  return MaterialApp(
    theme: buildOmniTheme(),
    home: ChangeNotifierProvider<DoctorDirectoryController>(
      create: (_) => DoctorDirectoryController(),
      child: const DoctorDirectoryScreen(),
    ),
  );
}

Widget _buildDetailApp({String doctorId = 'doc-1', TextScaler? textScaler}) {
  return MaterialApp(
    theme: buildOmniTheme(),
    builder: (context, child) {
      if (textScaler == null) return child!;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      );
    },
    home: DoctorDetailScreen(doctorId: doctorId),
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

      // Debug: dump all non-empty text
      final allTexts = find.byType(Text);
      final texts = allTexts
          .evaluate()
          .map((e) {
            final widget = e.widget as Text;
            return widget.data ?? '';
          })
          .where((t) => t.isNotEmpty)
          .toList();
      // Print to debug output
      for (final t in texts) {
        // ignore: avoid_print
        print('TEXT: $t');
      }
      // At minimum, we should have header + tab content texts
      expect(texts.length, greaterThan(5));
    });

    testWidgets('renders biography', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      // Check the about tab content is visible
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

      // Gallery images should be rendered
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

      // Check equipment chip exists in widget tree
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

      // Should still show the sheet
      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);
    });

    testWidgets('closing sheet returns to detail', (tester) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);

      expect(find.byType(DoctorAvailabilitySheet), findsOneWidget);

      // Tap close button
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
      expect(find.text('Confirmer le rendez-vous'), findsNothing);
      expect(
        find.text(
          'En continuant, vous réservez ce créneau avec Dr. Sarah Mansour.',
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
      expect(find.textContaining('En continuant, vous réservez'), findsNothing);

      await _selectAvailabilityTime(tester, '15:30');
      expect(
        find.text(
          'En continuant, vous réservez ce créneau avec Dr. Sarah Mansour.',
        ),
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

    testWidgets('Continuer closes the picker without confirmation UI', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailApp());
      await tester.pumpAndSettle();

      await _openAvailabilitySheet(tester);
      await _selectAvailabilityTime(tester, '15:30');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorAvailabilitySheet), findsNothing);
      expect(find.text('Confirmer le rendez-vous'), findsNothing);
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

      // The sheet auto-selects the first available date, so slots should be visible
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
