enum MapsConfigurationFailure {
  missingOrInvalidKey,
  platformBridgeUnavailable,
  javascriptLoadFailed,
  unsupportedPlatform,
}

class MapsConfigurationStatus {
  const MapsConfigurationStatus._({
    required this.configured,
    required this.platform,
    this.failure,
  });

  const MapsConfigurationStatus.ready(String platform)
    : this._(configured: true, platform: platform);

  const MapsConfigurationStatus.unavailable(
    String platform,
    MapsConfigurationFailure failure,
  ) : this._(configured: false, platform: platform, failure: failure);

  final bool configured;
  final String platform;
  final MapsConfigurationFailure? failure;
}

bool isConfiguredGoogleMapsApiKey(String value) {
  final normalized = value.trim();
  return normalized.startsWith('AIza') &&
      normalized.length >= 30 &&
      !normalized.contains(r'$(') &&
      !normalized.contains('%') &&
      !normalized.contains('REPLACE_WITH');
}
