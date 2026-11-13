// G2.1-A3: « Ma Santé », the family-member screen and onboarding save
// through the record's section saves. Logic only (CTO testing rule): the
// screens' draft builder and mapping, the shared editor view model against
// fake APIs, and the onboarding checks. No widget, no app run. Every value
// here is synthetic.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/features/home/medical_data_edit_mapping.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_basics_payload.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_validation.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_data_editor_draft.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_data_editor_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_messages.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_presenter.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));
const _self = SelfRecordSubject();
const _family = FamilyRecordSubject('fm-1');

void main() {
  group('« Ma Santé » and the family-member screen', () {
    for (final subject in const <RecordSubject>[_self, _family]) {
      test('${subject.queryValue}: blood type, conditions and medications '
          'are saved to that person only; height, weight and allergies are '
          'never sent', () async {
        final f = await _Fixture.loaded(subject);
        final outcome = await f.editor.save(
          f.draft(
            bloodType: 'B+',
            conditions: ['Asthme', 'Migraine'],
            medications: [
              ...f.ownRows(),
              const MedicationInput(
                key: 7,
                name: 'Vitamine D',
                dosageText: '1000 UI',
                timesPerDay: 1,
              ),
            ],
          ),
        );
        expect(outcome, EditorSaveOutcome.done);
        expect(f.writes.calls.map((c) => c.section), [
          RecordSection.bloodType,
          RecordSection.conditions,
          RecordSection.declaredMedications,
        ]);
        expect(f.writes.calls.every((c) => c.subject == subject), isTrue);
        expect(f.reads.subjects.toSet(), {subject.queryValue});
        expect(f.writes.calls[0].body, {'value': 'B+', 'expectedVersion': 2});
        expect(f.writes.calls[1].body, {
          'items': [
            {'itemId': 'c-own', 'label': 'Asthme'},
            {'label': 'Migraine'},
          ],
          'expectedVersion': 5,
        });
        expect(f.writes.calls[2].body['items'], [
          {
            'itemId': 'm-own',
            'name': 'Doliprane',
            'dosageText': '500 mg',
            'timesPerDay': 2,
            'duration': {'value': 5, 'unit': 'DAY'},
            'startedOn': '2026-11-01',
          },
          {'name': 'Vitamine D', 'dosageText': '1000 UI', 'timesPerDay': 1},
        ]);
      });
    }

    test('nothing changed: nothing is sent (the old honesty SnackBar is gone: '
        'conditions and medications now save)', () async {
      final f = await _Fixture.loaded(_self);
      expect(await f.editor.save(f.draft()), EditorSaveOutcome.done);
      expect(f.writes.calls, isEmpty);
    });

    test('« - » is never sent; « Je ne sais pas » sends UNKNOWN', () async {
      final f = await _Fixture.loaded(_self);
      await f.editor.save(f.draft(bloodType: null));
      expect(f.writes.calls, isEmpty);
      await f.editor.save(f.draft(bloodType: bloodTypeUnknown));
      expect(f.writes.calls.single.body['value'], 'UNKNOWN');
    });

    test(
      'professional items: shown, never sent; `critical` never sent',
      () async {
        final f = await _Fixture.loaded(_family);
        final baseline = f.editor.baseline!;
        expect(professionalLabelKeys(baseline.conditions), {'lupus'});
        expect(conditionChipLabels(baseline.conditions), contains('Lupus'));
        await f.editor.save(f.draft(conditions: const []));
        final body = jsonEncode(f.writes.calls.single.body);
        expect(body, isNot(contains('Lupus')));
        expect(body, isNot(contains('critical')));
        expect(f.writes.calls.single.body['items'], isEmpty);
      },
    );

    test('a typed medication name saves without the catalog', () async {
      final f = await _Fixture.loaded(_self);
      await f.editor.save(
        f.draft(
          medications: [
            ...f.ownRows(),
            const MedicationInput(key: 9, name: 'Nom libre'),
          ],
        ),
      );
      expect((f.writes.calls.single.body['items'] as List).last, {
        'name': 'Nom libre',
      });
    });

    test('an empty medication name is refused, never dropped', () async {
      final f = await _Fixture.loaded(_self);
      final outcome = await f.editor.save(
        f.draft(
          medications: [
            ...f.ownRows(),
            const MedicationInput(key: 9, name: ' '),
          ],
        ),
      );
      expect(outcome, EditorSaveOutcome.invalid);
      expect(f.writes.calls, isEmpty);
      expect(
        f.editor.fieldError('medications:9.name')!.kind,
        ApiFieldErrorKind.required,
      );
    });

    test(
      'a refused save keeps everything; « Réessayer » reuses the key',
      () async {
        final f = await _Fixture.loaded(_family);
        f.writes.failNext = _status(503, 'MRS_UNAVAILABLE');
        final draft = f.draft(conditions: ['Asthme', 'Arthrite']);
        expect(await f.editor.save(draft), EditorSaveOutcome.failed);
        final key = f.writes.calls.single.key;
        expect(
          recordFailureMessage(
            f.editor.failureOf(RecordSection.conditions)!,
            _fr,
          ),
          _fr.apiCodeMrsUnavailable,
        );
        expect(await f.editor.save(draft), EditorSaveOutcome.done);
        expect(f.writes.calls.last.key, key);
      },
    );
  });

  group('no value in logs', () {
    test('a failing family save prints nothing', () async {
      final printed = <String?>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = original);
      final f = await _Fixture.loaded(_family);
      f.writes.failNext = _status(503, 'MRS_UNAVAILABLE');
      await f.editor.save(f.draft(conditions: ['secret-condition-zz']));
      expect(printed, isEmpty);
      expect(
        f.editor.failureOf(RecordSection.conditions)!.logSummary,
        isNot(contains('secret-condition-zz')),
      );
    });
  });

  group('the « Fréquence » text', () {
    test('a number of takes per day is read; nothing is guessed', () {
      for (final (text, expected) in [
        ('', null),
        ('  ', null),
        ('2', 2),
        ('2x/jour', 2),
        ('2 x / jour', 2),
        ('2× par jour', 2),
        ('3 fois par jour', 3),
        ('1X/J', 1),
        ('matin et soir', 0),
        ('2-3x/jour', 0),
      ]) {
        expect(timesPerDayOfText(text), expected, reason: text);
      }
    });

    test(
      'a stored value reads back unchanged (an untouched row is not sent)',
      () {
        for (final times in [null, 1, 2, 6]) {
          expect(timesPerDayOfText(frequencyTextOf(times)), times);
        }
        expect(frequencyTextOf(2), '2x/jour');
      },
    );

    test('a text that is not a number of takes is refused in French', () {
      final baseline = _baseline();
      for (final text in ['matin et soir', '7']) {
        final plan = planMedications(
          baseline,
          editMedicalDataDraft(
            baseline: baseline,
            bloodType: baseline.bloodType,
            conditions: const ['Asthme'],
            medications: [
              MedicationInput(
                key: 1,
                name: 'X',
                timesPerDay: timesPerDayOfText(text),
              ),
            ],
          ),
          now: DateTime.utc(2026, 11, 12),
        );
        final error = (plan as SectionInvalid).errors.single;
        expect(error.path, 'items[0].timesPerDay');
        expect(
          recordFieldMessage(error.path, error.kind, _fr),
          'Entre 1 et 6 prises par jour.',
        );
      }
    });
  });

  group('the condition chips', () {
    test('presets (shared list, no « Allergie Pénicilline »), then own, then '
        'professional; each label once, any case', () {
      final chips = conditionChipLabels([
        _item('c-1', 'asthme', 'PATIENT'),
        _item('c-2', 'Maladie rare', 'PATIENT'),
        _item('c-3', 'Lupus', 'PROFESSIONAL'),
        _item('c-4', 'maladie rare', 'PROFESSIONAL'),
      ]);
      expect(chips, isNot(contains('Allergie Pénicilline')));
      expect(chips.where((c) => labelKey(c) == 'asthme').length, 1);
      expect(chips.sublist(chips.length - 2), ['Maladie rare', 'Lupus']);
    });
  });

  group('onboarding', () {
    test('conditions go as chosen (French labels), never critical', () {
      final body = onboardingStep3Body(const ['Asthme', ' Diabète ']);
      expect(body, {
        'conditions': [
          {'name': 'Asthme', 'criticalOptIn': false},
          {'name': 'Diabète', 'criticalOptIn': false},
        ],
      });
      expect(onboardingStep3Body(const []), {'noKnownConditions': true});
    });

    test('allergies go as typed; « Non » is none', () {
      final body = onboardingStep2Body([
        AllergyEntry(name: 'Lactose', severity: 'légère', lifeSafety: false),
      ]);
      expect(body, {
        'allergies': [
          {'name': 'Lactose', 'severity': 'légère', 'lifeSafety': false},
        ],
      });
      expect(onboardingStep2Body(const []), {'noKnownAllergies': true});
    });

    test('step 4 invents nothing: no fixed frequency, no start date', () {
      for (final answer in const [true, false, null]) {
        final body = jsonEncode(onboardingStep4Body(answer));
        expect(body, isNot(contains('1x daily')));
        expect(body, isNot(contains('startDate')));
      }
    });

    test('A3b: « Non » is « Aucun »; « Oui » (no field in V1) sends nothing '
        'for medications, so the list stays « Non renseigné »', () {
      expect(onboardingStep4Body(false), {'noKnownMedications': true});
      expect(onboardingStep4Body(true), isEmpty);
      expect(onboardingStep4Body(null), isEmpty);
    });

    test('A3b: the « Oui » note text is in the ARB', () {
      expect(
        _fr.onboardingMedicationsInRecord,
        'Vous pourrez ajouter vos médicaments dans votre dossier médical.',
      );
      expect(_fr.onboardingMedicationsInRecord, isNot(contains('bientôt')));
    });

    test('A3b: an empty, never-recorded treatments list reads '
        '« Non renseigné », never « Aucun traitement »', () {
      expect(
        medicationsEmptyText(
          current: true,
          l10n: _fr,
          listStatus: RecordListStatus.unknown,
        ),
        'Non renseigné',
      );
      expect(
        medicationsEmptyText(
          current: true,
          l10n: _fr,
          listStatus: RecordListStatus.noneKnown,
        ),
        _fr.passportNoCurrentMedications,
      );
      expect(
        medicationsEmptyText(current: true, l10n: _fr),
        _fr.passportNoCurrentMedications,
      );
    });

    test('« Je ne sais pas » is the record\'s UNKNOWN', () {
      expect(recordBloodTypeValue(BloodType.unknown), 'UNKNOWN');
      expect(recordBloodTypeValue(BloodType.oPositive), 'O+');
    });

    test('measurements: French, with the record\'s ranges', () {
      String? error(String h, String w) => onboardingMeasurementsError(
        rawHeight: h,
        rawWeight: w,
        heightCm: num.tryParse(h),
        weightKg: num.tryParse(w),
        l10n: _fr,
      );
      expect(error('', '70'), 'Indiquez votre taille.');
      expect(error('170', ''), 'Indiquez votre poids.');
      expect(
        error('29', '70'),
        'La taille doit être comprise entre 30 et 300 cm.',
      );
      expect(
        error('301', '70'),
        'La taille doit être comprise entre 30 et 300 cm.',
      );
      expect(error('300', '500'), isNull);
      expect(
        error('170', '0'),
        'Le poids doit être compris entre 0 et 500 kg.',
      );
      expect(
        error('170', '500.5'),
        'Le poids doit être compris entre 0 et 500 kg.',
      );
    });

    test('allergies: « Oui » needs one; names follow the record\'s rules', () {
      String? error(bool? answer, List<String> names) =>
          onboardingAllergiesError(
            answer: answer,
            rows: [
              for (final name in names)
                (name: name, severity: 'modérée', lifeSafety: false),
            ],
            l10n: _fr,
          );
      expect(error(true, const ['']), 'Indiquez le nom de l’allergie.');
      expect(error(false, const ['']), isNull);
      expect(error(true, ['x' * 161]), '160 caractères maximum.');
      expect(
        error(true, const ['Lait', 'LAIT']),
        'Cet élément figure déjà dans la liste.',
      );
      expect(
        error(true, const ['Lait\u202E']),
        'Ce texte contient des caractères non autorisés.',
      );
      expect(
        error(true, [for (var i = 0; i < 51; i++) 'a$i']),
        '50 éléments maximum.',
      );
      expect(error(true, const ['Lactose']), isNull);
      expect(
        onboardingAllergiesError(
          answer: true,
          rows: const [(name: 'Lactose', severity: '', lifeSafety: false)],
          l10n: _fr,
        ),
        'Choisissez la gravité de l’allergie.',
      );
    });

    test('conditions: « Oui » needs one; « Non » is none', () {
      expect(
        onboardingConditionsError(
          answer: true,
          conditions: const [],
          l10n: _fr,
        ),
        'Choisissez au moins une maladie, ou répondez « Non ».',
      );
      expect(
        onboardingConditionsError(
          answer: false,
          conditions: const [],
          l10n: _fr,
        ),
        isNull,
      );
      expect(
        onboardingConditionsError(
          answer: true,
          conditions: const ['Asthme'],
          l10n: _fr,
        ),
        isNull,
      );
    });

    test('every onboarding message is French (no English left)', () {
      final messages = [
        _fr.onboardingErrorFirstName,
        _fr.onboardingErrorLastName,
        _fr.onboardingErrorBirthDate,
        _fr.onboardingErrorBirthDatePast,
        _fr.onboardingErrorGender,
        _fr.onboardingErrorHeight,
        _fr.onboardingErrorWeight,
        _fr.onboardingErrorAllergyName,
        _fr.onboardingErrorAllergySeverity,
        _fr.onboardingErrorConditionRequired,
        _fr.recordFieldHeightRange,
        _fr.recordFieldWeightRange,
        _fr.onboardingSaveFailed,
        _fr.saveInvalidInput,
      ];
      final english = RegExp(
        r'\b(please|enter|required|invalid|must|select|name)\b',
        caseSensitive: false,
      );
      for (final message in messages) {
        expect(english.hasMatch(message), isFalse, reason: message);
      }
    });
  });
}

// ---- fixtures ----

RecordItem _item(String id, String label, String author) => RecordItem(
  itemId: id,
  label: label,
  author: RecordAuthor.fromServer(author),
);

Map<String, Object?> _medicalData() => {
  'lifeSafety': {
    'bloodType': 'A+',
    'bloodTypeAuthorType': 'PATIENT',
    'bloodTypeVersion': 2,
    'allergiesStatus': 'LIST',
    'allergyItems': [
      {'itemId': 'a-own', 'label': 'Pollen', 'authorType': 'PATIENT'},
    ],
    'allergiesVersion': 3,
    'conditionsStatus': 'LIST',
    'conditionItems': [
      {'itemId': 'c-own', 'label': 'Asthme', 'authorType': 'PATIENT'},
      {'itemId': 'c-pro', 'label': 'Lupus', 'authorType': 'PROFESSIONAL'},
    ],
    'conditionsVersion': 5,
  },
  'bodyMeasurements': {
    'heightCm': 170,
    'weightKg': 70.25,
    'authorType': 'PATIENT',
    'version': 1,
  },
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
final _prescription = {
  'medicationStatementId': 'rx-1',
  'name': 'Amlodipine',
  'source': 'PRESCRIPTION',
  'authorType': 'PROFESSIONAL',
};

EditorBaseline _baseline() => EditorBaseline.read(
  MedicalDataRecord.fromJson(_medicalData()),
  MedicationSnapshot(
    current: [
      MedicationRecord.fromJson(_prescription),
      MedicationRecord.fromJson(_ownCurrent),
    ],
    past: const [],
    listVersion: 7,
  ),
);

DioException _status(int status, String code) {
  final options = RequestOptions(path: '/me/medical-record');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: {'code': code, 'message': 'server text never shown'},
    ),
  );
}

class _Fixture {
  _Fixture(RecordSubject subject) {
    editor = MedicalDataEditorViewModel(
      reads: MedicalRecordRepository(reads),
      writes: MedicalRecordWriteRepository(writes),
      subject: subject,
      now: () => DateTime.utc(2026, 11, 12, 10),
    );
  }

  static Future<_Fixture> loaded(RecordSubject subject) async {
    final f = _Fixture(subject);
    await f.editor.load();
    return f;
  }

  final _ReadApi reads = _ReadApi();
  final _WriteApi writes = _WriteApi();
  late final MedicalDataEditorViewModel editor;

  /// The own rows exactly as the screen shows them (frequency through its
  /// text, as the screen does).
  List<MedicationInput> ownRows() => [
    for (final row in EditorDraft.of(editor.baseline!).medications)
      MedicationInput(
        key: row.key,
        itemId: row.itemId,
        name: row.name,
        dosageText: row.dosageText,
        timesPerDay: timesPerDayOfText(frequencyTextOf(row.timesPerDay)),
        durationText: row.durationText,
        durationUnit: row.durationUnit,
        startedOn: row.startedOn,
      ),
  ];

  /// The draft the screen builds; unchanged values by default.
  EditorDraft draft({
    String? bloodType = 'A+',
    List<String>? conditions,
    List<MedicationInput>? medications,
  }) => editMedicalDataDraft(
    baseline: editor.baseline!,
    bloodType: bloodType,
    conditions: conditions ?? const ['Asthme'],
    medications: medications ?? ownRows(),
  );
}

class _ReadApi implements MedicalRecordApiContract {
  final List<String> subjects = [];

  @override
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query = const {},
    CancelToken? cancelToken,
  }) async {
    subjects.add(subject.queryValue);
    return switch (resource) {
      MedicalRecordResource.medicalData => _medicalData(),
      MedicalRecordResource.medications => {
        'items': query['group'] == 'CURRENT'
            ? [_prescription, _ownCurrent]
            : <Object?>[],
        'listStatus': 'LIST',
        'listVersion': 7,
      },
      MedicalRecordResource.consultations => {'items': <Object?>[]},
    };
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
  DioException? failNext;

  @override
  Future<Object?> put(
    RecordSection section,
    RecordSubject subject,
    Map<String, Object?> body, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    calls.add(_WriteCall(section, subject, body, idempotencyKey));
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    return {
      'section': section.name,
      'version': ((body['expectedVersion'] as int?) ?? 0) + 1,
      'warnings': const <String>[],
    };
  }
}
