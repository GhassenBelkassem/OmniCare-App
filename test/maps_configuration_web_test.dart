@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/maps/maps_configuration.dart';

void main() {
  test('web configuration fails closed without a dart-defined key', () async {
    final status = await loadMapsConfiguration();

    expect(status.configured, isFalse);
    expect(status.platform, 'web');
    expect(status.failure, MapsConfigurationFailure.missingOrInvalidKey);
  });
}
