import 'dart:async';

import 'package:flutter/foundation.dart';

import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_doctor_source.dart';
import 'urgent_cabinet_doctor_list_item.dart';
import 'urgent_cabinet_request_review.dart';

export 'urgent_cabinet_doctor_source.dart';

enum UrgentCabinetDoctorFixtureScenario {
  populated,
  loading,
  empty,
  noEligibleDoctors,
  error,
}

/// Development-only synthetic data for P4 UI work.
///
/// It must never be treated as live availability or silently enabled in a
/// profile/release build.
class UrgentCabinetDoctorFixtureSource extends UrgentCabinetDoctorSource {
  const UrgentCabinetDoctorFixtureSource({
    this.scenario = UrgentCabinetDoctorFixtureScenario.populated,
  });

  final UrgentCabinetDoctorFixtureScenario scenario;

  @override
  bool get isDevelopmentFixture => true;

  @override
  Future<List<UrgentCabinetDoctorListItem>> loadDoctors() {
    return switch (scenario) {
      UrgentCabinetDoctorFixtureScenario.populated => Future.value(
        developmentDoctors,
      ),
      UrgentCabinetDoctorFixtureScenario.loading =>
        Completer<List<UrgentCabinetDoctorListItem>>().future,
      UrgentCabinetDoctorFixtureScenario.empty => Future.value(const []),
      UrgentCabinetDoctorFixtureScenario.noEligibleDoctors => Future.value(
        developmentUnavailableDoctors,
      ),
      UrgentCabinetDoctorFixtureScenario.error => Future.error(
        const UrgentCabinetDoctorFixtureException(),
      ),
    };
  }

  @override
  Future<UrgentCabinetDoctorDetail?> loadDoctorDetail(String doctorId) {
    return switch (scenario) {
      UrgentCabinetDoctorFixtureScenario.populated => Future.value(
        _developmentDetailById(doctorId),
      ),
      UrgentCabinetDoctorFixtureScenario.loading =>
        Completer<UrgentCabinetDoctorDetail?>().future,
      UrgentCabinetDoctorFixtureScenario.empty ||
      UrgentCabinetDoctorFixtureScenario.noEligibleDoctors => Future.value(
        null,
      ),
      UrgentCabinetDoctorFixtureScenario.error => Future.error(
        const UrgentCabinetDoctorFixtureException(),
      ),
    };
  }

  @override
  Future<UrgentCabinetFeeQuote?> loadUrgentCabinetFeeQuote({
    required String doctorId,
    required String cabinetId,
  }) {
    return switch (scenario) {
      UrgentCabinetDoctorFixtureScenario.populated => Future.value(
        _developmentFeeBySelection(doctorId, cabinetId),
      ),
      UrgentCabinetDoctorFixtureScenario.loading =>
        Completer<UrgentCabinetFeeQuote?>().future,
      UrgentCabinetDoctorFixtureScenario.empty ||
      UrgentCabinetDoctorFixtureScenario.noEligibleDoctors => Future.value(
        null,
      ),
      UrgentCabinetDoctorFixtureScenario.error => Future.error(
        const UrgentCabinetDoctorFixtureException(),
      ),
    };
  }

  static const developmentDoctors = <UrgentCabinetDoctorListItem>[
    UrgentCabinetDoctorListItem(
      doctorId: 'p4-demo-doctor-amine-ben-salah',
      displayName: 'Dr. Amine Ben Salah',
      specialty: 'Médecine générale',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      activeCabinetId: 'p4-demo-cabinet-lac-1',
      cabinetName: 'Cabinet Les Berges du Lac',
      cabinetLocality: 'Les Berges du Lac, Tunis',
      cabinetGovernorate: 'Tunis',
      cabinetCity: 'Tunis',
      cabinetAddress: 'Rue du Lac Victoria',
      distanceKm: 1.8,
    ),
    UrgentCabinetDoctorListItem(
      doctorId: 'p4-demo-doctor-ines-trabelsi',
      displayName: 'Dr. Inès Trabelsi',
      specialty: 'Médecine interne',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      activeCabinetId: 'p4-demo-cabinet-menzah-1',
      cabinetName: 'Cabinet El Menzah',
      cabinetLocality: 'El Menzah 6, Ariana',
      cabinetGovernorate: 'Ariana',
      cabinetCity: 'Ariana',
      cabinetAddress: 'Avenue Othman Ibn Affan',
      distanceKm: 3.4,
    ),
    UrgentCabinetDoctorListItem(
      doctorId: 'p4-demo-doctor-youssef-gharbi',
      displayName: 'Dr. Youssef Gharbi',
      specialty: 'Médecine familiale',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      activeCabinetId: 'p4-demo-cabinet-lafayette-1',
      cabinetName: 'Centre médical Lafayette',
      cabinetLocality: 'Lafayette, Tunis',
      cabinetGovernorate: 'Tunis',
      cabinetCity: 'Tunis',
      cabinetAddress: 'Rue de Palestine',
    ),
  ];

  static const developmentUnavailableDoctors = <UrgentCabinetDoctorListItem>[
    UrgentCabinetDoctorListItem(
      doctorId: 'p4-demo-doctor-ineligible',
      displayName: 'Dr. Exemple Inéligible',
      specialty: 'Médecine générale',
      eligibility: UrgentCabinetEligibility.ineligible,
      availability: UrgentCabinetAvailability.availableNow,
      activeCabinetId: 'p4-demo-cabinet-ineligible',
      cabinetName: 'Cabinet de démonstration',
      cabinetLocality: 'Tunis',
      cabinetGovernorate: 'Tunis',
      cabinetCity: 'Tunis',
    ),
    UrgentCabinetDoctorListItem(
      doctorId: 'p4-demo-doctor-unavailable',
      displayName: 'Dr. Exemple Indisponible',
      specialty: 'Médecine interne',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.unavailable,
      activeCabinetId: 'p4-demo-cabinet-unavailable',
      cabinetName: 'Cabinet de démonstration',
      cabinetLocality: 'Ariana',
      cabinetGovernorate: 'Ariana',
      cabinetCity: 'Ariana',
    ),
  ];

  static UrgentCabinetDoctorDetail? _developmentDetailById(String doctorId) {
    for (final detail in developmentDoctorDetails) {
      if (detail.doctorId == doctorId.trim()) return detail;
    }
    return null;
  }

  static UrgentCabinetFeeQuote? _developmentFeeBySelection(
    String doctorId,
    String cabinetId,
  ) {
    final normalizedDoctorId = doctorId.trim();
    final normalizedCabinetId = cabinetId.trim();
    for (final quote in developmentFeeQuotes) {
      if (quote.doctorId == normalizedDoctorId &&
          quote.cabinetId == normalizedCabinetId) {
        return quote;
      }
    }
    return null;
  }

  static const developmentFeeQuotes = <UrgentCabinetFeeQuote>[
    UrgentCabinetFeeQuote(
      doctorId: 'p4-demo-doctor-amine-ben-salah',
      cabinetId: 'p4-demo-cabinet-lac-1',
      amountMilliTnd: 75000,
      currencyCode: 'TND',
      provenance: UrgentCabinetFeeProvenance.developmentFixture,
      configurationRevision: 11,
      runtimeRevision: 21,
      practiceLocationVersion: 31,
    ),
    UrgentCabinetFeeQuote(
      doctorId: 'p4-demo-doctor-ines-trabelsi',
      cabinetId: 'p4-demo-cabinet-menzah-1',
      amountMilliTnd: 75000,
      currencyCode: 'TND',
      provenance: UrgentCabinetFeeProvenance.developmentFixture,
      configurationRevision: 12,
      runtimeRevision: 22,
      practiceLocationVersion: 32,
    ),
    UrgentCabinetFeeQuote(
      doctorId: 'p4-demo-doctor-youssef-gharbi',
      cabinetId: 'p4-demo-cabinet-lafayette-1',
      amountMilliTnd: 75000,
      currencyCode: 'TND',
      provenance: UrgentCabinetFeeProvenance.developmentFixture,
      configurationRevision: 13,
      runtimeRevision: 23,
      practiceLocationVersion: 33,
    ),
  ];

  static const developmentDoctorDetails = <UrgentCabinetDoctorDetail>[
    UrgentCabinetDoctorDetail(
      doctorId: 'p4-demo-doctor-amine-ben-salah',
      displayName: 'Dr. Amine Ben Salah',
      specialty: 'Médecine générale',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      provenance: UrgentCabinetDoctorDetailProvenance.developmentFixture,
      urgentCabinetFeeMilliTnd: 75000,
      configurationRevision: 11,
      runtimeRevision: 21,
      practiceLocationVersion: 31,
      subSpecialties: ['Soins de premier recours'],
      languages: ['Arabe', 'Français'],
      biography:
          'Profil de démonstration utilisé uniquement pour valider la présentation '
          'du parcours urgent au cabinet. Les informations professionnelles '
          'définitives seront fournies par le futur service P4 approuvé. Ce texte '
          'synthétique permet aussi de vérifier l’affichage progressif des '
          'descriptions longues, sans attribuer de qualification ou de parcours '
          'professionnel fictif à un médecin réel.',
      areasOfCare: [
        'Évaluation de symptômes aigus',
        'Soins de médecine générale',
      ],
      expertise: ['Orientation clinique', 'Suivi de premier recours'],
      visitReasons: [
        'Symptômes apparus récemment',
        'Besoin d’une évaluation médicale rapide',
      ],
      cabinets: [
        UrgentCabinetLocationDetail(
          cabinetId: 'p4-demo-cabinet-annexe',
          name: 'Cabinet annexe de démonstration',
          locality: 'Centre urbain nord, Tunis',
          city: 'Tunis',
          governorate: 'Tunis',
        ),
        UrgentCabinetLocationDetail(
          cabinetId: 'p4-demo-cabinet-lac-1',
          name: 'Cabinet Les Berges du Lac',
          locality: 'Les Berges du Lac, Tunis',
          city: 'Tunis',
          governorate: 'Tunis',
          address: 'Rue du Lac Victoria',
          distanceKm: 1.8,
          gallery: [
            UrgentCabinetDoctorImage.asset(
              'assets/images/clinics/demo/clinic_reception.jpg',
            ),
            UrgentCabinetDoctorImage.asset(
              'assets/images/clinics/demo/clinic_room.jpg',
            ),
            UrgentCabinetDoctorImage.asset(
              'assets/images/clinics/demo/clinic_waiting.jpg',
            ),
          ],
          equipment: ['Tensiomètre', 'Oxymètre', 'Électrocardiographe'],
          openingHours: [
            UrgentCabinetOpeningHours(
              day: 'Lundi – Vendredi',
              hours: '08:00 – 18:00',
            ),
            UrgentCabinetOpeningHours(day: 'Samedi', hours: '08:00 – 13:00'),
          ],
          accessibility: ['Accès adapté aux personnes à mobilité réduite'],
        ),
      ],
    ),
    UrgentCabinetDoctorDetail(
      doctorId: 'p4-demo-doctor-ines-trabelsi',
      displayName: 'Dr. Inès Trabelsi',
      specialty: 'Médecine interne',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      provenance: UrgentCabinetDoctorDetailProvenance.developmentFixture,
      urgentCabinetFeeMilliTnd: 75000,
      configurationRevision: 12,
      runtimeRevision: 22,
      practiceLocationVersion: 32,
      languages: ['Arabe', 'Français'],
      biography:
          'Profil de démonstration. Les données professionnelles réelles seront '
          'chargées depuis le futur service P4.',
      areasOfCare: ['Évaluation clinique urgente'],
      visitReasons: ['Symptômes nécessitant un avis médical rapide'],
      cabinets: [
        UrgentCabinetLocationDetail(
          cabinetId: 'p4-demo-cabinet-menzah-1',
          name: 'Cabinet El Menzah',
          locality: 'El Menzah 6, Ariana',
          city: 'Ariana',
          governorate: 'Ariana',
          address: 'Avenue Othman Ibn Affan',
          distanceKm: 3.4,
          gallery: [
            UrgentCabinetDoctorImage.asset(
              'assets/images/clinics/demo/clinic_exterior.jpg',
            ),
            UrgentCabinetDoctorImage.asset(
              'assets/images/clinics/demo/clinic_hallway.jpg',
            ),
          ],
          openingHours: [
            UrgentCabinetOpeningHours(
              day: 'Lundi – Vendredi',
              hours: '09:00 – 17:00',
            ),
          ],
        ),
      ],
    ),
    UrgentCabinetDoctorDetail(
      doctorId: 'p4-demo-doctor-youssef-gharbi',
      displayName: 'Dr. Youssef Gharbi',
      specialty: 'Médecine familiale',
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      provenance: UrgentCabinetDoctorDetailProvenance.developmentFixture,
      urgentCabinetFeeMilliTnd: 75000,
      configurationRevision: 13,
      runtimeRevision: 23,
      practiceLocationVersion: 33,
      cabinets: [
        UrgentCabinetLocationDetail(
          cabinetId: 'p4-demo-cabinet-lafayette-1',
          name: 'Centre médical Lafayette',
          locality: 'Lafayette, Tunis',
          city: 'Tunis',
          governorate: 'Tunis',
          address: 'Rue de Palestine',
        ),
      ],
    ),
  ];
}

class UrgentCabinetDoctorSources {
  const UrgentCabinetDoctorSources._();

  static UrgentCabinetDoctorSource forCurrentBuild() {
    return forBuild(enableDevelopmentFixtures: kDebugMode);
  }

  @visibleForTesting
  static UrgentCabinetDoctorSource forBuild({
    required bool enableDevelopmentFixtures,
  }) {
    return enableDevelopmentFixtures
        ? const UrgentCabinetDoctorFixtureSource()
        : const UrgentCabinetDoctorUnavailableSource();
  }
}

class UrgentCabinetDoctorFixtureException implements Exception {
  const UrgentCabinetDoctorFixtureException();
}
