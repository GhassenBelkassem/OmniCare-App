import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_offer.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_offer_inbox_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_offer_inbox_section.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_home_offer_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_workspace_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

final _now = DateTime.utc(2026, 10, 16, 10);

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _OfferHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <Object>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses.removeAt(0);
    if (response is DioException) throw response;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        HttpHeaders.cacheControlHeader: ['no-store'],
      },
    );
  }
}

class _ListCall {
  const _ListCall(this.beforeUpdatedAt, this.beforeOfferId);

  final DateTime? beforeUpdatedAt;
  final String? beforeOfferId;
}

class _CommandCall {
  const _CommandCall(
    this.action,
    this.offerId,
    this.expectedRevision,
    this.idempotencyKey,
  );

  final DoctorHomeOfferAction action;
  final String offerId;
  final int expectedRevision;
  final String idempotencyKey;
}

class _OfferRepository implements DoctorHomeOfferRepositoryContract {
  final listResults = <Object>[];
  final detailResults = <Object>[];
  final acceptResults = <Object>[];
  final declineResults = <Object>[];
  final listCalls = <_ListCall>[];
  final detailCalls = <String>[];
  final commandCalls = <_CommandCall>[];

  @override
  Future<DoctorHomeOffer> accept({
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) => _command(
    DoctorHomeOfferAction.accept,
    offerId,
    expectedRevision,
    idempotencyKey,
    acceptResults,
  );

  @override
  Future<DoctorHomeOffer> decline({
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) => _command(
    DoctorHomeOfferAction.decline,
    offerId,
    expectedRevision,
    idempotencyKey,
    declineResults,
  );

  Future<DoctorHomeOffer> _command(
    DoctorHomeOfferAction action,
    String offerId,
    int expectedRevision,
    String idempotencyKey,
    List<Object> results,
  ) {
    commandCalls.add(
      _CommandCall(action, offerId, expectedRevision, idempotencyKey),
    );
    final result = results.removeAt(0);
    if (result is Future<DoctorHomeOffer>) return result;
    if (result is DoctorHomeOffer) return Future.value(result);
    return Future.error(result);
  }

  @override
  Future<DoctorHomeOffer> get(
    String offerId, {
    CancelToken? cancelToken,
  }) async {
    detailCalls.add(offerId);
    final result = detailResults.removeAt(0);
    if (result is Future<DoctorHomeOffer>) return result;
    if (result is DoctorHomeOffer) return result;
    return Future.error(result);
  }

  @override
  Future<List<DoctorHomeOffer>> list({
    int limit = 20,
    DateTime? beforeUpdatedAt,
    String? beforeOfferId,
    CancelToken? cancelToken,
  }) async {
    listCalls.add(_ListCall(beforeUpdatedAt, beforeOfferId));
    final result = listResults.removeAt(0);
    if (result is Future<List<DoctorHomeOffer>>) return result;
    if (result is List<DoctorHomeOffer>) return result;
    return Future.error(result);
  }
}

Map<String, Object?> _pendingJson({
  String id = '11111111-1111-4111-8111-111111111111',
  DateTime? updatedAt,
  int revision = 2,
  DateTime? responseDeadlineAt,
  DateTime? evaluatedAt,
}) => {
  'offerId': id,
  'status': 'PENDING_RESPONSE',
  'revision': revision,
  'responseDeadlineAt':
      (responseDeadlineAt ?? _now.add(const Duration(seconds: 45)))
          .toIso8601String(),
  'holdExpiresAt': null,
  'holdCurrentlyValid': false,
  'quotedHomeFeeTnd': null,
  'currency': null,
  'withdrawalReason': null,
  'replayed': false,
  'updatedAt': (updatedAt ?? _now).toIso8601String(),
  'evaluatedAt': (evaluatedAt ?? _now).toIso8601String(),
};

Map<String, Object?> _heldJson({
  String id = '22222222-2222-4222-8222-222222222222',
  bool valid = true,
  DateTime? updatedAt,
  double fee = 25,
  bool replayed = false,
}) => {
  'offerId': id,
  'status': 'ACCEPTED_HELD',
  'revision': 4,
  'responseDeadlineAt': _now
      .subtract(const Duration(minutes: 1))
      .toIso8601String(),
  'holdExpiresAt': _now
      .add(valid ? const Duration(minutes: 2) : const Duration(seconds: -1))
      .toIso8601String(),
  'holdCurrentlyValid': valid,
  'quotedHomeFeeTnd': fee,
  'currency': 'TND',
  'withdrawalReason': null,
  'replayed': replayed,
  'updatedAt': (updatedAt ?? _now).toIso8601String(),
  'evaluatedAt': _now.toIso8601String(),
};

DoctorHomeOffer _pending({
  String id = '11111111-1111-4111-8111-111111111111',
  DateTime? updatedAt,
  int revision = 2,
  DateTime? responseDeadlineAt,
  DateTime? evaluatedAt,
}) => parseDoctorHomeOffer(
  _pendingJson(
    id: id,
    updatedAt: updatedAt,
    revision: revision,
    responseDeadlineAt: responseDeadlineAt,
    evaluatedAt: evaluatedAt,
  ),
);

DoctorHomeOffer _held({
  String id = '22222222-2222-4222-8222-222222222222',
  bool valid = true,
  DateTime? updatedAt,
  double fee = 25,
  bool replayed = false,
}) => parseDoctorHomeOffer(
  _heldJson(
    id: id,
    valid: valid,
    updatedAt: updatedAt,
    fee: fee,
    replayed: replayed,
  ),
);

DoctorHomeOffer _committed({
  String id = '11111111-1111-4111-8111-111111111111',
  double fee = 25,
}) => parseDoctorHomeOffer({
  ..._heldJson(id: id, valid: false, fee: fee),
  'status': 'SELECTED_COMMITTED',
  'revision': 5,
});

DoctorHomeOffer _terminal(
  DoctorHomeOfferStatus status, {
  String id = '11111111-1111-4111-8111-111111111111',
  int revision = 3,
}) => parseDoctorHomeOffer({
  ..._pendingJson(id: id),
  'status': switch (status) {
    DoctorHomeOfferStatus.declined => 'DECLINED',
    DoctorHomeOfferStatus.expired => 'EXPIRED',
    DoctorHomeOfferStatus.superseded => 'SUPERSEDED',
    DoctorHomeOfferStatus.cancelled => 'CANCELLED',
    DoctorHomeOfferStatus.notSelected => 'NOT_SELECTED',
    _ => throw ArgumentError('Unsupported terminal test status.'),
  },
  'revision': revision,
});

DioException _problem(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/me/urgent-home/offers'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/me/urgent-home/offers'),
    statusCode: status,
    data: {'code': code},
  ),
);

DoctorHomeOfferInboxController _controller(
  _OfferRepository repository, {
  VoidCallback? onSessionRejected,
  VoidCallback? onCommitmentMayHaveChanged,
  int pageSize = 20,
  int maximumRetainedPages = 3,
  String Function()? idempotencyKeyFactory,
}) => DoctorHomeOfferInboxController(
  repository: repository,
  onSessionRejected: onSessionRejected,
  onCommitmentMayHaveChanged: onCommitmentMayHaveChanged,
  pageSize: pageSize,
  maximumRetainedPages: maximumRetainedPages,
  idempotencyKeyFactory:
      idempotencyKeyFactory ?? () => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
);

void main() {
  group('P4-05B HOME offer DTO and HTTP contract', () {
    test(
      'parses only the exact minimized pending and accepted projections',
      () {
        final pending = _pending();
        final held = _held();

        expect(pending.status, DoctorHomeOfferStatus.pendingResponse);
        expect(pending.quotedHomeFeeTnd, isNull);
        expect(held.status, DoctorHomeOfferStatus.acceptedHeld);
        expect(held.quotedHomeFeeTnd, '25.000');
        expect(held.currency, 'TND');
        expect(held.holdCurrentlyValid, isTrue);
      },
    );

    test(
      'rejects unknown states, malformed fees and inconsistent hold shape',
      () {
        expect(
          () => parseDoctorHomeOffer({..._pendingJson(), 'status': 'NEW'}),
          throwsFormatException,
        );
        expect(
          () => parseDoctorHomeOffer({
            ..._heldJson(),
            'quotedHomeFeeTnd': 12.3456,
          }),
          throwsFormatException,
        );
        expect(
          () => parseDoctorHomeOffer({
            ..._heldJson(),
            'holdCurrentlyValid': true,
            'holdExpiresAt': _now
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
          }),
          throwsFormatException,
        );
      },
    );

    test('maps every terminal state exposed by the backend', () {
      const states = {
        'HOLD_EXPIRED',
        'DOCTOR_WITHDRAWN',
        'DECLINED',
        'SELECTED_COMMITTED',
        'NOT_SELECTED',
        'SELECTION_CLOSED',
        'INVALIDATED',
        'EXPIRED',
        'SUPERSEDED',
        'CANCELLED',
      };
      for (final state in states) {
        final value = <String, Object?>{..._pendingJson(), 'status': state};
        if (state == 'DOCTOR_WITHDRAWN') {
          value['withdrawalReason'] = 'NO_LONGER_AVAILABLE';
        }
        expect(parseDoctorHomeOffer(value).isTerminal, isTrue);
      }
    });

    test(
      'uses authenticated list/detail endpoints and exact keyset cursor',
      () async {
        final adapter = _OfferHttpAdapter()
          ..responses.add([_pendingJson()])
          ..responses.add(_heldJson());
        final dio = Dio()..httpClientAdapter = adapter;
        final client = AppHttpClient(
          tokenStore: SecureTokenStore(backend: _MemoryStorage()),
          baseUrl: 'https://example.test',
          dio: dio,
          refreshDio: Dio(),
        );
        final repository = DoctorHomeOfferRepository(client);

        await repository.list(
          limit: 20,
          beforeUpdatedAt: _now,
          beforeOfferId: '11111111-1111-4111-8111-111111111111',
        );
        await repository.get('22222222-2222-4222-8222-222222222222');

        expect(adapter.requests[0].method, 'GET');
        expect(adapter.requests[0].path, '/me/urgent-home/offers');
        expect(adapter.requests[0].queryParameters, {
          'limit': 20,
          'beforeUpdatedAt': _now.toIso8601String(),
          'beforeOfferId': '11111111-1111-4111-8111-111111111111',
        });
        expect(adapter.requests[1].method, 'GET');
        expect(
          adapter.requests[1].path,
          '/me/urgent-home/offers/22222222-2222-4222-8222-222222222222',
        );
        expect(
          adapter.requests.every((request) => request.data == null),
          isTrue,
        );
        expect(
          adapter.requests.every(
            (request) => !request.queryParameters.containsKey('doctorId'),
          ),
          isTrue,
        );
      },
    );

    test('posts only revision with a stable idempotency header', () async {
      final adapter = _OfferHttpAdapter()
        ..responses.add(_heldJson())
        ..responses.add({
          ..._pendingJson(),
          'status': 'DECLINED',
          'revision': 3,
        });
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = DoctorHomeOfferRepository(
        AppHttpClient(
          tokenStore: SecureTokenStore(backend: _MemoryStorage()),
          baseUrl: 'https://example.test',
          dio: dio,
          refreshDio: Dio(),
        ),
      );

      await repository.accept(
        offerId: '22222222-2222-4222-8222-222222222222',
        expectedRevision: 2,
        idempotencyKey: 'accept-key',
      );
      await repository.decline(
        offerId: '11111111-1111-4111-8111-111111111111',
        expectedRevision: 2,
        idempotencyKey: 'decline-key',
      );

      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'POST',
      ]);
      expect(adapter.requests.map((request) => request.path), [
        '/me/urgent-home/offers/22222222-2222-4222-8222-222222222222/accept',
        '/me/urgent-home/offers/11111111-1111-4111-8111-111111111111/decline',
      ]);
      expect(adapter.requests[0].data, {'expectedRevision': 2});
      expect(adapter.requests[1].data, {'expectedRevision': 2});
      expect(adapter.requests[0].headers['Idempotency-Key'], 'accept-key');
      expect(adapter.requests[1].headers['Idempotency-Key'], 'decline-key');
      expect(
        adapter.requests.every(
          (request) =>
              request.data is Map &&
              !(request.data as Map).containsKey('doctorId') &&
              !(request.data as Map).containsKey('patientId') &&
              !(request.data as Map).containsKey('price') &&
              !(request.data as Map).containsKey('location'),
        ),
        isTrue,
      );
    });

    test('maps rollout, ownership, session, server and network failures', () {
      expect(
        DoctorHomeOfferFailure.from(
          _problem(404, 'URGENT_RUNTIME_UNAVAILABLE'),
        ).kind,
        DoctorHomeOfferFailureKind.rolloutUnavailable,
      );
      expect(
        DoctorHomeOfferFailure.from(_problem(404, 'HOME_OFFER_NOT_FOUND')).kind,
        DoctorHomeOfferFailureKind.notFound,
      );
      expect(
        DoctorHomeOfferFailure.from(_problem(403, 'FORBIDDEN')).kind,
        DoctorHomeOfferFailureKind.sessionRejected,
      );
      expect(
        DoctorHomeOfferFailure.from(_problem(503, 'SERVICE_UNAVAILABLE')).kind,
        DoctorHomeOfferFailureKind.serverUnavailable,
      );
      expect(
        DoctorHomeOfferFailure.from(
          DioException(
            requestOptions: RequestOptions(path: '/offers'),
            type: DioExceptionType.connectionTimeout,
          ),
        ).kind,
        DoctorHomeOfferFailureKind.network,
      );
    });

    test('maps the complete HOME response-command error vocabulary', () {
      const expected = {
        'RESOURCE_STATE_CONFLICT':
            DoctorHomeOfferCommandFailureKind.stateConflict,
        'HOME_OFFER_NOT_ACTIONABLE':
            DoctorHomeOfferCommandFailureKind.notActionable,
        'HOME_OFFER_IDEMPOTENCY_CONFLICT':
            DoctorHomeOfferCommandFailureKind.idempotencyConflict,
        'HOME_OFFER_COMMAND_IN_PROGRESS':
            DoctorHomeOfferCommandFailureKind.commandInProgress,
        'HOME_HOLD_BUDGET_FULL':
            DoctorHomeOfferCommandFailureKind.holdBudgetFull,
        'HOME_DOCTOR_CAPACITY_CONFLICT':
            DoctorHomeOfferCommandFailureKind.capacityConflict,
        'HOME_OFFER_ELIGIBILITY_CHANGED':
            DoctorHomeOfferCommandFailureKind.eligibilityChanged,
        'LOCATION_PRESENCE_UNAVAILABLE':
            DoctorHomeOfferCommandFailureKind.locationUnavailable,
        'HOME_ROUTE_VERIFICATION_UNAVAILABLE':
            DoctorHomeOfferCommandFailureKind.routeUnavailable,
      };
      for (final entry in expected.entries) {
        expect(
          DoctorHomeOfferCommandFailure.from(_problem(409, entry.key)).kind,
          entry.value,
        );
      }
      expect(
        DoctorHomeOfferCommandFailure.from(
          _problem(404, 'URGENT_RUNTIME_UNAVAILABLE'),
        ).kind,
        DoctorHomeOfferCommandFailureKind.rolloutUnavailable,
      );
      expect(
        DoctorHomeOfferCommandFailure.from(
          _problem(404, 'HOME_OFFER_NOT_FOUND'),
        ).kind,
        DoctorHomeOfferCommandFailureKind.notFound,
      );
      expect(
        DoctorHomeOfferCommandFailure.from(_problem(403, 'FORBIDDEN')).kind,
        DoctorHomeOfferCommandFailureKind.sessionRejected,
      );
    });

    test(
      'rejects oversized, duplicate, terminal and unstable list pages',
      () async {
        Future<void> expectRejected(Object response) async {
          final adapter = _OfferHttpAdapter()..responses.add(response);
          final dio = Dio()..httpClientAdapter = adapter;
          final repository = DoctorHomeOfferRepository(
            AppHttpClient(
              tokenStore: SecureTokenStore(backend: _MemoryStorage()),
              baseUrl: 'https://example.test',
              dio: dio,
              refreshDio: Dio(),
            ),
          );
          await expectLater(repository.list(limit: 1), throwsFormatException);
        }

        await expectRejected([_pendingJson(), _heldJson()]);
        await expectRejected([_pendingJson(), _pendingJson()]);
        await expectRejected([
          {..._pendingJson(), 'status': 'EXPIRED'},
        ]);
        await expectRejected([
          _pendingJson(updatedAt: _now.subtract(const Duration(minutes: 1))),
          _heldJson(updatedAt: _now),
        ]);
      },
    );
  });

  group('server-authoritative HOME offer inbox', () {
    test('CABINET-only Doctor never queries HOME offers', () async {
      final repository = _OfferRepository();
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: false);

      await controller.activate();

      expect(repository.listCalls, isEmpty);
      expect(controller.state, DoctorHomeOfferInboxState.detached);
      controller.dispose();
    });

    test('HOME-only Doctor with zero Cabinets loads an empty inbox', () async {
      final repository = _OfferRepository()
        ..listResults.add(<DoctorHomeOffer>[]);
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);

      await controller.activate();

      expect(repository.listCalls, hasLength(1));
      expect(controller.state, DoctorHomeOfferInboxState.empty);
      controller.dispose();
    });

    test(
      'loads multiple authenticated offers and preserves accepted-hold meaning',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending(), _held()]);
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);

        await controller.activate();

        expect(controller.offers, hasLength(2));
        expect(controller.offers.last.isAcceptedHold, isTrue);
        expect(
          controller.offers.last.status,
          isNot(DoctorHomeOfferStatus.selectedCommitted),
        );
        controller.dispose();
      },
    );

    test('bounded keyset pagination retains at most three pages', () async {
      DoctorHomeOffer pageOffer(int page, int item) => _pending(
        id: '0000000$page-000$item-4000-8000-00000000000$item',
        updatedAt: _now.subtract(Duration(minutes: page, seconds: item)),
      );
      final repository = _OfferRepository()
        ..listResults.add([pageOffer(1, 1), pageOffer(1, 2)])
        ..listResults.add([pageOffer(2, 3), pageOffer(2, 4)])
        ..listResults.add([pageOffer(3, 5), pageOffer(3, 6)]);
      final controller = _controller(
        repository,
        pageSize: 2,
        maximumRetainedPages: 3,
      );
      controller.attachDoctor('doctor-a', hasHomeCapability: true);

      await controller.activate();
      await controller.loadMore();
      await controller.loadMore();
      await controller.loadMore();

      expect(repository.listCalls, hasLength(3));
      expect(controller.offers, hasLength(6));
      expect(controller.canLoadMore, isFalse);
      expect(repository.listCalls[1].beforeOfferId, pageOffer(1, 2).offerId);
      expect(
        repository.listCalls[1].beforeUpdatedAt,
        pageOffer(1, 2).updatedAt,
      );
      controller.dispose();
    });

    test('fast repeated refresh discards the older delayed response', () async {
      final first = Completer<List<DoctorHomeOffer>>();
      final repository = _OfferRepository()
        ..listResults.add(first.future)
        ..listResults.add([_held()]);
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);

      final oldRequest = controller.activate();
      await controller.refresh();
      first.complete([_pending()]);
      await oldRequest;

      expect(
        controller.offers.single.status,
        DoctorHomeOfferStatus.acceptedHeld,
      );
      controller.dispose();
    });

    test(
      'refresh cancels stale detail work and clears its loading state',
      () async {
        final detail = Completer<DoctorHomeOffer>();
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..listResults.add([_held()])
          ..detailResults.add(detail.future);
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        final staleDetail = controller.loadDetail(
          controller.offers.single.offerId,
        );
        expect(controller.detailLoadingOfferId, isNotNull);
        await controller.refresh();
        expect(controller.detailLoadingOfferId, isNull);
        detail.complete(_pending());

        expect(await staleDetail, isA<DoctorHomeOfferDetailUnavailable>());
        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.acceptedHeld,
        );
        controller.dispose();
      },
    );

    test('offline failure recovers through explicit refresh', () async {
      final repository = _OfferRepository()
        ..listResults.add(
          DioException(
            requestOptions: RequestOptions(path: '/offers'),
            type: DioExceptionType.connectionError,
          ),
        )
        ..listResults.add([_pending()]);
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);

      await controller.activate();
      expect(controller.state, DoctorHomeOfferInboxState.failure);
      await controller.refresh();
      expect(controller.state, DoctorHomeOfferInboxState.ready);
      controller.dispose();
    });

    test(
      'rollout 404 is fail-closed and distinct from an empty inbox',
      () async {
        final repository = _OfferRepository()
          ..listResults.add(_problem(404, 'URGENT_RUNTIME_UNAVAILABLE'));
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);

        await controller.activate();

        expect(controller.state, DoctorHomeOfferInboxState.unavailable);
        expect(controller.offers, isEmpty);
        controller.dispose();
      },
    );

    test('known rollout unavailability suppresses the inbox HTTP read', () async {
      final repository = _OfferRepository();
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      controller.synchronizeRolloutAccess(available: false);

      await controller.activate();

      expect(controller.state, DoctorHomeOfferInboxState.unavailable);
      expect(repository.listCalls, isEmpty);
      controller.dispose();
    });

    test('backend 503 fails closed without retaining stale offers', () async {
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..listResults.add(_problem(503, 'SERVICE_UNAVAILABLE'));
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      await controller.activate();

      await controller.refresh();

      expect(controller.state, DoctorHomeOfferInboxState.failure);
      expect(controller.offers, isEmpty);
      controller.dispose();
    });

    test(
      '401/403 invokes protected-session rejection and clears no fake state',
      () async {
        var rejected = 0;
        final repository = _OfferRepository()
          ..listResults.add(_problem(401, 'UNAUTHORIZED'));
        final controller = _controller(
          repository,
          onSessionRejected: () => rejected++,
        );
        controller.attachDoctor('doctor-a', hasHomeCapability: true);

        await controller.activate();

        expect(rejected, 1);
        expect(controller.offers, isEmpty);
        controller.dispose();
      },
    );

    test(
      'account switching fences and discards the previous Doctor response',
      () async {
        final first = Completer<List<DoctorHomeOffer>>();
        final repository = _OfferRepository()
          ..listResults.add(first.future)
          ..listResults.add([_held()]);
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        final previous = controller.activate();

        controller.attachDoctor('doctor-b', hasHomeCapability: true);
        final current = controller.activate();
        first.complete([_pending()]);
        await Future.wait([previous, current]);

        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.acceptedHeld,
        );
        controller.dispose();
      },
    );

    test(
      'foreign or stale detail 404 removes the stale list projection',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_problem(404, 'HOME_OFFER_NOT_FOUND'));
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        final result = await controller.loadDetail(
          controller.offers.single.offerId,
        );

        expect(result, isA<DoctorHomeOfferDetailUnavailable>());
        expect(controller.offers, isEmpty);
        expect(controller.state, DoctorHomeOfferInboxState.empty);
        controller.dispose();
      },
    );

    test(
      'detail opening fetches current server state instead of trusting list',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(
            _held(id: '11111111-1111-4111-8111-111111111111'),
          );
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        final result = await controller.loadDetail(
          controller.offers.single.offerId,
        );

        expect(result, isA<DoctorHomeOfferDetailLoaded>());
        expect(repository.detailCalls, hasLength(1));
        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.acceptedHeld,
        );
        controller.dispose();
      },
    );

    test(
      'detail may truthfully reveal supersession after a pending list row',
      () async {
        final superseded = parseDoctorHomeOffer({
          ..._pendingJson(),
          'status': 'SUPERSEDED',
          'revision': 3,
        });
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(superseded);
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        final result = await controller.loadDetail(
          controller.offers.single.offerId,
        );

        expect(result, isA<DoctorHomeOfferDetailLoaded>());
        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.superseded,
        );
        controller.dispose();
      },
    );

    test('logout clear discards retained offers and late responses', () async {
      final pending = Completer<List<DoctorHomeOffer>>();
      final repository = _OfferRepository()..listResults.add(pending.future);
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      final load = controller.activate();

      controller.clear();
      pending.complete([_pending()]);
      await load;

      expect(controller.state, DoctorHomeOfferInboxState.detached);
      expect(controller.offers, isEmpty);
      controller.dispose();
    });

    test(
      'deactivation cancels visibility and foreground refresh is bounded',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..listResults.add([_held()]);
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();
        controller.deactivate();

        await controller.refreshIfActive();
        expect(repository.listCalls, hasLength(1));
        await controller.activate();
        expect(repository.listCalls, hasLength(2));
        controller.dispose();
      },
    );
  });

  group('server-authoritative HOME offer commands', () {
    test(
      'accept uses the fresh revision and adopts a provisional hold',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending(revision: 1)])
          ..detailResults.add(_pending(revision: 2))
          ..acceptResults.add(
            _held(id: '11111111-1111-4111-8111-111111111111', fee: 75),
          );
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );

        expect(repository.commandCalls, hasLength(1));
        expect(repository.commandCalls.single.expectedRevision, 2);
        expect(
          repository.commandCalls.single.action,
          DoctorHomeOfferAction.accept,
        );
        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.acceptedHeld,
        );
        expect(controller.offers.single.quotedHomeFeeTnd, '75.000');
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.succeeded,
        );
        expect(controller.commandView?.message, contains('choix du Patient'));
        controller.dispose();
      },
    );

    test('accept preserves an explicit free-of-charge quote', () async {
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(_pending())
        ..acceptResults.add(
          _held(id: '11111111-1111-4111-8111-111111111111', fee: 0),
        );
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      await controller.activate();

      await controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.accept,
      );

      expect(controller.offers.single.quotedHomeFeeTnd, '0.000');
      controller.dispose();
    });

    test('decline adopts the terminal server state', () async {
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(_pending())
        ..declineResults.add(_terminal(DoctorHomeOfferStatus.declined));
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      await controller.activate();

      await controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.decline,
      );

      expect(
        repository.commandCalls.single.action,
        DoctorHomeOfferAction.decline,
      );
      expect(controller.offers.single.status, DoctorHomeOfferStatus.declined);
      expect(controller.canRespondTo(controller.offers.single), isFalse);
      controller.dispose();
    });

    test('double taps and accept-versus-decline races submit once', () async {
      final fresh = Completer<DoctorHomeOffer>();
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(fresh.future)
        ..acceptResults.add(_held(id: '11111111-1111-4111-8111-111111111111'));
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      await controller.activate();

      final accept = controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.accept,
      );
      final duplicate = controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.accept,
      );
      final competingDecline = controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.decline,
      );
      fresh.complete(_pending());
      await Future.wait([accept, duplicate, competingDecline]);

      expect(repository.commandCalls, hasLength(1));
      expect(
        repository.commandCalls.single.action,
        DoctorHomeOfferAction.accept,
      );
      controller.dispose();
    });

    test(
      'exact deadline, expired and unselected detail never submit a command',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(
            _pending(responseDeadlineAt: _now, evaluatedAt: _now),
          )
          ..detailResults.add(_terminal(DoctorHomeOfferStatus.expired))
          ..detailResults.add(_terminal(DoctorHomeOfferStatus.notSelected));
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );
        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );
        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );

        expect(repository.commandCalls, isEmpty);
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.failed,
        );
        controller.dispose();
      },
    );

    test(
      'stale revision reconciles and is never automatically retried',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending(revision: 1)])
          ..detailResults.add(_pending(revision: 2))
          ..detailResults.add(_pending(revision: 3))
          ..acceptResults.add(_problem(409, 'RESOURCE_STATE_CONFLICT'));
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );

        expect(repository.commandCalls, hasLength(1));
        expect(controller.offers.single.revision, 3);
        expect(controller.hasUnresolvedCommand, isFalse);
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.failed,
        );
        controller.dispose();
      },
    );

    for (final code in [
      'HOME_HOLD_BUDGET_FULL',
      'HOME_DOCTOR_CAPACITY_CONFLICT',
      'HOME_OFFER_ELIGIBILITY_CHANGED',
      'LOCATION_PRESENCE_UNAVAILABLE',
      'HOME_ROUTE_VERIFICATION_UNAVAILABLE',
      'HOME_OFFER_NOT_ACTIONABLE',
    ]) {
      test('$code reconciles without automatic command retry', () async {
        final status =
            code == 'LOCATION_PRESENCE_UNAVAILABLE' ||
                code == 'HOME_ROUTE_VERIFICATION_UNAVAILABLE'
            ? 503
            : 409;
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..detailResults.add(_pending())
          ..acceptResults.add(_problem(status, code));
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );

        expect(repository.commandCalls, hasLength(1));
        expect(controller.hasUnresolvedCommand, isFalse);
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.failed,
        );
        controller.dispose();
      });
    }

    test(
      'ambiguous timeout permits only an exact-key authorized retry',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..detailResults.add(_pending())
          ..acceptResults.add(
            DioException(
              requestOptions: RequestOptions(path: '/accept'),
              type: DioExceptionType.receiveTimeout,
            ),
          )
          ..acceptResults.add(
            _held(id: '11111111-1111-4111-8111-111111111111', replayed: true),
          );
        final controller = _controller(
          repository,
          idempotencyKeyFactory: () => 'stable-command-key',
        );
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.retryReady,
        );
        await controller.retryPendingCommand();

        expect(repository.commandCalls, hasLength(2));
        expect(
          repository.commandCalls.map((call) => call.idempotencyKey).toSet(),
          {'stable-command-key'},
        );
        expect(
          repository.commandCalls.map((call) => call.expectedRevision).toSet(),
          {2},
        );
        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.acceptedHeld,
        );
        expect(controller.commandView?.message, contains('déjà enregistrée'));
        controller.dispose();
      },
    );

    test(
      'idempotency conflict is reconciled before a fresh logical key',
      () async {
        final keys = ['conflicting-key', 'fresh-key'].iterator;
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..detailResults.add(_pending())
          ..detailResults.add(_pending())
          ..acceptResults.add(_problem(409, 'HOME_OFFER_IDEMPOTENCY_CONFLICT'))
          ..acceptResults.add(
            _held(id: '11111111-1111-4111-8111-111111111111'),
          );
        final controller = _controller(
          repository,
          idempotencyKeyFactory: () {
            keys.moveNext();
            return keys.current;
          },
        );
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );
        expect(controller.hasUnresolvedCommand, isFalse);
        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );

        expect(repository.commandCalls.map((call) => call.idempotencyKey), [
          'conflicting-key',
          'fresh-key',
        ]);
        controller.dispose();
      },
    );

    test(
      'server failure retains reconciliation without duplicate POST',
      () async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..detailResults.add(
            DioException(
              requestOptions: RequestOptions(path: '/detail'),
              type: DioExceptionType.connectionError,
            ),
          )
          ..detailResults.add(_held(id: '11111111-1111-4111-8111-111111111111'))
          ..acceptResults.add(_problem(503, 'SERVICE_UNAVAILABLE'));
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        await controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.reconcileRequired,
        );
        await controller.reconcilePendingCommand();

        expect(repository.commandCalls, hasLength(1));
        expect(
          controller.offers.single.status,
          DoctorHomeOfferStatus.acceptedHeld,
        );
        expect(
          controller.commandView?.phase,
          DoctorHomeOfferCommandPhase.succeeded,
        );
        controller.dispose();
      },
    );

    test(
      'account switch and logout fence a delayed command response',
      () async {
        final delayed = Completer<DoctorHomeOffer>();
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..acceptResults.add(delayed.future);
        final controller = _controller(repository);
        controller.attachDoctor('doctor-a', hasHomeCapability: true);
        await controller.activate();

        final command = controller.respond(
          controller.offers.single.offerId,
          DoctorHomeOfferAction.accept,
        );
        await Future<void>.delayed(Duration.zero);
        controller.attachDoctor('doctor-b', hasHomeCapability: true);
        controller.clear();
        delayed.complete(_held(id: '11111111-1111-4111-8111-111111111111'));
        await command;

        expect(controller.state, DoctorHomeOfferInboxState.detached);
        expect(controller.offers, isEmpty);
        expect(controller.commandView, isNull);
        controller.dispose();
      },
    );

    test('capability removal fences a delayed command response', () async {
      final delayed = Completer<DoctorHomeOffer>();
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(_pending())
        ..acceptResults.add(delayed.future);
      final controller = _controller(repository);
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      await controller.activate();

      final command = controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.accept,
      );
      await Future<void>.delayed(Duration.zero);
      controller.attachDoctor('doctor-a', hasHomeCapability: false);
      delayed.complete(_held(id: '11111111-1111-4111-8111-111111111111'));
      await command;

      expect(controller.state, DoctorHomeOfferInboxState.detached);
      expect(controller.offers, isEmpty);
      expect(controller.commandView, isNull);
      controller.dispose();
    });

    test('401 rejects the session and rollout 404 stays fail-closed', () async {
      var rejected = 0;
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(_pending())
        ..detailResults.add(_pending())
        ..acceptResults.add(_problem(401, 'UNAUTHORIZED'))
        ..acceptResults.add(_problem(404, 'URGENT_RUNTIME_UNAVAILABLE'));
      final controller = _controller(
        repository,
        onSessionRejected: () => rejected++,
      );
      controller.attachDoctor('doctor-a', hasHomeCapability: true);
      await controller.activate();

      await controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.accept,
      );
      expect(rejected, 1);
      await controller.respond(
        controller.offers.single.offerId,
        DoctorHomeOfferAction.accept,
      );

      expect(repository.commandCalls, hasLength(2));
      expect(controller.commandView?.phase, DoctorHomeOfferCommandPhase.failed);
      expect(controller.hasUnresolvedCommand, isFalse);
      controller.dispose();
    });
  });

  group('frozen HOME offer presentation', () {
    testWidgets(
      'renders grounded pending and accepted data with no Patient details',
      (tester) async {
        final repository = _OfferRepository()
          ..listResults.add([_pending(), _held()]);
        final controller = _controller(repository)
          ..attachDoctor('doctor-a', hasHomeCapability: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DoctorHomeOfferInboxSection(controller: controller),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Demande reçue'), findsOneWidget);
        expect(find.text('En attente du choix du patient'), findsWidgets);
        expect(find.text('25.000 TND'), findsOneWidget);
        expect(
          find.textContaining('Patient ne vous a pas encore sélectionné'),
          findsOneWidget,
        );
        expect(find.textContaining('Amina'), findsNothing);
        expect(find.textContaining('sympt'), findsNothing);
        expect(find.textContaining('adresse'), findsNothing);
        expect(find.text('Accepter'), findsNothing);
        expect(find.text('Décliner'), findsNothing);
        expect(find.text('Démarrer le trajet'), findsNothing);
        controller.dispose();
      },
    );

    testWidgets(
      'fresh detail exposes one-shot actions and acceptance stays provisional',
      (tester) async {
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..detailResults.add(_pending(revision: 3))
          ..acceptResults.add(
            _held(id: '11111111-1111-4111-8111-111111111111', fee: 75),
          );
        final controller = _controller(repository)
          ..attachDoctor('doctor-a', hasHomeCapability: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Scaffold(
              body: DoctorHomeOfferInboxSection(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Accepter'), findsNothing);
        await tester.tap(
          find.byKey(
            const ValueKey(
              'doctor-home-offer-detail-11111111-1111-4111-8111-111111111111',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Accepter'), findsOneWidget);
        expect(find.text('Décliner'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('doctor-home-offer-accept')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Le Patient doit encore vous sélectionner'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('doctor-home-offer-confirm-accept')),
        );
        await tester.pumpAndSettle();

        expect(repository.commandCalls, hasLength(1));
        expect(repository.commandCalls.single.expectedRevision, 3);
        expect(find.text('En attente du choix du patient'), findsWidgets);
        expect(find.text('75.000 TND'), findsWidgets);
        expect(
          find.textContaining('choix du Patient reste en attente'),
          findsOneWidget,
        );
        for (final unsupported in [
          'Démarrer le trajet',
          'Navigation',
          'Scanner le QR',
          'Dossier médical',
          'Démarrer la mission',
        ]) {
          expect(find.textContaining(unsupported), findsNothing);
        }
        controller.dispose();
      },
    );

    testWidgets('decline becomes terminal and removes response actions', (
      tester,
    ) async {
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(_pending())
        ..detailResults.add(_pending())
        ..declineResults.add(_terminal(DoctorHomeOfferStatus.declined));
      final controller = _controller(repository)
        ..attachDoctor('doctor-a', hasHomeCapability: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(
            body: DoctorHomeOfferInboxSection(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'doctor-home-offer-detail-11111111-1111-4111-8111-111111111111',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('doctor-home-offer-decline')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-home-offer-confirm-decline')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offre déclinée'), findsWidgets);
      expect(
        find.byKey(const ValueKey('doctor-home-offer-accept')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('doctor-home-offer-decline')),
        findsNothing,
      );
      controller.dispose();
    });

    testWidgets(
      'a concurrent Patient selection is informational and never starts a mission',
      (tester) async {
        var commitmentRefreshes = 0;
        final repository = _OfferRepository()
          ..listResults.add([_pending()])
          ..detailResults.add(_pending())
          ..detailResults.add(_pending())
          ..acceptResults.add(_committed());
        final controller = _controller(
          repository,
          onCommitmentMayHaveChanged: () => commitmentRefreshes++,
        )..attachDoctor('doctor-a', hasHomeCapability: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Scaffold(
              body: DoctorHomeOfferInboxSection(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const ValueKey(
              'doctor-home-offer-detail-11111111-1111-4111-8111-111111111111',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('doctor-home-offer-accept')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('doctor-home-offer-confirm-accept')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Médecin confirmé par le patient'), findsWidgets);
        expect(find.textContaining('mission, la destination'), findsOneWidget);
        expect(find.text('Démarrer le trajet'), findsNothing);
        expect(find.text('Démarrer la mission'), findsNothing);
        expect(commitmentRefreshes, 1);
        controller.dispose();
      },
    );

    testWidgets('a terminal fresh detail never exposes response actions', (
      tester,
    ) async {
      final repository = _OfferRepository()
        ..listResults.add([_pending()])
        ..detailResults.add(_terminal(DoctorHomeOfferStatus.expired));
      final controller = _controller(repository)
        ..attachDoctor('doctor-a', hasHomeCapability: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(
            body: DoctorHomeOfferInboxSection(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'doctor-home-offer-detail-11111111-1111-4111-8111-111111111111',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offre expirée'), findsWidgets);
      expect(
        find.byKey(const ValueKey('doctor-home-offer-accept')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('doctor-home-offer-decline')),
        findsNothing,
      );
      expect(repository.commandCalls, isEmpty);
      controller.dispose();
    });

    testWidgets('empty server inbox never falls back to demo offers', (
      tester,
    ) async {
      final repository = _OfferRepository()
        ..listResults.add(<DoctorHomeOffer>[]);
      final controller = _controller(repository)
        ..attachDoctor('doctor-a', hasHomeCapability: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(
            body: DoctorHomeOfferInboxSection(controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Aucune offre HOME en cours'), findsOneWidget);
      expect(find.textContaining('OMN-2026'), findsNothing);
      expect(find.textContaining('Douleur thoracique'), findsNothing);
      controller.dispose();
    });

    testWidgets(
      'dual-mode Urgences keeps one selector and mounts inbox only in HOME',
      (tester) async {
        final repository = _OfferRepository()
          ..listResults.add(<DoctorHomeOffer>[]);
        final offers = _controller(repository)
          ..attachDoctor('doctor-a', hasHomeCapability: true);
        final cabinet = DoctorUrgentCabinetController(
          developmentSimulationEnabled: false,
        );
        var mode = DoctorUrgentMode.home;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => DoctorUrgentWorkspaceScreen(
                  capabilities: const {
                    DoctorCapability.urgentHomeRequests,
                    DoctorCapability.urgentCabinetRequests,
                  },
                  workspaceConfig: null,
                  selectedMode: mode,
                  onModeChanged: (value) => setState(() => mode = value),
                  homeController: DoctorUrgentController(),
                  urgentCabinetController: cabinet,
                  homeOperationalMessage:
                      'Les commandes HOME restent désactivées.',
                  cabinetOperationalMessage:
                      'Les commandes CABINET restent désactivées.',
                  homeOfferController: offers,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey('doctor-urgent-mode-selector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('doctor-home-offer-inbox')),
          findsOneWidget,
        );
        expect(find.text('Aucune offre HOME en cours'), findsOneWidget);

        await tester.tap(find.text('Au cabinet'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('doctor-home-offer-inbox')),
          findsNothing,
        );
        expect(find.text('Urgences au cabinet'), findsOneWidget);
        offers.dispose();
        cabinet.dispose();
      },
    );

    test(
      'offer package contains only scoped response commands and no private data',
      () {
        const paths = [
          'lib/features/doctor/urgent/doctor_home_offer.dart',
          'lib/features/doctor/urgent/doctor_home_offer_repository.dart',
          'lib/features/doctor/urgent/doctor_home_offer_inbox_controller.dart',
          'lib/features/doctor/urgent/doctor_home_offer_inbox_section.dart',
        ];
        final source = paths
            .map((path) => File(path).readAsStringSync())
            .join('\n');
        for (final forbidden in [
          '/withdraw',
          'SharedPreferences',
          'SecureTokenStore',
          'debugPrint',
          'print(',
          'patientName',
          'symptoms',
          'latitude',
          'longitude',
          'WebSocket',
          'FirebaseMessaging',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: forbidden);
        }
      },
    );
  });
}
