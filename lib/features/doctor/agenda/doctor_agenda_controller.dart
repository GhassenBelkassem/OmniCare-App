import 'package:flutter/material.dart';

import 'doctor_demo_appointment.dart';

enum DoctorAgendaView { month, day }

class DoctorAgendaController extends ChangeNotifier {
  DoctorAgendaController({List<DoctorDemoAppointment>? appointments})
    : _appointments = List.of(
        appointments ?? DoctorDemoAppointmentFixtures.initial,
      );

  final List<DoctorDemoAppointment> _appointments;
  DateTime _selectedDate = DateTime(2026, 9, 23);
  DateTime _focusedDate = DateTime(2026, 9, 23);
  DoctorAgendaView _view = DoctorAgendaView.month;

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  DoctorAgendaView get view => _view;
  List<DoctorDemoAppointment> get appointments =>
      List.unmodifiable(_appointments);

  List<DoctorDemoAppointment> appointmentsFor(DateTime date) =>
      _appointments
          .where((item) => DateUtils.isSameDay(item.dateTime, date))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  DoctorDemoAppointment? get nextAppointment {
    final candidates = _appointments.where(
      (item) =>
          item.status == DoctorAppointmentStatus.scheduled ||
          item.status == DoctorAppointmentStatus.arrived,
    );
    if (candidates.isEmpty) return null;
    final ordered = candidates.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return ordered.first;
  }

  void selectDate(DateTime date, {DateTime? focusedDate}) {
    _selectedDate = DateUtils.dateOnly(date);
    _focusedDate = DateUtils.dateOnly(focusedDate ?? date);
    notifyListeners();
  }

  void focusMonth(DateTime date) {
    _focusedDate = DateUtils.dateOnly(date);
    notifyListeners();
  }

  void setView(DoctorAgendaView view) {
    if (_view == view) return;
    _view = view;
    notifyListeners();
  }

  void changeDay(int delta) =>
      selectDate(_selectedDate.add(Duration(days: delta)));

  void markArrived(String id) {
    final index = _appointments.indexWhere((item) => item.id == id);
    if (index < 0 ||
        _appointments[index].status != DoctorAppointmentStatus.scheduled) {
      return;
    }
    _appointments[index] = _appointments[index].copyWith(
      status: DoctorAppointmentStatus.arrived,
    );
    notifyListeners();
  }
}
