import 'package:flutter/foundation.dart';

enum PassportSection { summary, history, documents }

enum MedicationGroup { current, previous }

enum PassportConsultationStatus { completed, cancelled }

@immutable
class PassportConsultationMedication {
  const PassportConsultationMedication({
    required this.name,
    required this.instruction,
  });

  final String name;
  final String instruction;
}

@immutable
class PassportMedication {
  final String name;
  final String dosage;
  final String frequency;
  final bool isCurrent;
  final String? stoppedLabel;

  /// « Déclaré par le patient » for a medication the patient declared
  /// (ADR-012 rule 5); `null` for a prescription.
  final String? declaredLabel;

  const PassportMedication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.isCurrent,
    this.stoppedLabel,
    this.declaredLabel,
  });

  /// Dosage and frequency, skipping a part the prescription does not give.
  String get instruction =>
      [dosage, frequency].where((part) => part.isNotEmpty).join(' · ');
}

@immutable
class PassportConsultation {
  final String? consultationId;
  final String date;
  final String doctor;
  final String doctorType;
  final String reason;
  final String specialty;
  final String diagnosis;
  final List<PassportConsultationMedication> medications;
  final PassportConsultationStatus status;
  final bool isShareable;
  final int? sharingVersion;
  final String? assessment;
  final List<String> treatmentPlan;
  final String? notes;

  const PassportConsultation({
    this.consultationId,
    required this.date,
    required this.doctor,
    required this.doctorType,
    required this.reason,
    required this.specialty,
    required this.diagnosis,
    this.medications = const [],
    required this.status,
    required this.isShareable,
    this.sharingVersion,
    this.assessment,
    this.treatmentPlan = const [],
    this.notes,
  });

  PassportConsultation copyWithSharing({
    required bool isShareable,
    required int sharingVersion,
  }) => PassportConsultation(
    consultationId: consultationId,
    date: date,
    doctor: doctor,
    doctorType: doctorType,
    reason: reason,
    specialty: specialty,
    diagnosis: diagnosis,
    medications: medications,
    status: status,
    isShareable: isShareable,
    sharingVersion: sharingVersion,
    assessment: assessment,
    treatmentPlan: treatmentPlan,
    notes: notes,
  );
}

@immutable
class PassportFamilyMember {
  final String name;
  final String relationship;
  final String avatarAsset;
  final String? familyMemberId;
  final bool isSelf;

  const PassportFamilyMember({
    required this.name,
    required this.relationship,
    required this.avatarAsset,
    this.familyMemberId,
    this.isSelf = false,
  });
}

@immutable
class PatientPassportViewData {
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final String omniCareId;
  final String bloodGroup;
  final String allergies;
  final List<String> chronicConditions;
  final List<PassportMedication> medications;
  final List<PassportConsultation> consultations;
  final List<PassportFamilyMember> familyMembers;

  /// Null when the record holds no measurement: never a default value.
  final double? heightCm;
  final double? weightKg;

  const PatientPassportViewData({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.omniCareId,
    required this.bloodGroup,
    required this.allergies,
    required this.chronicConditions,
    required this.medications,
    required this.consultations,
    required this.familyMembers,
    this.heightCm,
    this.weightKg,
  });

  /// Identity only (header and identity card): no medical value at all.
  const PatientPassportViewData.identity({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.omniCareId,
  }) : bloodGroup = '',
       allergies = '',
       chronicConditions = const [],
       medications = const [],
       consultations = const [],
       familyMembers = const [],
       heightCm = null,
       weightKg = null;

  PatientPassportViewData copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? email,
    String? omniCareId,
    String? bloodGroup,
    String? allergies,
    List<String>? chronicConditions,
    List<PassportMedication>? medications,
    List<PassportConsultation>? consultations,
    List<PassportFamilyMember>? familyMembers,
    double? heightCm,
    double? weightKg,
  }) {
    return PatientPassportViewData(
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      omniCareId: omniCareId ?? this.omniCareId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      medications: medications ?? this.medications,
      consultations: consultations ?? this.consultations,
      familyMembers: familyMembers ?? this.familyMembers,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  List<PassportMedication> medicationsFor(MedicationGroup group) {
    return medications
        .where(
          (medication) =>
              medication.isCurrent == (group == MedicationGroup.current),
        )
        .toList(growable: false);
  }
}

@immutable
class PassportHistoryFilters {
  final String year;
  final String month;
  final String specialty;
  final String doctor;
  final String status;
  final String sharing;

  const PassportHistoryFilters({
    this.year = 'Toutes les années',
    this.month = 'Tous les Mois',
    this.specialty = 'Toutes les spécialités',
    this.doctor = 'Tous les médecins',
    this.status = 'Tous',
    this.sharing = 'Tous',
  });

  PassportHistoryFilters copyWith({
    String? year,
    String? month,
    String? specialty,
    String? doctor,
    String? status,
    String? sharing,
  }) {
    return PassportHistoryFilters(
      year: year ?? this.year,
      month: month ?? this.month,
      specialty: specialty ?? this.specialty,
      doctor: doctor ?? this.doctor,
      status: status ?? this.status,
      sharing: sharing ?? this.sharing,
    );
  }

  bool get isDefault => this == const PassportHistoryFilters();

  @override
  bool operator ==(Object other) {
    return other is PassportHistoryFilters &&
        other.year == year &&
        other.month == month &&
        other.specialty == specialty &&
        other.doctor == doctor &&
        other.status == status &&
        other.sharing == sharing;
  }

  @override
  int get hashCode =>
      Object.hash(year, month, specialty, doctor, status, sharing);
}
