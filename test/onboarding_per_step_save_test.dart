// G-2 1a-6: onboarding saves each page on « Continuer » and resumes where the
// patient stopped. Logic only (CTO testing rule): OnboardingProgressController
// + the real AccountApi/AppHttpClient against a fake server that applies the
// backend's step rules (OnboardingService.saveStep).
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;

import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_basics_payload.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_progress.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';

OnboardingDraft _draft({
  String firstName = 'Test',
  BloodType? blood = BloodType.oPositive,
  int? heightCm = 172,
  double? weightKg = 70.5,
  List<AllergyEntry>? allergies,
  List<String> conditions = const ['Hypertension'],
  List<MedicationEntry> medications = const [],
}) => OnboardingDraft(
  firstName: firstName,
  lastName: 'Patient',
  dateOfBirth: '1990-01-01',
  gender: 'F',
  chosenBloodType: blood,
  heightCm: heightCm,
  weightKg: weightKg,
  allergies:
      allergies ??
      [AllergyEntry(name: 'Pénicilline', severity: 'sévère', lifeSafety: true)],
  conditions: conditions,
  medications: medications,
  today: '2026-11-11',
);

const _step1 = 'POST /profile/onboarding/step/1';
const _step2 = 'POST /profile/onboarding/step/2';
const _step3 = 'POST /profile/onboarding/step/3';
const _step4 = 'POST /profile/onboarding/step/4';
const _passport = 'PATCH /profile/passport';

/// The generated French messages, without a widget tree.
final _fr = lookupOmniLocalizations(const Locale('fr'));

void main() {
  group('Continue on each page sends exactly that page’s request, once', () {
    test('pages 0 → 4 from a fresh account', () async {
      final server = _BackendLikeServer();
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      final draft = _draft();

      final perPage = <List<String>>[];
      for (var page = 0; page <= OnboardingPage.medications; page++) {
        server.writes.clear();
        final outcome = await progress.saveThrough(page, draft);
        expect(outcome, isA<OnboardingSaved>(), reason: 'page $page');
        perPage.add(server.writes.map((w) => w.key).toList());
      }

      expect(perPage, [
        [_step1],
        [_passport],
        [_step2],
        [_step3],
        [_step4],
      ]);
      expect(server.completed, isTrue);
    });

    test(
      'request bodies: identity only on step 1, medical data on PATCH',
      () async {
        final server = _BackendLikeServer();
        final progress = OnboardingProgressController(_api(server));
        await progress.load();
        await progress.saveThrough(OnboardingPage.allergies, _draft());

        expect(server.writes[0].body, {
          'firstName': 'Test',
          'lastName': 'Patient',
          'dateOfBirth': '1990-01-01',
          'gender': 'F',
        });
        expect(server.writes[1].body, {
          'bloodType': 'O+',
          'heightCm': 172,
          'weightKg': 70.5,
        });
        expect(server.writes[2].body, {
          'allergies': [
            {'name': 'Pénicilline', 'severity': 'sévère', 'lifeSafety': true},
          ],
        });
      },
    );

    test('last page completes onboarding', () async {
      final server = _BackendLikeServer(
        onboardingStep: 4,
        storedBlood: 'O+',
        height: 172,
        weight: 70.5,
      );
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      final outcome = await progress.saveThrough(
        OnboardingPage.medications,
        _draft(),
      );
      expect((outcome as OnboardingSaved).completed, isTrue);
      expect(server.writes.single.key, _step4);
      expect(server.writes.single.body, {'noKnownMedications': true});
    });

    test('a double tap sends one request; the second tap is ignored', () async {
      final server = _BackendLikeServer(holdWrites: true);
      final progress = OnboardingProgressController(_api(server));
      await progress.load();

      final first = progress.saveThrough(OnboardingPage.identity, _draft());
      final second = await progress.saveThrough(
        OnboardingPage.identity,
        _draft(),
      );
      expect(second, isA<OnboardingSaveIgnored>());
      expect(progress.isSaving, isTrue);

      server.release();
      expect(await first, isA<OnboardingSaved>());
      expect(server.writes.map((w) => w.key), [_step1]);
      expect(progress.isSaving, isFalse);
    });

    test('Continue again on an already-saved page sends nothing', () async {
      final server = _BackendLikeServer();
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      await progress.saveThrough(OnboardingPage.body, _draft());
      server.writes.clear();

      await progress.saveThrough(OnboardingPage.identity, _draft());
      await progress.saveThrough(OnboardingPage.body, _draft());
      expect(server.writes, isEmpty);
    });

    test(
      'pages swiped past are saved in order before the current one',
      () async {
        final server = _BackendLikeServer();
        final progress = OnboardingProgressController(_api(server));
        await progress.load();
        await progress.saveThrough(OnboardingPage.conditions, _draft());
        expect(server.writes.map((w) => w.key), [
          _step1,
          _passport,
          _step2,
          _step3,
        ]);
        expect(server.rejectedSteps, isEmpty);
      },
    );

    test('onboarding already complete: nothing is sent', () async {
      final server = _BackendLikeServer(completed: true);
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      final outcome = await progress.saveThrough(
        OnboardingPage.medications,
        _draft(),
      );
      expect((outcome as OnboardingSaved).completed, isTrue);
      expect(server.writes, isEmpty);
    });
  });

  group('a failure keeps the page and what was typed', () {
    test(
      'step 2 fails: no later step is sent; retry sends the same body',
      () async {
        final server = _BackendLikeServer(
          onboardingStep: 2,
          height: 172,
          weight: 70.5,
        )..failNext[_step2] = 503;
        final progress = OnboardingProgressController(_api(server));
        await progress.load();
        final draft = _draft(blood: null);

        final failed = await progress.saveThrough(
          OnboardingPage.allergies,
          draft,
        );
        expect(failed, isA<OnboardingSaveFailed>());
        expect(server.onboardingStep, 2);
        expect(draft.allergies.single.name, 'Pénicilline');

        server.writes.clear();
        final retried = await progress.saveThrough(
          OnboardingPage.allergies,
          draft,
        );
        expect(retried, isA<OnboardingSaved>());
        expect(server.writes.map((w) => w.key), [_step2]);
        expect(server.writes.single.body['allergies'], isNotEmpty);
        expect(server.onboardingStep, 3);
      },
    );

    test('a lost response (saved on server) is retried harmlessly', () async {
      final server = _BackendLikeServer(
        onboardingStep: 3,
        height: 172,
        weight: 70.5,
      )..dropResponseOnce[_step3] = true;
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      final draft = _draft(blood: null);

      expect(
        await progress.saveThrough(OnboardingPage.conditions, draft),
        isA<OnboardingSaveFailed>(),
      );
      expect(server.onboardingStep, 4); // the server did save it
      expect(
        await progress.saveThrough(OnboardingPage.conditions, draft),
        isA<OnboardingSaved>(),
      );
      expect(server.rejectedSteps, isEmpty);
    });

    test('French message: connection text by default, never server text', () {
      const network = ApiException(
        'PRIVATE_SERVER_TEXT',
        code: 'NETWORK_REQUEST_FAILED',
      );
      const unavailable = ApiException(
        'PRIVATE_SERVER_TEXT',
        code: 'MRS_UNAVAILABLE',
        statusCode: 503,
      );
      const invalid = ApiException(
        'PRIVATE_SERVER_TEXT',
        code: 'INVALID_INPUT',
        statusCode: 400,
      );
      expect(
        onboardingSaveErrorMessage(network, _fr),
        "Impossible d'enregistrer. Vérifiez votre connexion et réessayez.",
      );
      expect(
        onboardingSaveErrorMessage(unavailable, _fr),
        'Impossible d\'enregistrer. Vérifiez votre connexion et réessayez.',
      );
      expect(
        onboardingSaveErrorMessage(StateError('x'), _fr),
        'Impossible d\'enregistrer. Vérifiez votre connexion et réessayez.',
      );
      expect(
        onboardingSaveErrorMessage(invalid, _fr),
        'Certaines informations ne sont pas valides. Vérifiez et réessayez.',
      );
      for (final error in [network, unavailable, invalid]) {
        expect(
          onboardingSaveErrorMessage(error, _fr),
          isNot(contains('PRIVATE')),
        );
      }
    });
  });

  group('resume at the first unsaved page', () {
    final table = <(String, bool, int, bool, int)>[
      ('fresh account', false, 1, false, OnboardingPage.identity),
      ('identity saved, no measurements', false, 2, false, OnboardingPage.body),
      ('identity + body saved', false, 2, true, OnboardingPage.allergies),
      ('allergies saved', false, 3, true, OnboardingPage.conditions),
      ('conditions saved', false, 4, true, OnboardingPage.medications),
      ('completed (not shown)', true, 4, true, OnboardingPage.identity),
    ];
    for (final (name, completed, step, stored, expected) in table) {
      test('rule: $name', () {
        expect(
          onboardingResumePage(
            completed: completed,
            serverStep: step,
            bodyMeasurementsStored: stored,
          ),
          expected,
        );
      });
    }

    test('load() reads server progress and stored values', () async {
      final server = _BackendLikeServer(
        onboardingStep: 3,
        storedBlood: 'A+',
        height: 168,
        weight: 61,
      );
      final resume = await OnboardingProgressController(_api(server)).load();
      expect(resume.page, OnboardingPage.conditions);
      expect(resume.profile?.firstName, 'Saved');
      expect(resume.storedBasics?.bloodType, BloodType.aPositive);
      expect(resume.storedBasics?.heightCm, 168);
    });

    test('load() with a failed profile read opens the first page', () async {
      final server = _BackendLikeServer(onboardingStep: 3)..profileStatus = 503;
      final resume = await OnboardingProgressController(_api(server)).load();
      expect(resume.page, OnboardingPage.identity);
      expect(resume.profile, isNull);
    });

    test('after resume, only the unsaved pages are sent', () async {
      final server = _BackendLikeServer(
        onboardingStep: 3,
        storedBlood: 'O+',
        height: 172,
        weight: 70.5,
      );
      final progress = OnboardingProgressController(_api(server));
      final resume = await progress.load();
      await progress.saveThrough(resume.page, _draft());
      expect(server.writes.map((w) => w.key), [_step3]);
    });
  });

  group('1a-2b guard still holds after resume', () {
    test('stored A+ then « Je ne sais pas »: no bloodType sent', () async {
      final server = _BackendLikeServer(
        onboardingStep: 2,
        storedBlood: 'A+',
        height: 172,
        weight: 70.5,
      );
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      expect(
        bloodTypeToPreselect(progress.storedBloodType),
        BloodType.aPositive,
      );

      await progress.saveThrough(
        OnboardingPage.body,
        _draft(blood: BloodType.unknown, heightCm: 180, weightKg: 75),
      );
      expect(server.writes.single.key, _passport);
      expect(server.writes.single.body.containsKey('bloodType'), isFalse);
      expect(server.storedBlood, 'A+');
    });

    test(
      'stored A+ kept as pre-selected, same measurements: no request',
      () async {
        final server = _BackendLikeServer(
          onboardingStep: 2,
          storedBlood: 'A+',
          height: 172,
          weight: 70.5,
        );
        final progress = OnboardingProgressController(_api(server));
        await progress.load();
        await progress.saveThrough(
          OnboardingPage.body,
          _draft(blood: BloodType.aPositive),
        );
        expect(server.writes, isEmpty);
      },
    );

    test(
      'nothing stored then « Je ne sais pas »: unknown, sent once',
      () async {
        final server = _BackendLikeServer(onboardingStep: 2);
        final progress = OnboardingProgressController(_api(server));
        await progress.load();
        final draft = _draft(blood: BloodType.unknown);
        await progress.saveThrough(OnboardingPage.body, draft);
        await progress.saveThrough(OnboardingPage.body, draft);
        expect(server.writes.map((w) => w.key), [_passport]);
        expect(server.writes.single.body['bloodType'], 'unknown');
      },
    );

    test('medical-data read failed then « Je ne sais pas »: omitted', () async {
      final server = _BackendLikeServer(onboardingStep: 2, storedBlood: 'B-')
        ..medicalDataStatus = 503;
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      await progress.saveThrough(
        OnboardingPage.body,
        _draft(blood: BloodType.unknown),
      );
      expect(server.writes.single.body.containsKey('bloodType'), isFalse);
      expect(server.storedBlood, 'B-');
    });
  });

  // G2-1a-4 (1a-6 R1): going back to a saved page and changing it.
  group('edited already-saved page: message, no request', () {
    Future<OnboardingProgressController> savedThroughConditions(
      _BackendLikeServer server,
    ) async {
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      for (var page = 0; page <= OnboardingPage.conditions; page++) {
        await progress.saveThrough(page, _draft());
      }
      server.writes.clear();
      return progress;
    }

    final edits = <String, (int, OnboardingDraft)>{
      'identity': (OnboardingPage.identity, _draft(firstName: 'Autre')),
      'allergies': (OnboardingPage.allergies, _draft(allergies: const [])),
      'conditions': (
        OnboardingPage.conditions,
        _draft(conditions: const ['Hypertension', 'Asthma']),
      ),
    };
    for (final MapEntry(key: name, value: (page, edited)) in edits.entries) {
      test('$name changed → alreadySavedPageEdited, nothing sent', () async {
        final server = _BackendLikeServer();
        final progress = await savedThroughConditions(server);

        final outcome = await progress.saveThrough(page, edited);

        expect((outcome as OnboardingSaved).alreadySavedPageEdited, isTrue);
        expect(server.writes, isEmpty);
      });
    }

    test('saved page unchanged → no message, nothing sent', () async {
      final server = _BackendLikeServer();
      final progress = await savedThroughConditions(server);
      for (final page in [
        OnboardingPage.identity,
        OnboardingPage.allergies,
        OnboardingPage.conditions,
      ]) {
        final outcome = await progress.saveThrough(page, _draft());
        expect(
          (outcome as OnboardingSaved).alreadySavedPageEdited,
          isFalse,
          reason: 'page $page',
        );
      }
      expect(server.writes, isEmpty);
    });

    test('blood-type page still sends the change, no message', () async {
      final server = _BackendLikeServer();
      final progress = await savedThroughConditions(server);

      final outcome = await progress.saveThrough(
        OnboardingPage.body,
        _draft(blood: BloodType.aNegative),
      );

      expect((outcome as OnboardingSaved).alreadySavedPageEdited, isFalse);
      expect(server.writes.single.key, _passport);
      expect(server.writes.single.body, {'bloodType': 'A-'});
      expect(server.storedBlood, 'A-');
    });

    test('a page saved for the first time is never flagged', () async {
      final server = _BackendLikeServer();
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      final outcome = await progress.saveThrough(
        OnboardingPage.identity,
        _draft(firstName: 'Autre'),
      );
      expect((outcome as OnboardingSaved).alreadySavedPageEdited, isFalse);
      expect(server.writes.single.key, _step1);
    });

    test('after resume: compared with what the page showed', () async {
      final server = _BackendLikeServer(
        onboardingStep: 3,
        storedBlood: 'O+',
        height: 172,
        weight: 70.5,
      );
      final progress = OnboardingProgressController(_api(server));
      await progress.load();
      // Screen state right after the pre-fill: allergies not pre-filled.
      progress.rememberShownValues(_draft(allergies: const []));

      final unchanged = await progress.saveThrough(
        OnboardingPage.allergies,
        _draft(allergies: const []),
      );
      final changed = await progress.saveThrough(
        OnboardingPage.allergies,
        _draft(),
      );

      expect((unchanged as OnboardingSaved).alreadySavedPageEdited, isFalse);
      expect((changed as OnboardingSaved).alreadySavedPageEdited, isTrue);
      expect(server.writes, isEmpty);
    });

    test('message only for the page Continue is pressed on', () async {
      final server = _BackendLikeServer();
      final progress = await savedThroughConditions(server);
      // Identity edited earlier, Continue pressed on conditions (unchanged).
      final outcome = await progress.saveThrough(
        OnboardingPage.conditions,
        _draft(firstName: 'Autre'),
      );
      expect((outcome as OnboardingSaved).alreadySavedPageEdited, isFalse);
      expect(server.writes, isEmpty);
    });

    test('message text', () {
      expect(
        'Ces informations sont déjà enregistrées. Vous pourrez les modifier plus tard depuis votre profil.',
        'Ces informations sont déjà enregistrées. Vous pourrez les modifier '
            'plus tard depuis votre profil.',
      );
    });
  });
}

AccountApi _api(_BackendLikeServer server) => AccountApi(
  httpClient: AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
    baseUrl: 'https://api.test',
    dio: Dio()..httpClientAdapter = server,
    refreshDio: Dio(),
  ),
);

class _Write {
  _Write(this.key, this.body);
  final String key;
  final Map<String, dynamic> body;
}

/// Applies `OnboardingService.saveStep` and `updatePassportFields` rules.
class _BackendLikeServer implements HttpClientAdapter {
  _BackendLikeServer({
    this.onboardingStep = 1,
    this.completed = false,
    this.storedBlood,
    this.height,
    this.weight,
    this.holdWrites = false,
  });

  int onboardingStep;
  bool completed;
  String? storedBlood;
  num? height;
  num? weight;
  int profileStatus = 200;
  int medicalDataStatus = 200;
  final bool holdWrites;
  final Map<String, int> failNext = {};
  final Map<String, bool> dropResponseOnce = {};
  final List<_Write> writes = [];
  final List<int> rejectedSteps = [];
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    if (options.method == 'GET') return _get(options.path);

    final data = options.data;
    final body = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    writes.add(_Write(key, body));
    if (holdWrites) await _gate.future;
    final failure = failNext.remove(key);
    if (failure != null) {
      return _json(failure, {'code': 'MRS_UNAVAILABLE', 'message': 'PRIVATE'});
    }
    final response = key == _passport
        ? _patchPassport(body)
        : _saveStep(options.path);
    if (dropResponseOnce.remove(key) == true) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return response;
  }

  ResponseBody _get(String path) {
    if (path == '/profile') {
      if (profileStatus != 200) {
        return _json(profileStatus, {'code': 'X', 'message': 'PRIVATE'});
      }
      return _json(200, {
        'userId': 'u-1',
        'firstName': 'Saved',
        'lastName': 'Patient',
        'displayName': 'Saved Patient',
        'dateOfBirth': '1990-01-01',
        'gender': 'F',
        'onboardingCompleted': completed,
        'onboardingStep': onboardingStep,
        'preferredLanguage': 'fr',
        'notificationMedications': true,
        'notificationAppointments': true,
        'notificationPassport': true,
      });
    }
    if (medicalDataStatus != 200) {
      return _json(medicalDataStatus, {
        'code': 'MRS_UNAVAILABLE',
        'message': 'PRIVATE',
      });
    }
    return _json(200, {
      'lifeSafety': {'bloodType': storedBlood},
      'bodyMeasurements': {'heightCm': height, 'weightKg': weight},
    });
  }

  ResponseBody _saveStep(String path) {
    final step = int.parse(path.split('/').last);
    if (completed) {
      if (step == 4) return _stepResponse(4, completedNow: true);
      rejectedSteps.add(step);
      return _json(400, {'code': 'INVALID_STATE', 'message': 'PRIVATE'});
    }
    if (step == onboardingStep - 1) {
      return _stepResponse(onboardingStep, completedNow: false);
    }
    if (step != onboardingStep) {
      rejectedSteps.add(step);
      return _json(400, {'code': 'INVALID_STATE', 'message': 'PRIVATE'});
    }
    if (step == 4) {
      completed = true;
      return _stepResponse(4, completedNow: true);
    }
    onboardingStep = step + 1;
    return _stepResponse(onboardingStep, completedNow: false);
  }

  ResponseBody _patchPassport(Map<String, dynamic> body) {
    if (body.containsKey('bloodType')) {
      final value = body['bloodType'] as String;
      if (value == 'unknown') {
        if (storedBlood != null) {
          return _json(400, {'code': 'INVALID_INPUT', 'message': 'PRIVATE'});
        }
      } else {
        storedBlood = value;
      }
    }
    if (body.containsKey('heightCm')) height = body['heightCm'] as num;
    if (body.containsKey('weightKg')) weight = body['weightKg'] as num;
    return _json(200, const {});
  }

  ResponseBody _stepResponse(int nextStep, {required bool completedNow}) =>
      _json(200, {
        'passportCompletion': 40,
        'nextStep': nextStep,
        'onboardingCompleted': completedNow,
        'message': 'Étape enregistrée',
      });

  ResponseBody _json(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
