import '../core/api/auth_api.dart';

class AuthRepository {
  IAuthSource _source = MockAuthSource();

  void useMock() {
    _source = MockAuthSource();
  }

  void useApi(AuthApi api) {
    _source = ApiAuthSource(api);
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
    String? firstName,
    String? lastName,
    String? gender,
    String? dateOfBirth,
  }) =>
      _source.register(
        email: email,
        password: password,
        name: name,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );

  Future<String> login({
    required String email,
    required String password,
  }) =>
      _source.login(email: email, password: password);

  Future<AuthLoginResult> loginWithStatus({
    required String email,
    required String password,
  }) =>
      _source.loginWithStatus(email: email, password: password);

  Future<String> googleLogin({required String idToken}) =>
      _source.googleLogin(idToken: idToken);

  Future<AuthLoginResult> googleLoginWithStatus({required String idToken}) =>
      _source.googleLoginWithStatus(idToken: idToken);

  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) =>
      _source.verifyEmailOtp(email: email, code: code);

  Future<void> setPhone({
    required String email,
    required String phoneNumber,
  }) =>
      _source.setPhone(email: email, phoneNumber: phoneNumber);

  Future<String?> requestPhoneOtp({required String phoneNumber}) =>
      _source.requestPhoneOtp(phoneNumber: phoneNumber);

  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) =>
      _source.verifyPhoneOtp(phoneNumber: phoneNumber, otp: otp);
}

abstract class IAuthSource {
  Future<void> register({String? email, String? password, String? name, String? firstName, String? lastName, String? gender, String? dateOfBirth});
  Future<String> login({required String email, required String password});
  Future<AuthLoginResult> loginWithStatus({required String email, required String password});
  Future<String> googleLogin({required String idToken});
  Future<AuthLoginResult> googleLoginWithStatus({required String idToken});
  Future<void> verifyEmailOtp({required String email, required String code});
  Future<void> setPhone({required String email, required String phoneNumber});
  Future<String?> requestPhoneOtp({required String phoneNumber});
  Future<void> verifyPhoneOtp({required String phoneNumber, required String otp});
}

class MockAuthSource implements IAuthSource {
  @override
  Future<void> register({String? email, String? password, String? name, String? firstName, String? lastName, String? gender, String? dateOfBirth}) async {
    // Mock: accept any registration
  }

  @override
  Future<String> login({required String email, required String password}) async {
    return 'mock-jwt-token-abc123';
  }

  @override
  Future<AuthLoginResult> loginWithStatus({required String email, required String password}) async {
    return AuthLoginResult(
      accessToken: 'mock-jwt-token-abc123',
      email: email,
      phoneNumber: '+213 555 12 34 56',
      emailVerified: true,
      phoneVerified: true,
      onboardingComplete: true,
    );
  }

  @override
  Future<String> googleLogin({required String idToken}) async {
    return 'mock-jwt-token-google-xyz';
  }

  @override
  Future<AuthLoginResult> googleLoginWithStatus({required String idToken}) async {
    return AuthLoginResult(
      accessToken: 'mock-jwt-token-google-xyz',
      email: 'google.user@gmail.com',
      phoneNumber: null,
      emailVerified: true,
      phoneVerified: false,
      onboardingComplete: false,
    );
  }

  @override
  Future<void> verifyEmailOtp({required String email, required String code}) async {
    // Mock: accept any code
  }

  @override
  Future<void> setPhone({required String email, required String phoneNumber}) async {
    // Mock: silently succeed
  }

  @override
  Future<String?> requestPhoneOtp({required String phoneNumber}) async {
    return '123456';
  }

  @override
  Future<void> verifyPhoneOtp({required String phoneNumber, required String otp}) async {
    // Mock: accept any OTP
  }
}

class ApiAuthSource implements IAuthSource {
  final AuthApi _api;
  ApiAuthSource(this._api);

  @override
  Future<void> register({String? email, String? password, String? name, String? firstName, String? lastName, String? gender, String? dateOfBirth}) =>
      _api.register(email: email!, password: password!, name: name, firstName: firstName, lastName: lastName, gender: gender, dateOfBirth: dateOfBirth);

  @override
  Future<String> login({required String email, required String password}) =>
      _api.login(email: email, password: password);

  @override
  Future<AuthLoginResult> loginWithStatus({required String email, required String password}) =>
      _api.loginWithStatus(email: email, password: password);

  @override
  Future<String> googleLogin({required String idToken}) =>
      _api.googleLogin(idToken: idToken);

  @override
  Future<AuthLoginResult> googleLoginWithStatus({required String idToken}) =>
      _api.googleLoginWithStatus(idToken: idToken);

  @override
  Future<void> verifyEmailOtp({required String email, required String code}) =>
      _api.verifyEmailOtp(email: email, code: code);

  @override
  Future<void> setPhone({required String email, required String phoneNumber}) =>
      _api.setPhone(email: email, phoneNumber: phoneNumber);

  @override
  Future<String?> requestPhoneOtp({required String phoneNumber}) =>
      _api.requestPhoneOtp(phoneNumber: phoneNumber);

  @override
  Future<void> verifyPhoneOtp({required String phoneNumber, required String otp}) =>
      _api.verifyPhoneOtp(phoneNumber: phoneNumber, otp: otp);
}
