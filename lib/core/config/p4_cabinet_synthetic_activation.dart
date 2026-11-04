import 'package:flutter/foundation.dart';

import '../../features/emergency/urgent_cabinet/urgent_cabinet_submission_activation_gate.dart';
import 'app_environment.dart';

class P4CabinetSyntheticActivationException implements Exception {
  const P4CabinetSyntheticActivationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fail-closed launch boundary for the one approved local synthetic E2E mode.
///
/// Normal entrypoints never call this resolver and retain the checked-in closed
/// gate. This entrypoint additionally requires every authority as a direct
/// compile-time define and an explicit loopback API URL.
class P4CabinetSyntheticActivation {
  const P4CabinetSyntheticActivation._();

  static const _explicitAuthorization = bool.fromEnvironment(
    'OMNICARE_P4CAB_SYNTHETIC_SUBMISSION_AUTHORIZED',
    defaultValue: false,
  );
  static const _backendLifecycleReady = bool.fromEnvironment(
    'OMNICARE_P4CAB_BACKEND_LIFECYCLE_READY',
    defaultValue: false,
  );
  static const _isolatedDatabaseAuthorized = bool.fromEnvironment(
    'OMNICARE_P4CAB_ISOLATED_DATABASE_AUTHORIZED',
    defaultValue: false,
  );
  static const _waitingRecoveryIntegrated = bool.fromEnvironment(
    'OMNICARE_P4CAB_WAITING_RECOVERY_INTEGRATED',
    defaultValue: false,
  );
  static const _apiBaseUrlExplicitlyDefined = bool.hasEnvironment(
    'OMNICARE_API_BASE_URL',
  );

  static UrgentCabinetSubmissionActivationGate forCurrentBuild() => resolve(
    isDebugBuild: kDebugMode,
    apiBaseUrlExplicitlyDefined: _apiBaseUrlExplicitlyDefined,
    apiBaseUrl: AppEnvironment.apiBaseUrl,
    explicitSyntheticDevelopmentAuthorization: _explicitAuthorization,
    backendLifecycleReady: _backendLifecycleReady,
    authorizedIsolatedApplicationDatabase: _isolatedDatabaseAuthorized,
    waitingRecoveryIntegrated: _waitingRecoveryIntegrated,
  );

  @visibleForTesting
  static UrgentCabinetSubmissionActivationGate resolve({
    required bool isDebugBuild,
    required bool apiBaseUrlExplicitlyDefined,
    required String apiBaseUrl,
    required bool explicitSyntheticDevelopmentAuthorization,
    required bool backendLifecycleReady,
    required bool authorizedIsolatedApplicationDatabase,
    required bool waitingRecoveryIntegrated,
  }) {
    if (!isDebugBuild) {
      throw const P4CabinetSyntheticActivationException(
        'Synthetic CABINET submission is restricted to debug builds.',
      );
    }
    if (!apiBaseUrlExplicitlyDefined || !_isApprovedLoopbackApi(apiBaseUrl)) {
      throw const P4CabinetSyntheticActivationException(
        'Synthetic CABINET submission requires an explicit approved loopback API URL.',
      );
    }
    if (!explicitSyntheticDevelopmentAuthorization ||
        !backendLifecycleReady ||
        !authorizedIsolatedApplicationDatabase ||
        !waitingRecoveryIntegrated) {
      throw const P4CabinetSyntheticActivationException(
        'All four synthetic CABINET submission authorities are required.',
      );
    }

    return const UrgentCabinetSubmissionActivationGate(
      explicitSyntheticDevelopmentAuthorization: true,
      backendLifecycleReady: true,
      authorizedIsolatedApplicationDatabase: true,
      waitingRecoveryIntegrated: true,
    );
  }

  static bool _isApprovedLoopbackApi(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.port != 8080 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return false;
    }
    return const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
  }
}
