import 'package:flutter/foundation.dart';

enum UrgentCabinetPatientCheckInPreviewState {
  ready,
  verificationPendingPreview,
  codeUnavailable,
  codeExpired,
  codeAlreadyUsed,
  wrongContext,
  networkUnavailable,
  unknownOutcome,
  requestNoLongerActive,
  relationshipUnavailable,
}

enum UrgentCabinetPatientCheckInVisualTreatment {
  neutral,
  information,
  warning,
  critical,
}

/// Immutable copy for one local Patient check-in demonstration scenario.
///
/// This is intentionally presentation-only. It contains no identifier, QR
/// material, backend state, Patient-presence authority, consultation state,
/// or Medical Record authority.
@immutable
final class UrgentCabinetPatientCheckInPresentation {
  const UrgentCabinetPatientCheckInPresentation(this.state);

  static const demonstrationDisclosure =
      "Aperçu de démonstration — aucun statut réel n'a été modifié.";

  final UrgentCabinetPatientCheckInPreviewState state;

  String get title => switch (state) {
    UrgentCabinetPatientCheckInPreviewState.ready => 'Aperçu prêt',
    UrgentCabinetPatientCheckInPreviewState.verificationPendingPreview =>
      'En attente de validation',
    UrgentCabinetPatientCheckInPreviewState.codeUnavailable =>
      'Code sécurisé indisponible',
    UrgentCabinetPatientCheckInPreviewState.codeExpired => 'Code expiré',
    UrgentCabinetPatientCheckInPreviewState.codeAlreadyUsed =>
      'Code déjà utilisé',
    UrgentCabinetPatientCheckInPreviewState.wrongContext =>
      'Code non reconnu pour cette demande',
    UrgentCabinetPatientCheckInPreviewState.networkUnavailable =>
      'Connexion indisponible',
    UrgentCabinetPatientCheckInPreviewState.unknownOutcome =>
      'Résultat non confirmé',
    UrgentCabinetPatientCheckInPreviewState.requestNoLongerActive =>
      'Demande non disponible',
    UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable =>
      'Accès au proche indisponible',
  };

  String get description => switch (state) {
    UrgentCabinetPatientCheckInPreviewState.ready =>
      "Sélectionnez un scénario de démonstration pour découvrir les futurs messages de vérification. Aucun code réel n'est utilisé.",
    UrgentCabinetPatientCheckInPreviewState.verificationPendingPreview =>
      "Votre présence devra être vérifiée par le médecin avant d'être confirmée.",
    UrgentCabinetPatientCheckInPreviewState.codeUnavailable =>
      "Le code de présence n'est pas disponible pour le moment.",
    UrgentCabinetPatientCheckInPreviewState.codeExpired =>
      "Ce code n'est plus utilisable. Un nouveau code sécurisé devra être demandé lorsque le service sera disponible.",
    UrgentCabinetPatientCheckInPreviewState.codeAlreadyUsed =>
      'Ce code ne peut pas être présenté une nouvelle fois.',
    UrgentCabinetPatientCheckInPreviewState.wrongContext =>
      'Ce code ne correspond pas au contexte actuellement affiché.',
    UrgentCabinetPatientCheckInPreviewState.networkUnavailable =>
      "Impossible de vérifier l'état de votre demande sans connexion.",
    UrgentCabinetPatientCheckInPreviewState.unknownOutcome =>
      "Nous ne pouvons pas confirmer le résultat. L'état de la demande devra être actualisé avant toute nouvelle tentative.",
    UrgentCabinetPatientCheckInPreviewState.requestNoLongerActive =>
      'Cette demande ne peut plus être utilisée pour la vérification de présence.',
    UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable =>
      'Vous ne pouvez plus afficher les informations de vérification pour cette personne.',
  };

  String? get guidance => switch (state) {
    UrgentCabinetPatientCheckInPreviewState.verificationPendingPreview =>
      'Statut futur simulé uniquement.',
    UrgentCabinetPatientCheckInPreviewState.codeUnavailable =>
      "Demandez de l'aide au cabinet. Aucune présence n'a été enregistrée.",
    UrgentCabinetPatientCheckInPreviewState.codeAlreadyUsed =>
      "N'effectuez pas une nouvelle tentative sans actualiser la demande.",
    UrgentCabinetPatientCheckInPreviewState.wrongContext =>
      'Revenez aux instructions et vérifiez la demande concernée.',
    UrgentCabinetPatientCheckInPreviewState.networkUnavailable =>
      'Rétablissez la connexion avant toute nouvelle tentative.',
    UrgentCabinetPatientCheckInPreviewState.ready ||
    UrgentCabinetPatientCheckInPreviewState.codeExpired ||
    UrgentCabinetPatientCheckInPreviewState.unknownOutcome ||
    UrgentCabinetPatientCheckInPreviewState.requestNoLongerActive ||
    UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable => null,
  };

  UrgentCabinetPatientCheckInVisualTreatment get visualTreatment =>
      switch (state) {
        UrgentCabinetPatientCheckInPreviewState.ready ||
        UrgentCabinetPatientCheckInPreviewState.wrongContext =>
          UrgentCabinetPatientCheckInVisualTreatment.neutral,
        UrgentCabinetPatientCheckInPreviewState.verificationPendingPreview =>
          UrgentCabinetPatientCheckInVisualTreatment.information,
        UrgentCabinetPatientCheckInPreviewState.codeUnavailable ||
        UrgentCabinetPatientCheckInPreviewState.codeExpired ||
        UrgentCabinetPatientCheckInPreviewState.codeAlreadyUsed ||
        UrgentCabinetPatientCheckInPreviewState.networkUnavailable =>
          UrgentCabinetPatientCheckInVisualTreatment.warning,
        UrgentCabinetPatientCheckInPreviewState.unknownOutcome ||
        UrgentCabinetPatientCheckInPreviewState.requestNoLongerActive ||
        UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable =>
          UrgentCabinetPatientCheckInVisualTreatment.critical,
      };

  String get accessibilityAnnouncement =>
      [title, description, ?guidance, demonstrationDisclosure].join(' ');
}
