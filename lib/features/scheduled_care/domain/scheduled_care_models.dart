library;

enum CareSubjectType {
  self('SELF'),
  familyMember('FAMILY_MEMBER'),
  unknown('UNKNOWN');

  const CareSubjectType(this.wireValue);
  final String wireValue;

  static CareSubjectType parse(String? value) => switch (value) {
    'SELF' => CareSubjectType.self,
    'FAMILY_MEMBER' => CareSubjectType.familyMember,
    _ => CareSubjectType.unknown,
  };
}

/// The only patient identity shape accepted by scheduled care.
class CareSubject {
  const CareSubject._({
    required this.subjectType,
    this.familyMemberId,
    this.displayName,
    this.relationship,
  });

  const CareSubject.self({String? displayName})
    : this._(subjectType: CareSubjectType.self, displayName: displayName);

  factory CareSubject.familyMember({
    required String familyMemberId,
    String? displayName,
    String? relationship,
  }) {
    final id = familyMemberId.trim();
    if (id.isEmpty) {
      throw const ScheduledCareContractException(
        'Family member id is required.',
      );
    }
    return CareSubject._(
      subjectType: CareSubjectType.familyMember,
      familyMemberId: id,
      displayName: displayName,
      relationship: relationship,
    );
  }

  final CareSubjectType subjectType;
  final String? familyMemberId;
  final String? displayName;
  final String? relationship;

  Map<String, dynamic> toCreateJson() => switch (subjectType) {
    CareSubjectType.self => const {'subjectType': 'SELF'},
    CareSubjectType.familyMember => {
      'subjectType': 'FAMILY_MEMBER',
      'familyMemberId': familyMemberId,
    },
    CareSubjectType.unknown => throw const ScheduledCareContractException(
      'Unknown subject type cannot be submitted.',
    ),
  };

  factory CareSubject.fromJson(Map<String, dynamic> json) {
    final type = CareSubjectType.parse(_requiredString(json, 'subjectType'));
    final familyMemberId = _optionalString(json['familyMemberId']);
    if (type == CareSubjectType.self && familyMemberId != null) {
      throw const ScheduledCareContractException('Invalid SELF subject.');
    }
    if (type == CareSubjectType.familyMember && familyMemberId == null) {
      throw const ScheduledCareContractException(
        'Invalid FAMILY_MEMBER subject.',
      );
    }
    return CareSubject._(
      subjectType: type,
      familyMemberId: familyMemberId,
      displayName: _optionalString(json['displayName']),
      relationship: _optionalString(json['relationship']),
    );
  }
}

class RequestedSlot {
  const RequestedSlot({
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  final DateTime start;
  final DateTime end;
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
  };

  factory RequestedSlot.fromJson(Map<String, dynamic> json) {
    final start = _requiredInstant(json, 'start');
    final end = _requiredInstant(json, 'end');
    if (!start.isBefore(end)) {
      throw const ScheduledCareContractException('Invalid slot interval.');
    }
    return RequestedSlot(
      start: start,
      end: end,
      durationMinutes: end.difference(start).inMinutes,
    );
  }
}

enum BookingRequestStatus {
  pendingDoctor('PENDING_DOCTOR'),
  pendingPatientTimeConfirmation('PENDING_PATIENT_TIME_CONFIRMATION'),
  fulfilled('FULFILLED'),
  cancelledByPatient('CANCELLED_BY_PATIENT'),
  cancelledByDoctor('CANCELLED_BY_DOCTOR'),
  expired('EXPIRED'),
  unknown('UNKNOWN');

  const BookingRequestStatus(this.wireValue);
  final String wireValue;

  static BookingRequestStatus parse(String? value) => switch (value) {
    'PENDING_DOCTOR' => BookingRequestStatus.pendingDoctor,
    'PENDING_PATIENT_TIME_CONFIRMATION' =>
      BookingRequestStatus.pendingPatientTimeConfirmation,
    'FULFILLED' => BookingRequestStatus.fulfilled,
    'CANCELLED_BY_PATIENT' => BookingRequestStatus.cancelledByPatient,
    'CANCELLED_BY_DOCTOR' => BookingRequestStatus.cancelledByDoctor,
    'EXPIRED' => BookingRequestStatus.expired,
    _ => BookingRequestStatus.unknown,
  };
}

class DoctorProjection {
  const DoctorProjection({
    required this.doctorId,
    required this.displayName,
    this.specialty,
  });

  final String doctorId;
  final String displayName;
  final String? specialty;

  factory DoctorProjection.fromJson(Map<String, dynamic> json) =>
      DoctorProjection(
        doctorId: _requiredString(json, 'doctorId'),
        displayName: _requiredString(json, 'displayName'),
        specialty: _optionalString(json['specialty']),
      );
}

/// Immutable Cabinet snapshot returned by a booking request.
class BookingCabinetProjection {
  const BookingCabinetProjection({
    required this.practiceLocationId,
    required this.name,
    required this.address,
    required this.city,
    required this.governorate,
    required this.timezone,
  });

  final String practiceLocationId;
  final String name;
  final String address;
  final String city;
  final String governorate;
  final String timezone;

  factory BookingCabinetProjection.fromJson(Map<String, dynamic> json) =>
      BookingCabinetProjection(
        practiceLocationId: _requiredString(json, 'practiceLocationId'),
        name: _requiredString(json, 'name'),
        address: _requiredString(json, 'address'),
        city: _requiredString(json, 'city'),
        governorate: _requiredString(json, 'governorate'),
        timezone: _requiredString(json, 'timezone'),
      );
}

class PriceQuote {
  const PriceQuote({
    required this.amount,
    required this.currency,
    this.quotedAt,
  });

  final double amount;
  final String currency;
  final DateTime? quotedAt;

  factory PriceQuote.fromJson(Map<String, dynamic> json) => PriceQuote(
    amount: _requiredDouble(json, 'amount'),
    currency: _requiredString(json, 'currency'),
    quotedAt: _optionalInstant(json['quotedAt']),
  );
}

enum AvailableAction {
  cancelRequest('CANCEL_REQUEST'),
  acceptProposedTime('ACCEPT_PROPOSED_TIME'),
  declineProposedTime('DECLINE_PROPOSED_TIME'),
  unknown('UNKNOWN');

  const AvailableAction(this.wireValue);
  final String wireValue;

  static AvailableAction parse(String? value) => switch (value) {
    'CANCEL_REQUEST' => AvailableAction.cancelRequest,
    'ACCEPT_PROPOSED_TIME' => AvailableAction.acceptProposedTime,
    'DECLINE_PROPOSED_TIME' => AvailableAction.declineProposedTime,
    _ => AvailableAction.unknown,
  };
}

class CancellationProjection {
  const CancellationProjection({
    required this.actor,
    required this.reasonCode,
    required this.cancelledAt,
  });

  final String actor;
  final String? reasonCode;
  final DateTime cancelledAt;

  factory CancellationProjection.fromJson(Map<String, dynamic> json) =>
      CancellationProjection(
        actor: _requiredString(json, 'actor'),
        reasonCode: _optionalString(json['reasonCode']),
        cancelledAt: _requiredInstant(json, 'cancelledAt'),
      );
}

class ProposedSlot {
  const ProposedSlot({
    required this.proposalId,
    required this.start,
    required this.end,
    required this.proposedAt,
    required this.patientResponseDeadline,
  });

  final String proposalId;
  final DateTime start;
  final DateTime end;
  final DateTime proposedAt;
  final DateTime patientResponseDeadline;

  factory ProposedSlot.fromJson(Map<String, dynamic> json) => ProposedSlot(
    proposalId: _requiredString(json, 'proposalId'),
    start: _requiredInstant(json, 'start'),
    end: _requiredInstant(json, 'end'),
    proposedAt: _requiredInstant(json, 'proposedAt'),
    patientResponseDeadline: _requiredInstant(json, 'patientResponseDeadline'),
  );
}

class ActiveSlot {
  const ActiveSlot({
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  final DateTime start;
  final DateTime end;
  final int durationMinutes;

  factory ActiveSlot.fromJson(Map<String, dynamic> json) => ActiveSlot(
    start: _requiredInstant(json, 'start'),
    end: _requiredInstant(json, 'end'),
    durationMinutes: _requiredInt(json, 'durationMinutes'),
  );
}

class PatientBookingRequestDetail {
  const PatientBookingRequestDetail({
    required this.requestId,
    required this.version,
    required this.status,
    required this.rawStatus,
    required this.subject,
    required this.doctor,
    required this.cabinet,
    required this.originalRequestedSlot,
    this.proposedSlot,
    this.activeSlot,
    this.priceQuote,
    required this.createdAt,
    required this.responseDeadline,
    this.confirmedAppointmentId,
    this.cancellation,
    this.expiredAt,
    this.expiryReason,
    required this.slotReleased,
    required this.availableActions,
    required this.updatedAt,
  });

  final String requestId;
  final int version;
  final BookingRequestStatus status;
  final String rawStatus;
  final CareSubject subject;
  final DoctorProjection doctor;
  final BookingCabinetProjection cabinet;
  final RequestedSlot originalRequestedSlot;
  final ProposedSlot? proposedSlot;
  final ActiveSlot? activeSlot;
  final PriceQuote? priceQuote;
  final DateTime createdAt;
  final DateTime responseDeadline;
  final String? confirmedAppointmentId;
  final CancellationProjection? cancellation;
  final DateTime? expiredAt;
  final String? expiryReason;
  final bool slotReleased;
  final List<AvailableAction> availableActions;
  final DateTime updatedAt;

  factory PatientBookingRequestDetail.fromJson(Map<String, dynamic> json) {
    final rawStatus = _requiredString(json, 'status');
    final proposedSlot = _optionalMap(json['proposedSlot']);
    final activeSlot = _optionalMap(json['activeSlot']);
    final priceQuote = _optionalMap(json['priceQuote']);
    final cancellation = _optionalMap(json['cancellation']);
    return PatientBookingRequestDetail(
      requestId: _requiredString(json, 'requestId'),
      version: _requiredInt(json, 'version'),
      status: BookingRequestStatus.parse(rawStatus),
      rawStatus: rawStatus,
      subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
      doctor: DoctorProjection.fromJson(_requiredMap(json, 'doctor')),
      cabinet: BookingCabinetProjection.fromJson(_requiredMap(json, 'cabinet')),
      originalRequestedSlot: RequestedSlot.fromJson(
        _requiredMap(json, 'originalRequestedSlot'),
      ),
      proposedSlot: proposedSlot == null
          ? null
          : ProposedSlot.fromJson(proposedSlot),
      activeSlot: activeSlot == null ? null : ActiveSlot.fromJson(activeSlot),
      priceQuote: priceQuote == null ? null : PriceQuote.fromJson(priceQuote),
      createdAt: _requiredInstant(json, 'createdAt'),
      responseDeadline: _requiredInstant(json, 'responseDeadline'),
      confirmedAppointmentId: _optionalString(json['confirmedAppointmentId']),
      cancellation: cancellation == null
          ? null
          : CancellationProjection.fromJson(cancellation),
      expiredAt: _optionalInstant(json['expiredAt']),
      expiryReason: _optionalString(json['expiryReason']),
      slotReleased: _requiredBool(json, 'slotReleased'),
      availableActions: _requiredList(json, 'availableActions')
          .map((value) => AvailableAction.parse(value?.toString()))
          .toList(growable: false),
      updatedAt: _requiredInstant(json, 'updatedAt'),
    );
  }
}

class CreateBookingRequestCommand {
  const CreateBookingRequestCommand({
    required this.requestId,
    required this.doctorId,
    required this.practiceLocationId,
    required this.subject,
    required this.requestedSlot,
  });

  final String requestId;
  final String doctorId;
  final String practiceLocationId;
  final CareSubject subject;
  final RequestedSlot requestedSlot;

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'doctorId': doctorId,
    'practiceLocationId': practiceLocationId,
    'subject': subject.toCreateJson(),
    'requestedSlot': requestedSlot.toJson(),
  };
}

enum PatientCancellationReason {
  changeOfPlans('CHANGE_OF_PLANS'),
  noLongerNeeded('NO_LONGER_NEEDED'),
  proposalDeclined('PROPOSAL_DECLINED');

  const PatientCancellationReason(this.wireValue);
  final String wireValue;
}

class CancelBookingRequestCommand {
  const CancelBookingRequestCommand({
    required this.requestId,
    required this.expectedVersion,
    required this.idempotencyKey,
    required this.reason,
  });

  final String requestId;
  final int expectedVersion;
  final String idempotencyKey;
  final PatientCancellationReason reason;

  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'reasonCode': reason.wireValue,
  };
}

class AcceptBookingProposalCommand {
  const AcceptBookingProposalCommand({
    required this.requestId,
    required this.proposalId,
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  final String requestId;
  final String proposalId;
  final int expectedVersion;
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {'expectedVersion': expectedVersion};
}

class DeclineBookingProposalCommand {
  const DeclineBookingProposalCommand({
    required this.requestId,
    required this.proposalId,
    required this.expectedVersion,
    required this.idempotencyKey,
    this.reason = PatientCancellationReason.proposalDeclined,
  });

  final String requestId;
  final String proposalId;
  final int expectedVersion;
  final String idempotencyKey;
  final PatientCancellationReason reason;

  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'reasonCode': reason.wireValue,
  };
}

enum ScheduledAppointmentStatus {
  confirmed('CONFIRMED'),
  inProgress('IN_PROGRESS'),
  cancelled('CANCELLED'),
  completed('COMPLETED'),
  noShow('NO_SHOW'),
  unknown('UNKNOWN');

  const ScheduledAppointmentStatus(this.wireValue);
  final String wireValue;

  static ScheduledAppointmentStatus parse(String? value) => switch (value) {
    'CONFIRMED' => ScheduledAppointmentStatus.confirmed,
    'IN_PROGRESS' => ScheduledAppointmentStatus.inProgress,
    'CANCELLED' => ScheduledAppointmentStatus.cancelled,
    'COMPLETED' => ScheduledAppointmentStatus.completed,
    'NO_SHOW' => ScheduledAppointmentStatus.noShow,
    _ => ScheduledAppointmentStatus.unknown,
  };
}

enum ScheduledAppointmentAction {
  cancelAppointment('CANCEL_APPOINTMENT'),
  unknown('UNKNOWN');

  const ScheduledAppointmentAction(this.wireValue);
  final String wireValue;

  static ScheduledAppointmentAction parse(String? value) => switch (value) {
    'CANCEL_APPOINTMENT' => ScheduledAppointmentAction.cancelAppointment,
    _ => ScheduledAppointmentAction.unknown,
  };
}

class ConfirmedAppointmentSlot {
  const ConfirmedAppointmentSlot({
    required this.start,
    required this.end,
    required this.timezone,
    required this.durationMinutes,
  });

  final DateTime start;
  final DateTime end;
  final String timezone;
  final int durationMinutes;

  factory ConfirmedAppointmentSlot.fromJson(Map<String, dynamic> json) {
    final start = _requiredInstant(json, 'start');
    final end = _requiredInstant(json, 'end');
    if (!start.isBefore(end)) {
      throw const ScheduledCareContractException(
        'Invalid appointment slot interval.',
      );
    }
    return ConfirmedAppointmentSlot(
      start: start,
      end: end,
      timezone: _requiredString(json, 'timezone'),
      durationMinutes: _requiredInt(json, 'durationMinutes'),
    );
  }
}

class AppointmentCancellationProjection {
  const AppointmentCancellationProjection({
    required this.actor,
    this.reasonCode,
    required this.cancelledAt,
    required this.lateCancellation,
  });

  final String actor;
  final String? reasonCode;
  final DateTime cancelledAt;
  final bool lateCancellation;

  factory AppointmentCancellationProjection.fromJson(
    Map<String, dynamic> json,
  ) => AppointmentCancellationProjection(
    actor: _requiredString(json, 'actor'),
    reasonCode: _optionalString(json['reasonCode']),
    cancelledAt: _requiredInstant(json, 'cancelledAt'),
    lateCancellation: _requiredBool(json, 'lateCancellation'),
  );
}

class ConfirmedScheduledAppointment {
  const ConfirmedScheduledAppointment({
    required this.appointmentId,
    required this.sourceBookingRequestId,
    required this.version,
    required this.status,
    required this.rawStatus,
    required this.doctor,
    required this.subject,
    required this.cabinet,
    required this.slot,
    this.quotedPrice,
    required this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
    this.cancellation,
    this.intakeStatus,
    required this.availableActions,
  });

  final String appointmentId;
  final String sourceBookingRequestId;
  final int version;
  final ScheduledAppointmentStatus status;
  final String rawStatus;
  final DoctorProjection doctor;
  final CareSubject subject;
  final BookingCabinetProjection cabinet;
  final ConfirmedAppointmentSlot slot;
  final PriceQuote? quotedPrice;
  final DateTime confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AppointmentCancellationProjection? cancellation;
  final String? intakeStatus;
  final List<ScheduledAppointmentAction> availableActions;

  factory ConfirmedScheduledAppointment.fromJson(Map<String, dynamic> json) {
    final rawStatus = _requiredString(json, 'status');
    final quotedPrice = _optionalMap(json['quotedPrice']);
    final cancellation = _optionalMap(json['cancellation']);
    return ConfirmedScheduledAppointment(
      appointmentId: _requiredString(json, 'appointmentId'),
      sourceBookingRequestId: _requiredString(json, 'sourceBookingRequestId'),
      version: _requiredInt(json, 'version'),
      status: ScheduledAppointmentStatus.parse(rawStatus),
      rawStatus: rawStatus,
      doctor: DoctorProjection.fromJson(_requiredMap(json, 'doctor')),
      subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
      cabinet: BookingCabinetProjection.fromJson(_requiredMap(json, 'cabinet')),
      slot: ConfirmedAppointmentSlot.fromJson(_requiredMap(json, 'slot')),
      quotedPrice: quotedPrice == null
          ? null
          : PriceQuote.fromJson(quotedPrice),
      confirmedAt: _requiredInstant(json, 'confirmedAt'),
      createdAt: _requiredInstant(json, 'createdAt'),
      updatedAt: _requiredInstant(json, 'updatedAt'),
      cancellation: cancellation == null
          ? null
          : AppointmentCancellationProjection.fromJson(cancellation),
      intakeStatus: _optionalString(json['intakeStatus']),
      availableActions: _requiredList(json, 'availableActions')
          .map((value) => ScheduledAppointmentAction.parse(value?.toString()))
          .toList(growable: false),
    );
  }
}

class ProposalAcceptanceResult {
  const ProposalAcceptanceResult._({
    required this.request,
    required this.appointment,
  });

  final PatientBookingRequestDetail request;
  final ConfirmedScheduledAppointment appointment;

  factory ProposalAcceptanceResult.fromJson(Map<String, dynamic> json) {
    final request = PatientBookingRequestDetail.fromJson(
      _requiredMap(json, 'request'),
    );
    final appointment = ConfirmedScheduledAppointment.fromJson(
      _requiredMap(json, 'appointment'),
    );
    return ProposalAcceptanceResult.validated(request, appointment);
  }

  factory ProposalAcceptanceResult.validated(
    PatientBookingRequestDetail request,
    ConfirmedScheduledAppointment appointment,
  ) {
    if (request.status != BookingRequestStatus.fulfilled ||
        request.confirmedAppointmentId == null ||
        request.requestId == appointment.appointmentId ||
        request.confirmedAppointmentId != appointment.appointmentId ||
        appointment.sourceBookingRequestId != request.requestId) {
      throw const ScheduledCareContractException(
        'Request and appointment identities are inconsistent.',
      );
    }
    return ProposalAcceptanceResult._(
      request: request,
      appointment: appointment,
    );
  }
}

class BookingMutationResult {
  const BookingMutationResult({
    required this.request,
    required this.intentCompleted,
    this.appointment,
  });

  final PatientBookingRequestDetail request;
  final bool intentCompleted;
  final ConfirmedScheduledAppointment? appointment;
}

class ScheduledCareContractException implements Exception {
  const ScheduledCareContractException(this.reason);
  final String reason;

  @override
  String toString() => 'ScheduledCareContractException: $reason';
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return value.cast<String, dynamic>();
  throw ScheduledCareContractException('Missing object "$key".');
}

Map<String, dynamic>? _optionalMap(Object? value) {
  if (value == null) return null;
  if (value is Map) return value.cast<String, dynamic>();
  throw const ScheduledCareContractException('Expected an object.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw ScheduledCareContractException('Missing array "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value != null) return value;
  throw ScheduledCareContractException('Missing string "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const ScheduledCareContractException('Expected a string.');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final value = _optionalInstant(json[key]);
  if (value != null) return value;
  throw ScheduledCareContractException('Missing instant "$key".');
}

DateTime? _optionalInstant(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const ScheduledCareContractException('Expected an instant.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw const ScheduledCareContractException('Invalid absolute instant.');
  }
  return parsed.toUtc();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw ScheduledCareContractException('Missing integer "$key".');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw ScheduledCareContractException('Missing number "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw ScheduledCareContractException('Missing boolean "$key".');
}
