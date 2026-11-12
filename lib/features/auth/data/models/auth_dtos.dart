import '../../../../core/storage/secure_token_store.dart';

enum ClientPlatform {
  android('ANDROID'),
  ios('IOS'),
  web('WEB');

  const ClientPlatform(this.value);

  final String value;
}

enum GoogleAuthStatus {
  authenticated('AUTHENTICATED'),
  requiresPhone('REQUIRES_PHONE'),
  requiresAccountLink('REQUIRES_ACCOUNT_LINK');

  const GoogleAuthStatus(this.value);

  final String value;

  static GoogleAuthStatus fromJson(String value) {
    return GoogleAuthStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () =>
          throw FormatException('Unsupported Google auth status "$value".'),
    );
  }
}

enum EmailPasswordLoginStatus {
  authenticated('AUTHENTICATED'),
  requiresPhoneOtp('REQUIRES_PHONE_OTP');

  const EmailPasswordLoginStatus(this.value);

  final String value;

  static EmailPasswordLoginStatus fromJson(String value) {
    return EmailPasswordLoginStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw FormatException(
        'Unsupported email/password login status "$value".',
      ),
    );
  }
}

class AuthUserDto {
  final String id;
  final String role;
  final bool mustChangePassword;

  const AuthUserDto({
    required this.id,
    required this.role,
    required this.mustChangePassword,
  });

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    return AuthUserDto(
      id: _requiredString(json, 'id'),
      role: _requiredString(json, 'role'),
      mustChangePassword: json['mustChangePassword'] == true,
    );
  }
}

class LoginResponseDto {
  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final AuthUserDto user;

  const LoginResponseDto({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.user,
  });

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    final userJson = _requiredMap(json, 'user');
    return LoginResponseDto(
      accessToken: _requiredString(json, 'accessToken'),
      tokenType: _requiredString(json, 'tokenType'),
      expiresAt: _requiredUtcDateTime(json, 'expiresAt'),
      refreshToken: _requiredString(json, 'refreshToken'),
      refreshExpiresAt: _requiredUtcDateTime(json, 'refreshExpiresAt'),
      user: AuthUserDto.fromJson(userJson),
    );
  }

  StoredSession toStoredSession({String? sessionId}) {
    return StoredSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: expiresAt,
      refreshTokenExpiresAt: refreshExpiresAt,
      userId: user.id,
      userRole: user.role,
      sessionId: sessionId,
    );
  }

  @override
  String toString() {
    return 'LoginResponseDto(tokenType: $tokenType, '
        'expiresAt: ${expiresAt.toUtc().toIso8601String()}, '
        'refreshExpiresAt: ${refreshExpiresAt.toUtc().toIso8601String()}, '
        'user: ${user.id}/${user.role}, accessToken: <redacted>, '
        'refreshToken: <redacted>)';
  }
}

class GoogleInitiateResponseDto {
  final GoogleAuthStatus status;
  final LoginResponseDto? session;
  final String? signupToken;
  final String? linkChallenge;
  final String? emailHint;

  const GoogleInitiateResponseDto({
    required this.status,
    required this.session,
    required this.signupToken,
    required this.linkChallenge,
    required this.emailHint,
  });

  factory GoogleInitiateResponseDto.fromJson(Map<String, dynamic> json) {
    final status = GoogleAuthStatus.fromJson(_requiredString(json, 'status'));
    final sessionJson = json['session'];
    final signupToken = _optionalString(json['signupToken']);

    return GoogleInitiateResponseDto(
      status: status,
      session: sessionJson is Map
          ? LoginResponseDto.fromJson(sessionJson.cast<String, dynamic>())
          : null,
      signupToken: signupToken,
      linkChallenge: _optionalString(json['linkChallenge']),
      emailHint: _optionalString(json['emailHint']),
    );
  }
}

class EmailPasswordLoginResponseDto {
  final EmailPasswordLoginStatus status;
  final LoginResponseDto? session;
  final String? phone;

  const EmailPasswordLoginResponseDto({
    required this.status,
    required this.session,
    required this.phone,
  });

  factory EmailPasswordLoginResponseDto.fromJson(Map<String, dynamic> json) {
    final status = EmailPasswordLoginStatus.fromJson(
      _requiredString(json, 'status'),
    );
    final sessionJson = json['session'];
    return EmailPasswordLoginResponseDto(
      status: status,
      session: sessionJson is Map
          ? LoginResponseDto.fromJson(sessionJson.cast<String, dynamic>())
          : null,
      phone: _optionalString(json['phone']),
    );
  }
}

class CurrentUserDto {
  final String id;
  final String role;
  final String sessionId;
  final bool mustChangePassword;
  final bool hasPassword;

  const CurrentUserDto({
    required this.id,
    required this.role,
    required this.sessionId,
    required this.mustChangePassword,
    this.hasPassword = true,
  });

  factory CurrentUserDto.fromJson(Map<String, dynamic> json) {
    return CurrentUserDto(
      id: _requiredString(json, 'id'),
      role: _requiredString(json, 'role'),
      sessionId: _requiredString(json, 'sessionId'),
      mustChangePassword: json['mustChangePassword'] == true,
      hasPassword: json['hasPassword'] == true,
    );
  }
}

class PhoneRequestDto {
  final String phone;

  const PhoneRequestDto({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

class OtpRequestDto {
  final String phone;
  final String otp;
  final bool rememberDevice;

  const OtpRequestDto({
    required this.phone,
    required this.otp,
    this.rememberDevice = false,
  });

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'otp': otp,
    'rememberDevice': rememberDevice,
  };
}

class PhoneSignupCompleteRequestDto {
  final String phone;
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String deviceFingerprint;
  final ClientPlatform platform;
  final String deviceLabel;
  final bool sharedDevice;
  final bool rememberDevice;

  const PhoneSignupCompleteRequestDto({
    required this.phone,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.deviceFingerprint,
    required this.platform,
    required this.deviceLabel,
    required this.sharedDevice,
    this.rememberDevice = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'deviceFingerprint': deviceFingerprint,
      'platform': platform.value,
      'deviceLabel': deviceLabel,
      'sharedDevice': sharedDevice,
      'rememberDevice': rememberDevice,
    };
  }
}

class EmailPasswordLoginRequestDto {
  final String identifier;
  final String password;
  final String deviceFingerprint;
  final ClientPlatform platform;
  final String deviceLabel;
  final bool sharedDevice;
  final bool rememberDevice;

  const EmailPasswordLoginRequestDto({
    required this.identifier,
    required this.password,
    required this.deviceFingerprint,
    required this.platform,
    required this.deviceLabel,
    required this.sharedDevice,
    this.rememberDevice = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'password': password,
      'deviceFingerprint': deviceFingerprint,
      'platform': platform.value,
      'deviceLabel': deviceLabel,
      'sharedDevice': sharedDevice,
      'rememberDevice': rememberDevice,
    };
  }
}

class PhoneLoginVerifyRequestDto {
  final String phone;
  final String otp;
  final String deviceFingerprint;
  final ClientPlatform platform;
  final String deviceLabel;
  final bool sharedDevice;
  final bool rememberDevice;

  const PhoneLoginVerifyRequestDto({
    required this.phone,
    required this.otp,
    required this.deviceFingerprint,
    required this.platform,
    required this.deviceLabel,
    required this.sharedDevice,
    this.rememberDevice = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'otp': otp,
      'deviceFingerprint': deviceFingerprint,
      'platform': platform.value,
      'deviceLabel': deviceLabel,
      'sharedDevice': sharedDevice,
      'rememberDevice': rememberDevice,
    };
  }
}

class GoogleInitiateRequestDto {
  final String idToken;
  final String deviceFingerprint;
  final ClientPlatform platform;
  final String deviceLabel;
  final bool sharedDevice;
  final bool rememberDevice;

  const GoogleInitiateRequestDto({
    required this.idToken,
    required this.deviceFingerprint,
    required this.platform,
    required this.deviceLabel,
    required this.sharedDevice,
    this.rememberDevice = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'idToken': idToken,
      'deviceFingerprint': deviceFingerprint,
      'platform': platform.value,
      'deviceLabel': deviceLabel,
      'sharedDevice': sharedDevice,
      'rememberDevice': rememberDevice,
    };
  }
}

class GooglePhoneInitiateRequestDto {
  final String signupToken;
  final String phone;

  const GooglePhoneInitiateRequestDto({
    required this.signupToken,
    required this.phone,
  });

  Map<String, dynamic> toJson() {
    return {'signupToken': signupToken, 'phone': phone};
  }
}

class GooglePhoneVerifyRequestDto {
  final String signupToken;
  final String phone;
  final String otp;

  const GooglePhoneVerifyRequestDto({
    required this.signupToken,
    required this.phone,
    required this.otp,
  });

  Map<String, dynamic> toJson() {
    return {'signupToken': signupToken, 'phone': phone, 'otp': otp};
  }
}

class GoogleCompleteRequestDto {
  final String signupToken;
  final String? phone;
  final String deviceFingerprint;
  final ClientPlatform platform;
  final String deviceLabel;
  final bool sharedDevice;
  final bool rememberDevice;

  const GoogleCompleteRequestDto({
    required this.signupToken,
    this.phone,
    required this.deviceFingerprint,
    required this.platform,
    required this.deviceLabel,
    required this.sharedDevice,
    this.rememberDevice = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'signupToken': signupToken,
      if (phone != null) 'phone': phone,
      'deviceFingerprint': deviceFingerprint,
      'platform': platform.value,
      'deviceLabel': deviceLabel,
      'sharedDevice': sharedDevice,
      'rememberDevice': rememberDevice,
    };
  }
}

class GoogleLinkRequestDto {
  final String linkChallenge;
  final String password;

  const GoogleLinkRequestDto({
    required this.linkChallenge,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {'linkChallenge': linkChallenge, 'password': password};
  }

  @override
  String toString() =>
      'GoogleLinkRequestDto(linkChallenge: <redacted>, password: <redacted>)';
}

class RefreshTokenRequestDto {
  final String refreshToken;

  const RefreshTokenRequestDto({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class ChangePasswordRequestDto {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequestDto({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {'currentPassword': currentPassword, 'newPassword': newPassword};
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing required string field "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final stringValue = value.toString();
  return stringValue.trim().isEmpty ? null : stringValue;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('Missing required object field "$key".');
}

DateTime _requiredUtcDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_requiredString(json, key));
  if (value == null) {
    throw FormatException('Invalid ISO timestamp field "$key".');
  }
  return value.toUtc();
}
