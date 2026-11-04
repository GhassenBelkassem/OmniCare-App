import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum DoctorForegroundLocationPermission {
  denied,
  deniedForever,
  granted,
  unavailable,
}

@immutable
class DoctorDeviceLocationObservation {
  const DoctorDeviceLocationObservation({
    required this.latitude,
    required this.longitude,
    required this.horizontalAccuracyMeters,
    required this.observedAt,
    required this.isSimulated,
  });

  final double latitude;
  final double longitude;
  final double horizontalAccuracyMeters;
  final DateTime observedAt;
  final bool isSimulated;
}

abstract interface class DoctorHomeLocationProvider {
  bool get isSupported;

  Future<bool> isServiceEnabled();

  Future<DoctorForegroundLocationPermission> checkPermission();

  Future<DoctorForegroundLocationPermission> requestForegroundPermission();

  Future<DoctorDeviceLocationObservation> currentObservation();
}

/// Foreground-only native GPS boundary for Doctor HOME operational presence.
///
/// Web is deliberately unsupported in this milestone: browser permission
/// introspection is not reliable across supported browsers and the operational
/// presence contract is certified only for Android and iOS foreground use.
class GeolocatorDoctorHomeLocationProvider
    implements DoctorHomeLocationProvider {
  const GeolocatorDoctorHomeLocationProvider();

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<DoctorForegroundLocationPermission> checkPermission() async =>
      _permission(await Geolocator.checkPermission());

  @override
  Future<DoctorForegroundLocationPermission>
  requestForegroundPermission() async =>
      _permission(await Geolocator.requestPermission());

  @override
  Future<DoctorDeviceLocationObservation> currentObservation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
    return DoctorDeviceLocationObservation(
      latitude: position.latitude,
      longitude: position.longitude,
      horizontalAccuracyMeters: position.accuracy,
      observedAt: position.timestamp.toUtc(),
      isSimulated: position.isMocked,
    );
  }

  static DoctorForegroundLocationPermission _permission(
    LocationPermission value,
  ) => switch (value) {
    LocationPermission.whileInUse ||
    LocationPermission.always => DoctorForegroundLocationPermission.granted,
    LocationPermission.denied => DoctorForegroundLocationPermission.denied,
    LocationPermission.deniedForever =>
      DoctorForegroundLocationPermission.deniedForever,
    LocationPermission.unableToDetermine =>
      DoctorForegroundLocationPermission.unavailable,
  };
}
