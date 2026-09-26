import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/application/auth_controller.dart';
import '../auth/application/auth_role_family.dart';
import 'demo/doctor_demo_profile.dart';
import 'onboarding/doctor_onboarding_screen.dart';
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
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthController>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
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
    );
  }
}
