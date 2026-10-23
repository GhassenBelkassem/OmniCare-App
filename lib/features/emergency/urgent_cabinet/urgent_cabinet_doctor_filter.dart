import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'urgent_cabinet_doctor_list_item.dart';

enum UrgentCabinetSortOrder { nearest, nameAscending }

extension UrgentCabinetSortOrderLabel on UrgentCabinetSortOrder {
  String get label => switch (this) {
    UrgentCabinetSortOrder.nearest => 'Plus proches',
    UrgentCabinetSortOrder.nameAscending => 'Nom A–Z',
  };
}

@immutable
class UrgentCabinetDoctorFilterSnapshot {
  UrgentCabinetDoctorFilterSnapshot({
    Set<String> specialties = const {},
    this.maximumDistanceKm,
    this.governorate,
    this.city,
    this.sortOrder = UrgentCabinetSortOrder.nearest,
  }) : specialties = UnmodifiableSetView(
         specialties
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet(),
       );

  static final none = UrgentCabinetDoctorFilterSnapshot();

  final Set<String> specialties;
  final double? maximumDistanceKm;
  final String? governorate;
  final String? city;
  final UrgentCabinetSortOrder sortOrder;

  int get activeGroupCount {
    var count = 0;
    if (specialties.isNotEmpty) count++;
    if (maximumDistanceKm != null) count++;
    if (governorate != null) count++;
    if (city != null) count++;
    return count;
  }

  bool get isActive => activeGroupCount > 0;

  UrgentCabinetDoctorFilterSnapshot copyWith({
    Set<String>? specialties,
    double? maximumDistanceKm,
    bool clearMaximumDistance = false,
    String? governorate,
    bool clearGovernorate = false,
    String? city,
    bool clearCity = false,
    UrgentCabinetSortOrder? sortOrder,
  }) {
    return UrgentCabinetDoctorFilterSnapshot(
      specialties: specialties ?? this.specialties,
      maximumDistanceKm: clearMaximumDistance
          ? null
          : maximumDistanceKm ?? this.maximumDistanceKm,
      governorate: clearGovernorate
          ? null
          : _normalizedOptional(governorate) ?? this.governorate,
      city: clearCity ? null : _normalizedOptional(city) ?? this.city,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UrgentCabinetDoctorFilterSnapshot &&
        setEquals(specialties, other.specialties) &&
        maximumDistanceKm == other.maximumDistanceKm &&
        governorate == other.governorate &&
        city == other.city &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(specialties),
    maximumDistanceKm,
    governorate,
    city,
    sortOrder,
  );
}

@immutable
class UrgentCabinetDoctorFilterOptions {
  UrgentCabinetDoctorFilterOptions({
    required Iterable<String> specialties,
    required Iterable<String> governorates,
    required Map<String, Iterable<String>> citiesByGovernorate,
  }) : specialties = List.unmodifiable(_sortedDistinct(specialties)),
       governorates = List.unmodifiable(_sortedDistinct(governorates)),
       citiesByGovernorate = Map<String, List<String>>.unmodifiable({
         for (final entry in citiesByGovernorate.entries)
           entry.key: List<String>.unmodifiable(_sortedDistinct(entry.value)),
       });

  final List<String> specialties;
  final List<String> governorates;
  final Map<String, List<String>> citiesByGovernorate;

  List<String> citiesFor(String? governorate) {
    if (governorate != null) {
      return citiesByGovernorate[governorate] ?? const [];
    }
    return List.unmodifiable(
      _sortedDistinct(citiesByGovernorate.values.expand((cities) => cities)),
    );
  }
}

UrgentCabinetDoctorFilterOptions buildUrgentCabinetDoctorFilterOptions(
  Iterable<UrgentCabinetDoctorListItem> doctors,
) {
  final specialties = <String>{};
  final governorates = <String>{};
  final citiesByGovernorate = <String, Set<String>>{};

  for (final doctor in doctors.where(
    (doctor) => doctor.canReceiveUrgentRequest,
  )) {
    specialties.add(doctor.specialty);
    governorates.add(doctor.cabinetGovernorate);
    citiesByGovernorate
        .putIfAbsent(doctor.cabinetGovernorate, () => <String>{})
        .add(doctor.cabinetCity);
  }

  return UrgentCabinetDoctorFilterOptions(
    specialties: specialties,
    governorates: governorates,
    citiesByGovernorate: citiesByGovernorate,
  );
}

List<UrgentCabinetDoctorListItem> filterAndSortUrgentCabinetDoctors({
  required Iterable<UrgentCabinetDoctorListItem> doctors,
  required String query,
  required UrgentCabinetDoctorFilterSnapshot filters,
}) {
  final normalizedQuery = normalizeUrgentCabinetDoctorText(query.trim());
  final result = doctors
      .where((doctor) => doctor.canReceiveUrgentRequest)
      .where(
        (doctor) =>
            normalizedQuery.isEmpty || _matchesQuery(doctor, normalizedQuery),
      )
      .where((doctor) => _matchesFilters(doctor, filters))
      .toList(growable: false);

  final sorted = List<UrgentCabinetDoctorListItem>.of(result);
  sorted.sort(
    (left, right) => switch (filters.sortOrder) {
      UrgentCabinetSortOrder.nearest => _compareNearest(left, right),
      UrgentCabinetSortOrder.nameAscending => _compareByName(left, right),
    },
  );
  return List.unmodifiable(sorted);
}

bool _matchesQuery(UrgentCabinetDoctorListItem doctor, String normalizedQuery) {
  final searchable = [
    doctor.displayName,
    doctor.specialty,
    doctor.cabinetName,
    doctor.cabinetLocality,
    doctor.cabinetAddress ?? '',
    doctor.cabinetGovernorate,
    doctor.cabinetCity,
  ].map(normalizeUrgentCabinetDoctorText).join(' ');
  return searchable.contains(normalizedQuery);
}

bool _matchesFilters(
  UrgentCabinetDoctorListItem doctor,
  UrgentCabinetDoctorFilterSnapshot filters,
) {
  if (filters.specialties.isNotEmpty &&
      !filters.specialties.contains(doctor.specialty)) {
    return false;
  }

  final maximumDistance = filters.maximumDistanceKm;
  if (maximumDistance != null) {
    final distance = doctor.distanceKm;
    if (distance == null || distance > maximumDistance) return false;
  }

  if (filters.governorate != null &&
      doctor.cabinetGovernorate != filters.governorate) {
    return false;
  }

  if (filters.city != null && doctor.cabinetCity != filters.city) {
    return false;
  }

  return true;
}

int _compareNearest(
  UrgentCabinetDoctorListItem left,
  UrgentCabinetDoctorListItem right,
) {
  final leftDistance = left.distanceKm;
  final rightDistance = right.distanceKm;
  if (leftDistance == null && rightDistance != null) return 1;
  if (leftDistance != null && rightDistance == null) return -1;
  if (leftDistance != null && rightDistance != null) {
    final byDistance = leftDistance.compareTo(rightDistance);
    if (byDistance != 0) return byDistance;
  }
  return _compareByName(left, right);
}

int _compareByName(
  UrgentCabinetDoctorListItem left,
  UrgentCabinetDoctorListItem right,
) {
  final byName = normalizeUrgentCabinetDoctorText(
    left.displayName,
  ).compareTo(normalizeUrgentCabinetDoctorText(right.displayName));
  if (byName != 0) return byName;
  return left.doctorId.compareTo(right.doctorId);
}

String normalizeUrgentCabinetDoctorText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll('æ', 'ae')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll('œ', 'oe')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll(RegExp('[ýÿ]'), 'y');
}

String? _normalizedOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

List<String> _sortedDistinct(Iterable<String> values) {
  final distinct = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  distinct.sort((left, right) {
    final comparison = normalizeUrgentCabinetDoctorText(
      left,
    ).compareTo(normalizeUrgentCabinetDoctorText(right));
    return comparison != 0 ? comparison : left.compareTo(right);
  });
  return distinct;
}
