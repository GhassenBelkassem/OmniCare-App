import 'package:flutter/foundation.dart';

import 'scheduled_care_models.dart';

const _responseTarget = Duration(hours: 2);
const _requestTtl = Duration(hours: 24);
const _minimumNotice = Duration(hours: 4);
const _patientProposalTtl = Duration(hours: 6);

class ScheduledCarePrototypeController extends ChangeNotifier {
  ScheduledCarePrototypeController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _records = <ScheduledCareRecordPrototype>[];

  ScheduledCarePrototypeController.withFixtures({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _records = _initialRecords(_clock());
  }

  final DateTime Function() _clock;
  BookingDraftPrototype _draft = const BookingDraftPrototype();
  late List<ScheduledCareRecordPrototype> _records;
  int _sequence = 1;

  BookingDraftPrototype get draft => _draft;
  List<ScheduledCareRecordPrototype> get records => List.unmodifiable(_records);
  bool get hasActiveDraft => _draft.patient != null;
  DateTime get currentTime => _clock();

  List<ScheduledCareRecordPrototype> get pendingDoctor => _records
      .where((record) => record.status == ScheduledCareStatus.pendingDoctor)
      .toList(growable: false);

  List<ScheduledCareRecordPrototype> get pendingPatient => _records
      .where(
        (record) =>
            record.status == ScheduledCareStatus.pendingPatientTimeConfirmation,
      )
      .toList(growable: false);

  List<AppointmentPrototype> get confirmed =>
      _records.whereType<AppointmentPrototype>().toList(growable: false);

  void selectSelf({required String displayName}) {
    _draft = BookingDraftPrototype(
      patient: PatientSubjectPrototype(
        type: ScheduledPatientSubjectType.self,
        displayName: displayName.trim().isEmpty ? 'Moi' : displayName.trim(),
        relationshipLabel: 'Moi-même',
      ),
    );
    notifyListeners();
  }

  void selectFamilyMember({
    required String familyMemberId,
    required String displayName,
    required String relationshipLabel,
  }) {
    _draft = BookingDraftPrototype(
      patient: PatientSubjectPrototype(
        type: ScheduledPatientSubjectType.familyMember,
        familyMemberId: familyMemberId,
        displayName: displayName,
        relationshipLabel: relationshipLabel,
      ),
    );
    notifyListeners();
  }

  void selectDoctorAndCabinet({
    required String doctorId,
    required String doctorName,
    required String doctorSpecialty,
    double? consultationPriceTnd,
    required CabinetPrototype cabinet,
  }) {
    _draft = _draft.copyWith(
      doctorId: doctorId,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      consultationPriceTnd: consultationPriceTnd,
      cabinet: cabinet,
      clearSlot: true,
    );
    notifyListeners();
  }

  void selectSlot(SlotPrototype slot) {
    final cabinet = _draft.cabinet;
    if (cabinet == null || slot.cabinetId != cabinet.id) return;
    _draft = _draft.copyWith(slot: slot);
    notifyListeners();
  }

  BookingRequestPrototype submitDraft() {
    if (!_draft.canReview) {
      throw StateError('The scheduled booking draft is incomplete.');
    }
    final now = _clock();
    final requested = _draft.slot!;
    final cabinet = _draft.cabinet!;
    final isAvailable =
        requested.cabinetId == cabinet.id &&
        !requested.start.isBefore(now.add(_minimumNotice)) &&
        freeSlotsFor(
          cabinet,
        ).any((candidate) => _sameSlot(candidate, requested));
    if (!isAvailable) {
      throw StateError('The selected Cabinet slot is no longer available.');
    }
    final latestDeadline = requested.start.subtract(_minimumNotice);
    final deadline = now.add(_requestTtl).isBefore(latestDeadline)
        ? now.add(_requestTtl)
        : latestDeadline;
    final request = BookingRequestPrototype(
      id: 'p2-request-${_sequence++}',
      patient: _draft.patient!,
      doctorId: _draft.doctorId!,
      doctorName: _draft.doctorName!,
      doctorSpecialty: _draft.doctorSpecialty!,
      cabinet: cabinet,
      requestedSlot: requested,
      proposedSlot: null,
      status: ScheduledCareStatus.pendingDoctor,
      createdAt: now,
      responseDeadline: deadline,
      patientResponseDeadline: null,
      cancelledAt: null,
      cancellationReason: null,
      lateCancellation: false,
      intake: const IntakePrototype(),
    );
    _records = [request, ..._records];
    _draft = const BookingDraftPrototype();
    notifyListeners();
    return request;
  }

  void clearDraft() {
    if (!hasActiveDraft) return;
    _draft = const BookingDraftPrototype();
    notifyListeners();
  }

  ScheduledCareRecordPrototype? byId(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  List<SlotPrototype> freeSlotsFor(CabinetPrototype cabinet) {
    final now = _clock();
    final duration = cabinet.id.contains('ariana') ? 20 : 30;
    final starts = <DateTime>[
      _at(now, 2, cabinet.id.contains('ariana') ? 15 : 9),
      _at(now, 2, cabinet.id.contains('ariana') ? 16 : 10),
      _at(now, 3, cabinet.id.contains('ariana') ? 17 : 11),
    ];
    final held = _records
        .where(
          (record) =>
              record.status == ScheduledCareStatus.pendingDoctor ||
              record.status ==
                  ScheduledCareStatus.pendingPatientTimeConfirmation ||
              record.status == ScheduledCareStatus.confirmed,
        )
        .where((record) => record.cabinet.id == cabinet.id)
        .map((record) => record.activeSlot)
        .toList(growable: false);
    return starts
        .map(
          (start) => SlotPrototype(
            id: '${cabinet.id}-${start.millisecondsSinceEpoch}',
            cabinetId: cabinet.id,
            start: start,
            end: start.add(Duration(minutes: duration)),
          ),
        )
        .where(
          (candidate) =>
              held.every((occupied) => !_overlaps(candidate, occupied)),
        )
        .toList(growable: false);
  }

  void acceptByDoctor(String id) {
    _replace(id, (record) {
      if (record.status != ScheduledCareStatus.pendingDoctor) return record;
      return AppointmentPrototype(
        id: record.id,
        patient: record.patient,
        doctorId: record.doctorId,
        doctorName: record.doctorName,
        doctorSpecialty: record.doctorSpecialty,
        cabinet: record.cabinet,
        requestedSlot: record.requestedSlot,
        proposedSlot: record.proposedSlot,
        createdAt: record.createdAt,
        responseDeadline: record.responseDeadline,
        patientResponseDeadline: record.patientResponseDeadline,
        cancelledAt: null,
        cancellationReason: null,
        lateCancellation: false,
        intake: record.intake,
        confirmedAt: _clock(),
      );
    });
  }

  void proposeByDoctor(String id, SlotPrototype replacement) {
    _replace(id, (record) {
      if ((record.status != ScheduledCareStatus.pendingDoctor &&
              record.status != ScheduledCareStatus.confirmed) ||
          replacement.cabinetId != record.cabinet.id ||
          !freeSlotsFor(
            record.cabinet,
          ).any((candidate) => _sameSlot(candidate, replacement))) {
        return record;
      }
      return BookingRequestPrototype(
        id: record.id,
        patient: record.patient,
        doctorId: record.doctorId,
        doctorName: record.doctorName,
        doctorSpecialty: record.doctorSpecialty,
        cabinet: record.cabinet,
        requestedSlot: record.activeSlot,
        proposedSlot: replacement,
        status: ScheduledCareStatus.pendingPatientTimeConfirmation,
        patientResponseDeadline: _clock().add(_patientProposalTtl),
        createdAt: record.createdAt,
        responseDeadline: record.responseDeadline,
        cancelledAt: null,
        cancellationReason: null,
        lateCancellation: false,
        intake: record.intake,
      );
    });
  }

  void acceptProposalByPatient(String id) {
    _replace(id, (record) {
      if (record.status != ScheduledCareStatus.pendingPatientTimeConfirmation) {
        return record;
      }
      return AppointmentPrototype(
        id: record.id,
        patient: record.patient,
        doctorId: record.doctorId,
        doctorName: record.doctorName,
        doctorSpecialty: record.doctorSpecialty,
        cabinet: record.cabinet,
        requestedSlot: record.requestedSlot,
        proposedSlot: record.proposedSlot,
        createdAt: record.createdAt,
        responseDeadline: record.responseDeadline,
        patientResponseDeadline: record.patientResponseDeadline,
        cancelledAt: null,
        cancellationReason: null,
        lateCancellation: false,
        intake: record.intake,
        confirmedAt: _clock(),
      );
    });
  }

  void declineProposalByPatient(String id) {
    final record = byId(id);
    if (record?.status != ScheduledCareStatus.pendingPatientTimeConfirmation) {
      return;
    }
    cancelByPatient(id, reason: 'Créneau proposé refusé');
  }

  void cancelByPatient(String id, {String? reason}) {
    _replaceWithCancellation(
      id,
      ScheduledCareStatus.cancelledByPatient,
      reason ?? 'Annulé par le patient',
      const {
        ScheduledCareStatus.pendingDoctor,
        ScheduledCareStatus.pendingPatientTimeConfirmation,
        ScheduledCareStatus.confirmed,
      },
    );
  }

  void declineByDoctor(String id, {required String reason}) {
    if (reason.trim().isEmpty) return;
    _replaceWithCancellation(
      id,
      ScheduledCareStatus.cancelledByDoctor,
      reason.trim(),
      const {
        ScheduledCareStatus.pendingDoctor,
        ScheduledCareStatus.pendingPatientTimeConfirmation,
        ScheduledCareStatus.confirmed,
      },
    );
  }

  void expire(String id) {
    _replace(id, (record) {
      if (record is! BookingRequestPrototype ||
          (record.status != ScheduledCareStatus.pendingDoctor &&
              record.status !=
                  ScheduledCareStatus.pendingPatientTimeConfirmation)) {
        return record;
      }
      return record.copyWith(status: ScheduledCareStatus.expired);
    });
  }

  void submitIntake({
    required String id,
    required List<String> bodyAreas,
    required String description,
    required int painIntensity,
  }) {
    _replace(id, (record) {
      if (record is! AppointmentPrototype) return record;
      return record.copyWith(
        intake: IntakePrototype(
          status: ScheduledIntakeStatus.submitted,
          bodyAreas: List.unmodifiable(bodyAreas),
          description: description.trim(),
          painIntensity: painIntensity,
          submittedAt: _clock(),
        ),
      );
    });
  }

  String responseTargetLabel(ScheduledCareRecordPrototype record) {
    final remaining = record.responseDeadline.difference(_clock());
    if (remaining <= Duration.zero) return 'Échéance atteinte';
    if (remaining <= _responseTarget) return 'Réponse attendue rapidement';
    return 'Réponse idéale sous 2 h';
  }

  void _replace(
    String id,
    ScheduledCareRecordPrototype Function(ScheduledCareRecordPrototype record)
    transform,
  ) {
    _records = _records
        .map((record) => record.id == id ? transform(record) : record)
        .toList(growable: false);
    notifyListeners();
  }

  void _replaceWithCancellation(
    String id,
    ScheduledCareStatus status,
    String reason,
    Set<ScheduledCareStatus> allowedStatuses,
  ) {
    final now = _clock();
    _replace(id, (record) {
      if (!allowedStatuses.contains(record.status)) return record;
      final late =
          record.activeSlot.start.difference(now) < const Duration(hours: 24);
      return BookingRequestPrototype(
        id: record.id,
        patient: record.patient,
        doctorId: record.doctorId,
        doctorName: record.doctorName,
        doctorSpecialty: record.doctorSpecialty,
        cabinet: record.cabinet,
        requestedSlot: record.requestedSlot,
        proposedSlot: record.proposedSlot,
        status: status,
        createdAt: record.createdAt,
        responseDeadline: record.responseDeadline,
        patientResponseDeadline: record.patientResponseDeadline,
        cancelledAt: now,
        cancellationReason: reason,
        lateCancellation: late,
        intake: record.intake,
      );
    });
  }
}

bool _sameSlot(SlotPrototype left, SlotPrototype right) =>
    left.cabinetId == right.cabinetId &&
    left.start.isAtSameMomentAs(right.start) &&
    left.end.isAtSameMomentAs(right.end);

bool _overlaps(SlotPrototype left, SlotPrototype right) =>
    left.start.isBefore(right.end) && right.start.isBefore(left.end);

DateTime _at(DateTime base, int days, int hour, [int minute = 0]) =>
    DateTime(base.year, base.month, base.day + days, hour, minute);

List<ScheduledCareRecordPrototype> _initialRecords(DateTime now) {
  const lac = CabinetPrototype(
    id: 'cabinet-lac-2',
    name: 'Cabinet Lac 2',
    address: 'Rue du Lac de Constance',
    city: 'Tunis',
  );
  const ariana = CabinetPrototype(
    id: 'cabinet-ariana',
    name: 'Cabinet Ariana',
    address: '18 avenue Hédi Nouira',
    city: 'Ariana',
  );
  final mariemSlot = SlotPrototype(
    id: 'fixture-mariem',
    cabinetId: lac.id,
    start: _at(now, 2, 9),
    end: _at(now, 2, 9, 30),
  );
  final samiOriginal = SlotPrototype(
    id: 'fixture-sami-original',
    cabinetId: ariana.id,
    start: _at(now, 3, 15),
    end: _at(now, 3, 15, 20),
  );
  final samiProposal = SlotPrototype(
    id: 'fixture-sami-proposal',
    cabinetId: ariana.id,
    start: _at(now, 3, 16),
    end: _at(now, 3, 16, 20),
  );
  final ahmedSlot = SlotPrototype(
    id: 'fixture-ahmed',
    cabinetId: lac.id,
    start: _at(now, 1, 10),
    end: _at(now, 1, 10, 30),
  );

  return [
    BookingRequestPrototype(
      id: 'fixture-request-mariem',
      patient: const PatientSubjectPrototype(
        type: ScheduledPatientSubjectType.familyMember,
        familyMemberId: 'fixture-family-mariem',
        displayName: 'Mariem Ben Amor',
        relationshipLabel: 'Enfant',
      ),
      doctorId: 'doctor-demo',
      doctorName: 'Dr Amine Ben Salah',
      doctorSpecialty: 'Médecine générale',
      cabinet: lac,
      requestedSlot: mariemSlot,
      proposedSlot: null,
      status: ScheduledCareStatus.pendingDoctor,
      createdAt: now.subtract(const Duration(minutes: 35)),
      responseDeadline: now.add(const Duration(hours: 6)),
      patientResponseDeadline: null,
      cancelledAt: null,
      cancellationReason: null,
      lateCancellation: false,
      intake: const IntakePrototype(),
    ),
    BookingRequestPrototype(
      id: 'fixture-request-sami',
      patient: const PatientSubjectPrototype(
        type: ScheduledPatientSubjectType.self,
        displayName: 'Sami Trabelsi',
        relationshipLabel: 'Moi-même',
      ),
      doctorId: 'doctor-demo',
      doctorName: 'Dr Amine Ben Salah',
      doctorSpecialty: 'Médecine générale',
      cabinet: ariana,
      requestedSlot: samiOriginal,
      proposedSlot: samiProposal,
      status: ScheduledCareStatus.pendingPatientTimeConfirmation,
      createdAt: now.subtract(const Duration(hours: 1)),
      responseDeadline: now.add(const Duration(hours: 4)),
      patientResponseDeadline: now.add(_patientProposalTtl),
      cancelledAt: null,
      cancellationReason: null,
      lateCancellation: false,
      intake: const IntakePrototype(),
    ),
    AppointmentPrototype(
      id: 'fixture-appointment-ahmed',
      patient: const PatientSubjectPrototype(
        type: ScheduledPatientSubjectType.self,
        displayName: 'Ahmed Gharbi',
        relationshipLabel: 'Moi-même',
      ),
      doctorId: 'doctor-demo',
      doctorName: 'Dr Amine Ben Salah',
      doctorSpecialty: 'Médecine générale',
      cabinet: lac,
      requestedSlot: ahmedSlot,
      proposedSlot: null,
      createdAt: now.subtract(const Duration(hours: 3)),
      responseDeadline: now.subtract(const Duration(hours: 1)),
      patientResponseDeadline: null,
      cancelledAt: null,
      cancellationReason: null,
      lateCancellation: false,
      intake: const IntakePrototype(
        status: ScheduledIntakeStatus.submitted,
        bodyAreas: ['Épaule droite'],
        description: 'Douleur apparue progressivement après un effort.',
        painIntensity: 4,
      ),
      confirmedAt: now.subtract(const Duration(hours: 2)),
    ),
  ];
}
