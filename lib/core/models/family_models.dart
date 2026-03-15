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
  final String relationship;
  final String? birthDate;
  final int? ageYears;
  final String? gender;
  final String? bloodGroup;
  final Map<String, dynamic>? medicalInfo;
  final String? patientId;

  FamilyMember({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.birthDate,
    this.ageYears,
    this.gender,
    this.bloodGroup,
    this.medicalInfo,
    this.patientId,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: (json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      birthDate: json['birthDate']?.toString(),
      ageYears: (json['ageYears'] is num)
          ? (json['ageYears'] as num).toInt()
          : null,
      gender: json['gender']?.toString(),
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
      'relationship': relationship,
      'birthDate': birthDate,
      'ageYears': ageYears,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'medicalInfo': medicalInfo,
      'patientId': patientId,
    };
  }
}
