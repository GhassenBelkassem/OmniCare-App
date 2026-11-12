// G-2 1a-2b: « Je ne sais pas » never erases a stored blood type.
// Logic only (CTO testing rule): pure decision functions plus request bodies
// captured at the real AppHttpClient adapter.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_basics_payload.dart';

const _nothingStored = StoredBloodTypeKnown(null);
const _storedAPositive = StoredBloodTypeKnown(BloodType.aPositive);
const _unavailable = StoredBloodTypeUnavailable();

void main() {
  group('bloodTypeToSend', () {
    final cases = <(String, BloodType?, StoredBloodType, BloodType?)>[
      (
        'stored A+, « Je ne sais pas »',
        BloodType.unknown,
        _storedAPositive,
        null,
      ),
      (
        'nothing stored, « Je ne sais pas »',
        BloodType.unknown,
        _nothingStored,
        BloodType.unknown,
      ),
      ('nothing stored, nothing picked', null, _nothingStored, null),
      (
        'read failed, « Je ne sais pas »',
        BloodType.unknown,
        _unavailable,
        null,
      ),
      ('read failed, nothing picked', null, _unavailable, null),
      (
        'read failed, B+ picked',
        BloodType.bPositive,
        _unavailable,
        BloodType.bPositive,
      ),
      (
        'stored A+, A+ kept (pre-selected)',
        BloodType.aPositive,
        _storedAPositive,
        null,
      ),
      (
        'stored A+, O- picked',
        BloodType.oNegative,
        _storedAPositive,
        BloodType.oNegative,
      ),
      (
        'nothing stored, O- picked',
        BloodType.oNegative,
        _nothingStored,
        BloodType.oNegative,
      ),
      ('stored A+, nothing picked', null, _storedAPositive, null),
    ];
    for (final (name, chosen, stored, expected) in cases) {
      test(name, () {
        expect(bloodTypeToSend(chosen: chosen, stored: stored), expected);
      });
    }

    test(
      'unknown is never sent unless the server confirmed nothing stored',
      () {
        for (final stored in <StoredBloodType>[
          _unavailable,
          for (final type in BloodType.values) StoredBloodTypeKnown(type),
        ]) {
          expect(
            bloodTypeToSend(chosen: BloodType.unknown, stored: stored),
            isNull,
            reason: '$stored',
          );
        }
      },
    );
  });

  group('bloodTypeToPreselect', () {
    test('stored value is pre-selected', () {
      expect(bloodTypeToPreselect(_storedAPositive), BloodType.aPositive);
    });
    test('nothing stored or read failed: no pre-selection', () {
      expect(bloodTypeToPreselect(_nothingStored), isNull);
      expect(bloodTypeToPreselect(_unavailable), isNull);
    });
  });

  group('AccountApi.getStoredMedicalBasics (GET /profile/medical-data)', () {
    test('reads lifeSafety.bloodType', () async {
      final server = _Server(storedBloodType: 'A+');
      final basics = await _api(server).getStoredMedicalBasics();
      expect(basics.bloodType, BloodType.aPositive);
      expect(server.gets, ['/profile/medical-data']);
    });

    test('null bloodType means nothing stored', () async {
      final server = _Server(storedBloodType: null);
      expect((await _api(server).getStoredMedicalBasics()).bloodType, isNull);
    });

    test('server casing is tolerated', () async {
      final server = _Server(storedBloodType: 'ab-');
      expect(
        (await _api(server).getStoredMedicalBasics()).bloodType,
        BloodType.abNegative,
      );
    });

    test('reads body measurements', () async {
      final server = _Server(
        medicalDataBody: {
          'lifeSafety': {'bloodType': null},
          'bodyMeasurements': {'heightCm': 172, 'weightKg': 70.5},
        },
      );
      final basics = await _api(server).getStoredMedicalBasics();
      expect(basics.heightCm, 172);
      expect(basics.weightKg, 70.5);
      expect(basics.hasBodyMeasurements, isTrue);
    });

    test('missing lifeSafety is a malformed response, not "nothing"', () {
      final server = _Server(medicalDataBody: {'patientId': 'p-1'});
      expect(
        _api(server).getStoredMedicalBasics(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'MALFORMED_RESPONSE',
          ),
        ),
      );
    });

    test('non-string bloodType or non-number weight is malformed', () {
      for (final body in [
        {
          'lifeSafety': {'bloodType': 7},
        },
        {
          'lifeSafety': {'bloodType': 'A+'},
          'bodyMeasurements': {'heightCm': 170, 'weightKg': 'heavy'},
        },
      ]) {
        expect(
          _api(_Server(medicalDataBody: body)).getStoredMedicalBasics(),
          throwsA(isA<ApiException>()),
        );
      }
    });

    test('503 MRS_UNAVAILABLE surfaces as ApiException', () {
      final server = _Server(medicalDataStatus: 503);
      expect(
        _api(server).getStoredMedicalBasics(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'MRS_UNAVAILABLE'),
        ),
      );
    });
  });

  // The request-level scenarios (stored A+ then « Je ne sais pas », etc.) now
  // run through OnboardingProgressController in
  // test/onboarding_per_step_save_test.dart (G2-1a-6).
}

AccountApi _api(_Server server) => AccountApi(
  httpClient: AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
    baseUrl: 'https://api.test',
    dio: Dio()..httpClientAdapter = server,
    refreshDio: Dio(),
  ),
);

/// Answers GET /profile/medical-data like `ProfileController.getMedicalData`
/// and records every write body.
class _Server implements HttpClientAdapter {
  _Server({
    this.storedBloodType,
    this.medicalDataStatus = 200,
    this.medicalDataBody,
  });

  final String? storedBloodType;
  final int medicalDataStatus;
  final Map<String, dynamic>? medicalDataBody;
  final List<String> gets = [];
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      gets.add(options.path);
      if (medicalDataStatus != 200) {
        return _json(medicalDataStatus, {
          'code': 'MRS_UNAVAILABLE',
          'message': 'PRIVATE_SERVER_TEXT',
        });
      }
      return _json(
        200,
        medicalDataBody ??
            {
              'patientId': 'p-1',
              'lifeSafety': {
                'bloodType': storedBloodType,
                'allergies': const <String>[],
                'criticalConditions': const <String>[],
              },
              'bodyMeasurements': const <String, dynamic>{},
              'syncOperationIds': const <String>[],
              'syncStatus': 'COMPLETED',
            },
      );
    }
    final data = options.data;
    bodies.add(data is Map ? Map<String, dynamic>.from(data) : const {});
    return _json(200, {
      'passportCompletion': 20,
      'nextStep': 2,
      'onboardingCompleted': false,
    });
  }

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
