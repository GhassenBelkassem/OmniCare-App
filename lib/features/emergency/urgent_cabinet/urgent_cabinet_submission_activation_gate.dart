import 'package:flutter/foundation.dart';

import 'urgent_cabinet_targeted_request_models.dart';

/// Explicit multi-party activation boundary for Patient CABINET submission.
///
/// The default gate remains closed. Normal local-development construction may
/// inject an open gate only after its independent environment checks pass.
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
