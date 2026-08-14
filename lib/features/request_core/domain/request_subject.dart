import '../../../core/models/family_models.dart';
import 'request_vocabulary.dart';

/// Who a Module 05 request is for, as the client is allowed to express it.
///
/// # The identifier rule
///
/// `familyMemberId` is the **only** identifier this app may ever put in a
/// request subject, and it is a claim, not a grant: the backend re-resolves
/// ownership from the authenticated principal and the family tables.
///
/// These must never be sent, and this type makes that structurally impossible
/// because it has nowhere to put them:
///
/// * `FamilyMember.patientId` — the operational patient reference
/// * `mrsPatientId` — the medical-record reference
/// * `FamilyMember.accountHolderId` — the owning account
///
/// The legacy emergency flow does send `patientId`; that flow is untouched by
/// this milestone and is not a precedent for Module 05.
///
/// There is no "other person" subject in Module 05. A request is for the
/// account holder, or for one of their own family members.
class RequestSubject {
  const RequestSubject._(this.type, this.familyMemberId);

  /// The authenticated account holder is the patient.
  const RequestSubject.self() : this._(RequestSubjectType.self, null);

  /// A family member owned by the authenticated account holder.
  ///
  /// [familyMemberId] must be the family-member identifier, i.e.
  /// `FamilyMember.id`. Prefer [RequestSubject.forFamilyMember], which removes
  /// the opportunity to pass the wrong field.
  factory RequestSubject.familyMember(String familyMemberId) {
    final id = familyMemberId.trim();
    if (id.isEmpty) {
      throw const RequestContractException('Family member id is required.');
    }
    return RequestSubject._(RequestSubjectType.familyMember, id);
  }

  /// The safe way to build a family-member subject: the caller hands over the
  /// whole member and this factory picks the one legal field.
  factory RequestSubject.forFamilyMember(FamilyMember member) =>
      RequestSubject.familyMember(member.id);

  final RequestSubjectType type;

  /// Null for [RequestSubjectType.self]; always null on the wire in that case.
  final String? familyMemberId;

  bool get isSelf => type == RequestSubjectType.self;

  /// Request body fragment.
  ///
  /// For SELF the key is *omitted entirely* rather than sent as an explicit
  /// `null`: the server rejects a SELF subject that carries a family member
  /// value, and an absent key cannot be misread by any intermediary.
  Map<String, dynamic> toJson() {
    switch (type) {
      case RequestSubjectType.self:
        return const {'type': 'SELF'};
      case RequestSubjectType.familyMember:
        final id = familyMemberId;
        if (id == null || id.isEmpty) {
          throw const RequestContractException(
            'Family member subject is missing its identifier.',
          );
        }
        return {'type': 'FAMILY_MEMBER', 'familyMemberId': id};
      case RequestSubjectType.unknown:
        // Only ever produced by parsing a response. It must not be submitted.
        throw const RequestContractException(
          'Unknown subject type cannot be submitted.',
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RequestSubject &&
      other.type == type &&
      other.familyMemberId == familyMemberId;

  @override
  int get hashCode => Object.hash(type, familyMemberId);

  /// Never renders the family member identifier.
  @override
  String toString() => 'RequestSubject(${type.wireValue})';
}
