import 'maps_configuration_status.dart';

Future<MapsConfigurationStatus> loadMapsConfiguration() async =>
    const MapsConfigurationStatus.unavailable(
      'unsupported',
      MapsConfigurationFailure.unsupportedPlatform,
    );
