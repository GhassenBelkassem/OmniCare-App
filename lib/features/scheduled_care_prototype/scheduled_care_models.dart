/// P2-02 local presentation models for scheduled booking negotiation.
///
/// These classes are intentionally not transport DTOs. Nothing in this
/// feature is serialized to the appointment, request, or MRS APIs.
library;

enum ScheduledCareStatus {
  pendingDoctor,
  pendingPatientTimeConfirmation,
  confirmed,
  expired,
  cancelledByPatient,
  cancelledByDoctor,
}

enum ScheduledPatientSubjectType { self, familyMember }

enum ScheduledIntakeStatus { notSubmitted, submitted }

class PatientSubjectPrototype {
  const PatientSubjectPrototype({
    required this.type,
    required this.displayName,
    required this.relationshipLabel,
    this.familyMemberId,
  });

  final ScheduledPatientSubjectType type;
  final String displayName;
  final String relationshipLabel;
  final String? familyMemberId;
}

class CabinetPrototype {
  const CabinetPrototype({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
  });

  final String id;
  final String name;
  final String address;
  final String city;
}

class SlotPrototype {
  const SlotPrototype({
    required this.id,
    required this.cabinetId,
    required this.start,
    required this.end,
  });

  final String id;
  final String cabinetId;
  final DateTime start;
  final DateTime end;

  int get durationMinutes => end.difference(start).inMinutes;
}

class IntakePrototype {
  const IntakePrototype({
    this.status = ScheduledIntakeStatus.notSubmitted,
    this.bodyAreas = const [],
    this.description,
    this.painIntensity,
    this.submittedAt,
  });

  final ScheduledIntakeStatus status;
  final List<String> bodyAreas;
  final String? description;
  final int? painIntensity;
  final DateTime? submittedAt;
}

class BookingDraftPrototype {
  const BookingDraftPrototype({
    this.patient,
    this.doctorId,
    this.doctorName,
    this.doctorSpecialty,
    this.consultationPriceTnd,
    this.cabinet,
    this.slot,
  });

  final PatientSubjectPrototype? patient;
  final String? doctorId;
  final String? doctorName;
  final String? doctorSpecialty;
  final double? consultationPriceTnd;
  final CabinetPrototype? cabinet;
  final SlotPrototype? slot;

  bool get canReview =>
      patient != null &&
      doctorId != null &&
      doctorName != null &&
      cabinet != null &&
      slot != null;

  BookingDraftPrototype copyWith({
    PatientSubjectPrototype? patient,
    String? doctorId,
    String? doctorName,
    String? doctorSpecialty,
    double? consultationPriceTnd,
    CabinetPrototype? cabinet,
    SlotPrototype? slot,
    bool clearDoctor = false,
    bool clearSlot = false,
  }) {
    return BookingDraftPrototype(
      patient: patient ?? this.patient,
      doctorId: clearDoctor ? null : doctorId ?? this.doctorId,
      doctorName: clearDoctor ? null : doctorName ?? this.doctorName,
      doctorSpecialty: clearDoctor
          ? null
          : doctorSpecialty ?? this.doctorSpecialty,
      consultationPriceTnd: clearDoctor
          ? null
          : consultationPriceTnd ?? this.consultationPriceTnd,
      cabinet: clearDoctor ? null : cabinet ?? this.cabinet,
      slot: clearSlot || clearDoctor ? null : slot ?? this.slot,
    );
  }
}

sealed class ScheduledCareRecordPrototype {
  const ScheduledCareRecordPrototype({
    required this.id,
    required this.patient,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.cabinet,
    required this.requestedSlot,
    required this.proposedSlot,
    required this.status,
    required this.createdAt,
    required this.responseDeadline,
    required this.patientResponseDeadline,
    required this.cancelledAt,
    required this.cancellationReason,
    required this.lateCancellation,
    required this.intake,
  });

  final String id;
  final PatientSubjectPrototype patient;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final CabinetPrototype cabinet;
  final SlotPrototype requestedSlot;
  final SlotPrototype? proposedSlot;
  final ScheduledCareStatus status;
  final DateTime createdAt;
  final DateTime responseDeadline;
  final DateTime? patientResponseDeadline;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final bool lateCancellation;
  final IntakePrototype intake;

  SlotPrototype get activeSlot => proposedSlot ?? requestedSlot;
}

class BookingRequestPrototype extends ScheduledCareRecordPrototype {
  const BookingRequestPrototype({
    required super.id,
    required super.patient,
    required super.doctorId,
    required super.doctorName,
    required super.doctorSpecialty,
    required super.cabinet,
    required super.requestedSlot,
    required super.proposedSlot,
    required super.status,
    required super.createdAt,
    required super.responseDeadline,
    required super.patientResponseDeadline,
    required super.cancelledAt,
    required super.cancellationReason,
    required super.lateCancellation,
    required super.intake,
  }) : assert(status != ScheduledCareStatus.confirmed);

  BookingRequestPrototype copyWith({
    SlotPrototype? proposedSlot,
    ScheduledCareStatus? status,
    DateTime? patientResponseDeadline,
    DateTime? cancelledAt,
    String? cancellationReason,
    bool? lateCancellation,
  }) {
    return BookingRequestPrototype(
      id: id,
      patient: patient,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      cabinet: cabinet,
      requestedSlot: requestedSlot,
      proposedSlot: proposedSlot ?? this.proposedSlot,
      status: status ?? this.status,
      createdAt: createdAt,
      responseDeadline: responseDeadline,
      patientResponseDeadline:
          patientResponseDeadline ?? this.patientResponseDeadline,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      lateCancellation: lateCancellation ?? this.lateCancellation,
      intake: intake,
    );
  }
}

class AppointmentPrototype extends ScheduledCareRecordPrototype {
  const AppointmentPrototype({
    required super.id,
    required super.patient,
    required super.doctorId,
    required super.doctorName,
    required super.doctorSpecialty,
    required super.cabinet,
    required super.requestedSlot,
    required super.proposedSlot,
    required super.createdAt,
    required super.responseDeadline,
    required super.patientResponseDeadline,
    required super.cancelledAt,
    required super.cancellationReason,
    required super.lateCancellation,
    required super.intake,
    required this.confirmedAt,
  }) : super(status: ScheduledCareStatus.confirmed);

  final DateTime confirmedAt;

  AppointmentPrototype copyWith({IntakePrototype? intake}) {
    return AppointmentPrototype(
      id: id,
      patient: patient,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      cabinet: cabinet,
      requestedSlot: requestedSlot,
      proposedSlot: proposedSlot,
      createdAt: createdAt,
      responseDeadline: responseDeadline,
      patientResponseDeadline: patientResponseDeadline,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
      lateCancellation: lateCancellation,
      intake: intake ?? this.intake,
      confirmedAt: confirmedAt,
    );
  }
}

String scheduledCareStatusLabel(ScheduledCareStatus status) => switch (status) {
  ScheduledCareStatus.pendingDoctor => 'En attente du médecin',
  ScheduledCareStatus.pendingPatientTimeConfirmation =>
    'Votre confirmation est requise',
  ScheduledCareStatus.confirmed => 'Confirmé',
  ScheduledCareStatus.expired => 'Expiré',
  ScheduledCareStatus.cancelledByPatient => 'Annulé par le patient',
  ScheduledCareStatus.cancelledByDoctor => 'Annulé par le médecin',
};
