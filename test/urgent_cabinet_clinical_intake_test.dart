import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/emergency/emergency_symptom_intake_value.dart';
import 'package:omnicare_mobile/features/emergency/widgets/body_map_widget.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_clinical_intake_draft.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';

const _doctorId = 'p4-demo-doctor-amine-ben-salah';
const _cabinetId = 'p4-demo-cabinet-lac-1';

UrgentCabinetFlowController _controller() {
  return UrgentCabinetFlowController(accountId: 'patient-user-1')
    ..selectSelf()
    ..selectDoctor(doctorId: _doctorId, cabinetId: _cabinetId);
}

UrgentCabinetClinicalIntakeDraft _draft({
  Iterable<String> regions = const ['front-head', 'back-lumbar'],
  int painScore = 6,
  String description = ' Douleur aiguë depuis ce matin. ',
}) {
  return UrgentCabinetClinicalIntakeDraft.fromPresentation(
    careSubject: const UrgentCabinetCareSubject.self(),
    doctorId: _doctorId,
    cabinetId: _cabinetId,
    value: EmergencySymptomIntakeValue(
      rawAnatomicalRegionIds: regions,
      painScore: painScore,
      shortDescription: description,
    ),
  );
}

void main() {
  test('the frozen body map still emits the exact 54 reviewed identifiers', () {
    expect(muscleParts.keys.toSet(), {
      'front-head',
      'front-neck',
      'back-neck',
      'front-chest-pectoral-left',
      'front-chest-pectoral-right',
      'front-abs-upper',
      'front-abs-middle',
      'front-abs-lower',
      'front-oblique-left',
      'front-oblique-right',
      'front-serratus-left',
      'front-serratus-right',
      'back-trap-upper',
      'back-lat-left',
      'back-lat-right',
      'back-spine-upper',
      'back-spine-middle',
      'back-lumbar',
      'back-glute-left',
      'back-glute-right',
      'front-shoulder-deltoid-left',
      'front-shoulder-deltoid-right',
      'back-shoulder-deltoid-left',
      'back-shoulder-deltoid-right',
      'front-bicep-left',
      'front-bicep-right',
      'back-tricep-left',
      'back-tricep-right',
      'front-forearm-left',
      'front-forearm-right',
      'back-forearm-left',
      'back-forearm-right',
      'front-hand-left',
      'front-hand-right',
      'back-hand-left',
      'back-hand-right',
      'front-thigh-quad-left',
      'front-thigh-quad-right',
      'back-thigh-hamstring-left',
      'back-thigh-hamstring-right',
      'front-knee-left',
      'front-knee-right',
      'back-knee-left',
      'back-knee-right',
      'front-shin-left',
      'front-shin-right',
      'front-calf-left',
      'front-calf-right',
      'back-calf-left',
      'back-calf-right',
      'front-foot-left',
      'front-foot-right',
      'back-foot-left',
      'back-foot-right',
    });
  });

  test(
    'raw anatomy, explicit pain and trimmed description remain unmapped',
    () {
      final draft = _draft();

      expect(draft.isValid, isTrue);
      expect(draft.rawAnatomicalRegionIds, ['front-head', 'back-lumbar']);
      expect(draft.painScore, 6);
      expect(draft.shortDescription, 'Douleur aiguë depuis ce matin.');
    },
  );

  test('required clinical intake and 500-code-point limit fail closed', () {
    expect(
      _draft(regions: const []).validationIssue,
      UrgentCabinetClinicalIntakeIssue.missingAnatomicalRegion,
    );
    expect(
      _draft(painScore: 11).validationIssue,
      UrgentCabinetClinicalIntakeIssue.invalidPainScore,
    );
    expect(
      _draft(description: '   ').validationIssue,
      UrgentCabinetClinicalIntakeIssue.missingDescription,
    );
    expect(
      _draft(description: List.filled(501, 'a').join()).validationIssue,
      UrgentCabinetClinicalIntakeIssue.descriptionTooLong,
    );
  });

  test('exact quote authority and intake survive in the current flow', () {
    final controller = _controller();
    final detail =
        UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;

    expect(controller.captureQuoteSnapshot(detail), isTrue);
    expect(controller.quoteSnapshot?.configurationRevision, 11);
    expect(controller.quoteSnapshot?.runtimeRevision, 21);
    expect(controller.quoteSnapshot?.practiceLocationVersion, 31);
    expect(
      controller.saveClinicalIntake(_draft()),
      UrgentCabinetIntakeTransition.saved,
    );
    expect(controller.canReviewCurrentDraft, isTrue);
    expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
  });

  test('a different Doctor/Cabinet invalidates intake and quote together', () {
    final controller = _controller();
    final detail =
        UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;
    controller.captureQuoteSnapshot(detail);
    controller.saveClinicalIntake(_draft());

    controller.selectDoctor(
      doctorId: 'p4-demo-doctor-ines-trabelsi',
      cabinetId: 'p4-demo-cabinet-menzah-1',
    );

    expect(controller.clinicalIntakeDraft, isNull);
    expect(controller.quoteSnapshot, isNull);
    expect(controller.canReviewCurrentDraft, isFalse);
  });

  test('account and family invalidation clear all clinical authority', () {
    final accountController = _controller();
    final detail =
        UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;
    accountController.captureQuoteSnapshot(detail);
    accountController.saveClinicalIntake(_draft());
    accountController.ensureAccount('patient-user-2');

    expect(accountController.selectedSubject, isNull);
    expect(accountController.clinicalIntakeDraft, isNull);
    expect(accountController.quoteSnapshot, isNull);

    final familyController =
        UrgentCabinetFlowController(accountId: 'patient-user-1')
          ..selectFamilyMember('family-1')
          ..selectDoctor(doctorId: _doctorId, cabinetId: _cabinetId);
    familyController.invalidateFamilySubjectIfMissing(const {});

    expect(familyController.selectedSubject, isNull);
    expect(familyController.selectedDoctorId, isNull);
    expect(familyController.selectedCabinetId, isNull);
  });
}
