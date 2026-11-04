import 'package:flutter/foundation.dart';

import '../../features/emergency/urgent_cabinet/urgent_cabinet_submission_activation_gate.dart';
import 'app_environment.dart';

class P4CabinetLocalDevelopmentActivationException implements Exception {
  const P4CabinetLocalDevelopmentActivationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Independent activation boundary for the normal local-development CABINET flow.
///
/// With no activation defines the normal application remains closed. A partial
/// or unsafe activation fails startup instead of silently weakening the gate.
class P4CabinetLocalDevelopmentActivation {
  const P4CabinetLocalDevelopmentActivation._();

  static const _explicitAuthorization = bool.fromEnvironment(
    'OMNICARE_P4CAB_LOCAL_DEVELOPMENT_AUTHORIZED',
    defaultValue: false,
  );
  static const _backendLifecycleReady = bool.fromEnvironment(
    'OMNICARE_P4CAB_LOCAL_BACKEND_LIFECYCLE_READY',
    defaultValue: false,
  );
  static const _normalDatabaseAuthorized = bool.fromEnvironment(
    'OMNICARE_P4CAB_NORMAL_DATABASE_AUTHORIZED',
    defaultValue: false,
  );
  static const _waitingRecoveryIntegrated = bool.fromEnvironment(
    'OMNICARE_P4CAB_LOCAL_WAITING_RECOVERY_INTEGRATED',
    defaultValue: false,
  );
  static const _apiBaseUrlExplicitlyDefined = bool.hasEnvironment(
    'OMNICARE_API_BASE_URL',
  );

  static UrgentCabinetSubmissionActivationGate forCurrentBuild() => resolve(
    isDebugBuild: kDebugMode,
    apiBaseUrlExplicitlyDefined: _apiBaseUrlExplicitlyDefined,
    apiBaseUrl: AppEnvironment.apiBaseUrl,
    explicitLocalDevelopmentAuthorization: _explicitAuthorization,
    backendLifecycleReady: _backendLifecycleReady,
    authorizedNormalApplicationDatabase: _normalDatabaseAuthorized,
    waitingRecoveryIntegrated: _waitingRecoveryIntegrated,
  );

  @visibleForTesting
  static UrgentCabinetSubmissionActivationGate resolve({
    required bool isDebugBuild,
    required bool apiBaseUrlExplicitlyDefined,
    required String apiBaseUrl,
    required bool explicitLocalDevelopmentAuthorization,
    required bool backendLifecycleReady,
    required bool authorizedNormalApplicationDatabase,
    required bool waitingRecoveryIntegrated,
  }) {
    final requested =
        explicitLocalDevelopmentAuthorization ||
        backendLifecycleReady ||
        authorizedNormalApplicationDatabase ||
        waitingRecoveryIntegrated;
    if (!requested) {
      return UrgentCabinetSubmissionActivationGate.p4Cab03C01Closed;
    }
    if (!isDebugBuild) {
      throw const P4CabinetLocalDevelopmentActivationException(
        'Local CABINET submission is restricted to debug builds.',
      );
    }
    if (!apiBaseUrlExplicitlyDefined || !_isApprovedLoopbackApi(apiBaseUrl)) {
      throw const P4CabinetLocalDevelopmentActivationException(
        'Local CABINET submission requires an explicit loopback API on port 8080.',
      );
    }
    if (!explicitLocalDevelopmentAuthorization ||
        !backendLifecycleReady ||
        !authorizedNormalApplicationDatabase ||
        !waitingRecoveryIntegrated) {
      throw const P4CabinetLocalDevelopmentActivationException(
        'All independent local CABINET authorities are required.',
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
    return uri != null &&
        uri.scheme == 'http' &&
        uri.port == 8080 &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/') &&
        const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
  }
}
