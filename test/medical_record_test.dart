// G-2 1b-3b and FT-3: the « Dossier médical » record, logic only (CTO testing
// rule): honest texts per status, failures never shown as empty lists,
// per-card retry, subject switch, logout, no build switch, real identity.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_record_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/application/passport_identity.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_presenter.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/widgets/passport_card_status.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));

/// One recorded call to the fake API.
class _Call {
  _Call(this.resource, this.subject, this.query);
  final MedicalRecordResource resource;
  final String subject;
  final Map<String, String> query;
}

/// A fake API whose answers the test releases one by one.
class _FakeApi implements MedicalRecordApiContract {
  final calls = <_Call>[];
  final _pending = <Completer<Object?>>[];
  final _pendingCalls = <_Call>[];

  @override
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query = const {},
    CancelToken? cancelToken,
  }) {
    final call = _Call(resource, subject.queryValue, query);
    calls.add(call);
    final completer = Completer<Object?>();
    _pending.add(completer);
    _pendingCalls.add(call);
    return completer.future;
  }

  /// Answers only the pending calls made for [subject], with [error].
  Future<void> failPendingFor(String subject, Object error) async {
    for (var index = _pending.length - 1; index >= 0; index--) {
      if (_pendingCalls[index].subject != subject) continue;
      _pending.removeAt(index).completeError(error);
      _pendingCalls.removeAt(index);
    }
    await pumpEventQueue();
  }

  /// Answers every pending call: the body for its resource, or [error].
  Future<void> answerAll({Object? error}) async {
    final pending = List.of(_pending);
    final pendingCalls = List.of(_pendingCalls);
    _pending.clear();
    _pendingCalls.clear();
    for (var index = 0; index < pending.length; index++) {
      final call = pendingCalls[index];
      if (error != null) {
        pending[index].completeError(error);
      } else {
        pending[index].complete(_bodyFor(call.resource));
      }
    }
    await pumpEventQueue();
  }

  int count(MedicalRecordResource resource) =>
      calls.where((call) => call.resource == resource).length;
}

Object _bodyFor(MedicalRecordResource resource) => switch (resource) {
  MedicalRecordResource.medicalData => _medicalData(),
  MedicalRecordResource.medications => {
    'items': [
      {'medicationStatementId': 'm1', 'name': 'Amlodipine', 'strength': '5 mg'},
    ],
    'nextCursor': null,
  },
  MedicalRecordResource.consultations => {
    'items': [_consultation()],
    'nextCursor': 'next',
  },
};

Map<String, Object?> _medicalData({
  String? bloodType = 'O+',
  String allergiesStatus = 'LIST',
  List<String> allergies = const ['Pénicilline'],
  String conditionsStatus = 'LIST',
  List<String> conditions = const ['Asthme'],
  Object? heightCm = 172,
  Object? weightKg = 70.5,
}) => {
  'lifeSafety': {
    'bloodType': bloodType,
    'allergies': allergies,
    'allergiesStatus': allergiesStatus,
    'criticalConditions': conditions,
    'conditionsStatus': conditionsStatus,
  },
  'bodyMeasurements': {
    'heightCm': heightCm,
    'weightKg': weightKg,
    'bmi': null,
    'measuredAt': null,
  },
};

Map<String, Object?> _consultation({Map<String, Object?>? professional}) => {
  'consultationId': 'c1',
  // 23:30 UTC is already the next day in Tunis (UTC+01:00).
  'completedAt': '2026-02-11T23:30:00Z',
  'professional':
      professional ??
      {'firstName': 'Karim', 'lastName': 'Mansour', 'specialty': 'Cardiologie'},
  'reason': 'Contrôle',
  'sharingState': 'SHAREABLE',
  'sharingPolicyVersion': 3,
};

DioException _mrsUnavailable() {
  final options = RequestOptions(path: '/me/medical-record/medical-data');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 503,
      data: {'code': 'MRS_UNAVAILABLE', 'message': 'server text'},
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
    ),
  );
}

MedicalRecordViewModel _viewModel(_FakeApi api) =>
    MedicalRecordViewModel(repository: MedicalRecordRepository(api));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('honest texts per status', () {
    MedicalDataRecord record(Map<String, Object?> json) =>
        MedicalDataRecord.fromJson(json);

    test('allergies: UNKNOWN, NONE_KNOWN, LIST', () {
      expect(
        allergiesText(record(_medicalData(allergiesStatus: 'UNKNOWN')), _fr),
        'Non renseigné',
      );
      expect(
        allergiesText(
          record(_medicalData(allergiesStatus: 'NONE_KNOWN', allergies: [])),
          _fr,
        ),
        'Aucune allergie connue',
      );
      expect(
        allergiesText(
          record(_medicalData(allergies: ['Pénicilline', 'Arachide'])),
          _fr,
        ),
        'Pénicilline, Arachide',
      );
      // An unknown server value is never read as "none".
      expect(
        allergiesText(record(_medicalData(allergiesStatus: 'MAYBE')), _fr),
        'Non renseigné',
      );
    });

    test('conditions: text for UNKNOWN / NONE_KNOWN, chips for LIST', () {
      final unknown = record(_medicalData(conditionsStatus: 'UNKNOWN'));
      expect(conditionsText(unknown, _fr), 'Non renseigné');
      expect(conditionChips(unknown), isEmpty);
      final none = record(
        _medicalData(conditionsStatus: 'NONE_KNOWN', conditions: []),
      );
      expect(conditionsText(none, _fr), 'Aucun antécédent connu');
      final list = record(_medicalData(conditions: ['Asthme', 'Diabète']));
      expect(conditionsText(list, _fr), isNull);
      expect(conditionChips(list), ['Asthme', 'Diabète']);
      // LIST with nothing in it is not "none".
      expect(
        conditionsText(record(_medicalData(conditions: [])), _fr),
        'Non renseigné',
      );
    });

    test('blood type and measurements: null stays null, never a default', () {
      final empty = record(
        _medicalData(bloodType: null, heightCm: null, weightKg: null),
      );
      expect(bloodTypeText(empty, _fr), 'Non renseigné');
      expect(empty.heightCm, isNull);
      expect(empty.weightKg, isNull);
      expect(empty.bmi, isNull);
      final full = record(_medicalData());
      expect(bloodTypeText(full, _fr), 'O+');
      expect(full.heightCm, 172);
      expect(full.weightKg, 70.5);
    });

    test('treatments: empty texts and the mapped row', () {
      expect(
        medicationsEmptyText(current: true, l10n: _fr),
        'Aucun traitement en cours prescrit sur OmniCare.',
      );
      expect(
        medicationsEmptyText(current: false, l10n: _fr),
        'Aucun ancien traitement prescrit sur OmniCare.',
      );
      final row = passportMedication(
        const MedicationRecord(id: 'm', name: 'Metformine', timesPerDay: 2),
        current: true,
        l10n: _fr,
      );
      expect(row.name, 'Metformine');
      expect(row.instruction, '2× par jour');
      final unnamed = passportMedication(
        const MedicationRecord(id: 'm', doseAmount: 1, doseUnit: 'TABLET'),
        current: false,
        l10n: _fr,
      );
      expect(unnamed.name, 'Non renseigné');
      expect(unnamed.instruction, '1 TABLET');
      expect(unnamed.isCurrent, isFalse);
    });

    test(
      'history: Tunis date, doctor, specialty as entered, missing values',
      () {
        final row = passportConsultation(
          ConsultationRecord.fromJson(_consultation()),
          _fr,
        );
        expect(row.date, '12 févr. 2026');
        expect(row.doctor, 'Dr Karim Mansour');
        expect(row.specialty, 'Cardiologie');
        expect(row.reason, 'Contrôle');
        expect(row.isShareable, isTrue);
        expect(row.sharingVersion, 3);
        final unknown = passportConsultation(
          ConsultationRecord.fromJson({
            ..._consultation(professional: const {}),
            'reason': null,
          }),
          _fr,
        );
        expect(unknown.doctor, 'Non renseigné');
        expect(unknown.specialty, 'Non renseigné');
        expect(unknown.reason, 'Non renseigné');
      },
    );
  });

  group('card status', () {
    test('failure → its French text and a retry; loading; ready → content', () {
      var retried = 0;
      final failed = cardStatus(
        SectionFailed<MedicalDataRecord>(ApiFailure.from(_mrsUnavailable())),
        _fr,
        () => retried++,
      );
      expect(failed, isA<PassportCardFailed>());
      expect(
        (failed! as PassportCardFailed).message,
        'Le dossier médical est temporairement indisponible. Réessayez plus tard.',
      );
      (failed as PassportCardFailed).onRetry();
      expect(retried, 1);
      expect(
        cardStatus(const SectionIdle<int>(), _fr, () {}),
        isA<PassportCardLoading>(),
      );
      expect(
        cardStatus(const SectionLoading<int>(), _fr, () {}),
        isA<PassportCardLoading>(),
      );
      expect(cardStatus(const SectionReady<int>(1), _fr, () {}), isNull);
    });
  });

  group('MedicalRecordViewModel', () {
    test('no switch: the default model loads the record (G2.1-S1)', () async {
      final api = _FakeApi();
      final model = MedicalRecordViewModel(
        repository: MedicalRecordRepository(api),
      );
      model.show(const SelfRecordSubject());
      expect(api.count(MedicalRecordResource.medicalData), 1);
      expect(api.count(MedicalRecordResource.medications), 1);
      expect(model.medicalData, isA<SectionLoading<MedicalDataRecord>>());
      await api.answerAll();
      expect(model.medicalData, isA<SectionReady<MedicalDataRecord>>());
    });

    test(
      'show(SELF): medical data and current treatments, first page only',
      () async {
        final api = _FakeApi();
        final model = _viewModel(api);
        model.show(const SelfRecordSubject());
        expect(model.medicalData, isA<SectionLoading<MedicalDataRecord>>());
        await api.answerAll();
        expect(api.calls.map((call) => call.subject), everyElement('SELF'));
        expect(api.count(MedicalRecordResource.medicalData), 1);
        final medications = api.calls.singleWhere(
          (call) => call.resource == MedicalRecordResource.medications,
        );
        expect(medications.query, {'group': 'CURRENT', 'size': '20'});
        expect(api.count(MedicalRecordResource.consultations), 0);
        expect(model.medicalData, isA<SectionReady<MedicalDataRecord>>());

        model.ensureLoaded(MedicalRecordSection.consultations);
        await api.answerAll();
        expect(api.calls.last.query, {
          'size': '20',
        }, reason: 'history: first page only, never all');
        final history = model.consultations;
        expect(history, isA<SectionReady<RecordPage<ConsultationRecord>>>());
        expect(
          (history as SectionReady<RecordPage<ConsultationRecord>>)
              .value
              .hasMore,
          isTrue,
        );
        // Already loaded: no second request.
        model.ensureLoaded(MedicalRecordSection.consultations);
        expect(api.count(MedicalRecordResource.consultations), 1);
      },
    );

    test('a failure is a failed state, never an empty list', () async {
      final api = _FakeApi();
      final model = _viewModel(api);
      model.show(const SelfRecordSubject());
      await api.answerAll(error: _mrsUnavailable());
      final medications = model.medications(current: true);
      expect(medications, isA<SectionFailed<RecordPage<MedicationRecord>>>());
      expect((medications as SectionFailed).failure.code, 'MRS_UNAVAILABLE');
      expect(model.medicalData, isA<SectionFailed<MedicalDataRecord>>());
    });

    test('a malformed body is a failure, not partial data', () async {
      final result = await MedicalRecordRepository(
        _MalformedApi(),
      ).consultations(const SelfRecordSubject());
      expect(result, isA<Err<RecordPage<ConsultationRecord>>>());
    });

    test('retry reloads that section only', () async {
      final api = _FakeApi();
      final model = _viewModel(api);
      model.show(const SelfRecordSubject());
      await api.answerAll(error: _mrsUnavailable());
      model.retry(MedicalRecordSection.currentMedications);
      expect(
        model.medications(current: true),
        isA<SectionLoading<RecordPage<MedicationRecord>>>(),
      );
      expect(model.medicalData, isA<SectionFailed<MedicalDataRecord>>());
      await api.answerAll();
      expect(api.count(MedicalRecordResource.medications), 2);
      expect(api.count(MedicalRecordResource.medicalData), 1);
      expect(
        model.medications(current: true),
        isA<SectionReady<RecordPage<MedicationRecord>>>(),
      );
      expect(model.medicalData, isA<SectionFailed<MedicalDataRecord>>());
    });

    test('family switch sends FAMILY:{id}, clears the previous data and drops '
        'late answers', () async {
      final api = _FakeApi();
      final model = _viewModel(api);
      model.show(const SelfRecordSubject());
      await api.answerAll();
      expect(model.medicalData, isA<SectionReady<MedicalDataRecord>>());

      model.show(const FamilyRecordSubject('fam-1'));
      expect(model.subject, const FamilyRecordSubject('fam-1'));
      expect(model.medicalData, isNot(isA<SectionReady<MedicalDataRecord>>()));
      expect(
        model.medications(current: true),
        isNot(isA<SectionReady<RecordPage<MedicationRecord>>>()),
      );
      expect(api.calls.last.subject, 'FAMILY:fam-1');

      // A late answer for the previous subject must not land: SELF fails
      // after the switch, FAMILY:fam-2 is still pending → still loading.
      final stale = _FakeApi();
      final staleModel = _viewModel(stale);
      staleModel.show(const SelfRecordSubject());
      staleModel.show(const FamilyRecordSubject('fam-2'));
      await stale.failPendingFor('SELF', _mrsUnavailable());
      expect(staleModel.medicalData, isA<SectionLoading<MedicalDataRecord>>());
      expect(
        staleModel.medications(current: true),
        isA<SectionLoading<RecordPage<MedicationRecord>>>(),
      );
      await stale.answerAll();
      expect(staleModel.medicalData, isA<SectionReady<MedicalDataRecord>>());
    });

    test('logout (clear) drops every value and the subject', () async {
      final api = _FakeApi();
      final model = _viewModel(api);
      model.show(const SelfRecordSubject());
      await api.answerAll();
      model.ensureLoaded(MedicalRecordSection.consultations);
      await api.answerAll();
      model.clear();
      expect(model.subject, isNull);
      expect(model.medicalData, isA<SectionIdle<MedicalDataRecord>>());
      expect(
        model.medications(current: true),
        isA<SectionIdle<RecordPage<MedicationRecord>>>(),
      );
      expect(
        model.consultations,
        isA<SectionIdle<RecordPage<ConsultationRecord>>>(),
      );
      // The same subject shown again is fetched again, not served from memory.
      model.show(const SelfRecordSubject());
      expect(api.count(MedicalRecordResource.medicalData), 2);
    });

    test('a confirmed sharing change updates that consultation only', () async {
      final api = _FakeApi();
      final model = _viewModel(api);
      model.show(const SelfRecordSubject());
      model.ensureLoaded(MedicalRecordSection.consultations);
      await api.answerAll();
      model.applyConsultationSharing(
        consultationId: 'c1',
        isShareable: false,
        sharingVersion: 4,
      );
      final item =
          (model.consultations as SectionReady<RecordPage<ConsultationRecord>>)
              .value
              .items
              .single;
      expect(item.isShareable, isFalse);
      expect(item.sharingVersion, 4);
    });
  });

  group('identity (no fixture)', () {
    final profile = PatientProfile.fromJson({
      'userId': 'u1',
      'firstName': 'Amel',
      'lastName': 'Trabelsi',
      'displayName': 'Amel Trabelsi',
      'onboardingCompleted': true,
      'onboardingStep': 5,
      'preferredLanguage': 'fr',
      'notificationMedications': true,
      'notificationAppointments': true,
      'notificationPassport': true,
      'primaryPhone': {'value': '+216 20 000 000', 'verified': true},
      'primaryEmail': {'value': 'amel@example.tn', 'verified': true},
    });

    test('members come from the profile and family only', () {
      final members = passportMembers(
        profile: profile,
        family: [
          FamilyMember(
            id: 'fam-1',
            accountHolderId: 'u1',
            firstName: 'Youssef',
            lastName: 'Trabelsi',
            dateOfBirth: DateTime.utc(2018),
            gender: 'MALE',
            relationship: 'CHILD',
            graduated: false,
          ),
        ],
        l10n: _fr,
      );
      expect(members.map((member) => member.name), [
        'Amel Trabelsi',
        'Youssef Trabelsi',
      ]);
      expect(members.first.isSelf, isTrue);
      expect(members.first.relationship, 'Mon passeport');
      expect(recordSubjectOf(members.first), const SelfRecordSubject());
      expect(recordSubjectOf(members.last), const FamilyRecordSubject('fam-1'));
      expect(
        members.every(
          (member) => member.avatarAsset.startsWith('assets/images/avatars/'),
        ),
        isTrue,
        reason: 'no stock photo of a stranger',
      );
      // A removed family member falls back to the holder.
      expect(selectedPassportMember(members, 'gone').isSelf, isTrue);
    });

    test('the identity card holds real values or « Non renseigné »', () {
      final self = passportMembers(
        profile: profile,
        family: const [],
        l10n: _fr,
      ).single;
      final identity = passportIdentity(
        member: self,
        profile: profile,
        l10n: _fr,
      );
      expect(identity.name, 'Amel Trabelsi');
      expect(identity.phone, '+216 20 000 000');
      expect(identity.email, 'amel@example.tn');
      expect(identity.omniCareId, 'Non renseigné');
      expect(identity.bloodGroup, isEmpty);
      expect(identity.medications, isEmpty);
      expect(identity.heightCm, isNull);

      final anonymous = passportIdentity(
        member: passportMembers(
          profile: null,
          family: const [],
          l10n: _fr,
        ).single,
        profile: null,
        l10n: _fr,
      );
      for (final value in [
        anonymous.name,
        anonymous.phone,
        anonymous.email,
        anonymous.omniCareId,
      ]) {
        expect(value, 'Non renseigné');
      }
      expect(
        '${anonymous.name}${identity.name}${identity.omniCareId}',
        isNot(contains('Sarah')),
      );
    });
  });
}

class _MalformedApi implements MedicalRecordApiContract {
  @override
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query = const {},
    CancelToken? cancelToken,
  }) async => {
    'items': [
      {'consultationId': 'c1'},
    ],
  };
}
