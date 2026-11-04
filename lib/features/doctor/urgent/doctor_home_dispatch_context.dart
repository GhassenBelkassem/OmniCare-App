import 'package:flutter/foundation.dart';

enum DoctorHomeDestinationAcquisitionMode {
  currentGps,
  addressSearch,
  mapPin,
  manualAddress;

  static DoctorHomeDestinationAcquisitionMode parse(String value) =>
      switch (value) {
        'CURRENT_GPS' => DoctorHomeDestinationAcquisitionMode.currentGps,
        'ADDRESS_SEARCH' => DoctorHomeDestinationAcquisitionMode.addressSearch,
        'MAP_PIN' => DoctorHomeDestinationAcquisitionMode.mapPin,
        'MANUAL_ADDRESS' => DoctorHomeDestinationAcquisitionMode.manualAddress,
        _ => throw const FormatException(
          'Unknown HOME destination acquisition mode.',
        ),
      };
}

enum DoctorHomeDestinationProvenance {
  deviceGps,
  addressResult,
  patientMovedPin,
  manualEntry;

  static DoctorHomeDestinationProvenance parse(String value) => switch (value) {
    'DEVICE_GPS' => DoctorHomeDestinationProvenance.deviceGps,
    'ADDRESS_RESULT' => DoctorHomeDestinationProvenance.addressResult,
    'PATIENT_MOVED_PIN' => DoctorHomeDestinationProvenance.patientMovedPin,
    'MANUAL_ENTRY' => DoctorHomeDestinationProvenance.manualEntry,
    _ => throw const FormatException('Unknown HOME destination provenance.'),
  };
}

@immutable
class DoctorHomeDispatchDestination {
  const DoctorHomeDispatchDestination({
    required this.latitude,
    required this.longitude,
    required this.confirmedAddress,
    required this.acquisitionMode,
    required this.provenance,
    required this.confirmedAt,
  });

  final double latitude;
  final double longitude;
  final String confirmedAddress;
  final DoctorHomeDestinationAcquisitionMode acquisitionMode;
  final DoctorHomeDestinationProvenance provenance;
  final DateTime confirmedAt;
}

@immutable
class DoctorHomeDispatchContext {
  const DoctorHomeDispatchContext({
    required this.commitmentId,
    required this.commitmentRevision,
    required this.evaluatedAt,
    required this.destination,
  });

  final String commitmentId;
  final int commitmentRevision;
  final DateTime evaluatedAt;
  final DoctorHomeDispatchDestination destination;
}

DoctorHomeDispatchContext parseDoctorHomeDispatchContext(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected a HOME dispatch-context object.');
  }
  final json = value.cast<Object?, Object?>();
  final revision = json['commitmentRevision'];
  if (revision is! int || revision < 0) {
    throw const FormatException('Invalid HOME commitment revision.');
  }
  final rawDestination = json['destination'];
  if (rawDestination is! Map) {
    throw const FormatException('Missing HOME dispatch destination.');
  }
  final destination = rawDestination.cast<Object?, Object?>();
  final acquisitionMode = DoctorHomeDestinationAcquisitionMode.parse(
    _requiredString(destination, 'acquisitionMode'),
  );
  final provenance = DoctorHomeDestinationProvenance.parse(
    _requiredString(destination, 'provenance'),
  );
  if (!_isSupportedPair(acquisitionMode, provenance)) {
    throw const FormatException('Invalid HOME destination source pairing.');
  }

  return DoctorHomeDispatchContext(
    commitmentId: _requiredUuid(json, 'commitmentId'),
    commitmentRevision: revision,
    evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
    destination: DoctorHomeDispatchDestination(
      latitude: _coordinate(destination, 'latitude', min: -90, max: 90),
      longitude: _coordinate(destination, 'longitude', min: -180, max: 180),
      confirmedAddress: _confirmedAddress(destination),
      acquisitionMode: acquisitionMode,
      provenance: provenance,
      confirmedAt: _requiredDateTime(destination, 'confirmedAt'),
    ),
  );
}

bool _isSupportedPair(
  DoctorHomeDestinationAcquisitionMode mode,
  DoctorHomeDestinationProvenance provenance,
) => switch (mode) {
  DoctorHomeDestinationAcquisitionMode.currentGps =>
    provenance == DoctorHomeDestinationProvenance.deviceGps,
  DoctorHomeDestinationAcquisitionMode.addressSearch =>
    provenance == DoctorHomeDestinationProvenance.addressResult,
  DoctorHomeDestinationAcquisitionMode.mapPin =>
    provenance == DoctorHomeDestinationProvenance.patientMovedPin,
  DoctorHomeDestinationAcquisitionMode.manualAddress =>
    provenance == DoctorHomeDestinationProvenance.manualEntry,
};

String _requiredUuid(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  if (!_uuidPattern.hasMatch(value)) throw FormatException('Invalid $field.');
  return value;
}

String _requiredString(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $field.');
  }
  return value;
}

DateTime _requiredDateTime(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) throw FormatException('Invalid $field.');
  return parsed;
}

double _coordinate(
  Map<Object?, Object?> json,
  String field, {
  required double min,
  required double max,
}) {
  final value = json[field];
  if (value is! num || !value.isFinite) {
    throw FormatException('Invalid $field.');
  }
  final coordinate = value.toDouble();
  if (coordinate < min || coordinate > max) {
    throw FormatException('Invalid $field.');
  }
  return coordinate;
}

String _confirmedAddress(Map<Object?, Object?> json) {
  final value = _requiredString(json, 'confirmedAddress');
  if (value != value.trim() || value.length > 300) {
    throw const FormatException('Invalid confirmedAddress.');
  }
  return value;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
