import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_models.dart';

void main() {
  final now = DateTime(2026, 10, 6, 8);

  ScheduledCarePrototypeController createController() =>
      ScheduledCarePrototypeController.withFixtures(clock: () => now);

  const cabinet = CabinetPrototype(
    id: 'cabinet-test',
    name: 'Cabinet Test',
    address: '10 rue de Tunis',
    city: 'Tunis',
  );

  test('default workflow controller starts without fixture records', () {
    final controller = ScheduledCarePrototypeController(clock: () => now);
    addTearDown(controller.dispose);

    expect(controller.records, isEmpty);
    expect(controller.hasActiveDraft, isFalse);
  });

  test('SELF and family-member identity stay in the booking draft', () {
    final controller = createController();
    addTearDown(controller.dispose);

    controller.selectSelf(displayName: 'Leïla');
    expect(controller.draft.patient?.displayName, 'Leïla');
    expect(controller.draft.patient?.type, ScheduledPatientSubjectType.self);

    controller.selectFamilyMember(
      familyMemberId: 'family-42',
      displayName: 'Yasmine',
      relationshipLabel: 'Enfant',
    );
    expect(controller.draft.patient?.familyMemberId, 'family-42');
    expect(controller.draft.patient?.displayName, 'Yasmine');
    expect(controller.draft.patient?.relationshipLabel, 'Enfant');
  });

  test('review submission creates a Cabinet-bound PENDING_DOCTOR request', () {
    final controller = createController();
    addTearDown(controller.dispose);
    final slot = controller.freeSlotsFor(cabinet).first;

    controller
      ..selectSelf(displayName: 'Leïla')
      ..selectDoctorAndCabinet(
        doctorId: 'doctor-1',
        doctorName: 'Dr Amine',
        doctorSpecialty: 'Médecine générale',
        consultationPriceTnd: 80,
        cabinet: cabinet,
      )
      ..selectSlot(slot);

    final request = controller.submitDraft();
    expect(request.status, ScheduledCareStatus.pendingDoctor);
    expect(request.patient.displayName, 'Leïla');
    expect(request.cabinet, same(cabinet));
    expect(request.activeSlot.start, slot.start);
    expect(request.responseDeadline, now.add(const Duration(hours: 24)));
    expect(request.intake.status, ScheduledIntakeStatus.notSubmitted);
    expect(controller.hasActiveDraft, isFalse);
  });

  test('Doctor accept and counterproposal use canonical lifecycle states', () {
    final controller = createController();
    addTearDown(controller.dispose);

    controller.acceptByDoctor('fixture-request-mariem');
    expect(
      controller.byId('fixture-request-mariem')?.status,
      ScheduledCareStatus.confirmed,
    );

    final confirmed = controller.byId('fixture-appointment-ahmed')!;
    final replacement = controller.freeSlotsFor(confirmed.cabinet).first;
    controller.proposeByDoctor(confirmed.id, replacement);
    expect(
      controller.byId(confirmed.id)?.status,
      ScheduledCareStatus.pendingPatientTimeConfirmation,
    );
    expect(controller.byId(confirmed.id)?.proposedSlot, replacement);

    controller.acceptProposalByPatient(confirmed.id);
    expect(
      controller.byId(confirmed.id)?.status,
      ScheduledCareStatus.confirmed,
    );
  });

  test('decline, expiry, cancellation and intake remain independent', () {
    final controller = createController();
    addTearDown(controller.dispose);

    controller.declineProposalByPatient('fixture-request-sami');
    expect(
      controller.byId('fixture-request-sami')?.status,
      ScheduledCareStatus.cancelledByPatient,
    );

    controller.expire('fixture-request-mariem');
    expect(
      controller.byId('fixture-request-mariem')?.status,
      ScheduledCareStatus.expired,
    );

    controller.submitIntake(
      id: 'fixture-appointment-ahmed',
      bodyAreas: const ['Genou droit'],
      description: 'Douleur au mouvement',
      painIntensity: 6,
    );
    final appointment = controller.byId('fixture-appointment-ahmed');
    expect(appointment?.status, ScheduledCareStatus.confirmed);
    expect(appointment?.intake.status, ScheduledIntakeStatus.submitted);

    controller.cancelByPatient(
      'fixture-appointment-ahmed',
      reason: 'Indisponible',
    );
    final cancelled = controller.byId('fixture-appointment-ahmed');
    expect(cancelled?.status, ScheduledCareStatus.cancelledByPatient);
    expect(cancelled?.lateCancellation, isFalse);
    expect(cancelled?.cancellationReason, 'Indisponible');
  });

  test('Doctor refusal requires a reason', () {
    final controller = createController();
    addTearDown(controller.dispose);

    controller.declineByDoctor('fixture-request-mariem', reason: '   ');
    expect(
      controller.byId('fixture-request-mariem')?.status,
      ScheduledCareStatus.pendingDoctor,
    );

    controller.declineByDoctor(
      'fixture-request-mariem',
      reason: 'Cabinet exceptionnellement fermé',
    );
    final declined = controller.byId('fixture-request-mariem');
    expect(declined?.status, ScheduledCareStatus.cancelledByDoctor);
    expect(declined?.cancellationReason, 'Cabinet exceptionnellement fermé');
  });

  test('illegal terminal transitions are rejected', () {
    final controller = createController();
    addTearDown(controller.dispose);

    controller.cancelByPatient('fixture-request-mariem');
    final cancelled = controller.byId('fixture-request-mariem');
    controller.acceptByDoctor('fixture-request-mariem');
    controller.proposeByDoctor(
      'fixture-request-mariem',
      controller.freeSlotsFor(cancelled!.cabinet).first,
    );
    controller.expire('fixture-request-mariem');

    expect(controller.byId('fixture-request-mariem'), same(cancelled));
    expect(cancelled.status, ScheduledCareStatus.cancelledByPatient);
  });

  test('proposal requires a free slot from the same Cabinet', () {
    final controller = createController();
    addTearDown(controller.dispose);
    final request = controller.byId('fixture-request-mariem')!;
    final valid = controller.freeSlotsFor(request.cabinet).first;
    final wrongCabinet = SlotPrototype(
      id: 'wrong-cabinet',
      cabinetId: 'another-cabinet',
      start: valid.start,
      end: valid.end,
    );
    final unavailable = SlotPrototype(
      id: 'overlap-held-slot',
      cabinetId: request.cabinet.id,
      start: request.activeSlot.start.add(const Duration(minutes: 5)),
      end: request.activeSlot.end.add(const Duration(minutes: 5)),
    );

    controller.proposeByDoctor(request.id, wrongCabinet);
    controller.proposeByDoctor(request.id, unavailable);
    expect(
      controller.byId(request.id)?.status,
      ScheduledCareStatus.pendingDoctor,
    );

    controller.proposeByDoctor(request.id, valid);
    expect(
      controller.byId(request.id)?.status,
      ScheduledCareStatus.pendingPatientTimeConfirmation,
    );
  });

  test('held slots collide only within the same Cabinet', () {
    final controller = createController();
    addTearDown(controller.dispose);
    final held = controller.byId('fixture-request-mariem')!.activeSlot;
    final sameCabinet = controller.freeSlotsFor(
      controller.byId('fixture-request-mariem')!.cabinet,
    );
    const otherCabinet = CabinetPrototype(
      id: 'other-cabinet',
      name: 'Autre Cabinet',
      address: '20 rue de Tunis',
      city: 'Tunis',
    );
    final elsewhere = controller.freeSlotsFor(otherCabinet);

    expect(
      sameCabinet.any(
        (slot) =>
            slot.start.isBefore(held.end) && held.start.isBefore(slot.end),
      ),
      isFalse,
    );
    expect(
      elsewhere.any((slot) => slot.start.isAtSameMomentAs(held.start)),
      isTrue,
    );
  });
}
