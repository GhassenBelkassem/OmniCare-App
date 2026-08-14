/// Global account roles supported by the OmniCare mobile application and the
/// destination family each one belongs to.
///
/// The backend owns the authoritative role list. Mobile only maps the roles it
/// is able to serve and treats everything else as [AuthRoleFamily.unsupported]
/// so an unknown value can never be guessed into the patient, doctor or clinic
/// experience.
enum AuthRoleFamily { patient, doctor, clinic, unsupported }

class AuthRoles {
  const AuthRoles._();

  static const String patient = 'PATIENT';
  static const String doctor = 'DOCTOR';
  static const String clinicAdmin = 'CLINIC_ADMIN';
  static const String clinicMedecin = 'CLINIC_MEDECIN';
  static const String clinicInfirmiere = 'CLINIC_INFIRMIERE';
  static const String clinicKine = 'CLINIC_KINE';
  static const String clinicAssistant = 'CLINIC_ASSISTANT';

  static const Set<String> clinicRoles = <String>{
    clinicAdmin,
    clinicMedecin,
    clinicInfirmiere,
    clinicKine,
    clinicAssistant,
  };

  /// Normalizes a raw backend role value. Returns `null` when the value cannot
  /// be used as a role identifier at all.
  static String? normalize(String? role) {
    final value = role?.trim().toUpperCase();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static AuthRoleFamily familyOf(String? role) {
    final value = normalize(role);
    if (value == null) return AuthRoleFamily.unsupported;
    if (value == patient) return AuthRoleFamily.patient;
    if (value == doctor) return AuthRoleFamily.doctor;
    if (clinicRoles.contains(value)) return AuthRoleFamily.clinic;
    return AuthRoleFamily.unsupported;
  }

  static bool isPatient(String? role) =>
      familyOf(role) == AuthRoleFamily.patient;

  static bool isDoctor(String? role) => familyOf(role) == AuthRoleFamily.doctor;

  static bool isClinic(String? role) => familyOf(role) == AuthRoleFamily.clinic;

  static bool isSupported(String? role) =>
      familyOf(role) != AuthRoleFamily.unsupported;
}
