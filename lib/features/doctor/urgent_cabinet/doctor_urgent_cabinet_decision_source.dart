import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../workspace/doctor_workspace_config.dart';
import 'doctor_urgent_cabinet_commitment.dart';
import 'doctor_urgent_cabinet_decision.dart';
import 'doctor_urgent_cabinet_request.dart';
import 'doctor_urgent_cabinet_request_source.dart';

@immutable
class DoctorUrgentCabinetDecisionContext {
  DoctorUrgentCabinetDecisionContext({
    required String authenticatedDoctorId,
    required DoctorWorkspaceConfig? workspace,
  }) : authenticatedDoctorId = authenticatedDoctorId.trim(),
       requestContext = DoctorUrgentCabinetRequestContext.fromWorkspace(
         workspace,
       ),
       workspaceDoctorId = workspace?.doctorId.trim() ?? '';

  final String authenticatedDoctorId;
  final String workspaceDoctorId;
  final DoctorUrgentCabinetRequestContext requestContext;

  bool get isComplete =>
      authenticatedDoctorId.isNotEmpty &&
      authenticatedDoctorId == workspaceDoctorId &&
      requestContext.isComplete &&
      requestContext.doctorId == authenticatedDoctorId;

  bool get hasCommitmentRecoveryContext =>
      authenticatedDoctorId.isNotEmpty &&
      authenticatedDoctorId == workspaceDoctorId &&
      requestContext.hasCommitmentRecoveryContext &&
      requestContext.doctorId == authenticatedDoctorId;

  String get fingerprint => [
    authenticatedDoctorId,
    workspaceDoctorId,
    requestContext.fingerprint,
  ].join('|');

  bool validates(DoctorUrgentCabinetRequest request) =>
      (request.status == DoctorUrgentCabinetRequestStatus.committed
          ? hasCommitmentRecoveryContext
          : isComplete) &&
      request.targetDoctorId == authenticatedDoctorId &&
      doctorUrgentCabinetRequestMatchesContext(request, requestContext);
}

@immutable
sealed class DoctorUrgentCabinetDecisionResult {
  const DoctorUrgentCabinetDecisionResult({
    required this.requestIdentity,
    required this.action,
    required this.contextFingerprint,
  });

  final String requestIdentity;
  final DoctorUrgentCabinetDecisionAction action;
  final String contextFingerprint;
}

final class DoctorUrgentCabinetAcceptedResult
    extends DoctorUrgentCabinetDecisionResult {
  const DoctorUrgentCabinetAcceptedResult({
    required super.requestIdentity,
    required super.action,
    required super.contextFingerprint,
    this.commitment,
  });

  final DoctorUrgentCabinetCommitment? commitment;
}

final class DoctorUrgentCabinetDeclinedResult
    extends DoctorUrgentCabinetDecisionResult {
  const DoctorUrgentCabinetDeclinedResult({
    required super.requestIdentity,
    required super.action,
    required super.contextFingerprint,
  });
}

final class DoctorUrgentCabinetUnavailableResult
    extends DoctorUrgentCabinetDecisionResult {
  const DoctorUrgentCabinetUnavailableResult({
    required super.requestIdentity,
    required super.action,
    required super.contextFingerprint,
  });
}

final class DoctorUrgentCabinetDecisionDefiniteFailureResult
    extends DoctorUrgentCabinetDecisionResult {
  const DoctorUrgentCabinetDecisionDefiniteFailureResult({
    required super.requestIdentity,
    required super.action,
    required super.contextFingerprint,
    required this.message,
  });

  final String message;
}

final class DoctorUrgentCabinetDecisionUnknownResult
    extends DoctorUrgentCabinetDecisionResult {
  const DoctorUrgentCabinetDecisionUnknownResult({
    required super.requestIdentity,
    required super.action,
    required super.contextFingerprint,
    required this.message,
  });

  final String message;
}

abstract interface class DoctorUrgentCabinetDecisionSource {
  bool get isDevelopmentFixture;

  Future<DoctorUrgentCabinetDecisionResult> decide({
    required DoctorUrgentCabinetRequest request,
    required DoctorUrgentCabinetDecisionAction action,
    required DoctorUrgentCabinetDecisionContext context,
    CancelToken? cancelToken,
  });
}

typedef DoctorUrgentCabinetDevelopmentDecisionExecutor =
    Future<DoctorUrgentCabinetDecisionResult> Function({
      required DoctorUrgentCabinetRequest request,
      required DoctorUrgentCabinetDecisionAction action,
      required DoctorUrgentCabinetDecisionContext context,
    });

typedef DoctorUrgentCabinetDevelopmentRequestAuthorizer =
    bool Function(DoctorUrgentCabinetRequest request);

class DoctorUrgentCabinetDevelopmentDecisionSource
    implements DoctorUrgentCabinetDecisionSource {
  DoctorUrgentCabinetDevelopmentDecisionSource({
    DoctorUrgentCabinetRequest? request,
    DoctorUrgentCabinetDevelopmentRequestAuthorizer? authorizeRequest,
    DoctorUrgentCabinetDevelopmentDecisionExecutor? executor,
  }) : assert(request != null || authorizeRequest != null),
       _authorizedRequest = request,
       _authorizeRequest = authorizeRequest,
       _executor = executor;

  final DoctorUrgentCabinetRequest? _authorizedRequest;
  final DoctorUrgentCabinetDevelopmentRequestAuthorizer? _authorizeRequest;
  final DoctorUrgentCabinetDevelopmentDecisionExecutor? _executor;

  @override
  bool get isDevelopmentFixture => true;

  @override
  Future<DoctorUrgentCabinetDecisionResult> decide({
    required DoctorUrgentCabinetRequest request,
    required DoctorUrgentCabinetDecisionAction action,
    required DoctorUrgentCabinetDecisionContext context,
    CancelToken? cancelToken,
  }) async {
    if (!kDebugMode || !_isAuthorized(request, context)) {
      return _failure(request, action, context);
    }
    final executor = _executor;
    if (executor != null) {
      return executor(request: request, action: action, context: context);
    }
    return switch (action) {
      DoctorUrgentCabinetDecisionAction.accept =>
        DoctorUrgentCabinetAcceptedResult(
          requestIdentity: request.stableIdentity,
          action: action,
          contextFingerprint: context.fingerprint,
        ),
      DoctorUrgentCabinetDecisionAction.refuse =>
        DoctorUrgentCabinetDeclinedResult(
          requestIdentity: request.stableIdentity,
          action: action,
          contextFingerprint: context.fingerprint,
        ),
    };
  }

  bool _isAuthorized(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionContext context,
  ) {
    final authorizedRequest = _authorizedRequest;
    final authorizedTarget = authorizedRequest?.targetCabinetIdentity;
    final requestTarget = request.targetCabinetIdentity;
    final matchesFixedRequest =
        authorizedRequest != null &&
        request.developmentFixtureKey ==
            authorizedRequest.developmentFixtureKey &&
        request.stableIdentity == authorizedRequest.stableIdentity &&
        request.targetDoctorId == authorizedRequest.targetDoctorId &&
        request.cabinet.matches(authorizedRequest.cabinet) &&
        requestTarget is DoctorUrgentCabinetDevelopmentTargetIdentity &&
        authorizedTarget is DoctorUrgentCabinetDevelopmentTargetIdentity &&
        requestTarget.key == authorizedTarget.key;
    final matchesDynamicAuthorization =
        _authorizeRequest?.call(request) == true;
    return context.validates(request) &&
        request.isDevelopmentFixture &&
        request.serverRequestReference == null &&
        request.fee.provenance ==
            DoctorUrgentCabinetFeeProvenance.developmentFixture &&
        requestTarget is DoctorUrgentCabinetDevelopmentTargetIdentity &&
        (matchesFixedRequest || matchesDynamicAuthorization);
  }

  DoctorUrgentCabinetDecisionDefiniteFailureResult _failure(
    DoctorUrgentCabinetRequest request,
    DoctorUrgentCabinetDecisionAction action,
    DoctorUrgentCabinetDecisionContext context,
  ) => DoctorUrgentCabinetDecisionDefiniteFailureResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
    message: 'Cette décision de démonstration ne peut pas être effectuée.',
  );
}

class DoctorUrgentCabinetUnavailableDecisionSource
    implements DoctorUrgentCabinetDecisionSource {
  const DoctorUrgentCabinetUnavailableDecisionSource();

  @override
  bool get isDevelopmentFixture => false;

  @override
  Future<DoctorUrgentCabinetDecisionResult> decide({
    required DoctorUrgentCabinetRequest request,
    required DoctorUrgentCabinetDecisionAction action,
    required DoctorUrgentCabinetDecisionContext context,
    CancelToken? cancelToken,
  }) async => DoctorUrgentCabinetDecisionDefiniteFailureResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
    message: "La décision n'est pas disponible dans cet environnement.",
  );
}
