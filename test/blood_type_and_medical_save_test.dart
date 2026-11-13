// G-2 1a-2: the blood type mapping, the onboarding step-1 body and the
// onboarding blood tiles. Requests are captured at the HTTP adapter of the
// real AppHttpClient. (G2.1-A3: the Ma Santé and family-member saves moved to
// the record's section saves; their tests are in
// medical_data_a3_test.dart.)
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/core/l10n/blood_type_label.dart';
import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/onboarding/conversational_onboarding_screen.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_basics_payload.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_repository.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';

const _serverText = 'PRIVATE_SERVER_TEXT';

/// The generated French messages, without a widget tree.
final _fr = lookupOmniLocalizations(const Locale('fr'));

void main() {
  group('BloodType mapping', () {
    const table = {
      BloodType.aPositive: 'A+',
      BloodType.aNegative: 'A-',
      BloodType.bPositive: 'B+',
      BloodType.bNegative: 'B-',
      BloodType.abPositive: 'AB+',
      BloodType.abNegative: 'AB-',
      BloodType.oPositive: 'O+',
      BloodType.oNegative: 'O-',
      BloodType.unknown: 'unknown',
    };

    test('every value has exactly one wire value, round-tripping', () {
      expect(BloodType.values.toSet(), table.keys.toSet());
      for (final entry in table.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(BloodType.fromWire(entry.value), entry.key);
      }
    });

    test('labels: ABO types as-is, unknown as « Je ne sais pas »', () {
      for (final type in BloodType.values) {
        expect(
          type.label(_fr),
          type == BloodType.unknown ? 'Je ne sais pas' : type.wireValue,
        );
      }
    });

    test('server parsing is case- and space-tolerant', () {
      expect(BloodType.fromWire(' ab+ '), BloodType.abPositive);
      expect(BloodType.fromWire('o-'), BloodType.oNegative);
      expect(BloodType.fromWire('UNKNOWN'), BloodType.unknown);
    });

    test('unrecognised server values fall back to unknown', () {
      for (final raw in ['Z+', 'IDK', 'A', 'AB']) {
        expect(BloodType.fromWire(raw), BloodType.unknown, reason: raw);
      }
    });

    test('missing, blank and legacy "-" mean not provided (null)', () {
      for (final raw in [null, '', '   ', '-']) {
        expect(BloodType.fromWire(raw), isNull, reason: '$raw');
      }
    });

    test('no wire value is "-" or "IDK"', () {
      final wires = BloodType.values.map((t) => t.wireValue);
      expect(wires, isNot(contains('-')));
      expect(wires, isNot(contains('IDK')));
    });
  });

  group('Onboarding step 1 body', () {
    // Since G2-1a-6, step 1 carries identity only; blood type, height and
    // weight go through the record's section saves (G2.1-A3).
    test('step 1 never carries medical fields', () async {
      final server = _Server();
      final api = AccountApi(httpClient: _httpClient(server));
      await api.saveOnboardingStep(1, _step1Body());

      expect(server.requests.single.path, '/profile/onboarding/step/1');
      expect(server.requests.single.body.keys, {
        'firstName',
        'lastName',
        'dateOfBirth',
        'gender',
      });
      server.expectNoForbiddenValues();
    });

    testWidgets('blood tiles show « Je ne sais pas » and store unknown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final onboarding = UserOnboardingProvider();
      final server = _Server();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: onboarding),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: ConversationalOnboardingScreen(
              accountApi: AccountApi(httpClient: _httpClient(server)),
              medicalRecords: MedicalRecordRepository(
                MedicalRecordApi(_httpClient(server)),
              ),
              medicalRecordWrites: MedicalRecordWriteRepository(
                MedicalRecordWriteApi(_httpClient(server)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // G3-ONB2: a fresh start opens on the intro, above the PageView.
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('IDK'), findsNothing);
      final unknownTile = find.text('Je ne sais pas');
      await tester.scrollUntilVisible(
        unknownTile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(unknownTile, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(unknownTile);
      await tester.pump();
      expect(onboarding.bloodGroup, 'unknown');
      expect(BloodType.fromWire(onboarding.bloodGroup), BloodType.unknown);
    });
  });
}

Map<String, dynamic> _step1Body() => onboardingStep1Body(
  firstName: 'Test',
  lastName: 'Patient',
  dateOfBirth: '1990-01-01',
  gender: 'FEMALE',
);

AppHttpClient _httpClient(_Server server) => AppHttpClient(
  tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
  baseUrl: 'https://api.test',
  dio: Dio()..httpClientAdapter = server,
  refreshDio: Dio(),
);

class _Request {
  _Request(this.method, this.path, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> body;
}

/// Records every request and answers like the backend envelope
/// `{code, message}` on errors.
class _Server implements HttpClientAdapter {
  final List<_Request> requests = [];

  void expectNoForbiddenValues() {
    for (final request in requests) {
      expect(request.body.containsKey('medicalInfo'), isFalse);
      expect(request.body['bloodType'], isNot(anyOf('-', 'IDK')));
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return _json(404, {'code': 'RESOURCE_NOT_FOUND', 'message': _serverText});
    }
    final data = options.data;
    requests.add(
      _Request(
        options.method,
        options.path,
        data is Map ? Map<String, dynamic>.from(data) : const {},
      ),
    );
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
