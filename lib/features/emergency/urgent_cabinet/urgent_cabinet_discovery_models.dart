import 'package:flutter/foundation.dart';

enum UrgentCabinetDiscoverySort { name, distance }

@immutable
class UrgentCabinetGovernorateFacet {
  const UrgentCabinetGovernorateFacet({
    required this.governorate,
    required this.cities,
  });

  final String governorate;
  final List<String> cities;

  factory UrgentCabinetGovernorateFacet.fromJson(Map<String, dynamic> json) {
    return UrgentCabinetGovernorateFacet(
      governorate: _requiredString(json, 'governorate'),
      cities: _requiredStringList(json, 'cities'),
    );
  }
}

@immutable
class UrgentCabinetDiscoveryFacets {
  const UrgentCabinetDiscoveryFacets({
    required this.specialties,
    required this.locations,
    required this.evaluatedAt,
  });

  final List<String> specialties;
  final List<UrgentCabinetGovernorateFacet> locations;
  final DateTime evaluatedAt;

  factory UrgentCabinetDiscoveryFacets.fromJson(Map<String, dynamic> json) {
    final rawLocations = json['locations'];
    if (rawLocations is! List) {
      throw const FormatException('Invalid urgent CABINET facet locations.');
    }
    return UrgentCabinetDiscoveryFacets(
      specialties: _requiredStringList(json, 'specialties'),
      locations: List.unmodifiable(
        rawLocations.map((location) {
          if (location is! Map) {
            throw const FormatException(
              'Invalid urgent CABINET facet location.',
            );
          }
          return UrgentCabinetGovernorateFacet.fromJson(
            location.cast<String, dynamic>(),
          );
        }),
      ),
      evaluatedAt: _requiredInstant(json, 'evaluatedAt'),
    );
  }
}

@immutable
class UrgentCabinetSearchPosition {
  const UrgentCabinetSearchPosition({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

@immutable
class UrgentCabinetDiscoveryCriteria {
  const UrgentCabinetDiscoveryCriteria({
    this.query,
    this.specialty,
    this.governorate,
    this.city,
    this.position,
    this.maximumDistanceMeters,
    this.sort = UrgentCabinetDiscoverySort.name,
    this.page = 0,
    this.size = 20,
  });

  final String? query;
  final String? specialty;
  final String? governorate;
  final String? city;
  final UrgentCabinetSearchPosition? position;
  final int? maximumDistanceMeters;
  final UrgentCabinetDiscoverySort sort;
  final int page;
  final int size;

  Map<String, Object> toJson() {
    final validPosition = position?.isValid == true ? position : null;
    final distance = validPosition == null ? null : maximumDistanceMeters;
    final effectiveSort = validPosition == null
        ? UrgentCabinetDiscoverySort.name
        : sort;
    final result = <String, Object>{
      'sort': effectiveSort == UrgentCabinetDiscoverySort.distance
          ? 'DISTANCE'
          : 'NAME',
      'page': page,
      'size': size,
    };
    final normalizedQuery = _normalized(query);
    final normalizedSpecialty = _normalized(specialty);
    final normalizedGovernorate = _normalized(governorate);
    final normalizedCity = _normalized(city);
    if (normalizedQuery != null) result['query'] = normalizedQuery;
    if (normalizedSpecialty != null) result['specialty'] = normalizedSpecialty;
    if (normalizedGovernorate != null) {
      result['governorate'] = normalizedGovernorate;
    }
    if (normalizedCity != null) result['city'] = normalizedCity;
    if (validPosition != null) {
      result['latitude'] = validPosition.latitude;
      result['longitude'] = validPosition.longitude;
    }
    if (distance != null) result['maxDistanceMeters'] = distance;
    return result;
  }
}

@immutable
class UrgentCabinetDistance {
  const UrgentCabinetDistance({required this.meters, required this.method});

  final int meters;
  final String method;

  double get kilometers => meters / 1000;

  factory UrgentCabinetDistance.fromJson(Map<String, dynamic> json) {
    final meters = _requiredInt(json, 'meters');
    final method = _requiredString(json, 'method');
    if (meters < 0 || method != 'STRAIGHT_LINE_HAVERSINE') {
      throw const FormatException('Invalid urgent CABINET distance.');
    }
    return UrgentCabinetDistance(meters: meters, method: method);
  }
}

@immutable
class UrgentCabinetDoctorCabinet {
  const UrgentCabinetDoctorCabinet({
    required this.doctorId,
    required this.practiceLocationId,
    required this.doctorDisplayName,
    required this.specialty,
    required this.cabinetName,
    required this.cabinetAddress,
    required this.governorate,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.urgentCabinetFeeMilliTnd,
    required this.configurationRevision,
    required this.runtimeRevision,
    required this.practiceLocationVersion,
    this.patientToCabinetDistance,
  });

  final String doctorId;
  final String practiceLocationId;
  final String doctorDisplayName;
  final String specialty;
  final String cabinetName;
  final String cabinetAddress;
  final String governorate;
  final String city;
  final double latitude;
  final double longitude;
  final UrgentCabinetDistance? patientToCabinetDistance;
  final int urgentCabinetFeeMilliTnd;
  final int configurationRevision;
  final int runtimeRevision;
  final int practiceLocationVersion;

  factory UrgentCabinetDoctorCabinet.fromJson(Map<String, dynamic> json) {
    final latitude = _requiredDouble(json, 'latitude');
    final longitude = _requiredDouble(json, 'longitude');
    final configurationRevision = _requiredInt(json, 'configurationRevision');
    final runtimeRevision = _requiredInt(json, 'runtimeRevision');
    final practiceLocationVersion = _requiredInt(
      json,
      'practiceLocationVersion',
    );
    final fee = _requiredMilliTnd(json, 'urgentCabinetFeeTnd');
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        configurationRevision < 0 ||
        runtimeRevision < 0 ||
        practiceLocationVersion < 0 ||
        fee < 0) {
      throw const FormatException('Invalid urgent CABINET pair.');
    }

    final rawDistance = json['patientToCabinetDistance'];
    return UrgentCabinetDoctorCabinet(
      doctorId: _requiredString(json, 'doctorId'),
      practiceLocationId: _requiredString(json, 'practiceLocationId'),
      doctorDisplayName: _requiredString(json, 'doctorDisplayName'),
      specialty: _requiredString(json, 'specialty'),
      cabinetName: _requiredString(json, 'cabinetName'),
      cabinetAddress: _requiredString(json, 'cabinetAddress'),
      governorate: _requiredString(json, 'governorate'),
      city: _requiredString(json, 'city'),
      latitude: latitude,
      longitude: longitude,
      patientToCabinetDistance: rawDistance == null
          ? null
          : rawDistance is Map
          ? UrgentCabinetDistance.fromJson(rawDistance.cast<String, dynamic>())
          : throw const FormatException('Invalid urgent CABINET distance.'),
      urgentCabinetFeeMilliTnd: fee,
      configurationRevision: configurationRevision,
      runtimeRevision: runtimeRevision,
      practiceLocationVersion: practiceLocationVersion,
    );
  }
}

@immutable
class UrgentCabinetDiscoveryPage {
  const UrgentCabinetDiscoveryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.hasNext,
    required this.evaluatedAt,
  });

  final List<UrgentCabinetDoctorCabinet> items;
  final int page;
  final int size;
  final bool hasNext;
  final DateTime evaluatedAt;

  factory UrgentCabinetDiscoveryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Invalid urgent CABINET search items.');
    }
    final page = _requiredInt(json, 'page');
    final size = _requiredInt(json, 'size');
    if (page < 0 || size < 1 || size > 50) {
      throw const FormatException('Invalid urgent CABINET page metadata.');
    }
    return UrgentCabinetDiscoveryPage(
      items: List.unmodifiable(
        rawItems.map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid urgent CABINET search item.');
          }
          return UrgentCabinetDoctorCabinet.fromJson(
            item.cast<String, dynamic>(),
          );
        }),
      ),
      page: page,
      size: size,
      hasNext: _requiredBool(json, 'hasNext'),
      evaluatedAt: _requiredInstant(json, 'evaluatedAt'),
    );
  }
}

@immutable
class UrgentCabinetDiscoveryDetail {
  const UrgentCabinetDiscoveryDetail({
    required this.doctorCabinet,
    required this.publicProfile,
    required this.selectedPractice,
    required this.evaluatedAt,
  });

  final UrgentCabinetDoctorCabinet doctorCabinet;
  final UrgentCabinetDoctorPublicProfile publicProfile;
  final UrgentCabinetSelectedPractice selectedPractice;
  final DateTime evaluatedAt;

  factory UrgentCabinetDiscoveryDetail.fromJson(Map<String, dynamic> json) {
    final rawPair = json['doctorCabinet'];
    if (rawPair is! Map) {
      throw const FormatException('Invalid urgent CABINET detail pair.');
    }
    final rawProfile = json['publicProfile'];
    final rawPractice = json['selectedPractice'];
    if (rawProfile is! Map || rawPractice is! Map) {
      throw const FormatException('Invalid urgent CABINET public detail.');
    }
    return UrgentCabinetDiscoveryDetail(
      doctorCabinet: UrgentCabinetDoctorCabinet.fromJson(
        rawPair.cast<String, dynamic>(),
      ),
      publicProfile: UrgentCabinetDoctorPublicProfile.fromJson(
        rawProfile.cast<String, dynamic>(),
      ),
      selectedPractice: UrgentCabinetSelectedPractice.fromJson(
        rawPractice.cast<String, dynamic>(),
      ),
      evaluatedAt: _requiredInstant(json, 'evaluatedAt'),
    );
  }
}

@immutable
class UrgentCabinetDoctorPublicProfile {
  const UrgentCabinetDoctorPublicProfile({
    required this.subSpecialties,
    required this.languages,
    required this.areasOfCare,
    required this.expertise,
    required this.visitReasons,
    this.photoUrl,
    this.experienceYears,
    this.biography,
  });

  final String? photoUrl;
  final int? experienceYears;
  final List<String> subSpecialties;
  final List<String> languages;
  final List<String> areasOfCare;
  final List<String> expertise;
  final List<String> visitReasons;
  final String? biography;

  factory UrgentCabinetDoctorPublicProfile.fromJson(Map<String, dynamic> json) {
    final experienceYears = _optionalInt(json, 'experienceYears');
    if (experienceYears != null && experienceYears < 0) {
      throw const FormatException('Invalid Doctor experience.');
    }
    return UrgentCabinetDoctorPublicProfile(
      photoUrl: _optionalHttpUrl(json, 'photoUrl'),
      experienceYears: experienceYears,
      subSpecialties: _requiredStringList(json, 'subSpecialties'),
      languages: _requiredStringList(json, 'languages'),
      areasOfCare: _requiredStringList(json, 'areasOfCare'),
      expertise: _requiredStringList(json, 'expertise'),
      visitReasons: _requiredStringList(json, 'visitReasons'),
      biography: _optionalString(json, 'biography'),
    );
  }
}

@immutable
class UrgentCabinetPracticeMedia {
  const UrgentCabinetPracticeMedia({
    required this.url,
    required this.displayOrder,
  });

  final String url;
  final int displayOrder;

  factory UrgentCabinetPracticeMedia.fromJson(Map<String, dynamic> json) {
    final order = _requiredInt(json, 'displayOrder');
    final url = _optionalHttpUrl(json, 'url');
    if (url == null || order < 0) {
      throw const FormatException('Invalid urgent CABINET media.');
    }
    return UrgentCabinetPracticeMedia(url: url, displayOrder: order);
  }
}

@immutable
class UrgentCabinetEquipment {
  const UrgentCabinetEquipment({
    required this.code,
    required this.displayName,
    required this.portable,
  });

  final String code;
  final String displayName;
  final bool portable;

  factory UrgentCabinetEquipment.fromJson(Map<String, dynamic> json) {
    return UrgentCabinetEquipment(
      code: _requiredString(json, 'code'),
      displayName: _requiredString(json, 'displayName'),
      portable: _requiredBool(json, 'portable'),
    );
  }
}

@immutable
class UrgentCabinetSelectedPractice {
  const UrgentCabinetSelectedPractice({
    required this.gallery,
    required this.equipment,
    required this.wheelchairAccessible,
    this.patientInstructions,
  });

  final List<UrgentCabinetPracticeMedia> gallery;
  final List<UrgentCabinetEquipment> equipment;
  final bool wheelchairAccessible;
  final String? patientInstructions;

  factory UrgentCabinetSelectedPractice.fromJson(Map<String, dynamic> json) {
    final rawGallery = json['gallery'];
    final rawEquipment = json['equipment'];
    if (rawGallery is! List || rawEquipment is! List) {
      throw const FormatException('Invalid urgent CABINET practice detail.');
    }
    return UrgentCabinetSelectedPractice(
      gallery: List.unmodifiable(
        rawGallery.map((media) {
          if (media is! Map) {
            throw const FormatException('Invalid urgent CABINET media.');
          }
          return UrgentCabinetPracticeMedia.fromJson(
            media.cast<String, dynamic>(),
          );
        }),
      ),
      equipment: List.unmodifiable(
        rawEquipment.map((equipment) {
          if (equipment is! Map) {
            throw const FormatException('Invalid urgent CABINET equipment.');
          }
          return UrgentCabinetEquipment.fromJson(
            equipment.cast<String, dynamic>(),
          );
        }),
      ),
      wheelchairAccessible: _requiredBool(json, 'wheelchairAccessible'),
      patientInstructions: _optionalString(json, 'patientInstructions'),
    );
  }
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $key.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key.');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? _optionalHttpUrl(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Invalid $key.');
  return List.unmodifiable(
    value.map((item) {
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('Invalid $key.');
      }
      return item.trim();
    }),
  );
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Invalid $key.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Invalid $key.');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Invalid $key.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Invalid $key.');
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final raw = _requiredString(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null || !value.isUtc) throw FormatException('Invalid $key.');
  return value;
}

int _requiredMilliTnd(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num && value is! String) throw FormatException('Invalid $key.');
  final raw = value.toString();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(raw);
  if (match == null) throw FormatException('Invalid $key.');
  final whole = int.parse(match.group(1)!);
  final fractional = (match.group(2) ?? '').padRight(3, '0');
  return whole * 1000 + int.parse(fractional.isEmpty ? '0' : fractional);
}
