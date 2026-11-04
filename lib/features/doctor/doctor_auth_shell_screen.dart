import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/application/auth_controller.dart';
import '../auth/application/auth_role_family.dart';
import '../../core/network/app_http_client.dart';
import '../patient_doctor/data/doctor_directory_api.dart';
import '../patient_doctor/data/doctor_directory_repository.dart';
import '../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'profile/doctor_display_profile.dart';
import 'scheduled_care/application/doctor_booking_request_controller.dart';
import 'scheduled_care/application/doctor_appointment_controller.dart';
import 'scheduled_care/application/doctor_home_controller.dart';
import 'scheduled_care/application/doctor_proposal_controller.dart';
import 'scheduled_care/data/doctor_proposal_availability_repository.dart';
import 'scheduled_care/data/doctor_scheduled_care_api.dart';
import 'scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'agenda/doctor_agenda_controller.dart';
import 'active_consultation/doctor_active_consultation_api.dart';
import 'active_consultation/doctor_active_consultation_controller.dart';
import 'medical_record/doctor_medical_record_api.dart';
import 'medical_record/doctor_medical_record_controller.dart';
import 'shell/doctor_app_shell.dart';
import 'urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'urgent_cabinet/doctor_urgent_cabinet_repository.dart';
import 'urgent/doctor_home_offer_inbox_controller.dart';
import 'urgent/doctor_home_offer_repository.dart';
import 'urgent/doctor_home_commitment_controller.dart';
import 'urgent/doctor_home_commitment_repository.dart';
import 'urgent/doctor_home_dispatch_context_controller.dart';
import 'urgent/doctor_home_dispatch_context_repository.dart';
import 'urgent/doctor_home_location_provider.dart';
import 'urgent/doctor_home_presence_controller.dart';
import 'urgent/doctor_home_presence_repository.dart';
import 'urgent/doctor_urgent_runtime_controller.dart';
import 'urgent/doctor_urgent_runtime_repository.dart';
import 'workspace/doctor_workspace_bootstrap.dart';
import 'workspace/doctor_workspace_bootstrap_api.dart';
import 'workspace/doctor_workspace_bootstrap_controller.dart';
import 'workspace/doctor_workspace_bootstrap_repository.dart';

/// Role guard and server-authoritative workspace entry point for Doctor mobile.
class DoctorAuthShellScreen extends StatefulWidget {
  const DoctorAuthShellScreen({
    super.key,
    this.bootstrapRepository,
    this.runtimeRepository,
    this.presenceRepository,
    this.locationProvider,
    this.homeOfferRepository,
    this.homeCommitmentRepository,
    this.homeDispatchContextRepository,
    this.urgentCabinetRepository,
  });

  final DoctorWorkspaceBootstrapRepositoryContract? bootstrapRepository;
  final DoctorUrgentRuntimeRepositoryContract? runtimeRepository;
  final DoctorHomePresenceRepositoryContract? presenceRepository;
  final DoctorHomeLocationProvider? locationProvider;
  final DoctorHomeOfferRepositoryContract? homeOfferRepository;
  final DoctorHomeCommitmentRepositoryContract? homeCommitmentRepository;
  final DoctorHomeDispatchContextRepositoryContract?
  homeDispatchContextRepository;
  final DoctorUrgentCabinetRepositoryContract? urgentCabinetRepository;

  @override
  State<DoctorAuthShellScreen> createState() => _DoctorAuthShellScreenState();
}

class _DoctorAuthShellScreenState extends State<DoctorAuthShellScreen>
    with WidgetsBindingObserver {
  DoctorWorkspaceBootstrapController? _workspaceController;
  DoctorUrgentRuntimeController? _runtimeController;
  DoctorHomePresenceController? _presenceController;
  DoctorHomeOfferInboxController? _homeOfferController;
  DoctorHomeCommitmentController? _homeCommitmentController;
  DoctorHomeDispatchContextController? _homeDispatchContextController;
  String? _requestedDoctorId;
  String? _scheduledCareDoctorId;
  DoctorHomeController? _homeController;
  DoctorBookingRequestController? _bookingRequestController;
  DoctorProposalController? _proposalController;
  DoctorAgendaController? _agendaController;
  DoctorAppointmentController? _appointmentController;
  DoctorScheduledCareRealtimeTarget? _realtimeTarget;
  VoidCallback? _unregisterRealtimeTarget;
  DoctorUrgentCabinetRepositoryContract? _urgentCabinetRepository;
  DoctorUrgentCabinetController? _urgentCabinetController;
  DoctorActiveConsultationController? _activeConsultationController;
  DoctorActiveConsultationRealtimeTarget? _activeConsultationRealtimeTarget;
  VoidCallback? _unregisterActiveConsultationTarget;
  DoctorMedicalRecordController? _medicalRecordController;
  DoctorMedicalRecordRealtimeTarget? _medicalRecordRealtimeTarget;
  VoidCallback? _unregisterMedicalRecordTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workspaceController != null &&
        _runtimeController != null &&
        _presenceController != null &&
        _homeOfferController != null &&
        _homeCommitmentController != null &&
        _homeDispatchContextController != null) {
      return;
    }
    final api = DoctorWorkspaceBootstrapApi(context.read<AppHttpClient>());
    _activeConsultationController ??= DoctorActiveConsultationController(
      api: DoctorActiveConsultationApi(context.read<AppHttpClient>()),
    );
    _medicalRecordController ??= DoctorMedicalRecordController(
      api: DoctorMedicalRecordApi(context.read<AppHttpClient>()),
    );
    _registerActiveConsultationRealtime();
    _registerMedicalRecordRealtime();
    _initializeControllers(
      widget.bootstrapRepository ?? DoctorWorkspaceBootstrapRepository(api),
      widget.runtimeRepository ?? DoctorUrgentRuntimeRepository(api),
      widget.presenceRepository ??
          DoctorHomePresenceRepository(context.read<AppHttpClient>()),
      widget.locationProvider ?? const GeolocatorDoctorHomeLocationProvider(),
      widget.homeOfferRepository ??
          DoctorHomeOfferRepository(context.read<AppHttpClient>()),
      widget.homeCommitmentRepository ??
          DoctorHomeCommitmentRepository(context.read<AppHttpClient>()),
      widget.homeDispatchContextRepository ??
          DoctorHomeDispatchContextRepository(context.read<AppHttpClient>()),
      widget.urgentCabinetRepository ??
          DoctorUrgentCabinetRepository(
            context.read<AppHttpClient>(),
            onSessionRejected: _exitProtectedFlow,
          ),
    );
  }

  void _initializeControllers(
    DoctorWorkspaceBootstrapRepositoryContract workspaceRepository,
    DoctorUrgentRuntimeRepositoryContract runtimeRepository,
    DoctorHomePresenceRepositoryContract presenceRepository,
    DoctorHomeLocationProvider locationProvider,
    DoctorHomeOfferRepositoryContract homeOfferRepository,
    DoctorHomeCommitmentRepositoryContract homeCommitmentRepository,
    DoctorHomeDispatchContextRepositoryContract dispatchContextRepository,
    DoctorUrgentCabinetRepositoryContract urgentCabinetRepository,
  ) {
    _urgentCabinetRepository = urgentCabinetRepository;
    _workspaceController = DoctorWorkspaceBootstrapController(
      repository: workspaceRepository,
    )..addListener(_onWorkspaceChanged);
    _runtimeController = DoctorUrgentRuntimeController(
      repository: runtimeRepository,
      onSessionRejected: _exitProtectedFlow,
    )..addListener(_onRuntimeChanged);
    _presenceController = DoctorHomePresenceController(
      repository: presenceRepository,
      locationProvider: locationProvider,
      runtimeController: _runtimeController!,
      onSessionRejected: _exitProtectedFlow,
    )..addListener(_onPresenceChanged);
    _homeCommitmentController = DoctorHomeCommitmentController(
      repository: homeCommitmentRepository,
      onSessionRejected: _exitProtectedFlow,
    )..addListener(_onCommitmentChanged);
    _homeDispatchContextController = DoctorHomeDispatchContextController(
      repository: dispatchContextRepository,
      onSessionRejected: _exitProtectedFlow,
    );
    _homeOfferController = DoctorHomeOfferInboxController(
      repository: homeOfferRepository,
      onSessionRejected: _exitProtectedFlow,
      onCommitmentMayHaveChanged: _homeCommitmentController!.refresh,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeUrgentCabinet();
    _disposeScheduledCare();
    _unregisterActiveConsultationTarget?.call();
    _activeConsultationRealtimeTarget?.dispose();
    _activeConsultationController?.dispose();
    _unregisterMedicalRecordTarget?.call();
    _medicalRecordRealtimeTarget?.dispose();
    _medicalRecordController?.dispose();
    _workspaceController
      ?..removeListener(_onWorkspaceChanged)
      ..dispose();
    _runtimeController
      ?..removeListener(_onRuntimeChanged)
      ..dispose();
    _presenceController
      ?..removeListener(_onPresenceChanged)
      ..dispose();
    _homeOfferController?.dispose();
    _homeCommitmentController
      ?..removeListener(_onCommitmentChanged)
      ..dispose();
    _homeDispatchContextController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _homeDispatchContextController?.synchronizeCommitment(
              commitmentState: DoctorHomeCommitmentState.loading,
              commitment: _homeCommitmentController?.commitment,
            ) ??
            Future<void>.value(),
      );
      _presenceController?.resumeForeground();
      _workspaceController?.refresh();
      _homeOfferController?.refreshIfActive();
      unawaited(
        _activeConsultationController?.refresh() ?? Future<void>.value(),
      );
      _medicalRecordController?.refresh();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _presenceController?.pauseForBackground();
    }
  }

  void _onWorkspaceChanged() {
    final workspace = _workspaceController?.workspace;
    if (workspace != null &&
        _workspaceController?.state == DoctorWorkspaceBootstrapState.ready) {
      _runtimeController?.attachWorkspace(workspace);
      _presenceController?.attachWorkspace(workspace);
      final rolloutAvailable =
          workspace.runtimeAccess !=
          DoctorUrgentRuntimeBootstrapAccess.rolloutUnavailable;
      _homeOfferController?.attachDoctor(
        workspace.doctorId,
        hasHomeCapability: workspace.hasUrgentHome,
      );
      _homeOfferController?.synchronizeRolloutAccess(
        available: rolloutAvailable,
      );
      _homeDispatchContextController?.attachDoctor(workspace.doctorId);
      _homeCommitmentController?.attachDoctor(workspace.doctorId);
      _homeCommitmentController?.synchronizeRolloutAccess(
        available: rolloutAvailable,
      );
      if (rolloutAvailable) {
        _homeCommitmentController?.refresh();
      }
      final activeConsultationController = _activeConsultationController;
      if (activeConsultationController != null) {
        unawaited(
          activeConsultationController.attachDoctor(workspace.doctorId),
        );
      }
    }
    if (mounted) setState(() {});
  }

  void _onRuntimeChanged() {
    final runtimeState =
        _runtimeController?.state ?? DoctorUrgentRuntimeState.detached;
    if (runtimeState == DoctorUrgentRuntimeState.ready ||
        runtimeState == DoctorUrgentRuntimeState.unavailable) {
      final available = runtimeState == DoctorUrgentRuntimeState.ready;
      _homeOfferController?.synchronizeRolloutAccess(available: available);
      _homeCommitmentController?.synchronizeRolloutAccess(available: available);
      if (available &&
          _homeCommitmentController?.state ==
              DoctorHomeCommitmentState.initial) {
        _homeCommitmentController?.refresh();
      }
    }
    _presenceController?.synchronizeRuntime(
      runtimeState: runtimeState,
      snapshot: _runtimeController?.snapshot,
    );
    if (mounted) setState(() {});
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  void _onCommitmentChanged() {
    final commitmentController = _homeCommitmentController;
    if (commitmentController != null) {
      unawaited(
        _homeDispatchContextController?.synchronizeCommitment(
              commitmentState: commitmentController.state,
              commitment: commitmentController.commitment,
            ) ??
            Future<void>.value(),
      );
    }
    if (mounted) setState(() {});
  }

  void _registerActiveConsultationRealtime() {
    if (_unregisterActiveConsultationTarget != null) return;
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    final controller = _activeConsultationController;
    if (coordinator == null || controller == null) return;
    final target = DoctorActiveConsultationRealtimeTarget(controller);
    _activeConsultationRealtimeTarget = target;
    _unregisterActiveConsultationTarget = coordinator.registerTarget(target);
  }

  void _registerMedicalRecordRealtime() {
    if (_unregisterMedicalRecordTarget != null) return;
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    final controller = _medicalRecordController;
    if (coordinator == null || controller == null) return;
    final target = DoctorMedicalRecordRealtimeTarget(controller);
    _medicalRecordRealtimeTarget = target;
    _unregisterMedicalRecordTarget = coordinator.registerTarget(target);
  }

  Future<void> _logout(BuildContext context) async {
    _homeController?.clear();
    _bookingRequestController?.clear();
    _proposalController?.clear();
    _agendaController?.clear();
    _appointmentController?.clear();
    _activeConsultationController?.clear();
    _medicalRecordController?.clear();
    _disposeUrgentCabinet();
    _requestedDoctorId = null;
    _workspaceController?.clear();
    _presenceController?.clear();
    _homeOfferController?.clear();
    _homeDispatchContextController?.clear();
    _homeCommitmentController?.clear();
    _runtimeController?.clear();
    await context.read<AuthController>().logout();
  }

  void _ensureScheduledCare(String doctorId) {
    if (_scheduledCareDoctorId == doctorId && _homeController != null) return;
    _disposeScheduledCare();
    final repository = DoctorScheduledCareRepository(
      DoctorScheduledCareApi(context.read<AppHttpClient>()),
    );
    final home = DoctorHomeController(
      repository: repository,
      onForbidden: _exitProtectedFlow,
    );
    _scheduledCareDoctorId = doctorId;
    _homeController = home;
    final agenda = DoctorAgendaController(
      repository: repository,
      onForbidden: _exitProtectedFlow,
    );
    _agendaController = agenda;
    final bookingRequest = DoctorBookingRequestController(
      repository: repository,
      refreshHome: home.refresh,
      onForbidden: _exitProtectedFlow,
    );
    _bookingRequestController = bookingRequest;
    _proposalController = DoctorProposalController(
      authenticatedDoctorId: doctorId,
      scheduledCareRepository: repository,
      availabilityRepository: DoctorProposalAvailabilityRepository(
        DoctorDirectoryRepository(
          DoctorDirectoryApi(context.read<AppHttpClient>()),
        ),
      ),
      onRequestChanged: bookingRequest.applyAuthoritativeRequest,
      refreshHome: home.refresh,
      onForbidden: _exitProtectedFlow,
    );
    final appointment = DoctorAppointmentController(
      repository: repository,
      refreshAgenda: agenda.refresh,
      refreshHome: home.refresh,
      onForbidden: _exitProtectedFlow,
    );
    _appointmentController = appointment;
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (coordinator != null) {
      final target = DoctorScheduledCareRealtimeTarget(
        homeController: home,
        bookingController: bookingRequest,
        agendaController: agenda,
        appointmentController: appointment,
      );
      _realtimeTarget = target;
      _unregisterRealtimeTarget = coordinator.registerTarget(target);
    }
  }

  void _exitProtectedFlow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _logout(context);
    });
  }

  void _disposeScheduledCare() {
    _scheduledCareDoctorId = null;
    _unregisterRealtimeTarget?.call();
    _unregisterRealtimeTarget = null;
    _realtimeTarget?.dispose();
    _realtimeTarget = null;
    _homeController?.dispose();
    _bookingRequestController?.dispose();
    _proposalController?.dispose();
    _agendaController?.dispose();
    _appointmentController?.dispose();
    _homeController = null;
    _bookingRequestController = null;
    _proposalController = null;
    _agendaController = null;
    _appointmentController = null;
  }

  void _disposeUrgentCabinet() {
    _urgentCabinetController?.dispose();
    _urgentCabinetController = null;
  }

  DoctorUrgentCabinetController _ensureUrgentCabinet({
    required String authenticatedDoctorId,
  }) {
    final repository = _urgentCabinetRepository;
    if (repository == null) {
      throw StateError('Doctor CABINET repository is not initialized.');
    }
    final controller = _urgentCabinetController ??=
        DoctorUrgentCabinetController(developmentSimulationEnabled: false);
    controller.configure(
      authenticatedDoctorId: authenticatedDoctorId,
      workspaceConfig: _workspaceController?.workspace?.presentationConfig,
      requestSource: repository,
      decisionSource: repository,
      commitmentSource: repository,
    );
    return controller;
  }

  void _loadWorkspace(String doctorId) {
    _requestedDoctorId = doctorId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedDoctorId == doctorId) {
        _workspaceController?.load(doctorId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspaceController = _workspaceController;
    final runtimeController = _runtimeController;
    final presenceController = _presenceController;
    final homeOfferController = _homeOfferController;
    final homeCommitmentController = _homeCommitmentController;
    final homeDispatchContextController = _homeDispatchContextController;
    if (workspaceController == null ||
        runtimeController == null ||
        presenceController == null ||
        homeOfferController == null ||
        homeCommitmentController == null ||
        homeDispatchContextController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final auth = context.watch<AuthController>();
    if (!auth.isAuthenticated || auth.roleFamily != AuthRoleFamily.doctor) {
      if (_urgentCabinetController != null) _disposeUrgentCabinet();
      if (_scheduledCareDoctorId != null) _disposeScheduledCare();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestedDoctorId = null;
        workspaceController.clear();
        presenceController.clear();
        homeOfferController.clear();
        homeDispatchContextController.clear();
        homeCommitmentController.clear();
        runtimeController.clear();
        _activeConsultationController?.clear();
        _medicalRecordController?.clear();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final doctorId = auth.currentUser?.id.trim() ?? '';
    if (doctorId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_requestedDoctorId != doctorId) {
      if (_scheduledCareDoctorId != null &&
          _scheduledCareDoctorId != doctorId) {
        _disposeScheduledCare();
      }
      if (_urgentCabinetController != null) _disposeUrgentCabinet();
      presenceController.clear();
      homeOfferController.clear();
      homeDispatchContextController.clear();
      homeCommitmentController.clear();
      runtimeController.clear();
      _activeConsultationController?.clear();
      _medicalRecordController?.clear();
      _loadWorkspace(doctorId);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final retainedWorkspace = workspaceController.workspace;
    if ((workspaceController.isLoading ||
            workspaceController.state ==
                DoctorWorkspaceBootstrapState.initial) &&
        retainedWorkspace == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (workspaceController.state == DoctorWorkspaceBootstrapState.failure &&
        retainedWorkspace == null) {
      return _DoctorWorkspaceLoadFailure(
        message:
            workspaceController.errorMessage ??
            'La configuration professionnelle est indisponible.',
        onRetry: workspaceController.refresh,
        onLogout: () => _logout(context),
      );
    }
    final workspace = retainedWorkspace;
    if (workspace == null || workspace.doctorId != doctorId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = AuthenticatedDoctorDisplayProfile();

    _ensureScheduledCare(doctorId);
    final urgentCabinetController = _ensureUrgentCabinet(
      authenticatedDoctorId: doctorId,
    );

    return DoctorAppShell(
      profile: profile,
      onLogout: () => _logout(context),
      workspaceConfig: workspace.presentationConfig,
      authoritativeCapabilities: workspace.navigationCapabilities,
      urgentHomeOperationalMessage: workspace.homeOperationalMessage,
      urgentCabinetOperationalMessage: workspace.cabinetOperationalMessage,
      urgentRuntimeController: runtimeController,
      homePresenceController: presenceController,
      homeOfferController: homeOfferController,
      homeCommitmentController: homeCommitmentController,
      homeDispatchContextController: homeDispatchContextController,
      homeController: _homeController,
      bookingRequestController: _bookingRequestController,
      proposalController: _proposalController,
      agendaController: _agendaController,
      appointmentController: _appointmentController,
      activeConsultationController: _activeConsultationController,
      medicalRecordController: _medicalRecordController,
      urgentCabinetController: urgentCabinetController,
    );
  }
}

class _DoctorWorkspaceLoadFailure extends StatelessWidget {
  const _DoctorWorkspaceLoadFailure({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Espace médecin')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Configuration indisponible',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
                TextButton(
                  onPressed: onLogout,
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
