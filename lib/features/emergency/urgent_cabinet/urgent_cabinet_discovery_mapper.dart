import 'urgent_cabinet_discovery_models.dart';
import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_doctor_filter.dart';
import 'urgent_cabinet_doctor_list_item.dart';

extension UrgentCabinetDiscoveryPairPresentation on UrgentCabinetDoctorCabinet {
  UrgentCabinetDoctorListItem toListItem() {
    return UrgentCabinetDoctorListItem(
      doctorId: doctorId,
      displayName: doctorDisplayName,
      specialty: specialty,
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      activeCabinetId: practiceLocationId,
      cabinetName: cabinetName,
      cabinetLocality: _locality(city: city, governorate: governorate),
      cabinetGovernorate: governorate,
      cabinetCity: city,
      cabinetAddress: cabinetAddress,
      distanceKm: patientToCabinetDistance?.kilometers,
      distanceIsStraightLine: patientToCabinetDistance != null,
      urgentCabinetFeeMilliTnd: urgentCabinetFeeMilliTnd,
      configurationRevision: configurationRevision,
      runtimeRevision: runtimeRevision,
      practiceLocationVersion: practiceLocationVersion,
      latitude: latitude,
      longitude: longitude,
    );
  }

  UrgentCabinetDoctorDetail toDetail({DateTime? evaluatedAt}) {
    return UrgentCabinetDoctorDetail(
      doctorId: doctorId,
      displayName: doctorDisplayName,
      specialty: specialty,
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      provenance: UrgentCabinetDoctorDetailProvenance.service,
      urgentCabinetFeeMilliTnd: urgentCabinetFeeMilliTnd,
      configurationRevision: configurationRevision,
      runtimeRevision: runtimeRevision,
      practiceLocationVersion: practiceLocationVersion,
      evaluatedAt: evaluatedAt,
      cabinets: [
        UrgentCabinetLocationDetail(
          cabinetId: practiceLocationId,
          name: cabinetName,
          locality: _locality(city: city, governorate: governorate),
          city: city,
          governorate: governorate,
          address: cabinetAddress,
          distanceKm: patientToCabinetDistance?.kilometers,
          latitude: latitude,
          longitude: longitude,
        ),
      ],
    );
  }
}

extension UrgentCabinetDiscoveryDetailPresentation
    on UrgentCabinetDiscoveryDetail {
  UrgentCabinetDoctorDetail toDetail() {
    final pair = doctorCabinet;
    final profile = publicProfile;
    final practice = selectedPractice;
    final practicalInformation = <String>[
      if (practice.wheelchairAccessible) 'Accès fauteuil roulant',
      ?practice.patientInstructions,
    ];
    return UrgentCabinetDoctorDetail(
      doctorId: pair.doctorId,
      displayName: pair.doctorDisplayName,
      specialty: pair.specialty,
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      provenance: UrgentCabinetDoctorDetailProvenance.service,
      portrait: profile.photoUrl == null
          ? null
          : UrgentCabinetDoctorImage.network(profile.photoUrl!),
      subSpecialties: profile.subSpecialties,
      experienceYears: profile.experienceYears,
      languages: profile.languages,
      biography: profile.biography,
      areasOfCare: profile.areasOfCare,
      expertise: profile.expertise,
      visitReasons: profile.visitReasons,
      urgentCabinetFeeMilliTnd: pair.urgentCabinetFeeMilliTnd,
      configurationRevision: pair.configurationRevision,
      runtimeRevision: pair.runtimeRevision,
      practiceLocationVersion: pair.practiceLocationVersion,
      evaluatedAt: evaluatedAt,
      cabinets: [
        UrgentCabinetLocationDetail(
          cabinetId: pair.practiceLocationId,
          name: pair.cabinetName,
          locality: _locality(city: pair.city, governorate: pair.governorate),
          city: pair.city,
          governorate: pair.governorate,
          address: pair.cabinetAddress,
          distanceKm: pair.patientToCabinetDistance?.kilometers,
          latitude: pair.latitude,
          longitude: pair.longitude,
          gallery: practice.gallery
              .map((media) => UrgentCabinetDoctorImage.network(media.url))
              .toList(growable: false),
          equipment: practice.equipment
              .map((equipment) => equipment.displayName)
              .toList(growable: false),
          accessibility: List.unmodifiable(practicalInformation),
        ),
      ],
    );
  }
}

extension UrgentCabinetDiscoveryFacetsPresentation
    on UrgentCabinetDiscoveryFacets {
  UrgentCabinetDoctorFilterOptions toFilterOptions() {
    return UrgentCabinetDoctorFilterOptions(
      specialties: specialties,
      governorates: locations.map((location) => location.governorate),
      citiesByGovernorate: {
        for (final location in locations) location.governorate: location.cities,
      },
    );
  }
}

String _locality({required String city, required String governorate}) {
  if (city.toLowerCase() == governorate.toLowerCase()) return city;
  return '$city, $governorate';
}
