import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
import '../auth/application/auth_controller.dart';
import '../auth/application/auth_role_family.dart';
import '../doctor/scheduled_care/doctor_scheduled_care_models.dart';
import '../doctor/scheduled_care/doctor_scheduled_care_repository.dart';
import '../scheduled_care/data/scheduled_care_repository.dart';
import '../scheduled_care/domain/scheduled_care_models.dart';
import '../scheduled_care_prototype/scheduled_request_status_screen.dart';
import 'data/notification_models.dart';

abstract final class NotificationNavigation {
  static Future<void> open(
    BuildContext context,
    InboxNotification notification,
  ) async {
    final reference = notification.reference;
    final id = reference.id;
    if (id == null || reference.type == NotificationReferenceType.none) return;
    final doctor =
        context.read<AuthController>().roleFamily == AuthRoleFamily.doctor;
    final Widget destination;
    if (doctor) {
      destination = _DoctorNotificationResourceScreen(reference: reference);
    } else if (reference.type == NotificationReferenceType.bookingRequest) {
      destination = ScheduledRequestStatusScreen(recordId: id);
    } else {
      destination = _PatientNotificationAppointmentScreen(appointmentId: id);
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destination));
  }
}

class _PatientNotificationAppointmentScreen extends StatelessWidget {
  const _PatientNotificationAppointmentScreen({required this.appointmentId});
  final String appointmentId;

  @override
  Widget build(BuildContext context) =>
      _ResourceLoader<ConfirmedScheduledAppointment>(
        title: 'Détails du rendez-vous',
        load: () => context.read<ScheduledCareRepository>().getAppointment(
          appointmentId,
        ),
        builder: (appointment) => _ResourceCard(
          heading: appointment.doctor.displayName,
          status: appointment.status,
          subject: appointment.subject.displayName,
          cabinet: appointment.cabinet.name,
          city: appointment.cabinet.city,
          start: appointment.slot.start,
          end: appointment.slot.end,
        ),
      );
}

class _DoctorNotificationResourceScreen extends StatelessWidget {
  const _DoctorNotificationResourceScreen({required this.reference});
  final NotificationReference reference;

  @override
  Widget build(BuildContext context) {
    final id = reference.id!;
    final repository = context.read<DoctorScheduledCareRepository>();
    if (reference.type == NotificationReferenceType.bookingRequest) {
      return _ResourceLoader<DoctorBookingRequest>(
        title: 'Demande de rendez-vous',
        load: () => repository.getRequest(id),
        builder: (request) => _ResourceCard(
          heading: request.subject.displayName,
          status: request.status.wireName,
          subject: request.subject.relationship,
          cabinet: request.cabinet.name,
          city: request.cabinet.city,
          start: request.activeSlot.start,
          end: request.activeSlot.end,
        ),
      );
    }
    return _ResourceLoader<ConfirmedScheduledAppointment>(
      title: 'Détails du rendez-vous',
      load: () => repository.getAppointment(id),
      builder: (appointment) => _ResourceCard(
        heading: appointment.subject.displayName,
        status: appointment.status,
        subject: appointment.subject.relationship,
        cabinet: appointment.cabinet.name,
        city: appointment.cabinet.city,
        start: appointment.slot.start,
        end: appointment.slot.end,
      ),
    );
  }
}

class _ResourceLoader<T> extends StatefulWidget {
  const _ResourceLoader({
    required this.title,
    required this.load,
    required this.builder,
  });
  final String title;
  final Future<T> Function() load;
  final Widget Function(T value) builder;

  @override
  State<_ResourceLoader<T>> createState() => _ResourceLoaderState<T>();
}

class _ResourceLoaderState<T> extends State<_ResourceLoader<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(OmniSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.link_off_rounded,
                    size: 44,
                    color: OmniColors.textSecondary,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  const Text(
                    'Cette ressource n’est plus disponible.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  TextButton(
                    onPressed: () => setState(() => _future = widget.load()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          child: widget.builder(snapshot.requireData),
        );
      },
    ),
  );
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.heading,
    required this.status,
    required this.subject,
    required this.cabinet,
    required this.city,
    required this.start,
    required this.end,
  });
  final String heading;
  final String status;
  final String subject;
  final String cabinet;
  final String city;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.lg),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: OmniSpacing.md),
        _line('Statut', status),
        _line('Patient', subject),
        _line('Cabinet', '$cabinet · $city'),
        _line(
          'Date',
          DateFormat('d MMMM yyyy', 'fr_FR').format(start.toLocal()),
        ),
        _line(
          'Heure',
          '${DateFormat('HH:mm').format(start.toLocal())}–${DateFormat('HH:mm').format(end.toLocal())}',
        ),
      ],
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(color: OmniColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
