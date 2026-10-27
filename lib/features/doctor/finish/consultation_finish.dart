class ConsultationOperationalState {
  const ConsultationOperationalState({
    required this.consultationId,
    required this.status,
    required this.medicalAccessStatus,
    required this.version,
    this.completedAt,
  });
  final String consultationId;
  final String status;
  final String medicalAccessStatus;
  final int version;
  final DateTime? completedAt;
  factory ConsultationOperationalState.fromJson(Map<String, dynamic> json) {
    final id = json['consultationId'];
    final status = json['status'];
    final access = json['medicalAccessStatus'];
    final version = json['version'];
    if (id is! String ||
        status is! String ||
        access is! String ||
        version is! int) {
      throw const FormatException('Invalid Consultation response.');
    }
    return ConsultationOperationalState(
      consultationId: id,
      status: status,
      medicalAccessStatus: access,
      version: version,
      completedAt: json['completedAt'] is String
          ? DateTime.tryParse(json['completedAt'] as String)?.toUtc()
          : null,
    );
  }
}
