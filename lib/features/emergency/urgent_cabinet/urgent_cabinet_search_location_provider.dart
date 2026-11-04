import 'package:geolocator/geolocator.dart';

import 'urgent_cabinet_discovery_models.dart';

/// A CABINET-discovery-only location boundary.
///
/// Passive discovery never requests permission. A request is made only after
/// the Patient explicitly chooses a distance-dependent filter or sort, keeping
/// all non-distance discovery usable without GPS and without reusing HOME GPS.
abstract interface class UrgentCabinetSearchLocationProvider {
  Future<UrgentCabinetSearchPosition?> currentPositionIfAuthorized();

  Future<UrgentCabinetSearchPosition?> requestCurrentPosition();
}

class GeolocatorUrgentCabinetSearchLocationProvider
    implements UrgentCabinetSearchLocationProvider {
  const GeolocatorUrgentCabinetSearchLocationProvider();

  @override
  Future<UrgentCabinetSearchPosition?> currentPositionIfAuthorized() =>
      _currentPosition(requestPermission: false);

  @override
  Future<UrgentCabinetSearchPosition?> requestCurrentPosition() =>
      _currentPosition(requestPermission: true);

  Future<UrgentCabinetSearchPosition?> _currentPosition({
    required bool requestPermission,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      final result = UrgentCabinetSearchPosition(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return result.isValid ? result : null;
    } catch (_) {
      return null;
    }
  }
}
