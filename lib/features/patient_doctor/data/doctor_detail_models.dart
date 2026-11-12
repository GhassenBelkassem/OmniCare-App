/// Detail presentation models for the patient doctor profile screen.
///
/// [DoctorDetail] is the primary profile model. [PracticeLocation] represents
/// a single workplace (future multi-location compatible; the cabinet tab keeps
/// its presentation-only data). [DoctorAvailabilitySlot] represents a single
/// real bookable time slot parsed from the availability endpoint.
library;

import 'doctor_directory_models.dart';
import 'doctor_models.dart';

/// Scheduling timezone mandated by the current Tunisia doctor contract.
///
/// This is applied by the backend-to-presentation mapper while the doctor
/// detail projection has no timezone field. It is deliberately not a default
/// on [PracticeLocation], so future location contracts must supply their own
/// authoritative IANA timezone.
const String doctorSchedulingTimezone = 'Africa/Tunis';

const Duration _tunisUtcOffset = Duration(hours: 1);

/// Converts an instant to the Africa/Tunis wall clock, for DISPLAY ONLY.
///
/// Africa/Tunis has been UTC+01:00 without DST throughout the supported
/// scheduling horizon. The result carries Tunis wall-clock fields, so it must
/// never be sent to the server or compared with a server instant.
DateTime toTunisWallClock(DateTime instant) =>
    instant.toUtc().add(_tunisUtcOffset);

const int _afternoonStartHour = 12;
const int _eveningStartHour = 18;

/// A single bookable slot, holding the server instants unchanged.
///
/// [start] and [end] are the backend `Instant`s (UTC) and are the only time
/// values of the slot. Everything shown to the patient ([time], [timeOfDay],
/// the Tunis calendar day) is derived from them at display time.
class DoctorAvailabilitySlot {
  const DoctorAvailabilitySlot._({
    required this.startIso,
    required this.endIso,
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  /// Builds a slot from the backend `start`/`end` instants.
  ///
  /// Throws [DoctorContractException] when an instant is unparseable or has
  /// no UTC offset (an offset-less value would be read in the device zone).
  factory DoctorAvailabilitySlot.fromServer({
    required String startIso,
    required String endIso,
    int? durationMinutes,
  }) {
    final start = _parseInstant(startIso);
    final end = _parseInstant(endIso);
    return DoctorAvailabilitySlot._(
      startIso: startIso,
      endIso: endIso,
      start: start,
      end: end,
      durationMinutes: durationMinutes ?? end.difference(start).inMinutes,
    );
  }

  /// The backend `start` value, verbatim. Used as the slot identity.
  final String startIso;

  /// The backend `end` value, verbatim.
  final String endIso;

  /// The backend start instant, in UTC. Sent back to the server as is.
  final DateTime start;

  /// The backend end instant, in UTC. Sent back to the server as is.
  final DateTime end;

  /// Backend-provided duration; never inferred as a scheduling rule.
  final int durationMinutes;

  /// Africa/Tunis calendar day of [start] (date only), for grouping.
  DateTime get tunisDate {
    final wallClock = toTunisWallClock(start);
    return DateTime(wallClock.year, wallClock.month, wallClock.day);
  }

  /// Africa/Tunis time label of [start] (e.g. '09:00', '14:30').
  String get time {
    final wallClock = toTunisWallClock(start);
    final hour = wallClock.hour.toString().padLeft(2, '0');
    final minute = wallClock.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Africa/Tunis period of [start]: 'Matin', 'Après-midi', 'Soir'.
  String get timeOfDay {
    final hour = toTunisWallClock(start).hour;
    if (hour < _afternoonStartHour) return 'Matin';
    if (hour < _eveningStartHour) return 'Après-midi';
    return 'Soir';
  }

  static DateTime _parseInstant(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw const DoctorContractException(
        'Slot carries an unparseable instant.',
      );
    }
    return parsed;
  }
}

/// Date-level availability: which day has which slots.
class DoctorDayAvailability {
  const DoctorDayAvailability({required this.date, required this.slots});

  /// The date (year, month, day only — no time component).
  final DateTime date;

  /// Available time slots for this date.
  final List<DoctorAvailabilitySlot> slots;

  bool get hasSlots => slots.isNotEmpty;

  /// Slots grouped by time of day.
  Map<String, List<DoctorAvailabilitySlot>> get slotsByPeriod {
    final result = <String, List<DoctorAvailabilitySlot>>{};
    for (final slot in slots) {
      result.putIfAbsent(slot.timeOfDay, () => []).add(slot);
    }
    return result;
  }
}

/// Equipment or examination available at a practice location.
class PracticeEquipment {
  const PracticeEquipment({required this.label, this.iconCodePoint});

  final String label;
  final int? iconCodePoint;
}

/// Opening hours for a single day or day range.
class PracticeOpeningHours {
  const PracticeOpeningHours({required this.label, required this.hours});

  /// Day or range label (e.g. 'Lun – Ven', 'Sam').
  final String label;

  /// Hours string (e.g. '08:00 – 18:00').
  final String hours;
}

/// One public network photograph belonging to a practice location.
class PracticeLocationMedia {
  const PracticeLocationMedia({required this.url, this.displayOrder});

  final String url;
  final int? displayOrder;
}

/// A practice location where a doctor works.
///
/// Future-compatible with multiple locations per doctor.
class PracticeLocation {
  const PracticeLocation({
    required this.practiceLocationId,
    required this.name,
    required this.address,
    required this.city,
    required this.governorate,
    required this.timezone,
    this.type,
    this.latitude,
    this.longitude,
    this.publicPhone,
    this.wheelchairAccessible = false,
    this.primary = false,
    this.distanceKm,
    this.galleryMedia = const [],
    this.galleryImages = const [],
    this.openingHours = const [],
    this.equipment = const [],
    this.accessibility = const [],
    this.coverage = const [],
    this.appointmentInstructions,
  });

  /// Persisted backend Cabinet identity used for availability and creation.
  final String practiceLocationId;

  /// Display name (e.g. 'Cabinet Dr. Amine Ben Salah').
  final String name;

  /// Street address.
  final String address;

  /// City.
  final String city;

  final String governorate;

  /// IANA scheduling timezone retained with the Cabinet.
  final String timezone;

  final String? type;
  final double? latitude;
  final double? longitude;
  final String? publicPhone;
  final bool wheelchairAccessible;
  final bool primary;

  /// Distance from user in km (mock value).
  final double? distanceKm;

  /// Public network photographs supplied for this exact backend location.
  final List<PracticeLocationMedia> galleryMedia;

  /// Presentation-only local asset paths retained for demo compatibility.
  final List<String> galleryImages;

  /// Opening hours entries.
  final List<PracticeOpeningHours> openingHours;

  /// Equipment and examinations available at this location.
  final List<PracticeEquipment> equipment;

  /// Accessibility features (e.g. 'Accessible PMR', 'Ascenseur').
  final List<String> accessibility;

  /// Insurance/coverage information.
  final List<String> coverage;

  /// Pre-appointment instructions.
  final String? appointmentInstructions;
}

/// Full doctor profile for the detail screen.
///
/// Extends [DoctorListItem] data with richer profile information.
class DoctorDetail {
  const DoctorDetail({
    required this.listItem,
    this.verified = false,
    this.areasOfCare = const [],
    this.expertise = const [],
    this.biography,
    this.patientAgeGroups = const [],
    this.practiceLocations = const [],
    this.availability = const [],
    this.nextAvailableLabel,
    this.consultationPriceTnd,
  });

  /// The base list item data (name, specialty, etc.).
  final DoctorListItem listItem;

  /// Whether the doctor is verified.
  final bool verified;

  /// Domaines de prise en charge (e.g. 'Hypertension', 'Douleur thoracique').
  final List<String> areasOfCare;

  /// Expertise / sub-specialty areas (e.g. 'Cardiologie interventionnelle').
  final List<String> expertise;

  /// Short patient-oriented biography.
  final String? biography;

  /// Patient age groups (e.g. 'Adultes', 'Personnes âgées').
  final List<String> patientAgeGroups;

  /// Practice locations (one or more).
  final List<PracticeLocation> practiceLocations;

  /// Available dates with time slots.
  final List<DoctorDayAvailability> availability;

  /// Human-readable label for next availability (e.g. 'Aujourd\'hui · 16:30').
  final String? nextAvailableLabel;

  /// Authoritative pre-submit price from doctor detail, when present.
  final double? consultationPriceTnd;

  /// Convenience accessors forwarded from listItem.
  String get id => listItem.id;
  String get name => listItem.name;
  String get specialty => listItem.specialty;
  List<String> get subSpecialties => listItem.subSpecialties;
  int get experienceYears => listItem.experienceYears;
  List<String> get languages => listItem.languages;
  bool get acceptingNewPatients => listItem.acceptingNewPatients;
  List<String> get consultationTypes => listItem.consultationTypes;
  List<String> get visitReasons => listItem.visitReasons;
  String? get imageAssetPath => listItem.imageAssetPath;
  double? get distanceKm => listItem.distanceKm;

  /// Returns a copy with freshly fetched availability data attached.
  DoctorDetail copyWith({
    List<DoctorDayAvailability>? availability,
    String? nextAvailableLabel,
    bool clearNextAvailableLabel = false,
  }) {
    return DoctorDetail(
      listItem: listItem,
      verified: verified,
      areasOfCare: areasOfCare,
      expertise: expertise,
      biography: biography,
      patientAgeGroups: patientAgeGroups,
      practiceLocations: practiceLocations,
      availability: availability ?? this.availability,
      nextAvailableLabel: clearNextAvailableLabel
          ? null
          : nextAvailableLabel ?? this.nextAvailableLabel,
      consultationPriceTnd: consultationPriceTnd,
    );
  }
}
