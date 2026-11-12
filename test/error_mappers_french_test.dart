// G-2 1b-2c: the remaining patient feature error mappers read backend errors
// through the single parser (ApiFailure) and show French text only.
// Logic only (CTO testing rule): mappers and APIs against recorded bodies.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/api/documents_api.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/network/api_failure_message.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/auth/application/auth_error_messages.dart';
import 'package:omnicare_mobile/features/auth/data/auth_api.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_repository.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_repository.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/profile/medical_document_error_message.dart';
import 'package:omnicare_mobile/features/request_core/data/request_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/security/account_security_provider.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));

const _private = 'Something PRIVATE went wrong on the server';

/// A recorded HTTP error, as Dio hands it to a mapper.
DioException _http(int status, Object? body) {
  final options = RequestOptions(path: '/api/v1/x');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );
}

DioException _transport(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
);

/// Shape 1 (`ErrorResponse`).
Map<String, dynamic> _errorResponse(
  String code, {
  Map<String, String>? fields,
  Map<String, String>? fieldCodes,
}) => {
  'code': code,
  'message': _private,
  'timestamp': '2026-11-11T10:00:00Z',
  'fieldErrors': fields ?? const {},
  'fieldErrorCodes': ?fieldCodes,
};

/// Shape 3 (ProblemDetail + `errorCode`), as the request and booking
/// handlers send it.
Map<String, dynamic> _problem(int status, String errorCode) => {
  'type': 'https://api.omnicare.tn/problems/x',
  'title': _private,
  'status': status,
  'detail': _private,
  'instance': '/api/v1/x',
  'errorCode': errorCode,
  'requestId': '11111111-2222-4333-8444-555555555555',
};

/// Shape 4 (ProblemDetail + `code`), as the urgent CABINET handler sends it.
Map<String, dynamic> _problemCode(int status, String code) => {
  'title': _private,
  'status': status,
  'detail': _private,
  'code': code,
};

void _expectNoServerText(String text) {
  expect(text, isNot(contains('PRIVATE')));
  expect(text, isNot(contains('Please')));
  expect(text.trim(), isNotEmpty);
}

class _FixedServer implements HttpClientAdapter {
  _FixedServer(this.status, this.body);
  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body is String ? body as String : jsonEncode(body),
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

AppHttpClient _client(int status, Object body) {
  final client = AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
    baseUrl: 'https://api.test',
    dio: Dio(),
    refreshDio: Dio(),
  );
  client.dio.httpClientAdapter = _FixedServer(status, body);
  client.publicDio.httpClientAdapter = _FixedServer(status, body);
  return client;
}

Future<Object> _thrownBy(Future<Object?> Function() call) async {
  try {
    await call();
  } catch (error) {
    return error;
  }
  fail('expected the call to throw');
}

void main() {
  group('field messages (backend contract 1b-2b)', () {
    test('each field code gets its precise French text', () {
      final failure = ApiFailure.fromResponse(
        statusCode: 400,
        body: _errorResponse(
          'VALIDATION_ERROR',
          fields: {
            'a': 'must not be blank',
            'b': 'size must be between 0 and 5',
            'c': 'size must be between 12 and 128',
            'd': 'must match',
            'e': 'must be greater than 0',
            'f': 'must be true',
          },
          fieldCodes: {
            'a': 'REQUIRED',
            'b': 'TOO_LONG',
            'c': 'TOO_SHORT',
            'd': 'INVALID_FORMAT',
            'e': 'OUT_OF_RANGE',
            'f': 'INVALID',
          },
        ),
      );
      expect(apiFieldErrorMessages(failure.fieldErrors, _fr), {
        'a': 'Ce champ est obligatoire.',
        'b': 'Ce texte est trop long.',
        'c': 'Ce texte est trop court.',
        'd': 'Format invalide.',
        'e': 'Valeur hors limites.',
        'f': 'Vérifiez ce champ.',
      });
    });

    test(
      'without fieldErrorCodes every field reads « Vérifiez ce champ. »',
      () {
        final failure = ApiFailure.fromResponse(
          statusCode: 400,
          body: _errorResponse(
            'VALIDATION_ERROR',
            fields: {'firstName': 'must not be blank', 'email': 'bad'},
          ),
        );
        expect(apiFieldErrorMessages(failure.fieldErrors, _fr), {
          'firstName': 'Vérifiez ce champ.',
          'email': 'Vérifiez ce champ.',
        });
      },
    );
  });

  group('requests (Module 05)', () {
    test('known ProblemDetail codes keep their meaning, now in French', () {
      final target = RequestFailure.from(
        _http(422, _problem(422, 'REQUEST_TARGET_UNAVAILABLE')),
      );
      expect(target.kind, RequestFailureKind.targetUnavailable);
      expect(target.retryable, isFalse);
      expect(target.api?.code, 'REQUEST_TARGET_UNAVAILABLE');
      expect(
        target.message(_fr),
        'Cette clinique ne peut pas recevoir de demandes pour le moment.',
      );

      final conflict = RequestFailure.from(
        _http(409, _problem(409, 'REQUEST_IDEMPOTENCY_CONFLICT')),
      );
      expect(conflict.isOperationTerminal, isTrue);
      expect(
        conflict.message(_fr),
        'Cette demande a déjà servi à un autre envoi. '
        'Commencez une nouvelle demande.',
      );
      // A lower-case code is still recognised, as before.
      expect(
        RequestFailure.from(
          _http(409, _problem(409, 'request_version_conflict')),
        ).kind,
        RequestFailureKind.versionConflict,
      );
    });

    test('status fallbacks are unchanged; 401 wins over the code', () {
      expect(
        RequestFailure.from(_http(401, _problem(401, 'REQUEST_INVALID'))).kind,
        RequestFailureKind.sessionExpired,
      );
      expect(
        RequestFailure.from(_http(403, '<html>denied</html>')).kind,
        RequestFailureKind.subjectForbidden,
      );
      expect(
        RequestFailure.from(_http(503, '<html>down</html>')).message(_fr),
        'Les demandes de soins sont momentanément indisponibles. Réessayez.',
      );
    });

    test('an unknown case gets the generic text of its kind', () {
      final limited = RequestFailure.from(
        _http(429, _problem(429, 'SOMETHING_NEW')),
      );
      expect(limited.kind, RequestFailureKind.unexpected);
      expect(
        limited.message(_fr),
        'Trop de tentatives. Patientez avant de réessayer.',
      );
      expect(
        RequestFailure.from(StateError('x')).message(_fr),
        'Une erreur est survenue. Réessayez.',
      );
    });

    test('transport failures keep their retry semantics', () {
      final timeout = RequestFailure.from(
        _transport(DioExceptionType.receiveTimeout),
      );
      expect(timeout.retryable, isTrue);
      expect(
        timeout.message(_fr),
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
      expect(
        RequestFailure.from(
          _transport(DioExceptionType.connectionError),
        ).message(_fr),
        'Connexion impossible. Vérifiez votre connexion et réessayez.',
      );
      expect(
        RequestFailure.from(_transport(DioExceptionType.cancel)).kind,
        RequestFailureKind.cancelled,
      );
    });

    test('every request failure has French text, never server text', () {
      const all = [
        RequestFailure.networkUnavailable,
        RequestFailure.timedOut,
        RequestFailure.interrupted,
        RequestFailure.invalidResponse,
        RequestFailure.sessionExpired,
        RequestFailure.cancelled,
        RequestFailure.serverUnavailable,
        RequestFailure.unexpected,
        RequestFailure.subjectForbidden,
        RequestFailure.targetUnavailable,
        RequestFailure.invalidRequest,
        RequestFailure.versionConflict,
        RequestFailure.transitionInvalid,
        RequestFailure.idempotencyConflict,
        RequestFailure.notFound,
        RequestFailure.intentIncomplete,
        RequestFailure.recoveryIdentityUnavailable,
        RequestFailure.recoveryPersistenceUnavailable,
      ];
      final texts = {for (final f in all) f.diagnosticCode: f.message(_fr)};
      texts.values.forEach(_expectNoServerText);
      // Each local reason has its own wording (no accidental fallback).
      expect(texts['REQUEST_INTENT_INCOMPLETE'], contains('clinique'));
      expect(texts['REQUEST_INTERRUPTED'], contains('interrompue'));
    });

    test('field codes on a rejected request become precise French', () {
      final failure = RequestFailure.from(
        _http(
          400,
          _errorResponse(
            'VALIDATION_ERROR',
            fields: {'situation': 'size must be between 0 and 500'},
            fieldCodes: {'situation': 'TOO_LONG'},
          ),
        ),
      );
      expect(failure.kind, RequestFailureKind.invalid);
      expect(apiFieldErrorMessages(failure.api!.fieldErrors, _fr), {
        'situation': 'Ce texte est trop long.',
      });
    });
  });

  group('booking (scheduled care, shared with the doctor app)', () {
    test('known codes keep the same French text as before', () {
      final slot = ScheduledCareFailure.from(
        _http(409, _problem(409, 'SLOT_NO_LONGER_AVAILABLE')),
      );
      expect(slot.requiresAvailabilityRefresh, isTrue);
      expect(
        slot.message,
        'Ce créneau n’est plus disponible. Choisissez-en un autre.',
      );
      expect(slot.api?.statusCode, 409);
      // Shape 1 (`code`) reaches the same mapping.
      expect(
        ScheduledCareFailure.from(
          _http(400, _errorResponse('VALIDATION_FAILED')),
        ).message,
        'Certaines informations ne sont plus valides.',
      );
    });

    test('unknown cases stay generic French', () {
      expect(
        ScheduledCareFailure.from(
          _http(418, _problem(418, 'NEW_CODE')),
        ).message,
        'La demande n’a pas pu être traitée.',
      );
      expect(
        ScheduledCareFailure.from(
          _http(502, '<html>bad gateway</html>'),
        ).message,
        'Le service est momentanément indisponible.',
      );
      expect(
        ScheduledCareFailure.from(
          _transport(DioExceptionType.connectionError),
        ).kind,
        ScheduledCareFailureKind.unknownOutcome,
      );
    });

    test('the doctor app can still build its own const failures', () {
      const local = ScheduledCareFailure(
        kind: ScheduledCareFailureKind.versionConflict,
        message: 'La demande a changé. Son état a été actualisé.',
        diagnosticCode: 'VERSION_CONFLICT',
      );
      expect(local.api, isNull);
    });

    test('field codes are available for precise French', () {
      final failure = ScheduledCareFailure.from(
        _http(
          400,
          _errorResponse(
            'VALIDATION_FAILED',
            fields: {'reason': 'x'},
            fieldCodes: {'reason': 'REQUIRED'},
          ),
        ),
      );
      expect(apiFieldErrorMessages(failure.api!.fieldErrors, _fr), {
        'reason': 'Ce champ est obligatoire.',
      });
    });
  });

  group('clinic directory', () {
    test('statuses map to French', () {
      expect(
        PatientClinicFailure.from(_http(503, _errorResponse('X'))).message(_fr),
        'L’annuaire des cliniques est momentanément indisponible. Réessayez.',
      );
      expect(
        PatientClinicFailure.from(_http(401, _errorResponse('X'))).message(_fr),
        'Votre session a expiré. Reconnectez-vous.',
      );
      expect(
        PatientClinicFailure.from(_http(400, _errorResponse('X'))).message(_fr),
        'La liste des cliniques n’a pas pu être lue. Réessayez.',
      );
      expect(
        PatientClinicFailure.from(
          _transport(DioExceptionType.sendTimeout),
        ).message(_fr),
        'La liste des cliniques met trop de temps à répondre. Réessayez.',
      );
      expect(
        PatientClinicFailure.from(_transport(DioExceptionType.cancel)).kind,
        PatientClinicFailureKind.network,
      );
      expect(
        PatientClinicFailure.from(StateError('x')).message(_fr),
        'Une erreur est survenue. Réessayez.',
      );
    });
  });

  group('doctor directory', () {
    test('patient screens get French; the doctor app keeps its message', () {
      final gone = DoctorDirectoryFailure.from(
        _http(404, _errorResponse('RESOURCE_NOT_FOUND')),
      );
      expect(gone.isNotFound, isTrue);
      expect(
        gone.patientMessage(_fr),
        'Ce médecin n’existe plus ou n’est plus disponible.',
      );
      expect(gone.message, DoctorDirectoryFailure.notFound.message);
      expect(
        DoctorDirectoryFailure.from(_http(500, 'oops')).patientMessage(_fr),
        'Le répertoire des médecins est momentanément indisponible. Réessayez.',
      );
      expect(
        DoctorDirectoryFailure.from(
          _http(422, _errorResponse('NEW')),
        ).patientMessage(_fr),
        'Le répertoire des médecins n’a pas pu être lu. Réessayez.',
      );
    });
  });

  group('urgent CABINET', () {
    test(
      'request failures: same kinds and French text, code from the parser',
      () {
        final changed = UrgentCabinetPatientRequestFailure.from(
          _http(409, _problemCode(409, 'URGENT_CABINET_TARGET_CHANGED')),
        );
        expect(
          changed.kind,
          UrgentCabinetPatientRequestFailureKind.targetChanged,
        );
        expect(
          changed.message,
          'Le médecin ou le cabinet a changé. Rechargez sa fiche.',
        );

        final absent = UrgentCabinetPatientRequestFailure.from(
          _http(404, _problemCode(404, 'URGENT_CABINET_REQUEST_NOT_FOUND')),
        );
        expect(absent.isAuthoritativeRequestAbsence, isTrue);

        // A plain 404 (proxy, other resource) is not an authoritative absence.
        final plain = UrgentCabinetPatientRequestFailure.from(
          _http(404, '<html>not found</html>'),
        );
        expect(plain.isAuthoritativeRequestAbsence, isFalse);
        expect(plain.message, 'Cette demande CABINET est indisponible.');

        final unknown = UrgentCabinetPatientRequestFailure.from(
          _http(418, _problemCode(418, 'NEW_CODE')),
        );
        expect(unknown.kind, UrgentCabinetPatientRequestFailureKind.rejected);
        expect(unknown.message, isNot(contains('PRIVATE')));
      },
    );

    test('discovery: feature-unavailable code read by the parser', () {
      expect(
        UrgentCabinetDiscoveryFailure.from(
          _http(404, _problemCode(404, 'URGENT_CABINET_REQUEST_UNAVAILABLE')),
        ).isFeatureUnavailable,
        isTrue,
      );
      // The same body as JSON text is read the same way.
      expect(
        UrgentCabinetDiscoveryFailure.from(
          _http(
            404,
            jsonEncode(
              _problemCode(404, 'URGENT_CABINET_REQUEST_NOT_AUTHORIZED'),
            ),
          ),
        ).isFeatureUnavailable,
        isTrue,
      );
      expect(
        UrgentCabinetDiscoveryFailure.from(_http(404, 'gone')).isNotFound,
        isTrue,
      );
    });
  });

  group('documents', () {
    Future<Object> listFailure(int status, Object body) => _thrownBy(
      () => DocumentsApi(
        httpClient: _client(status, body),
      ).listDocuments('patient-1'),
    );

    test('backend codes → French, never the server text', () async {
      final down = await listFailure(503, _errorResponse('MRS_UNAVAILABLE'));
      expect(
        documentErrorMessage(down, _fr),
        'Le traitement des documents est momentanément indisponible. '
        'Réessayez plus tard.',
      );
      expect(down.toString(), isNot(contains('PRIVATE')));

      expect(
        documentErrorMessage(
          await listFailure(415, _errorResponse('UNSUPPORTED_FILE_TYPE')),
          _fr,
        ),
        'Choisissez un fichier PDF, PNG, JPG ou JPEG.',
      );
      expect(
        documentErrorMessage(
          await listFailure(403, _problem(403, 'NEW_FORBIDDEN_CODE')),
          _fr,
        ),
        'Vous n’avez pas accès à ces documents.',
      );
    });

    test(
      'unknown cases: generic kind text or the documents fallback',
      () async {
        expect(
          documentErrorMessage(
            await listFailure(429, _errorResponse('NEW_CODE')),
            _fr,
          ),
          'Trop de tentatives. Patientez avant de réessayer.',
        );
        expect(
          documentErrorMessage(
            await listFailure(418, _errorResponse('NEW_CODE')),
            _fr,
          ),
          'L’opération sur le document n’a pas pu aboutir. Réessayez.',
        );
        expect(
          documentErrorMessage(StateError('x'), _fr),
          'L’opération sur le document n’a pas pu aboutir. Réessayez.',
        );
      },
    );

    test('the app\'s own local codes are French too', () {
      const local = {
        'PROFILE_NOT_READY': 'Votre profil patient n’est pas encore prêt.',
        'OPERATION_IN_PROGRESS':
            'Une opération sur les documents est déjà en cours.',
        'EMPTY_FILE': 'Le fichier choisi est vide.',
        'FILE_TOO_LARGE': 'Ce fichier dépasse la limite de 20 Mo.',
        'FILE_READ_FAILED': 'Le fichier choisi n’a pas pu être lu.',
        'UPLOAD_RECOVERY_REQUIRED':
            'Le résultat de l’envoi précédent doit d’abord être récupéré. '
            'Actualisez quand la connexion est disponible.',
      };
      for (final entry in local.entries) {
        expect(
          documentErrorMessage(
            ApiException('English developer text', code: entry.key),
            _fr,
          ),
          entry.value,
        );
      }
    });
  });

  group('auth', () {
    Future<Object> profileFailure(int status, Object body) =>
        _thrownBy(() => AuthApi(_client(status, body)).getPatientProfile());

    test('known codes keep their French; fields become kinds', () async {
      final used = await profileFailure(
        409,
        _errorResponse(
          'AUTH_PHONE_ALREADY_USED',
          fields: {'phone': 'must be a valid phone'},
          fieldCodes: {'phone': 'INVALID_FORMAT'},
        ),
      );
      expect(used.toString(), isNot(contains('PRIVATE')));
      expect(
        AuthErrorMessages.message(used, _fr),
        'Ce numéro est déjà utilisé.',
      );
      final presentation = AuthErrorMessages.fromObject(used);
      expect(presentation.code, 'AUTH_PHONE_ALREADY_USED');
      expect(apiFieldErrorMessages(presentation.fieldErrors, _fr), {
        'phone': 'Format invalide.',
      });
    });

    test('provider outage: one wording on auth and security screens', () async {
      final outage = await profileFailure(
        503,
        _errorResponse('AUTH_PROVIDER_UNAVAILABLE'),
      );
      const text =
          'Service de connexion momentanément indisponible. Réessayez plus tard.';
      expect(AuthErrorMessages.message(outage, _fr), text);
      expect(securityErrorMessage(outage, _fr), text);
    });

    test(
      'unknown codes and transport failures get the generic kind text',
      () async {
        expect(
          AuthErrorMessages.message(
            await profileFailure(409, _errorResponse('SOMETHING_NEW')),
            _fr,
          ),
          'Les informations ont changé entre-temps. Actualisez et réessayez.',
        );
        expect(
          AuthErrorMessages.message(
            ApiFailure.fromDio(_transport(DioExceptionType.connectionTimeout)),
            _fr,
          ),
          'Le serveur met trop de temps à répondre. Réessayez.',
        );
        expect(
          AuthErrorMessages.message(StateError('x'), _fr),
          'Une erreur est survenue. Réessayez.',
        );
      },
    );

    test('session refresh reads the code through the single parser', () {
      expect(
        apiErrorCodeOf({'code': 'AUTH_SESSION_INVALID'}),
        'AUTH_SESSION_INVALID',
      );
      expect(
        apiErrorCodeOf({'errorCode': 'AUTH_SESSION_EXPIRED', 'code': 'X'}),
        'AUTH_SESSION_EXPIRED',
      );
      expect(
        apiErrorCodeOf('{"code":"AUTH_REFRESH_TOKEN_INVALID"}'),
        'AUTH_REFRESH_TOKEN_INVALID',
      );
      expect(apiErrorCodeOf('<html>'), isNull);
      expect(apiErrorCodeOf(null), isNull);
    });
  });
}
