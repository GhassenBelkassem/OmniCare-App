import 'package:flutter/foundation.dart';

import 'urgent_cabinet_targeted_request_models.dart';

/// Patient CABINET submission boundary.
///
/// P4 is a frozen production flow. The production gate keeps the request's
/// authenticated account, validated payload and freshly revalidated target /
/// quote as mandatory authorities; the legacy closed gate remains only as an
/// explicit test and synthetic-rollout seam.
@immutable
class UrgentCabinetSubmissionActivationGate {
  const UrgentCabinetSubmissionActivationGate({
    required this.explicitSyntheticDevelopmentAuthorization,
    required this.backendLifecycleReady,
    required this.authorizedIsolatedApplicationDatabase,
    required this.waitingRecoveryIntegrated,
  });

  static const p4Cab03C01Closed = UrgentCabinetSubmissionActivationGate(
    explicitSyntheticDevelopmentAuthorization: false,
    backendLifecycleReady: false,
    authorizedIsolatedApplicationDatabase: false,
    waitingRecoveryIntegrated: false,
  );

  static const p4Production = UrgentCabinetSubmissionActivationGate(
    explicitSyntheticDevelopmentAuthorization: true,
    backendLifecycleReady: true,
    authorizedIsolatedApplicationDatabase: true,
    waitingRecoveryIntegrated: true,
  );

  /// Compatibility alias for tests and callers created in the earlier phase.
  static const p4Cab03B02 = p4Cab03C01Closed;

  final bool explicitSyntheticDevelopmentAuthorization;
  final bool backendLifecycleReady;
  final bool authorizedIsolatedApplicationDatabase;
  final bool waitingRecoveryIntegrated;

  bool allows({
    required String? authenticatedAccountId,
    required UrgentCabinetTargetedSubmissionValidation submission,
    required bool currentAuthoritativeTargetAndQuote,
  }) =>
      explicitSyntheticDevelopmentAuthorization &&
      backendLifecycleReady &&
      authorizedIsolatedApplicationDatabase &&
      waitingRecoveryIntegrated &&
      authenticatedAccountId?.trim().isNotEmpty == true &&
      submission.isValid &&
      currentAuthoritativeTargetAndQuote;
}
