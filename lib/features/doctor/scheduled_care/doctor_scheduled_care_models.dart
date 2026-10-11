import '../../scheduled_care/domain/scheduled_care_models.dart';

enum DoctorDeclineReason {
  cabinetUnavailable('CABINET_UNAVAILABLE', 'Cabinet indisponible'),
  doctorUnavailable('DOCTOR_UNAVAILABLE', 'Médecin indisponible'),
  scheduleConflict('SCHEDULE_CONFLICT', 'Conflit d’agenda');

  const DoctorDeclineReason(this.wireName, this.label);
  final String wireName;
  final String label;
}

enum DoctorAppointmentCancellationReason {
  cabinetUnavailable('CABINET_UNAVAILABLE', 'Cabinet indisponible'),
  doctorUnavailable('DOCTOR_UNAVAILABLE', 'Médecin indisponible'),
  scheduleConflict('SCHEDULE_CONFLICT', 'Conflit d’agenda');

  const DoctorAppointmentCancellationReason(this.wireName, this.label);
  final String wireName;
  final String label;
}

enum DoctorScheduledCareStatus {
  pendingDoctor,
  pendingPatientTimeConfirmation,
  fulfilled,
  confirmed,
  inProgress,
  cancelledByPatient,
  cancelledByDoctor,
  cancelled,
  completed,
  noShow,
  expired,
}

String doctorScheduledCareStatusLabel(DoctorScheduledCareStatus status) =>
    switch (status) {
      DoctorScheduledCareStatus.pendingDoctor => 'En attente du médecin',
      DoctorScheduledCareStatus.pendingPatientTimeConfirmation =>
        'Confirmation du patient attendue',
      DoctorScheduledCareStatus.fulfilled => 'Demande confirmée',
      DoctorScheduledCareStatus.confirmed => 'Confirmé',
      DoctorScheduledCareStatus.inProgress => 'En cours',
      DoctorScheduledCareStatus.cancelledByPatient => 'Annulé par le patient',
      DoctorScheduledCareStatus.cancelledByDoctor => 'Annulé par le médecin',
      DoctorScheduledCareStatus.cancelled => 'Annulé',
      DoctorScheduledCareStatus.completed => 'Terminé',
      DoctorScheduledCareStatus.noShow => 'Patient absent',
      DoctorScheduledCareStatus.expired => 'Expiré',
    };

class DoctorScheduledCareCabinet {
  const DoctorScheduledCareCabinet({
    this.practiceLocationId,
    required this.name,
    required this.address,
    required this.city,
    required this.governorate,
    required this.timezone,
  });

  final String? practiceLocationId;
  final String name;
  final String address;
  final String city;
  final String governorate;
  final String timezone;

  factory DoctorScheduledCareCabinet.fromJson(Map<String, dynamic> json) =>
      DoctorScheduledCareCabinet(
        practiceLocationId: _optionalString(json, 'practiceLocationId'),
        name: _requiredString(json, 'name'),
        address: _requiredString(json, 'address'),
        city: _optionalString(json, 'city') ?? '',
        governorate: _optionalString(json, 'governorate') ?? '',
        timezone: _requiredString(json, 'timezone'),
      );
}

class DoctorScheduledCareItem {
  const DoctorScheduledCareItem({
    required this.resourceType,
    required this.version,
    required this.subject,
    required this.cabinet,
    required this.activeSlot,
    required this.availableActions,
    required this.updatedAt,
    required this.sortAt,
    this.requestId,
    this.appointmentId,
    this.sourceBookingRequestId,
    this.bookingRequestStatus,
    this.appointmentStatus,
    this.originalRequestedSlot,
    this.proposedSlot,
    this.responseDeadline,
    this.patientResponseDeadline,
    this.cancellation,
    this.expiredAt,
    this.expiryReason,
    this.confirmedAt,
    this.intakeStatus,
  }) : assert(
         resourceType != ScheduledCareResourceType.bookingRequest ||
             (requestId != null &&
                 appointmentId == null &&
                 bookingRequestStatus != null &&
                 appointmentStatus == null),
       ),
       assert(
         resourceType != ScheduledCareResourceType.appointment ||
             (appointmentId != null &&
                 appointmentStatus != null &&
                 bookingRequestStatus == null),
       );

  final ScheduledCareResourceType resourceType;
  final String? requestId;
  final String? appointmentId;
  final String? sourceBookingRequestId;
  final int version;
  final BookingRequestStatus? bookingRequestStatus;
  final ScheduledAppointmentStatus? appointmentStatus;
  final CareSubject subject;
  final DoctorScheduledCareCabinet cabinet;
  final ScheduledCareSlot activeSlot;
  final ScheduledCareSlot? originalRequestedSlot;
  final ProposedSlot? proposedSlot;
  final DateTime? responseDeadline;
  final DateTime? patientResponseDeadline;
  final ScheduledCareCancellation? cancellation;
  final DateTime? expiredAt;
  final String? expiryReason;
  final DateTime? confirmedAt;
  final String? intakeStatus;
  final Set<ScheduledCareAction> availableActions;
  final DateTime sortAt;
  final DateTime updatedAt;

  String get resourceId => switch (resourceType) {
    ScheduledCareResourceType.bookingRequest => requestId!,
    ScheduledCareResourceType.appointment => appointmentId!,
  };

  String get patientDisplayName => subject.displayName;
  String get relationshipLabel => subject.relationship;
  ScheduledCareSlot get requestedSlot => originalRequestedSlot ?? activeSlot;
  DateTime? get cancelledAt => cancellation?.cancelledAt;
  String? get cancellationReason => cancellation?.reasonCode;

  DoctorScheduledCareStatus get status {
    final requestStatus = bookingRequestStatus;
    if (requestStatus != null) {
      return switch (requestStatus) {
        BookingRequestStatus.pendingDoctor =>
          DoctorScheduledCareStatus.pendingDoctor,
        BookingRequestStatus.pendingPatientTimeConfirmation =>
          DoctorScheduledCareStatus.pendingPatientTimeConfirmation,
        BookingRequestStatus.fulfilled => DoctorScheduledCareStatus.fulfilled,
        BookingRequestStatus.cancelledByPatient =>
          DoctorScheduledCareStatus.cancelledByPatient,
        BookingRequestStatus.cancelledByDoctor =>
          DoctorScheduledCareStatus.cancelledByDoctor,
        BookingRequestStatus.expired => DoctorScheduledCareStatus.expired,
      };
    }
    return switch (appointmentStatus!) {
      ScheduledAppointmentStatus.confirmed =>
        DoctorScheduledCareStatus.confirmed,
      ScheduledAppointmentStatus.inProgress =>
        DoctorScheduledCareStatus.inProgress,
      ScheduledAppointmentStatus.cancelled =>
        DoctorScheduledCareStatus.cancelled,
      ScheduledAppointmentStatus.completed =>
        DoctorScheduledCareStatus.completed,
      ScheduledAppointmentStatus.noShow => DoctorScheduledCareStatus.noShow,
    };
  }

  bool can(ScheduledCareAction action) => availableActions.contains(action);

  factory DoctorScheduledCareItem.fromAgendaJson(Map<String, dynamic> json) {
    final type = ScheduledCareResourceType.parse(json['resourceType']);
    final status = _requiredString(json, 'status');
    final requestId = _optionalString(json, 'requestId');
    final appointmentId = _optionalString(json, 'appointmentId');
    if (type == ScheduledCareResourceType.bookingRequest &&
        (requestId == null || appointmentId != null)) {
      throw const FormatException('Invalid booking-request agenda identity.');
    }
    if (type == ScheduledCareResourceType.appointment &&
        appointmentId == null) {
      throw const FormatException('Invalid appointment agenda identity.');
    }
    final cabinet = DoctorScheduledCareCabinet.fromJson(
      _requiredMap(json, 'cabinet'),
    );
    return DoctorScheduledCareItem(
      resourceType: type,
      requestId: requestId,
      appointmentId: appointmentId,
      sourceBookingRequestId: _optionalString(json, 'sourceBookingRequestId'),
      version: _requiredInt(json, 'version'),
      bookingRequestStatus: type == ScheduledCareResourceType.bookingRequest
          ? BookingRequestStatus.parse(status)
          : null,
      appointmentStatus: type == ScheduledCareResourceType.appointment
          ? ScheduledAppointmentStatus.parse(status)
          : null,
      subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
      cabinet: cabinet,
      activeSlot: ScheduledCareSlot(
        start: _requiredInstant(json, 'start'),
        end: _requiredInstant(json, 'end'),
        timezone: cabinet.timezone,
      ),
      responseDeadline: _optionalInstant(json, 'responseDeadline'),
      cancellation: _optionalMap(json, 'cancellation') == null
          ? null
          : ScheduledCareCancellation.fromJson(
              _optionalMap(json, 'cancellation')!,
            ),
      intakeStatus: _optionalString(json, 'intakeStatus'),
      availableActions: _actions(json),
      sortAt: _requiredInstant(json, 'sortAt'),
      updatedAt: _requiredInstant(json, 'updatedAt'),
    );
  }

  factory DoctorScheduledCareItem.fromRequest(DoctorBookingRequest request) =>
      DoctorScheduledCareItem(
        resourceType: ScheduledCareResourceType.bookingRequest,
        requestId: request.requestId,
        version: request.version,
        bookingRequestStatus: request.status,
        subject: request.subject,
        cabinet: request.cabinet,
        activeSlot: request.activeSlot,
        originalRequestedSlot: request.originalRequestedSlot,
        proposedSlot: request.proposedSlot,
        responseDeadline: request.responseDeadline,
        patientResponseDeadline: request.patientResponseDeadline,
        cancellation: request.cancellation,
        expiredAt: request.expiredAt,
        expiryReason: request.expiryReason,
        availableActions: request.availableActions,
        sortAt: request.activeSlot.start,
        updatedAt: request.updatedAt,
      );

  factory DoctorScheduledCareItem.fromAppointment(
    ConfirmedScheduledAppointment appointment,
  ) => DoctorScheduledCareItem(
    resourceType: ScheduledCareResourceType.appointment,
    appointmentId: appointment.appointmentId,
    sourceBookingRequestId: appointment.sourceBookingRequestId,
    version: appointment.version,
    appointmentStatus: ScheduledAppointmentStatus.parse(appointment.status),
    subject: appointment.subject,
    cabinet: DoctorScheduledCareCabinet(
      practiceLocationId: appointment.cabinet.practiceLocationId,
      name: appointment.cabinet.name,
      address: appointment.cabinet.address,
      city: appointment.cabinet.city,
      governorate: appointment.cabinet.governorate,
      timezone: appointment.cabinet.timezone,
    ),
    activeSlot: appointment.slot,
    cancellation: appointment.cancellation,
    confirmedAt: appointment.confirmedAt,
    intakeStatus: appointment.intakeStatus,
    availableActions: appointment.availableActions
        .map(ScheduledCareAction.parse)
        .toSet(),
    sortAt: appointment.slot.start,
    updatedAt: appointment.updatedAt,
  );
}

class DoctorBookingRequest {
  const DoctorBookingRequest({
    required this.requestId,
    required this.version,
    required this.status,
    required this.subject,
    required this.cabinet,
    required this.originalRequestedSlot,
    required this.activeSlot,
    required this.createdAt,
    required this.responseDeadline,
    required this.availableActions,
    required this.updatedAt,
    this.proposedSlot,
    this.patientResponseDeadline,
    this.confirmedAppointmentId,
    this.cancellation,
    this.expiredAt,
    this.expiryReason,
  });

  final String requestId;
  final int version;
  final BookingRequestStatus status;
  final CareSubject subject;
  final DoctorScheduledCareCabinet cabinet;
  final ScheduledCareSlot originalRequestedSlot;
  final ProposedSlot? proposedSlot;
  final ScheduledCareSlot activeSlot;
  final DateTime createdAt;
  final DateTime responseDeadline;
  final DateTime? patientResponseDeadline;
  final String? confirmedAppointmentId;
  final ScheduledCareCancellation? cancellation;
  final DateTime? expiredAt;
  final String? expiryReason;
  final Set<ScheduledCareAction> availableActions;
  final DateTime updatedAt;

  bool can(ScheduledCareAction action) => availableActions.contains(action);

  factory DoctorBookingRequest.fromJson(
    Map<String, dynamic> json,
  ) => DoctorBookingRequest(
    requestId: _requiredString(json, 'requestId'),
    version: _requiredInt(json, 'version'),
    status: BookingRequestStatus.parse(json['status']),
    subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
    cabinet: DoctorScheduledCareCabinet.fromJson(_requiredMap(json, 'cabinet')),
    originalRequestedSlot: ScheduledCareSlot.fromJson(
      _requiredMap(json, 'originalRequestedSlot'),
    ),
    proposedSlot: _optionalMap(json, 'proposedSlot') == null
        ? null
        : ProposedSlot.fromJson(_optionalMap(json, 'proposedSlot')!),
    activeSlot: ScheduledCareSlot.fromJson(_requiredMap(json, 'activeSlot')),
    createdAt: _requiredInstant(json, 'createdAt'),
    responseDeadline: _requiredInstant(json, 'responseDeadline'),
    patientResponseDeadline: _optionalInstant(json, 'patientResponseDeadline'),
    confirmedAppointmentId: _optionalString(json, 'confirmedAppointmentId'),
    cancellation: _optionalMap(json, 'cancellation') == null
        ? null
        : ScheduledCareCancellation.fromJson(
            _optionalMap(json, 'cancellation')!,
          ),
    expiredAt: _optionalInstant(json, 'expiredAt'),
    expiryReason: _optionalString(json, 'expiryReason'),
    availableActions: _actions(json),
    updatedAt: _requiredInstant(json, 'updatedAt'),
  );
}

class DoctorBookingAcceptance {
  const DoctorBookingAcceptance({
    required this.request,
    required this.appointment,
  });

  final DoctorBookingRequest request;
  final ConfirmedScheduledAppointment appointment;

  factory DoctorBookingAcceptance.fromJson(Map<String, dynamic> json) =>
      DoctorBookingAcceptance(
        request: DoctorBookingRequest.fromJson(_requiredMap(json, 'request')),
        appointment: ConfirmedScheduledAppointment.fromJson(
          _requiredMap(json, 'appointment'),
        ),
      );
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
  final DoctorScheduledCareItem? nextPendingRequest;
  final DoctorScheduledCareItem? nextConfirmedAppointment;

  factory DoctorHomeSummary.fromJson(Map<String, dynamic> json) =>
      DoctorHomeSummary(
        generatedAt: _requiredInstant(json, 'generatedAt'),
        pendingRequestCount: _requiredInt(json, 'pendingRequestCount'),
        nextPendingRequest: _optionalMap(json, 'nextPendingRequest') == null
            ? null
            : DoctorScheduledCareItem.fromAgendaJson(
                _optionalMap(json, 'nextPendingRequest')!,
              ),
        nextConfirmedAppointment:
            _optionalMap(json, 'nextConfirmedAppointment') == null
            ? null
            : DoctorScheduledCareItem.fromAgendaJson(
                _optionalMap(json, 'nextConfirmedAppointment')!,
              ),
      );
}

class DoctorScheduledCareAgenda {
  const DoctorScheduledCareAgenda({
    required this.generatedAt,
    required this.from,
    required this.to,
    required this.items,
  });

  final DateTime generatedAt;
  final DateTime from;
  final DateTime to;
  final List<DoctorScheduledCareItem> items;

  factory DoctorScheduledCareAgenda.fromJson(Map<String, dynamic> json) =>
      DoctorScheduledCareAgenda(
        generatedAt: _requiredInstant(json, 'generatedAt'),
        from: _requiredInstant(json, 'from'),
        to: _requiredInstant(json, 'to'),
        items: _mapList(json, 'items', DoctorScheduledCareItem.fromAgendaJson),
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Missing or invalid $key.');
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key must be an RFC 3339 UTC instant.');
  }
  return parsed;
}

DateTime? _optionalInstant(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _requiredInstant(json, key);

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing or invalid $key.');
  return value.cast<String, dynamic>();
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('Invalid $key.');
  return value.cast<String, dynamic>();
}

List<T> _mapList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) throw FormatException('Missing or invalid $key.');
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map) throw FormatException('Invalid $key entry.');
      return parse(item.cast<String, dynamic>());
    }),
  );
}

Set<ScheduledCareAction> _actions(Map<String, dynamic> json) {
  final value = json['availableActions'];
  if (value is! List) {
    throw const FormatException('Missing or invalid availableActions.');
  }
  return Set.unmodifiable(value.map(ScheduledCareAction.parse));
}
