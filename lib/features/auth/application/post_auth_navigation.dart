import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/patient_profile.dart';
import '../../../core/nav/keyboard_navigation.dart';
import '../../../providers/user_provider.dart';
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

  Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  return true;
}
