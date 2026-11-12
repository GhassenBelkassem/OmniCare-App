// G-2 1a-2 (C3, C2 honesty, missing save error).
// Requests are captured at the HTTP adapter of the real AppHttpClient, after
// the real screens, providers, repositories and APIs built them.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/core/l10n/blood_type_label.dart';
import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/home/edit_medical_data_screen.dart';
import 'package:omnicare_mobile/features/home/family_member_detail_screen.dart';
import 'package:omnicare_mobile/features/home/medical_data_save.dart';
import 'package:omnicare_mobile/features/onboarding/conversational_onboarding_screen.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_basics_payload.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

const _saveLabel = 'Enregistrer les Modifications';
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

  group('Ma Santé (self) → PATCH /profile/passport', () {
    testWidgets('untouched blood type: no request at all', (tester) async {
      final server = _Server();
      await _openSelfEditor(tester, server, bloodType: null);
      await _tapSave(tester);
      expect(server.requests, isEmpty);
      expect(find.byType(EditMedicalDataScreen), findsNothing);
    });

    testWidgets('changed blood type: body is exactly {bloodType}', (
      tester,
    ) async {
      final server = _Server();
      await _openSelfEditor(tester, server, bloodType: null);
      await _chooseBloodType(tester, 'B+');
      await _tapSave(tester);
      expect(server.requests.single.method, 'PATCH');
      expect(server.requests.single.path, '/profile/passport');
      expect(server.requests.single.body, {'bloodType': 'B+'});
      server.expectNoForbiddenValues();
    });

    testWidgets('choosing "-" over a value sends nothing', (tester) async {
      final server = _Server();
      await _openSelfEditor(tester, server, bloodType: BloodType.aPositive);
      await _chooseBloodType(tester, '-');
      await _tapSave(tester);
      expect(server.requests, isEmpty);
    });

    testWidgets('re-choosing the current value sends nothing', (tester) async {
      final server = _Server();
      await _openSelfEditor(tester, server, bloodType: BloodType.oPositive);
      await _chooseBloodType(tester, 'O+');
      await _tapSave(tester);
      expect(server.requests, isEmpty);
    });

    testWidgets('conditions only: no request, honesty message shown', (
      tester,
    ) async {
      final server = _Server();
      await _openSelfEditor(tester, server, bloodType: null);
      await _toggleCondition(tester, 'Hypertension');
      await _tapSave(tester);
      expect(server.requests, isEmpty);
      expect(
        find.text(
          'Les antécédents et traitements ne peuvent pas encore être enregistrés.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('conditions + blood type: only bloodType sent, honesty shown', (
      tester,
    ) async {
      final server = _Server();
      await _openSelfEditor(tester, server, bloodType: null);
      await _chooseBloodType(tester, 'O-');
      await _toggleCondition(tester, 'Asthme');
      await _tapSave(tester);
      expect(server.requests.single.body, {'bloodType': 'O-'});
      server.expectNoForbiddenValues();
      expect(
        find.text(
          'Les antécédents et traitements ne peuvent pas encore être enregistrés.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('400 INVALID_INPUT: French message, no server text, stays', (
      tester,
    ) async {
      final server = _Server(patchStatus: 400, patchCode: 'INVALID_INPUT');
      await _openSelfEditor(tester, server, bloodType: null);
      await _chooseBloodType(tester, 'A-');
      await _tapSave(tester);
      expect(
        find.text(
          'Certaines informations ne sont pas valides. Vérifiez et réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(_serverText), findsNothing);
      expect(find.byType(EditMedicalDataScreen), findsOneWidget);
    });

    testWidgets('503 MRS_UNAVAILABLE: French unavailable message', (
      tester,
    ) async {
      final server = _Server(patchStatus: 503, patchCode: 'MRS_UNAVAILABLE');
      await _openSelfEditor(tester, server, bloodType: null);
      await _chooseBloodType(tester, 'A-');
      await _tapSave(tester);
      expect(
        find.text('Service momentanément indisponible. Réessayez plus tard.'),
        findsOneWidget,
      );
      expect(find.textContaining(_serverText), findsNothing);
    });

    testWidgets('network failure: « Connexion impossible »', (tester) async {
      final server = _Server(failPatchWithConnectionError: true);
      await _openSelfEditor(tester, server, bloodType: null);
      await _chooseBloodType(tester, 'A-');
      await _tapSave(tester);
      expect(find.text('Connexion impossible. Réessayez.'), findsOneWidget);
      expect(find.byType(EditMedicalDataScreen), findsOneWidget);
    });

    testWidgets('a non-API error is caught: generic message, no crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostApp(
          editor: EditMedicalDataScreen(
            bloodType: null,
            chronicConditions: const [],
            medications: const [],
            documents: const [],
            onSave: (_) async => throw StateError('boom'),
          ),
        ),
      );
      await _openHostedEditor(tester);
      await _chooseBloodType(tester, 'AB+');
      await _tapSave(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('Enregistrement impossible pour le moment. Réessayez.'),
        findsOneWidget,
      );
      expect(find.byType(EditMedicalDataScreen), findsOneWidget);
    });
  });

  group('Family detail → PATCH /profile/family-members/{id}/passport', () {
    testWidgets('untouched (static "-") blood type: no request', (
      tester,
    ) async {
      final server = _Server();
      await _openFamilyEditor(tester, server);
      await _tapSave(tester);
      expect(server.requests, isEmpty);
      expect(find.byType(FamilyMemberDetailScreen), findsOneWidget);
    });

    testWidgets('changed blood type: sent and shown', (tester) async {
      final server = _Server();
      await _openFamilyEditor(tester, server);
      await _chooseBloodType(tester, 'A-');
      await _tapSave(tester);
      expect(server.requests.single.method, 'PATCH');
      expect(
        server.requests.single.path,
        '/profile/family-members/fm-1/passport',
      );
      expect(server.requests.single.body, {'bloodType': 'A-'});
      server.expectNoForbiddenValues();
      expect(find.text('A-'), findsOneWidget);
    });

    testWidgets('conditions are not shown as saved; honesty message', (
      tester,
    ) async {
      final server = _Server();
      await _openFamilyEditor(tester, server);
      await _toggleCondition(tester, 'Migraine');
      await _tapSave(tester);
      expect(server.requests, isEmpty);
      expect(
        find.text(
          'Les antécédents et traitements ne peuvent pas encore être enregistrés.',
        ),
        findsOneWidget,
      );
      expect(find.byType(FamilyMemberDetailScreen), findsOneWidget);
      expect(find.text('Migraine'), findsNothing);
    });

    testWidgets('400: French message, value not changed on screen', (
      tester,
    ) async {
      final server = _Server(patchStatus: 400, patchCode: 'INVALID_INPUT');
      await _openFamilyEditor(tester, server);
      await _chooseBloodType(tester, 'B-');
      await _tapSave(tester);
      expect(
        find.text(
          'Certaines informations ne sont pas valides. Vérifiez et réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(_serverText), findsNothing);
      expect(find.byType(EditMedicalDataScreen), findsOneWidget);
    });
  });

  group('Onboarding step 1 and passport PATCH bodies', () {
    // Since G2-1a-6, step 1 carries identity only; blood type, height and
    // weight go through PATCH /profile/passport (same MRS record).
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

    test('no blood type chosen: absent from the passport PATCH', () async {
      final server = _Server();
      final api = AccountApi(httpClient: _httpClient(server));
      await api.patchMedicalPassport(heightCm: 172, weightKg: 70.5);
      expect(server.requests.single.body, {'heightCm': 172, 'weightKg': 70.5});
    });

    test(
      '« Je ne sais pas » is sent as unknown, ABO as its wire value',
      () async {
        final server = _Server();
        final api = AccountApi(httpClient: _httpClient(server));
        await api.patchMedicalPassport(bloodType: BloodType.unknown);
        await api.patchMedicalPassport(bloodType: BloodType.abNegative);

        expect(server.requests[0].body, {'bloodType': 'unknown'});
        expect(server.requests[1].body, {'bloodType': 'AB-'});
        server.expectNoForbiddenValues();
      },
    );

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
            ),
          ),
        ),
      );
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

  group('API surface', () {
    test('saveOwnMedicalEdit sends nothing for an untouched edit', () async {
      final server = _Server();
      final sent = await saveOwnMedicalEdit(
        AccountApi(httpClient: _httpClient(server)),
        const MedicalDataEdit(
          bloodType: null,
          conditionsOrMedicationsChanged: true,
          chronicConditions: ['Asthme'],
          medications: [],
          documents: [],
        ),
      );
      expect(sent, isFalse);
      expect(server.requests, isEmpty);
    });

    test('FamilyApi body is exactly the wire value', () async {
      final server = _Server();
      await FamilyApi(
        httpClient: _httpClient(server),
      ).patchMedicalPassport(id: 'fm-2', bloodType: BloodType.oNegative);
      expect(server.requests.single.body, {'bloodType': 'O-'});
    });
  });
}

Map<String, dynamic> _step1Body() => onboardingStep1Body(
  firstName: 'Test',
  lastName: 'Patient',
  dateOfBirth: '1990-01-01',
  gender: 'FEMALE',
);

Widget _hostApp({required Widget editor, Widget Function(Widget)? wrap}) {
  final host = Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => editor)),
          child: const Text('open'),
        ),
      ),
    ),
  );
  return MaterialApp(
    localizationsDelegates: OmniLocalizations.localizationsDelegates,
    supportedLocales: OmniLocalizations.supportedLocales,
    home: wrap == null ? host : wrap(host),
  );
}

Future<void> _openHostedEditor(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openSelfEditor(
  WidgetTester tester,
  _Server server, {
  required BloodType? bloodType,
}) async {
  final api = AccountApi(httpClient: _httpClient(server));
  await tester.pumpWidget(
    _hostApp(
      editor: EditMedicalDataScreen(
        bloodType: bloodType,
        chronicConditions: const [],
        medications: const [],
        documents: const [],
        onSave: (edit) => saveOwnMedicalEdit(api, edit),
      ),
    ),
  );
  await _openHostedEditor(tester);
}

Future<void> _openFamilyEditor(WidgetTester tester, _Server server) async {
  final provider = FamilyProvider(
    repository: FamilyRepository(
      api: FamilyApi(httpClient: _httpClient(server)),
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: OmniLocalizations.localizationsDelegates,
        supportedLocales: OmniLocalizations.supportedLocales,
        home: FamilyMemberDetailScreen(
          member: FamilyMember(
            id: 'fm-1',
            name: 'Membre Test',
            age: 8,
            relationship: 'Enfant',
            avatar: '',
            bloodType: null,
            chronicConditions: [],
            currentMedications: [],
            documents: [],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Modifier'));
  await tester.pumpAndSettle();
}

Future<void> _chooseBloodType(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _toggleCondition(WidgetTester tester, String condition) async {
  final chip = find.text(condition);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.text(_saveLabel);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

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
  _Server({
    this.patchStatus = 200,
    this.patchCode,
    this.failPatchWithConnectionError = false,
  });

  final int patchStatus;
  final String? patchCode;
  final bool failPatchWithConnectionError;
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
    if (options.method == 'PATCH' && failPatchWithConnectionError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (options.method == 'PATCH' && patchStatus >= 400) {
      return _json(patchStatus, {'code': patchCode, 'message': _serverText});
    }
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
