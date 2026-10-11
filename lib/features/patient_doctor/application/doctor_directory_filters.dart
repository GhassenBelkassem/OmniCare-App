import '../data/doctor_directory_models.dart';

/// Only filters owned by the certified P1-06 Doctor search contract.
class DoctorFilterSnapshot {
  const DoctorFilterSnapshot({
    this.specialty,
    this.governorate,
    this.city,
    this.maxDistanceKm,
    this.careCapability,
    this.cnamAccepted = false,
    this.privateInsuranceAccepted = false,
    this.acceptingNewPatients = false,
  });

  static const DoctorFilterSnapshot none = DoctorFilterSnapshot();

  final String? specialty;
  final String? governorate;
  final String? city;
  final double? maxDistanceKm;
  final DoctorCareCapability? careCapability;
  final bool cnamAccepted;
  final bool privateInsuranceAccepted;
  final bool acceptingNewPatients;

  bool get isActive => activeGroupCount > 0;

  int get activeGroupCount => [
    specialty,
    governorate,
    city,
    maxDistanceKm,
    careCapability,
    if (cnamAccepted) true,
    if (privateInsuranceAccepted) true,
    if (acceptingNewPatients) true,
  ].where((value) => value != null).length;

  DoctorFilterSnapshot copyWith({
    String? specialty,
    bool clearSpecialty = false,
    String? governorate,
    bool clearGovernorate = false,
    String? city,
    bool clearCity = false,
    double? maxDistanceKm,
    bool clearMaxDistanceKm = false,
    DoctorCareCapability? careCapability,
    bool clearCareCapability = false,
    bool? cnamAccepted,
    bool? privateInsuranceAccepted,
    bool? acceptingNewPatients,
  }) {
    return DoctorFilterSnapshot(
      specialty: clearSpecialty ? null : specialty ?? this.specialty,
      governorate: clearGovernorate ? null : governorate ?? this.governorate,
      city: clearCity ? null : city ?? this.city,
      maxDistanceKm: clearMaxDistanceKm
          ? null
          : maxDistanceKm ?? this.maxDistanceKm,
      careCapability: clearCareCapability
          ? null
          : careCapability ?? this.careCapability,
      cnamAccepted: cnamAccepted ?? this.cnamAccepted,
      privateInsuranceAccepted:
          privateInsuranceAccepted ?? this.privateInsuranceAccepted,
      acceptingNewPatients: acceptingNewPatients ?? this.acceptingNewPatients,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DoctorFilterSnapshot &&
        specialty == other.specialty &&
        governorate == other.governorate &&
        city == other.city &&
        maxDistanceKm == other.maxDistanceKm &&
        careCapability == other.careCapability &&
        cnamAccepted == other.cnamAccepted &&
        privateInsuranceAccepted == other.privateInsuranceAccepted &&
        acceptingNewPatients == other.acceptingNewPatients;
  }

  @override
  int get hashCode => Object.hash(
    specialty,
    governorate,
    city,
    maxDistanceKm,
    careCapability,
    cnamAccepted,
    privateInsuranceAccepted,
    acceptingNewPatients,
  );
}

String doctorCapabilityLabel(DoctorCareCapability value) => switch (value) {
  DoctorCareCapability.cabinet => 'Consultation au cabinet',
  DoctorCareCapability.homeVisit => 'Visite à domicile',
  DoctorCareCapability.urgentHome => 'Urgence à domicile',
  DoctorCareCapability.urgentCabinet => 'Urgence au cabinet',
};

String doctorDistanceLabel(double value) => '${value.toStringAsFixed(0)} km';
