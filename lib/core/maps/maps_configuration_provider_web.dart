import 'maps_configuration_status.dart';
import 'maps_javascript_loader.dart';

const _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

Future<MapsConfigurationStatus> loadMapsConfiguration() async {
  if (!isConfiguredGoogleMapsApiKey(_mapsApiKey)) {
    return const MapsConfigurationStatus.unavailable(
      'web',
      MapsConfigurationFailure.missingOrInvalidKey,
    );
  }

  final loaded = await loadGoogleMapsJavaScript(_mapsApiKey);
  return loaded
      ? const MapsConfigurationStatus.ready('web')
      : const MapsConfigurationStatus.unavailable(
          'web',
          MapsConfigurationFailure.javascriptLoadFailed,
        );
}
