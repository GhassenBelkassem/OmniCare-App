import 'package:flutter/foundation.dart';

/// Closed backend vocabulary accepted by the urgent CABINET submission API.
enum UrgentCabinetBodyAreaCode {
  head('HEAD'),
  neck('NECK'),
  chest('CHEST'),
  abdomen('ABDOMEN'),
  back('BACK'),
  pelvis('PELVIS'),
  upperLimb('UPPER_LIMB'),
  lowerLimb('LOWER_LIMB'),
  general('GENERAL');

  const UrgentCabinetBodyAreaCode(this.wireValue);

  final String wireValue;
}

/// Every stable identifier emitted by the frozen Patient body map.
///
/// Values are explicit: no prefix or substring inference is permitted. A null
/// value is an intentionally unresolved clinical classification and therefore
/// blocks payload creation. GENERAL is deliberately absent from this map; it
/// is never used as a fallback.
const Map<String, UrgentCabinetBodyAreaCode?>
urgentCabinetAnatomicalRegionMapping = {
  'front-head': UrgentCabinetBodyAreaCode.head,
  'front-neck': UrgentCabinetBodyAreaCode.neck,
  'back-neck': UrgentCabinetBodyAreaCode.neck,
  'front-chest-pectoral-left': UrgentCabinetBodyAreaCode.chest,
  'front-chest-pectoral-right': UrgentCabinetBodyAreaCode.chest,
  'front-abs-upper': UrgentCabinetBodyAreaCode.abdomen,
  'front-abs-middle': UrgentCabinetBodyAreaCode.abdomen,
  'front-abs-lower': UrgentCabinetBodyAreaCode.abdomen,
  'front-oblique-left': UrgentCabinetBodyAreaCode.abdomen,
  'front-oblique-right': UrgentCabinetBodyAreaCode.abdomen,
  'front-serratus-left': UrgentCabinetBodyAreaCode.chest,
  'front-serratus-right': UrgentCabinetBodyAreaCode.chest,
  'back-trap-upper': null,
  'back-lat-left': UrgentCabinetBodyAreaCode.back,
  'back-lat-right': UrgentCabinetBodyAreaCode.back,
  'back-spine-upper': UrgentCabinetBodyAreaCode.back,
  'back-spine-middle': UrgentCabinetBodyAreaCode.back,
  'back-lumbar': UrgentCabinetBodyAreaCode.back,
  'back-glute-left': UrgentCabinetBodyAreaCode.pelvis,
  'back-glute-right': UrgentCabinetBodyAreaCode.pelvis,
  'front-shoulder-deltoid-left': UrgentCabinetBodyAreaCode.upperLimb,
  'front-shoulder-deltoid-right': UrgentCabinetBodyAreaCode.upperLimb,
  'back-shoulder-deltoid-left': UrgentCabinetBodyAreaCode.upperLimb,
  'back-shoulder-deltoid-right': UrgentCabinetBodyAreaCode.upperLimb,
  'front-bicep-left': UrgentCabinetBodyAreaCode.upperLimb,
  'front-bicep-right': UrgentCabinetBodyAreaCode.upperLimb,
  'back-tricep-left': UrgentCabinetBodyAreaCode.upperLimb,
  'back-tricep-right': UrgentCabinetBodyAreaCode.upperLimb,
  'front-forearm-left': UrgentCabinetBodyAreaCode.upperLimb,
  'front-forearm-right': UrgentCabinetBodyAreaCode.upperLimb,
  'back-forearm-left': UrgentCabinetBodyAreaCode.upperLimb,
  'back-forearm-right': UrgentCabinetBodyAreaCode.upperLimb,
  'front-hand-left': UrgentCabinetBodyAreaCode.upperLimb,
  'front-hand-right': UrgentCabinetBodyAreaCode.upperLimb,
  'back-hand-left': UrgentCabinetBodyAreaCode.upperLimb,
  'back-hand-right': UrgentCabinetBodyAreaCode.upperLimb,
  'front-thigh-quad-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-thigh-quad-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-thigh-hamstring-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-thigh-hamstring-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-knee-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-knee-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-knee-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-knee-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-shin-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-shin-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-calf-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-calf-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-calf-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-calf-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-foot-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'front-foot-right': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-foot-left': UrgentCabinetBodyAreaCode.lowerLimb,
  'back-foot-right': UrgentCabinetBodyAreaCode.lowerLimb,
};

@immutable
class UrgentCabinetAnatomicalMappingResult {
  const UrgentCabinetAnatomicalMappingResult({
    required this.bodyAreaCodes,
    required this.unresolvedIdentifiers,
    required this.unknownIdentifiers,
  });

  final List<UrgentCabinetBodyAreaCode> bodyAreaCodes;
  final List<String> unresolvedIdentifiers;
  final List<String> unknownIdentifiers;

  bool get isComplete =>
      bodyAreaCodes.isNotEmpty &&
      bodyAreaCodes.length <= UrgentCabinetBodyAreaCode.values.length &&
      unresolvedIdentifiers.isEmpty &&
      unknownIdentifiers.isEmpty;
}

UrgentCabinetAnatomicalMappingResult mapUrgentCabinetAnatomy(
  Iterable<String> rawIdentifiers,
) {
  final codes = <UrgentCabinetBodyAreaCode>{};
  final unresolved = <String>[];
  final unknown = <String>[];

  for (final rawIdentifier in rawIdentifiers) {
    // Stable presentation identifiers are exact and must not be normalized.
    if (!urgentCabinetAnatomicalRegionMapping.containsKey(rawIdentifier)) {
      if (!unknown.contains(rawIdentifier)) unknown.add(rawIdentifier);
      continue;
    }
    final code = urgentCabinetAnatomicalRegionMapping[rawIdentifier];
    if (code == null) {
      if (!unresolved.contains(rawIdentifier)) unresolved.add(rawIdentifier);
      continue;
    }
    codes.add(code);
  }

  return UrgentCabinetAnatomicalMappingResult(
    bodyAreaCodes: List.unmodifiable(codes),
    unresolvedIdentifiers: List.unmodifiable(unresolved),
    unknownIdentifiers: List.unmodifiable(unknown),
  );
}
