import 'package:dio/dio.dart';

import '../../../core/models/patient_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/storage/secure_token_store.dart';
import 'models/auth_dtos.dart';

class AuthApi {
  AuthApi(this._httpClient);

  final AppHttpClient _httpClient;

  Future<void> initiatePhoneSignup(PhoneRequestDto request) {
    return _postEmpty('/auth/signup/phone/initiate', request.toJson());
  }

  Future<void> verifyPhoneSignupOtp(OtpRequestDto request) {
    return _postEmpty('/auth/signup/phone/verify', request.toJson());
  }

  Future<LoginResponseDto> completePhoneSignup(
    PhoneSignupCompleteRequestDto request,
  ) {
    return _postJson(
      '/auth/signup/complete',
      request.toJson(),
      LoginResponseDto.fromJson,
    );
  }

  Future<void> initiatePhoneLogin(PhoneRequestDto request) {
    return _postEmpty('/auth/login/phone/initiate', request.toJson());
  }

  Future<EmailPasswordLoginResponseDto> loginWithEmailPassword(
    EmailPasswordLoginRequestDto request,
  ) {
    return _postJson(
      '/auth/login',
      request.toJson(),
      EmailPasswordLoginResponseDto.fromJson,
    );
  }

  Future<LoginResponseDto> verifyPhoneLoginOtp(
    PhoneLoginVerifyRequestDto request,
  ) {
    return _postJson(
      '/auth/login/phone/verify',
      request.toJson(),
      LoginResponseDto.fromJson,
    );
  }

  Future<GoogleInitiateResponseDto> initiateGoogle(
    GoogleInitiateRequestDto request,
  ) {
    return _postJson(
      '/auth/google/initiate',
      request.toJson(),
      GoogleInitiateResponseDto.fromJson,
    );
  }

  Future<void> initiateGooglePhoneSignup(
    GooglePhoneInitiateRequestDto request,
  ) {
    return _postEmpty('/auth/google/phone/initiate', request.toJson());
  }

  Future<void> verifyGooglePhoneSignupOtp(GooglePhoneVerifyRequestDto request) {
    return _postEmpty('/auth/google/phone/verify', request.toJson());
  }

  Future<LoginResponseDto> completeGoogleSignup(
    GoogleCompleteRequestDto request,
  ) {
    return _postJson(
      '/auth/google/complete',
      request.toJson(),
      LoginResponseDto.fromJson,
    );
  }

  Future<StoredSession?> refreshSession() {
    return _httpClient.refreshCoordinator.refreshSession();
  }

  Future<CurrentUserDto> getCurrentUser() {
    return _getJson('/auth/me', CurrentUserDto.fromJson);
  }

  Future<void> logout() {
    return _postEmpty('/auth/logout', const {});
  }

  Future<void> changePassword(ChangePasswordRequestDto request) {
    return _postEmpty('/auth/password/change', request.toJson());
  }

  Future<PatientProfile> getPatientProfile() {
    return _getJson('/profile?includeMedical=false', PatientProfile.fromJson);
  }

  Future<void> _postEmpty(
    String path,
    Map<String, dynamic> data, {
    bool usePublicClient = false,
  }) async {
    try {
      await _client(usePublicClient).post<dynamic>(path, data: data);
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
    T Function(Map<String, dynamic>) fromJson, {
    bool usePublicClient = false,
  }) async {
    try {
      final response = await _client(
        usePublicClient,
      ).post<dynamic>(path, data: data);
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

  Dio _client(bool usePublicClient) {
    return usePublicClient ? _httpClient.publicDio : _httpClient.dio;
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

    return switch (error.type) {
      DioExceptionType.connectionTimeout => ApiException(
        'Connection timed out.',
        code: 'NETWORK_CONNECTION_TIMEOUT',
        statusCode: statusCode,
        cause: error,
      ),
      DioExceptionType.receiveTimeout => ApiException(
        'Server response timed out.',
        code: 'NETWORK_RECEIVE_TIMEOUT',
        statusCode: statusCode,
        cause: error,
      ),
      DioExceptionType.connectionError => ApiException(
        'Network unavailable.',
        code: 'NETWORK_UNAVAILABLE',
        statusCode: statusCode,
        cause: error,
      ),
      _ => ApiException(
        'Network request failed.',
        code: 'NETWORK_REQUEST_FAILED',
        statusCode: statusCode,
        cause: error,
      ),
    };
  }
}
