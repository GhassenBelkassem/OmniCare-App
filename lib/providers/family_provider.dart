import 'package:flutter/foundation.dart';
import '../core/api/family_api.dart';
import '../core/api/patients_api.dart';
import '../core/models/family_models.dart';
import '../core/utils/console_log.dart';

class FamilyProvider extends ChangeNotifier {
  final FamilyApi _api;
  final PatientsApi _patientsApi;

  FamilyProvider({FamilyApi? api, PatientsApi? patientsApi})
    : _api = api ?? FamilyApi(),
      _patientsApi = patientsApi ?? PatientsApi();

  List<FamilyMember> _members = [];
  bool _loading = false;
  String? _error;

  List<FamilyMember> get members => _members;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get hasMembers => _members.isNotEmpty;

  Future<void> loadFamilyMembers() async {
    consoleLog('[FamilyProvider] loadFamilyMembers() start');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      consoleLog('[FamilyProvider] Fetching family members from backend...');
      final familyMembers = await _api.getFamilyMembers();

      consoleLog('[FamilyProvider] Fetching patient IDs from backend...');
      final patients = await _patientsApi.getPatients();

      final patientMap = <String, String>{};
      for (final patient in patients) {
        if (patient.familyMemberId != null) {
          patientMap[patient.familyMemberId!] = patient.patientId;
        }
      }

      _members = familyMembers.map((member) {
        final patientId = patientMap[member.id];
        return FamilyMember(
          id: member.id,
          fullName: member.fullName,
          relationship: member.relationship,
          birthDate: member.birthDate,
          ageYears: member.ageYears,
          gender: member.gender,
          bloodGroup: member.bloodGroup,
          medicalInfo: member.medicalInfo,
          patientId: patientId,
        );
      }).toList();

      consoleLog(
        '[FamilyProvider] Loaded ${_members.length} family members with patient IDs',
      );
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[FamilyProvider] loadFamilyMembers() ERROR: $_error');
      consoleLog('[FamilyProvider] STACKTRACE: $st');
      _members = [];
    } finally {
      _loading = false;
      consoleLog(
        '[FamilyProvider] loadFamilyMembers() end. loading=$_loading error=$_error',
      );
      notifyListeners();
    }
  }

  Future<FamilyMember> addFamilyMember({
    required String fullName,
    required String relationship,
    required String birthDate,
    String? gender,
    Map<String, dynamic>? medicalInfo,
  }) async {
    consoleLog('[FamilyProvider] addFamilyMember() start: $fullName');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final newMember = await _api.createFamilyMember(
        fullName: fullName,
        relationship: relationship,
        birthDate: birthDate,
        gender: gender,
        medicalInfo: medicalInfo,
      );

      _members.add(newMember);
      consoleLog(
        '[FamilyProvider] Family member added successfully: ${newMember.id}',
      );
      return newMember;
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[FamilyProvider] addFamilyMember() ERROR: $_error');
      consoleLog('[FamilyProvider] STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<FamilyMember> updateFamilyMember({
    required String id,
    String? fullName,
    String? relationship,
    String? birthDate,
    String? gender,
    Map<String, dynamic>? medicalInfo,
  }) async {
    consoleLog('[FamilyProvider] updateFamilyMember() start: $id');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _api.updateFamilyMember(
        id: id,
        fullName: fullName,
        relationship: relationship,
        birthDate: birthDate,
        gender: gender,
        medicalInfo: medicalInfo,
      );

      final index = _members.indexWhere((m) => m.id == id);
      if (index != -1) {
        _members[index] = updated;
      }

      consoleLog('[FamilyProvider] Family member updated successfully: $id');
      return updated;
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[FamilyProvider] updateFamilyMember() ERROR: $_error');
      consoleLog('[FamilyProvider] STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteFamilyMember(String id) async {
    consoleLog('[FamilyProvider] deleteFamilyMember() start: $id');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.deleteFamilyMember(id);
      _members.removeWhere((m) => m.id == id);
      consoleLog('[FamilyProvider] Family member deleted successfully: $id');
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[FamilyProvider] deleteFamilyMember() ERROR: $_error');
      consoleLog('[FamilyProvider] STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<FamilyMember> updateMedicalPassport({
    required String id,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    consoleLog('[FamilyProvider] updateMedicalPassport() start: $id');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _api.patchMedicalPassport(
        id: id,
        bloodGroup: bloodGroup,
        medicalInfo: medicalInfo,
      );

      final index = _members.indexWhere((m) => m.id == id);
      if (index != -1) {
        _members[index] = updated;
      }

      consoleLog('[FamilyProvider] Medical passport updated successfully: $id');
      return updated;
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[FamilyProvider] updateMedicalPassport() ERROR: $_error');
      consoleLog('[FamilyProvider] STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    consoleLog('[FamilyProvider] clear() called');
    _members = [];
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
