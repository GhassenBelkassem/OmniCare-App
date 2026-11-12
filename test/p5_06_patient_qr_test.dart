import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/blood_type.dart';
import 'package:omnicare_mobile/core/models/family_models.dart' as family_core;
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/home/family_member_detail_screen.dart';
import 'package:omnicare_mobile/features/home/qr_code_modal.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_record_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/patient_passport_screen.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_share_qr.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_share_qr_api.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_share_qr_controller.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_models.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/core/result/result.dart';

void main() {
  const familyId = '11111111-1111-4111-8111-111111111111';
  const self = MedicalSharingSubject.self();
  const family = MedicalSharingSubject.family(familyId);

  test(
    'SELF and FAMILY requests contain only approved subject fields',
    () async {
      final adapter = _RecordingAdapter([
        _qrJson('opaque-self'),
        _qrJson('opaque-family'),
      ]);
      final api = MedicalShareQrApi(await _client(adapter));

      await api.issueQr(self, idempotencyKey: 'self-command');
      await api.issueQr(family, idempotencyKey: 'family-command');

      expect(
        adapter.requests[0].uri.path,
        '/api/v1/patient/medical-sharing/qr',
      );
      expect(adapter.bodies[0], {'subjectType': 'SELF'});
      expect(adapter.bodies[1], {
        'subjectType': 'FAMILY_MEMBER',
        'familyMemberId': familyId,
      });
      for (var index = 0; index < adapter.requests.length; index++) {
        final request = adapter.requests[index];
        final body = adapter.bodies[index] as Map<String, dynamic>;
        expect(_hasHeader(request, 'Pragma'), isFalse);
        expect(_header(request, 'Authorization'), 'Bearer test-access-token');
        expect(_header(request, 'Content-Type'), Headers.jsonContentType);
        expect(_header(request, 'Cache-Control'), 'no-store');
        expect(
          _header(request, 'Idempotency-Key'),
          index == 0 ? 'self-command' : 'family-command',
        );
        expect(body, isNot(contains('mrsPatientId')));
        expect(body, isNot(contains('operationalPatientId')));
        expect(body, isNot(contains('doctorId')));
        expect(body, isNot(contains('consultationId')));
      }
    },
  );

  test('successful issue keeps the opaque server payload in memory', () async {
    final api = _FakeQrApi()..payloads.add('opaque-server-value');
    final controller = MedicalShareQrController(api);

    await controller.issue(self);

    expect(controller.status, MedicalShareQrStatus.ready);
    expect(controller.qr?.payload, 'opaque-server-value');
    expect(controller.previewPayload, isNull);
    expect(api.subjects.single.toJson(), {'subjectType': 'SELF'});
  });

  test(
    'debug no-active-consultation response creates only the fixed preview',
    () async {
      final api = _FakeQrApi()
        ..failure = const ApiException(
          'not found',
          code: 'RESOURCE_NOT_FOUND',
          statusCode: 404,
        );
      final controller = MedicalShareQrController(api);

      await controller.issue(family);

      expect(controller.status, MedicalShareQrStatus.preview);
      expect(controller.qr, isNull);
      expect(
        controller.previewPayload,
        MedicalShareQrController.debugPreviewPayload,
      );
      expect(controller.previewPayload, isNot(contains(familyId)));
      for (final sensitiveValue in [
        'test-patient',
        'mrs-patient-id',
        'Sarah Ben Ahmed',
        'sarah@example.com',
        '+21612345678',
        'OMNI-123456',
      ]) {
        expect(controller.previewPayload, isNot(contains(sensitiveValue)));
      }
    },
  );

  test('release-mode configuration never creates a demo QR', () async {
    final api = _FakeQrApi()
      ..failure = const ApiException(
        'not found',
        code: 'RESOURCE_NOT_FOUND',
        statusCode: 404,
      );
    final controller = MedicalShareQrController(
      api,
      debugPreviewEnabled: false,
    );

    await controller.issue(self);

    expect(controller.status, MedicalShareQrStatus.error);
    expect(controller.qr, isNull);
    expect(controller.previewPayload, isNull);
    expect(controller.errorMessage, 'QR disponible pendant une consultation.');
  });

  test(
    'arbitrary server and security errors do not become a preview',
    () async {
      for (final failure in const [
        ApiException(
          'different failure',
          code: 'SOME_OTHER_NOT_FOUND',
          statusCode: 404,
        ),
        ApiException(
          'unexpected server failure',
          code: 'RESOURCE_NOT_FOUND',
          statusCode: 500,
        ),
        ApiException('unauthorized', code: 'UNAUTHORIZED', statusCode: 401),
        ApiException('forbidden', code: 'FORBIDDEN', statusCode: 403),
      ]) {
        final api = _FakeQrApi()..failure = failure;
        final controller = MedicalShareQrController(api);

        await controller.issue(self);

        expect(controller.status, MedicalShareQrStatus.error);
        expect(controller.previewPayload, isNull);
      }
    },
  );

  testWidgets('QR expires locally and regenerate obtains a new server QR', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final api = _FakeQrApi()
      ..payloads.addAll(['opaque-first', 'opaque-second'])
      ..expiries.addAll([
        now.add(const Duration(seconds: 2)),
        now.add(const Duration(minutes: 5)),
      ]);
    final controller = MedicalShareQrController(api, now: () => now);

    await controller.issue(self);
    expect(controller.qr?.payload, 'opaque-first');
    await tester.pump(const Duration(seconds: 2));
    expect(controller.status, MedicalShareQrStatus.expired);
    expect(controller.qr, isNull);

    await controller.regenerate();
    expect(controller.status, MedicalShareQrStatus.ready);
    expect(controller.qr?.payload, 'opaque-second');
    expect(api.subjects, hasLength(2));
    controller.dispose();
  });

  test('subject switch removes the previous subject QR', () async {
    final api = _FakeQrApi()..payloads.addAll(['opaque-self', 'opaque-family']);
    final controller = MedicalShareQrController(api);

    await controller.issue(self);
    await controller.issue(family);

    expect(controller.subject?.cacheKey, family.cacheKey);
    expect(controller.qr?.payload, 'opaque-family');
    expect(controller.qr?.payload, isNot('opaque-self'));
  });

  test('network failure never creates a raw Patient-ID fallback', () async {
    final api = _FakeQrApi()
      ..failure = const ApiException('network', code: 'MRS_UNAVAILABLE');
    final controller = MedicalShareQrController(api);

    await controller.issue(family);

    expect(controller.status, MedicalShareQrStatus.error);
    expect(controller.qr, isNull);
    expect(controller.previewPayload, isNull);
    expect(controller.errorMessage, isNot(contains(familyId)));
    expect(controller.errorMessage, isNot(contains('OMNICARE-PATIENT')));
  });

  test(
    'retry reuses one idempotency key while regenerate creates another',
    () async {
      final api = _FakeQrApi()
        ..failure = const ApiException('network', code: 'MRS_UNAVAILABLE');
      var sequence = 0;
      final controller = MedicalShareQrController(
        api,
        idempotencyKey: () => 'command-${++sequence}',
      );

      await controller.issue(self);
      api.failure = null;
      api.payloads.addAll(['opaque-retry', 'opaque-regenerated']);
      await controller.retry();
      await controller.regenerate();

      expect(api.keys, ['command-1', 'command-1', 'command-2']);
    },
  );

  test('logout or account change clearing removes all QR state', () async {
    final api = _FakeQrApi()..payloads.add('opaque-secret');
    final controller = MedicalShareQrController(api);
    await controller.issue(self);

    controller.clear();

    expect(controller.status, MedicalShareQrStatus.idle);
    expect(controller.subject, isNull);
    expect(controller.qr, isNull);
  });

  testWidgets('existing QR modal shell renders only the opaque response', (
    tester,
  ) async {
    final api = _FakeQrApi()..payloads.add('opaque-widget-payload');
    final controller = MedicalShareQrController(api);
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: QRCodeModal(patientName: 'Sarah', subject: self),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('QR Code Médical'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('medical-share-qr-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('medical-share-qr-ready')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('medical-share-qr-image')),
      findsOneWidget,
    );
    expect(controller.qr?.payload, 'opaque-widget-payload');
    expect(find.textContaining('OMNICARE-PATIENT'), findsNothing);
    expect(find.textContaining('ID:'), findsNothing);
  });

  testWidgets('debug preview is rendered and clearly labeled non-valid', (
    tester,
  ) async {
    final api = _FakeQrApi()
      ..failure = const ApiException(
        'not found',
        code: 'RESOURCE_NOT_FOUND',
        statusCode: 404,
      );
    final controller = MedicalShareQrController(api);
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: QRCodeModal(patientName: 'Sarah', subject: self),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('medical-share-qr-preview')),
      findsOneWidget,
    );
    expect(find.text('Aperçu — QR non valide'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('medical-share-qr-image')),
      findsOneWidget,
    );
    expect(
      controller.previewPayload,
      MedicalShareQrController.debugPreviewPayload,
    );
    expect(controller.qr, isNull);
  });

  testWidgets('family QR entry issues for the selected owned family member', (
    tester,
  ) async {
    final api = _FakeQrApi()..payloads.add('opaque-family-widget-payload');
    final controller = MedicalShareQrController(api);
    final member = FamilyMember(
      id: familyId,
      name: 'Amine',
      age: 12,
      relationship: 'Fils',
      avatar: '',
      bloodType: BloodType.oPositive,
      chronicConditions: const [],
      currentMedications: const [],
      documents: const [],
    );
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          localizationsDelegates: OmniLocalizations.localizationsDelegates,
          supportedLocales: OmniLocalizations.supportedLocales,
          home: FamilyMemberDetailScreen(member: member),
        ),
      ),
    );
    await tester.tap(find.text('Cliquez pour afficher'));
    await tester.pump();
    await tester.pump();

    expect(api.subjects.single.toJson(), {
      'subjectType': 'FAMILY_MEMBER',
      'familyMemberId': familyId,
    });
    expect(
      find.byKey(const ValueKey('medical-share-qr-ready')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Passport load is inert and SELF tap opens the existing secure QR modal',
    (tester) async {
      final api = _FakeQrApi()..payloads.add('opaque-passport-self');
      final controller = MedicalShareQrController(api);
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: controller),
            // G2.1-S1: the record is always live; an empty one keeps the
            // cards out of their loading state.
            ChangeNotifierProvider(create: (_) => _emptyMedicalRecord()),
          ],
          child: const MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: Scaffold(body: PatientPassportScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(api.subjects, isEmpty);
      expect(find.text('Identité du passeport'), findsOneWidget);
      expect(find.text('Afficher le QR'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.byKey(const ValueKey('passport-secure-qr-action')));
      await tester.pump();
      await tester.pump();

      expect(api.subjects.single.toJson(), {'subjectType': 'SELF'});
      expect(controller.qr?.payload, 'opaque-passport-self');
      expect(
        find.byKey(const ValueKey('medical-share-qr-image')),
        findsOneWidget,
      );
      expect(find.textContaining('OMNICARE-PASSPORT'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('medical-share-qr-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Passport family tap preserves the selected owned member id', (
    tester,
  ) async {
    final api = _FakeQrApi()..payloads.add('opaque-passport-family');
    final controller = MedicalShareQrController(api);
    final familyProvider = FamilyProvider(
      repository: _PassportFamilyRepository([
        _ownedFamilyMember(familyId, 'Amine', 'Ben Ahmed'),
      ]),
    );
    await familyProvider.loadFamilyMembers();
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: familyProvider),
          ChangeNotifierProvider(create: (_) => _emptyMedicalRecord()),
        ],
        child: const MaterialApp(
          localizationsDelegates: OmniLocalizations.localizationsDelegates,
          supportedLocales: OmniLocalizations.supportedLocales,
          home: Scaffold(body: PatientPassportScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(api.subjects, isEmpty);

    // G2-1b-3b: the header shows the real holder (no fixture); open the
    // family selector from its arrow.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amine Ben Ahmed'));
    await tester.pumpAndSettle();
    expect(find.text('Amine Ben Ahmed'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('passport-secure-qr-action')));
    await tester.pump();
    await tester.pump();

    expect(api.subjects.single.toJson(), {
      'subjectType': 'FAMILY_MEMBER',
      'familyMemberId': familyId,
    });
    expect(controller.qr?.payload, 'opaque-passport-family');
    expect(
      find.byKey(const ValueKey('medical-share-qr-image')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('medical-share-qr-close')));
    await tester.pumpAndSettle();
  });
}

/// An empty « Dossier médical » answered at once (G2.1-S1: the passport
/// screen always reads the record; these tests only exercise the QR).
MedicalRecordViewModel _emptyMedicalRecord() => MedicalRecordViewModel(
  repository: MedicalRecordRepository(_EmptyMedicalRecordApi()),
);

class _EmptyMedicalRecordApi implements MedicalRecordApiContract {
  @override
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query = const {},
    CancelToken? cancelToken,
  }) async => switch (resource) {
    MedicalRecordResource.medicalData => <String, Object?>{},
    _ => <String, Object?>{'items': <Object?>[], 'nextCursor': null},
  };
}

Map<String, dynamic> _qrJson(String payload) => {
  'sessionId': '22222222-2222-4222-8222-222222222222',
  'qrPayload': payload,
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String(),
};

class _FakeQrApi implements MedicalShareQrApiContract {
  final subjects = <MedicalSharingSubject>[];
  final keys = <String>[];
  final payloads = <String>[];
  final expiries = <DateTime>[];
  Object? failure;

  @override
  Future<MedicalShareQr> issueQr(
    MedicalSharingSubject subject, {
    required String idempotencyKey,
  }) async {
    subjects.add(subject);
    keys.add(idempotencyKey);
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    final payload = payloads.removeAt(0);
    final expiry = expiries.isEmpty
        ? DateTime.now().toUtc().add(const Duration(minutes: 5))
        : expiries.removeAt(0);
    return MedicalShareQr(payload: payload, expiresAt: expiry);
  }
}

Future<AppHttpClient> _client(HttpClientAdapter adapter) async {
  final dio = Dio()..httpClientAdapter = adapter;
  final tokenStore = SecureTokenStore(backend: _MemoryTokenBackend());
  await tokenStore.saveSession(_testSession());
  return AppHttpClient(
    tokenStore: tokenStore,
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

StoredSession _testSession() => StoredSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshTokenExpiresAt: DateTime.utc(2099, 2),
  userId: 'test-patient',
  userRole: 'PATIENT',
);

Object? _header(RequestOptions request, String name) {
  final normalized = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}

bool _hasHeader(RequestOptions request, String name) {
  final normalized = name.toLowerCase();
  return request.headers.keys.any((key) => key.toLowerCase() == normalized);
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

  final List<Map<String, dynamic>> responses;
  final requests = <RequestOptions>[];
  final bodies = <Object?>[];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(options.data);
    return ResponseBody.fromString(
      jsonEncode(responses[_index++]),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _PassportFamilyRepository extends FamilyRepository {
  _PassportFamilyRepository(this.members) : super(api: FamilyApi());

  final List<family_core.FamilyMember> members;

  @override
  Future<Result<List<family_core.FamilyMember>>> getFamilyMembers() async =>
      Ok(members);
}

family_core.FamilyMember _ownedFamilyMember(
  String id,
  String firstName,
  String lastName,
) => family_core.FamilyMember(
  id: id,
  accountHolderId: 'account-holder',
  firstName: firstName,
  lastName: lastName,
  dateOfBirth: DateTime(2012, 4, 3),
  gender: 'MALE',
  relationship: family_core.FamilyRelationships.enfant,
  graduated: false,
);
