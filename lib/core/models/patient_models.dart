class PatientSummary {
  final String patientId;
  final String type;
  final String displayName;
  final String? userId;
  final String? familyMemberId;

  PatientSummary({
    required this.patientId,
    required this.type,
    required this.displayName,
    this.userId,
    this.familyMemberId,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) {
    return PatientSummary(
      patientId: (json['patientId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      userId: json['userId']?.toString(),
      familyMemberId: json['familyMemberId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'type': type,
      'displayName': displayName,
      'userId': userId,
      'familyMemberId': familyMemberId,
    };
  }
}
