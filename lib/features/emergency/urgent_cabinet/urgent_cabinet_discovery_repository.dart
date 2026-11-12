import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/app_http_client.dart';
import 'urgent_cabinet_discovery_models.dart';

enum UrgentCabinetDiscoveryFailureKind {
  network,
  timeout,
  invalidResponse,
  sessionRejected,
  forbidden,

  /// Urgent CABINET is not available to this patient (backend 404
  /// URGENT_CABINET_REQUEST_UNAVAILABLE / URGENT_CABINET_REQUEST_NOT_AUTHORIZED,
  /// from `UrgentCabinetTargetedAccessPolicy`).
  featureUnavailable,
  notFound,
  server,
  cancelled,
  unexpected,
}

class UrgentCabinetDiscoveryFailure implements Exception {
  const UrgentCabinetDiscoveryFailure(this.kind);

  final UrgentCabinetDiscoveryFailureKind kind;

  bool get isCancelled => kind == UrgentCabinetDiscoveryFailureKind.cancelled;
  bool get isNotFound => kind == UrgentCabinetDiscoveryFailureKind.notFound;
  bool get isFeatureUnavailable =>
      kind == UrgentCabinetDiscoveryFailureKind.featureUnavailable;

  /// Backend codes meaning "urgent CABINET is not available to this patient".
  static const featureUnavailableCodes = {
    'URGENT_CABINET_REQUEST_UNAVAILABLE',
    'URGENT_CABINET_REQUEST_NOT_AUTHORIZED',
  };

  static UrgentCabinetDiscoveryFailure from(Object error) {
    if (error is UrgentCabinetDiscoveryFailure) return error;
    if (error is FormatException) {
      return const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.invalidResponse,
      );
    }
    if (error is! DioException) {
      return const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.unexpected,
      );
    }
    return switch (error.type) {
      DioExceptionType.cancel => const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.cancelled,
      ),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.timeout,
      ),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.network,
      ),
      DioExceptionType.badResponse => _fromResponse(error.response),
      DioExceptionType.unknown =>
        error.response == null
            ? const UrgentCabinetDiscoveryFailure(
                UrgentCabinetDiscoveryFailureKind.network,
              )
            : _fromResponse(error.response),
    };
  }

  static UrgentCabinetDiscoveryFailure _fromResponse(
    Response<dynamic>? response,
  ) {
    final status = response?.statusCode ?? 0;
    if (status == 401) {
      return const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.sessionRejected,
      );
    }
    if (status == 404) {
      // Backend errors are read once, by the single parser.
      return UrgentCabinetDiscoveryFailure(
        featureUnavailableCodes.contains(apiErrorCodeOf(response?.data))
            ? UrgentCabinetDiscoveryFailureKind.featureUnavailable
            : UrgentCabinetDiscoveryFailureKind.notFound,
      );
    }
    if (status == 403) {
      return const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.forbidden,
      );
    }
    if (status >= 500) {
      return const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.server,
      );
    }
    return const UrgentCabinetDiscoveryFailure(
      UrgentCabinetDiscoveryFailureKind.invalidResponse,
    );
  }

  @override
  String toString() => 'UrgentCabinetDiscoveryFailure(${kind.name})';
}

abstract interface class UrgentCabinetDiscoveryRepository {
  Future<UrgentCabinetDiscoveryFacets> facets({CancelToken? cancelToken});

  Future<UrgentCabinetDiscoveryPage> search(
    UrgentCabinetDiscoveryCriteria criteria, {
    CancelToken? cancelToken,
  });

  Future<UrgentCabinetDiscoveryDetail> detail({
    required String doctorId,
    required String practiceLocationId,
    CancelToken? cancelToken,
  });
}

class AppUrgentCabinetDiscoveryRepository
    implements UrgentCabinetDiscoveryRepository {
  const AppUrgentCabinetDiscoveryRepository(this._httpClient);

  final AppHttpClient _httpClient;

  static const _basePath = '/me/urgent-cabinet/discovery';

  @override
  Future<UrgentCabinetDiscoveryFacets> facets({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$_basePath/facets',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Expected urgent CABINET facets object.');
      }
      return UrgentCabinetDiscoveryFacets.fromJson(
        data.cast<String, dynamic>(),
      );
    } catch (error) {
      throw _collectionFailure(error);
    }
  }

  /// Collection routes (facets, search) have no item-level 404: any 404
  /// there means urgent CABINET is not available to this patient.
  static UrgentCabinetDiscoveryFailure _collectionFailure(Object error) {
    final failure = UrgentCabinetDiscoveryFailure.from(error);
    return failure.isNotFound
        ? const UrgentCabinetDiscoveryFailure(
            UrgentCabinetDiscoveryFailureKind.featureUnavailable,
          )
        : failure;
  }

  @override
  Future<UrgentCabinetDiscoveryPage> search(
    UrgentCabinetDiscoveryCriteria criteria, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$_basePath/search',
        data: criteria.toJson(),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Expected urgent CABINET search object.');
      }
      return UrgentCabinetDiscoveryPage.fromJson(data.cast<String, dynamic>());
    } catch (error) {
      throw _collectionFailure(error);
    }
  }

  @override
  Future<UrgentCabinetDiscoveryDetail> detail({
    required String doctorId,
    required String practiceLocationId,
    CancelToken? cancelToken,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    final normalizedLocationId = practiceLocationId.trim();
    if (normalizedDoctorId.isEmpty || normalizedLocationId.isEmpty) {
      throw const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.invalidResponse,
      );
    }
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$_basePath/doctors/${Uri.encodeComponent(normalizedDoctorId)}'
        '/practice-locations/${Uri.encodeComponent(normalizedLocationId)}',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Expected urgent CABINET detail object.');
      }
      final detail = UrgentCabinetDiscoveryDetail.fromJson(
        data.cast<String, dynamic>(),
      );
      if (detail.doctorCabinet.doctorId != normalizedDoctorId ||
          detail.doctorCabinet.practiceLocationId != normalizedLocationId) {
        throw const FormatException('Urgent CABINET pair mismatch.');
      }
      return detail;
    } catch (error) {
      throw UrgentCabinetDiscoveryFailure.from(error);
    }
  }
}
