import 'package:dio/dio.dart';

import '../../../core/models/patient_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/auth_refresh_coordinator.dart';
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

  Future<LoginResponseDto> linkGoogleAccount(GoogleLinkRequestDto request) {
    return _postJson(
      '/auth/google/link',
      request.toJson(),
      LoginResponseDto.fromJson,
    );
  }

  Future<AuthRefreshResult> refreshSession() {
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
    if (error.error is AuthReplayRequiredException) {
      return ApiException(
        'Your session was refreshed. Retry the operation so it can be sent safely.',
        code: 'AUTH_REPLAY_REQUIRED',
        cause: error,
      );
    }

    final refreshFailure = error.error;
    if (refreshFailure is AuthRefreshUnavailableException) {
      final malformed =
          refreshFailure.status == AuthRefreshStatus.malformedResponse;
      return ApiException(
        malformed
            ? 'The session refresh service returned an unexpected response.'
            : 'Your session could not be refreshed because the network or server is temporarily unavailable.',
        code: malformed
            ? 'AUTH_REFRESH_MALFORMED_RESPONSE'
            : 'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
        cause: refreshFailure.cause ?? error,
      );
    }

    // Backend and transport errors are read once, by the single parser: the
    // code, status, field kinds and retry delay, never the server's text.
    return ApiException.fromFailure(ApiFailure.fromDio(error), cause: error);
  }
}
