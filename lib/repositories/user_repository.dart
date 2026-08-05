import 'package:image_picker/image_picker.dart';

import '../core/api/account_api.dart';
import '../core/api/files_api.dart';
import '../core/models/patient_profile.dart';
import '../mock_data/mock_users.dart';

class UserRepository {
  AccountApi? _api;
  FilesApi? _filesApi;
  PatientProfile? _mockProfile;

  UserRepository({AccountApi? api, FilesApi? filesApi})
    : _api = api,
      _filesApi = filesApi;

  void useMock() {
    _api = null;
    _filesApi = null;
    _mockProfile ??= createMockProfile();
  }

  void useApi(AccountApi api, {FilesApi? filesApi}) {
    _api = api;
    if (filesApi != null) _filesApi = filesApi;
  }

  bool get isMock => _api == null;

  Future<PatientProfile> getProfile() async {
    if (_api == null) {
      return _mockProfile ??= createMockProfile();
    }
    return _api!.getPatientProfile();
  }

  Future<PatientProfile> updateProfile(PatientProfileUpdate update) async {
    if (_api == null) {
      final updated = update.applyTo(_mockProfile ??= createMockProfile());
      _mockProfile = updated;
      return updated;
    }
    return _api!.updateProfile(update);
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

  Future<PatientProfile> uploadAvatar(
    XFile file, {
    UploadProgressCallback? onProgress,
  }) async {
    if (_filesApi == null) {
      onProgress?.call(1, 1);
      final updated = (_mockProfile ??= createMockProfile()).copyWith(
        photoUrl: 'https://mock-storage.example.com/avatar.jpg',
      );
      _mockProfile = updated;
      return updated;
    }
    return _filesApi!.uploadAvatar(file: file, onProgress: onProgress);
  }

  Future<PatientProfile> removeAvatar() async {
    if (_filesApi == null) {
      final updated = (_mockProfile ??= createMockProfile()).copyWith(
        clearPhoto: true,
      );
      _mockProfile = updated;
      return updated;
    }
    return _filesApi!.removeAvatar();
  }

  Future<OnboardingStepResponseDto?> saveOnboardingStep(
    int step,
    Map<String, dynamic> data,
  ) async {
    if (_api == null) return null;
    return _api!.saveOnboardingStep(step, data);
  }
}
