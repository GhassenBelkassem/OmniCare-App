import 'package:flutter/foundation.dart';
import '../core/models/account_models.dart';
import '../core/utils/console_log.dart';
import '../features/auth/data/models/auth_dtos.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository;

  UserProvider({UserRepository? repository})
    : _repository = repository ?? (UserRepository()..useMock());

  AccountFullProfile? _profile;
  bool _loading = false;
  String? _error;
  Future<void>? _refreshFuture;

  AccountFullProfile? get profile => _profile;
  AccountUser? get user => _profile?.user;
  List<AccountFamilyMember> get familyMembers =>
      _profile?.familyMembers ?? const [];

  bool get isLoading => _loading;
  String? get error => _error;

  void setPatientProfile(PatientProfileDto profile) {
    _profile = AccountFullProfile(
      user: AccountUser(
        email: '',
        name: profile.displayName,
        role: 'PATIENT',
        firstName: profile.firstName,
        lastName: profile.lastName,
        bloodGroup: profile.bloodType,
        medicalInfo: {
          'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
          'gender': profile.gender,
          'heightCm': profile.heightCm,
          'weightKg': profile.weightKg,
          'bmi': profile.bmi,
          'passportCompletion': profile.passportCompletion,
          'onboardingCompleted': profile.onboardingCompleted,
          'onboardingStep': profile.onboardingStep,
          'preferredLanguage': profile.preferredLanguage,
        },
        avatar: profile.photoUrl,
      ),
      familyMembers: const [],
      documents: const [],
    );
    _error = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> loadIfLoggedIn() async {
    consoleLog('[UserProvider] loadIfLoggedIn() called');
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshFuture != null) {
      consoleLog('[UserProvider] refresh() dedup: awaiting in-flight refresh');
      return _refreshFuture;
    }

    _refreshFuture = _refreshImpl();
    try {
      await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _refreshImpl() async {
    consoleLog('[UserProvider] refresh() start');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      consoleLog('[UserProvider] Fetching full profile from repository...');
      _profile = await _repository.getFullProfile();

      consoleLog('[UserProvider] Full profile loaded successfully');
      consoleLog('[UserProvider] user == null: ${user == null}');
      if (user != null) {
        consoleLog(
          '[UserProvider] user.email="${user!.email}" providerType="${user!.providerType}" providerId="${user!.providerId}"',
        );
        consoleLog('[UserProvider] user.displayName: "${user!.displayName}"');
        consoleLog(
          '[UserProvider] user.derivedFirstName: "${user!.derivedFirstName}"',
        );
        consoleLog(
          '[UserProvider] user.derivedLastName: "${user!.derivedLastName}"',
        );
      }
      consoleLog('[UserProvider] familyMembers count: ${familyMembers.length}');
      consoleLog(
        '[UserProvider] documents count: ${_profile?.documents.length ?? 0}',
      );
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[UserProvider] refresh() ERROR: $_error');
      consoleLog('[UserProvider] refresh() STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      consoleLog(
        '[UserProvider] refresh() end. loading=$_loading error=$_error',
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    consoleLog('[UserProvider] logout() called');
    _profile = null;
    _error = null;
    consoleLog('[UserProvider] logout() completed. Profile cleared.');
    notifyListeners();
  }
}
