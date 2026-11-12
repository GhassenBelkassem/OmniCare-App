import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/app_http_client.dart';

class AccountSecuritySnapshot {
  const AccountSecuritySnapshot({required this.hasPassword});

  final bool hasPassword;

  factory AccountSecuritySnapshot.fromJson(Map<String, dynamic> json) {
    return AccountSecuritySnapshot(hasPassword: json['hasPassword'] == true);
  }
}

class AccountDevice {
  const AccountDevice({
    required this.id,
    required this.label,
    required this.platform,
    required this.current,
    required this.lastSeenAt,
    required this.activeSessionCount,
  });

  final String id;
  final String label;
  final String platform;
  final bool current;
  final DateTime? lastSeenAt;
  final int activeSessionCount;

  factory AccountDevice.fromJson(Map<String, dynamic> json) {
    return AccountDevice(
      id: json['deviceId']?.toString() ?? '',
      label: json['label']?.toString().trim().isNotEmpty == true
          ? json['label'].toString().trim()
          : 'Appareil inconnu',
      platform: json['platform']?.toString() ?? 'unknown',
      current: json['current'] == true,
      lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
      activeSessionCount: (json['activeSessionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthHistoryLocation {
  const AuthHistoryLocation({
    required this.label,
    required this.country,
    required this.approximate,
    this.city,
  });

  final String label;
  final String country;
  final String? city;
  final bool approximate;

  factory AuthHistoryLocation.fromJson(Map<String, dynamic> json) {
    return AuthHistoryLocation(
      label: json['label']?.toString() ?? 'Tunisie (approximatif)',
      country: json['country']?.toString() ?? 'Tunisie',
      city: json['city']?.toString(),
      approximate: json['approximate'] != false,
    );
  }
}

class AuthHistoryEvent {
  const AuthHistoryEvent({
    required this.id,
    required this.type,
    required this.label,
    required this.timestamp,
    required this.outcome,
    required this.device,
    required this.platform,
    required this.authenticationMethod,
    required this.location,
    required this.reportable,
    required this.reported,
    this.failureReason,
  });

  final String id;
  final String type;
  final String label;
  final DateTime timestamp;
  final String outcome;
  final String device;
  final String platform;
  final String authenticationMethod;
  final AuthHistoryLocation location;
  final String? failureReason;
  final bool reportable;
  final bool reported;

  bool get succeeded => outcome == 'SUCCESS';

  factory AuthHistoryEvent.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'];
    return AuthHistoryEvent(
      id: json['eventId']?.toString() ?? '',
      type: json['eventType']?.toString() ?? 'UNKNOWN',
      label: json['eventLabel']?.toString() ?? 'Activité du compte',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      outcome: json['outcome']?.toString() ?? 'FAILURE',
      device: json['device']?.toString() ?? 'Appareil inconnu',
      platform: json['platform']?.toString() ?? 'UNKNOWN',
      authenticationMethod:
          json['authenticationMethod']?.toString() ?? 'INCONNU',
      location: AuthHistoryLocation.fromJson(
        locationJson is Map
            ? locationJson.cast<String, dynamic>()
            : const <String, dynamic>{},
      ),
      failureReason: json['failureReason']?.toString(),
      reportable: json['reportable'] == true,
      reported: json['reported'] == true,
    );
  }
}

class AuthHistoryPage {
  const AuthHistoryPage({
    required this.items,
    required this.page,
    required this.hasNext,
  });

  final List<AuthHistoryEvent> items;
  final int page;
  final bool hasNext;

  factory AuthHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return AuthHistoryPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      AuthHistoryEvent.fromJson(item.cast<String, dynamic>()),
                )
                .where((event) => event.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      hasNext: json['hasNext'] == true,
    );
  }
}

class SecurityIncidentResult {
  const SecurityIncidentResult({
    required this.passwordResetRequired,
    required this.nextAction,
  });

  final bool passwordResetRequired;
  final String nextAction;

  factory SecurityIncidentResult.fromJson(Map<String, dynamic> json) {
    return SecurityIncidentResult(
      passwordResetRequired: json['passwordResetRequired'] == true,
      nextAction: json['nextAction']?.toString() ?? 'REAUTHENTICATE',
    );
  }
}

class PhoneChangeChallenge {
  const PhoneChangeChallenge({
    required this.nextStep,
    this.destinationMasked,
    this.expiresAt,
  });

  final String nextStep;
  final String? destinationMasked;
  final DateTime? expiresAt;

  factory PhoneChangeChallenge.fromJson(Map<String, dynamic> json) {
    return PhoneChangeChallenge(
      nextStep: json['nextStep']?.toString() ?? '',
      destinationMasked: json['destinationMasked']?.toString(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
    );
  }
}

class PhoneChangeStatus {
  const PhoneChangeStatus({
    required this.state,
    required this.activePhoneMasked,
    required this.canReverse,
    this.previousPhoneMasked,
    this.startedAt,
    this.completesAt,
  });

  final String state;
  final String activePhoneMasked;
  final String? previousPhoneMasked;
  final DateTime? startedAt;
  final DateTime? completesAt;
  final bool canReverse;

  bool get active => state == 'ACTIVE';

  factory PhoneChangeStatus.fromJson(Map<String, dynamic> json) {
    return PhoneChangeStatus(
      state: json['state']?.toString() ?? 'NONE',
      activePhoneMasked: json['activePhoneMasked']?.toString() ?? '••••',
      previousPhoneMasked: json['previousPhoneMasked']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      completesAt: DateTime.tryParse(json['completesAt']?.toString() ?? ''),
      canReverse: json['canReverse'] == true,
    );
  }
}

class AccountSecurityApi {
  AccountSecurityApi(this._httpClient);

  final AppHttpClient _httpClient;

  Future<AccountSecuritySnapshot> loadSnapshot() async {
    final data = await _request(() => _httpClient.dio.get<dynamic>('/auth/me'));
    return AccountSecuritySnapshot.fromJson(_object(data));
  }

  Future<List<AccountDevice>> loadDevices() async {
    final data = await _request(
      () => _httpClient.dio.get<dynamic>('/auth/devices'),
    );
    if (data is! List) throw const FormatException('Expected a device list.');
    return data
        .whereType<Map>()
        .map((item) => AccountDevice.fromJson(item.cast<String, dynamic>()))
        .where((device) => device.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<AuthHistoryPage> loadHistory({int page = 0, int size = 20}) async {
    final data = await _request(
      () => _httpClient.dio.get<dynamic>(
        '/auth/history',
        queryParameters: {'page': page, 'size': size},
      ),
    );
    return AuthHistoryPage.fromJson(_object(data));
  }

  Future<SecurityIncidentResult> reportHistoryEvent(String eventId) async {
    final data = await _request(
      () => _httpClient.dio.post<dynamic>(
        '/auth/history/$eventId/report',
        data: const <String, dynamic>{},
      ),
    );
    return SecurityIncidentResult.fromJson(_object(data));
  }

  Future<PhoneChangeStatus> loadPhoneChangeStatus() async {
    final data = await _request(
      () => _httpClient.dio.get<dynamic>('/auth/phone-change'),
    );
    return PhoneChangeStatus.fromJson(_object(data));
  }

  Future<PhoneChangeChallenge> initiateCurrentPhoneVerification() async {
    final data = await _request(
      () => _httpClient.dio.post<dynamic>(
        '/auth/phone-change/current/initiate',
        data: const <String, dynamic>{},
      ),
    );
    return PhoneChangeChallenge.fromJson(_object(data));
  }

  Future<PhoneChangeChallenge> verifyCurrentPhone(String otp) async {
    final data = await _request(
      () => _httpClient.dio.post<dynamic>(
        '/auth/phone-change/current/verify',
        data: {'otp': otp},
      ),
    );
    return PhoneChangeChallenge.fromJson(_object(data));
  }

  Future<PhoneChangeChallenge> initiateNewPhone(String newPhone) async {
    final data = await _request(
      () => _httpClient.dio.post<dynamic>(
        '/auth/phone-change/new/initiate',
        data: {'newPhone': newPhone},
      ),
    );
    return PhoneChangeChallenge.fromJson(_object(data));
  }

  Future<PhoneChangeStatus> verifyNewPhone(String otp) async {
    final data = await _request(
      () => _httpClient.dio.post<dynamic>(
        '/auth/phone-change/new/verify',
        data: {'otp': otp},
      ),
    );
    return PhoneChangeStatus.fromJson(_object(data));
  }

  Future<PhoneChangeStatus> reversePhoneChange() async {
    final data = await _request(
      () => _httpClient.dio.post<dynamic>(
        '/auth/phone-change/reverse',
        data: const <String, dynamic>{},
      ),
    );
    return PhoneChangeStatus.fromJson(_object(data));
  }

  Future<PhoneChangeStatus> reversePhoneChangeWithToken(String token) async {
    final data = await _request(
      () => _httpClient.publicDio.post<dynamic>(
        '/auth/phone-change/reverse-token',
        data: {'token': token},
      ),
    );
    return PhoneChangeStatus.fromJson(_object(data));
  }

  Future<void> changePassword(String currentPassword, String newPassword) {
    return _emptyPost('/auth/password/change', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> setPassword(String googleIdToken, String newPassword) {
    return _emptyPost('/auth/password/set', {
      'googleIdToken': googleIdToken,
      'newPassword': newPassword,
    });
  }

  Future<void> revokeDevice(String deviceId) {
    return _emptyPost('/auth/devices/$deviceId/logout', const {});
  }

  Future<void> revokeOtherDevices() {
    return _emptyPost('/auth/devices/logout-others', const {});
  }

  Future<void> logoutAll() => _emptyPost('/auth/logout-all', const {});

  Future<void> _emptyPost(String path, Map<String, dynamic> data) async {
    await _request(() => _httpClient.dio.post<dynamic>(path, data: data));
  }

  Future<Object?> _request(Future<Response<dynamic>> Function() action) async {
    try {
      return (await action()).data;
    } on DioException catch (error) {
      // One parser for every backend error shape; no server text is kept.
      throw ApiException.fromFailure(ApiFailure.fromDio(error), cause: error);
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse du serveur invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _object(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    throw const FormatException('Expected a JSON object.');
  }
}
