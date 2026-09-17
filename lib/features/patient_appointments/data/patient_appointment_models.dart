/// Presentation models for the patient appointment-management experience.
///
/// These models are deliberately local to the current static UI phase. They
/// describe scheduled encounters, not Module 05 request lifecycle records.
library;

enum PatientAppointmentProviderType { doctor, clinic }

enum PatientAppointmentSubjectType { self, familyMember }

enum PatientAppointmentStatus { confirmed, completed, cancelled }

enum PatientAppointmentTab { upcoming, past, cancelled }

enum PatientAppointmentDateFilter { all, thisWeek, thisMonth, thisYear, custom }

class PatientAppointment {
  const PatientAppointment({
    required this.appointmentId,
    required this.providerType,
    required this.providerId,
    required this.providerDisplayName,
    required this.providerSubtitle,
    required this.subjectType,
    required this.subjectDisplayName,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.locationName,
    required this.address,
    required this.city,
    required this.consultationType,
    required this.appointmentReference,
    this.providerImageAssetPath,
    this.preparationInstructions,
    this.canCancel = false,
    this.canReschedule = false,
    this.canReportProblem = true,
  });

  final String appointmentId;
  final PatientAppointmentProviderType providerType;
  final String providerId;
  final String providerDisplayName;
  final String providerSubtitle;
  final String? providerImageAssetPath;
  final PatientAppointmentSubjectType subjectType;
  final String subjectDisplayName;
  final DateTime startAt;
  final DateTime endAt;
  final PatientAppointmentStatus status;
  final String locationName;
  final String address;
  final String city;
  final String consultationType;
  final String appointmentReference;
  final String? preparationInstructions;
  final bool canCancel;
  final bool canReschedule;
  final bool canReportProblem;

  PatientAppointment copyWith({
    PatientAppointmentStatus? status,
    bool? canCancel,
    bool? canReschedule,
  }) {
    return PatientAppointment(
      appointmentId: appointmentId,
      providerType: providerType,
      providerId: providerId,
      providerDisplayName: providerDisplayName,
      providerSubtitle: providerSubtitle,
      providerImageAssetPath: providerImageAssetPath,
      subjectType: subjectType,
      subjectDisplayName: subjectDisplayName,
      startAt: startAt,
      endAt: endAt,
      status: status ?? this.status,
      locationName: locationName,
      address: address,
      city: city,
      consultationType: consultationType,
      appointmentReference: appointmentReference,
      preparationInstructions: preparationInstructions,
      canCancel: canCancel ?? this.canCancel,
      canReschedule: canReschedule ?? this.canReschedule,
      canReportProblem: canReportProblem,
    );
  }
}

class PatientAppointmentFilters {
  const PatientAppointmentFilters({
    this.providerType,
    this.subjectType,
    this.subjectDisplayName,
    this.dateFilter = PatientAppointmentDateFilter.all,
    this.customStart,
    this.customEnd,
    this.city,
  });

  static const none = PatientAppointmentFilters();

  final PatientAppointmentProviderType? providerType;
  final PatientAppointmentSubjectType? subjectType;
  final String? subjectDisplayName;
  final PatientAppointmentDateFilter dateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? city;

  bool get isActive =>
      providerType != null ||
      subjectType != null ||
      (subjectDisplayName?.isNotEmpty ?? false) ||
      dateFilter != PatientAppointmentDateFilter.all ||
      city != null;

  int get activeCount {
    var count = 0;
    if (providerType != null) count++;
    if (subjectType != null || subjectDisplayName != null) count++;
    if (dateFilter != PatientAppointmentDateFilter.all) count++;
    if (city != null) count++;
    return count;
  }

  PatientAppointmentFilters copyWith({
    PatientAppointmentProviderType? providerType,
    bool clearProviderType = false,
    PatientAppointmentSubjectType? subjectType,
    bool clearSubjectType = false,
    String? subjectDisplayName,
    bool clearSubjectDisplayName = false,
    PatientAppointmentDateFilter? dateFilter,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustomRange = false,
    String? city,
    bool clearCity = false,
  }) {
    return PatientAppointmentFilters(
      providerType: clearProviderType
          ? null
          : providerType ?? this.providerType,
      subjectType: clearSubjectType ? null : subjectType ?? this.subjectType,
      subjectDisplayName: clearSubjectDisplayName
          ? null
          : subjectDisplayName ?? this.subjectDisplayName,
      dateFilter: dateFilter ?? this.dateFilter,
      customStart: clearCustomRange ? null : customStart ?? this.customStart,
      customEnd: clearCustomRange ? null : customEnd ?? this.customEnd,
      city: clearCity ? null : city ?? this.city,
    );
  }
}
