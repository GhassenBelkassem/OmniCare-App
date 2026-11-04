import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/app_http_client.dart';
import '../workspace/doctor_workspace_bootstrap.dart';

@immutable
class DoctorHomePresenceUpdate {
  const DoctorHomePresenceUpdate({
    required this.updateId,
    required this.observedAt,
    required this.latitude,
    required this.longitude,
    required this.horizontalAccuracyMeters,
  });

  final String updateId;
  final DateTime observedAt;
  final double latitude;
  final double longitude;
  final double horizontalAccuracyMeters;

  Map<String, Object> toJson() => {
    'updateId': updateId,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'horizontalAccuracyMeters': horizontalAccuracyMeters,
  };
}

abstract interface class DoctorHomePresenceRepositoryContract {
  Future<DoctorHomeLocationPresence> publish(
    DoctorHomePresenceUpdate update, {
    CancelToken? cancelToken,
  });
}

class DoctorHomePresenceRepository
    implements DoctorHomePresenceRepositoryContract {
  const DoctorHomePresenceRepository(this._httpClient);

  static const path = '/me/urgent-runtime/location-presence';

  final AppHttpClient _httpClient;

  @override
  Future<DoctorHomeLocationPresence> publish(
    DoctorHomePresenceUpdate update, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.put<dynamic>(
      path,
      data: update.toJson(),
      cancelToken: cancelToken,
    );
    return parseDoctorHomeLocationPresence(response.data);
  }
}

DoctorHomeLocationPresence parseDoctorHomeLocationPresence(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected a HOME location presence object.');
  }
  final json = value.cast<Object?, Object?>();
  final status = json['status'];
  if (status is! String || status.isEmpty) {
    throw const FormatException('Missing HOME location presence status.');
  }
  return DoctorHomeLocationPresence(
    status: DoctorLocationPresenceStatus.parse(status),
    updateId: _nullableString(json, 'updateId'),
    observedAt: _nullableDateTime(json, 'observedAt'),
    receivedAt: _nullableDateTime(json, 'receivedAt'),
    expiresAt: _nullableDateTime(json, 'expiresAt'),
  );
}

String? _nullableString(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

DateTime? _nullableDateTime(Map<Object?, Object?> json, String field) {
  final value = _nullableString(json, field);
  if (value == null) return null;
  return DateTime.tryParse(value)?.toUtc() ??
      (throw FormatException('Invalid $field.'));
}

enum DoctorHomePresenceFailureKind {
  invalidObservation,
  staleObservation,
  inaccurateObservation,
  outOfOrder,
  dependencyUnavailable,
  runtimeUnavailable,
  sessionRejected,
  network,
  invalidResponse,
  unknown,
}

class DoctorHomePresenceFailure implements Exception {
  const DoctorHomePresenceFailure({required this.kind, required this.message});

  final DoctorHomePresenceFailureKind kind;
  final String message;

  static DoctorHomePresenceFailure from(Object error) {
    if (error is FormatException) {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.invalidResponse,
        message: 'La réponse de localisation est incompatible.',
      );
    }
    if (error is! DioException) {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.unknown,
        message: 'La localisation est momentanément indisponible.',
      );
    }
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final json = body is Map ? body.cast<Object?, Object?>() : null;
    final code = json?['code'] as String?;
    if (status == 401 || status == 403) {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.sessionRejected,
        message: 'Votre session ne permet plus cette opération.',
      );
    }
    if (status == 404 || code == 'URGENT_RUNTIME_UNAVAILABLE') {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.runtimeUnavailable,
        message: 'La présence HOME n’est pas activée sur cet environnement.',
      );
    }
    if (status == 503 || code == 'LOCATION_PRESENCE_UNAVAILABLE') {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.dependencyUnavailable,
        message: 'Le service de présence est temporairement indisponible.',
      );
    }
    if (status == 409 || code == 'LOCATION_OBSERVATION_OUT_OF_ORDER') {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.outOfOrder,
        message: 'Une position plus récente existe déjà sur le serveur.',
      );
    }
    if (code == 'LOCATION_OBSERVATION_TOO_OLD') {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.staleObservation,
        message: 'La position obtenue est déjà expirée.',
      );
    }
    if (code == 'LOCATION_OBSERVATION_INVALID' ||
        code == 'LOCATION_OBSERVATION_OUTSIDE_GEO_RANGE' ||
        code == 'LOCATION_OBSERVATION_IN_FUTURE' ||
        status == 400) {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.invalidObservation,
        message: 'La mesure de position n’est pas valide.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return const DoctorHomePresenceFailure(
        kind: DoctorHomePresenceFailureKind.network,
        message:
            'Résultat réseau incertain. La présence serveur va être vérifiée.',
      );
    }
    return const DoctorHomePresenceFailure(
      kind: DoctorHomePresenceFailureKind.unknown,
      message: 'La localisation est momentanément indisponible.',
    );
  }

  @override
  String toString() => message;
}
