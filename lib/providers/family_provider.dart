import 'package:flutter/foundation.dart';

import '../core/api/family_api.dart';
import '../core/models/blood_type.dart';
import '../core/models/family_models.dart';
import '../core/network/api_failure.dart';
import '../core/result/result.dart';
import '../core/utils/console_log.dart';
import '../repositories/family_repository.dart';

typedef FamilyChangedCallback = Future<void> Function();

class FamilyProvider extends ChangeNotifier {
  FamilyProvider({
    FamilyRepository? repository,
    FamilyChangedCallback? onFamilyChanged,
  }) : _repository = repository ?? FamilyRepository(api: FamilyApi()),
       _onFamilyChanged = onFamilyChanged;

  final FamilyRepository _repository;
  final FamilyChangedCallback? _onFamilyChanged;

  List<FamilyMember> _members = const [];
  bool _loading = false;
  bool _saving = false;
  ApiFailure? _loadFailure;
  ApiFailure? _mutationFailure;
  Map<String, ApiFieldErrorKind> _fieldErrors = const {};
  final Set<String> _deactivatingIds = {};
  Future<void>? _loadFuture;
  int _stateGeneration = 0;

  List<FamilyMember> get members => _members;
  bool get isLoading => _loading;
  bool get isSaving => _saving;

  /// Typed failures; screens turn them into French text
  /// (`apiFailureMessage`), never the server's.
  ApiFailure? get loadFailure => _loadFailure;
  ApiFailure? get mutationFailure => _mutationFailure;
  Map<String, ApiFieldErrorKind> get fieldErrors => _fieldErrors;
  bool get hasMembers => _members.isNotEmpty;
  bool isDeactivating(String id) => _deactivatingIds.contains(id);

  Future<void> loadFamilyMembers() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final operation = _loadFamilyMembers(_stateGeneration);
    _loadFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadFuture, operation)) _loadFuture = null;
    }
  }

  Future<void> _loadFamilyMembers(int generation) async {
    _loading = true;
    _loadFailure = null;
    notifyListeners();
    final result = await _repository.getFamilyMembers();
    if (generation != _stateGeneration) return;
    switch (result) {
      case Ok(:final value):
        _members = value;
      case Err(:final failure):
        _loadFailure = failure;
        consoleLog('[FamilyProvider] family list failed ${failure.logSummary}');
    }
    _loading = false;
    notifyListeners();
  }

  Future<FamilyMember> addFamilyMember({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) {
    return _runSave(
      () => _repository.createFamilyMember(
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        relationship: relationship,
        photoUrl: photoUrl,
      ),
      onSuccess: (member) {
        _members = List.unmodifiable([..._members, member]);
      },
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
    return _runSave(
      () => _repository.updateFamilyMember(
        id: id,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        relationship: relationship,
        photoUrl: photoUrl,
      ),
      onSuccess: (updated) {
        _members = List.unmodifiable(
          _members.map((member) => member.id == id ? updated : member),
        );
      },
    );
  }

  Future<void> deactivateFamilyMember(String id) async {
    if (_deactivatingIds.contains(id)) return;
    final generation = _stateGeneration;
    _deactivatingIds.add(id);
    _mutationFailure = null;
    _fieldErrors = const {};
    notifyListeners();
    try {
      final result = await _repository.deactivateFamilyMember(id);
      if (result case Err(:final failure)) {
        if (generation == _stateGeneration) _captureMutationFailure(failure);
        throw failure;
      }
      if (generation != _stateGeneration) return;
      _members = List.unmodifiable(_members.where((member) => member.id != id));
      await _refreshProfile();
    } finally {
      if (generation == _stateGeneration) {
        _deactivatingIds.remove(id);
        notifyListeners();
      }
    }
  }

  /// Throws the [ApiFailure] on failure (the caller shows the message).
  Future<void> updateMedicalPassport({
    required String id,
    required BloodType bloodType,
  }) async {
    final result = await _repository.patchMedicalPassport(
      id: id,
      bloodType: bloodType,
    );
    if (result case Err(:final failure)) throw failure;
  }

  void clearMutationError() {
    _mutationFailure = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  void clear() {
    _stateGeneration++;
    _loadFuture = null;
    _members = const [];
    _loading = false;
    _saving = false;
    _loadFailure = null;
    _mutationFailure = null;
    _fieldErrors = const {};
    _deactivatingIds.clear();
    notifyListeners();
  }

  /// Throws the [ApiFailure] on failure, after recording it.
  Future<FamilyMember> _runSave(
    Future<Result<FamilyMember>> Function() operation, {
    required ValueChanged<FamilyMember> onSuccess,
  }) async {
    if (_saving) throw StateError('A family update is already in progress.');
    final generation = _stateGeneration;
    _saving = true;
    _mutationFailure = null;
    _fieldErrors = const {};
    notifyListeners();
    try {
      final result = await operation();
      final member = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw _failed(failure, generation),
      };
      if (generation != _stateGeneration) return member;
      onSuccess(member);
      await _refreshProfile();
      return member;
    } finally {
      if (generation == _stateGeneration) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> _refreshProfile() async {
    try {
      await _onFamilyChanged?.call();
    } catch (_) {
      consoleLog('[FamilyProvider] profile refresh after family change failed');
    }
  }

  ApiFailure _failed(ApiFailure failure, int generation) {
    if (generation == _stateGeneration) _captureMutationFailure(failure);
    return failure;
  }

  void _captureMutationFailure(ApiFailure failure) {
    _mutationFailure = failure;
    _fieldErrors = failure.fieldErrors;
    consoleLog('[FamilyProvider] family mutation failed ${failure.logSummary}');
  }
}
