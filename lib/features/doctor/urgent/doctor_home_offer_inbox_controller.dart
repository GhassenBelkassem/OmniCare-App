import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/uuid_v4.dart';
import 'doctor_home_offer.dart';
import 'doctor_home_offer_repository.dart';

enum DoctorHomeOfferInboxState {
  detached,
  initial,
  loading,
  ready,
  empty,
  unavailable,
  failure,
}

sealed class DoctorHomeOfferDetailResult {
  const DoctorHomeOfferDetailResult();
}

final class DoctorHomeOfferDetailLoaded extends DoctorHomeOfferDetailResult {
  const DoctorHomeOfferDetailLoaded(this.offer);

  final DoctorHomeOffer offer;
}

final class DoctorHomeOfferDetailUnavailable
    extends DoctorHomeOfferDetailResult {
  const DoctorHomeOfferDetailUnavailable(this.message);

  final String message;
}

enum DoctorHomeOfferCommandPhase {
  verifying,
  submitting,
  reconciling,
  retryReady,
  reconcileRequired,
  succeeded,
  failed,
}

@immutable
class DoctorHomeOfferCommandView {
  const DoctorHomeOfferCommandView({
    required this.offerId,
    required this.action,
    required this.phase,
    required this.message,
  });

  final String offerId;
  final DoctorHomeOfferAction action;
  final DoctorHomeOfferCommandPhase phase;
  final String message;

  bool get isBusy =>
      phase == DoctorHomeOfferCommandPhase.verifying ||
      phase == DoctorHomeOfferCommandPhase.submitting ||
      phase == DoctorHomeOfferCommandPhase.reconciling;

  bool get canRetryExact => phase == DoctorHomeOfferCommandPhase.retryReady;

  bool get canReconcile =>
      phase == DoctorHomeOfferCommandPhase.reconcileRequired;
}

@immutable
class _PendingHomeOfferCommand {
  const _PendingHomeOfferCommand({
    required this.doctorId,
    required this.offerId,
    required this.expectedRevision,
    required this.idempotencyKey,
    required this.action,
  });

  final String doctorId;
  final String offerId;
  final int expectedRevision;
  final String idempotencyKey;
  final DoctorHomeOfferAction action;
}

class DoctorHomeOfferInboxController extends ChangeNotifier {
  DoctorHomeOfferInboxController({
    required DoctorHomeOfferRepositoryContract repository,
    this.onSessionRejected,
    this.onCommitmentMayHaveChanged,
    this.pageSize = 20,
    this.maximumRetainedPages = 3,
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) : _repository = repository,
       _idempotencyKeyFactory = idempotencyKeyFactory;

  final DoctorHomeOfferRepositoryContract _repository;
  final VoidCallback? onSessionRejected;
  final VoidCallback? onCommitmentMayHaveChanged;
  final int pageSize;
  final int maximumRetainedPages;
  final String Function() _idempotencyKeyFactory;

  DoctorHomeOfferInboxState _state = DoctorHomeOfferInboxState.detached;
  final List<DoctorHomeOffer> _offers = [];
  String? _doctorId;
  String? _message;
  bool _hasHomeCapability = false;
  bool _rolloutAvailable = true;
  bool _active = false;
  bool _loadingMore = false;
  bool _canLoadMore = false;
  int _loadedPages = 0;
  int _generation = 0;
  bool _disposed = false;
  String? _detailLoadingOfferId;
  CancelToken? _listToken;
  CancelToken? _detailToken;
  CancelToken? _commandToken;
  _PendingHomeOfferCommand? _pendingCommand;
  DoctorHomeOfferCommandView? _commandView;

  DoctorHomeOfferInboxState get state => _state;
  UnmodifiableListView<DoctorHomeOffer> get offers =>
      UnmodifiableListView(_offers);
  String? get message => _message;
  bool get isLoadingMore => _loadingMore;
  bool get canLoadMore => _canLoadMore && !_loadingMore;
  bool get isActive => _active;
  String? get detailLoadingOfferId => _detailLoadingOfferId;
  DoctorHomeOfferCommandView? get commandView => _commandView;
  bool get isCommandBusy => _commandView?.isBusy ?? false;
  bool get hasUnresolvedCommand => _pendingCommand != null;

  DoctorHomeOffer? offer(String offerId) {
    for (final offer in _offers) {
      if (offer.offerId == offerId) return offer;
    }
    return null;
  }

  bool canRespondTo(DoctorHomeOffer offer) =>
      _active &&
      _pendingCommand == null &&
      !isCommandBusy &&
      offer.isPending &&
      offer.responseDeadlineAt.isAfter(offer.evaluatedAt);

  void attachDoctor(String doctorId, {required bool hasHomeCapability}) {
    final normalized = doctorId.trim();
    if (normalized.isEmpty) throw ArgumentError.value(doctorId, 'doctorId');
    if (_doctorId != normalized) {
      _cancelRequests('Doctor HOME offer owner changed.');
      _doctorId = normalized;
      _offers.clear();
      _loadedPages = 0;
      _canLoadMore = false;
      _message = null;
      _state = DoctorHomeOfferInboxState.initial;
    }
    _hasHomeCapability = hasHomeCapability;
    if (!hasHomeCapability) {
      _active = false;
      _cancelRequests('Doctor does not own HOME capability.');
      _offers.clear();
      _state = DoctorHomeOfferInboxState.detached;
    }
    _notify();
  }

  void synchronizeRolloutAccess({required bool available}) {
    if (_rolloutAvailable == available) return;
    _rolloutAvailable = available;
    if (!available) {
      _cancelReadRequests('HOME offer rollout is unavailable.');
      _offers.clear();
      _loadedPages = 0;
      _canLoadMore = false;
      _message =
          'La lecture des offres HOME n’est pas activée sur cet environnement.';
      if (_doctorId != null && _hasHomeCapability) {
        _state = DoctorHomeOfferInboxState.unavailable;
      }
      _notify();
      return;
    }
    if (_doctorId != null && _hasHomeCapability) {
      _message = null;
      _state = DoctorHomeOfferInboxState.initial;
      _notify();
      if (_active) unawaited(refresh());
    }
  }

  Future<void> activate() async {
    if (_disposed || !_hasHomeCapability || _doctorId == null) return;
    _active = true;
    if (!_rolloutAvailable) {
      _state = DoctorHomeOfferInboxState.unavailable;
      _message =
          'La lecture des offres HOME n’est pas activée sur cet environnement.';
      _notify();
      return;
    }
    await refresh();
  }

  void deactivate() {
    if (!_active) return;
    _active = false;
    _cancelRequests(
      'HOME offer inbox left foreground view.',
      includeCommand: false,
    );
    _notify();
  }

  Future<void> refreshIfActive() =>
      _active ? refresh() : SynchronousFuture(null);

  Future<void> refresh() async {
    final doctorId = _doctorId;
    if (_disposed ||
        !_active ||
        !_rolloutAvailable ||
        !_hasHomeCapability ||
        doctorId == null) {
      return;
    }
    if (_pendingCommand != null) {
      await reconcilePendingCommand();
      return;
    }
    if (isCommandBusy) return;
    final generation = ++_generation;
    _listToken?.cancel('HOME offer refresh replaced.');
    _detailToken?.cancel('HOME offer detail replaced by inbox refresh.');
    _detailToken = null;
    _detailLoadingOfferId = null;
    final token = _listToken = CancelToken();
    _loadingMore = false;
    _message = null;
    _state = DoctorHomeOfferInboxState.loading;
    _notify();
    try {
      final page = await _repository.list(limit: pageSize, cancelToken: token);
      if (!_isCurrent(generation, doctorId, token)) return;
      _offers
        ..clear()
        ..addAll(page);
      _loadedPages = 1;
      _canLoadMore = page.length == pageSize && maximumRetainedPages > 1;
      _state = page.isEmpty
          ? DoctorHomeOfferInboxState.empty
          : DoctorHomeOfferInboxState.ready;
    } catch (error) {
      if (!_isCurrent(generation, doctorId, token) || _isCancellation(error)) {
        return;
      }
      _applyListFailure(DoctorHomeOfferFailure.from(error));
    } finally {
      if (_isCurrent(generation, doctorId, token)) {
        _listToken = null;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    final doctorId = _doctorId;
    if (_disposed ||
        !_active ||
        !_hasHomeCapability ||
        doctorId == null ||
        !canLoadMore ||
        _offers.isEmpty ||
        _loadedPages >= maximumRetainedPages) {
      return;
    }
    if (isCommandBusy || _pendingCommand != null) return;
    final generation = _generation;
    final token = _listToken = CancelToken();
    final cursor = _offers.last;
    _loadingMore = true;
    _message = null;
    _notify();
    try {
      final page = await _repository.list(
        limit: pageSize,
        beforeUpdatedAt: cursor.updatedAt,
        beforeOfferId: cursor.offerId,
        cancelToken: token,
      );
      if (!_isCurrent(generation, doctorId, token)) return;
      final known = _offers.map((offer) => offer.offerId).toSet();
      _offers.addAll(page.where((offer) => known.add(offer.offerId)));
      _loadedPages++;
      _canLoadMore =
          page.length == pageSize && _loadedPages < maximumRetainedPages;
      _state = _offers.isEmpty
          ? DoctorHomeOfferInboxState.empty
          : DoctorHomeOfferInboxState.ready;
    } catch (error) {
      if (!_isCurrent(generation, doctorId, token) || _isCancellation(error)) {
        return;
      }
      final failure = DoctorHomeOfferFailure.from(error);
      if (failure.kind == DoctorHomeOfferFailureKind.sessionRejected) {
        onSessionRejected?.call();
      }
      _message = failure.message;
      _canLoadMore = false;
    } finally {
      if (_isCurrent(generation, doctorId, token)) {
        _listToken = null;
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<DoctorHomeOfferDetailResult> loadDetail(String offerId) async {
    final doctorId = _doctorId;
    if (_disposed || !_active || doctorId == null) {
      return const DoctorHomeOfferDetailUnavailable(
        'Cette offre HOME n’est plus disponible.',
      );
    }
    if (isCommandBusy) {
      return const DoctorHomeOfferDetailUnavailable(
        'Une réponse HOME est en cours de vérification.',
      );
    }
    final generation = _generation;
    _detailToken?.cancel('HOME offer detail request replaced.');
    final token = _detailToken = CancelToken();
    _detailLoadingOfferId = offerId;
    _notify();
    try {
      final offer = await _repository.get(offerId, cancelToken: token);
      if (!_isCurrentDetail(generation, doctorId, token)) {
        return const DoctorHomeOfferDetailUnavailable(
          'Cette offre HOME n’est plus disponible.',
        );
      }
      final index = _offers.indexWhere((item) => item.offerId == offer.offerId);
      if (index >= 0) _offers[index] = offer;
      return DoctorHomeOfferDetailLoaded(offer);
    } catch (error) {
      if (!_isCurrentDetail(generation, doctorId, token) ||
          _isCancellation(error)) {
        return const DoctorHomeOfferDetailUnavailable(
          'Cette offre HOME n’est plus disponible.',
        );
      }
      final failure = DoctorHomeOfferFailure.from(error);
      if (failure.kind == DoctorHomeOfferFailureKind.sessionRejected) {
        onSessionRejected?.call();
      }
      if (failure.kind == DoctorHomeOfferFailureKind.notFound) {
        _offers.removeWhere((item) => item.offerId == offerId);
        if (_offers.isEmpty) _state = DoctorHomeOfferInboxState.empty;
      }
      return DoctorHomeOfferDetailUnavailable(failure.message);
    } finally {
      if (_isCurrentDetail(generation, doctorId, token)) {
        _detailToken = null;
        _detailLoadingOfferId = null;
        _notify();
      }
    }
  }

  Future<void> respond(String offerId, DoctorHomeOfferAction action) async {
    final doctorId = _doctorId;
    if (_disposed ||
        !_active ||
        !_hasHomeCapability ||
        doctorId == null ||
        isCommandBusy ||
        _pendingCommand != null) {
      return;
    }
    _cancelReadRequests('HOME offer command started.');
    final token = _commandToken = CancelToken();
    _commandView = DoctorHomeOfferCommandView(
      offerId: offerId,
      action: action,
      phase: DoctorHomeOfferCommandPhase.verifying,
      message: 'Vérification du statut actuel de l’offre…',
    );
    _notify();
    try {
      final current = await _repository.get(offerId, cancelToken: token);
      if (!_isCurrentCommandOwner(doctorId, token)) return;
      _adopt(current);
      if (!current.isPending ||
          !current.responseDeadlineAt.isAfter(current.evaluatedAt)) {
        _commandView = DoctorHomeOfferCommandView(
          offerId: offerId,
          action: action,
          phase: DoctorHomeOfferCommandPhase.failed,
          message: 'Cette offre ne peut plus recevoir de réponse.',
        );
        return;
      }
      final key = _idempotencyKeyFactory().trim();
      if (key.isEmpty || key.length > 128) {
        throw StateError('Invalid idempotency key factory result.');
      }
      final command = _PendingHomeOfferCommand(
        doctorId: doctorId,
        offerId: offerId,
        expectedRevision: current.revision,
        idempotencyKey: key,
        action: action,
      );
      _pendingCommand = command;
      await _send(command, token);
    } catch (error) {
      if (!_isCurrentCommandOwner(doctorId, token) || _isCancellation(error)) {
        return;
      }
      final failure = DoctorHomeOfferFailure.from(error);
      if (failure.kind == DoctorHomeOfferFailureKind.sessionRejected) {
        onSessionRejected?.call();
      }
      if (failure.kind == DoctorHomeOfferFailureKind.notFound) {
        _removeOffer(offerId);
      }
      _commandView = DoctorHomeOfferCommandView(
        offerId: offerId,
        action: action,
        phase: DoctorHomeOfferCommandPhase.failed,
        message: failure.message,
      );
    } finally {
      if (_isCurrentCommandOwner(doctorId, token) && _pendingCommand == null) {
        _commandToken = null;
        _notify();
      }
    }
  }

  Future<void> retryPendingCommand() async {
    final command = _pendingCommand;
    if (_disposed ||
        command == null ||
        _commandView?.canRetryExact != true ||
        _doctorId != command.doctorId ||
        !_active) {
      return;
    }
    _commandToken?.cancel('Exact HOME command retry started.');
    final token = _commandToken = CancelToken();
    await _send(command, token);
    if (_isCurrentCommandOwner(command.doctorId, token) &&
        _pendingCommand == null) {
      _commandToken = null;
      _notify();
    }
  }

  Future<void> reconcilePendingCommand() async {
    final command = _pendingCommand;
    if (_disposed || command == null || _doctorId != command.doctorId) return;
    _commandToken?.cancel('HOME command reconciliation restarted.');
    final token = _commandToken = CancelToken();
    const failure = DoctorHomeOfferCommandFailure(
      kind: DoctorHomeOfferCommandFailureKind.ambiguous,
      message: 'Vérification du résultat de la commande.',
    );
    await _reconcile(command, failure, token);
    if (_isCurrentCommandOwner(command.doctorId, token) &&
        _pendingCommand == null) {
      _commandToken = null;
      _notify();
    }
  }

  Future<void> _send(
    _PendingHomeOfferCommand command,
    CancelToken token,
  ) async {
    if (!_isCurrentCommand(command, token)) return;
    _commandView = DoctorHomeOfferCommandView(
      offerId: command.offerId,
      action: command.action,
      phase: DoctorHomeOfferCommandPhase.submitting,
      message: command.action == DoctorHomeOfferAction.accept
          ? 'Acceptation sécurisée en cours…'
          : 'Refus sécurisé en cours…',
    );
    _notify();
    try {
      final result = switch (command.action) {
        DoctorHomeOfferAction.accept => await _repository.accept(
          offerId: command.offerId,
          expectedRevision: command.expectedRevision,
          idempotencyKey: command.idempotencyKey,
          cancelToken: token,
        ),
        DoctorHomeOfferAction.decline => await _repository.decline(
          offerId: command.offerId,
          expectedRevision: command.expectedRevision,
          idempotencyKey: command.idempotencyKey,
          cancelToken: token,
        ),
      };
      if (!_isCurrentCommand(command, token)) return;
      _adopt(result);
      _pendingCommand = null;
      _commandView = DoctorHomeOfferCommandView(
        offerId: command.offerId,
        action: command.action,
        phase: DoctorHomeOfferCommandPhase.succeeded,
        message: _successMessage(result, command.action),
      );
    } catch (error) {
      if (!_isCurrentCommand(command, token) || _isCancellation(error)) return;
      final failure = DoctorHomeOfferCommandFailure.from(error);
      if (failure.kind == DoctorHomeOfferCommandFailureKind.sessionRejected) {
        _pendingCommand = null;
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.failed,
          message: failure.message,
        );
        onSessionRejected?.call();
        return;
      }
      if (failure.kind ==
          DoctorHomeOfferCommandFailureKind.rolloutUnavailable) {
        _pendingCommand = null;
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.failed,
          message: failure.message,
        );
        return;
      }
      if (failure.kind == DoctorHomeOfferCommandFailureKind.notFound) {
        _pendingCommand = null;
        _removeOffer(command.offerId);
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.failed,
          message: failure.message,
        );
        return;
      }
      await _reconcile(command, failure, token);
    } finally {
      if (_isCurrentCommandOwner(command.doctorId, token)) _notify();
    }
  }

  Future<void> _reconcile(
    _PendingHomeOfferCommand command,
    DoctorHomeOfferCommandFailure originalFailure,
    CancelToken token,
  ) async {
    if (!_isCurrentCommand(command, token)) return;
    _commandView = DoctorHomeOfferCommandView(
      offerId: command.offerId,
      action: command.action,
      phase: DoctorHomeOfferCommandPhase.reconciling,
      message: 'Vérification du résultat auprès du serveur…',
    );
    _notify();
    try {
      final current = await _repository.get(
        command.offerId,
        cancelToken: token,
      );
      if (!_isCurrentCommand(command, token)) return;
      _adopt(current);
      if (_matchesSuccessfulOutcome(current, command.action)) {
        _pendingCommand = null;
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.succeeded,
          message: _successMessage(current, command.action),
        );
      } else if (!current.isPending ||
          !current.responseDeadlineAt.isAfter(current.evaluatedAt) ||
          current.revision != command.expectedRevision) {
        _pendingCommand = null;
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.failed,
          message:
              '${originalFailure.message} Le statut actuel ne permet pas de répéter cette commande.',
        );
      } else if (originalFailure.hasAmbiguousOutcome) {
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.retryReady,
          message:
              '${originalFailure.message} L’offre est toujours en attente. Une répétition exacte est possible.',
        );
      } else {
        _pendingCommand = null;
        _commandView = DoctorHomeOfferCommandView(
          offerId: command.offerId,
          action: command.action,
          phase: DoctorHomeOfferCommandPhase.failed,
          message: originalFailure.message,
        );
      }
    } catch (error) {
      if (!_isCurrentCommand(command, token) || _isCancellation(error)) return;
      final readFailure = DoctorHomeOfferFailure.from(error);
      if (readFailure.kind == DoctorHomeOfferFailureKind.sessionRejected) {
        _pendingCommand = null;
        onSessionRejected?.call();
      } else if (readFailure.kind == DoctorHomeOfferFailureKind.notFound) {
        _pendingCommand = null;
        _removeOffer(command.offerId);
      } else if (!originalFailure.hasAmbiguousOutcome) {
        _pendingCommand = null;
      }
      _commandView = DoctorHomeOfferCommandView(
        offerId: command.offerId,
        action: command.action,
        phase: _pendingCommand == null
            ? DoctorHomeOfferCommandPhase.failed
            : DoctorHomeOfferCommandPhase.reconcileRequired,
        message: _pendingCommand == null
            ? readFailure.message
            : '${originalFailure.message} Le statut n’a pas pu être vérifié.',
      );
    }
  }

  void _adopt(DoctorHomeOffer offer) {
    final index = _offers.indexWhere((item) => item.offerId == offer.offerId);
    final previousStatus = index >= 0 ? _offers[index].status : null;
    if (index >= 0) {
      _offers[index] = offer;
    } else {
      _offers.insert(0, offer);
    }
    if (offer.status == DoctorHomeOfferStatus.selectedCommitted &&
        previousStatus != DoctorHomeOfferStatus.selectedCommitted) {
      onCommitmentMayHaveChanged?.call();
    }
  }

  void _removeOffer(String offerId) {
    _offers.removeWhere((item) => item.offerId == offerId);
    if (_offers.isEmpty && _state == DoctorHomeOfferInboxState.ready) {
      _state = DoctorHomeOfferInboxState.empty;
    }
  }

  static bool _matchesSuccessfulOutcome(
    DoctorHomeOffer offer,
    DoctorHomeOfferAction action,
  ) => switch (action) {
    DoctorHomeOfferAction.accept =>
      offer.isAcceptedHold ||
          offer.status == DoctorHomeOfferStatus.selectedCommitted ||
          offer.status == DoctorHomeOfferStatus.holdExpired ||
          offer.status == DoctorHomeOfferStatus.notSelected,
    DoctorHomeOfferAction.decline =>
      offer.status == DoctorHomeOfferStatus.declined,
  };

  static String _successMessage(
    DoctorHomeOffer offer,
    DoctorHomeOfferAction action,
  ) {
    if (offer.status == DoctorHomeOfferStatus.selectedCommitted) {
      return 'Le Patient vous a confirmé. L’intégration de mission reste indisponible dans cette version.';
    }
    if (action == DoctorHomeOfferAction.accept && offer.isAcceptedHold) {
      return offer.replayed
          ? 'L’acceptation temporaire était déjà enregistrée. Le choix du Patient reste en attente.'
          : 'Acceptation temporaire enregistrée. Le choix du Patient reste en attente.';
    }
    if (action == DoctorHomeOfferAction.decline &&
        offer.status == DoctorHomeOfferStatus.declined) {
      return offer.replayed
          ? 'Le refus était déjà enregistré.'
          : 'Offre déclinée.';
    }
    return 'Le statut serveur actuel a été restauré.';
  }

  void _applyListFailure(DoctorHomeOfferFailure failure) {
    _offers.clear();
    _canLoadMore = false;
    _loadedPages = 0;
    _message = failure.message;
    if (failure.kind == DoctorHomeOfferFailureKind.sessionRejected) {
      _state = DoctorHomeOfferInboxState.failure;
      onSessionRejected?.call();
    } else if (failure.kind == DoctorHomeOfferFailureKind.rolloutUnavailable) {
      _state = DoctorHomeOfferInboxState.unavailable;
    } else {
      _state = DoctorHomeOfferInboxState.failure;
    }
  }

  void clear() {
    _active = false;
    _cancelRequests('Doctor HOME offer session cleared.');
    _doctorId = null;
    _hasHomeCapability = false;
    _rolloutAvailable = true;
    _offers.clear();
    _loadedPages = 0;
    _canLoadMore = false;
    _message = null;
    _pendingCommand = null;
    _commandView = null;
    _state = DoctorHomeOfferInboxState.detached;
    _notify();
  }

  void _cancelRequests(String reason, {bool includeCommand = true}) {
    _cancelReadRequests(reason);
    if (includeCommand) {
      _commandToken?.cancel(reason);
      _commandToken = null;
      _pendingCommand = null;
      _commandView = null;
    }
  }

  void _cancelReadRequests(String reason) {
    _generation++;
    _listToken?.cancel(reason);
    _detailToken?.cancel(reason);
    _listToken = null;
    _detailToken = null;
    _detailLoadingOfferId = null;
    _loadingMore = false;
  }

  bool _isCurrentCommandOwner(String doctorId, CancelToken token) =>
      !_disposed &&
      identical(_commandToken, token) &&
      !token.isCancelled &&
      _doctorId == doctorId;

  bool _isCurrentCommand(_PendingHomeOfferCommand command, CancelToken token) =>
      _isCurrentCommandOwner(command.doctorId, token) &&
      identical(_pendingCommand, command);

  bool _isCurrent(int generation, String doctorId, CancelToken token) =>
      !_disposed &&
      _active &&
      generation == _generation &&
      identical(_listToken, token) &&
      !token.isCancelled &&
      _doctorId == doctorId;

  bool _isCurrentDetail(int generation, String doctorId, CancelToken token) =>
      !_disposed &&
      _active &&
      generation == _generation &&
      identical(_detailToken, token) &&
      !token.isCancelled &&
      _doctorId == doctorId;

  static bool _isCancellation(Object error) =>
      error is DioException && CancelToken.isCancel(error);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRequests('Doctor HOME offer controller disposed.');
    _offers.clear();
    super.dispose();
  }
}
