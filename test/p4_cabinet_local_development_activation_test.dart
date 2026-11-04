import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/config/p4_cabinet_local_development_activation.dart';

void main() {
  test(
    'normal application stays closed when no local activation is requested',
    () {
      final gate = P4CabinetLocalDevelopmentActivation.resolve(
        isDebugBuild: true,
        apiBaseUrlExplicitlyDefined: false,
        apiBaseUrl: 'http://localhost:8080',
        explicitLocalDevelopmentAuthorization: false,
        backendLifecycleReady: false,
        authorizedNormalApplicationDatabase: false,
        waitingRecoveryIntegrated: false,
      );

      expect(gate.explicitSyntheticDevelopmentAuthorization, isFalse);
      expect(gate.backendLifecycleReady, isFalse);
      expect(gate.authorizedIsolatedApplicationDatabase, isFalse);
      expect(gate.waitingRecoveryIntegrated, isFalse);
    },
  );

  test(
    'all independent local authorities open the existing submission gate',
    () {
      final gate = P4CabinetLocalDevelopmentActivation.resolve(
        isDebugBuild: true,
        apiBaseUrlExplicitlyDefined: true,
        apiBaseUrl: 'http://127.0.0.1:8080',
        explicitLocalDevelopmentAuthorization: true,
        backendLifecycleReady: true,
        authorizedNormalApplicationDatabase: true,
        waitingRecoveryIntegrated: true,
      );

      expect(gate.explicitSyntheticDevelopmentAuthorization, isTrue);
      expect(gate.backendLifecycleReady, isTrue);
      expect(gate.authorizedIsolatedApplicationDatabase, isTrue);
      expect(gate.waitingRecoveryIntegrated, isTrue);
    },
  );

  test('partial or non-loopback activation fails closed', () {
    expect(
      () => P4CabinetLocalDevelopmentActivation.resolve(
        isDebugBuild: true,
        apiBaseUrlExplicitlyDefined: true,
        apiBaseUrl: 'https://example.test',
        explicitLocalDevelopmentAuthorization: true,
        backendLifecycleReady: true,
        authorizedNormalApplicationDatabase: true,
        waitingRecoveryIntegrated: true,
      ),
      throwsA(isA<P4CabinetLocalDevelopmentActivationException>()),
    );
    expect(
      () => P4CabinetLocalDevelopmentActivation.resolve(
        isDebugBuild: true,
        apiBaseUrlExplicitlyDefined: true,
        apiBaseUrl: 'http://localhost:8080',
        explicitLocalDevelopmentAuthorization: true,
        backendLifecycleReady: false,
        authorizedNormalApplicationDatabase: true,
        waitingRecoveryIntegrated: true,
      ),
      throwsA(isA<P4CabinetLocalDevelopmentActivationException>()),
    );
  });

  test(
    'production builds reject local activation even with all authorities',
    () {
      expect(
        () => P4CabinetLocalDevelopmentActivation.resolve(
          isDebugBuild: false,
          apiBaseUrlExplicitlyDefined: true,
          apiBaseUrl: 'http://127.0.0.1:8080',
          explicitLocalDevelopmentAuthorization: true,
          backendLifecycleReady: true,
          authorizedNormalApplicationDatabase: true,
          waitingRecoveryIntegrated: true,
        ),
        throwsA(isA<P4CabinetLocalDevelopmentActivationException>()),
      );
    },
  );
}
