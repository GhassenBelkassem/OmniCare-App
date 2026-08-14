import 'package:flutter/material.dart';

import '../../request_core/domain/request_vocabulary.dart';

class RequestStatusCopy {
  const RequestStatusCopy(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
  static RequestStatusCopy of(PatientRequestStatus status) => switch (status) {
    PatientRequestStatus.requestReceived => const RequestStatusCopy(
      'Request received',
      'The clinic has received your request.',
      Icons.mark_email_read_outlined,
    ),
    PatientRequestStatus.underReview => const RequestStatusCopy(
      'Under review',
      'The clinic is reviewing your request.',
      Icons.hourglass_top_outlined,
    ),
    PatientRequestStatus.informationRequired => const RequestStatusCopy(
      'More information needed',
      'The clinic needs more information before continuing.',
      Icons.info_outline,
    ),
    PatientRequestStatus.schedulingInProgress => const RequestStatusCopy(
      'Scheduling',
      'The clinic is arranging the next step.',
      Icons.event_outlined,
    ),
    PatientRequestStatus.waitingForConfirmation => const RequestStatusCopy(
      'Waiting for confirmation',
      'The clinic is waiting for your confirmation.',
      Icons.pending_actions_outlined,
    ),
    PatientRequestStatus.confirmed => const RequestStatusCopy(
      'Confirmed',
      'Your request has been confirmed.',
      Icons.check_circle_outline,
    ),
    PatientRequestStatus.careInProgress => const RequestStatusCopy(
      'Care in progress',
      'Your care is currently in progress.',
      Icons.medical_services_outlined,
    ),
    PatientRequestStatus.completed => const RequestStatusCopy(
      'Completed',
      'This request has been completed.',
      Icons.task_alt_outlined,
    ),
    PatientRequestStatus.declined => const RequestStatusCopy(
      'Request declined',
      'The clinic could not proceed with this request.',
      Icons.cancel_outlined,
    ),
    PatientRequestStatus.cancelled => const RequestStatusCopy(
      'Cancelled',
      'This request has been cancelled.',
      Icons.do_not_disturb_on_outlined,
    ),
    PatientRequestStatus.unknown => const RequestStatusCopy(
      'Status updated',
      'Check back for the latest request update.',
      Icons.info_outline,
    ),
  };
}

String situationLabel(RequestSituation situation) => switch (situation) {
  RequestSituation.appointment => 'Appointment',
  RequestSituation.urgent => 'Urgent',
  RequestSituation.ambulance => 'Transport assistance',
  RequestSituation.unknown => 'Clinic request',
};
