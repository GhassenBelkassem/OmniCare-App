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

  const PassportMedication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.isCurrent,
    this.stoppedLabel,
  });

  String get instruction => '$dosage · $frequency';
}

@immutable
class PassportConsultation {
  final String date;
  final String doctor;
  final String doctorType;
  final String reason;
  final String specialty;
  final String diagnosis;
  final List<PassportConsultationMedication> medications;
  final PassportConsultationStatus status;
  final bool isShareable;

  const PassportConsultation({
    required this.date,
    required this.doctor,
    required this.doctorType,
    required this.reason,
    required this.specialty,
    required this.diagnosis,
    this.medications = const [],
    required this.status,
    required this.isShareable,
  });
}

@immutable
class PassportFamilyMember {
  final String name;
  final String relationship;
  final String avatarAsset;

  const PassportFamilyMember({
    required this.name,
    required this.relationship,
    required this.avatarAsset,
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
  final double heightCm;
  final double weightKg;

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
    this.heightCm = 180,
    this.weightKg = 78,
  });

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
