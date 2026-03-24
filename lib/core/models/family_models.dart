String? _bloodGroupFromBackend(String? raw) {
  if (raw == null) return null;
  final v = raw.trim();
  if (v.isEmpty) return null;
  return switch (v) {
    'A_POS' => 'A+',
    'A_NEG' => 'A-',
    'B_POS' => 'B+',
    'B_NEG' => 'B-',
    'AB_POS' => 'AB+',
    'AB_NEG' => 'AB-',
    'O_POS' => 'O+',
    'O_NEG' => 'O-',
    _ => v,
  };
}

class FamilyMember {
  final String id;
  final String fullName;
  final String? firstName;
  final String? lastName;
  final String relationship;
  final String? relationshipDescription;
  final String? phoneNumber;
  final String? birthDate;
  final int? ageYears;
  final String? gender;
  final String? profilePictureUrl;
  final String? profilePicturePublicId;
  final String? bloodGroup;
  final Map<String, dynamic>? medicalInfo;
  final String? patientId;

  FamilyMember({
    required this.id,
    required this.fullName,
    this.firstName,
    this.lastName,
    required this.relationship,
    this.relationshipDescription,
    this.phoneNumber,
    this.birthDate,
    this.ageYears,
    this.gender,
    this.profilePictureUrl,
    this.profilePicturePublicId,
    this.bloodGroup,
    this.medicalInfo,
    this.patientId,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: (json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      relationship: (json['relationship'] ?? '').toString(),
      relationshipDescription: json['relationshipDescription']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      birthDate: json['birthDate']?.toString(),
      ageYears: (json['ageYears'] is num)
          ? (json['ageYears'] as num).toInt()
          : null,
      gender: json['gender']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      profilePicturePublicId: json['profilePicturePublicId']?.toString(),
      bloodGroup: _bloodGroupFromBackend(json['bloodGroup']?.toString()),
      medicalInfo: (json['medicalInfo'] is Map)
          ? (json['medicalInfo'] as Map).cast<String, dynamic>()
          : null,
      patientId: json['patientId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'firstName': firstName,
      'lastName': lastName,
      'relationship': relationship,
      'relationshipDescription': relationshipDescription,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      'ageYears': ageYears,
      'gender': gender,
      'profilePictureUrl': profilePictureUrl,
      'profilePicturePublicId': profilePicturePublicId,
      'bloodGroup': bloodGroup,
      'medicalInfo': medicalInfo,
      'patientId': patientId,
    };
  }
}
