import 'package:intl/intl.dart';

abstract interface class DoctorDisplayProfile {
  String get fullName;
  String get greetingName;
  String get specialty;
  String get initials;
  String get todayLabel;
}

/// Identity-safe fallback for the authenticated Doctor shell.
///
/// The current session contract has no name/specialty projection. This avoids
/// presenting the demo doctor's identity as real data while retaining the
/// approved shell until a Doctor profile endpoint is introduced.
class AuthenticatedDoctorDisplayProfile implements DoctorDisplayProfile {
  AuthenticatedDoctorDisplayProfile({DateTime? now})
    : todayLabel = DateFormat('dd/MM/yyyy').format(now ?? DateTime.now());

  @override
  String get fullName => 'Médecin';
  @override
  String get greetingName => 'Docteur';
  @override
  String get specialty => '';
  @override
  String get initials => 'DR';
  @override
  final String todayLabel;
}
