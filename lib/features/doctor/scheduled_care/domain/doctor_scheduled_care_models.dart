import '../../../scheduled_care/domain/patient_scheduled_care_models.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';

enum DoctorBookingAction {
  acceptRequest('ACCEPT_REQUEST'),
  proposeNewTime('PROPOSE_NEW_TIME'),
  declineRequest('DECLINE_REQUEST'),
  unknown('UNKNOWN');

  const DoctorBookingAction(this.wireValue);
  final String wireValue;

  static DoctorBookingAction parse(String? value) => switch (value) {
    'ACCEPT_REQUEST' => DoctorBookingAction.acceptRequest,
    'PROPOSE_NEW_TIME' => DoctorBookingAction.proposeNewTime,
    'DECLINE_REQUEST' => DoctorBookingAction.declineRequest,
    _ => DoctorBookingAction.unknown,
  };
}

enum DoctorDeclineReason {
  cabinetUnavailable('CABINET_UNAVAILABLE', 'Cabinet indisponible'),
  doctorUnavailable('DOCTOR_UNAVAILABLE', 'Médecin indisponible'),
  scheduleConflict('SCHEDULE_CONFLICT', 'Conflit avec l’agenda');

  const DoctorDeclineReason(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

enum DoctorAppointmentCancellationReason {
  cabinetUnavailable('CABINET_UNAVAILABLE', 'Cabinet indisponible'),
  doctorUnavailable('DOCTOR_UNAVAILABLE', 'Médecin indisponible'),
  scheduleConflict('SCHEDULE_CONFLICT', 'Conflit avec l’agenda');

  const DoctorAppointmentCancellationReason(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

class DoctorAgendaRange {
  DoctorAgendaRange({required this.from, required this.to}) {
    final duration = to.toUtc().difference(from.toUtc());
    if (!from.toUtc().isBefore(to.toUtc()) ||
        duration > const Duration(days: 62)) {
      throw const ScheduledCareContractException(
        'Doctor Agenda range must be increasing and at most 62 days.',
      );
    }
  }

  final DateTime from;
  final DateTime to;

  Map<String, dynamic> toQueryParameters() => {
    'from': from.toUtc().toIso8601String(),
    'to': to.toUtc().toIso8601String(),
  };
}

class DoctorAgendaSnapshot {
  const DoctorAgendaSnapshot({
    required this.generatedAt,
    required this.from,
    required this.to,
    required this.items,
  });

  final DateTime generatedAt;
  final DateTime from;
  final DateTime to;
  final List<PatientScheduledCareItem> items;

  factory DoctorAgendaSnapshot.fromJson(Map<String, dynamic> json) {
    final from = _requiredInstant(json, 'from');
    final to = _requiredInstant(json, 'to');
    DoctorAgendaRange(from: from, to: to);
    final rawItems = _requiredList(json, 'items');
    if (rawItems.length > 5000) {
      throw const ScheduledCareContractException(
        'Doctor Agenda exceeds its result limit.',
      );
    }
    return DoctorAgendaSnapshot(
      generatedAt: _requiredInstant(json, 'generatedAt'),
      from: from,
      to: to,
      items: rawItems
          .map((value) {
            if (value is! Map) {
              throw const ScheduledCareContractException(
                'Expected a Doctor Agenda item object.',
              );
            }
            return PatientScheduledCareItem.fromJson(
              value.cast<String, dynamic>(),
            );
          })
          .toList(growable: false),
    );
  }
}

class DoctorHomeSummary {
  const DoctorHomeSummary({
    required this.generatedAt,
    required this.pendingRequestCount,
    this.nextPendingRequest,
    this.nextConfirmedAppointment,
  });

  final DateTime generatedAt;
  final int pendingRequestCount;
  final PatientScheduledCareItem? nextPendingRequest;
  final PatientScheduledCareItem? nextConfirmedAppointment;

  factory DoctorHomeSummary.fromJson(Map<String, dynamic> json) {
    final pending = _requiredInt(json, 'pendingRequestCount');
    if (pending < 0) {
      throw const ScheduledCareContractException(
        'Pending request count cannot be negative.',
      );
    }
    final request = _optionalItem(json['nextPendingRequest']);
    final appointment = _optionalItem(json['nextConfirmedAppointment']);
    if (request != null &&
        request.resourceType != ScheduledCareResourceType.bookingRequest) {
      throw const ScheduledCareContractException(
        'Home next request has the wrong resource type.',
      );
    }
    if (appointment != null &&
        appointment.resourceType != ScheduledCareResourceType.appointment) {
      throw const ScheduledCareContractException(
        'Home next appointment has the wrong resource type.',
      );
    }
    return DoctorHomeSummary(
      generatedAt: _requiredInstant(json, 'generatedAt'),
      pendingRequestCount: pending,
      nextPendingRequest: request,
      nextConfirmedAppointment: appointment,
    );
  }
}

class DoctorBookingRequestDetail {
  const DoctorBookingRequestDetail({
    required this.requestId,
    required this.version,
    required this.status,
    required this.rawStatus,
    required this.subject,
    required this.cabinet,
    required this.originalRequestedSlot,
    this.proposedSlot,
    this.activeSlot,
    required this.createdAt,
    required this.responseDeadline,
    this.patientResponseDeadline,
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
  final BookingCabinetProjection cabinet;
  final RequestedSlot originalRequestedSlot;
  final ProposedSlot? proposedSlot;
  final ActiveSlot? activeSlot;
  final DateTime createdAt;
  final DateTime responseDeadline;
  final DateTime? patientResponseDeadline;
  final String? confirmedAppointmentId;
  final CancellationProjection? cancellation;
  final DateTime? expiredAt;
  final String? expiryReason;
  final bool slotReleased;
  final List<DoctorBookingAction> availableActions;
  final DateTime updatedAt;

  bool get canAccept =>
      availableActions.contains(DoctorBookingAction.acceptRequest);
  bool get canDecline =>
      availableActions.contains(DoctorBookingAction.declineRequest);
  bool get canPropose =>
      availableActions.contains(DoctorBookingAction.proposeNewTime);

  factory DoctorBookingRequestDetail.fromJson(Map<String, dynamic> json) {
    final rawStatus = _requiredString(json, 'status');
    final proposed = _optionalMap(json['proposedSlot']);
    final active = _optionalMap(json['activeSlot']);
    final cancellation = _optionalMap(json['cancellation']);
    return DoctorBookingRequestDetail(
      requestId: _requiredString(json, 'requestId'),
      version: _requiredInt(json, 'version'),
      status: BookingRequestStatus.parse(rawStatus),
      rawStatus: rawStatus,
      subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
      cabinet: BookingCabinetProjection.fromJson(_requiredMap(json, 'cabinet')),
      originalRequestedSlot: RequestedSlot.fromJson(
        _requiredMap(json, 'originalRequestedSlot'),
      ),
      proposedSlot: proposed == null ? null : ProposedSlot.fromJson(proposed),
      activeSlot: active == null ? null : ActiveSlot.fromJson(active),
      createdAt: _requiredInstant(json, 'createdAt'),
      responseDeadline: _requiredInstant(json, 'responseDeadline'),
      patientResponseDeadline: _optionalInstant(
        json['patientResponseDeadline'],
      ),
      confirmedAppointmentId: _optionalString(json['confirmedAppointmentId']),
      cancellation: cancellation == null
          ? null
          : CancellationProjection.fromJson(cancellation),
      expiredAt: _optionalInstant(json['expiredAt']),
      expiryReason: _optionalString(json['expiryReason']),
      slotReleased: _requiredBool(json, 'slotReleased'),
      availableActions: _requiredList(json, 'availableActions')
          .map((value) => DoctorBookingAction.parse(value?.toString()))
          .toList(growable: false),
      updatedAt: _requiredInstant(json, 'updatedAt'),
    );
  }
}

class DoctorAcceptCommand {
  const DoctorAcceptCommand({
    required this.requestId,
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  final String requestId;
  final int expectedVersion;
  final String idempotencyKey;
  Map<String, dynamic> toJson() => {'expectedVersion': expectedVersion};
}

class DoctorDeclineCommand {
  const DoctorDeclineCommand({
    required this.requestId,
    required this.expectedVersion,
    required this.idempotencyKey,
    required this.reason,
  });

  final String requestId;
  final int expectedVersion;
  final String idempotencyKey;
  final DoctorDeclineReason reason;
  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'reasonCode': reason.wireValue,
  };
}

class DoctorProposalCommand {
  DoctorProposalCommand({
    required this.requestId,
    required this.expectedVersion,
    required this.practiceLocationId,
    required this.proposedStart,
    required this.proposedEnd,
    required this.idempotencyKey,
  }) {
    final start = DateTime.tryParse(proposedStart);
    final end = DateTime.tryParse(proposedEnd);
    if (requestId.trim().isEmpty ||
        practiceLocationId.trim().isEmpty ||
        start == null ||
        end == null ||
        !start.isBefore(end)) {
      throw const ScheduledCareContractException(
        'Invalid Doctor proposal command.',
      );
    }
  }

  final String requestId;
  final int expectedVersion;
  final String practiceLocationId;
  final String proposedStart;
  final String proposedEnd;
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'practiceLocationId': practiceLocationId,
    'proposedSlot': {'start': proposedStart, 'end': proposedEnd},
  };

  bool matches(DoctorBookingRequestDetail request) {
    final proposed = request.proposedSlot;
    if (proposed == null) return false;
    return request.requestId == requestId &&
        request.cabinet.practiceLocationId == practiceLocationId &&
        request.status == BookingRequestStatus.pendingPatientTimeConfirmation &&
        proposed.start.toUtc() == DateTime.parse(proposedStart).toUtc() &&
        proposed.end.toUtc() == DateTime.parse(proposedEnd).toUtc();
  }
}

class DoctorCancelAppointmentCommand {
  const DoctorCancelAppointmentCommand({
    required this.appointmentId,
    required this.expectedVersion,
    required this.reason,
    required this.idempotencyKey,
  });

  final String appointmentId;
  final int expectedVersion;
  final DoctorAppointmentCancellationReason reason;
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'reasonCode': reason.wireValue,
  };
}

class DoctorAppointmentMutationResult {
  const DoctorAppointmentMutationResult({
    required this.appointment,
    required this.intentCompleted,
  });

  final ConfirmedScheduledAppointment appointment;
  final bool intentCompleted;
}

class DoctorAcceptResult {
  const DoctorAcceptResult._({
    required this.request,
    required this.appointment,
  });

  final DoctorBookingRequestDetail request;
  final ConfirmedScheduledAppointment appointment;

  factory DoctorAcceptResult.fromJson(Map<String, dynamic> json) {
    return DoctorAcceptResult.validated(
      DoctorBookingRequestDetail.fromJson(_requiredMap(json, 'request')),
      ConfirmedScheduledAppointment.fromJson(_requiredMap(json, 'appointment')),
    );
  }

  factory DoctorAcceptResult.validated(
    DoctorBookingRequestDetail request,
    ConfirmedScheduledAppointment appointment,
  ) {
    if (request.status != BookingRequestStatus.fulfilled ||
        appointment.status != ScheduledAppointmentStatus.confirmed ||
        request.confirmedAppointmentId != appointment.appointmentId ||
        request.requestId == appointment.appointmentId ||
        appointment.sourceBookingRequestId != request.requestId) {
      throw const ScheduledCareContractException(
        'Doctor acceptance identities or states are inconsistent.',
      );
    }
    return DoctorAcceptResult._(request: request, appointment: appointment);
  }
}

class DoctorMutationResult {
  const DoctorMutationResult({
    required this.request,
    required this.intentCompleted,
    this.appointment,
  });

  final DoctorBookingRequestDetail request;
  final bool intentCompleted;
  final ConfirmedScheduledAppointment? appointment;
}

PatientScheduledCareItem? _optionalItem(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw const ScheduledCareContractException(
      'Expected a scheduled-care item object.',
    );
  }
  return PatientScheduledCareItem.fromJson(value.cast<String, dynamic>());
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
  throw ScheduledCareContractException('Missing list "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value != null) return value;
  throw ScheduledCareContractException('Missing string "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final value = _optionalInstant(json[key]);
  if (value != null) return value;
  throw ScheduledCareContractException('Missing instant "$key".');
}

DateTime? _optionalInstant(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) {
    throw const ScheduledCareContractException('Invalid instant.');
  }
  return parsed;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw ScheduledCareContractException('Missing integer "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw ScheduledCareContractException('Missing boolean "$key".');
}
