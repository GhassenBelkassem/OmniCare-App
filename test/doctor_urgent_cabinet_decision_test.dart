import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision_source.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

const _cabinet = DoctorCabinetConfig(
  name: 'Cabinet Mansour',
  governorate: 'Tunis',
  city: 'La Marsa',
  address: '1, rue de la Santé',
);

const _otherCabinet = DoctorCabinetConfig(
  name: 'Cabinet Lac 2',
  governorate: 'Tunis',
  city: 'Les Berges du Lac',
  address: '8, avenue du Lac',
);

DoctorWorkspaceConfig _workspace({
  String doctorId = 'doctor-a',
  bool capability = true,
  DoctorCabinetConfig? cabinet = _cabinet,
}) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: const {DoctorPracticeMode.cabinet},
  services: {
    DoctorWorkspaceService.cabinetConsultations,
    if (capability) DoctorWorkspaceService.urgentCabinetConsultations,
  },
  cabinet: cabinet,
  clinics: const [],
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);

DoctorUrgentCabinetRequest _request({String doctorId = 'doctor-a'}) =>
    DoctorUrgentCabinetRequest(
      developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(
        'request-a',
      ),
      targetDoctorId: doctorId,
      targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
        DoctorUrgentCabinetDevelopmentCabinetKey('cabinet-a'),
      ),
      cabinet: DoctorUrgentCabinetSnapshot(
        name: _cabinet.name,
        address: _cabinet.address,
        city: _cabinet.city,
        governorate: _cabinet.governorate,
      ),
      patient: const DoctorUrgentCabinetPatientProjection.masked(),
      fee: DoctorUrgentCabinetFeeSnapshot(
        amountMilliTnd: 75000,
        currencyCode: 'TND',
        provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
      ),
      dataProvenance: DoctorUrgentCabinetDataProvenance.developmentFixture,
      status: DoctorUrgentCabinetRequestStatus.newRequest,
    );

Future<DoctorUrgentCabinetController> _controller({
  DoctorUrgentCabinetDevelopmentDecisionExecutor? executor,
  DoctorWorkspaceConfig? workspace,
  DoctorUrgentCabinetRequest? request,
}) async {
  final resolvedRequest = request ?? _request();
  final resolvedWorkspace = workspace ?? _workspace();
  final controller = DoctorUrgentCabinetController()
    ..configure(
      authenticatedDoctorId: resolvedWorkspace.doctorId,
      workspaceConfig: resolvedWorkspace,
      requestSource: DoctorUrgentCabinetDevelopmentRequestSource(
        requests: [resolvedRequest],
      ),
      decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
        request: resolvedRequest,
        executor: executor,
      ),
    );
  await Future<void>.delayed(Duration.zero);
  return controller;
}

class _ControlledFeedSource implements DoctorUrgentCabinetRequestSource {
  final List<Completer<DoctorUrgentCabinetFeedState>> completers = [];

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) {
    final completer = Completer<DoctorUrgentCabinetFeedState>();
    completers.add(completer);
    return completer.future;
  }
}

DoctorUrgentCabinetDecisionResult _result({
  required DoctorUrgentCabinetRequest request,
  required DoctorUrgentCabinetDecisionAction action,
  required DoctorUrgentCabinetDecisionContext context,
  required String kind,
}) => switch (kind) {
  'accepted' => DoctorUrgentCabinetAcceptedResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
  ),
  'declined' => DoctorUrgentCabinetDeclinedResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
  ),
  'unavailable' => DoctorUrgentCabinetUnavailableResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
  ),
  'failed' => DoctorUrgentCabinetDecisionDefiniteFailureResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
    message: "La décision n'a pas été envoyée.",
  ),
  _ => DoctorUrgentCabinetDecisionUnknownResult(
    requestIdentity: request.stableIdentity,
    action: action,
    contextFingerprint: context.fingerprint,
    message:
        'Le résultat de cette décision ne peut pas être vérifié pour le moment.',
  ),
};

void main() {
  test(
    'refresh revokes source actionability until successful revalidation',
    () async {
      final request = _request();
      final source = _ControlledFeedSource();
      var decisionCalls = 0;
      final controller = DoctorUrgentCabinetController()
        ..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(),
          requestSource: source,
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
            executor:
                ({required request, required action, required context}) async {
                  decisionCalls++;
                  return _result(
                    request: request,
                    action: action,
                    context: context,
                    kind: 'accepted',
                  );
                },
          ),
        );
      addTearDown(controller.dispose);

      source.completers.single.complete(
        DoctorUrgentCabinetFeedLoaded([request]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleNewRequests, [request]);

      final refresh = controller.refresh();
      expect(controller.feedState, isA<DoctorUrgentCabinetFeedLoading>());
      expect(controller.visibleNewRequests, isEmpty);
      expect(
        controller.containsCurrentRequest(request.stableIdentity),
        isFalse,
      );
      expect(
        await controller.accept(request.stableIdentity),
        DoctorUrgentCabinetDecisionTransition.rejected,
      );
      expect(decisionCalls, 0);

      source.completers.last.complete(DoctorUrgentCabinetFeedLoaded([request]));
      await refresh;
      expect(controller.visibleNewRequests, [request]);
      expect(controller.containsCurrentRequest(request.stableIdentity), isTrue);
      expect(
        await controller.accept(request.stableIdentity),
        DoctorUrgentCabinetDecisionTransition.accepted,
      );
      expect(decisionCalls, 1);
    },
  );

  test(
    'feed error and unavailable retain cached state without authority',
    () async {
      for (final failedState in <DoctorUrgentCabinetFeedState>[
        const DoctorUrgentCabinetFeedError(message: 'error', canRetry: true),
        const DoctorUrgentCabinetFeedUnavailable(message: 'unavailable'),
      ]) {
        final request = _request();
        final source = _ControlledFeedSource();
        var decisionCalls = 0;
        final controller = DoctorUrgentCabinetController()
          ..configure(
            authenticatedDoctorId: 'doctor-a',
            workspaceConfig: _workspace(),
            requestSource: source,
            decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
              request: request,
              executor:
                  ({
                    required request,
                    required action,
                    required context,
                  }) async {
                    decisionCalls++;
                    return _result(
                      request: request,
                      action: action,
                      context: context,
                      kind: 'accepted',
                    );
                  },
            ),
          );
        addTearDown(controller.dispose);
        source.completers.single.complete(
          DoctorUrgentCabinetFeedLoaded([request]),
        );
        await Future<void>.delayed(Duration.zero);

        final refresh = controller.refresh();
        source.completers.last.complete(failedState);
        await refresh;

        expect(
          controller.stateFor(request.stableIdentity),
          isA<DoctorUrgentCabinetAwaitingDecision>(),
        );
        expect(controller.visibleNewRequests, isEmpty);
        expect(
          await controller.refuse(request.stableIdentity),
          DoctorUrgentCabinetDecisionTransition.rejected,
        );
        expect(decisionCalls, 0);
      }
    },
  );

  test(
    'in-flight result resolves while failed refresh prevents a second action',
    () async {
      final request = _request();
      final feed = _ControlledFeedSource();
      final decision = Completer<DoctorUrgentCabinetDecisionResult>();
      var decisionCalls = 0;
      final controller = DoctorUrgentCabinetController()
        ..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(),
          requestSource: feed,
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
            executor: ({required request, required action, required context}) {
              decisionCalls++;
              return decision.future;
            },
          ),
        );
      addTearDown(controller.dispose);
      feed.completers.single.complete(DoctorUrgentCabinetFeedLoaded([request]));
      await Future<void>.delayed(Duration.zero);

      final operation = controller.accept(request.stableIdentity);
      final context = controller.context!;
      final refresh = controller.refresh();
      expect(
        await controller.refuse(request.stableIdentity),
        DoctorUrgentCabinetDecisionTransition.rejected,
      );
      feed.completers.last.complete(
        const DoctorUrgentCabinetFeedError(message: 'error', canRetry: true),
      );
      await refresh;
      expect(controller.visibleNewRequests, isEmpty);

      decision.complete(
        _result(
          request: request,
          action: DoctorUrgentCabinetDecisionAction.accept,
          context: context,
          kind: 'accepted',
        ),
      );
      expect(await operation, DoctorUrgentCabinetDecisionTransition.accepted);
      expect(
        controller.stateFor(request.stableIdentity),
        isA<DoctorUrgentCabinetAccepted>(),
      );
      expect(decisionCalls, 1);
    },
  );

  test('in-flight refusal resolves across feed unavailability', () async {
    final request = _request();
    final feed = _ControlledFeedSource();
    final decision = Completer<DoctorUrgentCabinetDecisionResult>();
    var decisionCalls = 0;
    final controller = DoctorUrgentCabinetController()
      ..configure(
        authenticatedDoctorId: 'doctor-a',
        workspaceConfig: _workspace(),
        requestSource: feed,
        decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
          request: request,
          executor: ({required request, required action, required context}) {
            decisionCalls++;
            return decision.future;
          },
        ),
      );
    addTearDown(controller.dispose);
    feed.completers.single.complete(DoctorUrgentCabinetFeedLoaded([request]));
    await Future<void>.delayed(Duration.zero);

    final operation = controller.refuse(request.stableIdentity);
    final context = controller.context!;
    final refresh = controller.refresh();
    feed.completers.last.complete(
      const DoctorUrgentCabinetFeedUnavailable(message: 'unavailable'),
    );
    await refresh;
    expect(
      await controller.accept(request.stableIdentity),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );

    decision.complete(
      _result(
        request: request,
        action: DoctorUrgentCabinetDecisionAction.refuse,
        context: context,
        kind: 'declined',
      ),
    );
    expect(await operation, DoctorUrgentCabinetDecisionTransition.declined);
    expect(
      controller.stateFor(request.stableIdentity),
      isA<DoctorUrgentCabinetDeclined>(),
    );
    expect(decisionCalls, 1);
  });

  test(
    'manual request remains actionable across external feed failure',
    () async {
      final source = _ControlledFeedSource();
      final controller = DoctorUrgentCabinetController()
        ..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(),
          requestSource: source,
        );
      addTearDown(controller.dispose);
      source.completers.single.complete(const DoctorUrgentCabinetFeedEmpty());
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.simulateDevelopmentRequest(),
        DoctorUrgentCabinetSimulationTransition.created,
      );
      final manual = controller.visibleNewRequests.single;

      final refresh = controller.refresh();
      source.completers.last.complete(
        const DoctorUrgentCabinetFeedUnavailable(message: 'unavailable'),
      );
      await refresh;

      expect(controller.visibleNewRequests, [manual]);
      expect(controller.containsCurrentRequest(manual.stableIdentity), isTrue);
      expect(
        await controller.accept(manual.stableIdentity),
        DoctorUrgentCabinetDecisionTransition.accepted,
      );
    },
  );

  test(
    'terminal outcomes survive feed failures and are never reanimated',
    () async {
      for (final kind in ['accepted', 'declined', 'unavailable']) {
        final request = _request();
        final feed = _ControlledFeedSource();
        final controller = DoctorUrgentCabinetController()
          ..configure(
            authenticatedDoctorId: 'doctor-a',
            workspaceConfig: _workspace(),
            requestSource: feed,
            decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
              request: request,
              executor:
                  ({
                    required request,
                    required action,
                    required context,
                  }) async => _result(
                    request: request,
                    action: action,
                    context: context,
                    kind: kind,
                  ),
            ),
          );
        addTearDown(controller.dispose);
        feed.completers.single.complete(
          DoctorUrgentCabinetFeedLoaded([request]),
        );
        await Future<void>.delayed(Duration.zero);

        final transition = kind == 'declined'
            ? await controller.refuse(request.stableIdentity)
            : await controller.accept(request.stableIdentity);
        expect(transition.name, kind);
        final terminal = controller.stateFor(request.stableIdentity);
        expect(terminal?.isTerminal, isTrue);

        final failedRefresh = controller.refresh();
        feed.completers.last.complete(
          const DoctorUrgentCabinetFeedError(message: 'error', canRetry: true),
        );
        await failedRefresh;
        expect(controller.stateFor(request.stableIdentity), same(terminal));

        final unavailableRefresh = controller.refresh();
        feed.completers.last.complete(
          const DoctorUrgentCabinetFeedUnavailable(message: 'unavailable'),
        );
        await unavailableRefresh;
        expect(controller.stateFor(request.stableIdentity), same(terminal));

        final recoveredRefresh = controller.refresh();
        feed.completers.last.complete(DoctorUrgentCabinetFeedLoaded([request]));
        await recoveredRefresh;
        expect(controller.stateFor(request.stableIdentity), same(terminal));
        expect(controller.visibleNewRequests, isEmpty);
      }
    },
  );

  test('awaiting accepts once and survives feed refresh', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetAwaitingDecision>(),
    );
    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.accepted,
    );
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetAccepted>(),
    );
    expect(controller.visibleNewRequests, isEmpty);
    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );

    await controller.refresh();
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetAccepted>(),
    );
  });

  test('awaiting refusal is terminal and cannot become accepted', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    expect(
      await controller.refuse('request-a'),
      DoctorUrgentCabinetDecisionTransition.declined,
    );
    expect(
      await controller.refuse('request-a'),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );
    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetDeclined>(),
    );
  });

  test(
    'rapid taps set progress synchronously and invoke one operation',
    () async {
      final completer = Completer<DoctorUrgentCabinetDecisionResult>();
      var calls = 0;
      final controller = await _controller(
        executor: ({required request, required action, required context}) {
          calls++;
          return completer.future;
        },
      );
      addTearDown(controller.dispose);

      final first = controller.accept('request-a');
      expect(
        controller.stateFor('request-a'),
        isA<DoctorUrgentCabinetDecisionInProgress>(),
      );
      final duplicate = controller.accept('request-a');
      expect(await duplicate, DoctorUrgentCabinetDecisionTransition.rejected);
      expect(calls, 1);

      final context = controller.context!;
      completer.complete(
        _result(
          request: _request(),
          action: DoctorUrgentCabinetDecisionAction.accept,
          context: context,
          kind: 'accepted',
        ),
      );
      expect(await first, DoctorUrgentCabinetDecisionTransition.accepted);
    },
  );

  test('definite failure retries only the same operation', () async {
    var calls = 0;
    final controller = await _controller(
      executor: ({required request, required action, required context}) async {
        calls++;
        return _result(
          request: request,
          action: action,
          context: context,
          kind: calls == 1 ? 'failed' : 'accepted',
        );
      },
    );
    addTearDown(controller.dispose);

    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.failed,
    );
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetDecisionFailed>(),
    );
    expect(
      await controller.refuse('request-a'),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );
    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.accepted,
    );
    expect(calls, 2);
  });

  test('unknown outcome locks conflicting and repeated decisions', () async {
    final controller = await _controller(
      executor: ({required request, required action, required context}) async =>
          _result(
            request: request,
            action: action,
            context: context,
            kind: 'unknown',
          ),
    );
    addTearDown(controller.dispose);

    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.unknown,
    );
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetDecisionOutcomeUnknown>(),
    );
    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );
    expect(
      await controller.refuse('request-a'),
      DoctorUrgentCabinetDecisionTransition.rejected,
    );
  });

  test('unavailable remains distinct from refusal', () async {
    final controller = await _controller(
      executor: ({required request, required action, required context}) async =>
          _result(
            request: request,
            action: action,
            context: context,
            kind: 'unavailable',
          ),
    );
    addTearDown(controller.dispose);

    expect(
      await controller.accept('request-a'),
      DoctorUrgentCabinetDecisionTransition.unavailable,
    );
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetUnavailable>(),
    );
  });

  test('reset fences an old completion and restores the fixture', () async {
    final completer = Completer<DoctorUrgentCabinetDecisionResult>();
    final controller = await _controller(
      executor: ({required request, required action, required context}) =>
          completer.future,
    );
    addTearDown(controller.dispose);

    final oldOperation = controller.accept('request-a');
    final oldContext = controller.context!;
    controller.resetDevelopmentSimulation();
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetAwaitingDecision>(),
    );

    completer.complete(
      _result(
        request: _request(),
        action: DoctorUrgentCabinetDecisionAction.accept,
        context: oldContext,
        kind: 'accepted',
      ),
    );
    expect(await oldOperation, DoctorUrgentCabinetDecisionTransition.obsolete);
    expect(
      controller.stateFor('request-a'),
      isA<DoctorUrgentCabinetAwaitingDecision>(),
    );
  });

  test(
    'Doctor, cabinet capability and source provenance fail closed',
    () async {
      final wrongDoctor = await _controller(
        workspace: _workspace(doctorId: 'doctor-b'),
        request: _request(doctorId: 'doctor-a'),
      );
      addTearDown(wrongDoctor.dispose);
      expect(wrongDoctor.entries, isEmpty);

      final noCapability = await _controller(
        workspace: _workspace(capability: false),
      );
      addTearDown(noCapability.dispose);
      expect(noCapability.entries, isEmpty);

      final request = _request();
      final unavailableSourceController = DoctorUrgentCabinetController()
        ..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(
            requests: [request],
          ),
          decisionSource: const DoctorUrgentCabinetUnavailableDecisionSource(),
        );
      addTearDown(unavailableSourceController.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(
        await unavailableSourceController.accept('request-a'),
        DoctorUrgentCabinetDecisionTransition.rejected,
      );
    },
  );

  test('dispose prevents a late decision result from mutating state', () async {
    final completer = Completer<DoctorUrgentCabinetDecisionResult>();
    final controller = await _controller(
      executor: ({required request, required action, required context}) =>
          completer.future,
    );
    final operation = controller.accept('request-a');
    final context = controller.context!;
    controller.dispose();
    completer.complete(
      _result(
        request: _request(),
        action: DoctorUrgentCabinetDecisionAction.accept,
        context: context,
        kind: 'accepted',
      ),
    );
    expect(await operation, DoctorUrgentCabinetDecisionTransition.obsolete);
  });

  test('manual simulator creates one validated request at a time', () async {
    final controller = DoctorUrgentCabinetController()
      ..configure(
        authenticatedDoctorId: 'doctor-a',
        workspaceConfig: _workspace(),
        requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
      );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isDevelopmentSimulationAvailable, isTrue);
    expect(
      controller.simulateDevelopmentRequest(),
      DoctorUrgentCabinetSimulationTransition.created,
    );
    expect(
      controller.simulateDevelopmentRequest(),
      DoctorUrgentCabinetSimulationTransition.activeRequestExists,
    );
    expect(controller.visibleNewRequests, hasLength(1));
    final first = controller.visibleNewRequests.single;
    expect(first.targetDoctorId, 'doctor-a');
    expect(first.cabinet.matches(_request().cabinet), isTrue);
    expect(first.developmentFixtureKey, isNotNull);
    expect(first.serverRequestReference, isNull);
    expect(first.fee.formattedAmount, '75,000 DT');
    expect(first.patient.label, 'Patient concerné');
    expect(first.patient.disclosure, 'Identité non communiquée à ce stade');

    expect(
      await controller.accept(first.stableIdentity),
      DoctorUrgentCabinetDecisionTransition.accepted,
    );
    expect(
      controller.simulateDevelopmentRequest(),
      DoctorUrgentCabinetSimulationTransition.created,
    );
    final second = controller.visibleNewRequests.single;
    expect(second.stableIdentity, isNot(first.stableIdentity));
    expect(
      controller.stateFor(first.stableIdentity),
      isA<DoctorUrgentCabinetAccepted>(),
    );

    expect(
      await controller.refuse(second.stableIdentity),
      DoctorUrgentCabinetDecisionTransition.declined,
    );
    expect(controller.terminalDecisions, hasLength(2));
    expect(
      controller.stateFor(first.stableIdentity),
      isA<DoctorUrgentCabinetAccepted>(),
    );
    expect(
      controller.stateFor(second.stableIdentity),
      isA<DoctorUrgentCabinetDeclined>(),
    );
  });

  test(
    'manual simulator fails closed outside an exact debug context',
    () async {
      final profileController =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: 'doctor-a',
              workspaceConfig: _workspace(),
            );
      addTearDown(profileController.dispose);
      expect(profileController.isDevelopmentSimulationAvailable, isFalse);
      expect(
        profileController.simulateDevelopmentRequest(),
        DoctorUrgentCabinetSimulationTransition.blocked,
      );

      for (final controller in [
        DoctorUrgentCabinetController()..configure(
          authenticatedDoctorId: 'doctor-b',
          workspaceConfig: _workspace(doctorId: 'doctor-a'),
        ),
        DoctorUrgentCabinetController()..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(capability: false),
        ),
        DoctorUrgentCabinetController()..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(cabinet: null),
        ),
      ]) {
        addTearDown(controller.dispose);
        expect(controller.isDevelopmentSimulationAvailable, isFalse);
        expect(
          controller.simulateDevelopmentRequest(),
          DoctorUrgentCabinetSimulationTransition.blocked,
        );
      }
    },
  );

  test(
    'account and cabinet reconfiguration clear manual simulations',
    () async {
      final emptySource = DoctorUrgentCabinetDevelopmentRequestSource();
      final controller = DoctorUrgentCabinetController()
        ..configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(),
          requestSource: emptySource,
        );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.simulateDevelopmentRequest(),
        DoctorUrgentCabinetSimulationTransition.created,
      );
      final firstIdentity = controller.visibleNewRequests.single.stableIdentity;

      controller.configure(
        authenticatedDoctorId: 'doctor-a',
        workspaceConfig: _workspace(cabinet: _otherCabinet),
        requestSource: emptySource,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.stateFor(firstIdentity), isNull);
      expect(controller.entries, isEmpty);
      expect(
        controller.simulateDevelopmentRequest(),
        DoctorUrgentCabinetSimulationTransition.created,
      );
      final secondIdentity =
          controller.visibleNewRequests.single.stableIdentity;

      controller.configure(
        authenticatedDoctorId: 'doctor-b',
        workspaceConfig: _workspace(doctorId: 'doctor-b'),
        requestSource: emptySource,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.stateFor(secondIdentity), isNull);
      expect(controller.entries, isEmpty);
    },
  );
}
