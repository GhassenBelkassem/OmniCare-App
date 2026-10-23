import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/config/p4_cabinet_synthetic_activation.dart';

void main() {
  const authorities = (
    explicit: true,
    lifecycle: true,
    database: true,
    recovery: true,
  );

  test('opens only for debug, explicit loopback, and all four authorities', () {
    final gate = P4CabinetSyntheticActivation.resolve(
      isDebugBuild: true,
      apiBaseUrlExplicitlyDefined: true,
      apiBaseUrl: 'http://10.0.2.2:8080',
      explicitSyntheticDevelopmentAuthorization: authorities.explicit,
      backendLifecycleReady: authorities.lifecycle,
      authorizedIsolatedApplicationDatabase: authorities.database,
      waitingRecoveryIntegrated: authorities.recovery,
    );

    expect(gate.explicitSyntheticDevelopmentAuthorization, isTrue);
    expect(gate.backendLifecycleReady, isTrue);
    expect(gate.authorizedIsolatedApplicationDatabase, isTrue);
    expect(gate.waitingRecoveryIntegrated, isTrue);
  });

  test('rejects release builds and implicit or non-local API URLs', () {
    for (final input in [
      (debug: false, explicitUrl: true, url: 'http://localhost:8080'),
      (debug: true, explicitUrl: false, url: 'http://localhost:8080'),
      (debug: true, explicitUrl: true, url: 'https://api.omnicare.tn'),
      (debug: true, explicitUrl: true, url: 'http://localhost:8081'),
    ]) {
      expect(
        () => P4CabinetSyntheticActivation.resolve(
          isDebugBuild: input.debug,
          apiBaseUrlExplicitlyDefined: input.explicitUrl,
          apiBaseUrl: input.url,
          explicitSyntheticDevelopmentAuthorization: authorities.explicit,
          backendLifecycleReady: authorities.lifecycle,
          authorizedIsolatedApplicationDatabase: authorities.database,
          waitingRecoveryIntegrated: authorities.recovery,
        ),
        throwsA(isA<P4CabinetSyntheticActivationException>()),
      );
    }
  });

  test('rejects activation when any one authority is absent', () {
    for (final input in [
      (explicit: false, lifecycle: true, database: true, recovery: true),
      (explicit: true, lifecycle: false, database: true, recovery: true),
      (explicit: true, lifecycle: true, database: false, recovery: true),
      (explicit: true, lifecycle: true, database: true, recovery: false),
    ]) {
      expect(
        () => P4CabinetSyntheticActivation.resolve(
          isDebugBuild: true,
          apiBaseUrlExplicitlyDefined: true,
          apiBaseUrl: 'http://127.0.0.1:8080',
          explicitSyntheticDevelopmentAuthorization: input.explicit,
          backendLifecycleReady: input.lifecycle,
          authorizedIsolatedApplicationDatabase: input.database,
          waitingRecoveryIntegrated: input.recovery,
        ),
        throwsA(isA<P4CabinetSyntheticActivationException>()),
      );
    }
  });
}
