import '../core/api/family_api.dart';
import '../core/models/family_models.dart';

class FamilyRepository {
  const FamilyRepository({required FamilyApi api}) : _api = api;

  final FamilyApi _api;

  Future<List<FamilyMember>> getFamilyMembers() => _api.getFamilyMembers();

  Future<FamilyMember> createFamilyMember({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) {
    return _api.createFamilyMember(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      relationship: relationship,
      photoUrl: photoUrl,
    );
  }

  Future<FamilyMember> updateFamilyMember({
    required String id,
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) {
    return _api.updateFamilyMember(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      relationship: relationship,
      photoUrl: photoUrl,
    );
  }

  Future<void> deactivateFamilyMember(String id) {
    return _api.deactivateFamilyMember(id);
  }

  Future<void> patchMedicalPassport({required String id, String? bloodGroup}) {
    return _api.patchMedicalPassport(id: id, bloodGroup: bloodGroup);
  }
}
