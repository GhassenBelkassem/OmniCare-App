/// Strictly parsed models for the real patient doctor directory.
///
/// Verified field-by-field against the P1-06 backend controller, DTOs, and
/// `docs/p1-doctor-directory-search.md`:
///
/// - `GET /api/v1/doctors/search` → [DoctorSearchPage].
/// - `GET /api/v1/doctors/{id}` → [DoctorDirectoryDetail].
/// - `GET /api/v1/appointments/availability/slots` → [AvailabilitySlotDto].
///
/// No field is invented: absent data stays `null` / empty list, exactly like
/// the backend payload.
library;

enum DoctorCareCapability {
  cabinet('CABINET'),
  homeVisit('HOME_VISIT'),
  urgentHome('URGENT_HOME'),
  urgentCabinet('URGENT_CABINET');

  const DoctorCareCapability(this.wireValue);

  final String wireValue;

  static DoctorCareCapability parse(Object? value) {
    for (final capability in values) {
      if (value == capability.wireValue) return capability;
    }
    throw const DoctorContractException('Unknown care capability.');
  }
}

enum DoctorCoverageAcceptance {
  notDeclared('NOT_DECLARED'),
  accepted('ACCEPTED'),
  notAccepted('NOT_ACCEPTED');

  const DoctorCoverageAcceptance(this.wireValue);

  final String wireValue;

  static DoctorCoverageAcceptance parse(Object? value) {
    for (final acceptance in values) {
      if (value == acceptance.wireValue) return acceptance;
    }
    throw const DoctorContractException('Unknown coverage acceptance.');
  }
}

enum DoctorPracticeLocationType {
  cabinet('CABINET');

  const DoctorPracticeLocationType(this.wireValue);

  final String wireValue;

  static DoctorPracticeLocationType parse(Object? value) {
    for (final type in values) {
      if (value == type.wireValue) return type;
    }
    throw const DoctorContractException('Unknown practice location type.');
  }
}

enum DoctorCoverageProvenance {
  declared('DECLARED');

  const DoctorCoverageProvenance(this.wireValue);

  final String wireValue;

  static DoctorCoverageProvenance? parseNullable(Object? value) {
    if (value == null) return null;
    for (final provenance in values) {
      if (value == provenance.wireValue) return provenance;
    }
    throw const DoctorContractException('Unknown coverage provenance.');
  }
}

class DoctorSearchLocation {
  const DoctorSearchLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Immutable query for the production Doctor search endpoint.
class DoctorSearchCriteria {
  const DoctorSearchCriteria({
    this.query,
    this.specialty,
    this.governorate,
    this.city,
    this.location,
    this.maxDistanceKm,
    this.careCapability,
    this.cnamAcceptance,
    this.privateInsuranceAcceptance,
    this.selfPayAcceptance,
    this.acceptingNewPatients,
    this.page = 0,
    this.size = 20,
  });

  final String? query;
  final String? specialty;
  final String? governorate;
  final String? city;
  final DoctorSearchLocation? location;
  final double? maxDistanceKm;
  final DoctorCareCapability? careCapability;
  final DoctorCoverageAcceptance? cnamAcceptance;
  final DoctorCoverageAcceptance? privateInsuranceAcceptance;
  final DoctorCoverageAcceptance? selfPayAcceptance;
  final bool? acceptingNewPatients;
  final int page;
  final int size;

  Map<String, dynamic> toQueryParameters() {
    String? normalized(String? value) {
      final result = value?.trim();
      return result == null || result.isEmpty ? null : result;
    }

    final parameters = <String, dynamic>{
      if (location case final value?) ...{
        'lat': value.latitude,
        'lng': value.longitude,
      },
      if (careCapability case final value?) 'careCapability': value.wireValue,
      if (cnamAcceptance case final value?) 'cnamAcceptance': value.wireValue,
      if (privateInsuranceAcceptance case final value?)
        'privateInsuranceAcceptance': value.wireValue,
      if (selfPayAcceptance case final value?)
        'selfPayAcceptance': value.wireValue,
      'page': page,
      'size': size,
    };
    void putIfPresent(String key, Object? value) {
      if (value != null) parameters[key] = value;
    }

    putIfPresent('q', normalized(query));
    putIfPresent('specialty', normalized(specialty));
    putIfPresent('governorate', normalized(governorate));
    putIfPresent('city', normalized(city));
    putIfPresent('maxDistanceKm', maxDistanceKm);
    putIfPresent('acceptingNewPatients', acceptingNewPatients);
    return parameters;
  }
}

class DoctorMatchingPracticeLocation {
  const DoctorMatchingPracticeLocation({
    required this.practiceLocationId,
    required this.name,
    this.city,
    this.governorate,
    this.distanceKm,
  });

  final String practiceLocationId;
  final String name;
  final String? city;
  final String? governorate;
  final double? distanceKm;

  factory DoctorMatchingPracticeLocation.fromJson(Map<String, dynamic> json) {
    return DoctorMatchingPracticeLocation(
      practiceLocationId: _requiredString(json, 'practiceLocationId'),
      name: _requiredString(json, 'name'),
      city: _optionalString(json['city']),
      governorate: _optionalString(json['governorate']),
      distanceKm: _optionalDouble(json['distanceKm']),
    );
  }
}

class DoctorSearchCard {
  const DoctorSearchCard({
    required this.doctorId,
    required this.displayName,
    this.photoUrl,
    this.specialty,
    this.experienceYears,
    this.consultationPriceTnd,
    required this.verified,
    required this.acceptingNewPatients,
    this.careCapabilities = const [],
    this.distanceKm,
    this.matchingPracticeLocation,
  });

  final String doctorId;
  final String displayName;
  final String? photoUrl;
  final String? specialty;
  final int? experienceYears;
  final double? consultationPriceTnd;
  final bool verified;
  final bool acceptingNewPatients;
  final List<DoctorCareCapability> careCapabilities;
  final double? distanceKm;
  final DoctorMatchingPracticeLocation? matchingPracticeLocation;

  factory DoctorSearchCard.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['careCapabilities'];
    if (rawCapabilities is! List) {
      throw const DoctorContractException(
        'Missing required careCapabilities array.',
      );
    }
    final rawLocation = json['matchingPracticeLocation'];
    if (rawLocation != null && rawLocation is! Map) {
      throw const DoctorContractException(
        'Matching practice location is malformed.',
      );
    }
    return DoctorSearchCard(
      doctorId: _requiredString(json, 'doctorId'),
      displayName: _requiredString(json, 'displayName'),
      photoUrl: _optionalString(json['photoUrl']),
      specialty: _optionalString(json['specialty']),
      experienceYears: _optionalInt(json['experienceYears']),
      consultationPriceTnd: _optionalDouble(json['consultationPriceTnd']),
      verified: _requiredBool(json, 'verified'),
      acceptingNewPatients: _requiredBool(json, 'acceptingNewPatients'),
      careCapabilities: List.unmodifiable(
        rawCapabilities.map(DoctorCareCapability.parse),
      ),
      distanceKm: _optionalDouble(json['distanceKm']),
      matchingPracticeLocation: rawLocation == null
          ? null
          : DoctorMatchingPracticeLocation.fromJson(
              rawLocation.cast<String, dynamic>(),
            ),
    );
  }

  @override
  String toString() => 'DoctorSearchCard(<redacted>)';
}

class DoctorSearchPage {
  const DoctorSearchPage({
    required this.content,
    required this.page,
    required this.size,
    required this.hasNext,
  });

  final List<DoctorSearchCard> content;
  final int page;
  final int size;
  final bool hasNext;

  factory DoctorSearchPage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    if (rawContent is! List) {
      throw const DoctorContractException('Expected a content array.');
    }
    final page = json['page'];
    final size = json['size'];
    if (page is! int || size is! int) {
      throw const DoctorContractException('Invalid search page metadata.');
    }
    return DoctorSearchPage(
      content: List.unmodifiable(
        rawContent.map((item) {
          if (item is! Map) {
            throw const DoctorContractException(
              'Doctor search entry is malformed.',
            );
          }
          return DoctorSearchCard.fromJson(item.cast<String, dynamic>());
        }),
      ),
      page: page,
      size: size,
      hasNext: _requiredBool(json, 'hasNext'),
    );
  }
}

class DoctorEducation {
  const DoctorEducation({
    required this.id,
    required this.institution,
    required this.qualification,
    this.fieldOfStudy,
    this.completionYear,
    required this.displayOrder,
  });

  final String id;
  final String institution;
  final String qualification;
  final String? fieldOfStudy;
  final int? completionYear;
  final int displayOrder;

  factory DoctorEducation.fromJson(Map<String, dynamic> json) {
    return DoctorEducation(
      id: _requiredString(json, 'id'),
      institution: _requiredString(json, 'institution'),
      qualification: _requiredString(json, 'qualification'),
      fieldOfStudy: _optionalString(json['fieldOfStudy']),
      completionYear: _optionalInt(json['completionYear']),
      displayOrder: _requiredInt(json, 'displayOrder'),
    );
  }
}

class DoctorCertification {
  const DoctorCertification({
    required this.id,
    required this.name,
    this.issuer,
    this.issuedYear,
    this.expiryDate,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final String? issuer;
  final int? issuedYear;
  final DateTime? expiryDate;
  final int displayOrder;

  factory DoctorCertification.fromJson(Map<String, dynamic> json) {
    return DoctorCertification(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      issuer: _optionalString(json['issuer']),
      issuedYear: _optionalInt(json['issuedYear']),
      expiryDate: _optionalDate(json['expiryDate']),
      displayOrder: _requiredInt(json, 'displayOrder'),
    );
  }
}

class DoctorPracticeMedia {
  const DoctorPracticeMedia({required this.url, required this.displayOrder});

  final String url;
  final int displayOrder;

  factory DoctorPracticeMedia.fromJson(Map<String, dynamic> json) {
    return DoctorPracticeMedia(
      url: _requiredString(json, 'url'),
      displayOrder: _requiredInt(json, 'displayOrder'),
    );
  }
}

class DoctorEquipment {
  const DoctorEquipment({
    required this.code,
    required this.displayName,
    required this.portable,
  });

  final String code;
  final String displayName;
  final bool portable;

  factory DoctorEquipment.fromJson(Map<String, dynamic> json) {
    return DoctorEquipment(
      code: _requiredString(json, 'code'),
      displayName: _requiredString(json, 'displayName'),
      portable: _requiredBool(json, 'portable'),
    );
  }
}

class DoctorCoverageClaim {
  const DoctorCoverageClaim({
    required this.acceptance,
    this.provenance,
    required this.verified,
  });

  final DoctorCoverageAcceptance acceptance;
  final DoctorCoverageProvenance? provenance;
  final bool verified;

  factory DoctorCoverageClaim.fromJson(Map<String, dynamic> json) {
    return DoctorCoverageClaim(
      acceptance: DoctorCoverageAcceptance.parse(json['acceptance']),
      provenance: DoctorCoverageProvenance.parseNullable(json['provenance']),
      verified: _requiredBool(json, 'verified'),
    );
  }
}

class DoctorPracticeCoverage {
  const DoctorPracticeCoverage({
    required this.selfPay,
    required this.cnam,
    required this.privateInsurance,
    required this.specificPrivateInsurerDetailsAvailable,
  });

  final DoctorCoverageClaim selfPay;
  final DoctorCoverageClaim cnam;
  final DoctorCoverageClaim privateInsurance;
  final bool specificPrivateInsurerDetailsAvailable;

  factory DoctorPracticeCoverage.fromJson(Map<String, dynamic> json) {
    return DoctorPracticeCoverage(
      selfPay: DoctorCoverageClaim.fromJson(_requiredMap(json, 'selfPay')),
      cnam: DoctorCoverageClaim.fromJson(_requiredMap(json, 'cnam')),
      privateInsurance: DoctorCoverageClaim.fromJson(
        _requiredMap(json, 'privateInsurance'),
      ),
      specificPrivateInsurerDetailsAvailable: _requiredBool(
        json,
        'specificPrivateInsurerDetailsAvailable',
      ),
    );
  }
}

class DoctorPracticeLocation {
  const DoctorPracticeLocation({
    required this.id,
    required this.type,
    required this.name,
    required this.governorate,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.publicPhone,
    required this.wheelchairAccessible,
    this.patientInstructions,
    required this.primary,
    this.gallery = const [],
    this.equipment = const [],
    this.coverage,
  });

  final String id;
  final DoctorPracticeLocationType type;
  final String name;
  final String governorate;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final String? publicPhone;
  final bool wheelchairAccessible;
  final String? patientInstructions;
  final bool primary;
  final List<DoctorPracticeMedia> gallery;
  final List<DoctorEquipment> equipment;
  final DoctorPracticeCoverage? coverage;

  factory DoctorPracticeLocation.fromJson(Map<String, dynamic> json) {
    final rawCoverage = json['coverage'];
    if (rawCoverage != null && rawCoverage is! Map) {
      throw const DoctorContractException('Practice coverage is malformed.');
    }
    return DoctorPracticeLocation(
      id: _requiredString(json, 'id'),
      type: DoctorPracticeLocationType.parse(json['type']),
      name: _requiredString(json, 'name'),
      governorate: _requiredString(json, 'governorate'),
      city: _requiredString(json, 'city'),
      address: _requiredString(json, 'address'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      publicPhone: _optionalString(json['publicPhone']),
      wheelchairAccessible: _requiredBool(json, 'wheelchairAccessible'),
      patientInstructions: _optionalString(json['patientInstructions']),
      primary: _requiredBool(json, 'primary'),
      gallery: _modelList(
        json['gallery'],
        fieldName: 'gallery',
        parse: DoctorPracticeMedia.fromJson,
      ),
      equipment: _modelList(
        json['equipment'],
        fieldName: 'equipment',
        parse: DoctorEquipment.fromJson,
      ),
      coverage: rawCoverage == null
          ? null
          : DoctorPracticeCoverage.fromJson(
              rawCoverage.cast<String, dynamic>(),
            ),
    );
  }
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
    this.education = const [],
    this.certifications = const [],
    this.practiceLocations = const [],
    this.careCapabilities = const [],
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
  final List<DoctorEducation> education;
  final List<DoctorCertification> certifications;
  final List<DoctorPracticeLocation> practiceLocations;
  final List<DoctorCareCapability> careCapabilities;

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
      education: _modelList(
        json['education'],
        fieldName: 'education',
        parse: DoctorEducation.fromJson,
      ),
      certifications: _modelList(
        json['certifications'],
        fieldName: 'certifications',
        parse: DoctorCertification.fromJson,
      ),
      practiceLocations: _modelList(
        json['practiceLocations'],
        fieldName: 'practiceLocations',
        parse: DoctorPracticeLocation.fromJson,
      ),
      careCapabilities: _enumList(
        json['careCapabilities'],
        fieldName: 'careCapabilities',
        parse: DoctorCareCapability.parse,
      ),
    );
  }

  /// Renders neither the identifier nor the name.
  @override
  String toString() => 'DoctorDirectoryDetail(<redacted>)';
}

/// A single computable open window (GET availability slots).
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

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DoctorContractException('Missing required integer field "$key".');
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return null;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw DoctorContractException('Missing required number field "$key".');
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const DoctorContractException('Expected an ISO date string.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const DoctorContractException('Expected an ISO date string.');
  }
  return parsed;
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

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return value.cast<String, dynamic>();
  throw DoctorContractException('Missing required object field "$key".');
}

List<T> _modelList<T>(
  Object? value, {
  required String fieldName,
  required T Function(Map<String, dynamic>) parse,
}) {
  if (value == null) return const [];
  if (value is! List) {
    throw DoctorContractException('Expected a $fieldName array.');
  }
  return List.unmodifiable(
    value.map((element) {
      if (element is! Map) {
        throw DoctorContractException('$fieldName entry is malformed.');
      }
      return parse(element.cast<String, dynamic>());
    }),
  );
}

List<T> _enumList<T>(
  Object? value, {
  required String fieldName,
  required T Function(Object?) parse,
}) {
  if (value == null) return const [];
  if (value is! List) {
    throw DoctorContractException('Expected a $fieldName array.');
  }
  return List.unmodifiable(value.map(parse));
}

/// Thrown when a doctor directory payload cannot be trusted.
class DoctorContractException implements Exception {
  const DoctorContractException(this.reason);

  final String reason;

  @override
  String toString() => 'DoctorContractException: $reason';
}
