import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/clinical_safety/clinical_feature_unavailable_screen.dart';

void main() {
  group('Phase 1 production clinical correctness boundary', () {
    testWidgets(
      'unsupported clinical actions fail closed without success copy',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ClinicalFeatureUnavailableScreen()),
        );

        expect(
          find.byKey(const ValueKey('clinical-feature-unavailable-screen')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Aucune demande, réservation ou consultation'),
          findsOneWidget,
        );
        expect(find.textContaining('confirmé avec succès'), findsNothing);
        expect(find.textContaining('Demande envoyée'), findsNothing);
      },
    );

    test('production route graphs cannot reach synthetic HOME authorities', () {
      final main = File('lib/main.dart').readAsStringSync();
      final patientHome = File(
        'lib/features/home/new_home_screen.dart',
      ).readAsStringSync();

      for (final source in <String>[main, patientHome]) {
        for (final forbidden in const <String>[
          "emergency/doctor_selection_screen.dart",
          "emergency/review_confirm_screen.dart",
          "emergency/doctor_calling_screen.dart",
          "emergency/doctor_arriving_screen.dart",
          "emergency/consultation_qr_screen.dart",
          "emergency/consultation_complete_screen.dart",
          'DemoDoctorMatchingSource',
          'createDemoUrgentDoctors',
          'ConsultationsApi',
          'DoctorSelectionScreen(',
          'ReviewConfirmScreen(',
          'DoctorCallingScreen(',
          'DoctorArrivingScreen(',
          'ConsultationQRScreen(',
          'ConsultationCompleteScreen(',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: forbidden);
        }
      }

      for (final forbidden in const <String>[
        'ReservationProvider()',
        'ReservationRepository()',
        'TimeSelectionScreen(',
        'ClinicRequestScreen(',
        'AppointmentConfirmationScreen(',
        'BookingConfirmedScreen(',
      ]) {
        expect(main, isNot(contains(forbidden)), reason: forbidden);
      }

      expect(main, contains('const ClinicalFeatureUnavailableScreen()'));
      expect(patientHome, contains('const ClinicalFeatureUnavailableScreen()'));
    });

    test(
      'timer confirmation, travel, arrival, and completion routes fail closed',
      () {
        final productionRouteGraphs = <String>[
          File('lib/main.dart').readAsStringSync(),
          File('lib/features/home/new_home_screen.dart').readAsStringSync(),
        ];
        const legacySuccessRoutes = <String>[
          "'/doctor-selection'",
          "'/review-confirm'",
          "'/doctor-calling'",
          "'/doctor-arriving'",
          "'/consultation-qr'",
          "'/consultation-complete'",
        ];

        for (final source in productionRouteGraphs) {
          for (final route in legacySuccessRoutes) {
            expect(
              source,
              contains(route),
              reason: '$route must be intercepted',
            );
          }
          expect(source, contains('const ClinicalFeatureUnavailableScreen()'));
          expect(source, isNot(contains('DoctorCallingScreen(')));
          expect(source, isNot(contains('DoctorArrivingScreen(')));
          expect(source, isNot(contains('ConsultationCompleteScreen(')));
        }
      },
    );

    test('urgent review drops intake payload at the fail-closed route', () {
      final review = File(
        'lib/features/emergency/emergency_review_screen.dart',
      ).readAsStringSync();

      expect(review, contains("'/clinical-request-unavailable'"));
      expect(review, isNot(contains("'/doctor-selection'")));
      expect(review, isNot(contains("'/provider-list'")));
      expect(
        review,
        isNot(contains("arguments: _requestData")),
        reason: 'Unsupported destinations must not receive clinical intake.',
      );
    });

    test('legacy matching requires an explicitly injected source', () {
      final selection = File(
        'lib/features/emergency/doctor_selection_screen.dart',
      ).readAsStringSync();

      expect(selection, contains('required this.matchingSource'));
      expect(selection, contains('final DoctorMatchingSource matchingSource'));
      expect(selection, isNot(contains('DemoDoctorMatchingSource(')));
      expect(selection, isNot(contains('createDemoUrgentDoctors()')));
    });

    test(
      'authoritative Doctor shell never mounts the legacy HOME simulation',
      () {
        final shell = File(
          'lib/features/doctor/shell/doctor_app_shell.dart',
        ).readAsStringSync();

        expect(
          shell,
          contains(
            'legacyHomeSimulationEnabled: widget.authoritativeCapabilities == null',
          ),
        );
        expect(
          shell,
          contains('if (!legacyHomeSimulationEnabled) return workspace;'),
        );
        expect(
          shell,
          contains(
            'onOpenHomeQr: legacyHomeSimulationEnabled ? onOpenQr : null',
          ),
        );
      },
    );
  });
}
