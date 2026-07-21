import 'package:dio/dio.dart';

import '../../features/auth/data/models/auth_dtos.dart';
import '../network/api_exception.dart';
import '../network/app_http_client.dart';
import '../storage/secure_token_store.dart';
import '../models/account_models.dart';

class AccountApi {
  AccountApi({AppHttpClient? httpClient, Object? dio})
    : _httpClient = httpClient ?? AppHttpClient(tokenStore: SecureTokenStore());

  final AppHttpClient _httpClient;

  Future<AccountFullProfile> getFullProfile() async {
    final profile = await getPatientProfile();
    return AccountFullProfile(
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
  }

  Future<PatientProfileDto> getPatientProfile() {
    return _getJson('/profile', PatientProfileDto.fromJson);
  }

  Future<OnboardingStepResponseDto> saveOnboardingStep(
    int step,
    Map<String, dynamic> data,
  ) {
    return _postJson(
      '/profile/onboarding/step/$step',
      data,
      OnboardingStepResponseDto.fromJson,
    );
  }

  Future<void> patchMedicalPassport({
    String? bloodGroup,
    int? heightCm,
    double? weightKg,
    Map<String, dynamic>? medicalInfo,
  }) async {
    final data = <String, dynamic>{
      'bloodType': bloodGroup,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'medicalInfo': medicalInfo,
    }..removeWhere((_, value) => value == null);
    await _patchJson('/profile/passport', data);
  }

  Future<void> patchProfilePicture({
    required String profilePictureUrl,
    String? profilePicturePublicId,
  }) async {
    await _patchJson('/profile', {
      'photoUrl': profilePictureUrl,
      'profilePicturePublicId': profilePicturePublicId,
    });
  }

  Future<T> _getJson<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(path);
      return _parseJson(response.data, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException catch (e) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: e,
      );
    }
  }

  Future<T> _postJson<T>(
    String path,
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await _httpClient.dio.post<dynamic>(path, data: data);
      return _parseJson(response.data, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException catch (e) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: e,
      );
    }
  }

  Future<void> _patchJson(String path, Map<String, dynamic> data) async {
    try {
      await _httpClient.dio.patch<dynamic>(path, data: data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  T _parseJson<T>(Object? data, T Function(Map<String, dynamic>) fromJson) {
    if (data is Map) {
      return fromJson(data.cast<String, dynamic>());
    }
    throw const FormatException('Expected JSON object.');
  }

  ApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map) {
      try {
        final apiError = ApiErrorResponse.fromJson(
          data.cast<String, dynamic>(),
        );
        return ApiException(
          apiError.message,
          code: apiError.code,
          statusCode: statusCode,
          fieldErrors: apiError.fieldErrors,
          cause: error,
        );
      } catch (_) {
        return ApiException(
          'Unexpected server error response.',
          code: 'MALFORMED_ERROR_RESPONSE',
          statusCode: statusCode,
          cause: error,
        );
      }
    }

    return ApiException(
      'Network request failed.',
      code: 'NETWORK_REQUEST_FAILED',
      statusCode: statusCode,
      cause: error,
    );
  }
}

class OnboardingStepResponseDto {
  final int passportCompletion;
  final int nextStep;
  final bool onboardingCompleted;
  final String? message;

  const OnboardingStepResponseDto({
    required this.passportCompletion,
    required this.nextStep,
    required this.onboardingCompleted,
    required this.message,
  });

  factory OnboardingStepResponseDto.fromJson(Map<String, dynamic> json) {
    return OnboardingStepResponseDto(
      passportCompletion: (json['passportCompletion'] as num?)?.toInt() ?? 0,
      nextStep: (json['nextStep'] as num?)?.toInt() ?? 0,
      onboardingCompleted: json['onboardingCompleted'] == true,
      message: json['message']?.toString(),
    );
  }
}
