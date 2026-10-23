import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Static, local coordinates used exclusively by the Doctor Urgences demo.
/// They are not device or patient live-location data.
abstract final class DoctorUrgentMapDemo {
  static const doctorOrigin = LatLng(36.8152, 10.1643);
  static const patientDestination = LatLng(36.8065, 10.1815);

  static const route = <LatLng>[
    doctorOrigin,
    LatLng(36.8128, 10.1693),
    LatLng(36.8099, 10.1752),
    patientDestination,
  ];

  static Uri directionsUri() => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination':
        '${patientDestination.latitude},${patientDestination.longitude}',
    'travelmode': 'driving',
  });

  static Future<bool> openExternalDirections() =>
      launchUrl(directionsUri(), mode: LaunchMode.externalApplication);
}
