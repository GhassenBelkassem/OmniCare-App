import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_check_in_presentation.dart';

void main() {
  const expected =
      <
        UrgentCabinetPatientCheckInPreviewState,
        ({
          String title,
          String description,
          String? guidance,
          UrgentCabinetPatientCheckInVisualTreatment treatment,
        })
      >{
        UrgentCabinetPatientCheckInPreviewState.ready: (
          title: 'Aperçu prêt',
          description:
              "Sélectionnez un scénario de démonstration pour découvrir les futurs messages de vérification. Aucun code réel n'est utilisé.",
          guidance: null,
          treatment: UrgentCabinetPatientCheckInVisualTreatment.neutral,
        ),
        UrgentCabinetPatientCheckInPreviewState.verificationPendingPreview: (
          title: 'En attente de validation',
          description:
              "Votre présence devra être vérifiée par le médecin avant d'être confirmée.",
          guidance: 'Statut futur simulé uniquement.',
          treatment: UrgentCabinetPatientCheckInVisualTreatment.information,
        ),
        UrgentCabinetPatientCheckInPreviewState.codeUnavailable: (
          title: 'Code sécurisé indisponible',
          description:
              "Le code de présence n'est pas disponible pour le moment.",
          guidance:
              "Demandez de l'aide au cabinet. Aucune présence n'a été enregistrée.",
          treatment: UrgentCabinetPatientCheckInVisualTreatment.warning,
        ),
        UrgentCabinetPatientCheckInPreviewState.codeExpired: (
          title: 'Code expiré',
          description:
              "Ce code n'est plus utilisable. Un nouveau code sécurisé devra être demandé lorsque le service sera disponible.",
          guidance: null,
          treatment: UrgentCabinetPatientCheckInVisualTreatment.warning,
        ),
        UrgentCabinetPatientCheckInPreviewState.codeAlreadyUsed: (
          title: 'Code déjà utilisé',
          description: 'Ce code ne peut pas être présenté une nouvelle fois.',
          guidance:
              "N'effectuez pas une nouvelle tentative sans actualiser la demande.",
          treatment: UrgentCabinetPatientCheckInVisualTreatment.warning,
        ),
        UrgentCabinetPatientCheckInPreviewState.wrongContext: (
          title: 'Code non reconnu pour cette demande',
          description:
              'Ce code ne correspond pas au contexte actuellement affiché.',
          guidance:
              'Revenez aux instructions et vérifiez la demande concernée.',
          treatment: UrgentCabinetPatientCheckInVisualTreatment.neutral,
        ),
        UrgentCabinetPatientCheckInPreviewState.networkUnavailable: (
          title: 'Connexion indisponible',
          description:
              "Impossible de vérifier l'état de votre demande sans connexion.",
          guidance: 'Rétablissez la connexion avant toute nouvelle tentative.',
          treatment: UrgentCabinetPatientCheckInVisualTreatment.warning,
        ),
        UrgentCabinetPatientCheckInPreviewState.unknownOutcome: (
          title: 'Résultat non confirmé',
          description:
              "Nous ne pouvons pas confirmer le résultat. L'état de la demande devra être actualisé avant toute nouvelle tentative.",
          guidance: null,
          treatment: UrgentCabinetPatientCheckInVisualTreatment.critical,
        ),
        UrgentCabinetPatientCheckInPreviewState.requestNoLongerActive: (
          title: 'Demande non disponible',
          description:
              'Cette demande ne peut plus être utilisée pour la vérification de présence.',
          guidance: null,
          treatment: UrgentCabinetPatientCheckInVisualTreatment.critical,
        ),
        UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable: (
          title: 'Accès au proche indisponible',
          description:
              'Vous ne pouvez plus afficher les informations de vérification pour cette personne.',
          guidance: null,
          treatment: UrgentCabinetPatientCheckInVisualTreatment.critical,
        ),
      };

  test('every preview scenario has the approved exhaustive French mapping', () {
    expect(
      expected.keys.toSet(),
      UrgentCabinetPatientCheckInPreviewState.values.toSet(),
    );

    for (final state in UrgentCabinetPatientCheckInPreviewState.values) {
      final presentation = UrgentCabinetPatientCheckInPresentation(state);
      final approved = expected[state]!;

      expect(presentation.title, approved.title, reason: state.name);
      expect(
        presentation.description,
        approved.description,
        reason: state.name,
      );
      expect(presentation.guidance, approved.guidance, reason: state.name);
      expect(
        presentation.visualTreatment,
        approved.treatment,
        reason: state.name,
      );
      expect(presentation.accessibilityAnnouncement, contains(approved.title));
      expect(
        presentation.accessibilityAnnouncement,
        contains(
          UrgentCabinetPatientCheckInPresentation.demonstrationDisclosure,
        ),
      );
    }
  });

  test('no presentation claims real presence or clinical authorization', () {
    final renderedCopy = UrgentCabinetPatientCheckInPreviewState.values
        .map(UrgentCabinetPatientCheckInPresentation.new)
        .map(
          (presentation) => [
            presentation.title,
            presentation.description,
            presentation.guidance,
            presentation.accessibilityAnnouncement,
          ].whereType<String>().join(' '),
        )
        .join(' ');

    for (final prohibited in <String>[
      'Présence confirmée',
      'Patient arrivé',
      'Consultation démarrée',
      'Dossier médical accessible',
      'nonce',
      'signature',
      'token',
      'MRS',
    ]) {
      expect(renderedCopy, isNot(contains(prohibited)));
    }
  });

  test(
    'relationship scenario is presentation-only and makes no detection claim',
    () {
      const presentation = UrgentCabinetPatientCheckInPresentation(
        UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable,
      );

      expect(presentation.title, 'Accès au proche indisponible');
      expect(presentation.description, isNot(contains('révoqué')));
      expect(presentation.description, isNot(contains('détecté')));
      expect(presentation.guidance, isNull);
    },
  );
}
