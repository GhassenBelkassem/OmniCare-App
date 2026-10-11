import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/application/auth_controller.dart';
import '../auth/application/auth_role_family.dart';
import 'demo/doctor_demo_profile.dart';
import 'onboarding/doctor_onboarding_screen.dart';
import 'scheduled_care/doctor_scheduled_care_coordinator.dart';
import 'scheduled_care/doctor_scheduled_care_repository.dart';
import 'shell/doctor_app_shell.dart';
import 'workspace/doctor_workspace_controller.dart';
import 'workspace/doctor_workspace_repository.dart';
import '../scheduled_care/realtime/scheduled_care_realtime.dart';

/// Role guard and D1 local-workspace entry point for Doctor mobile.
class DoctorAuthShellScreen extends StatefulWidget {
  const DoctorAuthShellScreen({
    super.key,
    this.workspaceRepository,
    this.scheduledCare,
  });

  final DoctorWorkspaceRepository? workspaceRepository;
  final DoctorScheduledCareCoordinator? scheduledCare;

  @override
  State<DoctorAuthShellScreen> createState() => _DoctorAuthShellScreenState();
}

class _DoctorAuthShellScreenState extends State<DoctorAuthShellScreen> {
  late final DoctorWorkspaceController _workspaceController;
  String? _requestedDoctorId;
  DoctorScheduledCareCoordinator? _scheduledCare;
  String? _scheduledCareDoctorId;
  bool _exitScheduled = false;

  @override
  void initState() {
    super.initState();
    _workspaceController = DoctorWorkspaceController(
      repository: widget.workspaceRepository ?? DoctorWorkspaceRepository(),
    )..addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    _workspaceController
      ..removeListener(_onWorkspaceChanged)
      ..dispose();
    if (widget.scheduledCare == null) _scheduledCare?.dispose();
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _logout(BuildContext context) async {
    _scheduledCare?.clearSessionState();
    await context.read<AuthController>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _ensureScheduledCare(BuildContext context, String doctorId) {
    if (_scheduledCareDoctorId == doctorId && _scheduledCare != null) return;
    if (_scheduledCare != null) {
      if (widget.scheduledCare == null) {
        _scheduledCare!.dispose();
      } else {
        _scheduledCare!.clearSessionState();
      }
    }
    _scheduledCare =
        widget.scheduledCare ??
        DoctorScheduledCareCoordinator(
          repository: context.read<DoctorScheduledCareRepository>(),
          realtime: context.read<ScheduledCareRealtime>(),
          doctorId: doctorId,
        );
    _scheduledCareDoctorId = doctorId;
    final coordinator = _scheduledCare!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_scheduledCare, coordinator)) {
        coordinator.start();
      }
    });
  }

  void _scheduleDoctorExit(AuthController auth) {
    if (_exitScheduled) return;
    _exitScheduled = true;
    final destination = auth.isAuthenticated
        ? (auth.nextRoute ?? '/login')
        : '/login';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitScheduled = false;
      if (!mounted) return;
      _scheduledCare?.clearSessionState();
      if (widget.scheduledCare == null) _scheduledCare?.dispose();
      _scheduledCare = null;
      _scheduledCareDoctorId = null;
      _requestedDoctorId = null;
      _workspaceController.clearSessionState();
      Navigator.of(context).pushNamedAndRemoveUntil(destination, (_) => false);
    });
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
      _scheduleDoctorExit(auth);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final doctorId = auth.currentUser?.id.trim() ?? '';
    if (doctorId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _ensureScheduledCare(context, doctorId);
    if (_requestedDoctorId != doctorId) {
      _loadWorkspace(doctorId);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_workspaceController.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_workspaceController.onboardingCompleted) {
      return DoctorOnboardingScreen(
        doctorId: doctorId,
        profile: DoctorDemoProfile.current,
        onCompleted: _workspaceController.complete,
      );
    }

    return DoctorAppShell(
      profile: DoctorDemoProfile.current,
      onLogout: () => _logout(context),
      workspaceConfig: _workspaceController.config,
      onResetDemo: kDebugMode ? _workspaceController.resetForDemo : null,
      scheduledCare: _scheduledCare!,
    );
  }
}
