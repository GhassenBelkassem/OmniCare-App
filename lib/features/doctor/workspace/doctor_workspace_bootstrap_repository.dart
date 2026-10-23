import 'package:dio/dio.dart';

import 'doctor_workspace_bootstrap.dart';
import 'doctor_workspace_bootstrap_api.dart';

abstract interface class DoctorWorkspaceBootstrapRepositoryContract {
  Future<DoctorWorkspaceBootstrap> load(
    String doctorId, {
    CancelToken? cancelToken,
  });
}

class DoctorWorkspaceBootstrapRepository
    implements DoctorWorkspaceBootstrapRepositoryContract {
  const DoctorWorkspaceBootstrapRepository(this._api);

  final DoctorWorkspaceBootstrapApiContract _api;

  @override
  Future<DoctorWorkspaceBootstrap> load(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    final id = doctorId.trim();
    if (id.isEmpty) throw ArgumentError.value(doctorId, 'doctorId');

    final capabilitiesFuture = _api.getCapabilities(cancelToken: cancelToken);
    final configurationFuture = _api.getUrgentConfiguration(
      cancelToken: cancelToken,
    );
    final readinessFuture = _api.getUrgentReadiness(cancelToken: cancelToken);
    final locationsFuture = _api.getPracticeLocations(cancelToken: cancelToken);
    final runtimeFuture = _loadOptionalRuntime(cancelToken);

    final results = await Future.wait<Object?>([
      capabilitiesFuture,
      configurationFuture,
      readinessFuture,
      locationsFuture,
      runtimeFuture,
    ]);
    final capabilities =
        results[0]
            as ({int revision, Set<DoctorServerCareCapability> capabilities});
    final configuration = results[1] as DoctorUrgentConfigurationSnapshot;
    final readiness = results[2] as DoctorUrgentReadinessSnapshot;
    final locations = results[3] as List<DoctorPracticeLocationSnapshot>;
    final runtimeResult =
        results[4]
            as ({
              DoctorUrgentRuntimeSnapshot? snapshot,
              DoctorUrgentRuntimeBootstrapAccess access,
            });

    if (configuration.revision != capabilities.revision ||
        readiness.revision != capabilities.revision) {
      throw const DoctorWorkspaceBootstrapException(
        'La configuration a changé pendant son chargement. Réessayez.',
      );
    }
    final hasUrgentHome = capabilities.capabilities.contains(
      DoctorServerCareCapability.urgentHome,
    );
    final hasUrgentCabinet = capabilities.capabilities.contains(
      DoctorServerCareCapability.urgentCabinet,
    );
    if (readiness.home.capabilityEnabled != hasUrgentHome ||
        readiness.cabinet.capabilityEnabled != hasUrgentCabinet) {
      throw const DoctorWorkspaceBootstrapException(
        'La préparation des services urgents a changé. Réessayez.',
      );
    }

    return DoctorWorkspaceBootstrap(
      doctorId: id,
      serverCapabilities: capabilities.capabilities,
      capabilityRevision: capabilities.revision,
      configuration: configuration,
      readiness: readiness,
      activeCabinets: locations,
      runtime: runtimeResult.snapshot,
      runtimeAccess: runtimeResult.access,
    );
  }

  Future<
    ({
      DoctorUrgentRuntimeSnapshot? snapshot,
      DoctorUrgentRuntimeBootstrapAccess access,
    })
  >
  _loadOptionalRuntime(
    CancelToken? cancelToken,
  ) async {
    try {
      return (
        snapshot: await _api.getUrgentRuntime(cancelToken: cancelToken),
        access: DoctorUrgentRuntimeBootstrapAccess.available,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403 || CancelToken.isCancel(error)) {
        rethrow;
      }
      return (
        snapshot: null,
        access: status == 404
            ? DoctorUrgentRuntimeBootstrapAccess.rolloutUnavailable
            : DoctorUrgentRuntimeBootstrapAccess.unresolved,
      );
    }
  }
}

class DoctorWorkspaceBootstrapException implements Exception {
  const DoctorWorkspaceBootstrapException(this.message);

  final String message;

  @override
  String toString() => message;
}
