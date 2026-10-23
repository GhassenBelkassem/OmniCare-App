/// Local-only D3 fixtures for the Doctor Home. These are deliberately small
/// presentation models, not appointment, consultation, or work-queue domains.
class DoctorHomeDemoState {
  const DoctorHomeDemoState({
    this.activeConsultation,
    this.attentionItems = const [],
    this.nextAppointment,
    this.todayAppointments = const [],
    this.urgentStatus,
  });

  final DoctorHomeActiveConsultation? activeConsultation;
  final List<DoctorHomeAttentionItem> attentionItems;
  final DoctorHomeAppointment? nextAppointment;
  final List<DoctorHomeAppointment> todayAppointments;
  final DoctorHomeUrgentStatus? urgentStatus;

  static const normalDay = DoctorHomeDemoState(
    attentionItems: [
      DoctorHomeAttentionItem(
        kind: DoctorHomeAttentionKind.urgent,
        title: 'Résultat à revoir',
        patientName: 'Mohamed Trabelsi',
        dueLabel: 'Aujourd’hui',
      ),
      DoctorHomeAttentionItem(
        kind: DoctorHomeAttentionKind.followUp,
        title: 'Suivi à effectuer',
        patientName: 'Amina Chaari',
        dueLabel: 'Aujourd’hui',
      ),
      DoctorHomeAttentionItem(
        kind: DoctorHomeAttentionKind.appointmentRequest,
        title: 'Demande de rendez-vous',
        patientName: 'Sami Ben Ali',
        dueLabel: 'Demain',
      ),
    ],
    nextAppointment: DoctorHomeAppointment(
      time: '10:30',
      patientName: 'Mohamed Trabelsi',
      reason: 'Contrôle hypertension',
      location: 'Cabinet Lac 2',
      relativeTime: 'Dans 45 min',
    ),
    todayAppointments: [
      DoctorHomeAppointment(
        time: '09:00',
        patientName: 'Sami Ben Ali',
        reason: 'Consultation',
      ),
      DoctorHomeAppointment(
        time: '10:30',
        patientName: 'Mohamed Trabelsi',
        reason: 'Contrôle hypertension',
      ),
      DoctorHomeAppointment(
        time: '14:00',
        patientName: 'Nadia Mansour',
        reason: 'Consultation',
      ),
    ],
    urgentStatus: DoctorHomeUrgentStatus.available,
  );

  static const activeConsultationDay = DoctorHomeDemoState(
    activeConsultation: DoctorHomeActiveConsultation(
      patientName: 'Mohamed Trabelsi',
      reason: 'Contrôle hypertension',
      elapsedLabel: 'Depuis 08 min',
    ),
    attentionItems: [
      DoctorHomeAttentionItem(
        kind: DoctorHomeAttentionKind.urgent,
        title: 'Résultat à revoir',
        patientName: 'Mohamed Trabelsi',
        dueLabel: 'Aujourd’hui',
      ),
      DoctorHomeAttentionItem(
        kind: DoctorHomeAttentionKind.followUp,
        title: 'Suivi à effectuer',
        patientName: 'Amina Chaari',
        dueLabel: 'Aujourd’hui',
      ),
      DoctorHomeAttentionItem(
        kind: DoctorHomeAttentionKind.appointmentRequest,
        title: 'Demande de rendez-vous',
        patientName: 'Sami Ben Ali',
        dueLabel: 'Demain',
      ),
    ],
    nextAppointment: DoctorHomeAppointment(
      time: '10:30',
      patientName: 'Mohamed Trabelsi',
      reason: 'Contrôle hypertension',
      location: 'Cabinet Lac 2',
      relativeTime: 'Dans 45 min',
    ),
    todayAppointments: [
      DoctorHomeAppointment(
        time: '09:00',
        patientName: 'Sami Ben Ali',
        reason: 'Consultation',
      ),
    ],
    urgentStatus: DoctorHomeUrgentStatus.available,
  );

  static const emptyDay = DoctorHomeDemoState();
}

class DoctorHomeActiveConsultation {
  const DoctorHomeActiveConsultation({
    required this.patientName,
    required this.reason,
    required this.elapsedLabel,
  });

  final String patientName;
  final String reason;
  final String elapsedLabel;
}

class DoctorHomeAttentionItem {
  const DoctorHomeAttentionItem({
    required this.kind,
    required this.title,
    required this.patientName,
    required this.dueLabel,
  });

  final DoctorHomeAttentionKind kind;
  final String title;
  final String patientName;
  final String dueLabel;
}

enum DoctorHomeAttentionKind {
  urgent,
  result,
  followUp,
  appointmentRequest,
  incompleteConsultation,
  message,
}

class DoctorHomeAppointment {
  const DoctorHomeAppointment({
    required this.time,
    required this.patientName,
    required this.reason,
    this.location,
    this.relativeTime,
  });

  final String time;
  final String patientName;
  final String reason;
  final String? location;
  final String? relativeTime;
}

enum DoctorHomeUrgentStatus {
  offline,
  available,
  requestPending,
  missionInProgress,
}
