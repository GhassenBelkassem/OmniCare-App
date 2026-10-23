import 'package:flutter/material.dart';

import '../domain/patient_scheduled_care_models.dart';
import 'confirmed_scheduled_appointment_screen.dart';
import 'pending_booking_request_screen.dart';

/// Typed resource navigation shared by history now and notification deep links
/// later. It never infers an identifier from localized display content.
class ScheduledCareResourceResolver {
  const ScheduledCareResourceResolver._();

  static Future<void> openItem(
    BuildContext context,
    PatientScheduledCareItem item,
  ) => switch (item.identity) {
    BookingRequestResourceIdentity(:final requestId) => openRequest(
      context,
      requestId,
    ),
    AppointmentResourceIdentity(:final appointmentId) => openAppointment(
      context,
      appointmentId,
    ),
  };

  static Future<void> openRequest(BuildContext context, String requestId) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PendingBookingRequestScreen(requestId: requestId),
      ),
    );
  }

  static Future<void> openAppointment(
    BuildContext context,
    String appointmentId,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ConfirmedScheduledAppointmentScreen(appointmentId: appointmentId),
      ),
    );
  }
}
