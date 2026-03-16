class Consultation {
  final String? id;
  final String? doctorId;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? providerId;
  final String? providerType;
  final String? patientId;
  final String? patientName;
  final String? symptoms;
  final String? diagnosis;
  final String? treatment;
  final String? status;
  final int? painLevel;
  final List<String>? affectedAreas;
  final String? streetAddress;
  final String? apartmentSuite;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? fee;
  final String? netAmount;
  final String? omnicareFee;
  final String? timestamp;
  final String? allergyWarning;

  const Consultation({
    this.id,
    this.doctorId,
    this.doctorName,
    this.doctorSpecialty,
    this.providerId,
    this.providerType,
    this.patientId,
    this.patientName,
    this.symptoms,
    this.diagnosis,
    this.treatment,
    this.status,
    this.painLevel,
    this.affectedAreas,
    this.streetAddress,
    this.apartmentSuite,
    this.city,
    this.latitude,
    this.longitude,
    this.fee,
    this.netAmount,
    this.omnicareFee,
    this.timestamp,
    this.allergyWarning,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    final rawProviderId = json['providerId']?.toString();
    final rawProviderType = json['providerType']?.toString();

    return Consultation(
      id: json['id']?.toString(),
      doctorId: json['doctorId']?.toString(),
      doctorName: json['doctorName']?.toString(),
      doctorSpecialty: json['doctorSpecialty']?.toString(),
      providerId: rawProviderId,
      providerType: rawProviderType,
      patientId: json['patientId']?.toString(),
      patientName: json['patientName']?.toString(),
      symptoms: json['symptoms']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      treatment: json['treatment']?.toString(),
      status: json['status']?.toString(),
      painLevel: json['painLevel'] is int
          ? json['painLevel'] as int
          : int.tryParse(json['painLevel']?.toString() ?? ''),
      affectedAreas: (json['affectedAreas'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      streetAddress: json['streetAddress']?.toString(),
      apartmentSuite: json['apartmentSuite']?.toString(),
      city: json['city']?.toString(),
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : double.tryParse(json['longitude']?.toString() ?? ''),
      fee: json['fee']?.toString(),
      netAmount: json['netAmount']?.toString(),
      omnicareFee: json['omnicareFee']?.toString(),
      timestamp: json['timestamp']?.toString(),
      allergyWarning: json['allergyWarning']?.toString(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'doctorId': doctorId,
      'providerId': providerId,
      'patientId': patientId,
      'symptoms': symptoms,
      'painLevel': painLevel,
      'affectedAreas': affectedAreas,
      'streetAddress': streetAddress,
      'apartmentSuite': apartmentSuite,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
