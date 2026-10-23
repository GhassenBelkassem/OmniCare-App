import 'package:flutter/foundation.dart';

enum DoctorUrgentCabinetDataProvenance { developmentFixture, service }

enum DoctorUrgentCabinetFeeProvenance { developmentFixture, service }

enum DoctorUrgentCabinetRequestStatus { newRequest, committed }

enum DoctorUrgentCabinetAllowedAction { accept, decline }

enum DoctorUrgentCabinetBodyArea {
  head,
  neck,
  chest,
  abdomen,
  back,
  pelvis,
  upperLimb,
  lowerLimb,
  general;

  static DoctorUrgentCabinetBodyArea parse(String value) => switch (value) {
    'HEAD' => head,
    'NECK' => neck,
    'CHEST' => chest,
    'ABDOMEN' => abdomen,
    'BACK' => back,
    'PELVIS' => pelvis,
    'UPPER_LIMB' => upperLimb,
    'LOWER_LIMB' => lowerLimb,
    'GENERAL' => general,
    _ => throw FormatException('Unknown urgent CABINET body area: $value.'),
  };

  String get frenchLabel => switch (this) {
    head => 'Tête',
    neck => 'Cou',
    chest => 'Thorax',
    abdomen => 'Abdomen',
    back => 'Dos',
    pelvis => 'Bassin',
    upperLimb => 'Membre supérieur',
    lowerLimb => 'Membre inférieur',
    general => 'État général',
  };
}

@immutable
class DoctorUrgentCabinetDevelopmentFixtureKey {
  factory DoctorUrgentCabinetDevelopmentFixtureKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'A fixture key is required.');
    }
    return DoctorUrgentCabinetDevelopmentFixtureKey._(normalized);
  }

  const DoctorUrgentCabinetDevelopmentFixtureKey._(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is DoctorUrgentCabinetDevelopmentFixtureKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

@immutable
class DoctorUrgentCabinetDevelopmentCabinetKey {
  factory DoctorUrgentCabinetDevelopmentCabinetKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'A development cabinet key is required.',
      );
    }
    return DoctorUrgentCabinetDevelopmentCabinetKey._(normalized);
  }

  const DoctorUrgentCabinetDevelopmentCabinetKey._(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is DoctorUrgentCabinetDevelopmentCabinetKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

@immutable
class DoctorUrgentCabinetSnapshot {
  factory DoctorUrgentCabinetSnapshot({
    required String name,
    required String address,
    required String city,
    required String governorate,
  }) {
    final normalizedName = name.trim();
    final normalizedAddress = address.trim();
    final normalizedCity = city.trim();
    final normalizedGovernorate = governorate.trim();
    if (normalizedName.isEmpty ||
        normalizedAddress.isEmpty ||
        normalizedCity.isEmpty ||
        normalizedGovernorate.isEmpty) {
      throw ArgumentError('A complete local cabinet snapshot is required.');
    }
    return DoctorUrgentCabinetSnapshot._(
      name: normalizedName,
      address: normalizedAddress,
      city: normalizedCity,
      governorate: normalizedGovernorate,
    );
  }

  const DoctorUrgentCabinetSnapshot._({
    required this.name,
    required this.address,
    required this.city,
    required this.governorate,
  });

  static DoctorUrgentCabinetSnapshot? tryCreate({
    required String name,
    required String address,
    required String city,
    required String governorate,
  }) {
    try {
      return DoctorUrgentCabinetSnapshot(
        name: name,
        address: address,
        city: city,
        governorate: governorate,
      );
    } on ArgumentError {
      return null;
    }
  }

  final String name;
  final String address;
  final String city;
  final String governorate;

  String get normalizedFingerprint =>
      [name, address, city, governorate].map(_normalizeCabinetValue).join('|');

  bool matches(DoctorUrgentCabinetSnapshot other) =>
      normalizedFingerprint == other.normalizedFingerprint;
}

@immutable
sealed class DoctorUrgentCabinetTargetIdentity {
  const DoctorUrgentCabinetTargetIdentity();
}

@immutable
final class DoctorUrgentCabinetDevelopmentTargetIdentity
    extends DoctorUrgentCabinetTargetIdentity {
  const DoctorUrgentCabinetDevelopmentTargetIdentity(this.key);

  final DoctorUrgentCabinetDevelopmentCabinetKey key;
}

@immutable
final class DoctorUrgentCabinetServerTargetIdentity
    extends DoctorUrgentCabinetTargetIdentity {
  factory DoctorUrgentCabinetServerTargetIdentity(String cabinetId) {
    final normalized = cabinetId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        cabinetId,
        'cabinetId',
        'An authoritative cabinet ID is required.',
      );
    }
    return DoctorUrgentCabinetServerTargetIdentity._(normalized);
  }

  const DoctorUrgentCabinetServerTargetIdentity._(this.cabinetId);

  final String cabinetId;
}

@immutable
class DoctorUrgentCabinetPatientProjection {
  const DoctorUrgentCabinetPatientProjection.masked()
    : label = 'Patient concerné',
      disclosure = 'Identité non communiquée à ce stade';

  final String label;
  final String disclosure;
}

@immutable
class DoctorUrgentCabinetFeeSnapshot {
  factory DoctorUrgentCabinetFeeSnapshot({
    required int amountMilliTnd,
    required String currencyCode,
    required DoctorUrgentCabinetFeeProvenance provenance,
  }) {
    final currency = currencyCode.trim().toUpperCase();
    if (amountMilliTnd < 0) {
      throw ArgumentError.value(
        amountMilliTnd,
        'amountMilliTnd',
        'The fee cannot be negative.',
      );
    }
    if (currency != 'TND') {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Urgent CABINET fixtures currently require TND.',
      );
    }
    return DoctorUrgentCabinetFeeSnapshot._(
      amountMilliTnd: amountMilliTnd,
      currencyCode: currency,
      provenance: provenance,
    );
  }

  const DoctorUrgentCabinetFeeSnapshot._({
    required this.amountMilliTnd,
    required this.currencyCode,
    required this.provenance,
  });

  final int amountMilliTnd;
  final String currencyCode;
  final DoctorUrgentCabinetFeeProvenance provenance;

  String get formattedAmount {
    final whole = amountMilliTnd ~/ 1000;
    final fraction = (amountMilliTnd % 1000).toString().padLeft(3, '0');
    final groupedWhole = _groupThousands(whole.toString());
    return '$groupedWhole,$fraction DT';
  }
}

@immutable
class DoctorUrgentCabinetRequest {
  factory DoctorUrgentCabinetRequest({
    required DoctorUrgentCabinetDevelopmentFixtureKey? developmentFixtureKey,
    required String targetDoctorId,
    required DoctorUrgentCabinetTargetIdentity targetCabinetIdentity,
    required DoctorUrgentCabinetSnapshot cabinet,
    required DoctorUrgentCabinetPatientProjection patient,
    required DoctorUrgentCabinetFeeSnapshot fee,
    required DoctorUrgentCabinetDataProvenance dataProvenance,
    required DoctorUrgentCabinetRequestStatus status,
    String? serverRequestReference,
    int? serverRequestRevision,
    List<DoctorUrgentCabinetBodyArea> bodyAreas = const [],
    int? painScore,
    String? shortDescription,
    DateTime? createdAt,
    DateTime? responseDeadlineAt,
    DateTime? evaluatedAt,
    String? serverCommitmentReference,
    Set<DoctorUrgentCabinetAllowedAction>? allowedActions,
  }) {
    final doctorId = targetDoctorId.trim();
    final serverReference = serverRequestReference?.trim();
    if (doctorId.isEmpty) {
      throw ArgumentError.value(
        targetDoctorId,
        'targetDoctorId',
        'A target Doctor ID is required.',
      );
    }
    final isDevelopment =
        dataProvenance == DoctorUrgentCabinetDataProvenance.developmentFixture;
    final normalizedActions =
        Set<DoctorUrgentCabinetAllowedAction>.unmodifiable(
          allowedActions ??
              (status == DoctorUrgentCabinetRequestStatus.newRequest
                  ? const {
                      DoctorUrgentCabinetAllowedAction.accept,
                      DoctorUrgentCabinetAllowedAction.decline,
                    }
                  : const <DoctorUrgentCabinetAllowedAction>{}),
        );
    final normalizedDescription = shortDescription?.trim();
    final validPendingActions =
        normalizedActions.length == 2 ||
        (normalizedActions.length == 1 &&
            normalizedActions.contains(
              DoctorUrgentCabinetAllowedAction.decline,
            ));
    if ((status == DoctorUrgentCabinetRequestStatus.newRequest &&
            !validPendingActions) ||
        (status == DoctorUrgentCabinetRequestStatus.committed &&
            normalizedActions.isNotEmpty)) {
      throw ArgumentError(
        'Urgent CABINET actions must be ACCEPT+DECLINE or DECLINE for a '
        'pending request, and empty for a commitment.',
      );
    }
    if (isDevelopment) {
      if (developmentFixtureKey == null ||
          targetCabinetIdentity
              is! DoctorUrgentCabinetDevelopmentTargetIdentity ||
          fee.provenance !=
              DoctorUrgentCabinetFeeProvenance.developmentFixture ||
          (serverReference != null && serverReference.isNotEmpty)) {
        throw ArgumentError(
          'Development requests require fixture identities, fixture fee '
          'provenance, and no server request reference.',
        );
      }
    } else {
      final commitmentReference = serverCommitmentReference?.trim();
      if (developmentFixtureKey != null ||
          targetCabinetIdentity is! DoctorUrgentCabinetServerTargetIdentity ||
          fee.provenance != DoctorUrgentCabinetFeeProvenance.service ||
          serverReference == null ||
          serverReference.isEmpty) {
        throw ArgumentError(
          'Service requests require authoritative server identities and '
          'service fee provenance.',
        );
      }
      if (status == DoctorUrgentCabinetRequestStatus.newRequest) {
        if (serverRequestRevision == null ||
            serverRequestRevision < 0 ||
            bodyAreas.isEmpty ||
            painScore == null ||
            painScore < 0 ||
            painScore > 10 ||
            normalizedDescription == null ||
            normalizedDescription.isEmpty ||
            createdAt == null ||
            evaluatedAt == null ||
            (commitmentReference != null && commitmentReference.isNotEmpty)) {
          throw ArgumentError(
            'Service pending requests require revision, structured triage, '
            'timestamps, and no commitment identity.',
          );
        }
      } else if (commitmentReference == null ||
          commitmentReference.isEmpty ||
          evaluatedAt == null) {
        throw ArgumentError(
          'Recovered service commitments require commitment identity and '
          'evaluation time.',
        );
      }
    }

    return DoctorUrgentCabinetRequest._(
      developmentFixtureKey: developmentFixtureKey,
      targetDoctorId: doctorId,
      targetCabinetIdentity: targetCabinetIdentity,
      cabinet: cabinet,
      patient: patient,
      fee: fee,
      dataProvenance: dataProvenance,
      status: status,
      serverRequestReference: serverReference == null || serverReference.isEmpty
          ? null
          : serverReference,
      serverRequestRevision: serverRequestRevision,
      bodyAreas: List.unmodifiable(bodyAreas),
      painScore: painScore,
      shortDescription: normalizedDescription,
      createdAt: createdAt,
      responseDeadlineAt: responseDeadlineAt,
      evaluatedAt: evaluatedAt,
      serverCommitmentReference: serverCommitmentReference?.trim(),
      allowedActions: normalizedActions,
    );
  }

  const DoctorUrgentCabinetRequest._({
    required this.developmentFixtureKey,
    required this.targetDoctorId,
    required this.targetCabinetIdentity,
    required this.cabinet,
    required this.patient,
    required this.fee,
    required this.dataProvenance,
    required this.status,
    required this.serverRequestReference,
    required this.serverRequestRevision,
    required this.bodyAreas,
    required this.painScore,
    required this.shortDescription,
    required this.createdAt,
    required this.responseDeadlineAt,
    required this.evaluatedAt,
    required this.serverCommitmentReference,
    required this.allowedActions,
  });

  final DoctorUrgentCabinetDevelopmentFixtureKey? developmentFixtureKey;
  final String targetDoctorId;
  final DoctorUrgentCabinetTargetIdentity targetCabinetIdentity;
  final DoctorUrgentCabinetSnapshot cabinet;
  final DoctorUrgentCabinetPatientProjection patient;
  final DoctorUrgentCabinetFeeSnapshot fee;
  final DoctorUrgentCabinetDataProvenance dataProvenance;
  final DoctorUrgentCabinetRequestStatus status;
  final String? serverRequestReference;
  final int? serverRequestRevision;
  final List<DoctorUrgentCabinetBodyArea> bodyAreas;
  final int? painScore;
  final String? shortDescription;
  final DateTime? createdAt;
  final DateTime? responseDeadlineAt;
  final DateTime? evaluatedAt;
  final String? serverCommitmentReference;
  final Set<DoctorUrgentCabinetAllowedAction> allowedActions;

  bool get canAccept =>
      allowedActions.contains(DoctorUrgentCabinetAllowedAction.accept);

  bool get canDecline =>
      allowedActions.contains(DoctorUrgentCabinetAllowedAction.decline);

  bool get isDevelopmentFixture =>
      dataProvenance == DoctorUrgentCabinetDataProvenance.developmentFixture;

  String get stableIdentity =>
      developmentFixtureKey?.value ?? serverRequestReference!;

  String get structuredTriageLabel {
    if (bodyAreas.isEmpty || painScore == null) {
      return 'Aucune donnée de triage supplémentaire autorisée.';
    }
    final areas = bodyAreas.map((area) => area.frenchLabel).join(', ');
    return 'Zone${bodyAreas.length == 1 ? '' : 's'} : $areas · '
        'douleur $painScore/10.';
  }
}

String _normalizeCabinetValue(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
