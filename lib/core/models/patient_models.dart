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

class PatientPassport {
  final String patientId;
  final String type;
  final String displayName;
  final String fullName;
  final String? relationship;
  final String? phoneNumber;
  final String? dateOfBirth;
  final int? age;
  final double? height;
  final double? weight;
  final String? gender;
  final String? bloodGroup;
  final Map<String, dynamic>? medicalInfo;
  final List<String> chronicDiseases;
  final List<String> allergies;
  final List<PatientMedicationSummary> currentMedicines;
  final List<PastConsultationSummary> pastConsultations;
  final List<MedicalDocumentSummary> medicalDocuments;

  PatientPassport({
    required this.patientId,
    required this.type,
    required this.displayName,
    required this.fullName,
    this.relationship,
    this.phoneNumber,
    this.dateOfBirth,
    this.age,
    this.height,
    this.weight,
    this.gender,
    this.bloodGroup,
    this.medicalInfo,
    required this.chronicDiseases,
    required this.allergies,
    required this.currentMedicines,
    required this.pastConsultations,
    required this.medicalDocuments,
  });

  static double? _tryDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _tryInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory PatientPassport.fromJson(Map<String, dynamic> json) {
    final chronicRaw = json['chronicDiseases'];
    final allergiesRaw = json['allergies'];
    final medsRaw = json['currentMedicines'];
    final consultsRaw = json['pastConsultations'];
    final docsRaw = json['medicalDocuments'];

    return PatientPassport(
      patientId: (json['patientId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      relationship: json['relationship']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      age: _tryInt(json['age']),
      height: _tryDouble(json['height']),
      weight: _tryDouble(json['weight']),
      gender: json['gender']?.toString(),
      bloodGroup: json['bloodGroup']?.toString(),
      medicalInfo: (json['medicalInfo'] is Map)
          ? (json['medicalInfo'] as Map).cast<String, dynamic>()
          : null,
      chronicDiseases: (chronicRaw is List)
          ? chronicRaw.map((e) => e.toString()).toList()
          : const <String>[],
      allergies: (allergiesRaw is List)
          ? allergiesRaw.map((e) => e.toString()).toList()
          : const <String>[],
      currentMedicines: (medsRaw is List)
          ? medsRaw
                .whereType<Map>()
                .map(
                  (e) => PatientMedicationSummary.fromJson(
                    e.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const <PatientMedicationSummary>[],
      pastConsultations: (consultsRaw is List)
          ? consultsRaw
                .whereType<Map>()
                .map(
                  (e) => PastConsultationSummary.fromJson(
                    e.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const <PastConsultationSummary>[],
      medicalDocuments: (docsRaw is List)
          ? docsRaw
                .whereType<Map>()
                .map(
                  (e) => MedicalDocumentSummary.fromJson(
                    e.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const <MedicalDocumentSummary>[],
    );
  }
}

class PatientMedicationSummary {
  final String? id;
  final String? medicationId;
  final String? name;
  final String? dosage;
  final String? frequency;
  final String? notes;

  PatientMedicationSummary({
    this.id,
    this.medicationId,
    this.name,
    this.dosage,
    this.frequency,
    this.notes,
  });

  factory PatientMedicationSummary.fromJson(Map<String, dynamic> json) {
    return PatientMedicationSummary(
      id: json['id']?.toString(),
      medicationId: json['medicationId']?.toString(),
      name: json['name']?.toString(),
      dosage: json['dosage']?.toString(),
      frequency: json['frequency']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class PastConsultationSummary {
  final String? id;
  final String? status;
  final String? timestamp;
  final String? diagnosis;
  final String? treatment;
  final double? fee;

  PastConsultationSummary({
    this.id,
    this.status,
    this.timestamp,
    this.diagnosis,
    this.treatment,
    this.fee,
  });

  factory PastConsultationSummary.fromJson(Map<String, dynamic> json) {
    final feeRaw = json['fee'];
    return PastConsultationSummary(
      id: json['id']?.toString(),
      status: json['status']?.toString(),
      timestamp: json['timestamp']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      treatment: json['treatment']?.toString(),
      fee: (feeRaw is num)
          ? feeRaw.toDouble()
          : double.tryParse(feeRaw?.toString() ?? ''),
    );
  }
}

class MedicalDocumentSummary {
  final String? id;
  final String? title;
  final String? type;
  final String? issueDate;
  final String? fileUrl;

  MedicalDocumentSummary({
    this.id,
    this.title,
    this.type,
    this.issueDate,
    this.fileUrl,
  });

  factory MedicalDocumentSummary.fromJson(Map<String, dynamic> json) {
    return MedicalDocumentSummary(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      type: json['type']?.toString(),
      issueDate: json['issueDate']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
    );
  }
}
