import 'package:flutter/foundation.dart';

import '../core/api/family_api.dart';
import '../core/models/family_models.dart';
import '../core/network/api_exception.dart';
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
  String? _error;
  String? _mutationError;
  Map<String, String> _fieldErrors = const {};
  final Set<String> _deactivatingIds = {};
  Future<void>? _loadFuture;
  int _stateGeneration = 0;

  List<FamilyMember> get members => _members;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get error => _error;
  String? get mutationError => _mutationError;
  Map<String, String> get fieldErrors => _fieldErrors;
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
    _error = null;
    notifyListeners();
    try {
      final members = await _repository.getFamilyMembers();
      if (generation != _stateGeneration) return;
      _members = members;
    } catch (error) {
      if (generation != _stateGeneration) return;
      _error = _message(error, 'Impossible de charger les membres.');
      consoleLog('[FamilyProvider] family list failed');
    } finally {
      if (generation == _stateGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
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
    _mutationError = null;
    _fieldErrors = const {};
    notifyListeners();
    try {
      await _repository.deactivateFamilyMember(id);
      if (generation != _stateGeneration) return;
      _members = List.unmodifiable(_members.where((member) => member.id != id));
      await _refreshProfile();
    } catch (error) {
      if (generation != _stateGeneration) rethrow;
      _captureMutationError(error);
      rethrow;
    } finally {
      if (generation == _stateGeneration) {
        _deactivatingIds.remove(id);
        notifyListeners();
      }
    }
  }

  Future<void> updateMedicalPassport({required String id, String? bloodGroup}) {
    return _repository.patchMedicalPassport(id: id, bloodGroup: bloodGroup);
  }

  void clearMutationError() {
    _mutationError = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  void clear() {
    _stateGeneration++;
    _loadFuture = null;
    _members = const [];
    _loading = false;
    _saving = false;
    _error = null;
    _mutationError = null;
    _fieldErrors = const {};
    _deactivatingIds.clear();
    notifyListeners();
  }

  Future<FamilyMember> _runSave(
    Future<FamilyMember> Function() operation, {
    required ValueChanged<FamilyMember> onSuccess,
  }) async {
    if (_saving) throw StateError('A family update is already in progress.');
    final generation = _stateGeneration;
    _saving = true;
    _mutationError = null;
    _fieldErrors = const {};
    notifyListeners();
    try {
      final member = await operation();
      if (generation != _stateGeneration) return member;
      onSuccess(member);
      await _refreshProfile();
      return member;
    } catch (error) {
      if (generation != _stateGeneration) rethrow;
      _captureMutationError(error);
      rethrow;
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

  void _captureMutationError(Object error) {
    if (error is ApiException) {
      _fieldErrors = Map.unmodifiable(error.fieldErrors);
    }
    _mutationError = _message(error, 'Impossible d’enregistrer le membre.');
    consoleLog('[FamilyProvider] family mutation failed');
  }
}

String _message(Object error, String fallback) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return fallback;
}
