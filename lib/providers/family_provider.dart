import 'package:flutter/foundation.dart';
import '../core/api/family_api.dart';
import '../core/api/patients_api.dart';
import '../core/models/family_models.dart';
import '../core/utils/console_log.dart';

String _familyRelationshipUiToBackend(String ui) {
  final v = ui.trim();
  if (v.isEmpty) return v;
  return switch (v) {
    'Baba' => 'FATHER',
    'Maman' => 'MOTHER',
    'Mama' => 'MOTHER',
    'Enfant' => 'CHILD',
    'Fils' => 'CHILD',
    'Fille' => 'CHILD',
    'Grand-père' => 'GRANDFATHER',
    'Grand-mère' => 'GRANDMOTHER',
    'Frère' => 'SIBLING',
    'Sœur' => 'SIBLING',
    'Wife' => 'SPOUSE',
    'Husband' => 'SPOUSE',
    'Wife/Husband' => 'SPOUSE',
    'Brother' => 'SIBLING',
    'Sister' => 'SIBLING',
    'Brother/Sister' => 'SIBLING',
    'Oncle (Paternel)' => 'PATERNAL_UNCLE',
    'Oncle (Maternel)' => 'MATERNAL_UNCLE',
    'Tante (Paternelle)' => 'PATERNAL_AUNT',
    'Tante (Maternelle)' => 'MATERNAL_AUNT',
    'Cousin (Paternel)' => 'PATERNAL_COUSIN_MALE',
    'Cousin (Maternel)' => 'MATERNAL_COUSIN_MALE',
    'Cousine (Paternelle)' => 'PATERNAL_COUSIN_FEMALE',
    'Cousine (Maternelle)' => 'MATERNAL_COUSIN_FEMALE',
    'Autre' => 'OTHER',
    _ => v,
  };
}

String _familyRelationshipBackendToUi(String backend) {
  final v = backend.trim();
  if (v.isEmpty) return v;
  return switch (v) {
    'FATHER' => 'Baba',
    'MOTHER' => 'Maman',
    'CHILD' => 'Fils',
    'GRANDFATHER' => 'Grand-père',
    'GRANDMOTHER' => 'Grand-mère',
    'SIBLING' => 'Frère',
    'SPOUSE' => 'Autre',
    'OTHER' => 'Autre',
    'PATERNAL_UNCLE' => 'Oncle (Paternel)',
    'MATERNAL_UNCLE' => 'Oncle (Maternel)',
    'PATERNAL_AUNT' => 'Tante (Paternelle)',
    'MATERNAL_AUNT' => 'Tante (Maternelle)',
    'PATERNAL_COUSIN_MALE' => 'Cousin (Paternel)',
    'MATERNAL_COUSIN_MALE' => 'Cousin (Maternel)',
    'PATERNAL_COUSIN_FEMALE' => 'Cousine (Paternelle)',
    'MATERNAL_COUSIN_FEMALE' => 'Cousine (Maternelle)',
    _ => v,
  };
}

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

      _members = familyMembers
          .map(
            (m) => FamilyMember(
              id: m.id,
              fullName: m.fullName,
              firstName: m.firstName,
              lastName: m.lastName,
              relationship: _familyRelationshipBackendToUi(m.relationship),
              relationshipDescription: m.relationshipDescription,
              phoneNumber: m.phoneNumber,
              birthDate: m.birthDate,
              ageYears: m.ageYears,
              gender: m.gender,
              bloodGroup: m.bloodGroup,
              medicalInfo: m.medicalInfo,
              patientId: m.patientId,
            ),
          )
          .toList();
      consoleLog('[FamilyProvider] Loaded ${_members.length} family members');

      try {
        consoleLog('[FamilyProvider] Fetching patient IDs from backend...');
        final patients = await _patientsApi.getPatients();

        final patientMap = <String, String>{};
        for (final patient in patients) {
          if (patient.familyMemberId != null) {
            patientMap[patient.familyMemberId!] = patient.patientId;
          }
        }

        _members = _members.map((member) {
          final patientId = patientMap[member.id];
          return FamilyMember(
            id: member.id,
            fullName: member.fullName,
            firstName: member.firstName,
            lastName: member.lastName,
            relationship: member.relationship,
            relationshipDescription: member.relationshipDescription,
            phoneNumber: member.phoneNumber,
            birthDate: member.birthDate,
            ageYears: member.ageYears,
            gender: member.gender,
            bloodGroup: member.bloodGroup,
            medicalInfo: member.medicalInfo,
            patientId: patientId,
          );
        }).toList();

        consoleLog(
          '[FamilyProvider] Linked patient IDs for ${_members.length} family members',
        );
      } catch (e, st) {
        consoleLog('[FamilyProvider] Patient ID lookup failed (non-fatal): $e');
        consoleLog('[FamilyProvider] Patient ID lookup STACKTRACE: $st');
      }
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
    String? firstName,
    String? lastName,
    required String relationship,
    String? relationshipDescription,
    String? phoneNumber,
    required String birthDate,
    String? gender,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    consoleLog('[FamilyProvider] addFamilyMember() start: $fullName');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final backendRelationship = _familyRelationshipUiToBackend(relationship);
      final newMember = await _api.createFamilyMember(
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
        relationship: backendRelationship,
        relationshipDescription: relationshipDescription,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
        medicalInfo: medicalInfo,
      );

      if (bloodGroup != null && bloodGroup.trim().isNotEmpty) {
        try {
          await _api.patchMedicalPassport(
            id: newMember.id,
            bloodGroup: bloodGroup,
          );
        } catch (e, st) {
          consoleLog(
            '[FamilyProvider] bloodGroup patch failed (non-fatal): $e',
          );
          consoleLog('[FamilyProvider] bloodGroup patch STACKTRACE: $st');
        }
      }

      await loadFamilyMembers();

      final created = _members.where((m) => m.id == newMember.id).toList();
      final resolvedPatientId = created.isNotEmpty
          ? created.first.patientId
          : null;
      final chronicRaw = medicalInfo?['chronicConditions'];
      final chronic = (chronicRaw is List)
          ? chronicRaw
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
          : const <String>[];

      final medsRaw = medicalInfo?['currentMedications'];
      final meds = (medsRaw is List)
          ? medsRaw
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList()
          : const <Map<String, dynamic>>[];

      if (resolvedPatientId != null && resolvedPatientId.trim().isNotEmpty) {
        for (final c in chronic) {
          try {
            await _patientsApi.addPatientCondition(
              patientId: resolvedPatientId,
              name: c,
            );
          } catch (e, st) {
            consoleLog(
              '[FamilyProvider] addPatientCondition failed (non-fatal): $e',
            );
            consoleLog('[FamilyProvider] addPatientCondition STACKTRACE: $st');
          }
        }

        for (final m in meds) {
          final medicationId =
              (m['medicationId'] ??
                      m['medication_id'] ??
                      m['id'] ??
                      m['medication']?['id'])
                  ?.toString()
                  .trim();
          if (medicationId == null || medicationId.isEmpty) {
            continue;
          }

          try {
            final dosageOrNotes = (m['dosage'] ?? m['notes'])?.toString();
            await _patientsApi.addPatientMedication(
              patientId: resolvedPatientId,
              medicationId: medicationId,
              frequency: m['frequency']?.toString(),
              notes: dosageOrNotes,
            );
          } catch (e, st) {
            consoleLog(
              '[FamilyProvider] addPatientMedication failed (non-fatal): $e',
            );
            consoleLog('[FamilyProvider] addPatientMedication STACKTRACE: $st');
          }
        }
      }

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

  Future<FamilyMember> addFamilyMemberModel(FamilyMember member) {
    return addFamilyMember(
      fullName: member.fullName,
      firstName: member.firstName,
      lastName: member.lastName,
      relationship: member.relationship,
      relationshipDescription: member.relationshipDescription,
      phoneNumber: member.phoneNumber,
      birthDate: member.birthDate ?? '',
      gender: member.gender,
      bloodGroup: member.bloodGroup,
      medicalInfo: member.medicalInfo,
    );
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
      final backendRelationship = relationship == null
          ? null
          : _familyRelationshipUiToBackend(relationship);
      final updated = await _api.updateFamilyMember(
        id: id,
        fullName: fullName,
        relationship: backendRelationship,
        birthDate: birthDate,
        gender: gender,
        medicalInfo: medicalInfo,
      );

      final uiUpdated = FamilyMember(
        id: updated.id,
        fullName: updated.fullName,
        firstName: updated.firstName,
        lastName: updated.lastName,
        relationship: _familyRelationshipBackendToUi(updated.relationship),
        relationshipDescription: updated.relationshipDescription,
        phoneNumber: updated.phoneNumber,
        birthDate: updated.birthDate,
        ageYears: updated.ageYears,
        gender: updated.gender,
        bloodGroup: updated.bloodGroup,
        medicalInfo: updated.medicalInfo,
        patientId: updated.patientId,
      );

      final index = _members.indexWhere((m) => m.id == id);
      if (index != -1) {
        _members[index] = uiUpdated;
      }

      consoleLog('[FamilyProvider] Family member updated successfully: $id');
      return uiUpdated;
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

      final resolvedPatientId = updated.patientId;
      if (resolvedPatientId != null && resolvedPatientId.trim().isNotEmpty) {
        final chronicRaw = medicalInfo?['chronicConditions'];
        final chronic = (chronicRaw is List)
            ? chronicRaw
                  .map((e) => e.toString())
                  .where((e) => e.trim().isNotEmpty)
                  .toList()
            : const <String>[];

        for (final c in chronic) {
          try {
            await _patientsApi.addPatientCondition(
              patientId: resolvedPatientId,
              name: c,
            );
          } catch (e, st) {
            consoleLog(
              '[FamilyProvider] addPatientCondition failed (non-fatal): $e',
            );
            consoleLog('[FamilyProvider] addPatientCondition STACKTRACE: $st');
          }
        }

        final medsRaw = medicalInfo?['currentMedications'];
        final meds = (medsRaw is List)
            ? medsRaw
                  .whereType<Map>()
                  .map((e) => e.cast<String, dynamic>())
                  .toList()
            : const <Map<String, dynamic>>[];

        for (final m in meds) {
          final medicationId =
              (m['medicationId'] ??
                      m['medication_id'] ??
                      m['id'] ??
                      m['medication']?['id'])
                  ?.toString()
                  .trim();
          if (medicationId == null || medicationId.isEmpty) {
            continue;
          }

          try {
            final dosageOrNotes = (m['dosage'] ?? m['notes'])?.toString();
            await _patientsApi.addPatientMedication(
              patientId: resolvedPatientId,
              medicationId: medicationId,
              frequency: m['frequency']?.toString(),
              notes: dosageOrNotes,
            );
          } catch (e, st) {
            consoleLog(
              '[FamilyProvider] addPatientMedication failed (non-fatal): $e',
            );
            consoleLog('[FamilyProvider] addPatientMedication STACKTRACE: $st');
          }
        }
      }

      final uiUpdated = FamilyMember(
        id: updated.id,
        fullName: updated.fullName,
        firstName: updated.firstName,
        lastName: updated.lastName,
        relationship: _familyRelationshipBackendToUi(updated.relationship),
        relationshipDescription: updated.relationshipDescription,
        phoneNumber: updated.phoneNumber,
        birthDate: updated.birthDate,
        ageYears: updated.ageYears,
        gender: updated.gender,
        bloodGroup: updated.bloodGroup,
        medicalInfo: updated.medicalInfo,
        patientId: updated.patientId,
      );

      final index = _members.indexWhere((m) => m.id == id);
      if (index != -1) {
        _members[index] = uiUpdated;
      }

      consoleLog('[FamilyProvider] Medical passport updated successfully: $id');
      return uiUpdated;
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
