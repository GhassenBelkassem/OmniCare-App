import '../../../core/models/patient_profile.dart';
import '../data/models/auth_dtos.dart';
import 'auth_role_family.dart';

class AuthFlowException implements Exception {
  final String message;

  const AuthFlowException(this.message);

  @override
  String toString() => message;
}

enum AuthFlowMode { login, signup }

enum AuthRouteDecision {
  home,
  onboarding,
  passwordChangeRequired,
  doctorWorkspace,
  clinicWorkspace,
  unsupportedRole,
}

class PhoneSignupDraft {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String gender;

  const PhoneSignupDraft({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
  });

  String get dateOfBirthIso {
    final utc = DateTime.utc(
      dateOfBirth.year,
      dateOfBirth.month,
      dateOfBirth.day,
    );
    final yyyy = utc.year.toString().padLeft(4, '0');
    final mm = utc.month.toString().padLeft(2, '0');
    final dd = utc.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}

class AuthenticatedPatientSession {
  final CurrentUserDto user;

  /// Only populated for `PATIENT` accounts. Professional accounts (doctor and
  /// clinic roles) never load a patient profile.
  final PatientProfile? profile;

  const AuthenticatedPatientSession({
    required this.user,
    required this.profile,
  });

  AuthRoleFamily get roleFamily => AuthRoles.familyOf(user.role);

  AuthRouteDecision get routeDecision {
    if (user.mustChangePassword) {
      return AuthRouteDecision.passwordChangeRequired;
    }

    switch (roleFamily) {
      case AuthRoleFamily.patient:
        final patientProfile = profile;
        if (patientProfile == null) return AuthRouteDecision.unsupportedRole;
        return patientProfile.onboardingCompleted
            ? AuthRouteDecision.home
            : AuthRouteDecision.onboarding;
      case AuthRoleFamily.doctor:
        return AuthRouteDecision.doctorWorkspace;
      case AuthRoleFamily.clinic:
        return AuthRouteDecision.clinicWorkspace;
      case AuthRoleFamily.unsupported:
        return AuthRouteDecision.unsupportedRole;
    }
  }
}

enum GoogleAuthOutcome { authenticated, requiresPhone }

class GoogleAuthResult {
  final GoogleAuthOutcome outcome;
  final AuthenticatedPatientSession? session;

  const GoogleAuthResult._({required this.outcome, required this.session});

  const GoogleAuthResult.authenticated(AuthenticatedPatientSession session)
    : this._(outcome: GoogleAuthOutcome.authenticated, session: session);

  const GoogleAuthResult.requiresPhone()
    : this._(outcome: GoogleAuthOutcome.requiresPhone, session: null);
}

enum EmailPasswordLoginOutcome { authenticated, requiresPhoneOtp }

class EmailPasswordLoginResult {
  final EmailPasswordLoginOutcome outcome;
  final AuthenticatedPatientSession? session;
  final String? phone;

  const EmailPasswordLoginResult._({
    required this.outcome,
    required this.session,
    required this.phone,
  });

  const EmailPasswordLoginResult.authenticated(
    AuthenticatedPatientSession session,
  ) : this._(
        outcome: EmailPasswordLoginOutcome.authenticated,
        session: session,
        phone: null,
      );

  const EmailPasswordLoginResult.requiresPhoneOtp(String phone)
    : this._(
        outcome: EmailPasswordLoginOutcome.requiresPhoneOtp,
        session: null,
        phone: phone,
      );
}
