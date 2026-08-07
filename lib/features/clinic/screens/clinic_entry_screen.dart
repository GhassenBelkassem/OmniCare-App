import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../application/clinic_context_controller.dart';
import '../widgets/clinic_widgets.dart';
import 'clinic_access_unavailable_screen.dart';
import 'clinic_professional_home_screen.dart';
import 'clinic_selection_screen.dart';
import 'clinic_web_workspace_screen.dart';

/// Clinic shell. It triggers initialization for the authenticated `CLINIC_*`
/// user, renders the destination resolved by [ClinicContextController] and
/// revalidates the context when the app resumes.
class ClinicEntryScreen extends StatefulWidget {
  const ClinicEntryScreen({super.key});

  @override
  State<ClinicEntryScreen> createState() => _ClinicEntryScreenState();
}

class _ClinicEntryScreenState extends State<ClinicEntryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      context.read<ClinicContextController>().initializeForAuthenticatedUser(
        globalRole: auth.globalRole,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) return;
    // Throttled inside the controller to avoid refresh storms.
    context.read<ClinicContextController>().refreshOnResume();
  }

  @override
  Widget build(BuildContext context) {
    final destination = context.watch<ClinicContextController>().destination;

    return switch (destination) {
      ClinicDestination.loading => const ClinicLoadingScreen(),
      ClinicDestination.selection => const ClinicSelectionScreen(),
      ClinicDestination.professionalHome =>
        const ClinicProfessionalHomeScreen(),
      ClinicDestination.webWorkspace => const ClinicWebWorkspaceScreen(),
      ClinicDestination.accessUnavailable ||
      ClinicDestination.error => const ClinicAccessUnavailableScreen(),
    };
  }
}

class ClinicLoadingScreen extends StatelessWidget {
  const ClinicLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicPalette.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ClinicPalette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Preparing your clinic workspace',
                style: clinicTextStyle(
                  fontSize: 14,
                  color: ClinicPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
