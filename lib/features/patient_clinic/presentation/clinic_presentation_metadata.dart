import '../data/patient_clinic_models.dart';

/// Presentation-only image source: asset (bundled) or network (URL).
enum ClinicPresentationImageSource { asset, network }

/// A presentation-only image that knows whether it is a local asset or a
/// network URL. Used exclusively in the presentation layer — never in API DTOs.
class ClinicPresentationImage {
  const ClinicPresentationImage.asset(this.value)
      : source = ClinicPresentationImageSource.asset;
  const ClinicPresentationImage.network(this.value)
      : source = ClinicPresentationImageSource.network;

  final String value;
  final ClinicPresentationImageSource source;

  bool get isAsset => source == ClinicPresentationImageSource.asset;
  bool get isNetwork => source == ClinicPresentationImageSource.network;
}

/// Temporary Flutter-only presentation metadata for the patient Clinic
/// discovery experience.
///
/// IMPORTANT:
///
/// This data does NOT come from the Clinic API yet.
///
/// It exists only to allow the patient-facing UI/UX to be completed before
/// specialties, services, clinic type and richer public presentation data are
/// exposed by the backend.
///
/// Backend-authoritative fields MUST continue to come from
/// [PatientClinicListItem] / [PatientClinicDetail]:
///
/// - clinicId
/// - displayName
/// - city
/// - governorate
/// - address
/// - primaryImageUrl
/// - gallery
/// - about
/// - acceptingRequests
///
/// Nothing from this file must ever enter a request submission payload.
class ClinicPresentationMetadata {
  const ClinicPresentationMetadata({
    required this.clinicType,
    required this.specialties,
    required this.primarySpecialty,
    this.primarySpecialtyDescription,
    required this.services,
    required this.shortDescription,
    this.fallbackGallery = const [],
    this.distance,
    this.locality,
    this.driveTime,
    this.availability = const [],
    this.doctors = const [],
    this.insurance = const [],
    this.insuranceHighlight,
    this.facilities = const [],
    this.totalFacilitiesCount,
    this.hours,
    this.emergencyHours,
    this.languages = const [],
    this.accessibility = const [],
    this.verification,
    this.localDemoImages = const [],
  });

  final String clinicType;

  /// Patient-facing specialty vocabulary.
  final List<String> specialties;

  /// The primary/lead specialty for prominent display.
  final String primarySpecialty;

  /// Optional description for the primary specialty.
  final String? primarySpecialtyDescription;

  /// Public service labels used for discovery/presentation only.
  final List<String> services;

  /// Short editorial summary.
  ///
  /// Do not use performance/quality claims here.
  final String shortDescription;

  /// Temporary image assets/URLs used only when backend Clinic media
  /// is unavailable.
  ///
  /// Prefer local approved app assets later.
  final List<String> fallbackGallery;

  /// Presentation-only distance shown near location.
  final String? distance;

  /// Presentation-only neighbourhood/locality for richer location labels.
  final String? locality;

  /// Presentation-only estimated drive time.
  final String? driveTime;

  /// Presentation-only available time slots for walk-in / appointment info.
  final List<ClinicAvailabilitySlot> availability;

  /// Presentation-only doctor profiles for this clinic.
  final List<ClinicDoctorPresentation> doctors;

  /// Presentation-only accepted insurance labels.
  final List<String> insurance;

  /// The patient's matched insurance (if any) for highlight display.
  final String? insuranceHighlight;

  /// Presentation-only facility/equipment highlights.
  final List<ClinicFacilityPresentation> facilities;

  /// Total number of facilities (for "+N" display).
  final int? totalFacilitiesCount;

  /// Presentation-only operating hours.
  final ClinicHoursPresentation? hours;

  /// Emergency hours display (e.g., "24/7").
  final String? emergencyHours;

  /// Presentation-only spoken languages.
  final List<String> languages;

  /// Presentation-only accessibility features.
  final List<String> accessibility;

  /// Presentation-only verification/trust badges.
  final ClinicVerificationPresentation? verification;

  /// Local demo image asset paths (UI-demo only, replaced by backend gallery).
  final List<ClinicPresentationImage> localDemoImages;
}

/// A single available time slot for walk-in or appointment display.
class ClinicAvailabilitySlot {
  const ClinicAvailabilitySlot({
    required this.label,
    required this.time,
    required this.isOpen,
  });

  final String label;
  final String time;
  final bool isOpen;
}

/// Presentation-only doctor profile.
class ClinicDoctorPresentation {
  const ClinicDoctorPresentation({
    required this.name,
    required this.specialty,
    this.subtitle,
    this.availabilityLabel,
  });

  final String name;
  final String specialty;
  final String? subtitle;
  final String? availabilityLabel;
}

/// Presentation-only facility/equipment highlight.
class ClinicFacilityPresentation {
  const ClinicFacilityPresentation({
    required this.icon,
    required this.label,
  });

  final String icon;
  final String label;
}

/// Presentation-only operating hours.
class ClinicHoursPresentation {
  const ClinicHoursPresentation({
    required this.weekday,
    required this.saturday,
    required this.sunday,
  });

  final String weekday;
  final String saturday;
  final String sunday;
}

/// Presentation-only verification/trust badges.
class ClinicVerificationPresentation {
  const ClinicVerificationPresentation({
    required this.badges,
  });

  final List<String> badges;
}

/// Presentation-only care-need options for the filter sheet.
abstract final class CareNeedOptions {
  static const List<String> values = [
    'General consultation',
    'Specialist consultation',
    'Surgery',
    'Imaging',
    'Laboratory / Tests',
    'Maternity',
    'Rehabilitation / Kiné',
    'Other',
  ];
}

/// Presentation-only governorate → cities mapping for Tunisia.
abstract final class GovernorateCatalog {
  static const Map<String, List<String>> governorates = {
    'Tunis': [
      'Bardo',
      'La Marsa',
      'Carthage',
      'El Menzah',
      'Centre Urbain Nord',
      'Ennasr',
      'Bab Saadoun',
      'Lac 1',
      'Lac 2',
      'El Omrane',
      'El Omrane Bey',
      'Bab Alioua',
      'Sidi Hassine',
    ],
    'Sousse': [
      'Sousse Centre',
      'Sidi Abdelhamid',
      'Kantaoui',
      'Hammam Sousse',
      'Msaken',
    ],
    'Sfax': [
      'Sfax Centre',
      'Sakiet Ezzit',
      'Sakiet Eddaier',
      'Thyna',
    ],
    'Nabeul': [
      'Nabeul Centre',
      'Hammamet',
      'Dar El Meknes',
      'Korba',
    ],
    'Monastir': [
      'Monastir Centre',
      'Sahline',
      'Ksibet Thrayet',
    ],
    'Bizerte': [
      'Bizerte Centre',
      'Menzel Bourguiba',
      'Ras Jebel',
    ],
    'Kairouan': [
      'Kairouan Centre',
      'Oueslatia',
    ],
  };

  static List<String> citiesFor(String governorate) =>
      governorates[governorate] ?? const [];
}

/// Complete alphabetical catalog of medical specialties.
abstract final class SpecialtyCatalog {
  static const List<String> all = [
    'Allergology',
    'Anesthesiology',
    'Bariatric surgery',
    'Cardiology',
    'Cardiovascular surgery',
    'Clinical biology',
    'Dermatology',
    'Diabetology',
    'Emergency medicine',
    'Endocrinology',
    'Gastroenterology',
    'General medicine',
    'General practice',
    'General surgery',
    'Geriatrics',
    'Gynecology',
    'Hematology',
    'Hepatology',
    'Immunology',
    'Infectious diseases',
    'Intensive care',
    'Internal medicine',
    'Nephrology',
    'Neurology',
    'Neurosurgery',
    'Nuclear medicine',
    'Obstetrics',
    'Oncology',
    'Ophthalmology',
    'Oral surgery',
    'Orthopedics',
    'Otorhinolaryngology',
    'Pain management',
    'Pathology',
    'Pediatrics',
    'Phlebology',
    'Physical medicine',
    'Physiotherapy',
    'Plastic surgery',
    'Pneumology',
    'Podiatry',
    'Psychiatry',
    'Psychology',
    'Radiology',
    'Rheumatology',
    'Stomatology',
    'Thoracic surgery',
    'Toxicology',
    'Urology',
  ];

  static const List<String> common = [
    'General medicine',
    'Cardiology',
    'Orthopedics',
    'Physiotherapy',
  ];
}

/// UI-only catalog with presentation-only clinic data.
abstract final class ClinicPresentationCatalog {
  /// Local demo image paths shared by all dev clinics.
  static const List<ClinicPresentationImage> _demoImages = [
    ClinicPresentationImage.asset('assets/images/clinics/demo/clinic_exterior.jpg'),
    ClinicPresentationImage.asset('assets/images/clinics/demo/clinic_reception.jpg'),
    ClinicPresentationImage.asset('assets/images/clinics/demo/clinic_waiting.jpg'),
    ClinicPresentationImage.asset('assets/images/clinics/demo/clinic_room.jpg'),
    ClinicPresentationImage.asset('assets/images/clinics/demo/clinic_hallway.jpg'),
  ];

  static const ClinicPresentationMetadata defaultClinic =
      ClinicPresentationMetadata(
        clinicType: 'Multi-specialty clinic',
        specialties: [
          'General medicine',
          'Cardiology',
          'Orthopedics',
          'Physiotherapy',
          'Gynecology',
          'Radiology',
          'General surgery',
          'Dermatology',
        ],
        primarySpecialty: 'General medicine',
        primarySpecialtyDescription:
            'Comprehensive outpatient consultations and ongoing care.',
        services: [
          'Medical consultations',
          'Nursing care',
          'Physiotherapy',
        ],
        shortDescription:
            'Consultations and coordinated outpatient care in one clinic.',
        distance: '1.5 km away',
        locality: 'Centre Urbain Nord',
        driveTime: '~5 min drive',
        availability: [
          ClinicAvailabilitySlot(
            label: 'Today',
            time: '16:30',
            isOpen: true,
          ),
          ClinicAvailabilitySlot(
            label: 'Tomorrow',
            time: '09:00',
            isOpen: true,
          ),
          ClinicAvailabilitySlot(
            label: 'Tomorrow',
            time: '11:30',
            isOpen: true,
          ),
        ],
        doctors: [
          ClinicDoctorPresentation(
            name: 'Dr. Ahmed Ben Salah',
            specialty: 'General medicine',
            subtitle: '15+ years experience',
            availabilityLabel: 'Available today · 16:30',
          ),
          ClinicDoctorPresentation(
            name: 'Dr. Fatma Meziane',
            specialty: 'Cardiology',
            subtitle: 'Board certified',
            availabilityLabel: 'Available tomorrow · 09:00',
          ),
        ],
        insurance: ['CNAM', 'CNSS', 'COMAR', 'Private insurance'],
        insuranceHighlight: 'STAR',
        facilities: [
          ClinicFacilityPresentation(icon: 'radiography', label: 'X-ray'),
          ClinicFacilityPresentation(icon: 'monitor_heart', label: 'ECG'),
          ClinicFacilityPresentation(
            icon: 'biotech',
            label: 'Laboratory',
          ),
          ClinicFacilityPresentation(
            icon: 'airline_seat_flat',
            label: 'ICU',
          ),
        ],
        totalFacilitiesCount: 11,
        hours: ClinicHoursPresentation(
          weekday: '08:00 – 20:00',
          saturday: '08:00 – 14:00',
          sunday: 'Closed',
        ),
        emergencyHours: '24/7',
        languages: ['Arabic', 'French', 'English'],
        accessibility: [
          'Wheelchair accessible',
          'Elevator',
          'Accessible parking',
        ],
        verification: ClinicVerificationPresentation(
          badges: [
            'Licensed clinic',
            'Ministry of Health approved',
          ],
        ),
        localDemoImages: _demoImages,
      );

  static const Map<String, ClinicPresentationMetadata> _byClinicId = {
    'clinic-cardiology-001': ClinicPresentationMetadata(
      clinicType: 'Specialty clinic',
      specialties: [
        'Cardiology',
        'Internal medicine',
        'Orthopedics',
        'Gynecology',
        'Radiology',
        'General surgery',
        'Neurology',
        'Dermatology',
      ],
      primarySpecialty: 'Cardiology',
      primarySpecialtyDescription:
          'Cardiovascular consultations, diagnostics and follow-up.',
      services: ['Cardiology consultations', 'Cardiac follow-up'],
      shortDescription:
          'Cardiology-focused consultations and cardiac follow-up.',
      distance: '2.3 km away',
      locality: 'La Marsa',
      driveTime: '~8 min drive',
      availability: [
        ClinicAvailabilitySlot(
          label: 'Today',
          time: '16:30',
          isOpen: true,
        ),
        ClinicAvailabilitySlot(
          label: 'Tomorrow',
          time: '09:00',
          isOpen: true,
        ),
        ClinicAvailabilitySlot(
          label: 'Tomorrow',
          time: '11:30',
          isOpen: true,
        ),
      ],
      doctors: [
        ClinicDoctorPresentation(
          name: 'Dr. Habib Mansour',
          specialty: 'Cardiology',
          subtitle: '20+ years, interventional cardiology',
          availabilityLabel: 'Available today · 16:30',
        ),
        ClinicDoctorPresentation(
          name: 'Dr. Nadia Khlifi',
          specialty: 'Internal medicine',
          subtitle: 'Cardiac risk assessment',
          availabilityLabel: 'Available tomorrow · 09:00',
        ),
        ClinicDoctorPresentation(
          name: 'Dr. Sami Bouazizi',
          specialty: 'Cardiology',
          subtitle: 'Echocardiography specialist',
          availabilityLabel: 'Available tomorrow · 11:30',
        ),
      ],
      insurance: ['CNAM', 'CNSS', 'COMAR', 'Intertropical', 'Private insurance'],
      insuranceHighlight: 'STAR',
      facilities: [
        ClinicFacilityPresentation(
          label: 'Echocardiography',
          icon: 'monitor_heart',
        ),
        ClinicFacilityPresentation(
          label: 'ECG',
          icon: 'ecg',
        ),
        ClinicFacilityPresentation(
          label: 'Stress test',
          icon: 'fitness_center',
        ),
        ClinicFacilityPresentation(
          label: 'Cardiac imaging',
          icon: 'radiography',
        ),
      ],
      totalFacilitiesCount: 14,
      hours: ClinicHoursPresentation(
        weekday: '09:00 – 17:00',
        saturday: '09:00 – 13:00',
        sunday: 'Closed',
      ),
      emergencyHours: '24/7',
      languages: ['Arabic', 'French', 'English'],
      accessibility: ['Wheelchair accessible', 'Elevator'],
      verification: ClinicVerificationPresentation(
        badges: [
          'Licensed clinic',
          'Ministry of Health approved',
          'Cardiology specialist centre',
        ],
      ),
      localDemoImages: _demoImages,
    ),
    'clinic-rehab-001': ClinicPresentationMetadata(
      clinicType: 'Rehabilitation center',
      specialties: [
        'Physiotherapy',
        'Orthopedics',
        'Pain management',
        'Rheumatology',
      ],
      primarySpecialty: 'Physiotherapy',
      primarySpecialtyDescription:
          'Outpatient rehabilitation and supervised physiotherapy.',
      services: ['Physiotherapy', 'Rehabilitation care'],
      shortDescription:
          'Outpatient rehabilitation and supervised physiotherapy.',
      distance: '4.8 km away',
      locality: 'Ennasr',
      driveTime: '~12 min drive',
      availability: [
        ClinicAvailabilitySlot(
          label: 'Today',
          time: '14:00',
          isOpen: true,
        ),
        ClinicAvailabilitySlot(
          label: 'Tomorrow',
          time: '08:00',
          isOpen: true,
        ),
        ClinicAvailabilitySlot(
          label: 'Tomorrow',
          time: '10:30',
          isOpen: true,
        ),
      ],
      doctors: [
        ClinicDoctorPresentation(
          name: 'Dr. Sami Bouazizi',
          specialty: 'Physiotherapy',
          subtitle: 'Sports rehabilitation specialist',
          availabilityLabel: 'Available today · 14:00',
        ),
      ],
      insurance: ['CNAM', 'CNSS'],
      insuranceHighlight: 'STAR',
      facilities: [
        ClinicFacilityPresentation(
          label: 'Rehabilitation gym',
          icon: 'fitness_center',
        ),
        ClinicFacilityPresentation(
          label: 'Hydrotherapy',
          icon: 'pool',
        ),
        ClinicFacilityPresentation(
          label: 'Electrotherapy',
          icon: 'flash_on',
        ),
      ],
      totalFacilitiesCount: 8,
      hours: ClinicHoursPresentation(
        weekday: '08:00 – 18:00',
        saturday: '08:00 – 14:00',
        sunday: 'Closed',
      ),
      languages: ['Arabic', 'French'],
      accessibility: ['Wheelchair accessible', 'Ground floor access'],
      verification: ClinicVerificationPresentation(
        badges: [
          'Licensed clinic',
          'Ministry of Health approved',
        ],
      ),
      localDemoImages: _demoImages,
    ),
  };

  static ClinicPresentationMetadata forClinic(String clinicId) {
    return _byClinicId[clinicId] ?? defaultClinic;
  }
}

/// Combines backend truth with temporary presentation enrichment without
/// mutating the API model.
class PatientClinicPresentationItem {
  const PatientClinicPresentationItem({
    required this.clinic,
    required this.metadata,
  });

  final PatientClinicListItem clinic;
  final ClinicPresentationMetadata metadata;

  String get clinicId => clinic.clinicId;
  String get displayName => clinic.displayName;
  String? get city => clinic.city;
  String? get governorate => clinic.governorate;
  String? get primaryImageUrl => clinic.primaryImageUrl;
  bool get acceptingRequests => clinic.acceptingRequests;
  String get clinicType => metadata.clinicType;
  List<String> get specialties => metadata.specialties;
  String get primarySpecialty => metadata.primarySpecialty;
  List<String> get services => metadata.services;
  String get shortDescription => metadata.shortDescription;
  String? get distance => metadata.distance;
  String? get locality => metadata.locality;
  List<ClinicPresentationImage> get localDemoImages => metadata.localDemoImages;

  factory PatientClinicPresentationItem.fromBackend(
    PatientClinicListItem clinic,
  ) {
    return PatientClinicPresentationItem(
      clinic: clinic,
      metadata: ClinicPresentationCatalog.forClinic(clinic.clinicId),
    );
  }
}
