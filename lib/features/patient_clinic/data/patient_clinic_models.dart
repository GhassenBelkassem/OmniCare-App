/// Strictly parsed models for the real patient clinic directory.
///
/// Verified field-by-field against the backend `PatientClinicDirectoryController`
/// contract (`GET /api/v1/patient/clinics` and `/{clinicId}`). No services, no
/// ratings, no prices: the backend does not expose them for patients and the
/// app must not invent them.
library;

/// One clinic row in the patient directory list.
class PatientClinicListItem {
  const PatientClinicListItem({
    required this.clinicId,
    required this.displayName,
    this.city,
    this.governorate,
    this.primaryImageUrl,
    required this.acceptingRequests,
  });

  final String clinicId;
  final String displayName;
  final String? city;
  final String? governorate;
  final String? primaryImageUrl;
  final bool acceptingRequests;

  factory PatientClinicListItem.fromJson(Map<String, dynamic> json) {
    return PatientClinicListItem(
      clinicId: _requiredString(json, 'clinicId'),
      displayName: _requiredString(json, 'displayName'),
      city: _optionalString(json['city']),
      governorate: _optionalString(json['governorate']),
      primaryImageUrl: _optionalString(json['primaryImageUrl']),
      acceptingRequests: _requiredBool(json, 'acceptingRequests'),
    );
  }

  /// Renders neither the identifier nor the name.
  @override
  String toString() => 'PatientClinicListItem(<redacted>)';
}

/// One image in a clinic gallery.
class PatientClinicImage {
  const PatientClinicImage({required this.imageUrl});

  final String imageUrl;

  factory PatientClinicImage.fromJson(Map<String, dynamic> json) {
    return PatientClinicImage(imageUrl: _requiredString(json, 'imageUrl'));
  }

  /// Renders no image contents.
  @override
  String toString() => 'PatientClinicImage(<redacted>)';
}

/// Full detail of a single clinic.
///
/// `gallery` may be empty; the UI must cope with zero, one, or many images.
/// There is deliberately no services section: the backend does not surface a
/// public services vocabulary to patients in V1.
class PatientClinicDetail {
  const PatientClinicDetail({
    required this.clinicId,
    required this.displayName,
    this.about,
    this.city,
    this.governorate,
    this.address,
    this.primaryImageUrl,
    required this.acceptingRequests,
    required this.gallery,
  });

  final String clinicId;
  final String displayName;
  final String? about;
  final String? city;
  final String? governorate;
  final String? address;
  final String? primaryImageUrl;
  final bool acceptingRequests;
  final List<PatientClinicImage> gallery;

  factory PatientClinicDetail.fromJson(Map<String, dynamic> json) {
    final rawGallery = json['gallery'];
    final gallery = <PatientClinicImage>[];
    if (rawGallery is! List) {
      throw const PatientClinicContractException(
        'Clinic gallery is malformed.',
      );
    }
    for (final item in rawGallery) {
      if (item is! Map) {
        throw const PatientClinicContractException(
          'Clinic gallery entry is malformed.',
        );
      }
      gallery.add(PatientClinicImage.fromJson(item.cast<String, dynamic>()));
    }
    return PatientClinicDetail(
      clinicId: _requiredString(json, 'clinicId'),
      displayName: _requiredString(json, 'displayName'),
      about: _optionalString(json['about']),
      city: _optionalString(json['city']),
      governorate: _optionalString(json['governorate']),
      address: _optionalString(json['address']),
      primaryImageUrl: _optionalString(json['primaryImageUrl']),
      acceptingRequests: _requiredBool(json, 'acceptingRequests'),
      gallery: List.unmodifiable(gallery),
    );
  }

  /// The image to show first: the gallery lead if present, else the primary.
  String? get headerImageUrl =>
      gallery.isNotEmpty ? gallery.first.imageUrl : primaryImageUrl;

  /// Renders neither the identifier nor the name.
  @override
  String toString() => 'PatientClinicDetail(<redacted>)';
}

/// A bounded, paginated page of the patient clinic directory.
class PatientClinicDirectoryPage {
  const PatientClinicDirectoryPage({
    required this.contractVersion,
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  final String contractVersion;
  final List<PatientClinicListItem> items;
  final int page;
  final int pageSize;
  final bool hasNext;

  factory PatientClinicDirectoryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const PatientClinicContractException('Clinic list is malformed.');
    }
    final items = <PatientClinicListItem>[];
    for (final item in rawItems) {
      if (item is! Map) {
        throw const PatientClinicContractException(
          'Clinic list entry is malformed.',
        );
      }
      items.add(PatientClinicListItem.fromJson(item.cast<String, dynamic>()));
    }
    return PatientClinicDirectoryPage(
      contractVersion: _requiredString(json, 'contractVersion'),
      items: List.unmodifiable(items),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      hasNext: json['hasNext'] == true,
    );
  }

  @override
  String toString() => 'PatientClinicDirectoryPage(${items.length} items)';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw PatientClinicContractException('Missing required field "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw PatientClinicContractException(
    'Missing required numeric field "$key".',
  );
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw PatientClinicContractException(
    'Missing required boolean field "$key".',
  );
}

/// Thrown when a clinic directory payload cannot be trusted.
class PatientClinicContractException implements Exception {
  const PatientClinicContractException(this.reason);

  final String reason;

  @override
  String toString() => 'PatientClinicContractException: $reason';
}
