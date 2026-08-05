abstract final class FamilyRelationships {
  static const conjoint = 'conjoint';
  static const enfant = 'enfant';
  static const parent = 'parent';
  static const frereSoeur = 'frere_soeur';
  static const autre = 'autre';

  static const values = <String>{conjoint, enfant, parent, frereSoeur, autre};

  static String frenchLabel(String value) {
    return switch (value) {
      conjoint => 'Conjoint(e)',
      enfant => 'Enfant',
      parent => 'Parent',
      frereSoeur => 'Frère / sœur',
      autre => 'Autre',
      _ => value,
    };
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.accountHolderId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.relationship,
    required this.graduated,
    this.photoUrl,
    this.patientId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String accountHolderId;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String gender;
  final String relationship;
  final String? photoUrl;
  final String? patientId;
  final bool graduated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName'.trim();

  int get ageYears {
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: _requiredString(json, 'id'),
      accountHolderId: _requiredString(json, 'accountHolderId'),
      firstName: _requiredString(json, 'firstName'),
      lastName: _requiredString(json, 'lastName'),
      dateOfBirth: _requiredDate(json, 'dateOfBirth'),
      gender: _requiredString(json, 'gender'),
      relationship: _requiredRelationship(json),
      photoUrl: _optionalString(json['photoUrl']),
      patientId: _optionalString(json['patientId']),
      graduated: json['graduated'] == true,
      createdAt: _optionalDateTime(json['createdAt']),
      updatedAt: _optionalDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'dateOfBirth': formatDateOnly(dateOfBirth),
      'gender': gender,
      'relationship': relationship,
      'photoUrl': photoUrl,
    };
  }

  FamilyMember copyWith({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? relationship,
    String? photoUrl,
  }) {
    return FamilyMember(
      id: id,
      accountHolderId: accountHolderId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      relationship: relationship ?? this.relationship,
      photoUrl: photoUrl ?? this.photoUrl,
      patientId: patientId,
      graduated: graduated,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

String formatDateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _requiredRelationship(Map<String, dynamic> json) {
  final relationship = _requiredString(json, 'relationship');
  if (!FamilyRelationships.values.contains(relationship)) {
    throw FormatException('Invalid family relationship: $relationship');
  }
  return relationship;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('Missing $key.');
  return value;
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $key.');
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _optionalDateTime(Object? value) {
  final text = _optionalString(value);
  return text == null ? null : DateTime.tryParse(text);
}
