import 'package:image_picker/image_picker.dart';

import '../core/api/account_api.dart';
import '../core/api/files_api.dart';
import '../core/models/patient_profile.dart';
import '../core/network/api_failure.dart';

/// The patient's own profile and avatar. Without its APIs (only possible
/// outside the production wiring in `main.dart`), every call fails with
/// [ApiFailure.featureUnavailable]: there is no mock profile any more
/// (G-2 1b-3).
class UserRepository {
  AccountApi? _api;
  FilesApi? _filesApi;

  UserRepository({AccountApi? api, FilesApi? filesApi})
    : _api = api,
      _filesApi = filesApi;

  void useApi(AccountApi api, {FilesApi? filesApi}) {
    _api = api;
    if (filesApi != null) _filesApi = filesApi;
  }

  Future<PatientProfile> getProfile() async {
    final api = _api;
    if (api == null) throw ApiFailure.featureUnavailable;
    return api.getPatientProfile();
  }

  Future<PatientProfile> updateProfile(PatientProfileUpdate update) async {
    final api = _api;
    if (api == null) throw ApiFailure.featureUnavailable;
    return api.updateProfile(update);
  }

  Future<PatientProfile> uploadAvatar(
    XFile file, {
    UploadProgressCallback? onProgress,
  }) async {
    final filesApi = _filesApi;
    if (filesApi == null) throw ApiFailure.featureUnavailable;
    return filesApi.uploadAvatar(file: file, onProgress: onProgress);
  }

  Future<PatientProfile> removeAvatar() async {
    final filesApi = _filesApi;
    if (filesApi == null) throw ApiFailure.featureUnavailable;
    return filesApi.removeAvatar();
  }

  Future<OnboardingStepResponseDto?> saveOnboardingStep(
    int step,
    Map<String, dynamic> data,
  ) async {
    final api = _api;
    if (api == null) throw ApiFailure.featureUnavailable;
    return api.saveOnboardingStep(step, data);
  }
}
