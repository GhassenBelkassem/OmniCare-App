import 'doctor_detail_models.dart';
import 'doctor_directory_models.dart';
import 'doctor_models.dart';

/// Maps strictly parsed backend DTOs onto the existing presentation models
/// ([DoctorListItem], [DoctorDetail], [DoctorDayAvailability]).
///
/// Real values stay authoritative (name, specialty, price, verifications,
/// arrays, biography, availability, practiceCity). Only the **Cabinet tab**
/// content is presentation-only and uses [practiceLocationFallback] — the
/// backend has no cabinet tables (explicit v1.1 out of scope).

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
/// via [attachAvailability]. Cabinet data falls back to [practiceLocationFallback].
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
    practiceLocations: dto.practiceCity == null
        ? const []
        : [practiceLocationFallback(dto.displayName, dto.practiceCity!)],
    availability: const [],
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
    final start = startUtc.toLocal();
    final end = endUtc.toLocal();
    final date = DateTime(start.year, start.month, start.day);
    byDay.putIfAbsent(date, () => []).add(
      DoctorAvailabilitySlot(
        time: _formatTime(start),
        timeOfDay: _periodFor(start),
        startIso: dto.start,
        endIso: dto.end,
        start: start,
        end: end,
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
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

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
  final now = DateTime.now();
  for (final day in days) {
    if (day.date.isAfter(now.subtract(const Duration(days: 1))) &&
        day.hasSlots) {
      final slot = day.slots.first;
      return '${_dayLabel(day.date, now)} · ${slot.time}';
    }
  }
  return null;
}

String _dayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (date.isAtSameMomentAs(today)) return 'Aujourd\'hui';
  if (date.isAtSameMomentAs(tomorrow)) return 'Demain';
  const dayNames = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  return dayNames[(date.weekday - 1).clamp(0, 6)];
}

/// Presentation-only cabinet data fallback for the (out of scope) Cabinet tab.
///
/// The real header location line reads [PracticeLocation.city], which is set
/// to the real `practice_city`; the remaining cabinet presentation content is
/// demo data — no backend cabinet tables exist (v1.1 explicit out of scope).
PracticeLocation practiceLocationFallback(
  String displayName,
  String practiceCity,
) {
  return PracticeLocation(
    name: 'Cabinet $displayName',
    address: 'Adresse non renseignée',
    city: practiceCity,
    distanceKm: null,
    galleryImages: [],
    openingHours: [
      const PracticeOpeningHours(label: 'Lun – Ven', hours: '08:30 – 17:00'),
      const PracticeOpeningHours(label: 'Sam', hours: '08:30 – 13:00'),
    ],
    equipment: const [PracticeEquipment(label: 'ECG')],
    accessibility: const ['Accessible PMR'],
    coverage: const [],
    appointmentInstructions:
        'Apportez vos anciens résultats d\'analyses et votre carnet de '
        'santé si disponible.',
  );
}

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