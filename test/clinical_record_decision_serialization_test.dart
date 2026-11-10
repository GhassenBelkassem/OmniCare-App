import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record.dart';

void main() {
  test('serializes prescribed medication and as-needed follow-up exactly', () {
    final draft = ClinicalRecordDraft(
      medicationDecision: 'MEDICATION_PRESCRIBED',
      followUpRequired: true,
      followUpDecision: 'FOLLOW_UP_AS_NEEDED',
    );

    final json = draft.toJson();

    expect(json['medicationDecision'], 'MEDICATION_PRESCRIBED');
    expect(json['followUp'], {
      'required': true,
      'recommendedAt': null,
      'decision': 'FOLLOW_UP_AS_NEEDED',
    });
  });

  test('serializes no medication and no follow-up exactly', () {
    final draft = ClinicalRecordDraft(
      medicationDecision: 'NO_MEDICATION',
      followUpRequired: false,
      followUpDecision: 'NO_FOLLOW_UP',
    );

    final json = draft.toJson();

    expect(json['medicationDecision'], 'NO_MEDICATION');
    expect(json['followUp'], {
      'required': false,
      'recommendedAt': null,
      'decision': 'NO_FOLLOW_UP',
    });
  });

  test('serializes period follow-up with its required date', () {
    final draft = ClinicalRecordDraft(
      followUpRequired: true,
      followUpRecommendedAt: '2026-11-03',
      followUpDecision: 'FOLLOW_UP_IN_PERIOD',
    );

    expect(draft.toJson()['followUp'], {
      'required': true,
      'recommendedAt': '2026-11-03',
      'decision': 'FOLLOW_UP_IN_PERIOD',
    });
  });

  test('serializes after-results follow-up without a date', () {
    final draft = ClinicalRecordDraft(
      followUpRequired: true,
      followUpDecision: 'FOLLOW_UP_AFTER_RESULTS',
    );

    expect(draft.toJson()['followUp'], {
      'required': true,
      'recommendedAt': null,
      'decision': 'FOLLOW_UP_AFTER_RESULTS',
    });
  });

  test('serializes LOCAL free-text conclusion without an invented code', () {
    final draft = ClinicalRecordDraft(
      diagnosisSystem: 'LOCAL',
      diagnosisCode: '',
      diagnosisLabel: 'Free-text clinical conclusion',
      diagnosisStatus: 'CONFIRMED',
      assessment: null,
      medicationDecision: 'NO_MEDICATION',
      followUpDecision: 'NO_FOLLOW_UP',
    );

    expect(draft.toJson()['diagnoses'], [
      {
        'system': 'LOCAL',
        'code': '',
        'label': 'Free-text clinical conclusion',
        'status': 'CONFIRMED',
      },
    ]);
    expect(draft.toJson()['assessment'], isNull);
  });

  test('accepts schema v3 and preserves advanced fields across a copy', () {
    final envelope = ClinicalRecordEnvelope.fromJson({
      'clinicalRecordVersion': 4,
      'schemaVersion': 3,
      'clinicalRecord': {
        'history': {'presentIllness': 'Preserved history'},
        'clinicalFindings': <Object>[],
        'diagnoses': <Object>[],
        'treatmentPlan': ['Preserved advice'],
        'followUp': {'required': false},
      },
    });

    expect(envelope.record.copy().presentIllness, 'Preserved history');
    expect(envelope.record.copy().treatmentPlan, ['Preserved advice']);
  });
}
