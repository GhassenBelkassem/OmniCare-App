import '../../../core/models/family_models.dart';
import '../../../core/models/patient_profile.dart';
import '../../../l10n/omni_localizations.dart';
import '../data/medical_record_models.dart';
import '../models/patient_passport_view_models.dart';

/// Header, family selector and identity card from the real profile and family
/// (G2-1b-3b): never the « Sarah Ben Ahmed » fixture.

/// The account holder first, then each family member.
List<PassportFamilyMember> passportMembers({
  required PatientProfile? profile,
  required List<FamilyMember> family,
  required OmniLocalizations l10n,
}) => [
  PassportFamilyMember(
    name: _holderName(profile, l10n),
    relationship: l10n.passportSelfRelationship,
    avatarAsset: passportAvatarAsset(null),
    isSelf: true,
  ),
  for (final member in family)
    PassportFamilyMember(
      name: member.fullName.isEmpty
          ? l10n.medicalRecordNotRecorded
          : member.fullName,
      relationship: FamilyRelationships.frenchLabel(member.relationship),
      avatarAsset: passportAvatarAsset(member.id),
      familyMemberId: member.id,
    ),
];

/// The member shown: the one with [familyMemberId], else the account holder
/// (also when that family member no longer exists).
PassportFamilyMember selectedPassportMember(
  List<PassportFamilyMember> members,
  String? familyMemberId,
) => members.firstWhere(
  (member) => familyMemberId != null && member.familyMemberId == familyMemberId,
  orElse: () => members.first,
);

/// The record subject of [member]: SELF, or the family member's id.
RecordSubject recordSubjectOf(PassportFamilyMember member) {
  final familyMemberId = member.familyMemberId;
  return member.isSelf || familyMemberId == null
      ? const SelfRecordSubject()
      : FamilyRecordSubject(familyMemberId);
}

/// The identity card of [member]. Phone and e-mail are the account holder's
/// (the passport's contact); there is no real OmniCare ID yet, so that row
/// reads « Non renseigné ».
PatientPassportViewData passportIdentity({
  required PassportFamilyMember member,
  required PatientProfile? profile,
  required OmniLocalizations l10n,
}) {
  final notRecorded = l10n.medicalRecordNotRecorded;
  return PatientPassportViewData.identity(
    name: member.name,
    relationship: member.relationship,
    phone: _nonBlank(profile?.primaryPhone?.value) ?? notRecorded,
    email: _nonBlank(profile?.primaryEmail?.value) ?? notRecorded,
    omniCareId: notRecorded,
  );
}

/// Neutral illustrated avatar, same choice rule as the request flow's care
/// subject card (`care_subject_card.dart`): the account holder gets the first
/// one, a family member a stable one from its id.
String passportAvatarAsset(String? id) {
  const count = 12;
  var index = 0;
  if (id != null) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    index = hash % count;
  }
  return 'assets/images/avatars/lorelei/'
      'avatar_${(index + 1).toString().padLeft(2, '0')}.png';
}

String _holderName(PatientProfile? profile, OmniLocalizations l10n) =>
    _nonBlank(profile?.displayName) ??
    _nonBlank('${profile?.firstName ?? ''} ${profile?.lastName ?? ''}') ??
    l10n.medicalRecordNotRecorded;

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
