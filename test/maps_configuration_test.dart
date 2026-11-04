import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/maps/maps_configuration_provider_native.dart'
    as native;
import 'package:omnicare_mobile/core/maps/maps_configuration_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('omnicare/maps_configuration');

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Google Maps API-key validation', () {
    test('accepts only a configured Google-style key shape', () {
      expect(
        isConfiguredGoogleMapsApiKey('AIza${List.filled(32, 'a').join()}'),
        isTrue,
      );
    });

    test('rejects missing and placeholder values without exposing them', () {
      expect(isConfiguredGoogleMapsApiKey(''), isFalse);
      expect(isConfiguredGoogleMapsApiKey(r'$(MAPS_API_KEY)'), isFalse);
      expect(isConfiguredGoogleMapsApiKey('%GOOGLE_MAPS_API_KEY%'), isFalse);
      expect(
        isConfiguredGoogleMapsApiKey('REPLACE_WITH_RESTRICTED_WEB_MAPS_KEY'),
        isFalse,
      );
    });
  });

  group('native configuration bridge', () {
    test('accepts a configured Android response', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'status');
            return <String, Object?>{'configured': true, 'platform': 'android'};
          });

      final status = await native.loadMapsConfiguration();

      expect(status.configured, isTrue);
      expect(status.platform, 'android');
      expect(status.failure, isNull);
    });

    test('fails closed for a missing iOS key', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            return <String, Object?>{'configured': false, 'platform': 'ios'};
          });

      final status = await native.loadMapsConfiguration();

      expect(status.configured, isFalse);
      expect(status.platform, 'ios');
      expect(status.failure, MapsConfigurationFailure.missingOrInvalidKey);
    });

    test('fails closed when the native bridge is unavailable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final status = await native.loadMapsConfiguration();

      expect(status.configured, isFalse);
      expect(
        status.failure,
        MapsConfigurationFailure.platformBridgeUnavailable,
      );
    });
  });
}
