import '../data/patient_clinic_models.dart';
import 'clinic_presentation_metadata.dart';

/// Sort orders available for the currently loaded directory page.
///
/// [defaultOrder] keeps the backend `Slice` order. No invented ranking exists:
/// there is deliberately no "recommended" or "top match" option.
enum ClinicSortOrder {
  defaultOrder,
  alphabetical,
  acceptingFirst;

  String get label => switch (this) {
    ClinicSortOrder.defaultOrder => 'Default',
    ClinicSortOrder.alphabetical => 'A–Z',
    ClinicSortOrder.acceptingFirst => 'Accepting requests first',
  };
}

/// Immutable local filter state applied to the clinics currently loaded by the
/// directory controller.
///
/// IMPORTANT:
///
/// This filters only the already-loaded page(s). It is presentation-only and
/// never becomes a backend query parameter. [PatientClinicDirectoryController]
/// keeps owning real search and server-side `Slice` pagination.
class ClinicFilterSnapshot {
  const ClinicFilterSnapshot({
    this.careNeeds = const {},
    this.specialties = const {},
    this.cities = const {},
    this.distance,
    this.acceptingOnly = false,
    this.clinicTypes = const {},
    this.services = const {},
    this.sortOrder = ClinicSortOrder.defaultOrder,
  });

  static const ClinicFilterSnapshot none = ClinicFilterSnapshot();

  /// Presentation-only care-need categories selected by the patient.
  final Set<String> careNeeds;

  final Set<String> specialties;
  final Set<String> cities;

  /// Presentation-only distance filter. null means no distance filter.
  final String? distance;

  final bool acceptingOnly;
  final Set<String> clinicTypes;
  final Set<String> services;
  final ClinicSortOrder sortOrder;

  bool get isActive => activeGroupCount > 0;

  /// Number of non-default filter groups. Used only for the restrained
  /// active-filter badge on the directory header.
  int get activeGroupCount {
    var count = 0;
    if (careNeeds.isNotEmpty) count++;
    if (specialties.isNotEmpty) count++;
    if (cities.isNotEmpty) count++;
    if (distance != null) count++;
    if (acceptingOnly) count++;
    if (clinicTypes.isNotEmpty) count++;
    if (services.isNotEmpty) count++;
    if (sortOrder != ClinicSortOrder.defaultOrder) count++;
    return count;
  }

  ClinicFilterSnapshot copyWith({
    Set<String>? careNeeds,
    Set<String>? specialties,
    Set<String>? cities,
    String? distance,
    bool clearDistance = false,
    bool? acceptingOnly,
    Set<String>? clinicTypes,
    Set<String>? services,
    ClinicSortOrder? sortOrder,
  }) {
    return ClinicFilterSnapshot(
      careNeeds: careNeeds ?? this.careNeeds,
      specialties: specialties ?? this.specialties,
      cities: cities ?? this.cities,
      distance: clearDistance ? null : (distance ?? this.distance),
      acceptingOnly: acceptingOnly ?? this.acceptingOnly,
      clinicTypes: clinicTypes ?? this.clinicTypes,
      services: services ?? this.services,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! ClinicFilterSnapshot) return false;
    return _setEquals(careNeeds, other.careNeeds) &&
        _setEquals(specialties, other.specialties) &&
        _setEquals(cities, other.cities) &&
        distance == other.distance &&
        acceptingOnly == other.acceptingOnly &&
        _setEquals(clinicTypes, other.clinicTypes) &&
        _setEquals(services, other.services) &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(careNeeds),
    Object.hashAllUnordered(specialties),
    Object.hashAllUnordered(cities),
    distance,
    acceptingOnly,
    Object.hashAllUnordered(clinicTypes),
    Object.hashAllUnordered(services),
    sortOrder,
  );
}

/// The option vocabulary shown in the filter bottom sheet.
///
/// Every value is derived from the clinics currently loaded by the controller:
/// no city or specialty is invented here.
class ClinicFilterOptions {
  const ClinicFilterOptions({
    this.specialties = const [],
    this.cities = const [],
    this.clinicTypes = const [],
    this.services = const [],
  });

  final List<String> specialties;
  final List<String> cities;
  final List<String> clinicTypes;
  final List<String> services;
}

/// Builds the sheet option vocabulary from the currently loaded clinics.
ClinicFilterOptions buildClinicFilterOptions(
  Iterable<PatientClinicListItem> clinics,
) {
  final specialties = <String>{};
  final cities = <String>{};
  final clinicTypes = <String>{};
  final services = <String>{};

  for (final clinic in clinics) {
    final city = clinic.city;
    if (city != null && city.trim().isNotEmpty) cities.add(city);
    final metadata = ClinicPresentationCatalog.forClinic(clinic.clinicId);
    specialties.addAll(metadata.specialties);
    clinicTypes.add(metadata.clinicType);
    services.addAll(metadata.services);
  }

  List<String> sorted(Set<String> values) => values.toList()..sort();
  return ClinicFilterOptions(
    specialties: List.unmodifiable(sorted(specialties)),
    cities: List.unmodifiable(sorted(cities)),
    clinicTypes: List.unmodifiable(sorted(clinicTypes)),
    services: List.unmodifiable(sorted(services)),
  );
}

/// Applies the local filters to the currently loaded clinics.
///
/// Backend values stay authoritative: the returned list wraps the real
/// [PatientClinicListItem] plus isolated presentation metadata. The original
/// backend order is preserved for [ClinicSortOrder.defaultOrder]; other sorts
/// are stable within their key.
List<PatientClinicPresentationItem> applyClinicFilters({
  required List<PatientClinicListItem> items,
  required ClinicFilterSnapshot filters,
}) {
  final presentation = <PatientClinicPresentationItem>[];
  for (final clinic in items) {
    final item = PatientClinicPresentationItem.fromBackend(clinic);
    if (_matches(item, filters)) presentation.add(item);
  }

  if (filters.sortOrder == ClinicSortOrder.defaultOrder ||
      presentation.isEmpty) {
    return presentation;
  }

  final indexed = <(int, PatientClinicPresentationItem)>[
    for (var index = 0; index < presentation.length; index++)
      (index, presentation[index]),
  ];

  switch (filters.sortOrder) {
    case ClinicSortOrder.alphabetical:
      indexed.sort((a, b) {
        final byName = a.$2.displayName
            .toLowerCase()
            .compareTo(b.$2.displayName.toLowerCase());
        return byName != 0 ? byName : a.$1.compareTo(b.$1);
      });
    case ClinicSortOrder.acceptingFirst:
      indexed.sort((a, b) {
        if (a.$2.acceptingRequests != b.$2.acceptingRequests) {
          return a.$2.acceptingRequests ? -1 : 1;
        }
        return a.$1.compareTo(b.$1);
      });
    case ClinicSortOrder.defaultOrder:
      break;
  }

  return [for (final entry in indexed) entry.$2];
}

bool _matches(
  PatientClinicPresentationItem item,
  ClinicFilterSnapshot filters,
) {
  if (filters.acceptingOnly && !item.acceptingRequests) return false;

  if (filters.careNeeds.isNotEmpty &&
      !_matchesCareNeeds(item, filters.careNeeds)) {
    return false;
  }

  if (filters.specialties.isNotEmpty &&
      item.specialties.toSet().intersection(filters.specialties).isEmpty) {
    return false;
  }

  final city = item.city;
  if (filters.cities.isNotEmpty &&
      (city == null || !filters.cities.contains(city))) {
    return false;
  }

  if (filters.distance != null && !_matchesDistance(item, filters.distance!)) {
    return false;
  }

  if (filters.clinicTypes.isNotEmpty &&
      !filters.clinicTypes.contains(item.clinicType)) {
    return false;
  }

  if (filters.services.isNotEmpty &&
      item.services.toSet().intersection(filters.services).isEmpty) {
    return false;
  }

  return true;
}

/// Presentation-only care-need matching.
///
/// Matches against the clinic's specialties, services, and clinic type keywords.
/// This is a soft heuristic — the backend does not yet expose care-need
/// categories.
bool _matchesCareNeeds(
  PatientClinicPresentationItem item,
  Set<String> careNeeds,
) {
  final allText = [
    ...item.specialties,
    ...item.services,
    item.clinicType,
  ].join(' ').toLowerCase();

  for (final need in careNeeds) {
    final needle = need.toLowerCase();
    if (allText.contains(needle)) return true;

    // Keyword expansion for presentation-only matching.
    if (needle == 'general consultation' &&
        (allText.contains('general medicine') ||
            allText.contains('general practice') ||
            item.clinicType.toLowerCase().contains('general clinic'))) {
      return true;
    }
    if (needle == 'specialist consultation' &&
        (allText.contains('specialist') ||
            allText.contains('specialty') ||
            allText.contains('cardiology') ||
            allText.contains('orthopedics'))) {
      return true;
    }
    if (needle == 'surgery' && allText.contains('surgery')) return true;
    if (needle == 'imaging' &&
        (allText.contains('imaging') || allText.contains('radiology'))) {
      return true;
    }
    if (needle == 'laboratory / tests' &&
        (allText.contains('laboratory') ||
            allText.contains('lab') ||
            allText.contains('test'))) {
      return true;
    }
    if (needle == 'maternity' &&
        (allText.contains('maternity') || allText.contains('obstetric'))) {
      return true;
    }
    if (needle == 'rehabilitation / kiné' &&
        (allText.contains('physiotherapy') ||
            allText.contains('rehabilitation') ||
            allText.contains('kiné'))) {
      return true;
    }
  }
  return false;
}

/// Presentation-only distance matching against the metadata distance string.
///
/// Parses "2.3 km away" → 2.3 and compares against the selected threshold.
bool _matchesDistance(PatientClinicPresentationItem item, String distance) {
  final distanceText = item.distance;
  if (distanceText == null) return false;

  final kmValue = _parseKm(distanceText);
  if (kmValue == null) return false;

  final threshold = _parseKm(distance);
  if (threshold == null) return false;

  return kmValue <= threshold;
}

double? _parseKm(String text) {
  final match = RegExp(r'([\d.]+)\s*km').firstMatch(text.toLowerCase());
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
