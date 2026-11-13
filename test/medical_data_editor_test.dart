// G2.1-A2: the « Modifier les données de … » editor, logic only (CTO testing
// rule): drafts → exact requests, change detection, local checks, the save
// sequence (keys, conflicts, partial failures), the BMI category and the
// « Déclaré par le patient » flag. No widget, no app run. Every value here is
// synthetic.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_data_editor_draft.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_data_editor_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_record_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_reference_values.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_messages.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_presenter.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));
const _family = FamilyRecordSubject('fam-1');
final _now = DateTime.utc(2026, 11, 12, 10);

void main() {
  group('the draft of a fresh read changes nothing', () {
    test('an untouched editor sends nothing and closes', () async {
      final f = await _Fixture.loaded();
      expect(await f.editor.save(f.untouched()), EditorSaveOutcome.done);
      expect(f.writes.calls, isEmpty);
      expect(f.editor.savedSomething, isFalse);
    });

    test('a past declared medication beyond the first page counts as read', () {
      final baseline = _baseline();
      expect(baseline.pastDeclared.map((i) => i.itemId), ['m-past']);
      expect(baseline.ownCurrentDeclared.map((i) => i.itemId), ['m-own']);
      expect(baseline.readOnlyCurrentMedications.map((i) => i.id), ['rx-1']);
      expect(
        planMedications(baseline, EditorDraft.of(baseline), now: _now),
        isA<SectionUnchanged>(),
      );
    });
  });

  group('blood type', () {
    test('never defaults to A+: no value reads as nothing chosen', () {
      final baseline = _baseline(
        medicalData: _medicalData(bloodType: null, bloodTypeVersion: 0),
      );
      expect(baseline.bloodType, isNull);
      expect(EditorDraft.of(baseline).bloodType, isNull);
      expect(
        planBloodType(baseline, EditorDraft.of(baseline)),
        isA<SectionUnchanged>(),
      );
    });

    test('« Je ne sais pas » saved before reads back as UNKNOWN', () {
      final baseline = _baseline(
        medicalData: _medicalData(bloodType: null, bloodTypeVersion: 3),
      );
      expect(baseline.bloodType, bloodTypeUnknown);
    });

    test('« Je ne sais pas » sends UNKNOWN at the read version', () async {
      final f = await _Fixture.loaded();
      await f.editor.save(f.untouched(bloodType: bloodTypeUnknown));
      expect(f.writes.calls.single.section, RecordSection.bloodType);
      expect(f.writes.calls.single.body, {
        'value': 'UNKNOWN',
        'expectedVersion': 2,
      });
    });

    test('a blood type set by a professional is never sent', () async {
      final f = await _Fixture.loaded(
        medicalData: _medicalData(bloodTypeAuthor: 'PROFESSIONAL'),
      );
      expect(f.editor.baseline!.bloodTypeLocked, isTrue);
      await f.editor.save(f.untouched(bloodType: 'O-'));
      expect(f.writes.calls, isEmpty);
    });
  });

  group('measurements', () {
    test('only the changed value is sent, comma or point', () async {
      final f = await _Fixture.loaded();
      await f.editor.save(f.untouched(heightText: '172,5'));
      expect(f.writes.calls.single.body, {
        'heightCm': 172.5,
        'expectedVersion': 1,
      });
    });

    test('local checks mirror the server', () {
      final baseline = _baseline();
      List<EditorFieldError> errors(String height, String weight) =>
          (planMeasurements(
                    baseline,
                    _draftOf(baseline, heightText: height, weightText: weight),
                  )
                  as SectionInvalid)
              .errors;
      expect(errors('', '70'), [
        const EditorFieldError('heightCm', ApiFieldErrorKind.required),
      ]);
      expect(errors('abc', '70'), [
        const EditorFieldError('heightCm', ApiFieldErrorKind.invalidFormat),
      ]);
      expect(errors('29.9', '0'), [
        const EditorFieldError('heightCm', ApiFieldErrorKind.outOfRange),
        const EditorFieldError('weightKg', ApiFieldErrorKind.outOfRange),
      ]);
      expect(errors('301', '500.1').length, 2);
      expect(
        planMeasurements(baseline, _draftOf(baseline, heightText: '300')),
        isA<SectionReadyToSave>(),
      );
    });

    test('an empty field with nothing recorded stays unchanged', () {
      final baseline = _baseline(
        medicalData: _medicalData(heightCm: null, weightKg: null),
      );
      expect(
        planMeasurements(baseline, EditorDraft.of(baseline)),
        isA<SectionUnchanged>(),
      );
    });
  });

  group('allergies and conditions', () {
    test(
      'own items keep id and severity; professional ones are never sent',
      () async {
        final f = await _Fixture.loaded();
        await f.editor.save(
          f.untouched(allergyLabels: ['Allergie Pénicilline', 'Lactose']),
        );
        expect(f.writes.calls.single.section, RecordSection.allergies);
        expect(f.writes.calls.single.body, {
          'items': [
            {
              'itemId': 'a-own',
              'label': 'Allergie Pénicilline',
              'severity': 'SEVERE',
            },
            {'label': 'Lactose'},
          ],
          'expectedVersion': 3,
        });
      },
    );

    test(
      'an emptied list sends [] (« Aucune »), never the professional item',
      () async {
        final f = await _Fixture.loaded();
        await f.editor.save(f.untouched(conditionLabels: []));
        expect(f.writes.calls.single.body, {
          'items': <Object?>[],
          'expectedVersion': 5,
        });
      },
    );

    test('the app never sends `critical`', () async {
      final f = await _Fixture.loaded();
      await f.editor.save(f.untouched(conditionLabels: ['Asthme', 'Migraine']));
      final body = f.writes.calls.single.body;
      expect(jsonEncode(body), isNot(contains('critical')));
      expect(body['items'], [
        {'itemId': 'c-own', 'label': 'Asthme'},
        {'label': 'Migraine'},
      ]);
    });

    test('a label in another case keeps the own item and its stored label', () {
      final baseline = _baseline();
      final plan = planConditions(
        baseline,
        _draftOf(baseline, conditionLabels: ['asthme', 'Migraine']),
      );
      expect((plan as SectionReadyToSave).conditions!.first.toJson(), {
        'itemId': 'c-own',
        'label': 'Asthme',
      });
    });

    test('label checks: duplicate (also of a professional item), length, '
        'forbidden character, 50 items', () {
      final baseline = _baseline();
      List<EditorFieldError> errors(List<String> labels) =>
          (planAllergies(baseline, _draftOf(baseline, allergyLabels: labels))
                  as SectionInvalid)
              .errors;
      expect(errors(['Allergie Pénicilline', 'pollen']), [
        const EditorFieldError('items[1].label', ApiFieldErrorKind.duplicate),
      ]);
      expect(errors(['x' * 161]), [
        const EditorFieldError('items[0].label', ApiFieldErrorKind.tooLong),
      ]);
      expect(errors(['Lait\u202E']), [
        const EditorFieldError('items[0].label', ApiFieldErrorKind.invalid),
      ]);
      expect(errors([for (var i = 0; i < 50; i++) 'label-$i']), [
        const EditorFieldError('items', ApiFieldErrorKind.tooLong),
      ]);
      expect(
        planAllergies(baseline, _draftOf(baseline, allergyLabels: ['é' * 160])),
        isA<SectionReadyToSave>(),
      );
    });

    test('the « Autre… » field refuses at once what the server would', () {
      expect(newChipError('  ', const []), ApiFieldErrorKind.required);
      expect(
        newChipError('POLLEN', const ['Pollen']),
        ApiFieldErrorKind.duplicate,
      );
      expect(newChipError('x' * 161, const []), ApiFieldErrorKind.tooLong);
      expect(newChipError('a\u0007', const []), ApiFieldErrorKind.invalid);
      expect(newChipError('Lactose', const ['Pollen']), isNull);
      expect(
        recordFieldMessage('label', ApiFieldErrorKind.duplicate, _fr),
        'Cet élément figure déjà dans la liste.',
      );
    });
  });

  group('declared medications', () {
    test('rows, a new one and the past item go in one list at the list '
        'version; the prescription is never sent', () async {
      final f = await _Fixture.loaded();
      final draft = f.untouched();
      final own = draft.medications.single;
      await f.editor.save(
        _withMedications(draft, [
          MedicationInput(
            key: own.key,
            itemId: own.itemId,
            name: own.name,
            dosageText: '1 g',
            timesPerDay: 3,
            durationText: own.durationText,
            durationUnit: own.durationUnit,
            startedOn: own.startedOn,
          ),
          const MedicationInput(
            key: 9,
            name: 'Vitamine D',
            timesPerDay: 1,
            durationText: '2',
            durationUnit: DurationUnit.month,
          ),
        ]),
      );
      final call = f.writes.calls.single;
      expect(call.section, RecordSection.declaredMedications);
      expect(call.body, {
        'items': [
          {
            'itemId': 'm-own',
            'name': 'Doliprane',
            'dosageText': '1 g',
            'timesPerDay': 3,
            'duration': {'value': 5, 'unit': 'DAY'},
            'startedOn': '2026-11-01',
          },
          {
            'name': 'Vitamine D',
            'timesPerDay': 1,
            'duration': {'value': 2, 'unit': 'MONTH'},
          },
          {
            'itemId': 'm-past',
            'name': 'Ibuprofène',
            'duration': {'value': 3, 'unit': 'DAY'},
            'startedOn': '2026-10-01',
          },
        ],
        'expectedVersion': 7,
      });
      expect(jsonEncode(call.body), isNot(contains('rx-1')));
    });

    test('a row with an empty name is refused, never dropped', () async {
      final f = await _Fixture.loaded();
      final draft = f.untouched();
      final outcome = await f.editor.save(
        _withMedications(draft, [
          ...draft.medications,
          const MedicationInput(key: 4, name: '  '),
        ]),
      );
      expect(outcome, EditorSaveOutcome.invalid);
      expect(f.writes.calls, isEmpty);
      final error = f.editor.fieldError('medications:4.name')!;
      expect(error.kind, ApiFieldErrorKind.required);
      expect(
        recordFieldMessage(error.path, error.kind, _fr),
        'Ce champ est obligatoire.',
      );
    });

    test('local checks: duration, dose length, duplicates (also of a past '
        'item), date not in the future, 50 items', () {
      final baseline = _baseline();
      List<EditorFieldError> errors(List<MedicationInput> rows) =>
          (planMedications(
                    baseline,
                    _withMedications(EditorDraft.of(baseline), rows),
                    now: _now,
                  )
                  as SectionInvalid)
              .errors;
      expect(
        errors([const MedicationInput(key: 1, name: 'A', durationText: '0')]),
        [
          const EditorFieldError(
            'items[0].duration.value',
            ApiFieldErrorKind.outOfRange,
          ),
        ],
      );
      expect(
        errors([const MedicationInput(key: 1, name: 'A', durationText: 'x')]),
        [
          const EditorFieldError(
            'items[0].duration.value',
            ApiFieldErrorKind.invalidFormat,
          ),
        ],
      );
      expect(
        errors([MedicationInput(key: 1, name: 'A', dosageText: 'd' * 81)]),
        [
          const EditorFieldError(
            'items[0].dosageText',
            ApiFieldErrorKind.tooLong,
          ),
        ],
      );
      expect(errors([const MedicationInput(key: 1, name: 'ibuprofène')]), [
        const EditorFieldError('items[0].name', ApiFieldErrorKind.duplicate),
      ]);
      expect(
        errors([
          const MedicationInput(key: 1, name: 'A', startedOn: '2026-11-13'),
        ]),
        [
          const EditorFieldError(
            'items[0].startedOn',
            ApiFieldErrorKind.outOfRange,
          ),
        ],
      );
      expect(
        errors([
          for (var i = 0; i < 50; i++) MedicationInput(key: i, name: 'med-$i'),
        ]),
        [const EditorFieldError('items', ApiFieldErrorKind.tooLong)],
      );
    });

    test('today in Tunis is the limit of the start date', () {
      expect(
        tunisToday(DateTime.utc(2026, 11, 12, 22, 59)),
        DateTime(2026, 11, 12),
      );
      expect(
        tunisToday(DateTime.utc(2026, 11, 12, 23)),
        DateTime(2026, 11, 13),
      );
    });

    test('the editor reads every medication page, with a hard cap', () async {
      final api = _ReadApi(pagesPerGroup: 3);
      final result = await MedicalRecordRepository(
        api,
      ).editorMedications(const SelfRecordSubject());
      final snapshot = (result as Ok<MedicationSnapshot>).value;
      expect(snapshot.current.length, 3);
      expect(snapshot.listVersion, 7);
      expect(api.medicationQueries.map((q) => q['cursor']), [
        null,
        'CURRENT-1',
        'CURRENT-2',
        null,
        'PAST-1',
        'PAST-2',
      ]);
      expect(api.medicationQueries.every((q) => q['size'] == '50'), isTrue);

      final endless = _ReadApi(pagesPerGroup: 1000);
      final capped = await MedicalRecordRepository(
        endless,
      ).editorMedications(const SelfRecordSubject());
      expect(capped, isA<Err<MedicationSnapshot>>());
      expect(
        endless.medicationQueries.length,
        MedicalRecordRepository.editorMaxPages,
      );
    });
  });

  group('the save sequence', () {
    test(
      'only changed sections are sent, in order, to the subject on screen',
      () async {
        final f = await _Fixture.loaded(subject: _family);
        final outcome = await f.editor.save(
          f.untouched(
            bloodType: 'B+',
            heightText: '171',
            conditionLabels: ['Asthme', 'Migraine'],
          ),
        );
        expect(outcome, EditorSaveOutcome.done);
        expect(f.writes.calls.map((c) => c.section), [
          RecordSection.bloodType,
          RecordSection.measurements,
          RecordSection.conditions,
        ]);
        expect(f.writes.calls.every((c) => c.subject == _family), isTrue);
        expect(f.reads.calls.every((c) => c == 'FAMILY:fam-1'), isTrue);
      },
    );

    test('« Réessayer » reuses the key; an edit makes a new one', () async {
      final f = await _Fixture.loaded();
      f.writes.fail(RecordSection.conditions, _status(503, 'MRS_UNAVAILABLE'));
      final draft = f.untouched(conditionLabels: ['Asthme', 'Migraine']);
      expect(await f.editor.save(draft), EditorSaveOutcome.failed);
      final first = f.writes.calls.last.key;
      expect(
        f.editor.failureOf(RecordSection.conditions)!.code,
        'MRS_UNAVAILABLE',
      );
      expect(f.editor.pendingKeyOf(RecordSection.conditions), first);

      expect(await f.editor.save(draft), EditorSaveOutcome.done);
      expect(f.writes.calls.last.key, first);

      f.writes.fail(RecordSection.conditions, _status(503, 'MRS_UNAVAILABLE'));
      final next = f.untouched(conditionLabels: ['Asthme', 'Arthrite']);
      await f.editor.save(next);
      f.editor.edited(RecordSection.conditions);
      expect(f.editor.pendingKeyOf(RecordSection.conditions), isNull);
      expect(f.editor.failureOf(RecordSection.conditions), isNull);
      await f.editor.save(next);
      expect(
        f.writes.calls.last.key,
        isNot(f.writes.calls[f.writes.calls.length - 2].key),
      );
    });

    test('a section that saved stays saved when a later one fails', () async {
      final f = await _Fixture.loaded();
      f.writes.fail(RecordSection.conditions, _status(503, 'MRS_UNAVAILABLE'));
      final draft = f.untouched(
        allergyLabels: ['Allergie Pénicilline', 'Lactose'],
        conditionLabels: ['Asthme', 'Migraine'],
      );
      expect(await f.editor.save(draft), EditorSaveOutcome.failed);
      expect(f.editor.savedSomething, isTrue);
      expect(f.editor.failureOf(RecordSection.allergies), isNull);
      // The saved section was read back (its new item now has an id).
      expect(f.editor.baseline!.allergiesVersion, 4);

      f.writes.calls.clear();
      expect(await f.editor.save(draft), EditorSaveOutcome.done);
      expect(f.writes.calls.map((c) => c.section), [RecordSection.conditions]);
    });

    test('409 reloads that section and keeps the draft; the next save uses '
        'the new version', () async {
      final f = await _Fixture.loaded();
      f.writes.fail(
        RecordSection.conditions,
        _status(409, 'RECORD_VERSION_CONFLICT', currentVersion: 6),
      );
      f.reads.medicalData = _medicalData(conditionsVersion: 6);
      final draft = f.untouched(conditionLabels: ['Asthme', 'Migraine']);
      expect(await f.editor.save(draft), EditorSaveOutcome.failed);
      final failure = f.editor.failureOf(RecordSection.conditions)!;
      expect(failure, isA<RecordVersionConflictFailure>());
      expect(recordFailureMessage(failure, _fr), _fr.recordCodeVersionConflict);
      expect(f.editor.baseline!.conditionsVersion, 6);
      expect(
        f.editor.baseline!.allergiesVersion,
        3,
        reason: 'others untouched',
      );

      final firstKey = f.writes.calls.last.key;
      expect(await f.editor.save(draft), EditorSaveOutcome.done);
      expect(f.writes.calls.last.body, {
        'items': [
          {'itemId': 'c-own', 'label': 'Asthme'},
          {'label': 'Migraine'},
        ],
        'expectedVersion': 6,
      });
      expect(f.writes.calls.last.key, isNot(firstKey));
    });

    test(
      'a server field error lands on its row; a past item on the list',
      () async {
        final f = await _Fixture.loaded();
        final draft = f.untouched();
        final rows = [
          ...draft.medications,
          const MedicationInput(key: 8, name: 'Nouveau'),
        ];
        f.writes.fail(
          RecordSection.declaredMedications,
          _status(
            400,
            'VALIDATION_ERROR',
            fieldErrorCodes: {
              'items.1.name': 'DUPLICATE',
              'items[2].name': 'TOO_LONG',
            },
          ),
        );
        expect(
          await f.editor.save(_withMedications(draft, rows)),
          EditorSaveOutcome.failed,
        );
        expect(f.editor.failureOf(RecordSection.declaredMedications), isNull);
        expect(
          f.editor.fieldError('medications:8.name')!.kind,
          ApiFieldErrorKind.duplicate,
        );
        expect(
          f.editor.fieldError('medications')!.kind,
          ApiFieldErrorKind.tooLong,
        );
        f.editor.edited(RecordSection.declaredMedications);
        expect(f.editor.fieldError('medications:8.name'), isNull);
      },
    );

    test(
      'a professional item the server locks shows its French text',
      () async {
        final f = await _Fixture.loaded();
        f.writes.fail(RecordSection.allergies, _status(422, 'ITEM_LOCKED'));
        await f.editor.save(f.untouched(allergyLabels: []));
        expect(
          recordFailureMessage(
            f.editor.failureOf(RecordSection.allergies)!,
            _fr,
          ),
          _fr.recordCodeItemLocked,
        );
      },
    );

    test('warnings are kept and never block', () async {
      final f = await _Fixture.loaded();
      f.writes.warnings = ['HEIGHT_UNUSUAL'];
      expect(
        await f.editor.save(f.untouched(heightText: '250')),
        EditorSaveOutcome.done,
      );
      expect(f.editor.warnings, [RecordWarning.heightUnusual]);
      expect(
        recordWarningMessage(f.editor.warnings.single, _fr),
        'Valeur inhabituelle : vérifiez-la.',
      );
    });

    test(
      'a failed read shows the failure; « Réessayer » reads again',
      () async {
        final f = _Fixture();
        f.reads.failMedicalData = true;
        await f.editor.load();
        expect(f.editor.state, isA<SectionFailed<EditorBaseline>>());
        f.reads.failMedicalData = false;
        await f.editor.load();
        expect(f.editor.state, isA<SectionReady<EditorBaseline>>());
      },
    );
  });

  group('BMI', () {
    test('the category at each boundary (as shown, one decimal)', () {
      expect(bmiCategoryOf(null), isNull);
      expect(bmiCategoryOf(18.4), BmiCategory.underweight);
      expect(bmiCategoryOf(18.5), BmiCategory.normal);
      expect(bmiCategoryOf(24.9), BmiCategory.normal);
      expect(bmiCategoryOf(25.0), BmiCategory.overweight);
      expect(bmiCategoryOf(29.9), BmiCategory.overweight);
      expect(bmiCategoryOf(30.0), BmiCategory.obese);
      expect(displayedBmi(null, 70), isNull);
      expect(displayedBmi(170, 0), isNull);
      expect(displayedBmi(170, 70), 24.2);
      // 59.9 / 1.8² = 18.49 → shown 18.5 → « Normal », as on screen.
      expect(bmiCategoryOf(displayedBmi(180, 59.9)), BmiCategory.normal);
    });
  });

  group('« Déclaré par le patient »', () {
    test(
      'a declared medication carries the label; a prescription does not',
      () {
        final baseline = _baseline();
        final declared = passportMedication(
          baseline.ownCurrentDeclared.single,
          current: true,
          l10n: _fr,
        );
        final prescription = passportMedication(
          baseline.readOnlyCurrentMedications.single,
          current: true,
          l10n: _fr,
        );
        expect(declared.declaredLabel, 'Déclaré par le patient');
        expect(prescription.declaredLabel, isNull);
      },
    );
  });

  group('no value in logs', () {
    test('nothing is printed and no toString carries a value', () async {
      final printed = <String?>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = original);

      final f = await _Fixture.loaded();
      f.writes.fail(RecordSection.allergies, _status(503, 'MRS_UNAVAILABLE'));
      final draft = f.untouched(allergyLabels: ['secret-allergy-zz']);
      await f.editor.save(draft);
      expect(printed, isEmpty);
      for (final value in [
        draft,
        draft.medications.single,
        f.editor.baseline,
        f.editor.failureOf(RecordSection.allergies)!.logSummary,
      ]) {
        expect('$value', isNot(contains('secret-allergy-zz')));
        expect('$value', isNot(contains('Doliprane')));
      }
    });
  });
}

// ---- fixtures ----

Map<String, Object?> _medicalData({
  String? bloodType = 'A+',
  String bloodTypeAuthor = 'PATIENT',
  int bloodTypeVersion = 2,
  double? heightCm = 170,
  double? weightKg = 70,
  int conditionsVersion = 5,
  int allergiesVersion = 3,
  List<Map<String, Object?>>? allergyItems,
}) => {
  'lifeSafety': {
    'bloodType': bloodType,
    'bloodTypeAuthorType': bloodTypeAuthor,
    'bloodTypeVersion': bloodTypeVersion,
    'allergiesStatus': 'LIST',
    'allergyItems':
        allergyItems ??
        [
          {
            'itemId': 'a-own',
            'label': 'Allergie Pénicilline',
            'authorType': 'PATIENT',
            'severity': 'SEVERE',
          },
          {'itemId': 'a-pro', 'label': 'Pollen', 'authorType': 'PROFESSIONAL'},
        ],
    'allergiesVersion': allergiesVersion,
    'conditionsStatus': 'LIST',
    'conditionItems': [
      {'itemId': 'c-own', 'label': 'Asthme', 'authorType': 'PATIENT'},
      {'itemId': 'c-pro', 'label': 'Lupus', 'authorType': 'PROFESSIONAL'},
    ],
    'conditionsVersion': conditionsVersion,
  },
  'bodyMeasurements': {
    'heightCm': heightCm,
    'weightKg': weightKg,
    'authorType': 'PATIENT',
    'version': 1,
  },
};

final _prescription = {
  'medicationStatementId': 'rx-1',
  'name': 'Amlodipine',
  'source': 'PRESCRIPTION',
  'authorType': 'PROFESSIONAL',
};
final _ownCurrent = {
  'medicationStatementId': 'm-own',
  'itemId': 'm-own',
  'name': 'Doliprane',
  'dosageText': '500 mg',
  'timesPerDay': 2,
  'duration': {'value': 5, 'unit': 'DAY'},
  'startedOn': '2026-11-01',
  'source': 'PATIENT_DECLARED',
  'authorType': 'PATIENT',
};
final _ownPast = {
  'medicationStatementId': 'm-past',
  'itemId': 'm-past',
  'name': 'Ibuprofène',
  'duration': {'value': 3, 'unit': 'DAY'},
  'startedOn': '2026-10-01',
  'source': 'PATIENT_DECLARED',
  'authorType': 'PATIENT',
};

EditorBaseline _baseline({Map<String, Object?>? medicalData}) =>
    EditorBaseline.read(
      MedicalDataRecord.fromJson(medicalData ?? _medicalData()),
      MedicationSnapshot(
        current: [
          MedicationRecord.fromJson(_prescription),
          MedicationRecord.fromJson(_ownCurrent),
        ],
        past: [MedicationRecord.fromJson(_ownPast)],
        listVersion: 7,
      ),
    );

EditorDraft _draftOf(
  EditorBaseline baseline, {
  String? bloodType,
  String? heightText,
  String? weightText,
  List<String>? allergyLabels,
  List<String>? conditionLabels,
}) {
  final draft = EditorDraft.of(baseline);
  return EditorDraft(
    bloodType: bloodType ?? draft.bloodType,
    heightText: heightText ?? draft.heightText,
    weightText: weightText ?? draft.weightText,
    allergyLabels: allergyLabels ?? draft.allergyLabels,
    conditionLabels: conditionLabels ?? draft.conditionLabels,
    medications: draft.medications,
  );
}

EditorDraft _withMedications(EditorDraft draft, List<MedicationInput> rows) =>
    EditorDraft(
      bloodType: draft.bloodType,
      heightText: draft.heightText,
      weightText: draft.weightText,
      allergyLabels: draft.allergyLabels,
      conditionLabels: draft.conditionLabels,
      medications: rows,
    );

DioException _status(
  int status,
  String code, {
  int? currentVersion,
  Map<String, String>? fieldErrorCodes,
}) {
  final options = RequestOptions(path: '/me/medical-record');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: {
        'code': code,
        'message': 'server text never shown',
        'currentVersion': ?currentVersion,
        if (fieldErrorCodes != null) ...{
          'fieldErrors': {for (final k in fieldErrorCodes.keys) k: 'x'},
          'fieldErrorCodes': fieldErrorCodes,
        },
      },
    ),
  );
}

class _Fixture {
  _Fixture({RecordSubject subject = const SelfRecordSubject()}) {
    writes.readsToNotify = reads;
    editor = MedicalDataEditorViewModel(
      reads: MedicalRecordRepository(reads),
      writes: MedicalRecordWriteRepository(writes),
      subject: subject,
      now: () => _now,
    );
  }

  static Future<_Fixture> loaded({
    RecordSubject subject = const SelfRecordSubject(),
    Map<String, Object?>? medicalData,
  }) async {
    final f = _Fixture(subject: subject);
    if (medicalData != null) f.reads.medicalData = medicalData;
    await f.editor.load();
    return f;
  }

  final _ReadApi reads = _ReadApi();
  final _WriteApi writes = _WriteApi();
  late final MedicalDataEditorViewModel editor;

  EditorDraft untouched({
    String? bloodType,
    String? heightText,
    List<String>? allergyLabels,
    List<String>? conditionLabels,
  }) => _draftOf(
    editor.baseline!,
    bloodType: bloodType,
    heightText: heightText,
    allergyLabels: allergyLabels,
    conditionLabels: conditionLabels,
  );
}

class _ReadApi implements MedicalRecordApiContract {
  _ReadApi({this.pagesPerGroup = 1});

  final int pagesPerGroup;
  Map<String, Object?> medicalData = _medicalData();
  bool failMedicalData = false;
  final List<String> calls = [];
  final List<Map<String, String>> medicationQueries = [];

  /// As the server: the saved allergies come back with ids, own items first,
  /// then the professional one, at the new version.
  void savedAllergies(List<Object?> items, int version) {
    var next = 0;
    medicalData = _medicalData(
      allergiesVersion: version,
      allergyItems: [
        for (final item in items.cast<Map<String, Object?>>())
          {
            'itemId': item['itemId'] ?? 'a-new-${next++}',
            'label': item['label'],
            'authorType': 'PATIENT',
            'severity': ?item['severity'],
          },
        {'itemId': 'a-pro', 'label': 'Pollen', 'authorType': 'PROFESSIONAL'},
      ],
    );
  }

  @override
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query = const {},
    CancelToken? cancelToken,
  }) async {
    calls.add(subject.queryValue);
    switch (resource) {
      case MedicalRecordResource.medicalData:
        if (failMedicalData) throw _status(503, 'MRS_UNAVAILABLE');
        return medicalData;
      case MedicalRecordResource.medications:
        medicationQueries.add(query);
        final group = query['group']!;
        final page = query['cursor'] == null
            ? 0
            : int.parse(query['cursor']!.split('-').last);
        final last = page >= pagesPerGroup - 1;
        return {
          'items': group == 'CURRENT'
              ? (pagesPerGroup == 1
                    ? [_prescription, _ownCurrent]
                    : [
                        {..._ownCurrent, 'medicationStatementId': 'p$page'},
                      ])
              : (page == 0 ? [_ownPast] : <Object?>[]),
          'nextCursor': last ? null : '$group-${page + 1}',
          'listStatus': 'LIST',
          'listVersion': 7,
        };
      case MedicalRecordResource.consultations:
        return {'items': <Object?>[]};
    }
  }
}

class _WriteCall {
  _WriteCall(this.section, this.subject, this.body, this.key);

  final RecordSection section;
  final RecordSubject subject;
  final Map<String, Object?> body;
  final String key;
}

class _WriteApi implements MedicalRecordWriteApiContract {
  final List<_WriteCall> calls = [];
  final Map<RecordSection, DioException> _failures = {};
  List<String> warnings = const [];
  _ReadApi? readsToNotify;

  /// The next save of [section] fails once with [error].
  void fail(RecordSection section, DioException error) =>
      _failures[section] = error;

  @override
  Future<Object?> put(
    RecordSection section,
    RecordSubject subject,
    Map<String, Object?> body, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    calls.add(_WriteCall(section, subject, body, idempotencyKey));
    final failure = _failures.remove(section);
    if (failure != null) throw failure;
    final version = ((body['expectedVersion'] as int?) ?? 0) + 1;
    if (section == RecordSection.allergies) {
      readsToNotify?.savedAllergies(body['items']! as List<Object?>, version);
    }
    return {'section': section.name, 'version': version, 'warnings': warnings};
  }
}
