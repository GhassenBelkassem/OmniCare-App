import 'scheduled_care_models.dart';

enum PatientScheduledCareBucket {
  upcoming('UPCOMING'),
  past('PAST'),
  cancelled('CANCELLED');

  const PatientScheduledCareBucket(this.wireValue);
  final String wireValue;
}

enum ScheduledCareResourceType {
  bookingRequest('BOOKING_REQUEST'),
  appointment('APPOINTMENT');

  const ScheduledCareResourceType(this.wireValue);
  final String wireValue;

  static ScheduledCareResourceType parse(String? value) => switch (value) {
    'BOOKING_REQUEST' => ScheduledCareResourceType.bookingRequest,
    'APPOINTMENT' => ScheduledCareResourceType.appointment,
    _ => throw const ScheduledCareContractException(
      'Unknown scheduled-care resource type.',
    ),
  };
}

sealed class ScheduledCareResourceIdentity {
  const ScheduledCareResourceIdentity();

  String get value;
  String get key;
}

class BookingRequestResourceIdentity extends ScheduledCareResourceIdentity {
  const BookingRequestResourceIdentity(this.requestId);

  final String requestId;

  @override
  String get value => requestId;

  @override
  String get key => 'BOOKING_REQUEST:$requestId';
}

class AppointmentResourceIdentity extends ScheduledCareResourceIdentity {
  const AppointmentResourceIdentity(this.appointmentId);

  final String appointmentId;

  @override
  String get value => appointmentId;

  @override
  String get key => 'APPOINTMENT:$appointmentId';
}

class ScheduledCareDoctorSummary {
  const ScheduledCareDoctorSummary({required this.displayName, this.specialty});

  final String displayName;
  final String? specialty;

  factory ScheduledCareDoctorSummary.fromJson(Map<String, dynamic> json) =>
      ScheduledCareDoctorSummary(
        displayName: _requiredString(json, 'displayName'),
        specialty: _optionalString(json['specialty']),
      );
}

class ScheduledCareSubjectSummary {
  const ScheduledCareSubjectSummary({
    required this.subjectType,
    required this.displayName,
    this.relationship,
  });

  final CareSubjectType subjectType;
  final String displayName;
  final String? relationship;

  factory ScheduledCareSubjectSummary.fromJson(Map<String, dynamic> json) =>
      ScheduledCareSubjectSummary(
        subjectType: CareSubjectType.parse(
          _requiredString(json, 'subjectType'),
        ),
        displayName: _requiredString(json, 'displayName'),
        relationship: _optionalString(json['relationship']),
      );
}

class ScheduledCareCabinetSummary {
  const ScheduledCareCabinetSummary({
    required this.name,
    required this.address,
    required this.city,
    required this.governorate,
    required this.timezone,
  });

  final String name;
  final String address;
  final String city;
  final String governorate;
  final String timezone;

  factory ScheduledCareCabinetSummary.fromJson(Map<String, dynamic> json) =>
      ScheduledCareCabinetSummary(
        name: _requiredString(json, 'name'),
        address: _requiredString(json, 'address'),
        city: _requiredString(json, 'city'),
        governorate: _requiredString(json, 'governorate'),
        timezone: _requiredString(json, 'timezone'),
      );
}

class ScheduledCareCancellationSummary {
  const ScheduledCareCancellationSummary({
    required this.actor,
    this.reasonCode,
    required this.cancelledAt,
    this.lateCancellation,
  });

  final String actor;
  final String? reasonCode;
  final DateTime cancelledAt;
  final bool? lateCancellation;

  factory ScheduledCareCancellationSummary.fromJson(
    Map<String, dynamic> json,
  ) => ScheduledCareCancellationSummary(
    actor: _requiredString(json, 'actor'),
    reasonCode: _optionalString(json['reasonCode']),
    cancelledAt: _requiredInstant(json, 'cancelledAt'),
    lateCancellation: _optionalBool(json['lateCancellation']),
  );
}

class PatientScheduledCareItem {
  const PatientScheduledCareItem._({
    required this.resourceType,
    required this.identity,
    this.sourceBookingRequestId,
    required this.version,
    required this.status,
    required this.doctor,
    required this.subject,
    required this.cabinet,
    required this.start,
    required this.end,
    required this.timezone,
    this.responseDeadline,
    this.cancellation,
    this.intakeStatus,
    required this.availableActions,
    required this.sortAt,
    required this.updatedAt,
  });

  final ScheduledCareResourceType resourceType;
  final ScheduledCareResourceIdentity identity;
  final String? sourceBookingRequestId;
  final int version;
  final String status;
  final ScheduledCareDoctorSummary doctor;
  final ScheduledCareSubjectSummary subject;
  final ScheduledCareCabinetSummary cabinet;
  final DateTime start;
  final DateTime end;
  final String timezone;
  final DateTime? responseDeadline;
  final ScheduledCareCancellationSummary? cancellation;
  final String? intakeStatus;
  final List<String> availableActions;
  final DateTime sortAt;
  final DateTime updatedAt;

  String? get requestId => switch (identity) {
    BookingRequestResourceIdentity(:final requestId) => requestId,
    AppointmentResourceIdentity() => null,
  };

  String? get appointmentId => switch (identity) {
    AppointmentResourceIdentity(:final appointmentId) => appointmentId,
    BookingRequestResourceIdentity() => null,
  };

  String get identityKey => identity.key;

  factory PatientScheduledCareItem.fromJson(Map<String, dynamic> json) {
    final resourceType = ScheduledCareResourceType.parse(
      _requiredString(json, 'resourceType'),
    );
    final requestId = _optionalString(json['requestId']);
    final appointmentId = _optionalString(json['appointmentId']);
    final identity = switch (resourceType) {
      ScheduledCareResourceType.bookingRequest
          when requestId != null && appointmentId == null =>
        BookingRequestResourceIdentity(requestId),
      ScheduledCareResourceType.appointment
          when appointmentId != null && requestId == null =>
        AppointmentResourceIdentity(appointmentId),
      _ => throw const ScheduledCareContractException(
        'Scheduled-care resource identity does not match its discriminator.',
      ),
    };
    final start = _requiredInstant(json, 'start');
    final end = _requiredInstant(json, 'end');
    if (!start.isBefore(end)) {
      throw const ScheduledCareContractException(
        'Invalid scheduled-care interval.',
      );
    }
    final cancellation = _optionalMap(json['cancellation']);
    return PatientScheduledCareItem._(
      resourceType: resourceType,
      identity: identity,
      sourceBookingRequestId: _optionalString(json['sourceBookingRequestId']),
      version: _requiredInt(json, 'version'),
      status: _requiredString(json, 'status'),
      doctor: ScheduledCareDoctorSummary.fromJson(_requiredMap(json, 'doctor')),
      subject: ScheduledCareSubjectSummary.fromJson(
        _requiredMap(json, 'subject'),
      ),
      cabinet: ScheduledCareCabinetSummary.fromJson(
        _requiredMap(json, 'cabinet'),
      ),
      start: start,
      end: end,
      timezone: _requiredString(json, 'timezone'),
      responseDeadline: _optionalInstant(json['responseDeadline']),
      cancellation: cancellation == null
          ? null
          : ScheduledCareCancellationSummary.fromJson(cancellation),
      intakeStatus: _optionalString(json['intakeStatus']),
      availableActions: _requiredList(json, 'availableActions')
          .map((value) => value?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      sortAt: _requiredInstant(json, 'sortAt'),
      updatedAt: _requiredInstant(json, 'updatedAt'),
    );
  }
}

class PatientScheduledCarePage {
  const PatientScheduledCarePage({required this.items, this.nextCursor});

  final List<PatientScheduledCareItem> items;
  final String? nextCursor;

  factory PatientScheduledCarePage.fromJson(Map<String, dynamic> json) {
    final rawItems = _requiredList(json, 'items');
    return PatientScheduledCarePage(
      items: rawItems
          .map((value) {
            if (value is! Map) {
              throw const ScheduledCareContractException(
                'Expected a scheduled-care item object.',
              );
            }
            return PatientScheduledCareItem.fromJson(
              value.cast<String, dynamic>(),
            );
          })
          .toList(growable: false),
      nextCursor: _optionalString(json['nextCursor']),
    );
  }
}

class PatientScheduledCareFilters {
  const PatientScheduledCareFilters({
    this.from,
    this.to,
    this.subjectType,
    this.familyMemberId,
    this.city,
  });

  static const none = PatientScheduledCareFilters();

  final DateTime? from;
  final DateTime? to;
  final CareSubjectType? subjectType;
  final String? familyMemberId;
  final String? city;

  bool get isActive =>
      from != null ||
      to != null ||
      subjectType != null ||
      familyMemberId != null ||
      city != null;

  int get activeCount =>
      (from != null || to != null ? 1 : 0) +
      (subjectType != null || familyMemberId != null ? 1 : 0) +
      (city != null ? 1 : 0);

  PatientScheduledCareFilters copyWith({
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    CareSubjectType? subjectType,
    bool clearSubject = false,
    String? familyMemberId,
    String? city,
    bool clearCity = false,
  }) => PatientScheduledCareFilters(
    from: clearRange ? null : from ?? this.from,
    to: clearRange ? null : to ?? this.to,
    subjectType: clearSubject ? null : subjectType ?? this.subjectType,
    familyMemberId: clearSubject ? null : familyMemberId ?? this.familyMemberId,
    city: clearCity ? null : city ?? this.city,
  );
}

class PatientScheduledCareQuery {
  const PatientScheduledCareQuery({
    required this.bucket,
    this.cursor,
    this.limit = 20,
    this.query,
    this.filters = PatientScheduledCareFilters.none,
  });

  final PatientScheduledCareBucket bucket;
  final String? cursor;
  final int limit;
  final String? query;
  final PatientScheduledCareFilters filters;

  Map<String, dynamic> toQueryParameters() => {
    'bucket': bucket.wireValue,
    'limit': limit,
    'cursor': ?cursor,
    'query': ?_nonBlank(query),
    'from': ?filters.from?.toUtc().toIso8601String(),
    'to': ?filters.to?.toUtc().toIso8601String(),
    'subjectType': ?filters.subjectType?.wireValue,
    'familyMemberId': ?filters.familyMemberId,
    'city': ?_nonBlank(filters.city),
  };
}

enum AppointmentCancellationReason {
  changeOfPlans('CHANGE_OF_PLANS'),
  noLongerNeeded('NO_LONGER_NEEDED');

  const AppointmentCancellationReason(this.wireValue);
  final String wireValue;
}

class CancelScheduledAppointmentCommand {
  const CancelScheduledAppointmentCommand({
    required this.appointmentId,
    required this.expectedVersion,
    required this.idempotencyKey,
    this.reason,
  });

  final String appointmentId;
  final int expectedVersion;
  final String idempotencyKey;
  final AppointmentCancellationReason? reason;

  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'reasonCode': reason?.wireValue,
  };
}

class AppointmentMutationResult {
  const AppointmentMutationResult({
    required this.appointment,
    required this.intentCompleted,
  });

  final ConfirmedScheduledAppointment appointment;
  final bool intentCompleted;
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

bool? _optionalBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw const ScheduledCareContractException('Expected a boolean.');
}

String? _nonBlank(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
