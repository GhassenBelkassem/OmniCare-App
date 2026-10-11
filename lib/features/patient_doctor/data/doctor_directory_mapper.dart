import 'doctor_detail_models.dart';
import 'doctor_directory_models.dart';
import 'doctor_models.dart';

/// Maps strictly parsed backend DTOs onto the existing presentation models
/// ([DoctorListItem], [DoctorDetail], [DoctorDayAvailability]).
///
/// Real values stay authoritative (name, specialty, price, verifications,
/// arrays, biography, Cabinets, gallery, equipment and coverage). Missing
/// response fields stay absent; this layer never manufactures profile data.

/// Maps a directory list entry onto the presentation list model.
DoctorListItem toDoctorListItem(DoctorSearchCard dto) {
  return DoctorListItem(
    id: dto.doctorId,
    name: dto.displayName,
    specialty: dto.specialty,
    photoUrl: dto.photoUrl,
    consultationPriceTnd: dto.consultationPriceTnd,
    experienceYears: dto.experienceYears,
    verified: dto.verified,
    acceptingNewPatients: dto.acceptingNewPatients,
    careCapabilities: dto.careCapabilities,
    distanceKm: dto.distanceKm,
    matchingPracticeLocation: dto.matchingPracticeLocation,
  );
}

/// Builds the presentation [DoctorDetail] from the real detail DTO.
///
/// Availability is not part of the detail endpoint; the existing scheduling
/// integration attaches it afterwards via [attachAvailability].
DoctorDetail buildDoctorDetail(DoctorDirectoryDetail dto) {
  final listItem = DoctorListItem(
    id: dto.doctorId,
    name: dto.displayName,
    specialty: dto.specialty,
    photoUrl: dto.photoUrl,
    consultationPriceTnd: dto.consultationPriceTnd,
    experienceYears: dto.experienceYears,
    verified: dto.verified,
    acceptingNewPatients: dto.acceptingNewPatients,
    careCapabilities: dto.careCapabilities,
    subSpecialties: dto.subSpecialties,
    distanceKm: dto.distanceKm,
    consultationTypes: dto.consultationTypes,
    languages: dto.languages,
    visitReasons: dto.visitReasons,
  );

  return DoctorDetail(
    listItem: listItem,
    verified: dto.verified,
    areasOfCare: dto.areasOfCare,
    expertise: dto.expertise,
    biography: dto.biography,
    patientAgeGroups: dto.patientAgeGroups,
    education: dto.education,
    certifications: dto.certifications,
    careCapabilities: dto.careCapabilities,
    practiceLocations: List.unmodifiable(
      dto.practiceLocations.map(_toPracticeLocation),
    ),
    availability: const [],
  );
}

PracticeLocation _toPracticeLocation(DoctorPracticeLocation dto) {
  return PracticeLocation(
    id: dto.id,
    type: dto.type,
    name: dto.name,
    governorate: dto.governorate,
    address: dto.address,
    city: dto.city,
    latitude: dto.latitude,
    longitude: dto.longitude,
    publicPhone: dto.publicPhone,
    wheelchairAccessible: dto.wheelchairAccessible,
    primary: dto.primary,
    galleryImages: List.unmodifiable(dto.gallery.map((media) => media.url)),
    openingHours: const [],
    equipment: List.unmodifiable(
      dto.equipment.map(
        (equipment) => PracticeEquipment(
          code: equipment.code,
          label: equipment.displayName,
          portable: equipment.portable,
        ),
      ),
    ),
    accessibility: dto.wheelchairAccessible
        ? const ['Accessible PMR']
        : const [],
    coverage: _coverageLabels(dto.coverage),
    appointmentInstructions: dto.patientInstructions,
  );
}

List<String> _coverageLabels(DoctorPracticeCoverage? coverage) {
  if (coverage == null) return const [];
  return List.unmodifiable([
    if (coverage.cnam.acceptance == DoctorCoverageAcceptance.accepted)
      'CNAM acceptée (déclaration du professionnel)',
    if (coverage.cnam.acceptance == DoctorCoverageAcceptance.notAccepted)
      'CNAM non acceptée (déclaration du professionnel)',
    if (coverage.privateInsurance.acceptance ==
        DoctorCoverageAcceptance.accepted)
      'Assurance privée acceptée (déclaration du professionnel)',
    if (coverage.privateInsurance.acceptance ==
        DoctorCoverageAcceptance.notAccepted)
      'Assurance privée non acceptée (déclaration du professionnel)',
    if (coverage.selfPay.acceptance == DoctorCoverageAcceptance.accepted)
      'Paiement direct accepté (déclaration du professionnel)',
    if (coverage.selfPay.acceptance == DoctorCoverageAcceptance.notAccepted)
      'Paiement direct non accepté (déclaration du professionnel)',
  ]);
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
