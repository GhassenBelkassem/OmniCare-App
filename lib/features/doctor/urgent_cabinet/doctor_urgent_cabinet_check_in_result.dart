import 'package:flutter/foundation.dart';

enum DoctorUrgentCabinetCheckInPreviewState {
  ready,
  cameraUnavailable,
  cameraPermissionDenied,
  verifyingSimulation,
  invalidQr,
  expiredQr,
  alreadyConsumedQr,
  wrongContext,
  networkUnavailable,
  unknownOutcome,
  demonstrationResult,
}

enum DoctorUrgentCabinetCheckInRecovery {
  retryAllowed,
  newQrRequired,
  authoritativeRefreshRequired,
  closeOnly,
}

enum DoctorUrgentCabinetCheckInVisualTreatment {
  neutral,
  information,
  warning,
  critical,
  demonstration,
}

/// Immutable, presentation-only copy for the D-UI-05B static preview.
///
/// It deliberately carries no identity, QR payload, backend status, clinical
/// state, consultation authority, or medical-record grant.
@immutable
final class DoctorUrgentCabinetCheckInResult {
  const DoctorUrgentCabinetCheckInResult(this.state);

  final DoctorUrgentCabinetCheckInPreviewState state;

  String get title => switch (state) {
    DoctorUrgentCabinetCheckInPreviewState.ready => 'Caméra non connectée',
    DoctorUrgentCabinetCheckInPreviewState.cameraUnavailable =>
      'Caméra indisponible',
    DoctorUrgentCabinetCheckInPreviewState.cameraPermissionDenied =>
      'Autorisation caméra refusée',
    DoctorUrgentCabinetCheckInPreviewState.verifyingSimulation =>
      'Simulation de vérification en cours',
    DoctorUrgentCabinetCheckInPreviewState.invalidQr => 'QR invalide',
    DoctorUrgentCabinetCheckInPreviewState.expiredQr => 'QR expiré',
    DoctorUrgentCabinetCheckInPreviewState.alreadyConsumedQr =>
      'QR déjà utilisé',
    DoctorUrgentCabinetCheckInPreviewState.wrongContext =>
      'QR non reconnu pour cette demande',
    DoctorUrgentCabinetCheckInPreviewState.networkUnavailable =>
      'Connexion indisponible',
    DoctorUrgentCabinetCheckInPreviewState.unknownOutcome =>
      'Résultat non confirmé',
    DoctorUrgentCabinetCheckInPreviewState.demonstrationResult =>
      "Aperçu d'un résultat positif",
  };

  String get description => switch (state) {
    DoctorUrgentCabinetCheckInPreviewState.ready =>
      'Placez le futur QR sécurisé dans la zone de scan lorsque la fonctionnalité sera disponible.',
    DoctorUrgentCabinetCheckInPreviewState.cameraUnavailable =>
      "La caméra n'est pas disponible dans cet aperçu. Aucun QR n'a été lu.",
    DoctorUrgentCabinetCheckInPreviewState.cameraPermissionDenied =>
      "L'accès à la caméra est refusé. Aucune vérification n'a été effectuée.",
    DoctorUrgentCabinetCheckInPreviewState.verifyingSimulation =>
      "Aucun QR réel n'est lu et aucun statut n'est modifié.",
    DoctorUrgentCabinetCheckInPreviewState.invalidQr =>
      "Ce QR ne peut pas être reconnu comme un justificatif de présence valide. Aucune vérification n'a été enregistrée.",
    DoctorUrgentCabinetCheckInPreviewState.expiredQr =>
      "Ce QR n'est plus utilisable. Aucune vérification n'a été enregistrée.",
    DoctorUrgentCabinetCheckInPreviewState.alreadyConsumedQr =>
      "Ce QR ne peut pas être utilisé une nouvelle fois. Aucune information sur une demande antérieure n'est affichée.",
    DoctorUrgentCabinetCheckInPreviewState.wrongContext =>
      "Ce QR ne peut pas être utilisé dans le contexte actuel. Aucune vérification n'a été enregistrée.",
    DoctorUrgentCabinetCheckInPreviewState.networkUnavailable =>
      "La présence ne peut pas être confirmée sans réponse du service. Aucun statut n'a été modifié.",
    DoctorUrgentCabinetCheckInPreviewState.unknownOutcome =>
      "Le résultat de la vérification est inconnu. Ne relancez pas la vérification avant d'avoir actualisé l'état de la demande.",
    DoctorUrgentCabinetCheckInPreviewState.demonstrationResult =>
      "Scénario de démonstration uniquement — aucune présence réelle n'a été enregistrée.",
  };

  String? get guidance => switch (state) {
    DoctorUrgentCabinetCheckInPreviewState.invalidQr =>
      'Présentez un autre QR puis réessayez.',
    DoctorUrgentCabinetCheckInPreviewState.expiredQr =>
      "Demandez au patient ou à son représentant autorisé d'afficher un nouveau QR.",
    DoctorUrgentCabinetCheckInPreviewState.alreadyConsumedQr =>
      'Demandez un nouveau QR avant de réessayer.',
    DoctorUrgentCabinetCheckInPreviewState.wrongContext =>
      'Revenez à la demande acceptée concernée ou demandez un nouveau QR.',
    DoctorUrgentCabinetCheckInPreviewState.cameraPermissionDenied =>
      "Autorisez la caméra dans les réglages de l'appareil, puis réessayez.",
    DoctorUrgentCabinetCheckInPreviewState.networkUnavailable =>
      'Rétablissez la connexion avant toute nouvelle tentative.',
    DoctorUrgentCabinetCheckInPreviewState.unknownOutcome =>
      "Une actualisation autoritative sera nécessaire lorsque l'intégration sera disponible.",
    DoctorUrgentCabinetCheckInPreviewState.ready ||
    DoctorUrgentCabinetCheckInPreviewState.cameraUnavailable ||
    DoctorUrgentCabinetCheckInPreviewState.verifyingSimulation ||
    DoctorUrgentCabinetCheckInPreviewState.demonstrationResult => null,
  };

  String? get additionalSecurityCopy =>
      state == DoctorUrgentCabinetCheckInPreviewState.demonstrationResult
      ? "La consultation n'est pas démarrée et aucun accès au dossier médical n'est accordé."
      : null;

  DoctorUrgentCabinetCheckInRecovery get recovery => switch (state) {
    DoctorUrgentCabinetCheckInPreviewState.invalidQr ||
    DoctorUrgentCabinetCheckInPreviewState.networkUnavailable =>
      DoctorUrgentCabinetCheckInRecovery.retryAllowed,
    DoctorUrgentCabinetCheckInPreviewState.expiredQr ||
    DoctorUrgentCabinetCheckInPreviewState.alreadyConsumedQr ||
    DoctorUrgentCabinetCheckInPreviewState.wrongContext =>
      DoctorUrgentCabinetCheckInRecovery.newQrRequired,
    DoctorUrgentCabinetCheckInPreviewState.unknownOutcome =>
      DoctorUrgentCabinetCheckInRecovery.authoritativeRefreshRequired,
    DoctorUrgentCabinetCheckInPreviewState.ready ||
    DoctorUrgentCabinetCheckInPreviewState.cameraUnavailable ||
    DoctorUrgentCabinetCheckInPreviewState.cameraPermissionDenied ||
    DoctorUrgentCabinetCheckInPreviewState.verifyingSimulation ||
    DoctorUrgentCabinetCheckInPreviewState.demonstrationResult =>
      DoctorUrgentCabinetCheckInRecovery.closeOnly,
  };

  DoctorUrgentCabinetCheckInVisualTreatment get visualTreatment =>
      switch (state) {
        DoctorUrgentCabinetCheckInPreviewState.ready ||
        DoctorUrgentCabinetCheckInPreviewState.cameraUnavailable =>
          DoctorUrgentCabinetCheckInVisualTreatment.neutral,
        DoctorUrgentCabinetCheckInPreviewState.cameraPermissionDenied ||
        DoctorUrgentCabinetCheckInPreviewState.expiredQr ||
        DoctorUrgentCabinetCheckInPreviewState.alreadyConsumedQr ||
        DoctorUrgentCabinetCheckInPreviewState.wrongContext =>
          DoctorUrgentCabinetCheckInVisualTreatment.warning,
        DoctorUrgentCabinetCheckInPreviewState.invalidQr =>
          DoctorUrgentCabinetCheckInVisualTreatment.critical,
        DoctorUrgentCabinetCheckInPreviewState.verifyingSimulation ||
        DoctorUrgentCabinetCheckInPreviewState.networkUnavailable ||
        DoctorUrgentCabinetCheckInPreviewState.unknownOutcome =>
          DoctorUrgentCabinetCheckInVisualTreatment.information,
        DoctorUrgentCabinetCheckInPreviewState.demonstrationResult =>
          DoctorUrgentCabinetCheckInVisualTreatment.demonstration,
      };
}
