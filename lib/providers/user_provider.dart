import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/account_models.dart';
import '../core/models/patient_profile.dart';
import '../core/network/api_exception.dart';
import '../core/utils/console_log.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({UserRepository? repository})
    : _repository = repository ?? (UserRepository()..useMock());

  final UserRepository _repository;

  PatientProfile? _profile;
  AccountUser? _accountIdentity;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;
  String? _saveError;
  Map<String, String> _saveFieldErrors = const {};
  bool _avatarUploading = false;
  double? _avatarUploadProgress;
  String? _avatarError;
  XFile? _pendingAvatarFile;
  Future<void>? _refreshFuture;

  PatientProfile? get profile => _profile;

  // Compatibility view for screens that only need account identity.
  AccountUser? get user => _accountIdentity;

  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get loadError => _loadError;
  String? get saveError => _saveError;
  Map<String, String> get saveFieldErrors => _saveFieldErrors;
  bool get isAvatarUploading => _avatarUploading;
  double? get avatarUploadProgress => _avatarUploadProgress;
  String? get avatarError => _avatarError;
  bool get canRetryAvatar => _pendingAvatarFile != null && !_avatarUploading;
  String? get error => _loadError ?? _saveError;

  void setPatientProfile(PatientProfile profile) {
    _acceptProfile(profile);
    _loadError = null;
    _saveError = null;
    _saveFieldErrors = const {};
    _avatarUploading = false;
    _avatarUploadProgress = null;
    _avatarError = null;
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
    _loadError = null;
    notifyListeners();

    try {
      _acceptProfile(await _repository.getProfile());
    } catch (error) {
      _loadError = _safeMessage(
        error,
        fallback: 'Impossible de charger le profil.',
      );
      consoleLog('[UserProvider] profile refresh failed');
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
    _saveError = null;
    _saveFieldErrors = const {};
    notifyListeners();

    try {
      final saved = await _repository.updateProfile(update);
      _acceptProfile(saved);
      return saved;
    } catch (error) {
      if (error is ApiException) {
        _saveFieldErrors = Map.unmodifiable(error.fieldErrors);
      }
      _saveError = _safeMessage(
        error,
        fallback: 'Impossible d’enregistrer les modifications.',
      );
      consoleLog('[UserProvider] profile update failed');
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
    if (_avatarError == null) return;
    _avatarError = null;
    _pendingAvatarFile = null;
    notifyListeners();
  }

  void reportAvatarSelectionFailure() {
    _avatarError = 'Impossible d’accéder à cette image.';
    _pendingAvatarFile = null;
    notifyListeners();
  }

  void clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    _saveFieldErrors = const {};
    notifyListeners();
  }

  Future<void> logout() async {
    _profile = null;
    _accountIdentity = null;
    _loadError = null;
    _saveError = null;
    _saveFieldErrors = const {};
    _loading = false;
    _saving = false;
    _avatarUploading = false;
    _avatarUploadProgress = null;
    _avatarError = null;
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
    _avatarError = null;
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
      _avatarError = _safeMessage(
        error,
        fallback: 'Impossible de modifier la photo de profil.',
      );
      consoleLog('[UserProvider] avatar update failed');
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
  if (error is! ApiException) return true;
  final statusCode = error.statusCode;
  return error.code == 'NETWORK_REQUEST_FAILED' ||
      error.code == 'OBJECT_STORAGE_UNAVAILABLE' ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode >= 500);
}

String _safeMessage(Object error, {required String fallback}) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return fallback;
}
