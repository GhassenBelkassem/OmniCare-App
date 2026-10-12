import '../profile/doctor_display_profile.dart';

/// Temporary D0 identity data.
///
/// Doctor profile data will replace this model once the Doctor profile API is
/// introduced. Keeping it here prevents demo content from leaking through the
/// presentation widgets.
class DoctorDemoProfile implements DoctorDisplayProfile {
  const DoctorDemoProfile({
    required this.fullName,
    required this.greetingName,
    required this.specialty,
    required this.initials,
    required this.todayLabel,
  });

  @override
  final String fullName;
  @override
  final String greetingName;
  @override
  final String specialty;
  @override
  final String initials;
  @override
  final String todayLabel;

  static const current = DoctorDemoProfile(
    fullName: 'Dr Ahmed Mansour',
    greetingName: 'Dr Mansour',
    specialty: 'Cardiologue',
    initials: 'AM',
    todayLabel: 'Mardi 23 septembre',
  );
}
