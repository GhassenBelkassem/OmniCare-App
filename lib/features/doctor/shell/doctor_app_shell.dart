import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../auth/application/auth_role_family.dart';
import '../../notifications/application/notification_center_controller.dart';
import '../../notifications/notifications_screen.dart';
import '../../notifications/presentation/notification_badge.dart';
import '../../../services/notification_service.dart';
import '../profile/doctor_display_profile.dart';
import '../scheduled_care/application/doctor_booking_request_controller.dart';
import '../scheduled_care/application/doctor_appointment_controller.dart';
import '../scheduled_care/application/doctor_home_controller.dart';
import '../scheduled_care/application/doctor_proposal_controller.dart';
import '../scheduled_care/presentation/doctor_appointment_detail_sheet.dart';
import '../scheduled_care/presentation/doctor_booking_request_screen.dart';
import '../agenda/doctor_agenda_controller.dart';
import '../agenda/doctor_agenda_screen.dart';
import '../active_consultation/doctor_active_consultation.dart';
import '../active_consultation/doctor_active_consultation_controller.dart';
import '../home/doctor_home_screen.dart';
import '../medical_record/doctor_medical_record_controller.dart';
import '../medical_record/doctor_medical_record_workspace_screen.dart';
import '../urgent/doctor_urgent_controller.dart';
import '../urgent/doctor_home_offer_inbox_controller.dart';
import '../urgent/doctor_home_commitment_controller.dart';
import '../urgent/doctor_home_dispatch_context_controller.dart';
import '../urgent/doctor_home_presence_controller.dart';
import '../urgent/doctor_urgent_qr_scanner_screen.dart';
import '../urgent/doctor_urgent_runtime_controller.dart';
import '../urgent/doctor_urgent_workspace_screen.dart';
import '../urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import '../urgent_cabinet/doctor_urgent_cabinet_decision_source.dart';
import '../urgent_cabinet/doctor_urgent_cabinet_request_source.dart';
import '../workspace/doctor_workspace_config.dart';
import 'doctor_navigation_destination.dart';
import 'doctor_placeholder_tab.dart';

/// Shared, feature-neutral frame for the Doctor mobile experience.
///
/// The header and navigation are intentionally outside each tab's scroll
/// surface. Each destination owns exactly one vertical scroll view.
class DoctorAppShell extends StatefulWidget {
  const DoctorAppShell({
    super.key,
    required this.profile,
    required this.onLogout,
    this.workspaceConfig,
    this.onResetDemo,
    this.urgentController,
    this.homeController,
    this.bookingRequestController,
    this.proposalController,
    this.agendaController,
    this.appointmentController,
    this.urgentCabinetController,
    this.urgentCabinetRequestSource,
    this.urgentCabinetDecisionSource,
    this.authoritativeCapabilities,
    this.urgentHomeOperationalMessage,
    this.urgentCabinetOperationalMessage,
    this.urgentRuntimeController,
    this.homePresenceController,
    this.homeOfferController,
    this.homeCommitmentController,
    this.homeDispatchContextController,
    this.activeConsultationController,
    this.medicalRecordController,
  });

  static const profileTabKey = ValueKey('doctor-tab-profile');

  final DoctorDisplayProfile profile;
  final Future<void> Function() onLogout;
  final DoctorWorkspaceConfig? workspaceConfig;
  final Future<void> Function()? onResetDemo;
  final DoctorUrgentController? urgentController;
  final DoctorHomeController? homeController;
  final DoctorBookingRequestController? bookingRequestController;
  final DoctorProposalController? proposalController;
  final DoctorAgendaController? agendaController;
  final DoctorAppointmentController? appointmentController;
  final DoctorUrgentCabinetController? urgentCabinetController;
  final DoctorUrgentCabinetRequestSource? urgentCabinetRequestSource;
  final DoctorUrgentCabinetDecisionSource? urgentCabinetDecisionSource;
  final Set<DoctorCapability>? authoritativeCapabilities;
  final String? urgentHomeOperationalMessage;
  final String? urgentCabinetOperationalMessage;
  final DoctorUrgentRuntimeController? urgentRuntimeController;
  final DoctorHomePresenceController? homePresenceController;
  final DoctorHomeOfferInboxController? homeOfferController;
  final DoctorHomeCommitmentController? homeCommitmentController;
  final DoctorHomeDispatchContextController? homeDispatchContextController;
  final DoctorActiveConsultationController? activeConsultationController;
  final DoctorMedicalRecordController? medicalRecordController;

  @override
  State<DoctorAppShell> createState() => _DoctorAppShellState();
}

class _DoctorAppShellState extends State<DoctorAppShell> {
  DoctorNavigationDestinationId _selectedDestination =
      DoctorNavigationDestinationId.home;
  bool _isLoggingOut = false;
  _DoctorUrgentWorkflow _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
  late DoctorUrgentMode _selectedUrgentMode;
  late final DoctorAgendaController _agendaController =
      widget.agendaController ?? DoctorAgendaController.preview();
  late DoctorUrgentController _urgentController;
  late bool _ownsUrgentController;
  late DoctorUrgentCabinetController _urgentCabinetController;
  late bool _ownsUrgentCabinetController;
  StreamSubscription<UrgentCabinetNotificationOpenIntent>?
  _urgentCabinetOpenSubscription;

  @override
  void initState() {
    super.initState();
    _ownsUrgentController = widget.urgentController == null;
    _urgentController = widget.urgentController ?? DoctorUrgentController();
    _ownsUrgentCabinetController = widget.urgentCabinetController == null;
    _urgentCabinetController =
        widget.urgentCabinetController ??
        DoctorUrgentCabinetController(
          developmentSimulationEnabled:
              widget.authoritativeCapabilities == null,
        );
    _configureOwnedUrgentCabinetController();
    _urgentCabinetController.addListener(_onCabinetResponsibilityChanged);
    _selectedUrgentMode = _preferredUrgentMode();
    widget.homeCommitmentController?.addListener(_onCommitmentChanged);
    widget.activeConsultationController?.addListener(
      _onActiveConsultationChanged,
    );
    widget.medicalRecordController?.synchronize(
      widget.activeConsultationController?.active,
    );
    widget.homeController?.setRealtimeActive(true);
    _urgentCabinetOpenSubscription = NotificationService().urgentCabinetOpens
        .listen(
          (intent) => unawaited(_selectUrgentCabinetRequest(intent.requestId)),
        );
  }

  @override
  void dispose() {
    widget.homeController?.setRealtimeActive(false);
    widget.homeCommitmentController?.removeListener(_onCommitmentChanged);
    widget.activeConsultationController?.removeListener(
      _onActiveConsultationChanged,
    );
    _urgentCabinetController.removeListener(_onCabinetResponsibilityChanged);
    _urgentCabinetOpenSubscription?.cancel();
    if (widget.agendaController == null) _agendaController.dispose();
    if (_ownsUrgentController) _urgentController.dispose();
    if (_ownsUrgentCabinetController) _urgentCabinetController.dispose();
    super.dispose();
  }

  void _configureOwnedUrgentCabinetController() {
    if (!_ownsUrgentCabinetController) return;
    _urgentCabinetController.configure(
      authenticatedDoctorId: widget.workspaceConfig?.doctorId ?? '',
      workspaceConfig: widget.workspaceConfig,
      requestSource: widget.urgentCabinetRequestSource,
      decisionSource: widget.urgentCabinetDecisionSource,
    );
  }

  void _onCommitmentChanged() {
    if (!mounted) return;
    setState(() {
      if (!_destinations.any(
        (destination) => destination.id == _selectedDestination,
      )) {
        _selectedDestination = DoctorNavigationDestinationId.home;
      }
      if (_selectedUrgentMode == DoctorUrgentMode.home && !_showsUrgentHome) {
        _selectedUrgentMode = _preferredUrgentMode();
      }
    });
  }

  void _onCabinetResponsibilityChanged() {
    if (!mounted) return;
    setState(() {
      if (!_destinations.any(
        (destination) => destination.id == _selectedDestination,
      )) {
        _selectedDestination = DoctorNavigationDestinationId.home;
      }
      if (_selectedUrgentMode == DoctorUrgentMode.cabinet &&
          !_showsUrgentCabinet) {
        _selectedUrgentMode = _preferredUrgentMode();
      }
    });
  }

  void _onActiveConsultationChanged() {
    widget.medicalRecordController?.synchronize(
      widget.activeConsultationController?.active,
    );
    if (mounted) setState(() {});
  }

  Set<DoctorCapability> get _capabilities =>
      widget.authoritativeCapabilities ??
      (widget.workspaceConfig == null
          ? const <DoctorCapability>{}
          : deriveDoctorCapabilities(widget.workspaceConfig!));

  Set<DoctorCapability> get _navigationCapabilities {
    final homeResponsibility =
        widget.homeCommitmentController?.hasVisibleResponsibility == true;
    final cabinetResponsibility =
        _urgentCabinetController.hasVisibleResponsibility;
    if (!homeResponsibility && !cabinetResponsibility) {
      return _capabilities;
    }
    return {
      ..._capabilities,
      DoctorCapability.urgentRequests,
      if (homeResponsibility) DoctorCapability.urgentHomeRequests,
      if (cabinetResponsibility) DoctorCapability.urgentCabinetRequests,
      DoctorCapability.urgentWorkspace,
    };
  }

  List<DoctorNavigationDestination> get _destinations =>
      deriveDoctorNavigationDestinations(_navigationCapabilities);

  bool get _hasUrgentHome =>
      _capabilities.contains(DoctorCapability.urgentHomeRequests);

  bool get _showsUrgentHome =>
      _hasUrgentHome ||
      widget.homeCommitmentController?.hasVisibleResponsibility == true;

  bool get _hasUrgentCabinet =>
      _capabilities.contains(DoctorCapability.urgentCabinetRequests);

  bool get _showsUrgentCabinet =>
      _hasUrgentCabinet || _urgentCabinetController.hasVisibleResponsibility;

  DoctorUrgentMode _preferredUrgentMode() =>
      _showsUrgentHome ? DoctorUrgentMode.home : DoctorUrgentMode.cabinet;

  @override
  void didUpdateWidget(covariant DoctorAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.homeCommitmentController,
      widget.homeCommitmentController,
    )) {
      oldWidget.homeCommitmentController?.removeListener(_onCommitmentChanged);
      widget.homeCommitmentController?.addListener(_onCommitmentChanged);
    }
    if (!identical(
      oldWidget.activeConsultationController,
      widget.activeConsultationController,
    )) {
      oldWidget.activeConsultationController?.removeListener(
        _onActiveConsultationChanged,
      );
      widget.activeConsultationController?.addListener(
        _onActiveConsultationChanged,
      );
      widget.medicalRecordController?.synchronize(
        widget.activeConsultationController?.active,
      );
    }
    if (!identical(
      oldWidget.medicalRecordController,
      widget.medicalRecordController,
    )) {
      widget.medicalRecordController?.synchronize(
        widget.activeConsultationController?.active,
      );
    }
    final doctorChanged =
        oldWidget.workspaceConfig?.doctorId != widget.workspaceConfig?.doctorId;
    if (!identical(oldWidget.urgentController, widget.urgentController)) {
      if (_ownsUrgentController) _urgentController.dispose();
      _ownsUrgentController = widget.urgentController == null;
      _urgentController = widget.urgentController ?? DoctorUrgentController();
    } else if (doctorChanged && _ownsUrgentController) {
      _urgentController.dispose();
      _urgentController = DoctorUrgentController();
    }
    if (!identical(
      oldWidget.urgentCabinetController,
      widget.urgentCabinetController,
    )) {
      _urgentCabinetController.removeListener(_onCabinetResponsibilityChanged);
      if (_ownsUrgentCabinetController) _urgentCabinetController.dispose();
      _ownsUrgentCabinetController = widget.urgentCabinetController == null;
      _urgentCabinetController =
          widget.urgentCabinetController ??
          DoctorUrgentCabinetController(
            developmentSimulationEnabled:
                widget.authoritativeCapabilities == null,
          );
      _configureOwnedUrgentCabinetController();
      _urgentCabinetController.addListener(_onCabinetResponsibilityChanged);
    } else if (_ownsUrgentCabinetController &&
        (doctorChanged ||
            !identical(
              oldWidget.urgentCabinetRequestSource,
              widget.urgentCabinetRequestSource,
            ) ||
            !identical(
              oldWidget.urgentCabinetDecisionSource,
              widget.urgentCabinetDecisionSource,
            ) ||
            oldWidget.workspaceConfig != widget.workspaceConfig)) {
      _configureOwnedUrgentCabinetController();
    }
    if (!identical(oldWidget.homeController, widget.homeController)) {
      oldWidget.homeController?.setRealtimeActive(false);
      widget.homeController?.setRealtimeActive(
        _selectedDestination == DoctorNavigationDestinationId.home,
      );
    }
    if (!_destinations.any(
      (destination) => destination.id == _selectedDestination,
    )) {
      _selectedDestination = DoctorNavigationDestinationId.home;
    }
    if (doctorChanged) {
      _selectedUrgentMode = _preferredUrgentMode();
      _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
    } else {
      final selectedModeAvailable = switch (_selectedUrgentMode) {
        DoctorUrgentMode.home => _showsUrgentHome,
        DoctorUrgentMode.cabinet => _showsUrgentCabinet,
      };
      if (!selectedModeAvailable) {
        _selectedUrgentMode = _preferredUrgentMode();
      }
      if (!_hasUrgentHome) {
        _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _selectDestination(DoctorNavigationDestinationId destination) {
    if (!_destinations.any((item) => item.id == destination) ||
        _selectedDestination == destination) {
      return;
    }
    widget.homeController?.setRealtimeActive(
      destination == DoctorNavigationDestinationId.home,
    );
    setState(() {
      _selectedDestination = destination;
      if (destination != DoctorNavigationDestinationId.urgent) {
        _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
      }
    });
  }

  void _showUrgentWorkflow(_DoctorUrgentWorkflow workflow) {
    if (!_hasUrgentHome || widget.urgentHomeOperationalMessage != null) return;
    setState(() {
      _selectedDestination = DoctorNavigationDestinationId.urgent;
      _selectedUrgentMode = DoctorUrgentMode.home;
      _urgentWorkflow = workflow;
    });
  }

  void _openHomeUrgencies() {
    if (!_showsUrgentHome) return;
    setState(() {
      _selectedDestination = DoctorNavigationDestinationId.urgent;
      _selectedUrgentMode = DoctorUrgentMode.home;
      _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
    });
  }

  void _selectUrgentMode(DoctorUrgentMode mode) {
    final isAvailable = switch (mode) {
      DoctorUrgentMode.home => _showsUrgentHome,
      DoctorUrgentMode.cabinet => _showsUrgentCabinet,
    };
    if (!isAvailable || _selectedUrgentMode == mode) return;
    setState(() {
      _selectedUrgentMode = mode;
      _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final selectedDestination = destinations.firstWhere(
      (destination) => destination.id == _selectedDestination,
      orElse: () => destinations.first,
    );
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DoctorTopBar(
              profile: widget.profile,
              onNotifications: _openNotifications,
              activeConsultation: widget.activeConsultationController?.active,
              onActiveConsultation: _openActiveConsultation,
            ),
            Expanded(child: _selectedContent(selectedDestination.id)),
          ],
        ),
      ),
      bottomNavigationBar: _DoctorBottomNavigation(
        destinations: destinations,
        selectedDestination: selectedDestination.id,
        onSelected: (destination) => _selectDestination(destination.id),
      ),
    );
  }

  Widget _selectedContent(DoctorNavigationDestinationId destination) {
    return switch (destination) {
      DoctorNavigationDestinationId.home => DoctorHomeScreen(
        profile: widget.profile,
        capabilities: _capabilities,
        workspaceConfig: widget.workspaceConfig,
        urgentController: widget.authoritativeCapabilities == null
            ? _urgentController
            : null,
        homeController: widget.homeController,
        onOpenBookingRequest: _openBookingRequest,
        onOpenAgenda: () =>
            _selectDestination(DoctorNavigationDestinationId.agenda),
        onOpenUrgencies: _openHomeUrgencies,
      ),
      DoctorNavigationDestinationId.agenda => DoctorAgendaScreen(
        controller: _agendaController,
        onOpenBookingRequest: _openBookingRequest,
        onOpenAppointment: _openAppointment,
      ),
      DoctorNavigationDestinationId.urgent => _UrgentWorkflowContent(
        workflow: _urgentWorkflow,
        capabilities: _navigationCapabilities,
        workspaceConfig: widget.workspaceConfig,
        homeOperationalMessage: widget.urgentHomeOperationalMessage,
        cabinetOperationalMessage:
            _urgentCabinetController.hasVisibleResponsibility
            ? null
            : widget.urgentCabinetOperationalMessage,
        runtimeController: widget.urgentRuntimeController,
        homePresenceController: widget.homePresenceController,
        homeOfferController: widget.homeOfferController,
        homeCommitmentController: widget.homeCommitmentController,
        homeDispatchContextController: widget.homeDispatchContextController,
        selectedMode: _selectedUrgentMode,
        onModeChanged: _selectUrgentMode,
        urgentController: _urgentController,
        onOpenQr: () => _showUrgentWorkflow(_DoctorUrgentWorkflow.qr),
        onBackToUrgent: () => _showUrgentWorkflow(_DoctorUrgentWorkflow.urgent),
        onOpenMedicalRecord: () =>
            _showUrgentWorkflow(_DoctorUrgentWorkflow.medicalRecord),
        onBackToQr: () => _showUrgentWorkflow(_DoctorUrgentWorkflow.qr),
        urgentCabinetController: _urgentCabinetController,
        medicalRecordController: widget.medicalRecordController,
      ),
      DoctorNavigationDestinationId.patients => const DoctorPlaceholderTab(
        title: 'Patients',
        icon: Icons.people_alt_outlined,
      ),
      DoctorNavigationDestinationId.profile => DoctorPlaceholderTab(
        title: 'Profil',
        icon: Icons.account_circle_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LogoutButton(isLoggingOut: _isLoggingOut, onPressed: _logout),
            if (widget.onResetDemo != null) ...[
              const SizedBox(height: OmniSpacing.md),
              TextButton.icon(
                key: const ValueKey('doctor-reset-demo-button'),
                onPressed: widget.onResetDemo,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Réinitialiser la démo'),
              ),
            ],
          ],
        ),
      ),
    };
  }

  void _openBookingRequest(String requestId) {
    final controller = widget.bookingRequestController;
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorBookingRequestScreen(
          requestId: requestId,
          controller: controller,
          proposalController: widget.proposalController,
        ),
      ),
    );
  }

  void _openAppointment(String appointmentId) {
    final controller = widget.appointmentController;
    if (controller == null) return;
    showDoctorAppointmentDetail(
      context,
      appointmentId: appointmentId,
      controller: controller,
    );
  }

  Future<void> _openUrgentCabinetRequest(String requestId) async {
    if (!_showsUrgentCabinet) {
      _showUrgentCabinetUnavailableMessage();
      return;
    }
    final opened = await _urgentCabinetController.openFromNotification(
      requestId,
    );
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Cette demande CABINET n’est pas disponible pour ce compte.',
            ),
          ),
        );
      return;
    }
    Navigator.of(context).pop();
    _showUrgentCabinetDestination();
  }

  Future<void> _selectUrgentCabinetRequest(String requestId) async {
    if (!mounted) return;
    if (!_showsUrgentCabinet) {
      _showUrgentCabinetUnavailableMessage();
      return;
    }
    final opened = await _urgentCabinetController.openFromNotification(
      requestId,
    );
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Cette demande CABINET n’est plus disponible.'),
          ),
        );
      return;
    }
    _showUrgentCabinetDestination();
  }

  void _showUrgentCabinetDestination() {
    if (!mounted) return;
    setState(() {
      _selectedDestination = DoctorNavigationDestinationId.urgent;
      _selectedUrgentMode = DoctorUrgentMode.cabinet;
      _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
    });
  }

  void _showUrgentCabinetUnavailableMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Le service CABINET n’est pas disponible.'),
        ),
      );
  }

  void _openNotifications() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          role: AuthRoleFamily.doctor,
          onOpenDoctorRequest: _openBookingRequest,
          onOpenDoctorAppointment: _openAppointment,
          onOpenDoctorUrgentCabinetRequest: _openUrgentCabinetRequest,
        ),
      ),
    );
  }

  void _openActiveConsultation() {
    final active = widget.activeConsultationController?.active;
    if (active == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultation active'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Épisode ${active.consultationId}'),
            const SizedBox(height: OmniSpacing.sm),
            Text('Statut : ${_consultationStatusLabel(active.status)}'),
            Text(
              'Accès médical : '
              '${_medicalAccessStatusLabel(active.medicalAccessStatus)}',
            ),
          ],
        ),
        actions: [
          if (widget.medicalRecordController != null)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => DoctorMedicalRecordWorkspaceScreen(
                      controller: widget.medicalRecordController!,
                    ),
                  ),
                );
              },
              child: const Text('Ouvrir le dossier'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

enum _DoctorUrgentWorkflow { urgent, qr, medicalRecord }

String _consultationStatusLabel(DoctorConsultationStatus status) =>
    switch (status) {
      DoctorConsultationStatus.inProgress => 'En cours',
      DoctorConsultationStatus.finalizing => 'Finalisation',
      DoctorConsultationStatus.completed => 'Terminée',
      DoctorConsultationStatus.aborted => 'Interrompue',
    };

String _medicalAccessStatusLabel(
  DoctorConsultationMedicalAccessStatus status,
) => switch (status) {
  DoctorConsultationMedicalAccessStatus.none => 'Non activé',
  DoctorConsultationMedicalAccessStatus.active => 'Actif',
  DoctorConsultationMedicalAccessStatus.expired => 'Expiré',
  DoctorConsultationMedicalAccessStatus.revoked => 'Révoqué',
  DoctorConsultationMedicalAccessStatus.unavailable => 'Indisponible',
};

/// Keeps the D5/D6 urgent journey in the shell's content region. IndexedStack
/// preserves both the shell-owned controller and the verified QR state while a
/// doctor views the record and returns.
class _UrgentWorkflowContent extends StatelessWidget {
  const _UrgentWorkflowContent({
    required this.workflow,
    required this.capabilities,
    required this.workspaceConfig,
    required this.homeOperationalMessage,
    required this.cabinetOperationalMessage,
    required this.runtimeController,
    required this.homePresenceController,
    required this.homeOfferController,
    required this.homeCommitmentController,
    required this.homeDispatchContextController,
    required this.selectedMode,
    required this.onModeChanged,
    required this.urgentController,
    required this.onOpenQr,
    required this.onBackToUrgent,
    required this.onOpenMedicalRecord,
    required this.onBackToQr,
    required this.urgentCabinetController,
    required this.medicalRecordController,
  });

  final _DoctorUrgentWorkflow workflow;
  final Set<DoctorCapability> capabilities;
  final DoctorWorkspaceConfig? workspaceConfig;
  final String? homeOperationalMessage;
  final String? cabinetOperationalMessage;
  final DoctorUrgentRuntimeController? runtimeController;
  final DoctorHomePresenceController? homePresenceController;
  final DoctorHomeOfferInboxController? homeOfferController;
  final DoctorHomeCommitmentController? homeCommitmentController;
  final DoctorHomeDispatchContextController? homeDispatchContextController;
  final DoctorUrgentMode selectedMode;
  final ValueChanged<DoctorUrgentMode> onModeChanged;
  final DoctorUrgentController urgentController;
  final VoidCallback onOpenQr;
  final VoidCallback onBackToUrgent;
  final VoidCallback onOpenMedicalRecord;
  final VoidCallback onBackToQr;
  final DoctorUrgentCabinetController urgentCabinetController;
  final DoctorMedicalRecordController? medicalRecordController;

  @override
  Widget build(BuildContext context) {
    final workspace = DoctorUrgentWorkspaceScreen(
      capabilities: capabilities,
      workspaceConfig: workspaceConfig,
      homeOperationalMessage: homeOperationalMessage,
      cabinetOperationalMessage: cabinetOperationalMessage,
      runtimeController: runtimeController,
      homePresenceController: homePresenceController,
      homeOfferController: homeOfferController,
      homeCommitmentController: homeCommitmentController,
      homeDispatchContextController: homeDispatchContextController,
      selectedMode: selectedMode,
      onModeChanged: onModeChanged,
      homeController: urgentController,
      onOpenHomeQr: onOpenQr,
      urgentCabinetController: urgentCabinetController,
    );
    if (!capabilities.contains(DoctorCapability.urgentHomeRequests)) {
      return workspace;
    }
    return IndexedStack(
      index: workflow.index,
      children: [
        workspace,
        DoctorUrgentQrScannerScreen(
          request: urgentController.request,
          embedded: true,
          onBack: onBackToUrgent,
          onOpenMedicalRecord: onOpenMedicalRecord,
        ),
        if (medicalRecordController != null)
          DoctorMedicalRecordWorkspaceScreen(
            controller: medicalRecordController!,
            embedded: true,
            onBack: onBackToQr,
          )
        else
          const Center(child: Text('Dossier médical indisponible.')),
      ],
    );
  }
}

class _DoctorTopBar extends StatelessWidget {
  const _DoctorTopBar({
    required this.profile,
    required this.onNotifications,
    required this.activeConsultation,
    required this.onActiveConsultation,
  });

  final DoctorDisplayProfile profile;
  final VoidCallback onNotifications;
  final DoctorActiveConsultation? activeConsultation;
  final VoidCallback onActiveConsultation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unreadCount =
        context.watch<NotificationCenterController?>()?.unreadCount ?? 0;
    return Container(
      key: const ValueKey('doctor-top-bar'),
      height: 72,
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.base),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OmniCare',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: OmniColors.deepTeal,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Espace médecin',
                        style: textTheme.labelMedium?.copyWith(
                          color: OmniColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                NotificationBadge(count: unreadCount, onTap: onNotifications),
                if (activeConsultation != null) ...[
                  const SizedBox(width: OmniSpacing.xs),
                  IconButton(
                    key: const ValueKey('doctor-active-consultation-button'),
                    tooltip: 'Consultation active',
                    onPressed: onActiveConsultation,
                    icon: const Icon(Icons.medical_services_outlined),
                  ),
                ],
                const SizedBox(width: OmniSpacing.sm),
                Semantics(
                  label: 'Profil de ${profile.fullName}',
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: OmniColors.mintSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      profile.initials,
                      style: textTheme.labelLarge?.copyWith(
                        color: OmniColors.deepTeal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorBottomNavigation extends StatelessWidget {
  const _DoctorBottomNavigation({
    required this.destinations,
    required this.selectedDestination,
    required this.onSelected,
  });

  final List<DoctorNavigationDestination> destinations;
  final DoctorNavigationDestinationId selectedDestination;
  final ValueChanged<DoctorNavigationDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('doctor-bottom-navigation'),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(top: BorderSide(color: OmniColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.sm),
                child: Row(
                  children: List.generate(
                    destinations.length,
                    (index) => Expanded(
                      child: _DoctorNavigationButton(
                        key:
                            destinations[index].id ==
                                DoctorNavigationDestinationId.profile
                            ? DoctorAppShell.profileTabKey
                            : ValueKey(
                                'doctor-tab-${destinations[index].id.name}',
                              ),
                        destination: destinations[index],
                        isSelected:
                            selectedDestination == destinations[index].id,
                        onTap: () => onSelected(destinations[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorNavigationButton extends StatelessWidget {
  const _DoctorNavigationButton({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final DoctorNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = isSelected
        ? OmniColors.primaryAction
        : OmniColors.textTertiary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
            decoration: BoxDecoration(
              color: isSelected ? OmniColors.mintSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 23,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isLoggingOut, required this.onPressed});

  final bool isLoggingOut;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('doctor-logout-button'),
        onPressed: isLoggingOut ? null : onPressed,
        icon: isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded, size: 19),
        label: const Text('Se déconnecter'),
      ),
    );
  }
}
