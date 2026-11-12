import '../core/api/family_api.dart';
import '../core/models/blood_type.dart';
import '../core/models/family_models.dart';
import '../core/result/result.dart';

/// Family members of the signed-in account. Every call returns a [Result]:
/// the value, or the parsed backend failure (G-2 1b-2).
class FamilyRepository {
  const FamilyRepository({required FamilyApi api}) : _api = api;

  final FamilyApi _api;

  Future<Result<List<FamilyMember>>> getFamilyMembers() =>
      guardApiCall(_api.getFamilyMembers);

  Future<Result<FamilyMember>> createFamilyMember({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) => guardApiCall(
    () => _api.createFamilyMember(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      relationship: relationship,
      photoUrl: photoUrl,
    ),
  );

  Future<Result<FamilyMember>> updateFamilyMember({
    required String id,
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) => guardApiCall(
    () => _api.updateFamilyMember(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      relationship: relationship,
      photoUrl: photoUrl,
    ),
  );

  Future<Result<void>> deactivateFamilyMember(String id) =>
      guardApiCall(() => _api.deactivateFamilyMember(id));

  Future<Result<void>> patchMedicalPassport({
    required String id,
    required BloodType bloodType,
  }) => guardApiCall(
    () => _api.patchMedicalPassport(id: id, bloodType: bloodType),
  );
}
