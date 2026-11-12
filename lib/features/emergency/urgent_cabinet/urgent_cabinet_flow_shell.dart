import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/family_provider.dart';
import 'urgent_cabinet_arrival_instructions_screen.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_care_subject_screen.dart';
import 'urgent_cabinet_clinical_intake_screen.dart';
import 'urgent_cabinet_doctor_detail_screen.dart';
import 'urgent_cabinet_doctor_directory_screen.dart';
import 'urgent_cabinet_doctor_source.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_flow_routes.dart';
import 'urgent_cabinet_request_confirmation_screen.dart';
import 'urgent_cabinet_request_accepted_screen.dart';
import 'urgent_cabinet_request_decision_source.dart';
import 'urgent_cabinet_patient_qr_preview_screen.dart';
import 'urgent_cabinet_patient_lifecycle_controller.dart';
import 'urgent_cabinet_request_recovery_screen.dart';
import 'urgent_cabinet_request_source.dart';
import 'urgent_cabinet_request_state.dart';
import 'urgent_cabinet_request_waiting_screen.dart';
import 'urgent_cabinet_submission_activation_gate.dart';
import 'urgent_cabinet_targeted_request_models.dart';

const bool _p4PatientDecisionControlsRequested = bool.fromEnvironment(
  'P4_PATIENT_DECISION_CONTROLS',
  defaultValue: false,
);

@visibleForTesting
bool canUsePatientDevelopmentDecisionControls({
  required bool isDebugBuild,
  required bool flagEnabled,
  required bool decisionSourceActive,
  required String? authenticatedAccountId,
  required UrgentCabinetRequestDecisionSource decisionSource,
  required UrgentCabinetFlowController controller,
}) {
  final state = controller.requestState;
  final accountId = authenticatedAccountId?.trim();
  if (!isDebugBuild ||
      !flagEnabled ||
      !decisionSourceActive ||
      accountId == null ||
      accountId.isEmpty ||
      decisionSource is! UrgentCabinetDevelopmentDecisionSource ||
      !decisionSource.isDevelopmentFixture ||
      state is! UrgentCabinetRequestPendingDoctorResponse) {
    return false;
  }

  final review = state.review;
  return state.localAttemptGeneration > 0 &&
      state.isDevelopmentSimulation &&
      review.isDevelopmentFixture &&
      review.feeQuote.isDevelopmentFixture &&
      controller.accountId == accountId &&
      controller.selectedSubject == review.careSubject &&
      controller.selectedDoctorId == review.doctorId &&
      controller.selectedCabinetId == review.cabinetId &&
      review.feeQuote.doctorId == review.doctorId &&
      review.feeQuote.cabinetId == review.cabinetId;
}

/// Route-scoped boundary for one P4 urgent CABINET journey.
class UrgentCabinetFlowShell extends StatelessWidget {
  const UrgentCabinetFlowShell({
    super.key,
    this.doctorSource,
    this.requestSource,
    this.decisionSource,
    this.developmentDecisionControlsEnabledForTesting,
    this.submissionActivationGateForTesting,
  });

  final UrgentCabinetDoctorSource? doctorSource;
  final UrgentCabinetRequestSource? requestSource;
  final UrgentCabinetRequestDecisionSource? decisionSource;

  /// Test-only injection seam. Production uses the frozen P4 submission gate.
  @visibleForTesting
  final UrgentCabinetSubmissionActivationGate?
  submissionActivationGateForTesting;

  /// Test seam for the compile-time flag. [kDebugMode] remains mandatory.
  @visibleForTesting
  final bool? developmentDecisionControlsEnabledForTesting;

  @override
  Widget build(BuildContext context) {
    final accountId = context.read<UserProvider>().profile?.userId;
    final parentNavigator = Navigator.of(context);
    return ChangeNotifierProvider(
      create: (_) => UrgentCabinetFlowController(accountId: accountId),
      child: _UrgentCabinetFlowNavigator(
        doctorSource: doctorSource,
        requestSource: requestSource,
        decisionSource: decisionSource,
        developmentDecisionControlsEnabledForTesting:
            developmentDecisionControlsEnabledForTesting,
        submissionActivationGateForTesting: submissionActivationGateForTesting,
        onClose: parentNavigator.maybePop,
      ),
    );
  }
}

class _UrgentCabinetFlowNavigator extends StatefulWidget {
  const _UrgentCabinetFlowNavigator({
    required this.onClose,
    this.doctorSource,
    this.requestSource,
    this.decisionSource,
    this.developmentDecisionControlsEnabledForTesting,
    this.submissionActivationGateForTesting,
  });

  final UrgentCabinetDoctorSource? doctorSource;
  final UrgentCabinetRequestSource? requestSource;
  final UrgentCabinetRequestDecisionSource? decisionSource;
  final bool? developmentDecisionControlsEnabledForTesting;
  final UrgentCabinetSubmissionActivationGate?
  submissionActivationGateForTesting;
  final VoidCallback onClose;

  @override
  State<_UrgentCabinetFlowNavigator> createState() =>
      _UrgentCabinetFlowNavigatorState();
}

class _UrgentCabinetFlowNavigatorState
    extends State<_UrgentCabinetFlowNavigator> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final UrgentCabinetRequestDecisionSource _decisionSource;
  late final _UrgentCabinetRouteObserver _routeObserver;
  StreamSubscription<UrgentCabinetDoctorDecisionEvent>? _decisionSubscription;
  UrgentCabinetFlowController? _flowController;
  UrgentCabinetPatientLifecycleController? _lifecycleController;
  String? _observedAccountId;
  bool _observedInitialAccount = false;
  bool _closing = false;
  bool _terminalNavigationScheduled = false;
  bool _authoritativeRestorationScheduled = false;
  bool _arrivalNavigationOpen = false;
  bool _patientQrNavigationOpen = false;
  bool _developmentAcceptanceEmitting = false;
  bool _familyInvalidationScheduled = false;
  bool _familyLoadObserved = false;
  bool _familyProjectionScheduled = false;
  bool _initialLifecycleProjectionScheduled = false;
  int _decisionSubscriptionEpoch = 0;
  String? _navigatedTerminalKey;
  ({
    String accountId,
    int generation,
    UrgentCabinetCareSubject careSubject,
    String doctorId,
    String cabinetId,
  })?
  _emittedDevelopmentAcceptance;

  @override
  void initState() {
    super.initState();
    _decisionSource =
        widget.decisionSource ??
        UrgentCabinetRequestDecisionSources.forCurrentBuild();
    _routeObserver = _UrgentCabinetRouteObserver(onChanged: _routeChanged);
    _listenForDecisions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flow = context.read<UrgentCabinetFlowController>();
    if (!identical(_flowController, flow)) {
      _flowController?.removeListener(_handleFlowStateChanged);
      _flowController = flow..addListener(_handleFlowStateChanged);
    }
    final lifecycle = context.read<UrgentCabinetPatientLifecycleController?>();
    if (!identical(_lifecycleController, lifecycle)) {
      _lifecycleController?.removeListener(_handleLifecycleChanged);
      _lifecycleController = lifecycle?..addListener(_handleLifecycleChanged);
      _scheduleInitialLifecycleProjection();
    }

    final accountId = context.watch<UserProvider>().profile?.userId;
    final family = context.watch<FamilyProvider>();
    final selectedSubject = flow.selectedSubject;
    if (family.isLoading) _familyLoadObserved = true;
    final authoritativeSubject = _lifecycleController?.snapshot?.careSubject;
    final subjectToValidate = selectedSubject ?? authoritativeSubject;
    if (!_familyInvalidationScheduled &&
        _familyLoadObserved &&
        subjectToValidate?.isSelf == false &&
        !family.isLoading &&
        family.loadFailure == null &&
        !family.members.any(
          (member) => member.id == subjectToValidate?.familyMemberId,
        )) {
      _familyInvalidationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _familyInvalidationScheduled = false;
        if (!mounted) return;
        final accountId = flow.accountId;
        if (accountId != null) {
          unawaited(_lifecycleController?.invalidateSession(accountId));
        }
        flow.invalidateFamilySubjectIfMissing(
          family.members.map((member) => member.id).toSet(),
        );
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          UrgentCabinetFlowRoutes.careSubject,
          (route) => false,
        );
      });
    }
    if (!_familyProjectionScheduled &&
        _familyLoadObserved &&
        authoritativeSubject?.isSelf == false &&
        !family.isLoading &&
        family.loadFailure == null &&
        family.members.any(
          (member) => member.id == authoritativeSubject?.familyMemberId,
        )) {
      _familyProjectionScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _familyProjectionScheduled = false;
        if (mounted) _handleLifecycleChanged();
      });
    }
    if (!_observedInitialAccount) {
      _observedInitialAccount = true;
      _observedAccountId = accountId;
      return;
    }
    if (_observedAccountId == accountId) return;
    final previousAccountId = _observedAccountId;
    _observedAccountId = accountId;
    _restartDecisionSubscription();
    _navigatedTerminalKey = null;
    _emittedDevelopmentAcceptance = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (previousAccountId != null) {
        unawaited(_lifecycleController?.invalidateSession(previousAccountId));
      }
      context.read<UrgentCabinetFlowController>().ensureAccount(accountId);
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        UrgentCabinetFlowRoutes.careSubject,
        (route) => false,
      );
    });
  }

  void _listenForDecisions() {
    final epoch = ++_decisionSubscriptionEpoch;
    _decisionSubscription = _decisionSource.decisions.listen((event) {
      if (!mounted || epoch != _decisionSubscriptionEpoch) return;
      _flowController?.applyDoctorDecision(
        event,
        developmentAcceptanceAuthorized: _decisionSource.isDevelopmentFixture,
      );
    });
  }

  void _restartDecisionSubscription() {
    _decisionSubscriptionEpoch++;
    final previous = _decisionSubscription;
    _decisionSubscription = null;
    if (previous != null) unawaited(previous.cancel());
    _listenForDecisions();
  }

  void _handleFlowStateChanged() {
    _scheduleTerminalNavigation();
  }

  void _scheduleInitialLifecycleProjection() {
    if (_initialLifecycleProjectionScheduled) return;
    _initialLifecycleProjectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLifecycleProjectionScheduled = false;
      if (mounted) _handleLifecycleChanged();
    });
  }

  void _handleLifecycleChanged() {
    if (!mounted) return;
    final lifecycle = _lifecycleController;
    final flow = _flowController;
    final snapshot = lifecycle?.snapshot;
    if (lifecycle == null || flow == null) return;
    if (lifecycle.phase == UrgentCabinetPatientLifecyclePhase.unavailable) {
      // A transient read failure does not revoke the last server-authoritative
      // request. Keep a deliberately opened accepted child route in place;
      // reconnect/resume can reconcile it without fabricating a transition.
      if (lifecycle.hasTransientReadFailure &&
          lifecycle.snapshot?.responseStatus ==
              UrgentCabinetPatientResponseStatus.accepted &&
          flow.requestState is UrgentCabinetRequestAccepted) {
        return;
      }
      final message =
          lifecycle.failure?.message ??
          'Le statut de cette demande ne peut pas être vérifié.';
      if (flow.hasAuthoritativeRequest) {
        flow.markAuthoritativeUnavailable(message);
      } else {
        flow.markAuthorityRecoveryUnavailable(message);
        _scheduleAuthorityUnavailableRecovery();
      }
      return;
    }
    if (snapshot == null) return;
    final patientName = _patientDisplayName(snapshot.careSubject);
    if (patientName == null) return;
    final applied = flow.applyAuthoritativeSnapshot(
      snapshot: snapshot,
      patientDisplayName: patientName,
    );
    if (applied) _scheduleAuthoritativeRestoration(snapshot.requestId);
  }

  void _scheduleAuthoritativeRestoration(String requestId) {
    if (_authoritativeRestorationScheduled || _closing) return;
    _authoritativeRestorationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authoritativeRestorationScheduled = false;
      if (!mounted || _closing) return;
      final snapshot = _lifecycleController?.snapshot;
      final currentRoute = _routeObserver.currentName;
      if (snapshot?.requestId != requestId ||
          currentRoute != UrgentCabinetFlowRoutes.careSubject) {
        return;
      }
      final destination = switch (snapshot!.responseStatus) {
        UrgentCabinetPatientResponseStatus.pending =>
          UrgentCabinetFlowRoutes.requestWaiting,
        UrgentCabinetPatientResponseStatus.accepted =>
          UrgentCabinetFlowRoutes.requestAccepted,
        UrgentCabinetPatientResponseStatus.declined ||
        UrgentCabinetPatientResponseStatus.cancelled ||
        UrgentCabinetPatientResponseStatus.expired ||
        // Unreachable: the repository rejects unrecognized snapshots.
        UrgentCabinetPatientResponseStatus.unknown =>
          UrgentCabinetFlowRoutes.requestRecovery,
      };
      _navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
        destination,
        (route) => route.settings.name == UrgentCabinetFlowRoutes.careSubject,
      );
    });
  }

  void _scheduleAuthorityUnavailableRecovery() {
    if (_authoritativeRestorationScheduled || _closing) return;
    _authoritativeRestorationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authoritativeRestorationScheduled = false;
      if (!mounted ||
          _closing ||
          _flowController?.requestState
              is! UrgentCabinetRequestAuthorityUnavailable ||
          _routeObserver.currentName != UrgentCabinetFlowRoutes.careSubject) {
        return;
      }
      _navigatorKey.currentState?.pushNamed<void>(
        UrgentCabinetFlowRoutes.requestRecovery,
      );
    });
  }

  String? _patientDisplayName(UrgentCabinetCareSubject subject) {
    if (subject.isSelf) {
      final user = context.read<UserProvider>();
      final name = user.user?.displayName.trim().isNotEmpty == true
          ? user.user!.displayName.trim()
          : user.profile?.displayName.trim();
      return name == null || name.isEmpty ? null : name;
    }
    final familyMemberId = subject.familyMemberId;
    for (final member in context.read<FamilyProvider>().members) {
      if (member.id == familyMemberId && member.fullName.trim().isNotEmpty) {
        return member.fullName.trim();
      }
    }
    return null;
  }

  void _routeChanged() {
    final lifecycleVisible =
        _routeObserver.currentName == UrgentCabinetFlowRoutes.requestWaiting ||
        _routeObserver.currentName == UrgentCabinetFlowRoutes.requestAccepted;
    _lifecycleController?.setWaitingRouteActive(lifecycleVisible);
    _scheduleTerminalNavigation();
  }

  bool _canUseDevelopmentDecisionControls() {
    final flow = _flowController;
    if (flow == null) return false;
    return canUsePatientDevelopmentDecisionControls(
      isDebugBuild: kDebugMode,
      flagEnabled:
          widget.developmentDecisionControlsEnabledForTesting ??
          _p4PatientDecisionControlsRequested,
      decisionSourceActive:
          mounted && !_closing && _decisionSubscription != null,
      authenticatedAccountId: context.read<UserProvider>().profile?.userId,
      decisionSource: _decisionSource,
      controller: flow,
    );
  }

  void _simulateDevelopmentDoctorAcceptance() {
    if (_developmentAcceptanceEmitting ||
        !_canUseDevelopmentDecisionControls()) {
      return;
    }

    final flow = _flowController!;
    final state =
        flow.requestState as UrgentCabinetRequestPendingDoctorResponse;
    final review = state.review;
    final attempt = (
      accountId: flow.accountId!,
      generation: state.localAttemptGeneration,
      careSubject: review.careSubject,
      doctorId: review.doctorId,
      cabinetId: review.cabinetId,
    );
    if (_emittedDevelopmentAcceptance == attempt) return;

    _developmentAcceptanceEmitting = true;
    try {
      if (!_canUseDevelopmentDecisionControls()) return;
      final current = flow.requestState;
      if (current is! UrgentCabinetRequestPendingDoctorResponse ||
          current.localAttemptGeneration != attempt.generation ||
          current.review.careSubject != attempt.careSubject ||
          current.review.doctorId != attempt.doctorId ||
          current.review.cabinetId != attempt.cabinetId ||
          flow.accountId != attempt.accountId) {
        return;
      }

      _emittedDevelopmentAcceptance = attempt;
      (_decisionSource as UrgentCabinetDevelopmentDecisionSource).emitAccepted(
        accountId: attempt.accountId,
        localAttemptGeneration: attempt.generation,
        doctorId: attempt.doctorId,
        cabinetId: attempt.cabinetId,
      );
    } finally {
      _developmentAcceptanceEmitting = false;
    }
  }

  void _scheduleTerminalNavigation() {
    final state = _flowController?.requestState;
    if (state is! UrgentCabinetRequestAccepted &&
        state is! UrgentCabinetRequestDeclined &&
        state is! UrgentCabinetRequestCancelled &&
        state is! UrgentCabinetRequestExpired &&
        state is! UrgentCabinetRequestAuthorityUnavailable &&
        state is! UrgentCabinetRequestUnavailable) {
      return;
    }
    final navigationKey = state is UrgentCabinetRequestAttemptState
        ? '${state.phase.name}:${state.localAttemptGeneration}'
        : 'authority-unavailable';
    final currentRoute = _routeObserver.currentName;
    final routeCanTransition = state is UrgentCabinetRequestAccepted
        ? currentRoute == UrgentCabinetFlowRoutes.requestWaiting
        : state is UrgentCabinetRequestDeclined ||
              state is UrgentCabinetRequestCancelled ||
              state is UrgentCabinetRequestExpired
        ? currentRoute == UrgentCabinetFlowRoutes.requestWaiting ||
              currentRoute == UrgentCabinetFlowRoutes.requestAccepted
        : currentRoute == UrgentCabinetFlowRoutes.requestWaiting;
    if (_closing ||
        !routeCanTransition ||
        _navigatedTerminalKey == navigationKey ||
        _terminalNavigationScheduled) {
      return;
    }

    _terminalNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _terminalNavigationScheduled = false;
      if (!mounted || _closing) return;
      final current = _flowController?.requestState;
      if (current is! UrgentCabinetRequestAccepted &&
          current is! UrgentCabinetRequestDeclined &&
          current is! UrgentCabinetRequestCancelled &&
          current is! UrgentCabinetRequestExpired &&
          current is! UrgentCabinetRequestAuthorityUnavailable &&
          current is! UrgentCabinetRequestUnavailable) {
        return;
      }
      final currentKey = current is UrgentCabinetRequestAttemptState
          ? '${current.phase.name}:${current.localAttemptGeneration}'
          : 'authority-unavailable';
      final route = _routeObserver.currentName;
      final routeStillCanTransition = current is UrgentCabinetRequestAccepted
          ? route == UrgentCabinetFlowRoutes.requestWaiting
          : current is UrgentCabinetRequestDeclined ||
                current is UrgentCabinetRequestCancelled ||
                current is UrgentCabinetRequestExpired
          ? route == UrgentCabinetFlowRoutes.requestWaiting ||
                route == UrgentCabinetFlowRoutes.requestAccepted
          : route == UrgentCabinetFlowRoutes.requestWaiting;
      if (currentKey != navigationKey ||
          !routeStillCanTransition ||
          _navigatedTerminalKey == navigationKey) {
        return;
      }
      _navigatedTerminalKey = navigationKey;
      final destination = current is UrgentCabinetRequestAccepted
          ? UrgentCabinetFlowRoutes.requestAccepted
          : UrgentCabinetFlowRoutes.requestRecovery;
      _navigatorKey.currentState?.pushReplacementNamed<void, void>(destination);
    });
  }

  void _closeJourney() {
    if (_closing) return;
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onClose();
    });
  }

  void _endSimulationAndClose() {
    if (_closing) return;
    _decisionSubscriptionEpoch++;
    final subscription = _decisionSubscription;
    _decisionSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _flowController?.endDevelopmentSimulation();
    _closeJourney();
  }

  void _returnToExistingDirectory() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || _closing) return;
    if (_routeObserver.contains(UrgentCabinetFlowRoutes.doctorDirectory)) {
      navigator.popUntil(
        (route) =>
            route.settings.name == UrgentCabinetFlowRoutes.doctorDirectory,
      );
      return;
    }

    navigator.pushNamedAndRemoveUntil<void>(
      UrgentCabinetFlowRoutes.doctorDirectory,
      (route) => route.settings.name == UrgentCabinetFlowRoutes.careSubject,
    );
  }

  Future<void> _cancelAuthoritativeRequest() async {
    await _lifecycleController?.cancel();
  }

  Future<void> _openArrivalInstructions() async {
    if (_closing ||
        _arrivalNavigationOpen ||
        _routeObserver.currentName != UrgentCabinetFlowRoutes.requestAccepted) {
      return;
    }
    final flow = _flowController;
    if (flow == null || !canOpenUrgentCabinetArrivalInstructions(flow)) return;
    _arrivalNavigationOpen = true;
    try {
      await _navigatorKey.currentState?.pushNamed<void>(
        UrgentCabinetFlowRoutes.arrivalInstructions,
      );
    } finally {
      _arrivalNavigationOpen = false;
    }
  }

  Future<void> _openPatientQrPreview() async {
    if (_closing ||
        _patientQrNavigationOpen ||
        _routeObserver.currentName !=
            UrgentCabinetFlowRoutes.arrivalInstructions) {
      return;
    }
    final flow = _flowController;
    if (flow == null || !canOpenUrgentCabinetPatientQrPreview(flow)) return;
    _patientQrNavigationOpen = true;
    try {
      await _navigatorKey.currentState?.pushNamed<void>(
        UrgentCabinetFlowRoutes.patientQrPreview,
      );
    } finally {
      _patientQrNavigationOpen = false;
    }
  }

  Widget _buildArrivalInstructions() {
    final flow = _flowController;
    final state = flow?.requestState;
    if (flow != null &&
        state is UrgentCabinetRequestAccepted &&
        canOpenUrgentCabinetArrivalInstructions(flow)) {
      return UrgentCabinetArrivalInstructionsScreen(
        review: state.review,
        localAttemptGeneration: state.localAttemptGeneration,
        accountId: flow.accountId!,
        authoritativeRequestId: state.authoritativeSnapshot?.requestId,
        onOpenPatientQrPreview: _openPatientQrPreview,
      );
    }
    return const _ArrivalRouteUnavailable();
  }

  Widget _buildPatientQrPreview() {
    final flow = _flowController;
    final state = flow?.requestState;
    if (_routeObserver.currentName ==
            UrgentCabinetFlowRoutes.arrivalInstructions &&
        flow != null &&
        state is UrgentCabinetRequestAccepted &&
        canOpenUrgentCabinetPatientQrPreview(flow)) {
      return UrgentCabinetPatientQrPreviewScreen(
        review: state.review,
        localAttemptGeneration: state.localAttemptGeneration,
        accountId: flow.accountId!,
        authoritativeRequestId: state.authoritativeSnapshot?.requestId,
      );
    }
    return const _PatientQrRouteUnavailable();
  }

  Route<void> _buildRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      UrgentCabinetFlowRoutes.doctorDirectory =>
        UrgentCabinetDoctorDirectoryScreen(
          source: widget.doctorSource,
          onExitJourney: _endSimulationAndClose,
        ),
      UrgentCabinetFlowRoutes.doctorDetail => UrgentCabinetDoctorDetailScreen(
        source: widget.doctorSource,
      ),
      UrgentCabinetFlowRoutes.symptomIntake =>
        const UrgentCabinetClinicalIntakeScreen(),
      UrgentCabinetFlowRoutes.requestConfirmation =>
        UrgentCabinetRequestConfirmationScreen(
          source: widget.doctorSource,
          requestSource: widget.requestSource,
          activationGate:
              widget.submissionActivationGateForTesting ??
              context.read<UrgentCabinetSubmissionActivationGate?>() ??
              UrgentCabinetSubmissionActivationGate.p4Production,
        ),
      UrgentCabinetFlowRoutes.requestWaiting =>
        UrgentCabinetRequestWaitingScreen(
          onEndSimulation: _closeJourney,
          onCancelAuthoritativeRequest: _cancelAuthoritativeRequest,
          onSimulateAcceptance: _canUseDevelopmentDecisionControls()
              ? _simulateDevelopmentDoctorAcceptance
              : null,
        ),
      UrgentCabinetFlowRoutes.requestAccepted =>
        UrgentCabinetRequestAcceptedScreen(
          onExitJourney: _endSimulationAndClose,
          onOpenArrivalInstructions: _openArrivalInstructions,
        ),
      UrgentCabinetFlowRoutes.arrivalInstructions =>
        _buildArrivalInstructions(),
      UrgentCabinetFlowRoutes.patientQrPreview => _buildPatientQrPreview(),
      UrgentCabinetFlowRoutes.requestRecovery =>
        UrgentCabinetRequestRecoveryScreen(
          authorizeNewJourney: () async =>
              await _lifecycleController?.beginNewJourneyAfterTerminal() ??
              false,
          onChooseAnotherDoctor: _returnToExistingDirectory,
          onExitJourney: _endSimulationAndClose,
        ),
      _ => UrgentCabinetCareSubjectScreen(
        onClose: _closeJourney,
        nextRoute: widget.doctorSource != null
            ? UrgentCabinetFlowRoutes.doctorDirectory
            : UrgentCabinetFlowRoutes.symptomIntake,
      ),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler<void>(
      enabled: !_closing,
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        initialRoute: UrgentCabinetFlowRoutes.careSubject,
        onGenerateRoute: _buildRoute,
        observers: [_routeObserver],
      ),
    );
  }

  @override
  void dispose() {
    _flowController?.removeListener(_handleFlowStateChanged);
    _lifecycleController?.setWaitingRouteActive(false);
    _lifecycleController?.removeListener(_handleLifecycleChanged);
    _decisionSubscriptionEpoch++;
    final subscription = _decisionSubscription;
    _decisionSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _decisionSource.dispose();
    super.dispose();
  }
}

class _PatientQrRouteUnavailable extends StatelessWidget {
  const _PatientQrRouteUnavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('QR de présence'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(OmniSpacing.xl),
          child: Text(
            "Cet aperçu n'est plus disponible pour cette demande.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ArrivalRouteUnavailable extends StatelessWidget {
  const _ArrivalRouteUnavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text("Instructions d'arrivée"),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(OmniSpacing.xl),
          child: Text(
            "Ces instructions ne sont pas disponibles pour cette demande.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _UrgentCabinetRouteObserver extends NavigatorObserver {
  _UrgentCabinetRouteObserver({required this.onChanged});

  final VoidCallback onChanged;
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  String? get currentName =>
      _routes.isEmpty ? null : _routes.last.settings.name;

  bool contains(String routeName) {
    return _routes.any((route) => route.settings.name == routeName);
  }

  void _notify() => onChanged();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (oldRoute != null) _routes.remove(oldRoute);
    if (newRoute != null) {
      if (index >= 0 && index <= _routes.length) {
        _routes.insert(index, newRoute);
      } else {
        _routes.add(newRoute);
      }
    }
    _notify();
  }
}
