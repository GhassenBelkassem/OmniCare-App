import '../core/api/account_api.dart';
import '../core/models/account_models.dart';
import '../mock_data/mock_users.dart';

class UserRepository {
  AccountApi? _api;

  UserRepository({AccountApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(AccountApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<AccountFullProfile> getFullProfile() async {
    if (_api == null) {
      return createMockProfile();
    }
    return _api!.getFullProfile();
  }

  Future<void> patchMedicalPassport({
    String? bloodGroup,
    int? heightCm,
    double? weightKg,
    Map<String, dynamic>? medicalInfo,
  }) async {
    if (_api == null) return;
    await _api!.patchMedicalPassport(
      bloodGroup: bloodGroup,
      heightCm: heightCm,
      weightKg: weightKg,
      medicalInfo: medicalInfo,
    );
  }

  Future<void> patchProfilePicture({
    required String profilePictureUrl,
    String? profilePicturePublicId,
  }) async {
    if (_api == null) return;
    await _api!.patchProfilePicture(
      profilePictureUrl: profilePictureUrl,
      profilePicturePublicId: profilePicturePublicId,
    );
  }

  Future<OnboardingStepResponseDto?> saveOnboardingStep(
    int step,
    Map<String, dynamic> data,
  ) async {
    if (_api == null) return null;
    return _api!.saveOnboardingStep(step, data);
  }
}
