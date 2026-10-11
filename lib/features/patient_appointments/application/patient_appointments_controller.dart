import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../scheduled_care/application/scheduled_care_controller.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import '../../scheduled_care_prototype/scheduled_care_controller.dart';
import '../../scheduled_care_prototype/scheduled_care_models.dart';
import '../data/patient_appointment_mock_data.dart';
import '../data/patient_appointment_models.dart';

class PatientAppointmentsController extends ChangeNotifier {
  PatientAppointmentsController({
    List<PatientAppointment>? appointments,
    ScheduledCareController? scheduledCareController,
    Object? prototypeController,
  }) : _scheduledCare = scheduledCareController,
       _prototype = prototypeController is ScheduledCarePrototypeController
           ? prototypeController
           : null,
       _appointments = List.unmodifiable(
         appointments ??
             (scheduledCareController == null
                 ? createPatientAppointmentMocks()
                 : const <PatientAppointment>[]),
       ) {
    _scheduledCare?.addListener(_syncScheduledCare);
    _prototype?.addListener(_syncScheduledCare);
    _syncScheduledCare(notify: false);
  }

  final ScheduledCareController? _scheduledCare;
  final ScheduledCarePrototypeController? _prototype;
  List<PatientAppointment> _appointments;
  PatientAppointmentTab _tab = PatientAppointmentTab.upcoming;
  PatientAppointmentFilters _filters = PatientAppointmentFilters.none;
  String _query = '';
  Timer? _searchDebounce;

  List<PatientAppointment> get appointments => _appointments;
  PatientAppointmentTab get tab => _tab;
  PatientAppointmentFilters get filters => _filters;
  String get query => _query;
  bool get isLoading => _scheduledCare?.isLoadingList ?? false;
  bool get canLoadMore => _scheduledCare?.canLoadMore ?? false;

  PatientAppointment? byId(String id) {
    for (final appointment in _appointments) {
      if (appointment.resourceId == id) return appointment;
    }
    return null;
  }

  Future<void> load() async {
    final scheduled = _scheduledCare;
    if (scheduled == null) return;
    await scheduled.connectRealtime();
    await scheduled.loadList(_criteria());
  }

  Future<void> loadMore() async {
    final scheduled = _scheduledCare;
    if (scheduled == null || !scheduled.canLoadMore) return;
    await scheduled.loadList(_criteria(), append: true);
  }

  void setTab(PatientAppointmentTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
    unawaited(load());
  }

  void setQuery(String value) {
    final next = value.trimLeft();
    if (_query == next) return;
    _query = next;
    notifyListeners();
    if (_scheduledCare == null) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), load);
  }

  void setFilters(PatientAppointmentFilters filters) {
    _filters = filters;
    notifyListeners();
    unawaited(load());
  }

  void resetFilters() {
    if (!_filters.isActive && _query.isEmpty) return;
    _filters = PatientAppointmentFilters.none;
    _query = '';
    notifyListeners();
    unawaited(load());
  }

  // Retained for isolated widget fixtures. Production instances are populated
  // only by ScheduledCareController REST pages.
  void replaceAppointments(Iterable<PatientAppointment> appointments) {
    if (_scheduledCare != null) return;
    _appointments = List.unmodifiable(appointments);
    notifyListeners();
  }

  void appendAppointments(Iterable<PatientAppointment> appointments) {
    if (_scheduledCare != null) return;
    _appointments = List.unmodifiable([..._appointments, ...appointments]);
    notifyListeners();
  }

  Future<bool> cancelAppointment(String id, {String? reason}) async {
    final scheduled = _scheduledCare;
    final resource = byId(id);
    if (resource == null) return false;
    final prototype = _prototype;
    if (prototype?.byId(id) != null) {
      prototype!.cancelByPatient(id, reason: reason);
      return true;
    }
    if (scheduled == null) {
      final now = DateTime.now();
      _appointments = List.unmodifiable(
        _appointments.map(
          (appointment) => appointment.resourceId == id
              ? appointment.copyWith(
                  status: PatientAppointmentStatus.cancelledByPatient,
                  canCancel: false,
                  cancelledAt: now,
                  cancellationReason: reason ?? 'Annulé par le patient',
                  lateCancellation:
                      appointment.startAt.difference(now) <
                      const Duration(hours: 24),
                )
              : appointment,
        ),
      );
      notifyListeners();
      return true;
    }
    if (resource.resourceType ==
        PatientAppointmentResourceType.bookingRequest) {
      await scheduled.loadRequest(resource.requestId!);
      final result = await scheduled.cancelRequest();
      await load();
      return result;
    }
    await scheduled.loadAppointment(resource.appointmentId!);
    final result = await scheduled.cancelAppointment();
    await load();
    return result;
  }

  Future<bool> acceptCounterproposal(String id) async {
    final scheduled = _scheduledCare;
    final resource = byId(id);
    if (_prototype?.byId(id) != null) {
      _prototype!.acceptProposalByPatient(id);
      return true;
    }
    if (scheduled == null || resource?.requestId == null) return false;
    await scheduled.loadRequest(resource!.requestId!);
    final result = await scheduled.acceptProposal();
    await load();
    return result;
  }

  Future<bool> declineCounterproposal(String id) async {
    final scheduled = _scheduledCare;
    final resource = byId(id);
    if (_prototype?.byId(id) != null) {
      _prototype!.declineProposalByPatient(id);
      return true;
    }
    if (scheduled == null || resource?.requestId == null) return false;
    await scheduled.loadRequest(resource!.requestId!);
    final result = await scheduled.declineProposal();
    await load();
    return result;
  }

  Future<void> loadDetail(PatientAppointment appointment) async {
    final scheduled = _scheduledCare;
    if (scheduled == null) return;
    if (appointment.resourceType ==
        PatientAppointmentResourceType.bookingRequest) {
      await scheduled.loadRequest(appointment.requestId!);
    } else {
      await scheduled.loadAppointment(appointment.appointmentId!);
    }
  }

  List<PatientAppointment> visibleAppointments({DateTime? now}) {
    // The backend has already applied bucket, query, subject, date and city.
    // Fixture-only controllers preserve the old local behavior for tests.
    if (_scheduledCare != null) {
      if (_filters.providerType == PatientAppointmentProviderType.clinic) {
        return const [];
      }
      return List.unmodifiable(_appointments);
    }
    final current = now ?? DateTime.now();
    final query = _query.trim().toLowerCase();
    final result = _appointments.where((appointment) {
      if (!_matchesTab(appointment, current)) return false;
      if (!_matchesFilters(appointment, current)) return false;
      if (query.isEmpty) return true;
      return [
        appointment.providerDisplayName,
        appointment.providerSubtitle,
        appointment.locationName,
        appointment.address,
        appointment.city,
        appointment.subjectDisplayName,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
    return List.unmodifiable(result);
  }

  bool _matchesTab(PatientAppointment appointment, DateTime now) =>
      switch (_tab) {
        PatientAppointmentTab.upcoming =>
          appointment.status == PatientAppointmentStatus.pendingDoctor ||
              appointment.status ==
                  PatientAppointmentStatus.pendingPatientTimeConfirmation ||
              appointment.status == PatientAppointmentStatus.confirmed,
        PatientAppointmentTab.past =>
          appointment.status == PatientAppointmentStatus.completed,
        PatientAppointmentTab.cancelled =>
          appointment.status == PatientAppointmentStatus.cancelledByPatient ||
              appointment.status ==
                  PatientAppointmentStatus.cancelledByDoctor ||
              appointment.status == PatientAppointmentStatus.expired,
      };

  bool _matchesFilters(PatientAppointment appointment, DateTime now) {
    final filters = _filters;
    if (filters.providerType != null &&
        appointment.providerType != filters.providerType) {
      return false;
    }
    if (filters.subjectType != null &&
        appointment.subjectType != filters.subjectType) {
      return false;
    }
    if (filters.subjectDisplayName != null &&
        appointment.subjectDisplayName != filters.subjectDisplayName) {
      return false;
    }
    if (filters.city != null && appointment.city != filters.city) return false;
    final date = appointment.startAt;
    return switch (filters.dateFilter) {
      PatientAppointmentDateFilter.all => true,
      PatientAppointmentDateFilter.thisWeek =>
        !date.isBefore(DateTime(now.year, now.month, now.day)) &&
            date.isBefore(
              DateTime(
                now.year,
                now.month,
                now.day,
              ).add(const Duration(days: 7)),
            ),
      PatientAppointmentDateFilter.thisMonth =>
        date.year == now.year && date.month == now.month,
      PatientAppointmentDateFilter.thisYear => date.year == now.year,
      PatientAppointmentDateFilter.custom =>
        filters.customStart == null || filters.customEnd == null
            ? true
            : !date.isBefore(filters.customStart!) &&
                  date.isBefore(
                    DateTime(
                      filters.customEnd!.year,
                      filters.customEnd!.month,
                      filters.customEnd!.day + 1,
                    ),
                  ),
    };
  }

  ScheduledCareListCriteria _criteria() {
    DateTime? from;
    DateTime? to;
    final now = DateTime.now();
    switch (_filters.dateFilter) {
      case PatientAppointmentDateFilter.all:
        break;
      case PatientAppointmentDateFilter.thisWeek:
        from = DateTime(now.year, now.month, now.day);
        to = from.add(const Duration(days: 7));
      case PatientAppointmentDateFilter.thisMonth:
        from = DateTime(now.year, now.month);
        to = DateTime(now.year, now.month + 1);
      case PatientAppointmentDateFilter.thisYear:
        from = DateTime(now.year);
        to = DateTime(now.year + 1);
      case PatientAppointmentDateFilter.custom:
        from = _filters.customStart;
        final end = _filters.customEnd;
        to = end == null ? null : DateTime(end.year, end.month, end.day + 1);
    }
    return ScheduledCareListCriteria(
      bucket: switch (_tab) {
        PatientAppointmentTab.upcoming => ScheduledCareBucket.upcoming,
        PatientAppointmentTab.past => ScheduledCareBucket.past,
        PatientAppointmentTab.cancelled => ScheduledCareBucket.cancelled,
      },
      query: _query,
      from: from,
      to: to,
      subjectType: switch (_filters.subjectType) {
        PatientAppointmentSubjectType.self => CareSubjectType.self,
        PatientAppointmentSubjectType.familyMember =>
          CareSubjectType.familyMember,
        null => null,
      },
      familyMemberId: _filters.subjectFamilyMemberId,
      city: _filters.city,
    );
  }

  void _syncScheduledCare({bool notify = true}) {
    final scheduled = _scheduledCare;
    if (scheduled != null) {
      _appointments = List.unmodifiable(
        scheduled.items.map(_fromScheduledCare),
      );
    } else if (_prototype != null) {
      _appointments = List.unmodifiable(_prototype.records.map(_fromPrototype));
    } else {
      return;
    }
    if (notify) notifyListeners();
  }

  PatientAppointment _fromScheduledCare(ScheduledCareListItem item) {
    final status = switch (item.status) {
      'PENDING_DOCTOR' => PatientAppointmentStatus.pendingDoctor,
      'PENDING_PATIENT_TIME_CONFIRMATION' =>
        PatientAppointmentStatus.pendingPatientTimeConfirmation,
      'CONFIRMED' => PatientAppointmentStatus.confirmed,
      'COMPLETED' => PatientAppointmentStatus.completed,
      'CANCELLED_BY_PATIENT' ||
      'CANCELLED' => PatientAppointmentStatus.cancelledByPatient,
      'CANCELLED_BY_DOCTOR' => PatientAppointmentStatus.cancelledByDoctor,
      'EXPIRED' => PatientAppointmentStatus.expired,
      _ => PatientAppointmentStatus.expired,
    };
    return PatientAppointment(
      resourceType:
          item.resourceType == ScheduledCareResourceType.bookingRequest
          ? PatientAppointmentResourceType.bookingRequest
          : PatientAppointmentResourceType.appointment,
      requestId: item.requestId,
      appointmentId: item.appointmentId,
      sourceBookingRequestId: item.sourceBookingRequestId,
      version: item.version,
      availableActions: item.availableActions,
      timezone: item.timezone,
      providerType: PatientAppointmentProviderType.doctor,
      providerId: '',
      providerDisplayName: item.doctorName,
      providerSubtitle: item.doctorSpecialty,
      subjectType: item.subjectType == CareSubjectType.familyMember
          ? PatientAppointmentSubjectType.familyMember
          : PatientAppointmentSubjectType.self,
      subjectDisplayName: item.subjectDisplayName,
      startAt: displayInTimeZone(item.start, item.timezone),
      endAt: displayInTimeZone(item.end, item.timezone),
      status: status,
      locationName: item.cabinetName,
      address: item.address,
      city: item.city,
      consultationType: 'Consultation au Cabinet',
      appointmentReference: item.resourceId,
      responseDeadline: item.responseDeadline?.toLocal(),
      intakeStatus: item.intakeStatus == 'SUBMITTED'
          ? PatientAppointmentIntakeStatus.submitted
          : PatientAppointmentIntakeStatus.notSubmitted,
      cancelledAt: item.cancellation?.cancelledAt.toLocal(),
      cancellationReason: item.cancellation?.reasonCode,
      lateCancellation: item.cancellation?.lateCancellation ?? false,
      canCancel:
          item.availableActions.contains('CANCEL_REQUEST') ||
          item.availableActions.contains('CANCEL_APPOINTMENT'),
      // Confirmed rescheduling is intentionally absent from the P2 contract.
      canReschedule: false,
      canReportProblem: false,
    );
  }

  PatientAppointment _fromPrototype(ScheduledCareRecordPrototype record) {
    final status = switch (record.status) {
      ScheduledCareStatus.pendingDoctor =>
        PatientAppointmentStatus.pendingDoctor,
      ScheduledCareStatus.pendingPatientTimeConfirmation =>
        PatientAppointmentStatus.pendingPatientTimeConfirmation,
      ScheduledCareStatus.confirmed => PatientAppointmentStatus.confirmed,
      ScheduledCareStatus.expired => PatientAppointmentStatus.expired,
      ScheduledCareStatus.cancelledByPatient =>
        PatientAppointmentStatus.cancelledByPatient,
      ScheduledCareStatus.cancelledByDoctor =>
        PatientAppointmentStatus.cancelledByDoctor,
    };
    return PatientAppointment(
      requestId: record is BookingRequestPrototype ? record.id : null,
      appointmentId: record is AppointmentPrototype ? record.id : null,
      resourceType: record is BookingRequestPrototype
          ? PatientAppointmentResourceType.bookingRequest
          : PatientAppointmentResourceType.appointment,
      prototypeRecordId: record.id,
      requestedStartAt: record.requestedSlot.start,
      requestedEndAt: record.requestedSlot.end,
      responseDeadline: record.responseDeadline,
      patientResponseDeadline: record.patientResponseDeadline,
      providerType: PatientAppointmentProviderType.doctor,
      providerId: record.doctorId,
      providerDisplayName: record.doctorName,
      providerSubtitle: record.doctorSpecialty,
      subjectType:
          record.patient.type == ScheduledPatientSubjectType.familyMember
          ? PatientAppointmentSubjectType.familyMember
          : PatientAppointmentSubjectType.self,
      subjectDisplayName: record.patient.displayName,
      startAt: record.activeSlot.start,
      endAt: record.activeSlot.end,
      status: status,
      locationName: record.cabinet.name,
      address: record.cabinet.address,
      city: record.cabinet.city,
      consultationType: 'Consultation au Cabinet',
      appointmentReference: record.id,
      intakeStatus: record.intake.status == ScheduledIntakeStatus.submitted
          ? PatientAppointmentIntakeStatus.submitted
          : PatientAppointmentIntakeStatus.notSubmitted,
      cancelledAt: record.cancelledAt,
      cancellationReason: record.cancellationReason,
      lateCancellation: record.lateCancellation,
      canCancel:
          record.status == ScheduledCareStatus.pendingDoctor ||
          record.status == ScheduledCareStatus.pendingPatientTimeConfirmation ||
          record.status == ScheduledCareStatus.confirmed,
      canReschedule: false,
      canReportProblem: false,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scheduledCare?.removeListener(_syncScheduledCare);
    _prototype?.removeListener(_syncScheduledCare);
    super.dispose();
  }
}
