/// Strictly parsed models for the real patient doctor directory.
///
/// Verified field-by-field against the backend contract documented in
/// `OmniCare_Module_Doctor_Directory_v1.0.md`:
///
/// - `GET /api/v1/doctors` → [DoctorDirectoryListItem] (11 fields).
/// - `GET /api/v1/doctors/{id}` → [DoctorDirectoryDetail] (22 fields).
/// - `GET /api/v1/appointments/availability/slots` → [AvailabilitySlotDto].
/// - `POST /api/v1/appointments` → [AppointmentBooking] (AppointmentResponse).
///
/// No field is invented: absent data stays `null` / empty list, exactly like
/// the backend payload.
library;

/// One doctor row in the patient directory list.
class DoctorDirectoryListItem {
  const DoctorDirectoryListItem({
    required this.doctorId,
    required this.displayName,
    this.specialty,
    this.photoUrl,
    this.affiliatedClinicId,
    this.availableForUrgent = false,
    this.consultationPriceTnd,
    this.phoneNumber,
    this.isActive = true,
    this.experienceYears,
    this.distanceKm,
  });

  final String doctorId;
  final String displayName;
  final String? specialty;
  final String? photoUrl;
  final String? affiliatedClinicId;
  final bool availableForUrgent;
  final double? consultationPriceTnd;
  final String? phoneNumber;
  final bool isActive;
  final int? experienceYears;
  final double? distanceKm;

  factory DoctorDirectoryListItem.fromJson(Map<String, dynamic> json) {
    return DoctorDirectoryListItem(
      doctorId: _requiredString(json, 'doctorId'),
      displayName: _requiredString(json, 'displayName'),
      specialty: _optionalString(json['specialty']),
      photoUrl: _optionalString(json['photoUrl']),
      affiliatedClinicId: _optionalString(json['affiliatedClinicId']),
      availableForUrgent: _requiredBool(json, 'availableForUrgent'),
      consultationPriceTnd: _optionalDouble(json['consultationPriceTnd']),
      phoneNumber: _optionalString(json['phoneNumber']),
      isActive: _requiredBool(json, 'isActive'),
      experienceYears: _optionalInt(json['experienceYears']),
      distanceKm: _optionalDouble(json['distanceKm']),
    );
  }

  /// Renders neither the identifier nor the name.
  @override
  String toString() => 'DoctorDirectoryListItem(<redacted>)';
}

/// Full doctor detail, a strict superset of the list entry.
class DoctorDirectoryDetail {
  const DoctorDirectoryDetail({
    required this.doctorId,
    required this.displayName,
    this.specialty,
    this.photoUrl,
    this.affiliatedClinicId,
    this.availableForUrgent = false,
    this.consultationPriceTnd,
    this.phoneNumber,
    this.isActive = true,
    this.experienceYears,
    this.distanceKm,
    this.verified = false,
    this.subSpecialties = const [],
    this.practiceCity,
    this.languages = const [],
    this.acceptingNewPatients = true,
    this.areasOfCare = const [],
    this.expertise = const [],
    this.visitReasons = const [],
    this.patientAgeGroups = const [],
    this.consultationTypes = const [],
    this.biography,
  });

  final String doctorId;
  final String displayName;
  final String? specialty;
  final String? photoUrl;
  final String? affiliatedClinicId;
  final bool availableForUrgent;
  final double? consultationPriceTnd;
  final String? phoneNumber;
  final bool isActive;
  final int? experienceYears;
  final double? distanceKm;
  final bool verified;
  final List<String> subSpecialties;
  final String? practiceCity;
  final List<String> languages;
  final bool acceptingNewPatients;
  final List<String> areasOfCare;
  final List<String> expertise;
  final List<String> visitReasons;
  final List<String> patientAgeGroups;
  final List<String> consultationTypes;
  final String? biography;

  factory DoctorDirectoryDetail.fromJson(Map<String, dynamic> json) {
    return DoctorDirectoryDetail(
      doctorId: _requiredString(json, 'doctorId'),
      displayName: _requiredString(json, 'displayName'),
      specialty: _optionalString(json['specialty']),
      photoUrl: _optionalString(json['photoUrl']),
      affiliatedClinicId: _optionalString(json['affiliatedClinicId']),
      availableForUrgent: _requiredBool(json, 'availableForUrgent'),
      consultationPriceTnd: _optionalDouble(json['consultationPriceTnd']),
      phoneNumber: _optionalString(json['phoneNumber']),
      isActive: _requiredBool(json, 'isActive'),
      experienceYears: _optionalInt(json['experienceYears']),
      distanceKm: _optionalDouble(json['distanceKm']),
      verified: _requiredBool(json, 'verified'),
      subSpecialties: _optionalStringList(json['subSpecialties']),
      practiceCity: _optionalString(json['practiceCity']),
      languages: _optionalStringList(json['languages']),
      acceptingNewPatients: json['acceptingNewPatients'] is bool
          ? json['acceptingNewPatients'] as bool
          : true,
      areasOfCare: _optionalStringList(json['areasOfCare']),
      expertise: _optionalStringList(json['expertise']),
      visitReasons: _optionalStringList(json['visitReasons']),
      patientAgeGroups: _optionalStringList(json['patientAgeGroups']),
      consultationTypes: _optionalStringList(json['consultationTypes']),
      biography: _optionalString(json['biography']),
    );
  }

  /// Renders neither the identifier nor the name.
  @override
  String toString() => 'DoctorDirectoryDetail(<redacted>)';
}

/// A single computable open window (GET availability slots).
///
/// Patients book by matching the `POST /api/v1/appointments` body exactly
/// against one of these `start`/`end` values.
class AvailabilitySlotDto {
  const AvailabilitySlotDto({required this.start, required this.end});

  /// ISO 8601 instant, e.g. `2026-09-24T09:00:00Z`.
  final String start;

  /// ISO 8601 instant, e.g. `2026-09-24T09:30:00Z`.
  final String end;

  factory AvailabilitySlotDto.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotDto(
      start: _requiredString(json, 'start'),
      end: _requiredString(json, 'end'),
    );
  }

  @override
  String toString() => 'AvailabilitySlotDto($start -> $end)';
}

/// The patient-facing appointment confirmation returned by the booking write.
class AppointmentBooking {
  const AppointmentBooking({
    required this.id,
    required this.doctorId,
    required this.patientId,
    this.patientName,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.source,
    this.notes,
    this.quotedPriceTnd,
    this.startedAt,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String? patientName;
  final String startTime;
  final String endTime;
  final String status;
  final String source;
  final String? notes;
  final double? quotedPriceTnd;
  final String? startedAt;
  final String? completedAt;
  final String? createdAt;

  factory AppointmentBooking.fromJson(Map<String, dynamic> json) {
    return AppointmentBooking(
      id: _requiredString(json, 'id'),
      doctorId: _requiredString(json, 'doctorId'),
      patientId: _requiredString(json, 'patientId'),
      patientName: _optionalString(json['patientName']),
      startTime: _requiredString(json, 'startTime'),
      endTime: _requiredString(json, 'endTime'),
      status: _requiredString(json, 'status'),
      source: _requiredString(json, 'source'),
      notes: _optionalString(json['notes']),
      quotedPriceTnd: _optionalDouble(json['quotedPriceTnd']),
      startedAt: _optionalString(json['startedAt']),
      completedAt: _optionalString(json['completedAt']),
      createdAt: _optionalString(json['createdAt']),
    );
  }

  /// Renders neither the id nor the patient identity.
  @override
  String toString() => 'AppointmentBooking(<redacted>)';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw DoctorContractException('Missing required field "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return null;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw DoctorContractException('Missing required boolean field "$key".');
}

List<String> _optionalStringList(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return List.unmodifiable(
      value.map((element) {
        if (element is String && element.trim().isNotEmpty) {
          return element.trim();
        }
        throw const DoctorContractException(
          'String list contains a non-string element.',
        );
      }),
    );
  }
  throw const DoctorContractException('Expected a string array.');
}

/// Thrown when a doctor directory payload cannot be trusted.
class DoctorContractException implements Exception {
  const DoctorContractException(this.reason);

  final String reason;

  @override
  String toString() => 'DoctorContractException: $reason';
}