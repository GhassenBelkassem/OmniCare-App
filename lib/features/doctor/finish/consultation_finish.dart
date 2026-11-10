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

class ConsultationFinishReadiness {
  const ConsultationFinishReadiness({
    required this.ready,
    required this.clinicalRecordSaved,
    required this.diagnosisReady,
    required this.medicationDecisionReady,
    required this.followUpReady,
    required this.prescriptionReady,
    required this.ordersReady,
    required this.artifactsReady,
    required this.missing,
  });
  final bool ready;
  final bool clinicalRecordSaved;
  final bool diagnosisReady;
  final bool medicationDecisionReady;
  final bool followUpReady;
  final bool prescriptionReady;
  final bool ordersReady;
  final bool artifactsReady;
  final List<String> missing;

  factory ConsultationFinishReadiness.fromJson(Map<String, dynamic> json) {
    bool flag(String key) => json[key] == true;
    final missing = json['missing'];
    if (json['ready'] is! bool || missing is! List) {
      throw const FormatException('Invalid Finish readiness response.');
    }
    return ConsultationFinishReadiness(
      ready: flag('ready'),
      clinicalRecordSaved: flag('clinicalRecordSaved'),
      diagnosisReady: flag('diagnosisReady'),
      medicationDecisionReady: flag('medicationDecisionReady'),
      followUpReady: flag('followUpReady'),
      prescriptionReady: flag('prescriptionReady'),
      ordersReady: flag('ordersReady'),
      artifactsReady: flag('artifactsReady'),
      missing: missing.whereType<String>().toList(growable: false),
    );
  }
}
