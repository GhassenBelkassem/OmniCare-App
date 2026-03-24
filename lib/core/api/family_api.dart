import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/family_models.dart';
import 'dio_client.dart';

class FamilyApi {
  final Dio _dio;

  FamilyApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<FamilyMember>> getFamilyMembers() async {
    debugPrint('[FamilyApi] getFamilyMembers() -> GET /api/family');
    final response = await _dio.get('/family');
    debugPrint('[FamilyApi] Response status: ${response.statusCode}');

    final raw = response.data;

    if (raw is Map && raw['data'] is List) {
      final list = (raw['data'] as List);
      return list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    throw StateError('Unexpected /api/family response: ${response.data}');
  }

  Future<FamilyMember> createFamilyMember({
    required String fullName,
    String? firstName,
    String? lastName,
    required String relationship,
    String? relationshipDescription,
    String? phoneNumber,
    required String birthDate,
    String? gender,
    String? profilePictureUrl,
    String? profilePicturePublicId,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    debugPrint('[FamilyApi] createFamilyMember() -> POST /api/family');

    final payload = {
      'fullName': fullName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      'relationship': relationship,
      if (relationshipDescription != null)
        'relationshipDescription': relationshipDescription,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      if (gender != null) 'gender': gender,
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      if (profilePicturePublicId != null)
        'profilePicturePublicId': profilePicturePublicId,
      if (medicalInfo != null) 'medicalInfo': medicalInfo,
    };

    final response = await _dio.post('/family', data: payload);

    final raw = response.data;
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      final unwrapped = (map['data'] is Map)
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      return FamilyMember.fromJson(unwrapped);
    }

    throw StateError('Unexpected POST /api/family response: ${response.data}');
  }

  Future<FamilyMember> updateFamilyMember({
    required String id,
    String? fullName,
    String? firstName,
    String? lastName,
    String? relationship,
    String? relationshipDescription,
    String? phoneNumber,
    String? birthDate,
    String? gender,
    String? profilePictureUrl,
    String? profilePicturePublicId,
    Map<String, dynamic>? medicalInfo,
  }) async {
    debugPrint('[FamilyApi] updateFamilyMember() -> PATCH /api/family/$id');

    final payload = <String, dynamic>{};
    if (fullName != null) payload['fullName'] = fullName;
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;
    if (relationship != null) payload['relationship'] = relationship;
    if (relationshipDescription != null) {
      payload['relationshipDescription'] = relationshipDescription;
    }
    if (phoneNumber != null) payload['phoneNumber'] = phoneNumber;
    if (birthDate != null) payload['birthDate'] = birthDate;
    if (gender != null) payload['gender'] = gender;
    if (profilePictureUrl != null) {
      payload['profilePictureUrl'] = profilePictureUrl;
    }
    if (profilePicturePublicId != null) {
      payload['profilePicturePublicId'] = profilePicturePublicId;
    }
    if (medicalInfo != null) payload['medicalInfo'] = medicalInfo;

    final response = await _dio.patch('/family/$id', data: payload);

    final raw = response.data;
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      final unwrapped = (map['data'] is Map)
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      return FamilyMember.fromJson(unwrapped);
    }

    throw StateError(
      'Unexpected PATCH /api/family/$id response: ${response.data}',
    );
  }

  Future<void> deleteFamilyMember(String id) async {
    debugPrint('[FamilyApi] deleteFamilyMember() -> DELETE /api/family/$id');
    await _dio.delete('/family/$id');
  }

  Future<FamilyMember> patchMedicalPassport({
    required String id,
    String? bloodGroup,
    Map<String, dynamic>? medicalInfo,
  }) async {
    debugPrint(
      '[FamilyApi] patchMedicalPassport() -> PATCH /api/family/$id/medical-passport',
    );

    final payload = <String, dynamic>{};
    final backendBlood = _bloodGroupToBackend(bloodGroup);
    if (backendBlood != null) {
      payload['bloodGroup'] = backendBlood;
    }
    if (medicalInfo != null) {
      payload['medicalInfo'] = medicalInfo;
    }

    final response = await _dio.patch(
      '/family/$id/medical-passport',
      data: payload,
    );

    final raw = response.data;
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      final unwrapped = (map['data'] is Map)
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      return FamilyMember.fromJson(unwrapped);
    }

    throw StateError(
      'Unexpected PATCH /api/family/$id/medical-passport response: ${response.data}',
    );
  }
}

String? _bloodGroupToBackend(String? ui) {
  if (ui == null) return null;
  final v = ui.trim();
  if (v.isEmpty || v == '-' || v == 'IDK') return null;
  return switch (v) {
    'A+' => 'A_POS',
    'A-' => 'A_NEG',
    'B+' => 'B_POS',
    'B-' => 'B_NEG',
    'AB+' => 'AB_POS',
    'AB-' => 'AB_NEG',
    'O+' => 'O_POS',
    'O-' => 'O_NEG',
    _ => v,
  };
}
