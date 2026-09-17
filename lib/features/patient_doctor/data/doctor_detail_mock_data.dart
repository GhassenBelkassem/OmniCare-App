import 'doctor_models.dart';
import 'doctor_detail_models.dart';
import 'doctor_mock_data.dart';

/// Returns a map of doctor ID to [DoctorDetail] for the patient doctor detail
/// screen. This is a static mock — no backend API is used.
Map<String, DoctorDetail> createDoctorDetails() {
  final items = createDoctorListItems();
  final details = <String, DoctorDetail>{};

  for (final item in items) {
    details[item.id] = _detailForItem(item);
  }
  return details;
}

/// Returns the [DoctorDetail] for a given doctor ID, or null if not found.
DoctorDetail? getDoctorDetail(String id) {
  return createDoctorDetails()[id];
}

DoctorDetail _detailForItem(DoctorListItem item) {
  return switch (item.id) {
    'doc-1' => _doctorSarah(item),
    'doc-2' => _doctorKarim(item),
    'doc-3' => _doctorAmina(item),
    'doc-4' => _doctorRedha(item),
    'doc-5' => _doctorNadia(item),
    _ => _genericDoctor(item),
  };
}

DoctorDetail _doctorSarah(DoctorListItem item) => DoctorDetail(
  listItem: item,
  verified: true,
  areasOfCare: [
    'Bilan général',
    'Prévention',
    'Vaccination',
    'Suivi de chronicité',
    'Infections respiratoires',
    'Troubles du sommeil',
  ],
  expertise: ['Médecine préventive', 'Bilan général', 'Médecine familiale'],
  biography:
      'Médecin généraliste diplômée de la Faculté de Médecine de Tunis. '
      'Elle exerce depuis 12 ans en cabinet privé, avec un accent particulier '
      'sur la prévention, le suivi des maladies chroniques et la médecine '
      'familiale. Elle accompagne ses patients dans un suivi personnalisé '
      'et accessible.',
  patientAgeGroups: ['Adultes', 'Personnes âgées'],
  practiceLocations: [
    PracticeLocation(
      name: 'Cabinet Dr. Sarah Mansour',
      address: 'Rue Didouche Mourad, Alger',
      city: 'Alger',
      distanceKm: 2.3,
      galleryImages: [],
      openingHours: [
        PracticeOpeningHours(label: 'Lun – Ven', hours: '08:30 – 17:00'),
        PracticeOpeningHours(label: 'Sam', hours: '08:30 – 13:00'),
      ],
      equipment: [
        PracticeEquipment(label: 'ECG'),
        PracticeEquipment(label: 'Analyses sanguines'),
        PracticeEquipment(label: 'Nébulisation'),
      ],
      accessibility: ['Accessible PMR'],
      coverage: ['CNAM conventionné'],
      appointmentInstructions:
          'Apportez vos anciens résultats d\'analyses et votre carnet de '
          'santé si disponible.',
    ),
  ],
  nextAvailableLabel: "Aujourd'hui · 09:30",
  availability: _mockAvailability(),
);

DoctorDetail _doctorKarim(DoctorListItem item) => DoctorDetail(
  listItem: item,
  verified: true,
  areasOfCare: [
    'Vaccination',
    'Suivi de croissance',
    'Asthme pédiatrique',
    'Allergies alimentaires',
    'Infections ORL',
    'Éczéma',
  ],
  expertise: ['Pédiatrie générale', 'Dermatologie pédiatrique'],
  biography:
      'Pédiatre expérimenté spécialisé dans le suivi de croissance et les '
      'maladies allergiques de l\'enfant. Il propose un suivi bienveillant '
      'et rassurant pour les enfants et leurs familles.',
  patientAgeGroups: ['Enfants'],
  practiceLocations: [
    PracticeLocation(
      name: 'Cabinet Dr. Karim Bensalem',
      address: 'Rue Larbi Ben M\'hidi, Alger',
      city: 'Alger',
      distanceKm: 4.1,
      galleryImages: [],
      openingHours: [
        PracticeOpeningHours(label: 'Lun – Ven', hours: '09:00 – 18:00'),
      ],
      equipment: [
        PracticeEquipment(label: 'Nébulisation'),
        PracticeEquipment(label: 'Audiométrie'),
        PracticeEquipment(label: 'Test cutané'),
      ],
      accessibility: ['Ascenseur', 'Parking à proximité'],
      coverage: ['CNAM conventionné', 'Assurance acceptée'],
      appointmentInstructions: 'Apportez le carnet de santé de votre enfant.',
    ),
  ],
  nextAvailableLabel: "Demain · 10:00",
  availability: _mockAvailability(),
);

DoctorDetail _doctorAmina(DoctorListItem item) => DoctorDetail(
  listItem: item,
  verified: false,
  areasOfCare: [
    'Acné',
    'Psoriasis',
    'Dermatite atopique',
    'Dépistage cutané',
    'Teintes laser',
    'Chirurgie dermatologique',
  ],
  expertise: ['Dermatologie générale', 'Acné', 'Dermatologie pédiatrique'],
  biography:
      'Dermatologue formée en Tunisie et en France. Elle prend en charge '
      'les pathologies cutanées courantes avec une approche minutieuse et '
      'unsuivi personnalisé. Consultation en cabinet et téléconsultation.',
  patientAgeGroups: ['Adultes', 'Enfants'],
  practiceLocations: [
    PracticeLocation(
      name: 'Cabinet Dr. Amina Hadj',
      address: 'Boulevard Krim Belkacem, Alger',
      city: 'Alger',
      distanceKm: 5.7,
      galleryImages: [],
      openingHours: [
        PracticeOpeningHours(label: 'Lun – Mer', hours: '09:00 – 17:00'),
        PracticeOpeningHours(label: 'Jeu – Ven', hours: '14:00 – 20:00'),
        PracticeOpeningHours(label: 'Sam', hours: '09:00 – 13:00'),
      ],
      equipment: [
        PracticeEquipment(label: 'Dermatoscope'),
        PracticeEquipment(label: 'Cryothérapie'),
        PracticeEquipment(label: 'Petite chirurgie dermatologique'),
      ],
      coverage: [],
      appointmentInstructions:
          'Évitez d\'appliquer du maquillage sur la zone concernée avant '
          'le rendez-vous.',
    ),
  ],
  nextAvailableLabel: "Jeudi · 14:00",
  availability: _mockAvailability(),
);

DoctorDetail _doctorRedha(DoctorListItem item) => DoctorDetail(
  listItem: item,
  verified: true,
  areasOfCare: [
    'Hypertension',
    'Douleur thoracique',
    'Palpitations',
    'Cholestérol élevé',
    'Troubles du rythme',
    'Insuffisance cardiaque',
    'Évaluation du risque cardiovasculaire',
  ],
  expertise: [
    'Cardiologie interventionnelle',
    'Cardiologie du sport',
    'Troubles du rythme',
  ],
  biography:
      'Cardiologue spécialisé dans la prise en charge de l\'hypertension, '
      'des maladies coronariennes et des troubles du rythme. Sa pratique '
      'met l\'accent sur la prévention et le suivi cardiovasculaire à long '
      'terme. Il intervient également en cardiologie du sport.',
  patientAgeGroups: ['Adultes', 'Personnes âgées'],
  practiceLocations: [
    PracticeLocation(
      name: 'Cabinet Dr. Redha Amrani',
      address: 'Rue Abane Ramdane, Alger',
      city: 'Alger',
      distanceKm: 1.8,
      galleryImages: [],
      openingHours: [
        PracticeOpeningHours(label: 'Lun – Ven', hours: '08:00 – 16:00'),
      ],
      equipment: [
        PracticeEquipment(label: 'ECG'),
        PracticeEquipment(label: 'Échocardiographie'),
        PracticeEquipment(label: 'Holter ECG'),
        PracticeEquipment(label: 'Test d\'effort'),
        PracticeEquipment(label: 'Mesure ambulatoire de tension'),
      ],
      accessibility: ['Accessible PMR', 'Ascenseur', 'Parking à proximité'],
      coverage: ['CNAM conventionné', 'Assurance acceptée'],
      appointmentInstructions:
          'Apportez vos anciens ECG, analyses et votre liste de '
          'médicaments si disponibles.',
    ),
  ],
  nextAvailableLabel: "Aujourd'hui · 16:30",
  availability: _mockAvailability(),
);

DoctorDetail _doctorNadia(DoctorListItem item) => DoctorDetail(
  listItem: item,
  verified: true,
  areasOfCare: [
    'Suivi de grossesse',
    'Échographie prénatale',
    'Contraception',
    'Ménopause',
    'Infections gynécologiques',
    'Dépistage cervical',
  ],
  expertise: ['Grossesse et suivi prénatal', 'Gynécologie obstétricale'],
  biography:
      'Gynécologue obstétricienne avec 10 ans d\'expérience. Elle assure '
      'le suivi de grossesse, les échographies et la prise en charge des '
      'pathologies gynécologiques courantes dans un cadre bienveillant '
      'et professionnel.',
  patientAgeGroups: ['Adultes'],
  practiceLocations: [
    PracticeLocation(
      name: 'Cabinet Dr. Nadia Cherif',
      address: 'Rue Ahmed Bey, Alger',
      city: 'Alger',
      distanceKm: 3.5,
      galleryImages: [],
      openingHours: [
        PracticeOpeningHours(label: 'Lun – Ven', hours: '09:00 – 17:00'),
        PracticeOpeningHours(label: 'Sam', hours: '09:00 – 13:00'),
      ],
      equipment: [
        PracticeEquipment(label: 'Échographie'),
        PracticeEquipment(label: 'Colposcopie'),
        PracticeEquipment(label: 'Cardiotocographie'),
      ],
      accessibility: ['Ascenseur'],
      coverage: ['CNAM conventionné'],
      appointmentInstructions:
          'Pour un suivi de grossesse, apportez votre carnet de sante '
          'et vos examens precedents.',
    ),
  ],
  nextAvailableLabel: "Mercredi · 10:30",
  availability: _mockAvailability(),
);

DoctorDetail _genericDoctor(DoctorListItem item) => DoctorDetail(
  listItem: item,
  areasOfCare: item.visitReasons,
  expertise: item.subSpecialties,
  biography: null,
  patientAgeGroups: [item.patientAgeGroup ?? 'Adultes'],
  practiceLocations: [
    PracticeLocation(
      name: 'Cabinet ${item.name}',
      address: item.address ?? 'Adresse non renseignée',
      city: 'Alger',
      distanceKm: item.distanceKm,
    ),
  ],
  availability: _mockAvailability(),
);

/// Generates mock availability for the current week.
List<DoctorDayAvailability> _mockAvailability() {
  final now = DateTime.now();
  final days = <DoctorDayAvailability>[];

  for (var i = 0; i < 14; i++) {
    final date = DateTime(now.year, now.month, now.day + i);
    if (date.weekday == DateTime.sunday) continue;

    final slots = <DoctorAvailabilitySlot>[];

    if (date.weekday != DateTime.saturday) {
      slots.addAll([
        DoctorAvailabilitySlot(time: '09:00', timeOfDay: 'Matin'),
        DoctorAvailabilitySlot(time: '09:30', timeOfDay: 'Matin'),
        DoctorAvailabilitySlot(time: '10:30', timeOfDay: 'Matin'),
        DoctorAvailabilitySlot(time: '14:00', timeOfDay: 'Après-midi'),
        DoctorAvailabilitySlot(time: '15:30', timeOfDay: 'Après-midi'),
        DoctorAvailabilitySlot(time: '16:00', timeOfDay: 'Après-midi'),
      ]);
    } else {
      slots.addAll([
        DoctorAvailabilitySlot(time: '09:00', timeOfDay: 'Matin'),
        DoctorAvailabilitySlot(time: '10:00', timeOfDay: 'Matin'),
        DoctorAvailabilitySlot(time: '11:00', timeOfDay: 'Matin'),
      ]);
    }

    days.add(DoctorDayAvailability(date: date, slots: slots));
  }

  return days;
}
