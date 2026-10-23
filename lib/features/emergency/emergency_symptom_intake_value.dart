import 'package:flutter/foundation.dart';

/// Raw, presentation-level values emitted by the frozen symptom intake.
///
/// Anatomical identifiers deliberately remain unmapped. A consuming flow must
/// not interpret them as backend clinical categories without separate approval.
@immutable
class EmergencySymptomIntakeValue {
  EmergencySymptomIntakeValue({
    required Iterable<String> rawAnatomicalRegionIds,
    required this.painScore,
    required String shortDescription,
  }) : rawAnatomicalRegionIds = List.unmodifiable(rawAnatomicalRegionIds),
       shortDescription = shortDescription.trim();

  final List<String> rawAnatomicalRegionIds;
  final int painScore;
  final String shortDescription;
}
