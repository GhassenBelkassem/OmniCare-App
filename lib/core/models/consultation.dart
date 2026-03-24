class Consultation {
  final String? id;
  final String? doctorId;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? providerId;
  final String? providerType;
  final String? patientId;
  final String? patientName;
  final int? patientAge;
  final String? patientGender;
  final double? height;
  final double? weight;
  final String? bloodGroup;
  final String? relationship;
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
  final double? fee;
  final double? netAmount;
  final double? omnicareFee;
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
    this.patientAge,
    this.patientGender,
    this.height,
    this.weight,
    this.bloodGroup,
    this.relationship,
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

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _parseOptionalText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static dynamic _pick(Map<String, dynamic> json, String camel, String snake) {
    if (json.containsKey(snake)) return json[snake];
    if (json.containsKey(camel)) return json[camel];
    return null;
  }

  factory Consultation.fromJson(Map<String, dynamic> json) {
    final rawProviderId = _pick(json, 'providerId', 'provider_id')?.toString();
    final rawProviderType = _pick(
      json,
      'providerType',
      'provider_type',
    )?.toString();
    final rawId =
        (_pick(json, 'id', 'id')?.toString() ??
                _pick(json, 'consultationId', 'consultation_id')?.toString())
            ?.toString();

    return Consultation(
      id: rawId,
      doctorId: _pick(json, 'doctorId', 'doctor_id')?.toString(),
      doctorName: _pick(json, 'doctorName', 'doctor_name')?.toString(),
      doctorSpecialty: _pick(
        json,
        'doctorSpecialty',
        'doctor_specialty',
      )?.toString(),
      providerId: rawProviderId,
      providerType: rawProviderType,
      patientId: _pick(json, 'patientId', 'patient_id')?.toString(),
      patientName: _pick(json, 'patientName', 'patient_name')?.toString(),
      patientAge: _parseInt(_pick(json, 'patientAge', 'patient_age')),
      patientGender: _parseOptionalText(
        _pick(json, 'patientGender', 'patient_gender'),
      ),
      height: _parseDouble(_pick(json, 'height', 'height')),
      weight: _parseDouble(_pick(json, 'weight', 'weight')),
      bloodGroup: _parseOptionalText(_pick(json, 'bloodGroup', 'blood_group')),
      relationship: _parseOptionalText(
        _pick(json, 'relationship', 'relationship'),
      ),
      symptoms: _parseOptionalText(_pick(json, 'symptoms', 'symptoms')),
      diagnosis: _pick(json, 'diagnosis', 'diagnosis')?.toString(),
      treatment: _pick(json, 'treatment', 'treatment')?.toString(),
      status: _pick(json, 'status', 'status')?.toString(),
      painLevel: _parseInt(_pick(json, 'painLevel', 'pain_level')),
      affectedAreas: (_pick(json, 'affectedAreas', 'affected_areas') as List?)
          ?.map((e) => e.toString())
          .toList(),
      streetAddress: _pick(json, 'streetAddress', 'street_address')?.toString(),
      apartmentSuite: _pick(
        json,
        'apartmentSuite',
        'apartment_suite',
      )?.toString(),
      city: _pick(json, 'city', 'city')?.toString(),
      latitude: _parseDouble(_pick(json, 'latitude', 'latitude')),
      longitude: _parseDouble(_pick(json, 'longitude', 'longitude')),
      fee: _parseDouble(_pick(json, 'fee', 'fee')),
      netAmount: _parseDouble(_pick(json, 'netAmount', 'net_amount')),
      omnicareFee: _parseDouble(
        _pick(json, 'omnicareFee', 'omnicare_fee') ??
            _pick(json, 'platformFeeAmount', 'platform_fee_amount'),
      ),
      timestamp: _pick(json, 'timestamp', 'timestamp')?.toString(),
      allergyWarning: _pick(
        json,
        'allergyWarning',
        'allergy_warning',
      )?.toString(),
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
