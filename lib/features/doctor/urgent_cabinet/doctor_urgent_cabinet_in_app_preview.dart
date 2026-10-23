import 'package:flutter/foundation.dart';

import '../workspace/doctor_workspace_config.dart';
import 'doctor_urgent_cabinet_decision_source.dart';
import 'doctor_urgent_cabinet_request.dart';
import 'doctor_urgent_cabinet_request_source.dart';

@immutable
class DoctorUrgentCabinetInAppPreviewConfig {
  const DoctorUrgentCabinetInAppPreviewConfig({
    required this.enabled,
    required this.developmentDoctorId,
    required this.cabinetName,
    required this.cabinetAddress,
    required this.cabinetCity,
    required this.cabinetGovernorate,
  });

  const DoctorUrgentCabinetInAppPreviewConfig.fromEnvironment()
    : enabled = const bool.fromEnvironment(
        'D_UI_02_IN_APP_PREVIEW',
        defaultValue: false,
      ),
      developmentDoctorId = const String.fromEnvironment('D_UI_02_DOCTOR_ID'),
      cabinetName = const String.fromEnvironment('D_UI_02_CABINET_NAME'),
      cabinetAddress = const String.fromEnvironment('D_UI_02_CABINET_ADDRESS'),
      cabinetCity = const String.fromEnvironment('D_UI_02_CABINET_CITY'),
      cabinetGovernorate = const String.fromEnvironment(
        'D_UI_02_CABINET_GOVERNORATE',
      );

  final bool enabled;
  final String developmentDoctorId;
  final String cabinetName;
  final String cabinetAddress;
  final String cabinetCity;
  final String cabinetGovernorate;
}

enum DoctorUrgentCabinetInAppPreviewReason {
  enabled,
  notDebugBuild,
  previewDisabled,
  notAuthenticatedDoctor,
  authenticatedDoctorIdMissing,
  developmentDoctorIdMissing,
  developmentDoctorIdMismatch,
  workspaceDoctorIdMismatch,
  urgentCabinetCapabilityMissing,
  localCabinetMissingOrIncomplete,
  developmentCabinetMissingOrIncomplete,
  cabinetMismatch,
}

@immutable
class DoctorUrgentCabinetInAppPreviewDecision {
  const DoctorUrgentCabinetInAppPreviewDecision._({
    required this.reason,
    required this.fingerprint,
    this.requestSource,
    this.decisionSource,
  });

  final DoctorUrgentCabinetInAppPreviewReason reason;
  final Object fingerprint;
  final DoctorUrgentCabinetRequestSource? requestSource;
  final DoctorUrgentCabinetDecisionSource? decisionSource;

  bool get isEnabled =>
      reason == DoctorUrgentCabinetInAppPreviewReason.enabled &&
      requestSource != null &&
      decisionSource != null;

  String get debugMessage => switch (reason) {
    DoctorUrgentCabinetInAppPreviewReason.enabled =>
      'synthetic CABINET request enabled for the authenticated Doctor and matching cabinet',
    DoctorUrgentCabinetInAppPreviewReason.notDebugBuild =>
      'disabled because this is not a debug build',
    DoctorUrgentCabinetInAppPreviewReason.previewDisabled =>
      'disabled because D_UI_02_IN_APP_PREVIEW is not true',
    DoctorUrgentCabinetInAppPreviewReason.notAuthenticatedDoctor =>
      'blocked because the authenticated session is not a Doctor session',
    DoctorUrgentCabinetInAppPreviewReason.authenticatedDoctorIdMissing =>
      'blocked because the authenticated Doctor ID is unavailable',
    DoctorUrgentCabinetInAppPreviewReason.developmentDoctorIdMissing =>
      'blocked because D_UI_02_DOCTOR_ID is missing',
    DoctorUrgentCabinetInAppPreviewReason.developmentDoctorIdMismatch =>
      'blocked because D_UI_02_DOCTOR_ID does not match the authenticated Doctor ID',
    DoctorUrgentCabinetInAppPreviewReason.workspaceDoctorIdMismatch =>
      'blocked because the local workspace does not belong to the authenticated Doctor',
    DoctorUrgentCabinetInAppPreviewReason.urgentCabinetCapabilityMissing =>
      'blocked because urgent CABINET consultations are not configured',
    DoctorUrgentCabinetInAppPreviewReason.localCabinetMissingOrIncomplete =>
      'blocked because the local cabinet configuration is missing or incomplete',
    DoctorUrgentCabinetInAppPreviewReason
        .developmentCabinetMissingOrIncomplete =>
      'blocked because the D_UI_02 cabinet definitions are missing or incomplete',
    DoctorUrgentCabinetInAppPreviewReason.cabinetMismatch =>
      'blocked because the D_UI_02 cabinet does not match the configured cabinet',
  };
}

abstract final class DoctorUrgentCabinetInAppPreview {
  static const _fixtureKey = 'd-ui-02b-in-app-preview-request';
  static const _cabinetKey = 'd-ui-02b-in-app-preview-cabinet';

  static DoctorUrgentCabinetInAppPreviewDecision forCurrentBuild({
    required bool isAuthenticatedDoctor,
    required String authenticatedDoctorId,
    required DoctorWorkspaceConfig? workspaceConfig,
  }) => resolve(
    isDebugBuild: kDebugMode,
    isAuthenticatedDoctor: isAuthenticatedDoctor,
    authenticatedDoctorId: authenticatedDoctorId,
    workspaceConfig: workspaceConfig,
    config: const DoctorUrgentCabinetInAppPreviewConfig.fromEnvironment(),
  );

  @visibleForTesting
  static DoctorUrgentCabinetInAppPreviewDecision resolve({
    required bool isDebugBuild,
    required bool isAuthenticatedDoctor,
    required String authenticatedDoctorId,
    required DoctorWorkspaceConfig? workspaceConfig,
    required DoctorUrgentCabinetInAppPreviewConfig config,
  }) {
    final authenticatedId = authenticatedDoctorId.trim();
    final developmentId = config.developmentDoctorId.trim();
    final localSnapshot = _localCabinetSnapshot(workspaceConfig);
    final developmentSnapshot = DoctorUrgentCabinetSnapshot.tryCreate(
      name: config.cabinetName,
      address: config.cabinetAddress,
      city: config.cabinetCity,
      governorate: config.cabinetGovernorate,
    );
    final fingerprint = (
      isDebugBuild: isDebugBuild,
      isAuthenticatedDoctor: isAuthenticatedDoctor,
      authenticatedDoctorId: authenticatedId,
      workspaceDoctorId: workspaceConfig?.doctorId.trim(),
      hasCapability:
          workspaceConfig?.services.contains(
            DoctorWorkspaceService.urgentCabinetConsultations,
          ) ??
          false,
      localCabinet: localSnapshot?.normalizedFingerprint,
      previewEnabled: config.enabled,
      developmentDoctorId: developmentId,
      developmentCabinet: developmentSnapshot?.normalizedFingerprint,
    );

    DoctorUrgentCabinetInAppPreviewDecision blocked(
      DoctorUrgentCabinetInAppPreviewReason reason,
    ) => DoctorUrgentCabinetInAppPreviewDecision._(
      reason: reason,
      fingerprint: fingerprint,
    );

    if (!isDebugBuild) {
      return blocked(DoctorUrgentCabinetInAppPreviewReason.notDebugBuild);
    }
    if (!config.enabled) {
      return blocked(DoctorUrgentCabinetInAppPreviewReason.previewDisabled);
    }
    if (!isAuthenticatedDoctor) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.notAuthenticatedDoctor,
      );
    }
    if (authenticatedId.isEmpty) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.authenticatedDoctorIdMissing,
      );
    }
    if (developmentId.isEmpty) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.developmentDoctorIdMissing,
      );
    }
    if (developmentId != authenticatedId) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.developmentDoctorIdMismatch,
      );
    }
    if (workspaceConfig == null ||
        workspaceConfig.doctorId.trim() != authenticatedId) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.workspaceDoctorIdMismatch,
      );
    }
    if (!workspaceConfig.services.contains(
      DoctorWorkspaceService.urgentCabinetConsultations,
    )) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.urgentCabinetCapabilityMissing,
      );
    }
    if (localSnapshot == null) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason.localCabinetMissingOrIncomplete,
      );
    }
    if (developmentSnapshot == null) {
      return blocked(
        DoctorUrgentCabinetInAppPreviewReason
            .developmentCabinetMissingOrIncomplete,
      );
    }
    if (!developmentSnapshot.matches(localSnapshot)) {
      return blocked(DoctorUrgentCabinetInAppPreviewReason.cabinetMismatch);
    }

    final request = DoctorUrgentCabinetRequest(
      developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(
        _fixtureKey,
      ),
      targetDoctorId: developmentId,
      targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
        DoctorUrgentCabinetDevelopmentCabinetKey(_cabinetKey),
      ),
      cabinet: developmentSnapshot,
      patient: const DoctorUrgentCabinetPatientProjection.masked(),
      fee: DoctorUrgentCabinetFeeSnapshot(
        amountMilliTnd: 75000,
        currencyCode: 'TND',
        provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
      ),
      dataProvenance: DoctorUrgentCabinetDataProvenance.developmentFixture,
      status: DoctorUrgentCabinetRequestStatus.newRequest,
    );
    return DoctorUrgentCabinetInAppPreviewDecision._(
      reason: DoctorUrgentCabinetInAppPreviewReason.enabled,
      fingerprint: fingerprint,
      requestSource: DoctorUrgentCabinetDevelopmentRequestSource(
        requests: [request],
      ),
      decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
        request: request,
      ),
    );
  }

  static DoctorUrgentCabinetSnapshot? _localCabinetSnapshot(
    DoctorWorkspaceConfig? workspaceConfig,
  ) {
    final cabinet = workspaceConfig?.cabinet;
    if (cabinet == null) return null;
    return DoctorUrgentCabinetSnapshot.tryCreate(
      name: cabinet.name,
      address: cabinet.address,
      city: cabinet.city,
      governorate: cabinet.governorate,
    );
  }
}
