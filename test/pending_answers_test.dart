// G-1 D2 / D4 (patient side): access requests and follow-up proposals.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/auth/application/auth_role_family.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_navigation_resolver.dart';
import 'package:omnicare_mobile/features/notifications/presentation/notification_badge.dart';
import 'package:omnicare_mobile/features/pending_answers/application/pending_answer_problem.dart';
import 'package:omnicare_mobile/features/pending_answers/application/pending_answers_controller.dart';
import 'package:omnicare_mobile/features/pending_answers/data/pending_answers_api.dart';
import 'package:omnicare_mobile/features/pending_answers/data/pending_answers_models.dart';
import 'package:omnicare_mobile/features/pending_answers/presentation/pending_answers_entry.dart';
import 'package:omnicare_mobile/features/pending_answers/presentation/pending_answers_format.dart';
import 'package:omnicare_mobile/features/pending_answers/presentation/pending_answers_section.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_scheduled_care_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/patient_scheduled_care_models.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';
const _otherRequestId = '22222222-2222-4222-8222-222222222222';
const _proposalId = '33333333-3333-4333-8333-333333333333';

PatientAccessRequest _request({
  String id = _requestId,
  int version = 3,
  String status = 'PENDING',
  DateTime? createdAt,
  bool family = false,
}) => PatientAccessRequest(
  requestId: id,
  version: version,
  status: status,
  consultationId: 'consultation-1',
  createdAt: createdAt ?? DateTime.utc(2025, 11, 13, 8),
  subject: PendingAnswerSubject(
    isSelf: !family,
    displayName: family ? 'Yasmine Amri' : 'Sami Amri',
  ),
  doctor: const PendingAnswerDoctor(
    displayName: 'Karim Ben Salah',
    specialty: 'Cardiologie',
  ),
);

FollowUpProposal _proposal({String status = 'PROPOSED', int version = 5}) =>
    FollowUpProposal(
      appointmentId: _proposalId,
      version: version,
      status: status,
      start: DateTime.utc(2025, 11, 13, 9, 20),
      proposalExpiresAt: DateTime.utc(2025, 11, 12, 17),
      cabinet: const FollowUpCabinet(
        name: 'Cabinet El Menzah',
        address: '12 rue des Jasmins',
        city: 'Tunis',
      ),
      subject: const PendingAnswerSubject(isSelf: true, displayName: 'Sami'),
      doctor: const PendingAnswerDoctor(
        displayName: 'Karim Ben Salah',
        specialty: 'Cardiologie',
      ),
    );

class _Call {
  _Call(this.id, this.accept, this.version, this.key);
  final String id;
  final bool accept;
  final int version;
  final String key;
}

class _FakeApi implements PendingAnswersApiContract {
  List<PatientAccessRequest> requests = [];
  List<FollowUpProposal> proposals = [];
  int requestListCalls = 0;
  final accessCalls = <_Call>[];
  final proposalCalls = <_Call>[];
  Future<void> Function()? gate;
  Object? Function(_Call call)? accessFailure;
  Object? Function(_Call call)? proposalFailure;
  PatientAccessRequest? byId;
  Object? byIdFailure;

  Object? listFailure;

  @override
  Future<List<PatientAccessRequest>> accessRequests() async {
    requestListCalls++;
    if (listFailure != null) throw listFailure!;
    return requests;
  }

  @override
  Future<PatientAccessRequest> accessRequest(String requestId) async {
    if (byIdFailure != null) throw byIdFailure!;
    return byId ?? requests.firstWhere((item) => item.requestId == requestId);
  }

  @override
  Future<PatientAccessRequest> answerAccessRequest(
    String requestId, {
    required bool accept,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final call = _Call(requestId, accept, expectedVersion, idempotencyKey);
    accessCalls.add(call);
    await gate?.call();
    final failure = accessFailure?.call(call);
    if (failure != null) throw failure;
    requests = requests.where((item) => item.requestId != requestId).toList();
    return _request(id: requestId, status: accept ? 'ACCEPTED' : 'REFUSED');
  }

  @override
  Future<List<FollowUpProposal>> followUpProposals() async => proposals;

  @override
  Future<FollowUpProposal> answerFollowUpProposal(
    String appointmentId, {
    required bool accept,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final call = _Call(appointmentId, accept, expectedVersion, idempotencyKey);
    proposalCalls.add(call);
    await gate?.call();
    final failure = proposalFailure?.call(call);
    if (failure != null) throw failure;
    proposals = [];
    return _proposal(status: accept ? 'CONFIRMED' : 'CANCELLED');
  }
}

PendingAnswersController _controller(_FakeApi api) {
  var next = 0;
  return PendingAnswersController(
    api,
    idempotencyKeyFactory: () => 'key-${++next}',
  );
}

ApiFailure _conflict(String code) =>
    ApiFailure(kind: ApiFailureKind.conflict, code: code, statusCode: 409);

const _network = ApiFailure(kind: ApiFailureKind.network);
const _unavailable = ApiFailure(
  kind: ApiFailureKind.server,
  code: 'MRS_UNAVAILABLE',
  statusCode: 503,
);

Widget _app(
  PendingAnswersController controller, {
  Widget? child,
  GlobalKey<NavigatorState>? navigatorKey,
  Future<void> Function()? onProposalConfirmed,
}) => ChangeNotifierProvider<PendingAnswersController>.value(
  value: controller,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    theme: buildOmniTheme(),
    localizationsDelegates: OmniLocalizations.localizationsDelegates,
    supportedLocales: OmniLocalizations.supportedLocales,
    home: Scaffold(
      body:
          child ??
          Column(
            children: [
              PendingAnswersSection(onProposalConfirmed: onProposalConfirmed),
            ],
          ),
    ),
  ),
);

void main() {
  group('error mapping', () {
    test('codes and statuses map to the patient-facing problem', () {
      expect(
        pendingAnswerProblemOf(_conflict('VERSION_CONFLICT')),
        PendingAnswerProblem.versionConflict,
      );
      for (final code in [
        'ACCESS_REQUEST_NOT_PENDING',
        'FOLLOW_UP_PROPOSAL_NOT_PENDING',
        'FOLLOW_UP_PROPOSAL_EXPIRED',
      ]) {
        expect(
          pendingAnswerProblemOf(_conflict(code)),
          PendingAnswerProblem.notActive,
        );
      }
      expect(
        pendingAnswerProblemOf(
          const ApiFailure(
            kind: ApiFailureKind.notFound,
            code: 'ACCESS_REQUEST_NOT_FOUND',
            statusCode: 404,
          ),
        ),
        PendingAnswerProblem.notActive,
      );
      expect(
        pendingAnswerProblemOf(_unavailable),
        PendingAnswerProblem.unavailable,
      );
      expect(
        pendingAnswerProblemOf(
          const ApiFailure(kind: ApiFailureKind.server, statusCode: 503),
        ),
        PendingAnswerProblem.unavailable,
      );
      expect(pendingAnswerProblemOf(_network), PendingAnswerProblem.network);
      expect(
        pendingAnswerProblemOf(const ApiFailure(kind: ApiFailureKind.timeout)),
        PendingAnswerProblem.network,
      );
      expect(
        pendingAnswerProblemOf(_conflict('IDEMPOTENCY_KEY_REUSED')),
        PendingAnswerProblem.other,
      );
      expect(isAmbiguousFailure(_network), isTrue);
      expect(isAmbiguousFailure(_unavailable), isTrue);
      expect(
        isAmbiguousFailure(_conflict('ACCESS_REQUEST_NOT_PENDING')),
        isFalse,
      );
    });

    test('French date in Africa/Tunis', () {
      expect(
        formatTunisDayTime(DateTime.utc(2025, 11, 13, 9, 20)),
        'jeu. 13 nov. à 10:20',
      );
    });
  });

  group('controller', () {
    test(
      'one key per tap, the same key on retry, expectedVersion sent',
      () async {
        final api = _FakeApi()..requests = [_request()];
        final controller = _controller(api);
        await controller.refresh();

        api.accessFailure = (_) => _network;
        await controller.answerAccessRequest(_requestId, accept: true);
        expect(controller.problemOf(_requestId), PendingAnswerProblem.network);
        api.accessFailure = null;
        await controller.answerAccessRequest(_requestId, accept: true);

        expect(api.accessCalls.map((call) => call.key), ['key-1', 'key-1']);
        expect(api.accessCalls.map((call) => call.version), [3, 3]);
        expect(
          controller.accessRequestState(_requestId),
          PendingCardState.accepted,
        );
        expect(controller.problemOf(_requestId), isNull);
      },
    );

    test('a definitive answer or another command gets a new key', () async {
      final api = _FakeApi()..proposals = [_proposal()];
      final controller = _controller(api);
      await controller.refresh();

      api.proposalFailure = (_) => _unavailable;
      await controller.answerFollowUpProposal(_proposalId, accept: true);
      await controller.answerFollowUpProposal(_proposalId, accept: false);
      api.proposalFailure = (_) => _conflict('FOLLOW_UP_PROPOSAL_EXPIRED');
      await controller.answerFollowUpProposal(_proposalId, accept: false);

      expect(api.proposalCalls.map((call) => call.key), [
        'key-1',
        'key-2',
        'key-2',
      ]);
      expect(controller.proposals.single.state, PendingCardState.notActive);
    });

    test(
      'VERSION_CONFLICT reloads silently and shows the fresh state',
      () async {
        final api = _FakeApi()..requests = [_request(version: 3)];
        final controller = _controller(api);
        await controller.refresh();
        api.accessFailure = (_) => _conflict('VERSION_CONFLICT');
        api.requests = [_request(version: 4)];

        await controller.answerAccessRequest(_requestId, accept: false);

        expect(api.requestListCalls, 2);
        expect(controller.problemOf(_requestId), isNull);
        expect(controller.accessRequests.single.item.version, 4);
        expect(
          controller.accessRequestState(_requestId),
          PendingCardState.pending,
        );
      },
    );

    test('the window offers the newest request once per session', () async {
      final api = _FakeApi()
        ..requests = [
          _request(createdAt: DateTime.utc(2025, 11, 13, 8)),
          _request(
            id: _otherRequestId,
            createdAt: DateTime.utc(2025, 11, 13, 9),
          ),
        ];
      final controller = _controller(api);
      await controller.refresh();

      expect(controller.takeWindowCandidate()?.requestId, _otherRequestId);
      expect(controller.takeWindowCandidate()?.requestId, _requestId);
      expect(controller.takeWindowCandidate(), isNull);
      controller.clear();
      await controller.refresh();
      expect(controller.takeWindowCandidate()?.requestId, _otherRequestId);
    });
  });

  group('section in « Mes rendez-vous »', () {
    testWidgets('hidden when nothing is pending', (tester) async {
      final controller = _controller(_FakeApi());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      expect(find.text('En attente de votre réponse'), findsNothing);
      expect(
        find.byKey(const ValueKey('pending-answers-hidden')),
        findsOneWidget,
      );
    });

    testWidgets('a failed load shows one line; pulling down reloads', (
      tester,
    ) async {
      final api = _FakeApi()..listFailure = _network;
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      expect(find.text('En attente de votre réponse'), findsOneWidget);
      expect(
        find.text('Impossible de charger vos demandes. Tirez pour actualiser.'),
        findsOneWidget,
      );

      api
        ..listFailure = null
        ..requests = [_request()];
      await tester.fling(
        find.byKey(const ValueKey('pending-answers-section')),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible de charger vos demandes. Tirez pour actualiser.'),
        findsNothing,
      );
      expect(find.text('Demande d’accès à votre dossier'), findsOneWidget);

      // Loaded and empty: hidden again.
      api.requests = [];
      await controller.refresh(keepAnswered: false);
      await tester.pumpAndSettle();
      expect(find.text('En attente de votre réponse'), findsNothing);
    });

    testWidgets('access request: pending, confirm dialog, accepted', (
      tester,
    ) async {
      final api = _FakeApi()..requests = [_request()];
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.text('En attente de votre réponse'), findsOneWidget);
      expect(find.text('Demande d’accès à votre dossier'), findsOneWidget);
      expect(find.text('Dr Karim Ben Salah · Cardiologie'), findsOneWidget);
      expect(find.text('Pour vous'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('access-request-accept-$_requestId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Autoriser l’accès ?'), findsOneWidget);
      expect(
        find.text(
          'Dr Karim Ben Salah pourra consulter votre dossier médical pendant cette '
          'consultation. L’accès prend fin à la fin de la consultation.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(api.accessCalls, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('access-request-accept-$_requestId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('access-request-confirm')));
      await tester.pumpAndSettle();
      expect(api.accessCalls.single.accept, isTrue);
      expect(find.text('Accès autorisé.'), findsOneWidget);
    });

    testWidgets('access request: refuse needs no confirmation', (tester) async {
      final api = _FakeApi()..requests = [_request(family: true)];
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      expect(find.text('Pour Yasmine Amri'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.accessCalls.single.accept, isFalse);
      expect(find.text('Demande refusée.'), findsOneWidget);
    });

    testWidgets('access request: loading disables both buttons', (
      tester,
    ) async {
      final release = Completer<void>();
      final api = _FakeApi()
        ..requests = [_request()]
        ..gate = (() => release.future);
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('pending-card-busy')), findsOneWidget);
      final refuse = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
      );
      final accept = tester.widget<FilledButton>(
        find.byKey(const ValueKey('access-request-accept-$_requestId')),
      );
      expect(refuse.onPressed, isNull);
      expect(accept.onPressed, isNull);
      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Demande refusée.'), findsOneWidget);
    });

    testWidgets('access request: not active and error states', (tester) async {
      final api = _FakeApi()..requests = [_request()];
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      api.accessFailure = (_) => _unavailable;
      await tester.tap(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Service momentanément indisponible. Réessayez dans un instant.',
        ),
        findsOneWidget,
      );

      api.accessFailure = (_) => _network;
      await tester.tap(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
      );
      await tester.pumpAndSettle();
      final l10n = OmniLocalizations.of(
        tester.element(find.byType(PendingAnswersSection)),
      );
      expect(find.text(l10n.apiErrorNetwork), findsOneWidget);

      api.accessFailure = (_) => _conflict('ACCESS_REQUEST_NOT_PENDING');
      await tester.tap(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cette demande n’est plus active.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('access-request-refuse-$_requestId')),
        findsNothing,
      );
    });

    testWidgets(
      'follow-up: pending details, confirm, shows under « À venir »',
      (tester) async {
        var listRefreshed = 0;
        final api = _FakeApi()..proposals = [_proposal()];
        final controller = _controller(api);
        await tester.pumpWidget(
          _app(controller, onProposalConfirmed: () async => listRefreshed++),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rendez-vous de contrôle proposé'), findsOneWidget);
        expect(find.text('jeu. 13 nov. à 10:20'), findsOneWidget);
        expect(
          find.text('Cabinet El Menzah · 12 rue des Jasmins, Tunis'),
          findsOneWidget,
        );
        expect(
          find.text('À confirmer avant mer. 12 nov. à 18:00'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('follow-up-confirm-$_proposalId')),
        );
        await tester.pumpAndSettle();
        expect(api.proposalCalls.single.accept, isTrue);
        expect(api.proposalCalls.single.version, 5);
        expect(
          find.text('Rendez-vous confirmé. Il apparaît dans « À venir ».'),
          findsOneWidget,
        );
        expect(listRefreshed, 1);
      },
    );

    testWidgets('follow-up: refuse asks first, then refused', (tester) async {
      final api = _FakeApi()..proposals = [_proposal()];
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('follow-up-decline-$_proposalId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Refuser ce rendez-vous ?'), findsOneWidget);
      expect(find.text('Le créneau sera libéré.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('follow-up-decline-confirm')));
      await tester.pumpAndSettle();
      expect(api.proposalCalls.single.accept, isFalse);
      expect(find.text('Rendez-vous refusé.'), findsOneWidget);
    });

    testWidgets('follow-up: loading, error and not active', (tester) async {
      final release = Completer<void>();
      final api = _FakeApi()
        ..proposals = [_proposal()]
        ..gate = (() => release.future)
        ..proposalFailure = ((_) => _unavailable);
      final controller = _controller(api);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('follow-up-confirm-$_proposalId')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('pending-card-busy')), findsOneWidget);
      release.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Service momentanément indisponible. Réessayez dans un instant.',
        ),
        findsOneWidget,
      );

      api
        ..gate = null
        ..proposalFailure = ((_) => _conflict('FOLLOW_UP_PROPOSAL_EXPIRED'));
      await tester.tap(
        find.byKey(const ValueKey('follow-up-confirm-$_proposalId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cette demande n’est plus active.'), findsOneWidget);
    });
  });

  group('access-request window', () {
    Future<(GlobalKey<NavigatorState>, PendingAnswersController, _FakeApi)>
    pump(WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final api = _FakeApi()..requests = [_request()];
      final controller = _controller(api);
      await tester.pumpWidget(
        _app(controller, navigatorKey: navigatorKey, child: const SizedBox()),
      );
      return (navigatorKey, controller, api);
    }

    testWidgets('shown once per session; closing keeps the request pending', (
      tester,
    ) async {
      final (navigatorKey, controller, api) = await pump(tester);
      unawaited(
        PendingAnswersEntry.offerAccessRequestWindow(
          navigatorKey.currentState!,
          controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Votre médecin demande l’accès à votre dossier'),
        findsOneWidget,
      );
      expect(find.text('Dr Karim Ben Salah · Cardiologie'), findsOneWidget);
      expect(find.text('Pour vous'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('access-request-window-close')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('access-request-window')), findsNothing);
      expect(
        controller.accessRequestState(_requestId),
        PendingCardState.pending,
      );
      expect(api.accessCalls, isEmpty);

      unawaited(
        PendingAnswersEntry.offerAccessRequestWindow(
          navigatorKey.currentState!,
          controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('access-request-window')), findsNothing);
    });

    testWidgets('« Autoriser » answers directly, no second confirmation', (
      tester,
    ) async {
      final (navigatorKey, controller, api) = await pump(tester);
      unawaited(
        PendingAnswersEntry.offerAccessRequestWindow(
          navigatorKey.currentState!,
          controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('access-request-window-accept')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.accessCalls.single.accept, isTrue);
      expect(find.byKey(const ValueKey('access-request-window')), findsNothing);
      expect(find.text('Accès autorisé.'), findsOneWidget);
    });

    testWidgets('« Refuser » refuses and says so', (tester) async {
      final (navigatorKey, controller, api) = await pump(tester);
      unawaited(
        PendingAnswersEntry.offerAccessRequestWindow(
          navigatorKey.currentState!,
          controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('access-request-window-refuse')),
      );
      await tester.pumpAndSettle();
      expect(api.accessCalls.single.accept, isFalse);
      expect(find.text('Demande refusée.'), findsOneWidget);
    });

    testWidgets(
      'a push for an answered request opens « Mes rendez-vous » saying so',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final api = _FakeApi()..byId = _request(status: 'ACCEPTED');
        final controller = _controller(api);
        final list = PatientScheduledCareController(repository: _EmptyList());
        await tester.pumpWidget(
          ChangeNotifierProvider<PatientScheduledCareController>.value(
            value: list,
            child: _app(
              controller,
              navigatorKey: navigatorKey,
              child: const SizedBox(),
            ),
          ),
        );
        unawaited(
          PendingAnswersEntry.openAccessRequest(
            navigatorKey.currentState!,
            controller,
            _requestId,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('access-request-window')),
          findsNothing,
        );
        expect(find.text('Mes rendez-vous'), findsOneWidget);
        expect(find.text('Cette demande n’est plus active.'), findsOneWidget);
      },
    );
  });

  group('push routing', () {
    PendingNotificationOpenIdentity? parse(
      String type,
      String key,
      String id,
    ) => NotificationNavigationResolver.parsePendingPayload({
      'type': type,
      key: id,
    });

    test('the three push types route to their patient destinations', () {
      final cases = {
        'ACCESS_REQUESTED': (
          'request_id',
          NotificationNavigationResource.accessRequest,
        ),
        'FOLLOW_UP_PROPOSED': (
          'appointment_id',
          NotificationNavigationResource.followUpProposal,
        ),
        'FOLLOW_UP_WITHDRAWN': (
          'appointment_id',
          NotificationNavigationResource.followUpWithdrawn,
        ),
      };
      cases.forEach((type, value) {
        final identity = parse(type, value.$1, _requestId);
        expect(identity, isNotNull, reason: type);
        final resolution = NotificationNavigationResolver.resolvePending(
          identity!,
          AuthRoleFamily.patient,
          accountScope: 'patient-1',
        );
        expect(resolution.status, NotificationNavigationStatus.target);
        expect(resolution.resource, value.$2);
        expect(resolution.resourceId, _requestId);
        expect(isPendingAnswerResource(resolution.resource), isTrue);
        // A doctor never gets a destination for these.
        expect(
          NotificationNavigationResolver.resolvePending(
            identity,
            AuthRoleFamily.doctor,
            accountScope: 'patient-1',
          ).status,
          NotificationNavigationStatus.noDestination,
        );
      });
      // The id is the only thing read from the payload.
      expect(parse('ACCESS_REQUESTED', 'request_id', 'not-a-uuid'), isNull);
    });

    testWidgets(
      'FOLLOW_UP_PROPOSED focuses the proposal; WITHDRAWN shows the info',
      (tester) async {
        final api = _FakeApi()..proposals = [_proposal()];
        final controller = _controller(api);
        controller.focusProposal(_proposalId);
        await tester.pumpWidget(_app(controller));
        await tester.pumpAndSettle();
        final card = tester.widget<Container>(
          find.byKey(const ValueKey('follow-up-card-$_proposalId')),
        );
        final border = (card.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, OmniColors.freshMint);
        expect(controller.focusProposalId, isNull);

        controller.showInfo(followUpWithdrawnMessage);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Un rendez-vous de contrôle proposé a été annulé par le cabinet.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a focused proposal that is gone says it is no longer active', (
      tester,
    ) async {
      final controller = _controller(_FakeApi());
      controller.focusProposal(_proposalId);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      expect(find.text('Cette demande n’est plus active.'), findsOneWidget);
    });
  });

  group('bell', () {
    testWidgets('red badge only when there are unread notifications', (
      tester,
    ) async {
      Future<void> pumpBadge(int count) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBadge(count: count, onTap: () {}),
          ),
        ),
      );
      await pumpBadge(0);
      expect(
        find.byKey(const ValueKey('notification-badge-count')),
        findsNothing,
      );
      await pumpBadge(3);
      expect(
        find.byKey(const ValueKey('notification-badge-count')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    });
  });
}

class _EmptyList implements PatientScheduledCareRepositoryContract {
  @override
  Future<PatientScheduledCarePage> getPatientScheduledCare(
    PatientScheduledCareQuery query, {
    CancelToken? cancelToken,
  }) async => const PatientScheduledCarePage(items: []);
}
