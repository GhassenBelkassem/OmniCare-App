import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../workspace/doctor_workspace_config.dart';
import '../active_consultation/doctor_active_consultation_controller.dart';
import '../consultation_detail_screen.dart';
import 'doctor_urgent_cabinet_accepted_card.dart';
import 'doctor_urgent_cabinet_accepted_sheet.dart';
import 'doctor_urgent_cabinet_check_in_entry_sheet.dart';
import 'doctor_urgent_cabinet_controller.dart';
import 'doctor_urgent_cabinet_decision.dart';
import 'doctor_urgent_cabinet_foreground_refresh.dart';
import 'doctor_urgent_cabinet_qr_preview_screen.dart';
import 'doctor_urgent_cabinet_request.dart';
import 'doctor_urgent_cabinet_request_card.dart';
import 'doctor_urgent_cabinet_request_sheet.dart';
import 'doctor_urgent_cabinet_request_source.dart';

/// D-UI-01 presentation for a locally configured urgent CABINET workspace.
///
/// Feed and decision state are owned above this remountable presentation.
class DoctorUrgentCabinetScreen extends StatefulWidget {
  const DoctorUrgentCabinetScreen({
    super.key,
    required this.workspaceConfig,
    required this.controller,
    this.activeConsultationController,
  });

  final DoctorWorkspaceConfig? workspaceConfig;
  final DoctorUrgentCabinetController controller;
  final DoctorActiveConsultationController? activeConsultationController;

  @override
  State<DoctorUrgentCabinetScreen> createState() =>
      _DoctorUrgentCabinetScreenState();
}

class _DoctorUrgentCabinetScreenState extends State<DoctorUrgentCabinetScreen>
    with WidgetsBindingObserver {
  BuildContext? _openSheetContext;
  Object? _openSheetToken;
  String? _openRequestIdentity;
  String? _openAcceptedRequestIdentity;
  NavigatorState? _openScannerNavigator;
  Route<void>? _openScannerRoute;
  Object? _openScannerToken;
  String? _openScannerRequestIdentity;
  bool _sheetDismissScheduled = false;
  bool _scannerDismissScheduled = false;
  bool _scannerWasInvalidated = false;
  bool _showAllAcceptedRequests = false;
  String? _contextFingerprint;
  late DoctorUrgentCabinetForegroundRefresh _foregroundRefresh;

  DoctorCabinetConfig? get _completeCabinet {
    final cabinet = widget.workspaceConfig?.cabinet;
    if (cabinet == null ||
        cabinet.name.trim().isEmpty ||
        cabinet.city.trim().isEmpty ||
        cabinet.governorate.trim().isEmpty ||
        cabinet.address.trim().isEmpty) {
      return null;
    }
    return cabinet;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contextFingerprint = widget.controller.context?.fingerprint;
    widget.controller.addListener(_handleControllerChanged);
    _foregroundRefresh = _buildForegroundRefresh(widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _consumeNotificationOpenIntent();
        if (widget.controller.canReconcileInForeground) {
          _foregroundRefresh.start();
        }
      }
    });
  }

  DoctorUrgentCabinetForegroundRefresh _buildForegroundRefresh(
    DoctorUrgentCabinetController controller,
  ) => DoctorUrgentCabinetForegroundRefresh(
    refresh: () => controller.refresh(showLoading: false),
  );

  @override
  void didUpdateWidget(covariant DoctorUrgentCabinetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    _foregroundRefresh.dispose();
    _dismissOpenSheet();
    _dismissOpenScanner(invalidated: true);
    _showAllAcceptedRequests = false;
    _contextFingerprint = widget.controller.context?.fingerprint;
    widget.controller.addListener(_handleControllerChanged);
    _foregroundRefresh = _buildForegroundRefresh(widget.controller);
    if (widget.controller.canReconcileInForeground) {
      _foregroundRefresh.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundRefresh.dispose();
    widget.controller.removeListener(_handleControllerChanged);
    _dismissOpenSheet();
    _dismissOpenScanner(invalidated: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.controller.canReconcileInForeground) {
          _foregroundRefresh.start();
        }
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foregroundRefresh.pause();
        return;
    }
  }

  void _handleControllerChanged() {
    final nextContextFingerprint = widget.controller.context?.fingerprint;
    if (_contextFingerprint != nextContextFingerprint) {
      _contextFingerprint = nextContextFingerprint;
      _showAllAcceptedRequests = false;
      if (widget.controller.canReconcileInForeground) {
        _foregroundRefresh.start();
      } else {
        _foregroundRefresh.pause();
      }
    }
    final identity = _openRequestIdentity;
    if (identity != null) {
      if (!widget.controller.containsCurrentRequest(identity)) {
        _dismissOpenSheet();
      }
    }
    final acceptedIdentity = _openAcceptedRequestIdentity;
    if (acceptedIdentity != null &&
        _currentAcceptedRequest(acceptedIdentity) == null) {
      _dismissOpenSheet();
    }
    final scannerIdentity = _openScannerRequestIdentity;
    if (scannerIdentity != null && !_canOpenScannerPreview(scannerIdentity)) {
      _dismissOpenScanner(invalidated: true);
    }
    _consumeNotificationOpenIntent();
    if (mounted) setState(() {});
  }

  void _consumeNotificationOpenIntent() {
    final intent = widget.controller.takeNotificationOpenIntent();
    if (intent == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (intent.state) {
        case DoctorUrgentCabinetNotificationTargetState.pending:
          final request = widget.controller
              .stateFor(intent.requestIdentity)
              ?.request;
          if (request != null && _isCurrentRequest(request)) {
            unawaited(_openRequest(request));
          }
        case DoctorUrgentCabinetNotificationTargetState.accepted:
          final accepted = _currentAcceptedRequest(intent.requestIdentity);
          if (accepted != null) unawaited(_openAcceptedRequest(accepted));
        case DoctorUrgentCabinetNotificationTargetState.declined:
          _showNotificationStatus('Cette demande a déjà été refusée.');
        case DoctorUrgentCabinetNotificationTargetState.cancelled:
          _showNotificationStatus("Cette demande n’est plus active.");
        case DoctorUrgentCabinetNotificationTargetState.expired:
          _showNotificationStatus('Cette demande a expiré.');
      }
    });
  }

  void _showNotificationStatus(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openRequest(DoctorUrgentCabinetRequest request) async {
    if (_openSheetToken != null ||
        _openScannerToken != null ||
        _openRequestIdentity != null ||
        _openAcceptedRequestIdentity != null ||
        !_isCurrentRequest(request)) {
      return;
    }
    _openRequestIdentity = request.stableIdentity;
    final authoritative = await widget.controller.loadAuthoritativeDetail(
      request.stableIdentity,
    );
    if (!mounted ||
        authoritative == null ||
        !_isCurrentRequest(authoritative)) {
      _openRequestIdentity = null;
      return;
    }
    final sheetToken = Object();
    _openAcceptedRequestIdentity = null;
    await showDoctorUrgentCabinetRequestSheet(
      context,
      request: authoritative,
      controller: widget.controller,
      onSheetContextReady: (sheetContext) {
        if (!mounted || !_isCurrentRequest(authoritative)) {
          _scheduleSheetDismiss(sheetContext);
          return;
        }
        _openSheetToken = sheetToken;
        _openSheetContext = sheetContext;
      },
    );
    if (identical(_openSheetToken, sheetToken)) {
      _openSheetToken = null;
      _openSheetContext = null;
      _openRequestIdentity = null;
    }
  }

  Future<void> _openAcceptedRequest(
    DoctorUrgentCabinetAccepted accepted,
  ) async {
    final identity = accepted.request.stableIdentity;
    final current = _currentAcceptedRequest(identity);
    final originFocusNode = FocusManager.instance.primaryFocus;
    final expectedContextFingerprint = widget.controller.context?.fingerprint;
    if (_openSheetToken != null ||
        _openScannerToken != null ||
        _openRequestIdentity != null ||
        _openAcceptedRequestIdentity != null ||
        current == null) {
      return;
    }

    final request = current.request;
    final commitment = widget.controller.commitmentFor(identity);
    final sheetToken = Object();
    _openRequestIdentity = null;
    _openAcceptedRequestIdentity = identity;
    final action = await showDoctorUrgentCabinetAcceptedSheet(
      context,
      request: request,
      arrivalVerificationEnabled: widget.controller.canVerifyArrival(identity),
      consultationStartEnabled:
          widget.activeConsultationController != null &&
          widget.controller.canStartConsultation(identity),
      arrivedWaitingForCapacity:
          commitment?.arrivalVerifiedAt != null &&
          commitment?.consultationId == null &&
          commitment?.canStartConsultation != true,
      onSheetContextReady: (sheetContext) {
        if (!mounted || _currentAcceptedRequest(identity) == null) {
          _scheduleSheetDismiss(sheetContext);
          return;
        }
        _openSheetToken = sheetToken;
        _openSheetContext = sheetContext;
      },
    );
    if (identical(_openSheetToken, sheetToken)) {
      _openSheetToken = null;
      _openSheetContext = null;
      _openAcceptedRequestIdentity = null;
    }
    if (!mounted || _currentAcceptedRequest(identity) == null) {
      return;
    }
    if (action == DoctorUrgentCabinetAcceptedSheetAction.startConsultation) {
      await _startConsultation(identity);
      return;
    }
    if (action != DoctorUrgentCabinetAcceptedSheetAction.verifyArrival) return;
    await _openCheckInEntry(
      identity,
      originFocusNode: originFocusNode,
      expectedContextFingerprint: expectedContextFingerprint,
    );
  }

  Future<void> _startConsultation(String identity) async {
    final activeController = widget.activeConsultationController;
    final commitment = widget.controller.commitmentFor(identity);
    if (activeController == null ||
        commitment == null ||
        !commitment.canStartConsultation) {
      return;
    }
    final outcome = await activeController.startUrgentCabinet(
      commitment.commitmentId,
      commitment.revision,
    );
    if (!mounted) return;
    if (outcome != DoctorConsultationStartOutcome.started &&
        outcome != DoctorConsultationStartOutcome.recovered) {
      _showNotificationStatus(
        activeController.startErrorMessage ??
            'Impossible de démarrer la consultation.',
      );
      await widget.controller.refresh(showLoading: false);
      return;
    }
    final active = activeController.active;
    if (active == null) return;
    await widget.controller.refresh(showLoading: false);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConsultationDetailScreen(
          consultationId: active.consultationId,
          activeWorkspace: true,
          onCompleted: (consultationId) async {
            await activeController.reconcileCompleted(consultationId);
            await widget.controller.refresh(showLoading: false);
          },
          consultation: <String, dynamic>{
            'id': active.consultationId,
            'sourceId': active.sourceId,
            'status': active.status.name,
            'urgentIntakeBodyAreas':
                _currentAcceptedRequest(identity)?.request.bodyAreas
                    .map((area) => area.frenchLabel)
                    .toList(growable: false) ??
                const <String>[],
            'urgentIntakePainScore': _currentAcceptedRequest(
              identity,
            )?.request.painScore,
            'urgentIntakeDescription': _currentAcceptedRequest(
              identity,
            )?.request.shortDescription,
          },
        ),
      ),
    );
  }

  Future<void> _openCheckInEntry(
    String identity, {
    required FocusNode? originFocusNode,
    required String? expectedContextFingerprint,
  }) async {
    if (_openSheetToken != null ||
        _openScannerToken != null ||
        _openRequestIdentity != null ||
        _openAcceptedRequestIdentity != null ||
        _currentAcceptedRequest(identity) == null) {
      return;
    }

    final sheetToken = Object();
    _openAcceptedRequestIdentity = identity;
    final action = await showDoctorUrgentCabinetCheckInEntrySheet(
      context,
      scannerPreviewEnabled: _canOpenScannerPreview(
        identity,
        expectedContextFingerprint: expectedContextFingerprint,
      ),
      onVerifyToken: widget.controller.canVerifyArrival(identity)
          ? (token) => widget.controller.verifyArrival(identity, token)
          : null,
      onSheetContextReady: (sheetContext) {
        if (!mounted || _currentAcceptedRequest(identity) == null) {
          _scheduleSheetDismiss(sheetContext);
          return;
        }
        _openSheetToken = sheetToken;
        _openSheetContext = sheetContext;
      },
    );
    if (identical(_openSheetToken, sheetToken)) {
      _openSheetToken = null;
      _openSheetContext = null;
      _openAcceptedRequestIdentity = null;
    }
    if (!mounted ||
        action !=
            DoctorUrgentCabinetCheckInEntrySheetAction.openScannerPreview ||
        !_canOpenScannerPreview(
          identity,
          expectedContextFingerprint: expectedContextFingerprint,
        )) {
      return;
    }
    await _openScannerPreview(
      identity,
      originFocusNode: originFocusNode,
      expectedContextFingerprint: expectedContextFingerprint,
    );
  }

  bool _canOpenScannerPreview(
    String identity, {
    String? expectedContextFingerprint,
  }) {
    final current = _currentAcceptedRequest(identity);
    final contextFingerprint = widget.controller.context?.fingerprint;
    return kDebugMode &&
        current != null &&
        current.request.isDevelopmentFixture &&
        widget.controller.isDevelopmentSimulationAvailable &&
        (expectedContextFingerprint == null ||
            expectedContextFingerprint == contextFingerprint);
  }

  Future<void> _openScannerPreview(
    String identity, {
    required FocusNode? originFocusNode,
    required String? expectedContextFingerprint,
  }) async {
    if (_openSheetToken != null ||
        _openScannerToken != null ||
        _openRequestIdentity != null ||
        _openAcceptedRequestIdentity != null ||
        !_canOpenScannerPreview(
          identity,
          expectedContextFingerprint: expectedContextFingerprint,
        )) {
      return;
    }

    final accepted = _currentAcceptedRequest(identity)!;
    final navigator = Navigator.of(context);
    final scannerToken = Object();
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'doctor-urgent-cabinet-qr-preview'),
      builder: (_) => DoctorUrgentCabinetQrPreviewScreen(
        request: accepted.request,
        debugScenariosEnabled: true,
      ),
    );

    _openScannerNavigator = navigator;
    _openScannerRoute = route;
    _openScannerToken = scannerToken;
    _openScannerRequestIdentity = identity;
    _scannerWasInvalidated = false;
    await navigator.push<void>(route);

    final wasInvalidated = _scannerWasInvalidated;
    if (identical(_openScannerToken, scannerToken)) {
      _openScannerNavigator = null;
      _openScannerRoute = null;
      _openScannerToken = null;
      _openScannerRequestIdentity = null;
      _scannerWasInvalidated = false;
    }
    if (!wasInvalidated &&
        mounted &&
        _canOpenScannerPreview(
          identity,
          expectedContextFingerprint: expectedContextFingerprint,
        )) {
      _restoreOriginFocus(originFocusNode);
    }
  }

  bool _isCurrentRequest(DoctorUrgentCabinetRequest request) {
    return widget.controller.containsCurrentRequest(request.stableIdentity) &&
        widget.controller.context?.validates(request) == true;
  }

  DoctorUrgentCabinetAccepted? _currentAcceptedRequest(String identity) {
    final state = widget.controller.stateFor(identity);
    if (state is! DoctorUrgentCabinetAccepted ||
        state.request.stableIdentity != identity ||
        widget.controller.context?.validates(state.request) != true) {
      return null;
    }
    return state;
  }

  void _dismissOpenSheet() {
    final sheetContext = _openSheetContext;
    _openSheetToken = null;
    _openSheetContext = null;
    _openRequestIdentity = null;
    _openAcceptedRequestIdentity = null;
    if (sheetContext == null) return;
    _scheduleSheetDismiss(sheetContext);
  }

  void _dismissOpenScanner({required bool invalidated}) {
    final navigator = _openScannerNavigator;
    final route = _openScannerRoute;
    if (invalidated) _scannerWasInvalidated = true;
    _openScannerNavigator = null;
    _openScannerRoute = null;
    _openScannerToken = null;
    _openScannerRequestIdentity = null;
    if (navigator == null || route == null || _scannerDismissScheduled) return;
    _scannerDismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerDismissScheduled = false;
      if (!navigator.mounted || !route.isActive) return;
      navigator.removeRoute(route);
    });
  }

  void _restoreOriginFocus(FocusNode? originFocusNode) {
    if (originFocusNode == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          originFocusNode.context?.mounted != true ||
          !originFocusNode.canRequestFocus) {
        return;
      }
      originFocusNode.requestFocus();
    });
  }

  void _scheduleSheetDismiss(BuildContext sheetContext) {
    if (_sheetDismissScheduled) return;
    _sheetDismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetDismissScheduled = false;
      if (!sheetContext.mounted) return;
      final route = ModalRoute.of(sheetContext);
      if (route?.isActive ?? false) {
        Navigator.of(sheetContext).removeRoute(route!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cabinet = _completeCabinet;
    final textTheme = Theme.of(context).textTheme;
    final developmentPresentation =
        widget.controller.usesDevelopmentPresentation;
    final terminalDecisions = widget.controller.terminalDecisions;
    final acceptedDecisions = terminalDecisions
        .whereType<DoctorUrgentCabinetAccepted>()
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    final otherTerminalDecisions = terminalDecisions
        .where(
          (decision) =>
              decision is DoctorUrgentCabinetDeclined ||
              decision is DoctorUrgentCabinetUnavailable,
        )
        .toList(growable: false);
    return SingleChildScrollView(
      key: const ValueKey('doctor-urgent-cabinet-scroll'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Urgences au cabinet',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                developmentPresentation
                    ? 'Préparez votre espace pour les futures demandes urgentes '
                          'dans votre cabinet.'
                    : 'Recevez et traitez les demandes urgentes ciblées pour '
                          'votre cabinet.',
                style: textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: OmniSpacing.lg),
              Wrap(
                spacing: OmniSpacing.sm,
                runSpacing: OmniSpacing.sm,
                children: [
                  const _ContextChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Service configuré',
                    foreground: OmniColors.deepTeal,
                    background: OmniColors.mintSoft,
                  ),
                  _ContextChip(
                    icon: developmentPresentation
                        ? Icons.science_outlined
                        : Icons.verified_user_outlined,
                    label: developmentPresentation
                        ? 'Développement synthétique'
                        : 'Demandes sécurisées',
                    foreground: OmniColors.slateBlue,
                    background: OmniColors.slateSoft,
                  ),
                ],
              ),
              const SizedBox(height: OmniSpacing.xl),
              if (cabinet == null)
                const _InformationCard(
                  key: ValueKey('doctor-urgent-cabinet-missing-config'),
                  icon: Icons.warning_amber_rounded,
                  iconColor: OmniColors.amber,
                  iconBackground: OmniColors.amberSoft,
                  title: 'Configuration du cabinet requise',
                  description:
                      'Ajoutez les informations complètes de votre cabinet '
                      'avant de préparer ce service.',
                )
              else
                _CabinetCard(cabinet: cabinet),
              const SizedBox(height: OmniSpacing.lg),
              _InformationCard(
                key: const ValueKey('doctor-urgent-cabinet-availability'),
                icon: Icons.power_settings_new_rounded,
                iconColor: OmniColors.amber,
                iconBackground: OmniColors.amberSoft,
                title: 'Disponibilité au cabinet',
                description: developmentPresentation
                    ? 'Flux synthétique — aucune notification temps réel.'
                    : 'Les demandes ciblées sont chargées depuis le service autorisé.',
              ),
              const SizedBox(height: OmniSpacing.lg),
              if (widget.controller.isDevelopmentSimulationAvailable) ...[
                _DevelopmentSimulationAction(
                  enabled: widget.controller.canSimulateDevelopmentRequest,
                  onPressed: widget.controller.simulateDevelopmentRequest,
                ),
                const SizedBox(height: OmniSpacing.lg),
              ],
              if (acceptedDecisions.isNotEmpty) ...[
                _AcceptedRequestSection(
                  decisions: acceptedDecisions,
                  expanded: _showAllAcceptedRequests,
                  onExpandedChanged: (expanded) {
                    setState(() => _showAllAcceptedRequests = expanded);
                  },
                  onOpen: _openAcceptedRequest,
                ),
                const SizedBox(height: OmniSpacing.lg),
              ],
              _buildRequestArea(),
              if (otherTerminalDecisions.isNotEmpty) ...[
                const SizedBox(height: OmniSpacing.lg),
                _DecisionAcknowledgements(decisions: otherTerminalDecisions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestArea() {
    final requests = widget.controller.visibleNewRequests;
    if (requests.isNotEmpty) {
      return _IncomingRequestSection(requests: requests, onOpen: _openRequest);
    }
    return switch (widget.controller.feedState) {
      DoctorUrgentCabinetFeedLoading() => const _RequestStateCard(
        key: ValueKey('doctor-urgent-cabinet-loading'),
        loading: true,
        icon: Icons.hourglass_top_rounded,
        iconColor: OmniColors.slateBlue,
        iconBackground: OmniColors.slateSoft,
        title: 'Chargement des demandes',
        description: 'Chargement des demandes ciblées…',
      ),
      DoctorUrgentCabinetFeedLoaded() => const _InformationCard(
        key: ValueKey('doctor-urgent-cabinet-empty'),
        icon: Icons.inbox_outlined,
        iconColor: OmniColors.slateBlue,
        iconBackground: OmniColors.slateSoft,
        title: 'Aucune demande urgente au cabinet',
        description: 'Aucune demande ciblée n’est actuellement en attente.',
      ),
      DoctorUrgentCabinetFeedEmpty() => const _InformationCard(
        key: ValueKey('doctor-urgent-cabinet-empty'),
        icon: Icons.inbox_outlined,
        iconColor: OmniColors.slateBlue,
        iconBackground: OmniColors.slateSoft,
        title: 'Aucune demande urgente au cabinet',
        description: 'Aucune demande ciblée n’est actuellement en attente.',
      ),
      DoctorUrgentCabinetFeedUnavailable(:final message) => _InformationCard(
        key: const ValueKey('doctor-urgent-cabinet-unavailable'),
        icon: Icons.cloud_off_outlined,
        iconColor: OmniColors.slateBlue,
        iconBackground: OmniColors.slateSoft,
        title: 'Demandes indisponibles',
        description: message,
      ),
      DoctorUrgentCabinetFeedError(:final message, :final canRetry) =>
        _RequestStateCard(
          key: const ValueKey('doctor-urgent-cabinet-error'),
          icon: Icons.error_outline_rounded,
          iconColor: OmniColors.error,
          iconBackground: OmniColors.errorSoft,
          title: 'Demandes indisponibles',
          description: message,
          onRetry: canRetry ? widget.controller.refresh : null,
        ),
    };
  }
}

class _AcceptedRequestSection extends StatelessWidget {
  const _AcceptedRequestSection({
    required this.decisions,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onOpen,
  });

  static const previewLimit = 3;

  final List<DoctorUrgentCabinetAccepted> decisions;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<DoctorUrgentCabinetAccepted> onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = expanded
        ? decisions
        : decisions.take(previewLimit).toList(growable: false);
    return Column(
      key: const ValueKey('doctor-urgent-cabinet-accepted-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Demandes acceptées',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Semantics(
              label:
                  '${decisions.length} ${decisions.length == 1 ? 'demande acceptée' : 'demandes acceptées'}',
              child: Container(
                key: const ValueKey('doctor-urgent-cabinet-accepted-count'),
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.sm,
                  vertical: OmniSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: OmniColors.mintSoft,
                  borderRadius: BorderRadius.circular(OmniRadii.pill),
                ),
                child: Text(
                  '${decisions.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OmniSpacing.md),
        for (var index = 0; index < visible.length; index++) ...[
          DoctorUrgentCabinetAcceptedCard(
            request: visible[index].request,
            onOpen: () => onOpen(visible[index]),
          ),
          if (index != visible.length - 1)
            const SizedBox(height: OmniSpacing.base),
        ],
        if (decisions.length > previewLimit) ...[
          const SizedBox(height: OmniSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey(
                expanded
                    ? 'doctor-urgent-cabinet-accepted-collapse'
                    : 'doctor-urgent-cabinet-accepted-expand',
              ),
              onPressed: () => onExpandedChanged(!expanded),
              icon: Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                expanded
                    ? 'Réduire la liste'
                    : 'Voir toutes les demandes acceptées',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DevelopmentSimulationAction extends StatelessWidget {
  const _DevelopmentSimulationAction({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('doctor-urgent-cabinet-simulator'),
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Wrap(
      spacing: OmniSpacing.md,
      runSpacing: OmniSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Outil de développement',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: OmniColors.slateBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: OmniSpacing.xs),
              Text(
                'Demande simulée — aucun patient réel.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('doctor-urgent-cabinet-simulate'),
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.science_outlined, size: 18),
          label: const Text('Simuler une demande'),
        ),
      ],
    ),
  );
}

class _DecisionAcknowledgements extends StatelessWidget {
  const _DecisionAcknowledgements({required this.decisions});

  final List<DoctorUrgentCabinetDecisionState> decisions;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('doctor-urgent-cabinet-decision-acknowledgements'),
    children: [
      for (var index = 0; index < decisions.length; index++) ...[
        _DecisionAcknowledgement(decision: decisions[index]),
        if (index != decisions.length - 1)
          const SizedBox(height: OmniSpacing.sm),
      ],
    ],
  );
}

class _DecisionAcknowledgement extends StatelessWidget {
  const _DecisionAcknowledgement({required this.decision});

  final DoctorUrgentCabinetDecisionState decision;

  @override
  Widget build(BuildContext context) {
    final (message, icon, foreground, background) = switch (decision) {
      DoctorUrgentCabinetAccepted() => (
        'Demande acceptée — simulation',
        Icons.check_circle_outline_rounded,
        OmniColors.deepTeal,
        OmniColors.mintSoft,
      ),
      DoctorUrgentCabinetDeclined() => (
        'Demande refusée — simulation',
        Icons.event_busy_outlined,
        OmniColors.urgentCoral,
        OmniColors.urgentCoralSoft,
      ),
      DoctorUrgentCabinetUnavailable() => (
        "Cette demande n'est plus disponible",
        Icons.info_outline_rounded,
        OmniColors.slateBlue,
        OmniColors.slateSoft,
      ),
      _ => throw StateError('A terminal decision is required.'),
    };
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        key: ValueKey(
          'doctor-urgent-cabinet-decision-${decision.request.stableIdentity}',
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          border: Border.all(color: foreground.withValues(alpha: .22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequestSection extends StatelessWidget {
  const _IncomingRequestSection({required this.requests, required this.onOpen});

  final List<DoctorUrgentCabinetRequest> requests;
  final ValueChanged<DoctorUrgentCabinetRequest> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('doctor-urgent-cabinet-request-section'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Nouvelles demandes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Semantics(
            label:
                '${requests.length} ${requests.length == 1 ? 'nouvelle demande' : 'nouvelles demandes'}',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.sm,
                vertical: OmniSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: OmniColors.urgentCoralSoft,
                borderRadius: BorderRadius.circular(OmniRadii.pill),
              ),
              child: Text(
                '${requests.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.urgentCoral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: OmniSpacing.md),
      for (var index = 0; index < requests.length; index++) ...[
        DoctorUrgentCabinetRequestCard(
          key: ValueKey(
            'doctor-urgent-cabinet-card-${requests[index].stableIdentity}',
          ),
          request: requests[index],
          onOpen: () => onOpen(requests[index]),
        ),
        if (index != requests.length - 1)
          const SizedBox(height: OmniSpacing.base),
      ],
    ],
  );
}

class _RequestStateCard extends StatelessWidget {
  const _RequestStateCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    this.loading = false,
    this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title. $description',
    liveRegion: true,
    container: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OmniColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  TextButton.icon(
                    key: const ValueKey('doctor-urgent-cabinet-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: OmniSpacing.xs),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CabinetCard extends StatelessWidget {
  const _CabinetCard({required this.cabinet});

  final DoctorCabinetConfig cabinet;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cabinet configuré localement : ${cabinet.name}',
    container: true,
    child: Container(
      key: const ValueKey('doctor-urgent-cabinet-details'),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconSurface(
                icon: Icons.medical_services_outlined,
                color: OmniColors.clinicalCyan,
                background: OmniColors.clinicalCyanSoft,
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cabinet.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Text(
                      '${cabinet.city}, ${cabinet.governorate}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          Text(cabinet.address),
          const SizedBox(height: OmniSpacing.md),
          Text(
            'Configuration locale non vérifiée',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ),
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title. $description',
    container: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconSurface(
            icon: icon,
            color: iconColor,
            background: iconBackground,
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OmniColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _IconSurface extends StatelessWidget {
  const _IconSurface({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 21),
  );
}
