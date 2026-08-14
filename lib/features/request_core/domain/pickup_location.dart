import 'request_vocabulary.dart';

/// A confirmed operational pickup location for an AMBULANCE request only.
///
/// Mirrors the backend `PickupLocationSelection` record. Three things make it
/// safe by construction:
///
/// * [source] names exactly how the patient confirmed the location.
/// * `DEVICE_GPS` and `MAP_SELECTION` carry a [geoPoint]; `MANUAL_ADDRESS`
///   carries a [postalAddress] instead. The app enforces that invariant, so a
///   manual address can never leak coordinates onto the wire.
/// * [capturedAt] is the one moment the location was confirmed; it is frozen on
///   the first submission attempt and reused verbatim on every retry, so a
///   retry can never reacquire GPS or drift the coordinates.
///
/// None of these values are ever rendered: [toString] is redacted, and the
/// serialized body lives only in the request layer.
class PickupLocationSelection {
  PickupLocationSelection({
    required this.source,
    this.geoPoint,
    this.postalAddress,
    required this.capturedAt,
  }) {
    final hasGeoSource =
        source == PickupLocationSource.deviceGps ||
        source == PickupLocationSource.mapSelection;
    if (hasGeoSource && geoPoint == null ||
        source == PickupLocationSource.manualAddress && postalAddress == null ||
        source == PickupLocationSource.manualAddress && geoPoint != null ||
        source == PickupLocationSource.unknown) {
      throw const RequestContractException('Invalid pickup location shape.');
    }
  }

  final PickupLocationSource source;
  final GeoPoint? geoPoint;
  final PostalAddress? postalAddress;
  final DateTime capturedAt;

  /// True when this selection carries the coordinates its [source] requires.
  bool get hasCoordinates =>
      source == PickupLocationSource.deviceGps ||
      source == PickupLocationSource.mapSelection;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source.wireValue,
      if (geoPoint != null) 'geoPoint': geoPoint!.toJson(),
      if (postalAddress != null) 'postalAddress': postalAddress!.toJson(),
      'capturedAt': capturedAt.toUtc().toIso8601String(),
    };
  }

  factory PickupLocationSelection.fromJson(Map<String, dynamic> json) {
    final source = PickupLocationSource.parse(_optionalString(json['source']));
    final geo = json['geoPoint'];
    final postal = json['postalAddress'];
    return PickupLocationSelection(
      source: source,
      geoPoint: geo is Map
          ? GeoPoint.fromJson(geo.cast<String, dynamic>())
          : null,
      postalAddress: postal is Map
          ? PostalAddress.fromJson(postal.cast<String, dynamic>())
          : null,
      capturedAt: _requiredInstant(json, 'capturedAt'),
    );
  }

  @override
  String toString() => 'PickupLocationSelection[${source.wireValue}]';

  @override
  bool operator ==(Object other) =>
      other is PickupLocationSelection &&
      other.source == source &&
      other.geoPoint == geoPoint &&
      other.postalAddress == postalAddress &&
      other.capturedAt == capturedAt;

  @override
  int get hashCode => Object.hash(source, geoPoint, postalAddress, capturedAt);
}

/// Operational coordinates for a `DEVICE_GPS` or `MAP_SELECTION` pickup.
///
/// Serialized as plain JSON numbers, matching the backend `GeoPoint` contract.
/// [accuracyMeters] is optional and only sent when the backend source accepts
/// it.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// Normalizes device/map values to the backend's exact decimal precision.
  factory GeoPoint.fromCapturedCoordinates({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const RequestContractException('Pickup coordinates are invalid.');
    }
    return GeoPoint(
      latitude: _round(latitude, 6),
      longitude: _round(longitude, 6),
      accuracyMeters: accuracyMeters == null || !accuracyMeters.isFinite
          ? null
          : _round(accuracyMeters.clamp(0, 10000), 2),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    };
  }

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      accuracyMeters: _optionalDouble(json['accuracyMeters']),
    );
  }

  @override
  String toString() => 'GeoPoint[redacted]';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);
}

/// A manual pickup address. Carries no coordinates by design.
class PostalAddress {
  const PostalAddress({
    required this.addressLine,
    this.addressDetails,
    required this.city,
    this.governorate,
  });

  final String addressLine;
  final String? addressDetails;
  final String city;
  final String? governorate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'addressLine': addressLine,
      if (addressDetails != null) 'addressDetails': addressDetails,
      'city': city,
      if (governorate != null) 'governorate': governorate,
    };
  }

  factory PostalAddress.fromJson(Map<String, dynamic> json) {
    return PostalAddress(
      addressLine: _requiredString(json, 'addressLine'),
      addressDetails: _optionalString(json['addressDetails']),
      city: _requiredString(json, 'city'),
      governorate: _optionalString(json['governorate']),
    );
  }

  @override
  String toString() => 'PostalAddress[redacted]';

  @override
  bool operator ==(Object other) =>
      other is PostalAddress &&
      other.addressLine == addressLine &&
      other.addressDetails == addressDetails &&
      other.city == city &&
      other.governorate == governorate;

  @override
  int get hashCode =>
      Object.hash(addressLine, addressDetails, city, governorate);
}

double _round(num value, int precision) {
  final factor = precision == 6 ? 1000000 : 100;
  return (value * factor).roundToDouble() / factor;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw RequestContractException('Missing required field "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw RequestContractException('Missing required numeric field "$key".');
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return null;
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const RequestContractException('Timestamp is not ISO-8601.');
  }
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) {
    throw const RequestContractException('Timestamp is not ISO-8601.');
  }
  return parsed.toUtc();
}
