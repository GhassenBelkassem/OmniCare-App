import 'doctor_detail_models.dart';
import 'doctor_directory_models.dart';
import 'doctor_models.dart';

/// Maps strictly parsed backend DTOs onto the existing presentation models
/// ([DoctorListItem], [DoctorDetail], [DoctorDayAvailability]).
///
/// Real values stay authoritative (name, specialty, price, verifications,
/// arrays, biography, availability and exact practice locations).

/// Maps a directory list entry onto the presentation list model.
DoctorListItem toDoctorListItem(DoctorDirectoryListItem dto) {
  return DoctorListItem(
    id: dto.doctorId,
    name: dto.displayName,
    specialty: dto.specialty ?? '',
    rating: 0.0,
    totalReviews: 0,
    officeConsultationFee: dto.consultationPriceTnd ?? 0.0,
    experienceYears: dto.experienceYears ?? 0,
    isOnline: false,
    providerId: '',
    address: null,
    phoneNumber: dto.phoneNumber,
    latitude: null,
    longitude: null,
    imageAssetPath: null,
    subSpecialties: const [],
    distanceKm: dto.distanceKm,
    acceptingNewPatients: true,
    patientAgeGroup: null,
    consultationTypes: const [],
    gender: null,
    languages: const [],
    visitReasons: const [],
    insuranceAccepted: const [],
    practiceLocationType: null,
    timeOfDay: null,
    availableSaturday: false,
    homeVisitAvailable: false,
    dutyService: false,
  );
}

/// Builds the presentation [DoctorDetail] from the real detail DTO.
///
/// Availability is not part of the detail endpoint; it is attached afterwards
/// via [attachAvailability].
DoctorDetail buildDoctorDetail(DoctorDirectoryDetail dto) {
  final listItem = DoctorListItem(
    id: dto.doctorId,
    name: dto.displayName,
    specialty: dto.specialty ?? '',
    rating: 0.0,
    totalReviews: 0,
    officeConsultationFee: dto.consultationPriceTnd ?? 0.0,
    experienceYears: dto.experienceYears ?? 0,
    isOnline: false,
    providerId: '',
    address: null,
    phoneNumber: dto.phoneNumber,
    latitude: null,
    longitude: null,
    imageAssetPath: null,
    subSpecialties: dto.subSpecialties,
    distanceKm: dto.distanceKm,
    acceptingNewPatients: dto.acceptingNewPatients,
    patientAgeGroup: null,
    consultationTypes: dto.consultationTypes,
    gender: null,
    languages: dto.languages,
    visitReasons: dto.visitReasons,
    insuranceAccepted: const [],
    practiceLocationType: null,
    timeOfDay: null,
    availableSaturday: false,
    homeVisitAvailable: false,
    dutyService: false,
  );

  return DoctorDetail(
    listItem: listItem,
    verified: dto.verified,
    areasOfCare: dto.areasOfCare,
    expertise: dto.expertise,
    biography: dto.biography,
    patientAgeGroups: dto.patientAgeGroups,
    practiceLocations: dto.practiceLocations.map(_toPracticeLocation).toList(),
    availability: const [],
    consultationPriceTnd: dto.consultationPriceTnd,
  );
}

/// Groups raw slot instants by local date and period, sorted chronologically.
List<DoctorDayAvailability> groupAvailabilitySlots(
  List<AvailabilitySlotDto> slots,
) {
  final byDay = <DateTime, List<DoctorAvailabilitySlot>>{};
  for (final dto in slots) {
    final startUtc = DateTime.tryParse(dto.start);
    final endUtc = DateTime.tryParse(dto.end);
    if (startUtc == null || endUtc == null) {
      throw const DoctorContractException(
        'Slot carries an unparseable instant.',
      );
    }
    final start = toTunisWallClock(startUtc);
    final end = toTunisWallClock(endUtc);
    final date = DateTime(start.year, start.month, start.day);
    byDay
        .putIfAbsent(date, () => [])
        .add(
          DoctorAvailabilitySlot(
            time: _formatTime(start),
            timeOfDay: _periodFor(start),
            startIso: dto.start,
            endIso: dto.end,
            start: start,
            end: end,
            durationMinutes:
                dto.durationMinutes ?? endUtc.difference(startUtc).inMinutes,
          ),
        );
  }

  final days = byDay.entries.map((entry) {
    final slotsOfDay = List<DoctorAvailabilitySlot>.of(entry.value)
      ..sort((a, b) => a.start.compareTo(b.start));
    return DoctorDayAvailability(
      date: entry.key,
      slots: List.unmodifiable(slotsOfDay),
    );
  }).toList()..sort((a, b) => a.date.compareTo(b.date));

  return List.unmodifiable(days);
}

/// Attaches the grouped availability (and its next-availability label) to a
/// detail built by [buildDoctorDetail].
DoctorDetail attachAvailability(
  DoctorDetail detail,
  List<DoctorDayAvailability> days,
) {
  final label = nextAvailableLabelFor(days);
  return detail.copyWith(
    availability: days,
    nextAvailableLabel: label,
    clearNextAvailableLabel: label == null,
  );
}

/// "Aujourd\'hui · 09:30" / "Demain · 10:00" / "Mercredi · 14:00" from the
/// earliest returned slot, or null when there is no availability at all.
String? nextAvailableLabelFor(List<DoctorDayAvailability> days) {
  final now = toTunisWallClock(DateTime.now());
  final today = DateTime(now.year, now.month, now.day);
  for (final day in days) {
    final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
    if (!dayDate.isBefore(today) && day.hasSlots) {
      final slot = day.slots.first;
      return '${_dayLabel(dayDate, today)} · ${slot.time}';
    }
  }
  return null;
}

String _dayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final calendarDate = DateTime(date.year, date.month, date.day);
  if (calendarDate == today) return 'Aujourd\'hui';
  if (calendarDate == tomorrow) return 'Demain';
  const dayNames = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  return dayNames[(calendarDate.weekday - 1).clamp(0, 6)];
}

PracticeLocation _toPracticeLocation(DoctorPracticeLocationDto dto) {
  return PracticeLocation(
    practiceLocationId: dto.id,
    name: dto.name,
    address: dto.address,
    city: dto.city,
    governorate: dto.governorate,
    // The current doctor-detail DTO has no timezone property. Apply the
    // frozen Tunisia scheduling contract here at the adapter boundary.
    timezone: doctorSchedulingTimezone,
    type: dto.type,
    latitude: dto.latitude,
    longitude: dto.longitude,
    publicPhone: dto.publicPhone,
    wheelchairAccessible: dto.wheelchairAccessible,
    primary: dto.primary,
    distanceKm: null,
    galleryMedia: dto.gallery
        .map(
          (media) => PracticeLocationMedia(
            url: media.url,
            displayOrder: media.displayOrder,
          ),
        )
        .toList(growable: false),
    galleryImages: const [],
    openingHours: const [],
    equipment: dto.equipment
        .map((item) => PracticeEquipment(label: item.displayName))
        .toList(growable: false),
    accessibility: dto.wheelchairAccessible
        ? const ['Accessible PMR']
        : const [],
    coverage: const [],
    appointmentInstructions: dto.patientInstructions,
  );
}

/// Africa/Tunis has been UTC+01:00 without DST throughout the supported
/// scheduling horizon. This conversion is intentionally centralized so the
/// device timezone never influences Cabinet slot grouping or labels.
DateTime toTunisWallClock(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 1));

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _periodFor(DateTime value) {
  if (value.hour < 12) return 'Matin';
  if (value.hour < 18) return 'Après-midi';
  return 'Soir';
}
