import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/application/auth_controller.dart';
import '../auth/application/auth_role_family.dart';
import '../../core/network/app_http_client.dart';
import '../patient_doctor/data/doctor_directory_api.dart';
import '../patient_doctor/data/doctor_directory_repository.dart';
import '../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'onboarding/doctor_onboarding_screen.dart';
import 'profile/doctor_display_profile.dart';
import 'scheduled_care/application/doctor_booking_request_controller.dart';
import 'scheduled_care/application/doctor_appointment_controller.dart';
import 'scheduled_care/application/doctor_home_controller.dart';
import 'scheduled_care/application/doctor_proposal_controller.dart';
import 'scheduled_care/data/doctor_proposal_availability_repository.dart';
import 'scheduled_care/data/doctor_scheduled_care_api.dart';
import 'scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'agenda/doctor_agenda_controller.dart';
import 'shell/doctor_app_shell.dart';
import 'workspace/doctor_workspace_controller.dart';
import 'workspace/doctor_workspace_repository.dart';

/// Role guard and D1 local-workspace entry point for Doctor mobile.
class DoctorAuthShellScreen extends StatefulWidget {
  const DoctorAuthShellScreen({super.key, this.workspaceRepository});

  final DoctorWorkspaceRepository? workspaceRepository;

  @override
  State<DoctorAuthShellScreen> createState() => _DoctorAuthShellScreenState();
}

class _DoctorAuthShellScreenState extends State<DoctorAuthShellScreen> {
  late final DoctorWorkspaceController _workspaceController;
  String? _requestedDoctorId;
  String? _scheduledCareDoctorId;
  DoctorHomeController? _homeController;
  DoctorBookingRequestController? _bookingRequestController;
  DoctorProposalController? _proposalController;
  DoctorAgendaController? _agendaController;
  DoctorAppointmentController? _appointmentController;
  DoctorScheduledCareRealtimeTarget? _realtimeTarget;
  VoidCallback? _unregisterRealtimeTarget;

  @override
  void initState() {
    super.initState();
    _workspaceController = DoctorWorkspaceController(
      repository: widget.workspaceRepository ?? DoctorWorkspaceRepository(),
    )..addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    _disposeScheduledCare();
    _workspaceController
      ..removeListener(_onWorkspaceChanged)
      ..dispose();
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _logout(BuildContext context) async {
    _homeController?.clear();
    _bookingRequestController?.clear();
    _proposalController?.clear();
    _agendaController?.clear();
    _appointmentController?.clear();
    await context.read<AuthController>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
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

  void _loadWorkspace(String doctorId) {
    _requestedDoctorId = doctorId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedDoctorId == doctorId) {
        _workspaceController.load(doctorId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.isAuthenticated || auth.roleFamily != AuthRoleFamily.doctor) {
      if (_scheduledCareDoctorId != null) _disposeScheduledCare();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
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
      _loadWorkspace(doctorId);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_workspaceController.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = AuthenticatedDoctorDisplayProfile();
    if (!_workspaceController.onboardingCompleted) {
      return DoctorOnboardingScreen(
        doctorId: doctorId,
        profile: profile,
        onCompleted: _workspaceController.complete,
      );
    }

    _ensureScheduledCare(doctorId);

    return DoctorAppShell(
      profile: profile,
      onLogout: () => _logout(context),
      workspaceConfig: _workspaceController.config,
      onResetDemo: kDebugMode ? _workspaceController.resetForDemo : null,
      homeController: _homeController,
      bookingRequestController: _bookingRequestController,
      proposalController: _proposalController,
      agendaController: _agendaController,
      appointmentController: _appointmentController,
    );
  }
}
