import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_access.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';

void main() {
  Widget buildRecord(
    DoctorMedicalRecordAccess access, {
    Key? key,
    VoidCallback? onContinueConsultation = _noop,
  }) => MaterialApp(
    theme: buildOmniTheme(),
    home: DoctorMedicalRecordScreen(
      key: key,
      access: access,
      onContinueConsultation: onContinueConsultation,
    ),
  );

  testWidgets('full access presents the patient passport read-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRecord(DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo)),
    );

    for (final label in [
      'Dossier médical',
      'Amina Chaari · 45 ans',
      'Urgence à domicile · OMN-2026-1847',
      'Accès médical autorisé',
      'Accès temporaire pour cette consultation.',
      'Informations essentielles',
      'Groupe Sanguin',
      'Aucune allergie connue',
      'Diabète Type 2',
      'Metformine',
      'Contexte urgent',
      'Continuer la consultation',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.textContaining('Ajouter un document'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full access supports patient-style history and document tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRecord(DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo)),
    );

    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    expect(find.text('Historique des consultations'), findsOneWidget);
    expect(find.text('Contrôle de routine'), findsOneWidget);
    expect(find.text('Vaccination'), findsOneWidget);
    expect(find.text('Consultation annuelle'), findsOneWidget);
    expect(find.text('Médecin généraliste'), findsNWidgets(2));
    expect(find.text('Gynécologue'), findsOneWidget);
    expect(find.text('Dr. Karim Mansour'), findsNothing);
    expect(find.text('Dr. Nadia Hamdi'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.lock_open_outlined), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsNWidgets(3));

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('Documents médicaux'), findsOneWidget);
    expect(find.text('Bilan sanguin'), findsOneWidget);
    expect(find.byTooltip('Aperçu du document'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Aperçu du document').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('lecture seule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consultation detail presents the authorized clinical summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRecord(DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo)),
    );
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contrôle de routine'));
    await tester.pumpAndSettle();

    for (final label in [
      'Détail de la consultation',
      'Motif',
      'Diagnostic',
      'Médicaments',
      'Hypertension artérielle stable',
      'Amlodipine 5 mg',
      '1 comprimé / jour',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('12 févr. 2026'), findsNWidgets(2));
    expect(find.text('Médecin généraliste'), findsNWidgets(3));
    expect(find.text('Contrôle de routine'), findsNWidgets(2));
    for (final absent in [
      'Consultation disponible en lecture seule',
      'Modifier',
      'Supprimer',
      'Partager',
      'Dr. Karim Mansour',
      'Dr. Nadia Hamdi',
    ]) {
      expect(find.textContaining(absent), findsNothing);
    }
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consultation detail states when no medication was prescribed', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRecord(DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo)),
    );
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    final vaccination = find.textContaining('Vaccination').first;
    await tester.scrollUntilVisible(vaccination, 160);
    await tester.tap(vaccination);
    await tester.pumpAndSettle();

    expect(find.text('Détail de la consultation'), findsOneWidget);
    expect(find.text('Consultation préventive'), findsOneWidget);
    expect(find.text('Aucun médicament prescrit'), findsOneWidget);
    expect(find.text('Amlodipine 5 mg'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limited access never renders withheld medical record values', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRecord(
        DoctorMedicalRecordAccess.lifeSafetyDemo(DoctorUrgentRequest.demo),
      ),
    );

    expect(find.text('Informations vitales'), findsOneWidget);
    expect(find.text('Aucune allergie connue'), findsOneWidget);
    for (final withheld in [
      'Diabète Type 2',
      'Hypertension',
      'Metformine',
      'Lisinopril',
      'Bilan sanguin',
    ]) {
      expect(find.text(withheld), findsNothing);
    }

    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    expect(find.text('Historique non partagé par le patient'), findsOneWidget);
    expect(find.text('Non partagé par le patient'), findsOneWidget);
    expect(find.text('Dr. Karim Mansour'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('Documents non partagés par le patient'), findsOneWidget);
    expect(find.text('Bilan sanguin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consultation continuation delegates to the canonical route', (
    tester,
  ) async {
    var continuationCalls = 0;
    await tester.pumpWidget(
      buildRecord(
        DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo),
        onContinueConsultation: () => continuationCalls++,
      ),
    );
    final continuation = find.text('Continuer la consultation');
    await tester.scrollUntilVisible(continuation, 180);
    await tester.tap(continuation);
    await tester.pumpAndSettle();
    expect(continuationCalls, 1);
    expect(
      find.text('La consultation sera ajoutée à l’étape suivante.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview without canonical continuation exposes no fake action', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRecord(
        DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo),
        onContinueConsultation: null,
      ),
    );

    expect(find.text('Continuer la consultation'), findsNothing);
    expect(
      find.text('La consultation sera ajoutée à l’étape suivante.'),
      findsNothing,
    );
  });

  testWidgets('medical record fits supported phone dimensions', (tester) async {
    const sizes = [Size(360, 568), Size(390, 844), Size(430, 932)];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        buildRecord(
          DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest.demo),
          key: ValueKey(size),
        ),
      );
      expect(find.text('Continuer la consultation'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'summary at $size');
      final history = find.text('Historique');
      await tester.tap(history);
      await tester.pumpAndSettle();
      final consultation = find.text('Contrôle de routine');
      await tester.scrollUntilVisible(consultation, 160);
      await tester.tap(consultation);
      await tester.pumpAndSettle();
      expect(find.text('Détail de la consultation'), findsOneWidget);
      expect(find.text('Amlodipine 5 mg'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'sheet at $size');
      Navigator.of(
        tester.element(find.text('Détail de la consultation')),
      ).pop();
      await tester.pumpAndSettle();
    }
  });
}

void _noop() {}
