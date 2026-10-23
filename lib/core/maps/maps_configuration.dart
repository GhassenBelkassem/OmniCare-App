import 'maps_configuration_provider_stub.dart'
    if (dart.library.io) 'maps_configuration_provider_native.dart'
    if (dart.library.js_interop) 'maps_configuration_provider_web.dart'
    as provider;
import 'maps_configuration_status.dart';

export 'maps_configuration_status.dart';

Future<MapsConfigurationStatus> loadMapsConfiguration() =>
    provider.loadMapsConfiguration();
