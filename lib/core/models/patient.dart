class PatientSummary {
  final String? patientId;
  final String? type;
  final String? displayName;
  final String? userId;
  final String? familyMemberId;

  const PatientSummary({
    this.patientId,
    this.type,
    this.displayName,
    this.userId,
    this.familyMemberId,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) {
    return PatientSummary(
      patientId: json['patientId']?.toString(),
      type: json['type']?.toString(),
      displayName: json['displayName']?.toString(),
      userId: json['userId']?.toString(),
      familyMemberId: json['familyMemberId']?.toString(),
    );
  }
}
