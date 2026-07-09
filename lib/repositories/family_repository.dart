import '../core/api/family_api.dart';
import '../core/models/family_models.dart';
import '../mock_data/mock_family_members.dart';

class FamilyRepository {
  FamilyApi? _api;

  FamilyRepository({FamilyApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(FamilyApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<List<FamilyMember>> getFamilyMembers() async {
    if (_api == null) return createMockFamilyMembers();
    return _api!.getFamilyMembers();
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
    if (_api == null) {
      return FamilyMember(
        id: 'new-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
        relationship: relationship,
        relationshipDescription: relationshipDescription,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        ageYears: null,
        gender: gender,
        profilePictureUrl: profilePictureUrl,
        profilePicturePublicId: profilePicturePublicId,
        bloodGroup: bloodGroup,
        medicalInfo: medicalInfo,
        patientId: null,
      );
    }
    return _api!.createFamilyMember(
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      relationship: relationship,
      relationshipDescription: relationshipDescription,
      phoneNumber: phoneNumber,
      birthDate: birthDate,
      gender: gender,
      profilePictureUrl: profilePictureUrl,
      profilePicturePublicId: profilePicturePublicId,
      bloodGroup: bloodGroup,
      medicalInfo: medicalInfo,
    );
  }

  Future<FamilyMember> updateFamilyMember({
    required String id,
    String? fullName,
    String? relationship,
    String? birthDate,
    String? gender,
    Map<String, dynamic>? medicalInfo,
  }) async {
    if (_api == null) {
      return FamilyMember(
        id: id,
        fullName: fullName ?? '',
        relationship: relationship ?? '',
        birthDate: birthDate,
        gender: gender,
        medicalInfo: medicalInfo,
        patientId: null,
      );
    }
    return _api!.updateFamilyMember(
      id: id,
      fullName: fullName,
      relationship: relationship,
      birthDate: birthDate,
      gender: gender,
      medicalInfo: medicalInfo,
    );
  }

  Future<void> deleteFamilyMember(String id) async {
    if (_api == null) return;
    await _api!.deleteFamilyMember(id);
  }

  Future<FamilyMember> patchMedicalPassport({
    required String id,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    if (_api == null) {
      return FamilyMember(
        id: id,
        fullName: '',
        relationship: '',
        bloodGroup: bloodGroup,
        medicalInfo: medicalInfo,
        patientId: null,
      );
    }
    return _api!.patchMedicalPassport(
      id: id,
      bloodGroup: bloodGroup,
      medicalInfo: medicalInfo,
    );
  }
}
