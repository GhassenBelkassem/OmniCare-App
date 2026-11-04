import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'maps_configuration_status.dart';

const _channel = MethodChannel('omnicare/maps_configuration');

Future<MapsConfigurationStatus> loadMapsConfiguration() async {
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'unsupported',
  };
  if (platform == 'unsupported') {
    return const MapsConfigurationStatus.unavailable(
      'unsupported',
      MapsConfigurationFailure.unsupportedPlatform,
    );
  }

  try {
    final result = await _channel.invokeMapMethod<String, Object?>('status');
    if (result?['configured'] == true && result?['platform'] == platform) {
      return MapsConfigurationStatus.ready(platform);
    }
    return MapsConfigurationStatus.unavailable(
      platform,
      MapsConfigurationFailure.missingOrInvalidKey,
    );
  } on MissingPluginException {
    return MapsConfigurationStatus.unavailable(
      platform,
      MapsConfigurationFailure.platformBridgeUnavailable,
    );
  } on PlatformException {
    return MapsConfigurationStatus.unavailable(
      platform,
      MapsConfigurationFailure.platformBridgeUnavailable,
    );
  }
}
