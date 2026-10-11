import '../domain/urgent_journey_models.dart';

enum SyntheticCabinetDirectoryStatus { loading, ready, empty, failure }

final class SyntheticCabinetDirectorySnapshot {
  SyntheticCabinetDirectorySnapshot({
    required this.status,
    required Iterable<CabinetTargetProjection> candidates,
    this.query = '',
    this.safeErrorKey,
  }) : candidates = List.unmodifiable(candidates);

  final SyntheticCabinetDirectoryStatus status;
  final List<CabinetTargetProjection> candidates;
  final String query;
  final String? safeErrorKey;
}

/// Searchable deterministic urgent directory. This is not scheduled care and
/// has no slot, booking, network, or availability authority.
final class SyntheticCabinetDirectorySource {
  SyntheticCabinetDirectorySource({
    this.initialStatus = SyntheticCabinetDirectoryStatus.ready,
  });

  final SyntheticCabinetDirectoryStatus initialStatus;

  static final candidates = <CabinetTargetProjection>[
    CabinetTargetProjection(
      doctorRef: DoctorPublicUiRef('syn_cabinet_doctor_1'),
      cabinetRef: CabinetPublicUiRef('syn_cabinet_1'),
      doctorDisplayName: 'Dr Lina Démo',
      cabinetDisplayName: 'Cabinet Lac Démo',
      publicAddress: 'Les Berges du Lac, Tunis',
      specialtyLabel: 'Médecine générale',
      urgentCapabilityLabel: 'Consultation urgente au cabinet',
      quote: UrgentFeeQuote(
        context: UrgentFeeContext.cabinet,
        amountMinor: 8000,
        currency: 'TND',
        feeVersion: 2,
      ),
    ),
    CabinetTargetProjection(
      doctorRef: DoctorPublicUiRef('syn_cabinet_doctor_2'),
      cabinetRef: CabinetPublicUiRef('syn_cabinet_2'),
      doctorDisplayName: 'Dr Sami Démo',
      cabinetDisplayName: 'Cabinet Centre Démo',
      publicAddress: 'Centre urbain nord, Tunis',
      specialtyLabel: 'Médecine familiale',
      urgentCapabilityLabel: 'Consultation urgente au cabinet',
      quote: UrgentFeeQuote(
        context: UrgentFeeContext.cabinet,
        amountMinor: 9500,
        currency: 'TND',
        feeVersion: 5,
      ),
    ),
  ];

  SyntheticCabinetDirectorySnapshot search([String query = '']) {
    if (initialStatus != SyntheticCabinetDirectoryStatus.ready) {
      return SyntheticCabinetDirectorySnapshot(
        status: initialStatus,
        candidates: const [],
        query: query,
        safeErrorKey: initialStatus == SyntheticCabinetDirectoryStatus.failure
            ? 'p4_directory_failure'
            : null,
      );
    }
    final normalized = query.trim().toLowerCase();
    final filtered = candidates.where(
      (target) =>
          normalized.isEmpty ||
          target.doctorDisplayName.toLowerCase().contains(normalized) ||
          target.cabinetDisplayName.toLowerCase().contains(normalized) ||
          target.specialtyLabel.toLowerCase().contains(normalized),
    );
    return SyntheticCabinetDirectorySnapshot(
      status: filtered.isEmpty
          ? SyntheticCabinetDirectoryStatus.empty
          : SyntheticCabinetDirectoryStatus.ready,
      candidates: filtered,
      query: query,
    );
  }
}
