@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/maps/maps_configuration.dart';
import 'package:omnicare_mobile/core/maps/maps_configuration_provider_web.dart'
    as web_provider;

void main() {
  test('web configuration fails closed without a dart-defined key', () async {
    final status = await loadMapsConfiguration();

    expect(status.configured, isFalse);
    expect(status.platform, 'web');
    expect(status.failure, MapsConfigurationFailure.missingOrInvalidKey);
  });

  test('configured web key is passed only to the JavaScript loader', () async {
    final key = 'AIza${List.filled(32, 'w').join()}';
    var calls = 0;
    String? receivedKey;

    final status = await web_provider.loadMapsConfigurationForWeb(key, (
      candidate,
    ) async {
      calls++;
      receivedKey = candidate;
      return true;
    });

    expect(status.configured, isTrue);
    expect(status.platform, 'web');
    expect(calls, 1);
    expect(receivedKey, key);
  });

  test('missing web key never invokes the JavaScript loader', () async {
    var calls = 0;

    final status = await web_provider.loadMapsConfigurationForWeb('', (
      _,
    ) async {
      calls++;
      return true;
    });

    expect(status.configured, isFalse);
    expect(status.failure, MapsConfigurationFailure.missingOrInvalidKey);
    expect(calls, 0);
  });
}
