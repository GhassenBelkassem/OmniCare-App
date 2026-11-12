// G-2 1b-2: the former server-text sinks (P0 §f.3) now expose French text.
// Logic only (CTO testing rule): view models and APIs against a fake server
// that answers with the backend's real English texts.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/network/api_failure_message.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/network/save_error_message.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/auth/data/professional_access_request_api.dart';
import 'package:omnicare_mobile/features/onboarding/onboarding_progress.dart';
import 'package:omnicare_mobile/features/security/account_security_api.dart';
import 'package:omnicare_mobile/features/security/account_security_provider.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';
import 'package:omnicare_mobile/repositories/user_repository.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));

const _english = 'Something PRIVATE went wrong on the server';

/// Answers every request with one status and JSON body.
class _FixedServer implements HttpClientAdapter {
  _FixedServer(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
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

AppHttpClient _client(int status, Map<String, dynamic> body) => AppHttpClient(
  tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
  baseUrl: 'https://api.test',
  dio: Dio()..httpClientAdapter = _FixedServer(status, body),
  refreshDio: Dio(),
);

Map<String, dynamic> _error(String code, {Map<String, String>? fields}) => {
  'code': code,
  'message': _english,
  'timestamp': '2026-11-11T10:00:00Z',
  'fieldErrors': fields ?? const {},
};

void _expectFrench(String? text) {
  expect(text, isNotNull);
  expect(text, isNot(contains('PRIVATE')));
  expect(text, isNot(contains('must ')));
}

void main() {
  test('1 professional access request: French, never server text', () async {
    final api = ProfessionalAccessRequestApi(
      _client(409, _error('PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING')),
    );
    final failure = await api
        .submit(const {})
        .then<ApiFailure?>((_) => null, onError: (Object e) => e as ApiFailure);
    expect(
      apiFailureMessage(
        failure!,
        _fr,
        fallback: _fr.professionalAccessSendFailed,
      ),
      'Une demande est déjà en cours pour cette adresse e-mail ou cet '
      'identifiant professionnel.',
    );

    final invalid = ProfessionalAccessRequestApi(
      _client(
        400,
        _error('VALIDATION_ERROR', fields: {'email': 'must be a well-formed'}),
      ),
    );
    final validation = await invalid
        .submit(const {})
        .then<ApiFailure?>((_) => null, onError: (Object e) => e as ApiFailure);
    expect(validation!.fieldErrors.keys, ['email']);
    _expectFrench(
      apiFailureMessage(
        validation,
        _fr,
        fallback: _fr.professionalAccessSendFailed,
      ),
    );
  });

  group('2–3 account security', () {
    AccountSecurityProvider provider(int status, String code) =>
        AccountSecurityProvider(
          api: AccountSecurityApi(_client(status, _error(code))),
          forceLocalLogout: () async {},
          onProfileChanged: () async {},
        );

    test('device list error (sink 2): French', () async {
      final security = provider(500, 'INTERNAL_SERVER_ERROR');
      await expectLater(security.load(), throwsA(anything));
      expect(security.hasError, isTrue);
      expect(
        security.errorMessage(_fr),
        'Service momentanément indisponible. Réessayez plus tard.',
      );
    });

    test('password change (sink 3): wrong current password', () async {
      final security = provider(401, 'AUTH_INVALID_CREDENTIALS');
      Object? thrown;
      try {
        await security.savePassword(currentPassword: 'a', newPassword: 'b');
      } catch (error) {
        thrown = error;
      }
      // The screen shows securityErrorMessage(thrown) instead of toString().
      expect(
        securityErrorMessage(thrown!, _fr),
        'Les identifiants sont incorrects.',
      );
      expect(thrown.toString(), isNot(contains('PRIVATE')));
    });

    test('phone change keeps its own wording', () async {
      final security = provider(409, 'CONFLICT');
      await expectLater(
        security.initiateCurrentPhoneVerification(),
        throwsA(anything),
      );
      expect(
        security.phoneErrorMessage(_fr),
        'Un changement de numéro est déjà en cours.',
      );
    });

    test('local reasons are French ARB text', () {
      expect(
        securityErrorMessage(
          const SecurityLocalException(SecurityLocalError.googleCancelled),
          _fr,
        ),
        'Réauthentification Google annulée.',
      );
      expect(
        securityErrorMessage(
          const SecurityLocalException(SecurityLocalError.actionInProgress),
          _fr,
        ),
        'Une opération est déjà en cours.',
      );
    });
  });

  group('5 profile (UserProvider)', () {
    UserProvider provider(int status, Map<String, dynamic> body) =>
        UserProvider(
          repository: UserRepository(
            api: AccountApi(httpClient: _client(status, body)),
          ),
        );

    test('load failure → French, profile fallback for vague kinds', () async {
      final users = provider(404, _error('RESOURCE_NOT_FOUND'));
      await expectLater(users.refresh(), throwsA(anything));
      expect(
        apiFailureMessageOr(
          users.loadFailure,
          _fr,
          fallback: _fr.profileLoadFailed,
        ),
        'Impossible de charger le profil.',
      );
    });

    test('save failure → French message and French field texts', () async {
      final users = provider(
        400,
        _error('VALIDATION_ERROR', fields: {'firstName': 'must not be blank'}),
      );
      await expectLater(
        users.updateProfile(const PatientProfileUpdate(firstName: '')),
        throwsA(anything),
      );
      _expectFrench(
        apiFailureMessage(
          users.saveFailure!,
          _fr,
          fallback: _fr.profileSaveFailed,
        ),
      );
      expect(apiFieldErrorMessages(users.saveFieldErrors, _fr), {
        'firstName': 'Vérifiez ce champ.',
      });
    });

    test('MRS down on a profile call → its own message', () async {
      final users = provider(503, _error('MRS_UNAVAILABLE'));
      await expectLater(users.refresh(), throwsA(anything));
      expect(
        apiFailureMessage(users.loadFailure!, _fr),
        'Le dossier médical est temporairement indisponible. Réessayez plus tard.',
      );
    });
  });

  group('6 family (FamilyProvider, Result in FamilyRepository)', () {
    FamilyProvider provider(int status, Map<String, dynamic> body) =>
        FamilyProvider(
          repository: FamilyRepository(
            api: FamilyApi(httpClient: _client(status, body)),
          ),
        );

    test('list failure is a typed failure, shown in French', () async {
      final family = provider(500, _error('INTERNAL_SERVER_ERROR'));
      await family.loadFamilyMembers();
      expect(family.loadFailure?.kind, ApiFailureKind.server);
      expect(
        apiFailureMessage(
          family.loadFailure!,
          _fr,
          fallback: _fr.familyLoadFailed,
        ),
        'Service momentanément indisponible. Réessayez plus tard.',
      );
    });

    test('save: field errors become French, never the server text', () async {
      final family = provider(
        400,
        _error(
          'VALIDATION_ERROR',
          fields: {
            'firstName': 'must not be blank',
            'relationship': 'must not be null',
          },
        ),
      );
      Object? thrown;
      try {
        await family.addFamilyMember(
          firstName: 'Lina',
          lastName: 'Ben Ali',
          dateOfBirth: DateTime(2015),
          gender: 'F',
          relationship: FamilyRelationships.frereSoeur,
        );
      } catch (error) {
        thrown = error;
      }
      expect(thrown, isA<ApiFailure>());
      expect(apiFieldErrorMessages(family.fieldErrors, _fr), {
        'firstName': 'Vérifiez ce champ.',
        'relationship': 'Vérifiez ce champ.',
      });
      _expectFrench(
        apiFailureMessage(
          family.mutationFailure!,
          _fr,
          fallback: _fr.familySaveFailed,
        ),
      );
    });

    test('a graduated member cannot be removed → removal fallback', () async {
      final family = provider(400, _error('INVALID_STATE'));
      await expectLater(
        family.deactivateFamilyMember('m-1'),
        throwsA(anything),
      );
      expect(
        apiFailureMessageOr(
          family.mutationFailure,
          _fr,
          fallback: _fr.familyRemoveFailed,
        ),
        'Impossible de retirer ce membre.',
      );
    });
  });

  test('8 onboarding and 1a-2 saves: French from the same parser', () {
    final withServerText = ApiException.fromFailure(
      ApiFailure.fromResponse(statusCode: 503, body: _error('MRS_UNAVAILABLE')),
    );
    expect(
      onboardingSaveErrorMessage(withServerText, _fr),
      "Impossible d'enregistrer. Vérifiez votre connexion et réessayez.",
    );
    expect(
      saveErrorMessage(withServerText, _fr),
      'Service momentanément indisponible. Réessayez plus tard.',
    );
  });

  test('9 logout error: generic French, not toString()', () {
    final error = Exception(_english);
    final text = apiFailureMessage(ApiFailure.from(error), _fr);
    expect(text, 'Une erreur est survenue. Réessayez.');
  });
}
