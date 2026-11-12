import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/account_models.dart';
import '../core/models/patient_profile.dart';
import '../core/network/api_failure.dart';
import '../core/utils/console_log.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({UserRepository? repository})
    : _repository = repository ?? UserRepository();

  final UserRepository _repository;

  PatientProfile? _profile;
  AccountUser? _accountIdentity;
  bool _loading = false;
  bool _saving = false;
  ApiFailure? _loadFailure;
  ApiFailure? _saveFailure;
  Map<String, ApiFieldErrorKind> _saveFieldErrors = const {};
  bool _avatarUploading = false;
  double? _avatarUploadProgress;
  ApiFailure? _avatarFailure;
  bool _avatarSelectionFailed = false;
  XFile? _pendingAvatarFile;
  Future<void>? _refreshFuture;

  PatientProfile? get profile => _profile;

  // Compatibility view for screens that only need account identity.
  AccountUser? get user => _accountIdentity;

  bool get isLoading => _loading;
  bool get isSaving => _saving;

  /// Failures are typed; the screen turns them into French text
  /// (`apiFailureMessage`), never the server's.
  ApiFailure? get loadFailure => _loadFailure;
  ApiFailure? get saveFailure => _saveFailure;
  Map<String, ApiFieldErrorKind> get saveFieldErrors => _saveFieldErrors;
  bool get isAvatarUploading => _avatarUploading;
  double? get avatarUploadProgress => _avatarUploadProgress;
  ApiFailure? get avatarFailure => _avatarFailure;

  /// The picked image could not be read (no backend call).
  bool get avatarSelectionFailed => _avatarSelectionFailed;
  bool get hasAvatarError => _avatarFailure != null || _avatarSelectionFailed;
  bool get canRetryAvatar => _pendingAvatarFile != null && !_avatarUploading;

  void setPatientProfile(PatientProfile profile) {
    _acceptProfile(profile);
    _loadFailure = null;
    _saveFailure = null;
    _saveFieldErrors = const {};
    _avatarUploading = false;
    _avatarUploadProgress = null;
    _avatarFailure = null;
    _avatarSelectionFailed = false;
    _pendingAvatarFile = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> loadIfLoggedIn() => refresh();

  Future<void> refresh() async {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final operation = _refreshImpl();
    _refreshFuture = operation;
    try {
      await operation;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _refreshImpl() async {
    _loading = true;
    _loadFailure = null;
    notifyListeners();

    try {
      _acceptProfile(await _repository.getProfile());
    } catch (error) {
      final failure = _loadFailure = ApiFailure.from(error);
      consoleLog('[UserProvider] profile refresh failed ${failure.logSummary}');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<PatientProfile> updateProfile(PatientProfileUpdate update) async {
    if (_saving || _avatarUploading) {
      throw StateError('A profile update is already in progress.');
    }

    _saving = true;
    _saveFailure = null;
    _saveFieldErrors = const {};
    notifyListeners();

    try {
      final saved = await _repository.updateProfile(update);
      _acceptProfile(saved);
      return saved;
    } catch (error) {
      final failure = _saveFailure = ApiFailure.from(error);
      _saveFieldErrors = failure.fieldErrors;
      consoleLog('[UserProvider] profile update failed ${failure.logSummary}');
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<PatientProfile> updatePreferences({
    String? preferredLanguage,
    bool? notificationMedications,
    bool? notificationAppointments,
    bool? notificationPassport,
  }) {
    return updateProfile(
      PatientProfileUpdate(
        preferredLanguage: preferredLanguage,
        notificationMedications: notificationMedications,
        notificationAppointments: notificationAppointments,
        notificationPassport: notificationPassport,
      ),
    );
  }

  Future<PatientProfile> updatePersonalInformation({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
  }) {
    return updateProfile(
      PatientProfileUpdate(
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        gender: gender,
      ),
    );
  }

  Future<PatientProfile> uploadAvatar(XFile file) {
    if (_avatarUploading || _saving) {
      throw StateError('A profile update is already in progress.');
    }
    _pendingAvatarFile = file;
    return _runAvatarMutation(
      () => _repository.uploadAvatar(file, onProgress: _onAvatarProgress),
      clearPendingOnSuccess: true,
    );
  }

  Future<PatientProfile> retryAvatarUpload() {
    final file = _pendingAvatarFile;
    if (file == null) {
      throw StateError('No avatar upload is available to retry.');
    }
    return _runAvatarMutation(
      () => _repository.uploadAvatar(file, onProgress: _onAvatarProgress),
      clearPendingOnSuccess: true,
    );
  }

  Future<PatientProfile> removeAvatar() {
    _pendingAvatarFile = null;
    return _runAvatarMutation(_repository.removeAvatar);
  }

  void clearAvatarError() {
    if (!hasAvatarError) return;
    _avatarFailure = null;
    _avatarSelectionFailed = false;
    _pendingAvatarFile = null;
    notifyListeners();
  }

  void reportAvatarSelectionFailure() {
    _avatarFailure = null;
    _avatarSelectionFailed = true;
    _pendingAvatarFile = null;
    notifyListeners();
  }

  void clearSaveError() {
    if (_saveFailure == null) return;
    _saveFailure = null;
    _saveFieldErrors = const {};
    notifyListeners();
  }

  Future<void> logout() async {
    _profile = null;
    _accountIdentity = null;
    _loadFailure = null;
    _saveFailure = null;
    _saveFieldErrors = const {};
    _loading = false;
    _saving = false;
    _avatarUploading = false;
    _avatarUploadProgress = null;
    _avatarFailure = null;
    _avatarSelectionFailed = false;
    _pendingAvatarFile = null;
    notifyListeners();
  }

  void _acceptProfile(PatientProfile profile) {
    _profile = profile;
    _accountIdentity = AccountUser(
      email: profile.primaryEmail?.value ?? '',
      name: profile.displayName,
      role: 'PATIENT',
      firstName: profile.firstName,
      lastName: profile.lastName,
      phoneNumber: profile.primaryPhone?.value,
      avatar: profile.photoUrl,
    );
  }

  Future<PatientProfile> _runAvatarMutation(
    Future<PatientProfile> Function() operation, {
    bool clearPendingOnSuccess = false,
  }) async {
    if (_avatarUploading || _saving) {
      throw StateError('A profile update is already in progress.');
    }

    _avatarUploading = true;
    _avatarUploadProgress = 0;
    _avatarFailure = null;
    _avatarSelectionFailed = false;
    notifyListeners();
    try {
      final saved = await operation();
      _acceptProfile(saved);
      if (clearPendingOnSuccess) _pendingAvatarFile = null;
      return saved;
    } catch (error) {
      if (!_isRetryableAvatarError(error)) {
        _pendingAvatarFile = null;
      }
      final failure = _avatarFailure = ApiFailure.from(error);
      consoleLog('[UserProvider] avatar update failed ${failure.logSummary}');
      rethrow;
    } finally {
      _avatarUploading = false;
      _avatarUploadProgress = null;
      notifyListeners();
    }
  }

  void _onAvatarProgress(int sentBytes, int totalBytes) {
    if (!_avatarUploading || totalBytes <= 0) return;
    final progress = (sentBytes / totalBytes).clamp(0.0, 1.0).toDouble();
    final previous = _avatarUploadProgress ?? 0;
    if (progress < 1 && progress - previous < 0.02) return;
    _avatarUploadProgress = progress;
    notifyListeners();
  }
}

bool _isRetryableAvatarError(Object error) {
  final failure = ApiFailure.from(error);
  return switch (failure.kind) {
    ApiFailureKind.network ||
    ApiFailureKind.timeout ||
    ApiFailureKind.rateLimited ||
    ApiFailureKind.server => true,
    ApiFailureKind.unknown => failure.statusCode == null,
    _ => failure.code == 'OBJECT_STORAGE_UNAVAILABLE',
  };
}
