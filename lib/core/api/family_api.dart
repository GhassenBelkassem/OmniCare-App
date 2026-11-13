import 'package:dio/dio.dart';

import '../models/family_models.dart';
import '../network/api_exception.dart';
import '../network/api_failure.dart';
import '../network/app_http_client.dart';
import '../storage/secure_token_store.dart';

class FamilyApi {
  FamilyApi({AppHttpClient? httpClient, Object? dio})
    : _httpClient = httpClient ?? AppHttpClient(tokenStore: SecureTokenStore());

  static const _path = '/profile/family-members';

  final AppHttpClient _httpClient;

  Future<List<FamilyMember>> getFamilyMembers() async {
    try {
      final response = await _httpClient.dio.get<dynamic>(_path);
      final data = response.data;
      if (data is! List) throw const FormatException('Expected JSON list.');
      return List<FamilyMember>.unmodifiable(
        data.map((item) {
          if (item is! Map) {
            throw const FormatException('Expected family member object.');
          }
          return FamilyMember.fromJson(item.cast<String, dynamic>());
        }),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  Future<FamilyMember> createFamilyMember({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) {
    return _sendMember(
      () => _httpClient.dio.post<dynamic>(
        _path,
        data: _requestData(
          firstName: firstName,
          lastName: lastName,
          dateOfBirth: dateOfBirth,
          gender: gender,
          relationship: relationship,
          photoUrl: photoUrl,
        ),
      ),
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
    return _sendMember(
      () => _httpClient.dio.patch<dynamic>(
        '$_path/${Uri.encodeComponent(id)}',
        data: _requestData(
          firstName: firstName,
          lastName: lastName,
          dateOfBirth: dateOfBirth,
          gender: gender,
          relationship: relationship,
          photoUrl: photoUrl,
        ),
      ),
    );
  }

  Future<void> deactivateFamilyMember(String id) async {
    try {
      await _httpClient.dio.delete<dynamic>(
        '$_path/${Uri.encodeComponent(id)}',
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<FamilyMember> _sendMember(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object.');
      return FamilyMember.fromJson(data.cast<String, dynamic>());
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _requestData({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) {
    if (!FamilyRelationships.values.contains(relationship)) {
      throw ArgumentError.value(relationship, 'relationship');
    }
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'dateOfBirth': formatDateOnly(dateOfBirth),
      'gender': gender,
      'relationship': relationship,
      'photoUrl': photoUrl,
    };
  }

  /// One parser for every backend error shape; no server text is kept.
  ApiException _mapDioException(DioException error) =>
      ApiException.fromFailure(ApiFailure.fromDio(error), cause: error);
}
