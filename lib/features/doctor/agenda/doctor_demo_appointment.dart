enum DoctorAppointmentStatus {
  scheduled,
  arrived,
  inConsultation,
  completed,
  cancelled,
}

enum DoctorAppointmentLocationType { cabinet, homeVisit }

class DoctorDemoAppointment {
  const DoctorDemoAppointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.dateTime,
    required this.durationMinutes,
    required this.reason,
    required this.locationType,
    required this.locationName,
    required this.status,
  });

  final String id;
  final String patientId;
  final String patientName;
  final int patientAge;
  final DateTime dateTime;
  final int durationMinutes;
  final String reason;
  final DoctorAppointmentLocationType locationType;
  final String locationName;
  final DoctorAppointmentStatus status;

  DoctorDemoAppointment copyWith({DoctorAppointmentStatus? status}) =>
      DoctorDemoAppointment(
        id: id,
        patientId: patientId,
        patientName: patientName,
        patientAge: patientAge,
        dateTime: dateTime,
        durationMinutes: durationMinutes,
        reason: reason,
        locationType: locationType,
        locationName: locationName,
        status: status ?? this.status,
      );
}

abstract final class DoctorDemoAppointmentFixtures {
  static final initial = <DoctorDemoAppointment>[
    DoctorDemoAppointment(
      id: 'sami-0900',
      patientId: 'sami',
      patientName: 'Sami Ben Ali',
      patientAge: 38,
      dateTime: DateTime(2026, 9, 23, 9),
      durationMinutes: 30,
      reason: 'Consultation de suivi',
      locationType: DoctorAppointmentLocationType.cabinet,
      locationName: 'Cabinet Lac 2',
      status: DoctorAppointmentStatus.completed,
    ),
    DoctorDemoAppointment(
      id: 'mohamed-1030',
      patientId: 'mohamed',
      patientName: 'Mohamed Trabelsi',
      patientAge: 45,
      dateTime: DateTime(2026, 9, 23, 10, 30),
      durationMinutes: 30,
      reason: 'Contrôle hypertension',
      locationType: DoctorAppointmentLocationType.cabinet,
      locationName: 'Cabinet Lac 2',
      status: DoctorAppointmentStatus.scheduled,
    ),
    DoctorDemoAppointment(
      id: 'nadia-1400',
      patientId: 'nadia',
      patientName: 'Nadia Mansour',
      patientAge: 41,
      dateTime: DateTime(2026, 9, 23, 14),
      durationMinutes: 30,
      reason: 'Consultation',
      locationType: DoctorAppointmentLocationType.cabinet,
      locationName: 'Cabinet Lac 2',
      status: DoctorAppointmentStatus.cancelled,
    ),
    DoctorDemoAppointment(
      id: 'hatem-1000',
      patientId: 'hatem',
      patientName: 'Hatem Gharbi',
      patientAge: 62,
      dateTime: DateTime(2026, 9, 24, 10),
      durationMinutes: 45,
      reason: 'Visite de suivi',
      locationType: DoctorAppointmentLocationType.homeVisit,
      locationName: 'La Marsa',
      status: DoctorAppointmentStatus.scheduled,
    ),
  ];
}
