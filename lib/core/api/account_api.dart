import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import '../network/api_failure.dart';
import '../network/app_http_client.dart';
import '../storage/secure_token_store.dart';
import '../models/blood_type.dart';
import '../models/patient_profile.dart';

class AccountApi {
  AccountApi({AppHttpClient? httpClient, Object? dio})
    : _httpClient = httpClient ?? AppHttpClient(tokenStore: SecureTokenStore());

  final AppHttpClient _httpClient;

  Future<PatientProfile> getPatientProfile() {
    return _getJson(
      '/profile',
      PatientProfile.fromJson,
      queryParameters: const {'includeMedical': false},
    );
  }

  /// The patient's stored blood type, height and weight from
  /// `GET /profile/medical-data` (`lifeSafety.bloodType`,
  /// `bodyMeasurements.heightCm/weightKg`).
  ///
  /// Narrow read for onboarding (pre-fill, resume, blood-type guard) only;
  /// the full medical-data repository comes with G-2 Phase 3. Throws
  /// [ApiException] on failure or on an unexpected shape.
  Future<StoredMedicalBasics> getStoredMedicalBasics() {
    return _getJson('/profile/medical-data', StoredMedicalBasics.fromJson);
  }

  Future<PatientProfile> updateProfile(PatientProfileUpdate update) {
    return _patchForJson('/profile', update.toJson(), PatientProfile.fromJson);
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

  Future<T> _getJson<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
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

  Future<T> _patchForJson<T>(
    String path,
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await _httpClient.dio.patch<dynamic>(path, data: data);
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

  T _parseJson<T>(Object? data, T Function(Map<String, dynamic>) fromJson) {
    if (data is Map) {
      return fromJson(data.cast<String, dynamic>());
    }
    throw const FormatException('Expected JSON object.');
  }

  /// One parser for every backend error shape; no server text is kept.
  ApiException _mapDioException(DioException error) =>
      ApiException.fromFailure(ApiFailure.fromDio(error), cause: error);
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

/// Blood type and body measurements already stored on the server.
class StoredMedicalBasics {
  const StoredMedicalBasics({
    required this.bloodType,
    required this.heightCm,
    required this.weightKg,
  });

  /// Null when no blood type is stored.
  final BloodType? bloodType;
  final int? heightCm;
  final double? weightKg;

  /// Height and weight are only ever stored together (backend rule).
  bool get hasBodyMeasurements => heightCm != null && weightKg != null;

  factory StoredMedicalBasics.fromJson(Map<String, dynamic> json) {
    final lifeSafety = json['lifeSafety'];
    if (lifeSafety is! Map) {
      throw const FormatException('Missing lifeSafety section.');
    }
    final bloodType = lifeSafety['bloodType'];
    if (bloodType != null && bloodType is! String) {
      throw const FormatException('bloodType must be a string or null.');
    }
    final body = json['bodyMeasurements'];
    if (body != null && body is! Map) {
      throw const FormatException('bodyMeasurements must be an object.');
    }
    final height = body is Map ? body['heightCm'] : null;
    final weight = body is Map ? body['weightKg'] : null;
    if ((height != null && height is! num) ||
        (weight != null && weight is! num)) {
      throw const FormatException('Body measurements must be numbers.');
    }
    return StoredMedicalBasics(
      bloodType: BloodType.fromWire(bloodType as String?),
      heightCm: (height as num?)?.toInt(),
      weightKg: (weight as num?)?.toDouble(),
    );
  }
}
