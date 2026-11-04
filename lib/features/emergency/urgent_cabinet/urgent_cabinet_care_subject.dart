import 'package:flutter/foundation.dart';

enum UrgentCabinetCareSubjectType { self, familyMember }

/// P4-only reference to the person who needs urgent cabinet care.
///
/// This is deliberately a local domain model, not a backend payload. A family
/// subject is identified only by the persisted [familyMemberId].
@immutable
class UrgentCabinetCareSubject {
  const UrgentCabinetCareSubject.self()
    : type = UrgentCabinetCareSubjectType.self,
      familyMemberId = null;

  factory UrgentCabinetCareSubject.familyMember(String familyMemberId) {
    final normalizedId = familyMemberId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        familyMemberId,
        'familyMemberId',
        'A persisted family-member ID is required.',
      );
    }
    return UrgentCabinetCareSubject._(
      type: UrgentCabinetCareSubjectType.familyMember,
      familyMemberId: normalizedId,
    );
  }

  const UrgentCabinetCareSubject._({
    required this.type,
    required this.familyMemberId,
  });

  final UrgentCabinetCareSubjectType type;
  final String? familyMemberId;

  bool get isSelf => type == UrgentCabinetCareSubjectType.self;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UrgentCabinetCareSubject &&
            other.type == type &&
            other.familyMemberId == familyMemberId;
  }

  @override
  int get hashCode => Object.hash(type, familyMemberId);
}
