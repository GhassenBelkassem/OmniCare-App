import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'doctor_workspace_bootstrap.dart';

abstract interface class DoctorWorkspaceBootstrapApiContract {
  Future<({int revision, Set<DoctorServerCareCapability> capabilities})>
  getCapabilities({CancelToken? cancelToken});

  Future<DoctorUrgentConfigurationSnapshot> getUrgentConfiguration({
    CancelToken? cancelToken,
  });

  Future<DoctorUrgentReadinessSnapshot> getUrgentReadiness({
    CancelToken? cancelToken,
  });

  Future<List<DoctorPracticeLocationSnapshot>> getPracticeLocations({
    CancelToken? cancelToken,
  });

  Future<DoctorUrgentRuntimeSnapshot> getUrgentRuntime({
    CancelToken? cancelToken,
  });
}

abstract interface class DoctorUrgentRuntimeApiContract {
  Future<DoctorUrgentRuntimeSnapshot> getUrgentRuntime({
    CancelToken? cancelToken,
  });

  Future<DoctorUrgentRuntimeSnapshot> replaceUrgentRuntime({
    required int expectedRevision,
    required bool homeEnabled,
    required bool cabinetEnabled,
    CancelToken? cancelToken,
  });
}

class DoctorWorkspaceBootstrapApi
    implements
        DoctorWorkspaceBootstrapApiContract,
        DoctorUrgentRuntimeApiContract {
  const DoctorWorkspaceBootstrapApi(this._httpClient);

  static const capabilitiesPath = '/me/care-capabilities';
  static const configurationPath = '/me/care-capabilities/urgent-configuration';
  static const readinessPath =
      '/me/care-capabilities/urgent-configuration/readiness';
  static const practiceLocationsPath = '/me/practice-locations';
  static const runtimePath = '/me/urgent-runtime';

  final AppHttpClient _httpClient;

  @override
  Future<({int revision, Set<DoctorServerCareCapability> capabilities})>
  getCapabilities({CancelToken? cancelToken}) async {
    final response = await _httpClient.dio.get<dynamic>(
      capabilitiesPath,
      cancelToken: cancelToken,
    );
    final json = _object(response.data, 'Doctor care capabilities');
    final values = _list(json, 'capabilities');
    return (
      revision: _nonNegativeInt(json, 'revision'),
      capabilities: values
          .map((value) => DoctorServerCareCapability.parse(_string(value)))
          .toSet(),
    );
  }

  @override
  Future<DoctorUrgentConfigurationSnapshot> getUrgentConfiguration({
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      configurationPath,
      cancelToken: cancelToken,
    );
    final json = _object(response.data, 'urgent configuration');
    final home = _object(json['home'], 'HOME urgent configuration');
    final cabinet = _object(json['cabinet'], 'CABINET urgent configuration');
    return DoctorUrgentConfigurationSnapshot(
      revision: _nonNegativeInt(json, 'revision'),
      homeFeeConfigured: _bool(home, 'feeConfigured'),
      homeTravelDistanceConfigured: _bool(home, 'maxTravelDistanceConfigured'),
      cabinetFeeConfigured: _bool(cabinet, 'feeConfigured'),
    );
  }

  @override
  Future<DoctorUrgentReadinessSnapshot> getUrgentReadiness({
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      readinessPath,
      cancelToken: cancelToken,
    );
    final json = _object(response.data, 'urgent readiness');
    return DoctorUrgentReadinessSnapshot(
      revision: _nonNegativeInt(json, 'revision'),
      professionalEligible: _bool(json, 'professionalEligible'),
      home: _modeReadiness(json['home'], 'HOME readiness'),
      cabinet: _modeReadiness(json['cabinet'], 'CABINET readiness'),
      completeLiveMatchingEligibilityEvaluated: _bool(
        json,
        'completeLiveMatchingEligibilityEvaluated',
      ),
      evaluatedAt: _dateTime(json, 'evaluatedAt'),
    );
  }

  @override
  Future<List<DoctorPracticeLocationSnapshot>> getPracticeLocations({
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      practiceLocationsPath,
      cancelToken: cancelToken,
    );
    if (response.data is! List) {
      throw const FormatException('Expected a practice-location list.');
    }
    return (response.data as List<dynamic>)
        .map((value) {
          final json = _object(value, 'practice location');
          final type = _requiredString(json, 'type');
          if (type != 'CABINET') {
            throw FormatException('Unknown practice-location type: $type.');
          }
          return DoctorPracticeLocationSnapshot(
            id: _requiredString(json, 'id'),
            name: _requiredString(json, 'name'),
            governorate: _requiredString(json, 'governorate'),
            city: _requiredString(json, 'city'),
            address: _requiredString(json, 'address'),
            active: _bool(json, 'active'),
            primary: _bool(json, 'primary'),
          );
        })
        .where((location) => location.active)
        .toList(growable: false)
      ..sort((left, right) {
        if (left.primary != right.primary) return left.primary ? -1 : 1;
        return left.id.compareTo(right.id);
      });
  }

  @override
  Future<DoctorUrgentRuntimeSnapshot> getUrgentRuntime({
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      runtimePath,
      cancelToken: cancelToken,
    );
    return _runtimeSnapshot(response.data);
  }

  @override
  Future<DoctorUrgentRuntimeSnapshot> replaceUrgentRuntime({
    required int expectedRevision,
    required bool homeEnabled,
    required bool cabinetEnabled,
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.put<dynamic>(
      runtimePath,
      data: {
        'expectedRevision': expectedRevision,
        'homeEnabled': homeEnabled,
        'cabinetEnabled': cabinetEnabled,
      },
      cancelToken: cancelToken,
    );
    return _runtimeSnapshot(response.data);
  }

  static DoctorUrgentRuntimeSnapshot _runtimeSnapshot(Object? value) {
    final json = _object(value, 'urgent runtime');
    final homeEnabled = _bool(json, 'homeEnabled');
    final cabinetEnabled = _bool(json, 'cabinetEnabled');
    final home = _runtimeMode(json['home'], 'HOME runtime');
    final cabinet = _runtimeMode(json['cabinet'], 'CABINET runtime');
    if (home.runtimeIntentEnabled != homeEnabled ||
        cabinet.runtimeIntentEnabled != cabinetEnabled) {
      throw const FormatException(
        'Urgent runtime intent fields are inconsistent.',
      );
    }
    return DoctorUrgentRuntimeSnapshot(
      revision: _nonNegativeInt(json, 'revision'),
      homeEnabled: homeEnabled,
      cabinetEnabled: cabinetEnabled,
      capacityState: DoctorUrgentCapacityState.parse(
        _requiredString(json, 'capacityState'),
      ),
      home: home,
      cabinet: cabinet,
      homeLocationPresence: _locationPresence(json['homeLocationPresence']),
      completeRequestSpecificEligibilityEvaluated: _bool(
        json,
        'completeRequestSpecificEligibilityEvaluated',
      ),
      evaluatedAt: _dateTime(json, 'evaluatedAt'),
    );
  }

  static DoctorUrgentRuntimeModeStatus _runtimeMode(
    Object? value,
    String label,
  ) {
    final json = _object(value, label);
    return DoctorUrgentRuntimeModeStatus(
      runtimeIntentEnabled: _bool(json, 'runtimeIntentEnabled'),
      activationPrerequisitesSatisfied: _bool(
        json,
        'activationPrerequisitesSatisfied',
      ),
      capacityAvailable: _bool(json, 'capacityAvailable'),
      operationalPresenceReady: _bool(json, 'operationalPresenceReady'),
      runtimeFoundationReady: _bool(json, 'runtimeFoundationReady'),
      requestSpecificEligibilityEvaluated: _bool(
        json,
        'requestSpecificEligibilityEvaluated',
      ),
      effectiveCurrentEligibility: _bool(json, 'effectiveCurrentEligibility'),
      blockingReasons: _list(json, 'blockingReasons')
          .map((item) => DoctorUrgentReadinessReason.parse(_string(item)))
          .toList(growable: false),
    );
  }

  static DoctorHomeLocationPresence _locationPresence(Object? value) {
    final json = _object(value, 'HOME location presence');
    return DoctorHomeLocationPresence(
      status: DoctorLocationPresenceStatus.parse(
        _requiredString(json, 'status'),
      ),
      updateId: _nullableString(json, 'updateId'),
      observedAt: _nullableDateTime(json, 'observedAt'),
      receivedAt: _nullableDateTime(json, 'receivedAt'),
      expiresAt: _nullableDateTime(json, 'expiresAt'),
    );
  }

  static DoctorUrgentModeReadiness _modeReadiness(Object? value, String label) {
    final json = _object(value, label);
    return DoctorUrgentModeReadiness(
      capabilityEnabled: _bool(json, 'capabilityEnabled'),
      configurationReady: _bool(json, 'configurationReady'),
      runtimeAvailabilityIntent: _bool(json, 'runtimeAvailabilityIntent'),
      effectiveCurrentEligibility: _bool(json, 'effectiveCurrentEligibility'),
      blockingReasons: _list(json, 'blockingReasons')
          .map((value) => DoctorUrgentReadinessReason.parse(_string(value)))
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> _object(Object? value, String label) {
    if (value is Map) return value.cast<String, dynamic>();
    throw FormatException('Expected a $label object.');
  }

  static List<dynamic> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is List) return value;
    throw FormatException('Expected an array for $key.');
  }

  static int _nonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int && value >= 0) return value;
    throw FormatException('Expected a non-negative integer for $key.');
  }

  static bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw FormatException('Expected a boolean for $key.');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _string(json[key]).trim();
    if (value.isEmpty) throw FormatException('Expected a value for $key.');
    return value;
  }

  static String? _nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    return _string(value);
  }

  static String _string(Object? value) {
    if (value is String) return value;
    throw const FormatException('Expected a string value.');
  }

  static DateTime _dateTime(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Expected an instant for $key.');
    return parsed.toUtc();
  }

  static DateTime? _nullableDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Expected an instant for $key.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Expected an instant for $key.');
    return parsed.toUtc();
  }
}
