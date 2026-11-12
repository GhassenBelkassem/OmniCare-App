import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/utils/uuid_v4.dart';
import '../data/pending_answers_api.dart';
import '../data/pending_answers_models.dart';
import 'pending_answer_problem.dart';

/// State of one card in « En attente de votre réponse ».
enum PendingCardState { pending, accepted, refused, notActive }

/// One card: the item as last known, and how it ended (if it did).
class PendingEntry<T> {
  const PendingEntry(this.item, this.state);

  final T item;
  final PendingCardState state;
}

/// G-1 D2 / D4: the patient's pending access requests and follow-up
/// proposals, shared by « Mes rendez-vous » and the access-request window.
///
/// Memory only (no disk cache), nothing logged. One Idempotency-Key per tap,
/// reused while the same command is retried after an ambiguous failure.
class PendingAnswersController extends ChangeNotifier {
  PendingAnswersController(
    this._api, {
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) : _newKey = idempotencyKeyFactory;

  final PendingAnswersApiContract _api;
  final String Function() _newKey;

  List<PendingEntry<PatientAccessRequest>> _accessRequests = const [];
  List<PendingEntry<FollowUpProposal>> _proposals = const [];
  final Set<String> _busy = <String>{};
  final Map<String, PendingAnswerProblem> _problems = {};
  final Map<String, ({String signature, String key})> _commands = {};
  final Set<String> _offeredThisSession = <String>{};
  bool _loading = false;
  bool _loaded = false;
  bool _loadFailed = false;
  int _generation = 0;
  Future<void>? _inFlightRefresh;
  String? _focusProposalId;
  String? _info;
  bool _windowOpen = false;

  List<PendingEntry<PatientAccessRequest>> get accessRequests =>
      _accessRequests;
  List<PendingEntry<FollowUpProposal>> get proposals => _proposals;
  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;

  /// The last load of at least one list failed (« Tirez pour actualiser »).
  bool get loadFailed => _loadFailed;
  bool get isEmpty => _accessRequests.isEmpty && _proposals.isEmpty;
  bool isBusy(String id) => _busy.contains(id);
  PendingAnswerProblem? problemOf(String id) => _problems[id];
  String? get focusProposalId => _focusProposalId;
  String? get info => _info;

  /// Loads both lists. [keepAnswered] keeps the cards answered in this view
  /// (« Demande refusée. ») until the screen is opened again.
  Future<void> refresh({bool keepAnswered = true}) {
    final running = _inFlightRefresh;
    if (running != null) return running;
    final future = _refresh(keepAnswered).whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  Future<void> _refresh(bool keepAnswered) async {
    final generation = _generation;
    _loading = true;
    notifyListeners();
    List<PatientAccessRequest>? requests;
    List<FollowUpProposal>? proposals;
    await Future.wait([
      _api.accessRequests().then((value) => requests = value).catchError((_) {
        return const <PatientAccessRequest>[];
      }),
      _api.followUpProposals().then((value) => proposals = value).catchError((
        _,
      ) {
        return const <FollowUpProposal>[];
      }),
    ]);
    if (generation != _generation) return;
    if (requests != null) {
      _accessRequests = _merge(
        _accessRequests,
        requests!.where((item) => item.isPending),
        (item) => item.requestId,
        keepAnswered,
      );
    }
    if (proposals != null) {
      _proposals = _merge(
        _proposals,
        proposals!.where((item) => item.isPending),
        (item) => item.appointmentId,
        keepAnswered,
      );
    }
    _loading = false;
    _loaded = true;
    _loadFailed = requests == null || proposals == null;
    notifyListeners();
  }

  /// Server items are the truth; answered cards stay only when [keepAnswered].
  static List<PendingEntry<T>> _merge<T>(
    List<PendingEntry<T>> current,
    Iterable<T> fresh,
    String Function(T) idOf,
    bool keepAnswered,
  ) {
    final freshById = {for (final item in fresh) idOf(item): item};
    final result = <PendingEntry<T>>[];
    final seen = <String>{};
    for (final entry in current) {
      final id = idOf(entry.item);
      final next = freshById[id];
      if (next != null) {
        result.add(PendingEntry(next, PendingCardState.pending));
        seen.add(id);
      } else if (keepAnswered && entry.state != PendingCardState.pending) {
        result.add(entry);
      }
    }
    for (final item in fresh) {
      if (!seen.contains(idOf(item))) {
        result.add(PendingEntry(item, PendingCardState.pending));
      }
    }
    return List.unmodifiable(result);
  }

  PatientAccessRequest? accessRequestById(String id) {
    for (final entry in _accessRequests) {
      if (entry.item.requestId == id) return entry.item;
    }
    return null;
  }

  PendingCardState? accessRequestState(String id) {
    for (final entry in _accessRequests) {
      if (entry.item.requestId == id) return entry.state;
    }
    return null;
  }

  Future<void> answerAccessRequest(String requestId, {required bool accept}) =>
      _answer(
        id: requestId,
        kind: 'access',
        accept: accept,
        version: () => _pendingAccess(requestId)?.version,
        call: (version, key) => _api.answerAccessRequest(
          requestId,
          accept: accept,
          expectedVersion: version,
          idempotencyKey: key,
        ),
        apply: (state) => _accessRequests = _withState(
          _accessRequests,
          (item) => item.requestId == requestId,
          state,
        ),
      );

  Future<void> answerFollowUpProposal(
    String appointmentId, {
    required bool accept,
  }) => _answer(
    id: appointmentId,
    kind: 'follow-up',
    accept: accept,
    version: () => _pendingProposal(appointmentId)?.version,
    call: (version, key) => _api.answerFollowUpProposal(
      appointmentId,
      accept: accept,
      expectedVersion: version,
      idempotencyKey: key,
    ),
    apply: (state) => _proposals = _withState(
      _proposals,
      (item) => item.appointmentId == appointmentId,
      state,
    ),
  );

  Future<void> _answer({
    required String id,
    required String kind,
    required bool accept,
    required int? Function() version,
    required Future<Object> Function(int version, String key) call,
    required void Function(PendingCardState state) apply,
  }) async {
    final expected = version();
    if (expected == null || _busy.contains(id)) return;
    final signature = '$kind:$id:${accept ? 'accept' : 'refuse'}:$expected';
    final command = _commands[id];
    final key = command != null && command.signature == signature
        ? command.key
        : _newKey();
    _commands[id] = (signature: signature, key: key);
    _busy.add(id);
    _problems.remove(id);
    notifyListeners();
    try {
      await call(expected, key);
      _commands.remove(id);
      apply(accept ? PendingCardState.accepted : PendingCardState.refused);
    } catch (error) {
      final failure = ApiFailure.from(error);
      if (!isAmbiguousFailure(failure)) _commands.remove(id);
      final problem = pendingAnswerProblemOf(failure);
      switch (problem) {
        case PendingAnswerProblem.versionConflict:
          _busy.remove(id);
          await refresh();
          return;
        case PendingAnswerProblem.notActive:
          apply(PendingCardState.notActive);
        default:
          _problems[id] = problem;
      }
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  PatientAccessRequest? _pendingAccess(String id) {
    for (final entry in _accessRequests) {
      if (entry.item.requestId == id &&
          entry.state == PendingCardState.pending) {
        return entry.item;
      }
    }
    return null;
  }

  FollowUpProposal? _pendingProposal(String id) {
    for (final entry in _proposals) {
      if (entry.item.appointmentId == id &&
          entry.state == PendingCardState.pending) {
        return entry.item;
      }
    }
    return null;
  }

  static List<PendingEntry<T>> _withState<T>(
    List<PendingEntry<T>> entries,
    bool Function(T) matches,
    PendingCardState state,
  ) => List.unmodifiable([
    for (final entry in entries)
      matches(entry.item) ? PendingEntry(entry.item, state) : entry,
  ]);

  /// Access-request window: the newest pending request not yet shown in this
  /// app session (marked as shown), or null.
  PatientAccessRequest? takeWindowCandidate() {
    if (_windowOpen) return null;
    final pending = [
      for (final entry in _accessRequests)
        if (entry.state == PendingCardState.pending &&
            !_offeredThisSession.contains(entry.item.requestId))
          entry.item,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (pending.isEmpty) return null;
    _offeredThisSession.add(pending.first.requestId);
    return pending.first;
  }

  /// A push opened this request: show it even if it was shown before.
  void markOffered(String requestId) => _offeredThisSession.add(requestId);

  /// Push deep link: reads one request by id (any status) and keeps it when
  /// it is still pending. Throws the API failure.
  Future<PatientAccessRequest> readAccessRequest(String requestId) async {
    final request = await _api.accessRequest(requestId);
    upsertAccessRequest(request);
    return request;
  }

  /// Adds (or refreshes) one request read by id (push deep link).
  void upsertAccessRequest(PatientAccessRequest request) {
    if (!request.isPending) return;
    final exists = _accessRequests.any(
      (entry) => entry.item.requestId == request.requestId,
    );
    _accessRequests = List.unmodifiable([
      if (!exists) PendingEntry(request, PendingCardState.pending),
      for (final entry in _accessRequests)
        entry.item.requestId == request.requestId
            ? PendingEntry(request, PendingCardState.pending)
            : entry,
    ]);
    notifyListeners();
  }

  bool get isWindowOpen => _windowOpen;
  set windowOpen(bool value) => _windowOpen = value;

  /// « Mes rendez-vous » opened from a push: scroll to this proposal.
  void focusProposal(String appointmentId) {
    _focusProposalId = appointmentId;
    notifyListeners();
  }

  void clearFocus() => _focusProposalId = null;

  /// One info message shown by « Mes rendez-vous » when it opens.
  void showInfo(String message) {
    _info = message;
    notifyListeners();
  }

  String? takeInfo() {
    final value = _info;
    _info = null;
    return value;
  }

  /// Logout / account switch: nothing survives the session.
  void clear() {
    _generation++;
    _accessRequests = const [];
    _proposals = const [];
    _busy.clear();
    _problems.clear();
    _commands.clear();
    _offeredThisSession.clear();
    _loading = false;
    _loaded = false;
    _loadFailed = false;
    _inFlightRefresh = null;
    _focusProposalId = null;
    _info = null;
    _windowOpen = false;
    notifyListeners();
  }
}
