import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/patient_profile.dart';
import '../../../core/nav/keyboard_navigation.dart';
import '../../../providers/user_provider.dart';
import '../../emergency/urgent_cabinet/urgent_cabinet_patient_lifecycle_controller.dart';
import '../../emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart';
import 'auth_controller.dart';
import 'auth_role_family.dart';

/// Single post-authentication routing rule shared by every successful
/// authentication path (email/password, phone OTP, Google, restored session).
///
/// * `PATIENT` keeps the existing behaviour: the patient profile is published
///   to [UserProvider] and the existing patient route is used.
/// * `DOCTOR` and `CLINIC_*` accounts never require a patient profile.
/// * Anything mobile cannot serve fails safely back to login instead of being
///   guessed into the patient or clinic experience.
///
/// Returns `true` when a navigation was performed.
Future<bool> navigateAfterAuthentication(
  BuildContext context,
  AuthController auth, {
  bool dismissKeyboard = true,
}) async {
  if (!auth.isAuthenticated) return false;

  final family = auth.roleFamily;
  final route = auth.nextRoute;

  if (family == AuthRoleFamily.unsupported || route == null) {
    await auth.logout();
    if (!context.mounted) return false;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    return false;
  }

  // The patient experience still requires a restored patient profile.
  PatientProfile? patientProfile;
  if (family == AuthRoleFamily.patient) {
    patientProfile = auth.patientProfile;
    if (patientProfile == null) return false;
  }

  if (dismissKeyboard) {
    await dismissKeyboardBeforeNavigation(context);
    if (!context.mounted) return false;
  }

  if (patientProfile != null) {
    context.read<UserProvider>().setPatientProfile(patientProfile);
  }

  var restoreUrgentCabinet = false;
  String? restoredUrgentCabinetAccountId;
  if (patientProfile != null && route == '/home') {
    final lifecycle = context.read<UrgentCabinetPatientLifecycleController?>();
    if (lifecycle != null) {
      final accountId = patientProfile.userId.trim();
      final authenticatedAccountId = auth.currentUser?.id.trim();
      if (accountId.isNotEmpty && accountId == authenticatedAccountId) {
        final restored = await lifecycle.recoverAfterAuthentication(
          accountId: accountId,
        );
        if (!context.mounted ||
            !auth.isAuthenticated ||
            auth.currentUser?.id.trim() != accountId) {
          return false;
        }
        final status = lifecycle.snapshot?.responseStatus;
        restoreUrgentCabinet =
            restored &&
            (status == UrgentCabinetPatientResponseStatus.pending ||
                status == UrgentCabinetPatientResponseStatus.accepted);
        if (restoreUrgentCabinet) {
          restoredUrgentCabinetAccountId = accountId;
        }
      }
    }
  }

  final navigator = Navigator.of(context);
  navigator.pushNamedAndRemoveUntil(route, (_) => false);
  if (restoreUrgentCabinet) {
    // Keep Home below the flow. Closing an accepted confirmation is therefore
    // a deliberate return to Home, not a permanent recovery redirect.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!auth.isAuthenticated ||
          auth.currentUser?.role != 'PATIENT' ||
          auth.currentUser?.id.trim() != restoredUrgentCabinetAccountId) {
        return;
      }
      navigator.pushNamed('/urgent-cabinet/care-subject');
    });
  }
  return true;
}
