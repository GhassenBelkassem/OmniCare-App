import 'package:flutter/foundation.dart';

import '../data/patient_appointment_models.dart';
import '../data/patient_appointment_mock_data.dart';

class PatientAppointmentsController extends ChangeNotifier {
  PatientAppointmentsController({List<PatientAppointment>? appointments})
    : _appointments = List.unmodifiable(
        appointments ?? createPatientAppointmentMocks(),
      );

  List<PatientAppointment> _appointments;
  PatientAppointmentTab _tab = PatientAppointmentTab.upcoming;
  PatientAppointmentFilters _filters = PatientAppointmentFilters.none;
  String _query = '';

  List<PatientAppointment> get appointments => _appointments;
  PatientAppointmentTab get tab => _tab;
  PatientAppointmentFilters get filters => _filters;
  String get query => _query;

  PatientAppointment? byId(String id) {
    for (final appointment in _appointments) {
      if (appointment.appointmentId == id) return appointment;
    }
    return null;
  }

  void setTab(PatientAppointmentTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void setQuery(String value) {
    final next = value.trimLeft();
    if (_query == next) return;
    _query = next;
    notifyListeners();
  }

  void setFilters(PatientAppointmentFilters filters) {
    _filters = filters;
    notifyListeners();
  }

  void resetFilters() {
    if (!_filters.isActive) return;
    _filters = PatientAppointmentFilters.none;
    notifyListeners();
  }

  /// Replaces the currently loaded page. A future paginated source can call
  /// this for the first page and append pages without changing the UI API.
  void replaceAppointments(Iterable<PatientAppointment> appointments) {
    _appointments = List.unmodifiable(appointments);
    notifyListeners();
  }

  /// Appends a future page while keeping the static controller independent of
  /// networking and persistence.
  void appendAppointments(Iterable<PatientAppointment> appointments) {
    _appointments = List.unmodifiable([..._appointments, ...appointments]);
    notifyListeners();
  }

  void cancelAppointment(String id) {
    _appointments = List.unmodifiable(
      _appointments.map(
        (appointment) => appointment.appointmentId == id
            ? appointment.copyWith(
                status: PatientAppointmentStatus.cancelled,
                canCancel: false,
              )
            : appointment,
      ),
    );
    notifyListeners();
  }

  List<PatientAppointment> visibleAppointments({DateTime? now}) {
    final current = now ?? DateTime.now();
    final query = _query.trim().toLowerCase();
    final result = _appointments.where((appointment) {
      if (!_matchesTab(appointment, current)) return false;
      if (!_matchesFilters(appointment, current)) return false;
      if (query.isEmpty) return true;
      final searchable = [
        appointment.providerDisplayName,
        appointment.providerSubtitle,
        appointment.locationName,
        appointment.address,
        appointment.city,
        appointment.subjectDisplayName,
        appointment.consultationType,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    result.sort((a, b) {
      final comparison = a.startAt.compareTo(b.startAt);
      return _tab == PatientAppointmentTab.upcoming ? comparison : -comparison;
    });
    return List.unmodifiable(result);
  }

  bool _matchesTab(PatientAppointment appointment, DateTime now) {
    return switch (_tab) {
      PatientAppointmentTab.upcoming =>
        appointment.status == PatientAppointmentStatus.confirmed &&
            appointment.startAt.isAfter(now),
      PatientAppointmentTab.past =>
        appointment.status == PatientAppointmentStatus.completed,
      PatientAppointmentTab.cancelled =>
        appointment.status == PatientAppointmentStatus.cancelled,
    };
  }

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
    switch (filters.dateFilter) {
      case PatientAppointmentDateFilter.all:
        return true;
      case PatientAppointmentDateFilter.thisWeek:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 7));
        return !date.isBefore(start) && date.isBefore(end);
      case PatientAppointmentDateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case PatientAppointmentDateFilter.thisYear:
        return date.year == now.year;
      case PatientAppointmentDateFilter.custom:
        final start = filters.customStart;
        final end = filters.customEnd;
        if (start == null || end == null) return true;
        final inclusiveEnd = DateTime(end.year, end.month, end.day + 1);
        return !date.isBefore(start) && date.isBefore(inclusiveEnd);
    }
  }
}
