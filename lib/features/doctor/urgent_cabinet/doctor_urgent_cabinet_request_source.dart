import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../workspace/doctor_workspace_config.dart';
import 'doctor_urgent_cabinet_request.dart';

@immutable
class DoctorUrgentCabinetRequestContext {
  const DoctorUrgentCabinetRequestContext._({
    required this.doctorId,
    required this.cabinet,
    required this.hasUrgentCabinetCapability,
  });

  factory DoctorUrgentCabinetRequestContext.fromWorkspace(
    DoctorWorkspaceConfig? workspace,
  ) {
    final localCabinet = workspace?.cabinet;
    final cabinet = localCabinet == null
        ? null
        : DoctorUrgentCabinetSnapshot.tryCreate(
            name: localCabinet.name,
            address: localCabinet.address,
            city: localCabinet.city,
            governorate: localCabinet.governorate,
          );
    return DoctorUrgentCabinetRequestContext._(
      doctorId: workspace?.doctorId.trim() ?? '',
      cabinet: cabinet,
      hasUrgentCabinetCapability:
          workspace?.services.contains(
            DoctorWorkspaceService.urgentCabinetConsultations,
          ) ??
          false,
    );
  }

  final String doctorId;
  final DoctorUrgentCabinetSnapshot? cabinet;
  final bool hasUrgentCabinetCapability;

  bool get hasCommitmentRecoveryContext =>
      doctorId.isNotEmpty && cabinet != null;

  bool get isComplete =>
      hasCommitmentRecoveryContext && hasUrgentCabinetCapability;

  String get fingerprint => [
    doctorId,
    hasUrgentCabinetCapability,
    cabinet?.normalizedFingerprint ?? 'missing-cabinet',
  ].join('|');
}

@immutable
sealed class DoctorUrgentCabinetFeedState {
  const DoctorUrgentCabinetFeedState();
}

final class DoctorUrgentCabinetFeedLoading
    extends DoctorUrgentCabinetFeedState {
  const DoctorUrgentCabinetFeedLoading();
}

final class DoctorUrgentCabinetFeedLoaded extends DoctorUrgentCabinetFeedState {
  DoctorUrgentCabinetFeedLoaded(Iterable<DoctorUrgentCabinetRequest> requests)
    : requests = UnmodifiableListView(requests);

  final List<DoctorUrgentCabinetRequest> requests;
}

final class DoctorUrgentCabinetFeedEmpty extends DoctorUrgentCabinetFeedState {
  const DoctorUrgentCabinetFeedEmpty();
}

final class DoctorUrgentCabinetFeedUnavailable
    extends DoctorUrgentCabinetFeedState {
  const DoctorUrgentCabinetFeedUnavailable({required this.message});

  final String message;
}

final class DoctorUrgentCabinetFeedError extends DoctorUrgentCabinetFeedState {
  const DoctorUrgentCabinetFeedError({
    required this.message,
    this.canRetry = false,
  });

  final String message;
  final bool canRetry;
}

abstract interface class DoctorUrgentCabinetRequestSource {
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  });
}

abstract interface class DoctorUrgentCabinetRequestDetailSource {
  Future<DoctorUrgentCabinetRequest> getRequest(
    String requestId,
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  });
}

enum DoctorUrgentCabinetNotificationTargetState {
  pending,
  accepted,
  declined,
  cancelled,
  expired,
}

@immutable
class DoctorUrgentCabinetNotificationTarget {
  const DoctorUrgentCabinetNotificationTarget({
    required this.requestId,
    required this.state,
    this.pendingRequest,
    this.commitmentId,
  });

  final String requestId;
  final DoctorUrgentCabinetNotificationTargetState state;
  final DoctorUrgentCabinetRequest? pendingRequest;
  final String? commitmentId;
}

/// Resolves a notification reference through the authenticated Doctor detail
/// endpoint. Notification payload data is never lifecycle authority.
abstract interface class DoctorUrgentCabinetNotificationTargetSource {
  Future<DoctorUrgentCabinetNotificationTarget> resolveNotificationTarget(
    String requestId,
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  });
}

class DoctorUrgentCabinetDevelopmentRequestSource
    implements DoctorUrgentCabinetRequestSource {
  DoctorUrgentCabinetDevelopmentRequestSource({
    Iterable<DoctorUrgentCabinetRequest> requests = const [],
  }) : _requests = List.unmodifiable(requests);

  final List<DoctorUrgentCabinetRequest> _requests;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    if (!kDebugMode) {
      return const DoctorUrgentCabinetFeedUnavailable(
        message:
            "La source de démonstration n'est pas disponible dans cet environnement.",
      );
    }
    if (!context.isComplete) return const DoctorUrgentCabinetFeedEmpty();

    final matching = <String, DoctorUrgentCabinetRequest>{};
    for (final request in _requests) {
      if (doctorUrgentCabinetRequestMatchesContext(request, context)) {
        matching.putIfAbsent(request.stableIdentity, () => request);
      }
    }
    if (matching.isEmpty) return const DoctorUrgentCabinetFeedEmpty();
    return DoctorUrgentCabinetFeedLoaded(matching.values);
  }
}

class DoctorUrgentCabinetUnavailableRequestSource
    implements DoctorUrgentCabinetRequestSource {
  const DoctorUrgentCabinetUnavailableRequestSource();

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    return const DoctorUrgentCabinetFeedUnavailable(
      message:
          "La réception de demandes réelles n'est pas encore connectée à cet espace.",
    );
  }
}

abstract final class DoctorUrgentCabinetRequestSources {
  static DoctorUrgentCabinetFeedState initialStateForCurrentBuild() =>
      kDebugMode
      ? const DoctorUrgentCabinetFeedEmpty()
      : const DoctorUrgentCabinetFeedUnavailable(
          message:
              "La réception de demandes réelles n'est pas encore connectée à cet espace.",
        );

  static DoctorUrgentCabinetRequestSource forCurrentBuild() =>
      forBuild(enableDevelopmentFixtures: kDebugMode);

  @visibleForTesting
  static DoctorUrgentCabinetRequestSource forBuild({
    required bool enableDevelopmentFixtures,
    Iterable<DoctorUrgentCabinetRequest> requests = const [],
  }) => enableDevelopmentFixtures
      ? DoctorUrgentCabinetDevelopmentRequestSource(requests: requests)
      : const DoctorUrgentCabinetUnavailableRequestSource();
}

bool doctorUrgentCabinetRequestMatchesContext(
  DoctorUrgentCabinetRequest request,
  DoctorUrgentCabinetRequestContext context,
) {
  final localCabinet = context.cabinet;
  final validContext =
      request.status == DoctorUrgentCabinetRequestStatus.committed
      ? context.hasCommitmentRecoveryContext
      : context.isComplete;
  if (!validContext || localCabinet == null) return false;
  if (request.targetDoctorId != context.doctorId) return false;
  if (!request.cabinet.matches(localCabinet)) return false;

  return switch (request.dataProvenance) {
    DoctorUrgentCabinetDataProvenance.developmentFixture =>
      request.developmentFixtureKey != null &&
          request.targetCabinetIdentity
              is DoctorUrgentCabinetDevelopmentTargetIdentity &&
          request.serverRequestReference == null &&
          request.fee.provenance ==
              DoctorUrgentCabinetFeeProvenance.developmentFixture,
    DoctorUrgentCabinetDataProvenance.service =>
      request.developmentFixtureKey == null &&
          request.targetCabinetIdentity
              is DoctorUrgentCabinetServerTargetIdentity &&
          request.serverRequestReference != null &&
          request.fee.provenance == DoctorUrgentCabinetFeeProvenance.service,
  };
}
