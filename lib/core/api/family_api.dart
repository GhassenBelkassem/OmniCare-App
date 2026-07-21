import '../../mock_data/mock_family_members.dart';
import '../models/family_models.dart';

class FamilyApi {
  FamilyApi({Object? dio});

  Future<List<FamilyMember>> getFamilyMembers() async {
    return createMockFamilyMembers();
  }

  Future<FamilyMember> createFamilyMember({
    required String fullName,
    String? firstName,
    String? lastName,
    required String relationship,
    String? relationshipDescription,
    String? phoneNumber,
    required String birthDate,
    String? gender,
    String? profilePictureUrl,
    String? profilePicturePublicId,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    return FamilyMember(
      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      relationship: relationship,
      relationshipDescription: relationshipDescription,
      phoneNumber: phoneNumber,
      birthDate: birthDate,
      gender: gender,
      bloodGroup: bloodGroup,
      medicalInfo: medicalInfo,
    );
  }

  Future<FamilyMember> updateFamilyMember({
    required String id,
    String? fullName,
    String? firstName,
    String? lastName,
    String? relationship,
    String? relationshipDescription,
    String? phoneNumber,
    String? birthDate,
    String? gender,
    String? profilePictureUrl,
    String? profilePicturePublicId,
    Map<String, dynamic>? medicalInfo,
  }) async {
    return FamilyMember(
      id: id,
      fullName: fullName ?? '',
      relationship: relationship ?? '',
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      gender: gender,
      medicalInfo: medicalInfo,
    );
  }

  Future<void> deleteFamilyMember(String id) async {}

  Future<FamilyMember> patchMedicalPassport({
    required String id,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    return FamilyMember(
      id: id,
      fullName: '',
      relationship: '',
      bloodGroup: bloodGroup,
      medicalInfo: medicalInfo,
    );
  }
}
