import 'dart:convert';

enum ScheduledCareEventType {
  bookingRequestCreated,
  bookingRequestTimeProposed,
  bookingRequestFulfilled,
  bookingRequestCancelled,
  bookingRequestExpired,
  appointmentCreated,
  appointmentCancelled,
  consultationActivated,
  consultationUpdated,
  clinicalAccessChanged,
  unknown,
}

enum ScheduledCareResourceType {
  bookingRequest,
  appointment,
  consultation,
  clinicalOrder,
  prescription,
  artifact,
}

class ScheduledCareInvalidationEvent {
  const ScheduledCareInvalidationEvent({
    required this.eventId,
    required this.type,
    required this.rawEventType,
    required this.resourceType,
    required this.resourceId,
    required this.version,
    required this.occurredAt,
  });

  final String eventId;
  final ScheduledCareEventType type;
  final String rawEventType;
  final ScheduledCareResourceType resourceType;
  final String resourceId;
  final int version;
  final DateTime occurredAt;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _instantZone = RegExp(r'(?:[zZ]|[+-]\d{2}:\d{2})$');

  static ScheduledCareInvalidationEvent? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final json = decoded.cast<String, dynamic>();
      final eventId = json['eventId'];
      final rawType = json['eventType'];
      final rawResource = json['resourceType'];
      final resourceId = json['resourceId'];
      final version = json['version'];
      final occurredAtRaw = json['occurredAt'];
      if (eventId is! String ||
          !_uuid.hasMatch(eventId) ||
          rawType is! String ||
          rawType.trim().isEmpty ||
          resourceId is! String ||
          !_uuid.hasMatch(resourceId) ||
          version is! int ||
          version < 0 ||
          occurredAtRaw is! String) {
        return null;
      }
      final occurredAt = DateTime.tryParse(occurredAtRaw);
      if (occurredAt == null || !_instantZone.hasMatch(occurredAtRaw)) {
        return null;
      }
      final resourceType = switch (rawResource) {
        'BOOKING_REQUEST' => ScheduledCareResourceType.bookingRequest,
        'APPOINTMENT' => ScheduledCareResourceType.appointment,
        'CONSULTATION' => ScheduledCareResourceType.consultation,
        'CLINICAL_ORDER' => ScheduledCareResourceType.clinicalOrder,
        'PRESCRIPTION' => ScheduledCareResourceType.prescription,
        'ARTIFACT' => ScheduledCareResourceType.artifact,
        _ => null,
      };
      if (resourceType == null) return null;
      return ScheduledCareInvalidationEvent(
        eventId: eventId.toLowerCase(),
        type: _eventType(rawType),
        rawEventType: rawType,
        resourceType: resourceType,
        resourceId: resourceId.toLowerCase(),
        version: version,
        occurredAt: occurredAt.toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  static ScheduledCareEventType _eventType(String value) => switch (value) {
    'BOOKING_REQUEST_CREATED' => ScheduledCareEventType.bookingRequestCreated,
    'BOOKING_REQUEST_TIME_PROPOSED' =>
      ScheduledCareEventType.bookingRequestTimeProposed,
    'BOOKING_REQUEST_FULFILLED' =>
      ScheduledCareEventType.bookingRequestFulfilled,
    'BOOKING_REQUEST_CANCELLED' =>
      ScheduledCareEventType.bookingRequestCancelled,
    'BOOKING_REQUEST_EXPIRED' => ScheduledCareEventType.bookingRequestExpired,
    'APPOINTMENT_CREATED' => ScheduledCareEventType.appointmentCreated,
    'APPOINTMENT_CANCELLED' => ScheduledCareEventType.appointmentCancelled,
    'CONSULTATION_ACTIVATED' => ScheduledCareEventType.consultationActivated,
    'CONSULTATION_UPDATED' => ScheduledCareEventType.consultationUpdated,
    'CLINICAL_ACCESS_CHANGED' => ScheduledCareEventType.clinicalAccessChanged,
    _ => ScheduledCareEventType.unknown,
  };
}
