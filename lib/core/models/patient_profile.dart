class VerifiedContact {
  const VerifiedContact({required this.value, required this.verified});

  final String value;
  final bool verified;

  factory VerifiedContact.fromJson(Map<String, dynamic> json) {
    return VerifiedContact(
      value: _requiredString(json, 'value'),
      verified: _requiredBool(json, 'verified'),
    );
  }
}

class ProfileNotificationPreferences {
  const ProfileNotificationPreferences({
    required this.medications,
    required this.appointments,
    required this.passport,
  });

  final bool medications;
  final bool appointments;
  final bool passport;

  ProfileNotificationPreferences copyWith({
    bool? medications,
    bool? appointments,
    bool? passport,
  }) {
    return ProfileNotificationPreferences(
      medications: medications ?? this.medications,
      appointments: appointments ?? this.appointments,
      passport: passport ?? this.passport,
    );
  }
}

class PatientProfile {
  const PatientProfile({
    this.patientId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.dateOfBirth,
    required this.gender,
    required this.photoUrl,
    required this.primaryPhone,
    required this.primaryEmail,
    required this.onboardingCompleted,
    required this.onboardingStep,
    required this.preferredLanguage,
    required this.notifications,
    required this.updatedAt,
  });

  final String? patientId;
  final String userId;
  final String firstName;
  final String lastName;
  final String displayName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? photoUrl;
  final VerifiedContact? primaryPhone;
  final VerifiedContact? primaryEmail;
  final bool onboardingCompleted;
  final int onboardingStep;
  final String preferredLanguage;
  final ProfileNotificationPreferences notifications;
  final DateTime? updatedAt;

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      patientId: _optionalString(json['patientId']),
      userId: _requiredString(json, 'userId'),
      firstName: _requiredString(json, 'firstName'),
      lastName: _requiredString(json, 'lastName'),
      displayName: _requiredString(json, 'displayName'),
      dateOfBirth: _optionalDateOnly(json['dateOfBirth']),
      gender: _optionalString(json['gender']),
      photoUrl: _optionalString(json['photoUrl']),
      primaryPhone: _optionalContact(json['primaryPhone']),
      primaryEmail: _optionalContact(json['primaryEmail']),
      onboardingCompleted: _requiredBool(json, 'onboardingCompleted'),
      onboardingStep: _requiredInt(json, 'onboardingStep'),
      preferredLanguage: _requiredString(json, 'preferredLanguage'),
      notifications: ProfileNotificationPreferences(
        medications: _requiredBool(json, 'notificationMedications'),
        appointments: _requiredBool(json, 'notificationAppointments'),
        passport: _requiredBool(json, 'notificationPassport'),
      ),
      updatedAt: _optionalInstant(json['updatedAt']),
    );
  }

  PatientProfile copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    DateTime? dateOfBirth,
    String? gender,
    String? photoUrl,
    bool clearPhoto = false,
    VerifiedContact? primaryPhone,
    VerifiedContact? primaryEmail,
    bool? onboardingCompleted,
    int? onboardingStep,
    String? preferredLanguage,
    ProfileNotificationPreferences? notifications,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      patientId: patientId,
      userId: userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
      primaryPhone: primaryPhone ?? this.primaryPhone,
      primaryEmail: primaryEmail ?? this.primaryEmail,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notifications: notifications ?? this.notifications,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get derivedFirstName {
    final value = firstName.trim();
    if (value.isNotEmpty) return value;
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }
}

class PatientProfileUpdate {
  const PatientProfileUpdate({
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.preferredLanguage,
    this.notificationMedications,
    this.notificationAppointments,
    this.notificationPassport,
  });

  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? preferredLanguage;
  final bool? notificationMedications;
  final bool? notificationAppointments;
  final bool? notificationPassport;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'firstName': firstName?.trim(),
      'lastName': lastName?.trim(),
      'dateOfBirth': dateOfBirth == null ? null : _formatDate(dateOfBirth!),
      'gender': gender?.trim(),
      'preferredLanguage': preferredLanguage?.trim(),
      'notificationMedications': notificationMedications,
      'notificationAppointments': notificationAppointments,
      'notificationPassport': notificationPassport,
    }..removeWhere((_, value) => value == null);
  }

  PatientProfile applyTo(PatientProfile profile) {
    final resolvedFirstName = firstName?.trim() ?? profile.firstName;
    final resolvedLastName = lastName?.trim() ?? profile.lastName;
    return profile.copyWith(
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      displayName: '$resolvedFirstName $resolvedLastName'.trim(),
      dateOfBirth: dateOfBirth,
      gender: gender?.trim(),
      preferredLanguage: preferredLanguage?.trim(),
      notifications: profile.notifications.copyWith(
        medications: notificationMedications,
        appointments: notificationAppointments,
        passport: notificationPassport,
      ),
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

VerifiedContact? _optionalContact(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw const FormatException('Expected contact object.');
  }
  return VerifiedContact.fromJson(value.cast<String, dynamic>());
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected string.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Missing or invalid $key.');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Missing or invalid $key.');
  return value.toInt();
}

DateTime? _optionalDateOnly(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected date string.');
  final parts = value.split('-');
  if (parts.length != 3) throw const FormatException('Invalid date.');
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    throw const FormatException('Invalid date.');
  }
  return DateTime.utc(year, month, day);
}

DateTime? _optionalInstant(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected timestamp.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Invalid timestamp.');
  return parsed.toUtc();
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
