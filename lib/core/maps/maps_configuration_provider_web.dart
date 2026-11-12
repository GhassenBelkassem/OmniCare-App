import 'maps_configuration_status.dart';
import 'maps_javascript_loader.dart';

const _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_WEB_API_KEY');

Future<MapsConfigurationStatus> loadMapsConfiguration() =>
    loadMapsConfigurationForWeb(_mapsApiKey, loadGoogleMapsJavaScript);

typedef GoogleMapsJavaScriptLoader = Future<bool> Function(String apiKey);

Future<MapsConfigurationStatus> loadMapsConfigurationForWeb(
  String apiKey,
  GoogleMapsJavaScriptLoader loader,
) async {
  if (!isConfiguredGoogleMapsApiKey(apiKey)) {
    return const MapsConfigurationStatus.unavailable(
      'web',
      MapsConfigurationFailure.missingOrInvalidKey,
    );
  }

  final loaded = await loader(apiKey);
  return loaded
      ? const MapsConfigurationStatus.ready('web')
      : const MapsConfigurationStatus.unavailable(
          'web',
          MapsConfigurationFailure.javascriptLoadFailed,
        );
}
