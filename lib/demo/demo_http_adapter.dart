import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A Dio transport that can never open a socket.
///
/// The demo deliberately fails closed: adding a new API call without adding a
/// fixture produces a local 501 response instead of contacting OmniCare.
class DemoHttpAdapter implements HttpClientAdapter {
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      return _json(503, {'code': 'DEMO_CLOSED', 'message': 'Demo closed.'});
    }

    final path = _normalizedPath(options.uri.path);
    final method = options.method.toUpperCase();
    final fixture = _fixture(method, path, options);
    if (fixture != null) return _json(fixture.statusCode, fixture.body);

    return _json(501, {
      'code': 'DEMO_FIXTURE_MISSING',
      'message': 'No static demo fixture for $method $path.',
      'path': path,
    });
  }

  _DemoResponse? _fixture(String method, String path, RequestOptions options) {
    if (method == 'GET' && path == '/notifications/unread-count') {
      return const _DemoResponse({'unreadCount': 2});
    }
    if (method == 'GET' && path == '/notifications') {
      return _DemoResponse({
        'content': <Object>[],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
        'unreadCount': 2,
      });
    }
    if (method == 'POST' && path == '/notifications/read-all') {
      return const _DemoResponse({'updated': 2});
    }
    if (method == 'POST' &&
        RegExp(r'^/notifications/[^/]+/read$').hasMatch(path)) {
      return const _DemoResponse(null, statusCode: 204);
    }

    if (method == 'GET' && path == '/profile/family-members') {
      return const _DemoResponse([
        {
          'id': '11000000-0000-4000-8000-000000000001',
          'accountHolderId': '00000000-0000-4000-8000-000000000001',
          'patientId': '12000000-0000-4000-8000-000000000001',
          'firstName': 'Youssef',
          'lastName': 'Ben Amor',
          'dateOfBirth': '2016-03-21',
          'gender': 'MALE',
          'relationship': 'enfant',
          'photoUrl': null,
          'graduated': false,
          'createdAt': _now,
          'updatedAt': _now,
        },
      ]);
    }

    if (method == 'GET' && path == '/me/access') {
      return const _DemoResponse({'accessFamily': 'CLINIC'});
    }
    if (method == 'GET' && path == '/me/clinics') {
      return const _DemoResponse({
        'activeMemberships': [
          {
            'clinicId': '30000000-0000-4000-8000-000000000001',
            'clinicName': 'Clinique OmniCare Lac 2',
            'membershipId': '31000000-0000-4000-8000-000000000001',
            'professionalRole': 'CLINIC_ADMIN',
            'membershipStatus': 'ACTIVE',
            'clinicStatus': 'ACTIVE',
            'version': 1,
          },
        ],
        'unavailableMemberships': <Object>[],
      });
    }
    if (method == 'GET' &&
        RegExp(r'^/clinics/[^/]+/bootstrap$').hasMatch(path)) {
      return const _DemoResponse({
        'clinic': {
          'clinicId': '30000000-0000-4000-8000-000000000001',
          'clinicName': 'Clinique OmniCare Lac 2',
          'clinicStatus': 'ACTIVE',
        },
        'membership': {
          'membershipId': '31000000-0000-4000-8000-000000000001',
          'membershipStatus': 'ACTIVE',
          'professionalRole': 'CLINIC_ADMIN',
          'version': 1,
        },
        'capabilities': [
          'CLINIC_OVERVIEW_READ',
          'CLINIC_PROFILE_READ',
          'CLINIC_MEMBERSHIP_SELF_READ',
          'CLINIC_TASK_READ',
          'CLINIC_TASK_HANDOVER',
        ],
        'featureFlags': {
          'CLINIC_REQUESTS_ENABLED': true,
          'CLINIC_MOBILE_TASKS_ENABLED': true,
        },
      });
    }
    if (method == 'GET' &&
        RegExp(
          r'^/clinics/[^/]+/(tasks/(position-queue|my)|task-handovers/(incoming|outgoing))$',
        ).hasMatch(path)) {
      return const _DemoResponse({
        'items': <Object>[],
        'page': 0,
        'pageSize': 20,
        'hasNext': false,
        'generatedAt': _now,
        'contractVersion': 'demo-v1',
      });
    }

    if (method == 'GET' && path == '/me/care-capabilities') {
      return const _DemoResponse({
        'revision': 1,
        'capabilities': [
          'CABINET',
          'HOME_VISIT',
          'URGENT_HOME',
          'URGENT_CABINET',
        ],
      });
    }
    if (method == 'GET' &&
        path == '/me/care-capabilities/urgent-configuration') {
      return const _DemoResponse({
        'revision': 1,
        'home': {'feeConfigured': true, 'maxTravelDistanceConfigured': true},
        'cabinet': {'feeConfigured': true},
      });
    }
    if (method == 'GET' &&
        path == '/me/care-capabilities/urgent-configuration/readiness') {
      return _DemoResponse({
        'revision': 1,
        'professionalEligible': true,
        'home': _homeReadinessMode,
        'cabinet': _readinessMode,
        'completeLiveMatchingEligibilityEvaluated': true,
        'evaluatedAt': _now,
      });
    }
    if (method == 'GET' && path == '/me/practice-locations') {
      return const _DemoResponse([
        {
          'id': '20000000-0000-4000-8000-000000000001',
          'type': 'CABINET',
          'name': 'Cabinet Lac 2',
          'governorate': 'Tunis',
          'city': 'Les Berges du Lac',
          'address': 'Rue du Lac Biwa, Tunis',
          'active': true,
          'primary': true,
        },
      ]);
    }
    if ((method == 'GET' || method == 'PUT') && path == '/me/urgent-runtime') {
      return _DemoResponse({
        'revision': method == 'PUT' ? 2 : 1,
        'homeEnabled': false,
        'cabinetEnabled': true,
        'capacityState': 'FREE',
        'home': _homeRuntimeMode,
        'cabinet': _runtimeMode,
        'homeLocationPresence': {
          'status': 'AVAILABLE',
          'updateId': 'demo-location',
          'observedAt': _now,
          'receivedAt': _now,
          'accuracyMeters': 8.0,
          'ageSeconds': 5,
        },
        'completeRequestSpecificEligibilityEvaluated': true,
        'evaluatedAt': _now,
      });
    }

    if (method == 'GET' && path == '/doctor/consultations/active') {
      return const _DemoResponse(null, statusCode: 204);
    }
    if (method == 'GET' && path == '/me/urgent-home/offers') {
      return const _DemoResponse(<Object>[]);
    }
    if (method == 'GET' && path == '/me/urgent-home/commitments/active') {
      return const _DemoResponse({
        'result': 'NO_ACTIVE_COMMITMENT',
        'commitment': null,
        'evaluatedAt': _now,
      });
    }
    if (method == 'GET' && path == '/doctor/scheduled-care/home-summary') {
      return const _DemoResponse({
        'generatedAt': _now,
        'pendingRequestCount': 0,
        'nextPendingRequest': null,
        'nextConfirmedAppointment': null,
      });
    }
    if (method == 'GET' && path == '/doctor/scheduled-care') {
      final from = options.queryParameters['from']?.toString() ?? _now;
      final to =
          options.queryParameters['to']?.toString() ?? '2026-11-29T09:00:00Z';
      return _DemoResponse({
        'generatedAt': _now,
        'from': from,
        'to': to,
        'items': <Object>[],
      });
    }

    if (method == 'GET' && path == '/patient/clinics') {
      return const _DemoResponse({
        'contractVersion': '1.0',
        'items': <Object>[],
        'page': 0,
        'pageSize': 20,
        'hasNext': false,
      });
    }
    if (method == 'GET' && path == '/doctors') {
      return const _DemoResponse(<Object>[]);
    }
    if (method == 'GET' && path == '/appointment-requests') {
      return const _DemoResponse({
        'contractVersion': '1.0',
        'items': <Object>[],
        'page': 0,
        'pageSize': 20,
        'hasNext': false,
      });
    }
    if (method == 'GET' && path == '/patient/scheduled-care') {
      return const _DemoResponse({'items': <Object>[], 'nextCursor': null});
    }

    // Mutation-only presentation actions are successful and remain local.
    if (method != 'GET' && method != 'HEAD') {
      return _DemoResponse(
        options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : <String, dynamic>{'demo': true},
      );
    }
    return null;
  }

  static const _readinessMode = <String, Object>{
    'capabilityEnabled': true,
    'configurationReady': true,
    'runtimeAvailabilityIntent': true,
    'effectiveCurrentEligibility': true,
    'blockingReasons': <Object>[],
  };

  static const _homeReadinessMode = <String, Object>{
    'capabilityEnabled': true,
    'configurationReady': true,
    'runtimeAvailabilityIntent': false,
    'effectiveCurrentEligibility': false,
    'blockingReasons': <Object>['RUNTIME_HOME_INTENT_DISABLED'],
  };

  static const _runtimeMode = <String, Object>{
    'runtimeIntentEnabled': true,
    'activationPrerequisitesSatisfied': true,
    'capacityAvailable': true,
    'operationalPresenceReady': true,
    'runtimeFoundationReady': true,
    'requestSpecificEligibilityEvaluated': true,
    'effectiveCurrentEligibility': true,
    'blockingReasons': <Object>[],
  };

  static const _homeRuntimeMode = <String, Object>{
    'runtimeIntentEnabled': false,
    'activationPrerequisitesSatisfied': true,
    'capacityAvailable': true,
    'operationalPresenceReady': false,
    'runtimeFoundationReady': true,
    'requestSpecificEligibilityEvaluated': true,
    'effectiveCurrentEligibility': false,
    'blockingReasons': <Object>['RUNTIME_HOME_INTENT_DISABLED'],
  };

  static const _now = '2026-10-29T09:00:00Z';

  String _normalizedPath(String path) {
    const prefix = '/api/v1';
    if (path == prefix) return '/';
    return path.startsWith('$prefix/') ? path.substring(prefix.length) : path;
  }

  ResponseBody _json(int statusCode, Object? body) {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        'x-omnicare-demo': ['static'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}

class _DemoResponse {
  const _DemoResponse(this.body, {this.statusCode = 200});

  final Object? body;
  final int statusCode;
}
