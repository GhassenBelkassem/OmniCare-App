// G-2 1b-2: one error parser for the five backend error shapes, French
// messages from app_fr.arb, Result<T>. Logic only (CTO testing rule).
//
// Bodies follow the backend records field by field (ErrorResponse,
// GlobalExceptionHandler session-limit map, ProblemDetail + errorCode/code,
// SecurityErrorResponseWriter problem map). The English `message`/`detail`
// values are the backend's real texts; none may come out of the parser.
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/network/api_failure_message.dart';
import 'package:omnicare_mobile/core/network/transport_failure.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));

/// Shape 1: ErrorResponse, a Bean Validation failure on the family form.
const _shape1 = {
  'code': 'VALIDATION_ERROR',
  'message': 'Validation failed',
  'timestamp': '2026-11-11T10:00:00Z',
  'fieldErrors': {
    'firstName': 'must not be blank',
    'dateOfBirth': 'must be a past date',
  },
};

/// Shape 2: the session-limit map.
const _shape2 = {
  'code': 'AUTH_MAX_SESSIONS_REACHED',
  'message': 'Maximum number of active sessions reached',
  'timestamp': '2026-11-11T10:00:00Z',
  'activeSessions': [
    {'sessionId': 's-1', 'deviceLabel': 'Pixel', 'platform': 'ANDROID'},
  ],
};

/// Shape 3: ProblemDetail + errorCode (M05 requests).
const _shape3 = {
  'type': 'https://omnicare.tn/problems/request-invalid',
  'title': 'Bad Request',
  'status': 400,
  'detail': 'The request is invalid.',
  'instance': '/api/v1/appointment-requests/clinic',
  'errorCode': 'REQUEST_INVALID',
  'requestId': 'req-3',
  'timestamp': '2026-11-11T10:00:00Z',
};

/// Shape 4: ProblemDetail + code (urgent cabinet, care capability).
const _shape4 = {
  'type': 'about:blank',
  'title': 'Unprocessable',
  'status': 400,
  'detail': 'Validation failed for urgent cabinet request.',
  'instance': '/api/v1/me/urgent-cabinet/requests',
  'code': 'VALIDATION_FAILED',
  'requestId': 'req-4',
  'timestamp': '2026-11-11T10:00:00Z',
};

/// Shape 5: security problem map on a `/me/*` path.
const _shape5 = {
  'type': 'about:blank',
  'title': 'Unauthorized',
  'status': 401,
  'detail': 'Authentication is required.',
  'instance': '/api/v1/me/urgent-cabinet/requests',
  'code': 'UNAUTHORIZED',
  'requestId': 'req-5',
  'timestamp': '2026-11-11T10:00:00Z',
};

const _serverTexts = [
  'Validation failed',
  'must not be blank',
  'must be a past date',
  'Maximum number of active sessions reached',
  'The request is invalid.',
  'Validation failed for urgent cabinet request.',
  'Authentication is required.',
  'Pixel',
];

DioException _dio(int status, Object? body, {Map<String, List<String>>? h}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(h ?? const {}),
    ),
  );
}

void main() {
  group('the five shapes', () {
    test('1 ErrorResponse: code, validation, field paths', () {
      final f = ApiFailure.fromDio(_dio(400, _shape1));
      expect(f.kind, ApiFailureKind.validation);
      expect(f.code, 'VALIDATION_ERROR');
      expect(f.statusCode, 400);
      // Today's backend sends no field code: each field is "invalid".
      expect(f.fieldErrors, {
        'firstName': ApiFieldErrorKind.invalid,
        'dateOfBirth': ApiFieldErrorKind.invalid,
      });
      expect(f.requestId, isNull);
    });

    test('1 with fieldErrorCodes: kinds from the codes', () {
      final f = ApiFailure.fromDio(
        _dio(400, {
          ..._shape1,
          'fieldErrorCodes': {
            'firstName': 'NotBlank',
            'dateOfBirth': 'Past',
            'lastName': 'TOO_LONG',
            'phone': 'Pattern',
            'notes': 'Size',
          },
        }),
      );
      expect(f.fieldErrors, {
        'firstName': ApiFieldErrorKind.required,
        'dateOfBirth': ApiFieldErrorKind.outOfRange,
        'lastName': ApiFieldErrorKind.tooLong,
        'phone': ApiFieldErrorKind.invalidFormat,
        'notes': ApiFieldErrorKind.invalidLength,
      });
    });

    test('2 session-limit map: code and conflict', () {
      final f = ApiFailure.fromDio(_dio(409, _shape2));
      expect(f.kind, ApiFailureKind.conflict);
      expect(f.code, 'AUTH_MAX_SESSIONS_REACHED');
      expect(f.fieldErrors, isEmpty);
    });

    test('3 ProblemDetail + errorCode, and errorCode wins over code', () {
      final f = ApiFailure.fromDio(_dio(400, _shape3));
      expect(f.kind, ApiFailureKind.validation);
      expect(f.code, 'REQUEST_INVALID');
      expect(f.requestId, 'req-3');
      final both = ApiFailure.fromDio(
        _dio(409, {..._shape3, 'code': 'OTHER', 'errorCode': 'SLOT_TAKEN'}),
      );
      expect(both.code, 'SLOT_TAKEN');
    });

    test('4 ProblemDetail + code', () {
      final f = ApiFailure.fromDio(_dio(400, _shape4));
      expect(f.code, 'VALIDATION_FAILED');
      expect(f.requestId, 'req-4');
    });

    test('5 security problem map', () {
      final f = ApiFailure.fromDio(_dio(401, _shape5));
      expect(f.kind, ApiFailureKind.unauthorized);
      expect(f.code, 'UNAUTHORIZED');
      expect(f.requestId, 'req-5');
    });

    test('no server text survives parsing or logging', () {
      for (final (status, body) in [
        (400, _shape1),
        (409, _shape2),
        (400, _shape3),
        (400, _shape4),
        (401, _shape5),
      ]) {
        final f = ApiFailure.fromDio(_dio(status, body));
        final legacy = ApiException.fromFailure(f);
        final shown = [
          f.toString(),
          f.logSummary,
          legacy.message,
          legacy.toString(),
          ...legacy.fieldErrors.values,
          apiFailureMessage(f, _fr),
          ...apiFieldErrorMessages(f.fieldErrors, _fr).values,
        ].join(' | ');
        for (final text in _serverTexts) {
          expect(shown.contains(text), isFalse, reason: '$text in $shown');
        }
      }
    });
  });

  group('garbage never throws', () {
    test('HTML, text, empty, list, number, broken JSON → kind of status', () {
      for (final body in <Object?>[
        '<html><body>502 Bad Gateway</body></html>',
        'Service Unavailable',
        '',
        null,
        const ['x'],
        42,
        '{"code": ',
      ]) {
        final f = ApiFailure.fromDio(_dio(502, body));
        expect(f.kind, ApiFailureKind.server, reason: '$body');
        expect(f.code, isNull, reason: '$body');
      }
      final teapot = ApiFailure.fromDio(_dio(418, '<html/>'));
      expect(teapot.kind, ApiFailureKind.unknown);
      expect(teapot.statusCode, 418);
    });

    test('a JSON string body is still read', () {
      final f = ApiFailure.fromDio(_dio(503, '{"code":"MRS_UNAVAILABLE"}'));
      expect(f.code, 'MRS_UNAVAILABLE');
    });

    test('notifications 404 with an empty body → notFound', () {
      expect(ApiFailure.fromDio(_dio(404, '')).kind, ApiFailureKind.notFound);
    });

    test('non-string code and odd field maps are ignored', () {
      final f = ApiFailure.fromDio(
        _dio(400, {'code': 12, 'fieldErrors': 'x', 'fieldErrorCodes': null}),
      );
      expect(f.code, isNull);
      expect(f.fieldErrors, isEmpty);
    });

    test('Retry-After is read from the header', () {
      final f = ApiFailure.fromDio(
        _dio(
          429,
          const {'code': 'TOO_MANY_REQUESTS'},
          h: const {
            'retry-after': ['60'],
          },
        ),
      );
      expect(f.kind, ApiFailureKind.rateLimited);
      expect(f.retryAfter, const Duration(seconds: 60));
    });
  });

  group('transport errors and other inputs', () {
    final options = RequestOptions(path: '/x');
    test('Dio types', () {
      for (final (type, kind) in [
        (DioExceptionType.connectionTimeout, ApiFailureKind.timeout),
        (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
        (DioExceptionType.sendTimeout, ApiFailureKind.timeout),
        (DioExceptionType.connectionError, ApiFailureKind.network),
        (DioExceptionType.badCertificate, ApiFailureKind.network),
        (DioExceptionType.cancel, ApiFailureKind.unknown),
        (DioExceptionType.unknown, ApiFailureKind.network),
      ]) {
        expect(
          ApiFailure.fromDio(
            DioException(requestOptions: options, type: type),
          ).kind,
          kind,
          reason: '$type',
        );
      }
    });

    test('from(): failures, legacy exceptions, transport, anything', () {
      const existing = ApiFailure(kind: ApiFailureKind.conflict, code: 'C');
      expect(ApiFailure.from(existing), same(existing));
      expect(
        ApiFailure.from(
          const ApiException('Server said no', code: 'X', statusCode: 403),
        ).kind,
        ApiFailureKind.forbidden,
      );
      expect(
        ApiFailure.from(
          const ApiException('offline', code: 'NETWORK_REQUEST_FAILED'),
        ).kind,
        ApiFailureKind.network,
      );
      expect(
        ApiFailure.from(
          const TransportFailure(kind: TransportFailureKind.dns),
        ).kind,
        ApiFailureKind.network,
      );
      expect(ApiFailure.from(StateError('x')).kind, ApiFailureKind.unknown);
      expect(ApiFailure.from(null).kind, ApiFailureKind.unknown);
      final wrapped = ApiException.fromFailure(existing);
      expect(ApiFailure.from(wrapped), same(existing));
    });
  });

  group('French messages', () {
    test('one generic message per kind', () {
      final expected = {
        ApiFailureKind.network:
            'Connexion impossible. Vérifiez votre connexion et réessayez.',
        ApiFailureKind.timeout:
            'Le serveur met trop de temps à répondre. Réessayez.',
        ApiFailureKind.unauthorized:
            'Votre session a expiré. Reconnectez-vous.',
        ApiFailureKind.forbidden: 'Vous n’avez pas accès à cette action.',
        ApiFailureKind.notFound:
            'Cet élément est introuvable ou n’est plus disponible.',
        ApiFailureKind.conflict:
            'Les informations ont changé entre-temps. Actualisez et réessayez.',
        ApiFailureKind.validation:
            'Certaines informations ne sont pas valides. Vérifiez et réessayez.',
        ApiFailureKind.rateLimited:
            'Trop de tentatives. Patientez avant de réessayer.',
        ApiFailureKind.server:
            'Service momentanément indisponible. Réessayez plus tard.',
        ApiFailureKind.featureUnavailable:
            'Cette fonctionnalité est indisponible pour le moment.',
        ApiFailureKind.unknown: 'Une erreur est survenue. Réessayez.',
      };
      expect(expected.keys.toSet(), ApiFailureKind.values.toSet());
      for (final entry in expected.entries) {
        expect(
          apiFailureMessage(ApiFailure(kind: entry.key), _fr),
          entry.value,
        );
      }
    });

    test('codes with a clear meaning have their own message', () {
      final cases = {
        'MRS_UNAVAILABLE':
            'Le dossier médical est temporairement indisponible. Réessayez plus tard.',
        'OBJECT_STORAGE_UNAVAILABLE':
            'Le stockage des fichiers est temporairement indisponible. Réessayez plus tard.',
        'FILE_TOO_LARGE': 'Ce fichier est trop volumineux.',
        'UNSUPPORTED_FILE_TYPE': 'Ce type de fichier n’est pas accepté.',
        'PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING':
            'Une demande est déjà en cours pour cette adresse e-mail ou cet identifiant professionnel.',
        'AUTH_PASSWORD_COMPROMISED':
            'Ce mot de passe est compromis. Choisissez-en un autre.',
        'AUTH_INVALID_CREDENTIALS': 'Les identifiants sont incorrects.',
      };
      for (final entry in cases.entries) {
        expect(
          apiFailureMessage(
            ApiFailure(kind: ApiFailureKind.server, code: entry.key),
            _fr,
          ),
          entry.value,
        );
      }
    });

    test('a code with an endpoint-dependent meaning → kind message', () {
      const failure = ApiFailure(
        kind: ApiFailureKind.validation,
        code: 'INVALID_STATE',
      );
      expect(
        apiFailureMessage(failure, _fr),
        'Certaines informations ne sont pas valides. Vérifiez et réessayez.',
      );
    });

    test('screen fallback: used for vague kinds, not for network etc.', () {
      const fallback = 'Impossible de charger le profil.';
      expect(
        apiFailureMessage(
          const ApiFailure(kind: ApiFailureKind.unknown),
          _fr,
          fallback: fallback,
        ),
        fallback,
      );
      expect(
        apiFailureMessage(
          const ApiFailure(kind: ApiFailureKind.network),
          _fr,
          fallback: fallback,
        ),
        'Connexion impossible. Vérifiez votre connexion et réessayez.',
      );
      expect(apiFailureMessageOr(null, _fr, fallback: fallback), fallback);
    });

    test('one French message per field kind', () {
      final expected = {
        ApiFieldErrorKind.required: 'Ce champ est obligatoire.',
        ApiFieldErrorKind.tooLong: 'Ce texte est trop long.',
        ApiFieldErrorKind.tooShort: 'Ce texte est trop court.',
        ApiFieldErrorKind.invalidLength:
            'La longueur de ce champ n’est pas valide.',
        ApiFieldErrorKind.invalidFormat: 'Format invalide.',
        ApiFieldErrorKind.outOfRange: 'Valeur hors limites.',
        ApiFieldErrorKind.invalid: 'Vérifiez ce champ.',
      };
      expect(expected.keys.toSet(), ApiFieldErrorKind.values.toSet());
      for (final entry in expected.entries) {
        expect(apiFieldErrorMessage(entry.key, _fr), entry.value);
      }
    });
  });

  group('Result<T>', () {
    test('guardApiCall wraps a value or a parsed failure', () async {
      expect(await guardApiCall(() async => 3), isA<Ok<int>>());
      final err = await guardApiCall<int>(() async => throw _dio(503, _shape3));
      expect(err, isA<Err<int>>());
      expect((err as Err<int>).failure.kind, ApiFailureKind.server);
      expect(err.toString(), isNot(contains('The request is invalid.')));
    });
  });
}
