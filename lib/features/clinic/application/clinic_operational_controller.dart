import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/clinic_failure.dart';
import '../data/clinic_models.dart';
import '../data/clinic_repository.dart';

enum ClinicReadStatus { idle, loading, refreshing, content, empty, error }

enum ClinicTaskCommandAction { acknowledge, start, block, unblock, complete }

enum ClinicCaseCommandAction {
  startReview,
  requestInformation,
  readyForPlanning,
  decline,
}

enum ClinicHandoverCommandAction { accept, decline, cancel }

class ClinicTaskDetailState {
  const ClinicTaskDetailState({
    this.task,
    this.caseDetail,
    this.taskId,
    this.status = ClinicReadStatus.idle,
    this.failure,
    this.commandInFlight = false,
  });

  final ClinicTaskDetail? task;
  final ClinicCaseDetail? caseDetail;
  final String? taskId;
  final ClinicReadStatus status;
  final ClinicFailure? failure;
  final bool commandInFlight;

  bool get isLoading => status == ClinicReadStatus.loading;
  bool get isRefreshing => status == ClinicReadStatus.refreshing;
  bool get isBusy => isLoading || isRefreshing || commandInFlight;

  ClinicTaskDetailState copyWith({
    ClinicTaskDetail? task,
    ClinicCaseDetail? caseDetail,
    String? taskId,
    ClinicReadStatus? status,
    ClinicFailure? failure,
    bool? commandInFlight,
    bool clearTask = false,
    bool clearCaseDetail = false,
    bool clearFailure = false,
  }) {
    return ClinicTaskDetailState(
      task: clearTask ? null : task ?? this.task,
      caseDetail: clearCaseDetail ? null : caseDetail ?? this.caseDetail,
      taskId: taskId ?? this.taskId,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      commandInFlight: commandInFlight ?? this.commandInFlight,
    );
  }
}

class ClinicTaskCommandResult {
  const ClinicTaskCommandResult.success(this.message) : failure = null;

  const ClinicTaskCommandResult.failure(this.failure) : message = null;

  final String? message;
  final ClinicFailure? failure;

  bool get succeeded => failure == null;
}

class ClinicTaskListState {
  const ClinicTaskListState({
    this.items = const [],
    this.page = 0,
    this.hasNext = false,
    this.status = ClinicReadStatus.idle,
    this.failure,
  });

  final List<ClinicTaskSummary> items;
  final int page;
  final bool hasNext;
  final ClinicReadStatus status;
  final ClinicFailure? failure;

  bool get isLoading => status == ClinicReadStatus.loading;
  bool get isRefreshing => status == ClinicReadStatus.refreshing;
  bool get isBusy => isLoading || isRefreshing;

  ClinicTaskListState copyWith({
    List<ClinicTaskSummary>? items,
    int? page,
    bool? hasNext,
    ClinicReadStatus? status,
    ClinicFailure? failure,
    bool clearFailure = false,
  }) {
    return ClinicTaskListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ClinicHandoverListState {
  const ClinicHandoverListState({
    this.items = const [],
    this.page = 0,
    this.hasNext = false,
    this.status = ClinicReadStatus.idle,
    this.failure,
  });

  final List<ClinicHandoverSummary> items;
  final int page;
  final bool hasNext;
  final ClinicReadStatus status;
  final ClinicFailure? failure;

  bool get isLoading => status == ClinicReadStatus.loading;
  bool get isRefreshing => status == ClinicReadStatus.refreshing;
  bool get isBusy => isLoading || isRefreshing;

  ClinicHandoverListState copyWith({
    List<ClinicHandoverSummary>? items,
    int? page,
    bool? hasNext,
    ClinicReadStatus? status,
    ClinicFailure? failure,
    bool clearFailure = false,
  }) {
    return ClinicHandoverListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ClinicHandoverTargetListState {
  const ClinicHandoverTargetListState({
    this.items = const [],
    this.taskId,
    this.page = 0,
    this.hasNext = false,
    this.status = ClinicReadStatus.idle,
    this.failure,
  });

  final List<ClinicHandoverTarget> items;
  final String? taskId;
  final int page;
  final bool hasNext;
  final ClinicReadStatus status;
  final ClinicFailure? failure;

  bool get isLoading => status == ClinicReadStatus.loading;
  bool get isRefreshing => status == ClinicReadStatus.refreshing;
  bool get isBusy => isLoading || isRefreshing;

  ClinicHandoverTargetListState copyWith({
    List<ClinicHandoverTarget>? items,
    String? taskId,
    int? page,
    bool? hasNext,
    ClinicReadStatus? status,
    ClinicFailure? failure,
    bool clearItems = false,
    bool clearFailure = false,
  }) {
    return ClinicHandoverTargetListState(
      items: clearItems ? const [] : items ?? this.items,
      taskId: taskId ?? this.taskId,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

/// Owns transient, server-authoritative read state for the P3-14 workspace.
/// Nothing in this controller is persisted and it contains no task commands or
/// local workflow transitions.
class ClinicOperationalController extends ChangeNotifier {
  ClinicOperationalController({
    required ClinicRepository repository,
    int pageSize = 20,
  }) : _repository = repository,
       _pageSize = pageSize.clamp(1, 100).toInt();

  final ClinicRepository _repository;
  final int _pageSize;

  ClinicTaskListState _positionQueue = const ClinicTaskListState();
  ClinicTaskListState _myTasks = const ClinicTaskListState();
  ClinicTaskDetailState _taskDetail = const ClinicTaskDetailState();
  ClinicHandoverListState _incomingHandovers = const ClinicHandoverListState();
  ClinicHandoverListState _outgoingHandovers = const ClinicHandoverListState();
  ClinicHandoverTargetListState _handoverTargets =
      const ClinicHandoverTargetListState();
  bool _handoverCommandInFlight = false;
  final Map<String, CancelToken> _tokens = <String, CancelToken>{};
  String? _clinicId;
  bool _disposed = false;

  ClinicTaskListState get positionQueue => _positionQueue;
  ClinicTaskListState get myTasks => _myTasks;
  ClinicTaskDetailState get taskDetail => _taskDetail;
  ClinicHandoverListState get incomingHandovers => _incomingHandovers;
  ClinicHandoverListState get outgoingHandovers => _outgoingHandovers;
  ClinicHandoverTargetListState get handoverTargets => _handoverTargets;
  bool get handoverCommandInFlight => _handoverCommandInFlight;
  String? get clinicId => _clinicId;

  Future<void> loadPositionQueue(
    String clinicId, {
    bool refresh = false,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null) return;
    final requestKey = 'position-queue';
    final state = _positionQueue;
    if (state.isBusy) return;
    _clinicId = id;
    _positionQueue = state.copyWith(
      status: refresh && state.items.isNotEmpty
          ? ClinicReadStatus.refreshing
          : ClinicReadStatus.loading,
      clearFailure: true,
    );
    _notify();
    try {
      final page = await _repository.loadPositionQueue(
        id,
        page: 0,
        pageSize: _pageSize,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed) return;
      _positionQueue = ClinicTaskListState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        status: page.items.isEmpty
            ? ClinicReadStatus.empty
            : ClinicReadStatus.content,
      );
    } catch (error) {
      if (_clinicId != id || _disposed) return;
      _positionQueue = state.copyWith(
        status: ClinicReadStatus.error,
        failure: ClinicFailure.from(error),
      );
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  Future<void> loadMyTasks(String clinicId, {bool refresh = false}) async {
    final id = _validClinicId(clinicId);
    if (id == null) return;
    final requestKey = 'my-tasks';
    final state = _myTasks;
    if (state.isBusy) return;
    _clinicId = id;
    _myTasks = state.copyWith(
      status: refresh && state.items.isNotEmpty
          ? ClinicReadStatus.refreshing
          : ClinicReadStatus.loading,
      clearFailure: true,
    );
    _notify();
    try {
      final page = await _repository.loadMyTasks(
        id,
        page: 0,
        pageSize: _pageSize,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed) return;
      _myTasks = ClinicTaskListState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        status: page.items.isEmpty
            ? ClinicReadStatus.empty
            : ClinicReadStatus.content,
      );
    } catch (error) {
      if (_clinicId != id || _disposed) return;
      _myTasks = state.copyWith(
        status: ClinicReadStatus.error,
        failure: ClinicFailure.from(error),
      );
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  Future<void> loadIncomingHandovers(
    String clinicId, {
    bool refresh = false,
  }) async {
    await _loadHandovers(clinicId, incoming: true, refresh: refresh);
  }

  Future<void> loadHandoverTargets(
    String clinicId,
    ClinicTaskDetail task, {
    bool refresh = false,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null) return;
    final tid = task.taskId;
    final requestKey = 'handover-targets-$tid';
    final state = _handoverTargets;
    if (state.isBusy) return;
    final taskChanged = state.taskId != null && state.taskId != tid;
    _clinicId = id;
    _handoverTargets = state.copyWith(
      taskId: tid,
      status: refresh && state.items.isNotEmpty && !taskChanged
          ? ClinicReadStatus.refreshing
          : ClinicReadStatus.loading,
      clearItems: taskChanged,
      clearFailure: true,
    );
    _notify();
    try {
      final page = await _repository.loadHandoverTargets(
        id,
        tid,
        page: 0,
        pageSize: _pageSize,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed || _handoverTargets.taskId != tid) {
        return;
      }
      _handoverTargets = ClinicHandoverTargetListState(
        items: page.items,
        taskId: tid,
        page: page.page,
        hasNext: page.hasNext,
        status: page.items.isEmpty
            ? ClinicReadStatus.empty
            : ClinicReadStatus.content,
      );
    } catch (error) {
      if (_clinicId != id || _disposed || _handoverTargets.taskId != tid) {
        return;
      }
      _handoverTargets = _handoverTargets.copyWith(
        status: ClinicReadStatus.error,
        failure: ClinicFailure.from(error),
      );
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  Future<void> loadTaskDetail(
    String clinicId,
    String taskId, {
    bool refresh = false,
  }) async {
    final id = _validClinicId(clinicId);
    final tid = taskId.trim();
    if (id == null || tid.isEmpty) return;
    final requestKey = 'task-detail-$tid';
    String? caseRequestKey;
    final state = _taskDetail;
    if (state.isLoading || state.isRefreshing) return;
    _clinicId = id;
    _taskDetail = state.copyWith(
      taskId: tid,
      status: refresh && state.task != null
          ? ClinicReadStatus.refreshing
          : ClinicReadStatus.loading,
      clearFailure: true,
      clearTask: state.taskId != null && state.taskId != tid,
      clearCaseDetail: state.taskId != null && state.taskId != tid,
    );
    _notify();
    try {
      final task = await _repository.loadTaskDetail(
        id,
        tid,
        cancelToken: _replaceToken(requestKey),
      );
      ClinicCaseDetail? caseDetail;
      if (task.taskType == ClinicTaskType.administrativeReview) {
        caseRequestKey = 'case-detail-${task.caseId}';
        final key = caseRequestKey;
        caseDetail = await _repository.loadCaseDetail(
          id,
          task.caseId,
          cancelToken: _replaceToken(key),
        );
      }
      if (_clinicId != id || _disposed || _taskDetail.taskId != tid) return;
      _taskDetail = ClinicTaskDetailState(
        task: task,
        caseDetail: caseDetail,
        taskId: tid,
        status: ClinicReadStatus.content,
      );
    } catch (error) {
      if (_clinicId != id || _disposed || _taskDetail.taskId != tid) return;
      _taskDetail = _taskDetail.copyWith(
        status: ClinicReadStatus.error,
        failure: ClinicFailure.from(error),
        clearTask: true,
        clearCaseDetail: true,
      );
    } finally {
      _removeToken(requestKey);
      final key = caseRequestKey;
      if (key != null) _removeToken(key);
      _notify();
    }
  }

  Future<ClinicTaskCommandResult> acknowledgeTask(
    String clinicId,
    ClinicTaskDetail task,
  ) {
    return _runTaskCommand(
      clinicId,
      task,
      action: ClinicTaskCommandAction.acknowledge,
    );
  }

  Future<ClinicTaskCommandResult> startTask(
    String clinicId,
    ClinicTaskDetail task,
  ) {
    return _runTaskCommand(
      clinicId,
      task,
      action: ClinicTaskCommandAction.start,
    );
  }

  Future<ClinicTaskCommandResult> blockTask(
    String clinicId,
    ClinicTaskDetail task,
    ClinicTaskBlockedReason reason,
  ) {
    return _runTaskCommand(
      clinicId,
      task,
      action: ClinicTaskCommandAction.block,
      blockReason: reason,
    );
  }

  Future<ClinicTaskCommandResult> unblockTask(
    String clinicId,
    ClinicTaskDetail task,
  ) {
    return _runTaskCommand(
      clinicId,
      task,
      action: ClinicTaskCommandAction.unblock,
    );
  }

  Future<ClinicTaskCommandResult> completeTask(
    String clinicId,
    ClinicTaskDetail task,
  ) {
    return _runTaskCommand(
      clinicId,
      task,
      action: ClinicTaskCommandAction.complete,
    );
  }

  Future<ClinicTaskCommandResult> startReview(
    String clinicId,
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail,
  ) {
    return _runCaseCommand(
      clinicId,
      task,
      caseDetail,
      action: ClinicCaseCommandAction.startReview,
    );
  }

  Future<ClinicTaskCommandResult> requestInformation(
    String clinicId,
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail, {
    required ClinicInformationRequestReason reason,
    String? patientInstruction,
  }) {
    return _runCaseCommand(
      clinicId,
      task,
      caseDetail,
      action: ClinicCaseCommandAction.requestInformation,
      informationReason: reason,
      patientInstruction: patientInstruction,
    );
  }

  Future<ClinicTaskCommandResult> readyForPlanning(
    String clinicId,
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail,
  ) {
    return _runCaseCommand(
      clinicId,
      task,
      caseDetail,
      action: ClinicCaseCommandAction.readyForPlanning,
    );
  }

  Future<ClinicTaskCommandResult> declineCase(
    String clinicId,
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail, {
    required ClinicCaseDeclineReason reason,
  }) {
    return _runCaseCommand(
      clinicId,
      task,
      caseDetail,
      action: ClinicCaseCommandAction.decline,
      declineReason: reason,
    );
  }

  Future<void> loadOutgoingHandovers(
    String clinicId, {
    bool refresh = false,
  }) async {
    await _loadHandovers(clinicId, incoming: false, refresh: refresh);
  }

  Future<ClinicTaskCommandResult> initiateHandover(
    String clinicId,
    ClinicTaskDetail task, {
    required ClinicHandoverTarget target,
    required ClinicHandoverReason reason,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null || _handoverCommandInFlight) {
      return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
    }
    final tid = task.taskId;
    final requestKey = 'handover-initiate-$tid';
    _clinicId = id;
    _handoverCommandInFlight = true;
    _taskDetail = _taskDetail.copyWith(clearFailure: true);
    _handoverTargets = _handoverTargets.copyWith(clearFailure: true);
    _notify();
    try {
      await _repository.initiateHandover(
        id,
        tid,
        toMembershipId: target.membershipId,
        reason: reason,
        expectedTaskVersion: task.version,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      _handoverCommandInFlight = false;
      _notify();
      await _refreshAfterHandoverCommand(id, taskId: tid);
      return const ClinicTaskCommandResult.success('Handover requested.');
    } catch (error) {
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      final failure = ClinicFailure.from(error);
      _handoverCommandInFlight = false;
      _handoverTargets = _handoverTargets.copyWith(failure: failure);
      _taskDetail = _taskDetail.copyWith(failure: failure);
      _notify();
      await _refreshAfterHandoverCommand(id, taskId: tid, refreshTargets: true);
      return ClinicTaskCommandResult.failure(failure);
    } finally {
      _removeToken(requestKey);
      if (!_disposed && _handoverCommandInFlight) {
        _handoverCommandInFlight = false;
        _notify();
      }
    }
  }

  Future<ClinicTaskCommandResult> acceptHandover(
    String clinicId,
    ClinicHandoverSummary handover,
  ) {
    return _runHandoverCommand(
      clinicId,
      handover,
      action: ClinicHandoverCommandAction.accept,
    );
  }

  Future<ClinicTaskCommandResult> declineHandover(
    String clinicId,
    ClinicHandoverSummary handover,
  ) {
    return _runHandoverCommand(
      clinicId,
      handover,
      action: ClinicHandoverCommandAction.decline,
    );
  }

  Future<ClinicTaskCommandResult> cancelHandover(
    String clinicId,
    ClinicHandoverSummary handover,
  ) {
    return _runHandoverCommand(
      clinicId,
      handover,
      action: ClinicHandoverCommandAction.cancel,
    );
  }

  Future<void> loadNextPositionQueue() async {
    await _loadNextTasks(
      requestKey: 'position-queue',
      state: _positionQueue,
      loader: (page) => _repository.loadPositionQueue(
        _clinicId!,
        page: page,
        pageSize: _pageSize,
        cancelToken: _replaceToken('position-queue'),
      ),
      update: (page, items) {
        _positionQueue = ClinicTaskListState(
          items: items,
          page: page.page,
          hasNext: page.hasNext,
          status: ClinicReadStatus.content,
        );
      },
    );
  }

  Future<void> loadNextMyTasks() async {
    await _loadNextTasks(
      requestKey: 'my-tasks',
      state: _myTasks,
      loader: (page) => _repository.loadMyTasks(
        _clinicId!,
        page: page,
        pageSize: _pageSize,
        cancelToken: _replaceToken('my-tasks'),
      ),
      update: (page, items) {
        _myTasks = ClinicTaskListState(
          items: items,
          page: page.page,
          hasNext: page.hasNext,
          status: ClinicReadStatus.content,
        );
      },
    );
  }

  Future<void> loadNextIncomingHandovers() async {
    await _loadNextHandovers(incoming: true);
  }

  Future<void> loadNextOutgoingHandovers() async {
    await _loadNextHandovers(incoming: false);
  }

  Future<void> loadNextHandoverTargets() async {
    final id = _clinicId;
    final tid = _handoverTargets.taskId;
    final state = _handoverTargets;
    if (id == null || tid == null || !state.hasNext || state.isBusy) return;
    final requestKey = 'handover-targets-$tid';
    final currentItems = state.items;
    _handoverTargets = state.copyWith(
      status: ClinicReadStatus.refreshing,
      clearFailure: true,
    );
    _notify();
    try {
      final page = await _repository.loadHandoverTargets(
        id,
        tid,
        page: state.page + 1,
        pageSize: _pageSize,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed || _handoverTargets.taskId != tid) {
        return;
      }
      _handoverTargets = ClinicHandoverTargetListState(
        items: List.unmodifiable([...currentItems, ...page.items]),
        taskId: tid,
        page: page.page,
        hasNext: page.hasNext,
        status: ClinicReadStatus.content,
      );
    } catch (error) {
      if (_clinicId != id || _disposed || _handoverTargets.taskId != tid) {
        return;
      }
      _handoverTargets = _handoverTargets.copyWith(
        status: ClinicReadStatus.error,
        failure: ClinicFailure.from(error),
      );
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  Future<void> refreshLoaded(String clinicId) async {
    final id = _validClinicId(clinicId);
    if (id == null) return;

    final positionQueueWasLoaded =
        _positionQueue.status != ClinicReadStatus.idle;
    final myTasksWereLoaded = _myTasks.status != ClinicReadStatus.idle;
    final incomingWereLoaded =
        _incomingHandovers.status != ClinicReadStatus.idle;
    final outgoingWereLoaded =
        _outgoingHandovers.status != ClinicReadStatus.idle;
    final detailWasLoaded = _taskDetail.status != ClinicReadStatus.idle;
    final contextChanged = _clinicId != null && _clinicId != id;

    if (contextChanged) {
      clear();
      _clinicId = id;
      if (detailWasLoaded) {
        _taskDetail = const ClinicTaskDetailState(
          status: ClinicReadStatus.error,
          failure: ClinicFailure(
            kind: ClinicFailureKind.clinicUnavailable,
            message: 'This task is not available right now.',
            retryable: false,
            diagnosticCode: 'CLINIC_TASK_UNAVAILABLE',
          ),
        );
        _notify();
      }
    }

    if (positionQueueWasLoaded) {
      await loadPositionQueue(clinicId, refresh: true);
    }
    if (myTasksWereLoaded) {
      await loadMyTasks(clinicId, refresh: true);
    }
    if (incomingWereLoaded) {
      await loadIncomingHandovers(clinicId, refresh: true);
    }
    if (outgoingWereLoaded) {
      await loadOutgoingHandovers(clinicId, refresh: true);
    }
    final detailTaskId = _taskDetail.taskId;
    if (!contextChanged &&
        detailTaskId != null &&
        _taskDetail.status != ClinicReadStatus.idle) {
      await loadTaskDetail(clinicId, detailTaskId, refresh: true);
    }
  }

  void clear() {
    for (final token in _tokens.values) {
      if (!token.isCancelled) token.cancel('clinic-operational-cleared');
    }
    _tokens.clear();
    _clinicId = null;
    _positionQueue = const ClinicTaskListState();
    _myTasks = const ClinicTaskListState();
    _taskDetail = const ClinicTaskDetailState();
    _incomingHandovers = const ClinicHandoverListState();
    _outgoingHandovers = const ClinicHandoverListState();
    _handoverTargets = const ClinicHandoverTargetListState();
    _handoverCommandInFlight = false;
    _notify();
  }

  Future<ClinicTaskCommandResult> _runTaskCommand(
    String clinicId,
    ClinicTaskDetail task, {
    required ClinicTaskCommandAction action,
    ClinicTaskBlockedReason? blockReason,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null || _taskDetail.commandInFlight) {
      return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
    }
    final tid = task.taskId;
    final requestKey = 'task-command-$tid';
    _clinicId = id;
    _taskDetail = _taskDetail.copyWith(
      taskId: tid,
      commandInFlight: true,
      clearFailure: true,
    );
    _notify();

    try {
      switch (action) {
        case ClinicTaskCommandAction.acknowledge:
          await _repository.acknowledgeTask(
            id,
            tid,
            expectedVersion: task.version,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicTaskCommandAction.start:
          await _repository.startTask(
            id,
            tid,
            expectedVersion: task.version,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicTaskCommandAction.block:
          final reason = blockReason;
          if (reason == null || !reason.isGeneric) {
            return const ClinicTaskCommandResult.failure(
              ClinicFailure.invalidResponse,
            );
          }
          await _repository.blockTask(
            id,
            tid,
            reason: reason,
            expectedVersion: task.version,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicTaskCommandAction.unblock:
          await _repository.unblockTask(
            id,
            tid,
            expectedVersion: task.version,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicTaskCommandAction.complete:
          await _repository.completeTask(
            id,
            tid,
            expectedVersion: task.version,
            cancelToken: _replaceToken(requestKey),
          );
      }
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      _taskDetail = _taskDetail.copyWith(commandInFlight: false);
      _notify();
      await _refreshAfterTaskCommand(id, tid);
      final startedPreviously = task.startedAt != null;
      return ClinicTaskCommandResult.success(switch (action) {
        ClinicTaskCommandAction.acknowledge => 'Task acknowledged.',
        ClinicTaskCommandAction.start =>
          startedPreviously ? 'Task resumed.' : 'Task started.',
        ClinicTaskCommandAction.block => 'Task blocked.',
        ClinicTaskCommandAction.unblock => 'Task unblocked.',
        ClinicTaskCommandAction.complete => 'Task completed.',
      });
    } catch (error) {
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      final failure = ClinicFailure.from(error);
      _taskDetail = _taskDetail.copyWith(
        commandInFlight: false,
        failure: failure,
      );
      _notify();
      if (failure.kind == ClinicFailureKind.concurrency ||
          failure.diagnosticCode == 'CLINIC_TASK_UNAVAILABLE') {
        await _refreshAfterTaskCommand(id, tid);
      } else if (_taskDetail.taskId == tid) {
        await loadTaskDetail(id, tid, refresh: true);
      }
      return ClinicTaskCommandResult.failure(failure);
    } finally {
      _removeToken(requestKey);
      if (!_disposed && _taskDetail.commandInFlight) {
        _taskDetail = _taskDetail.copyWith(commandInFlight: false);
        _notify();
      }
    }
  }

  Future<ClinicTaskCommandResult> _runCaseCommand(
    String clinicId,
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail, {
    required ClinicCaseCommandAction action,
    ClinicInformationRequestReason? informationReason,
    String? patientInstruction,
    ClinicCaseDeclineReason? declineReason,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null || _taskDetail.commandInFlight) {
      return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
    }
    final tid = task.taskId;
    final requestKey = 'case-command-${caseDetail.clinicCaseId}';
    _clinicId = id;
    _taskDetail = _taskDetail.copyWith(
      taskId: tid,
      commandInFlight: true,
      clearFailure: true,
    );
    _notify();

    try {
      switch (action) {
        case ClinicCaseCommandAction.startReview:
          await _repository.startReview(
            id,
            caseDetail.clinicCaseId,
            expectedVersion: caseDetail.version,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicCaseCommandAction.requestInformation:
          final reason = informationReason;
          if (reason == null ||
              reason == ClinicInformationRequestReason.unknown) {
            return const ClinicTaskCommandResult.failure(
              ClinicFailure.invalidResponse,
            );
          }
          await _repository.requestInformation(
            id,
            caseDetail.clinicCaseId,
            expectedVersion: caseDetail.version,
            reason: reason,
            patientInstruction: _safeOptionalInstruction(patientInstruction),
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicCaseCommandAction.readyForPlanning:
          await _repository.readyForPlanning(
            id,
            caseDetail.clinicCaseId,
            expectedVersion: caseDetail.version,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicCaseCommandAction.decline:
          final reason = declineReason;
          if (reason == null || reason == ClinicCaseDeclineReason.unknown) {
            return const ClinicTaskCommandResult.failure(
              ClinicFailure.invalidResponse,
            );
          }
          await _repository.declineCase(
            id,
            caseDetail.clinicCaseId,
            expectedVersion: caseDetail.version,
            reason: reason,
            cancelToken: _replaceToken(requestKey),
          );
      }
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      _taskDetail = _taskDetail.copyWith(commandInFlight: false);
      _notify();
      await _refreshAfterTaskCommand(id, tid);
      return ClinicTaskCommandResult.success(switch (action) {
        ClinicCaseCommandAction.startReview => 'Review started.',
        ClinicCaseCommandAction.requestInformation => 'Information requested.',
        ClinicCaseCommandAction.readyForPlanning => 'Ready for planning.',
        ClinicCaseCommandAction.decline => 'Request declined.',
      });
    } catch (error) {
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      final failure = ClinicFailure.from(error);
      _taskDetail = _taskDetail.copyWith(
        commandInFlight: false,
        failure: failure,
      );
      _notify();
      if (failure.kind == ClinicFailureKind.concurrency ||
          failure.diagnosticCode == 'CLINIC_TASK_UNAVAILABLE') {
        await _refreshAfterTaskCommand(id, tid);
      } else if (_taskDetail.taskId == tid) {
        await loadTaskDetail(id, tid, refresh: true);
      }
      return ClinicTaskCommandResult.failure(failure);
    } finally {
      _removeToken(requestKey);
      if (!_disposed && _taskDetail.commandInFlight) {
        _taskDetail = _taskDetail.copyWith(commandInFlight: false);
        _notify();
      }
    }
  }

  Future<void> _refreshAfterTaskCommand(String clinicId, String taskId) async {
    await loadPositionQueue(clinicId, refresh: true);
    await loadMyTasks(clinicId, refresh: true);
    await loadIncomingHandovers(clinicId, refresh: true);
    await loadOutgoingHandovers(clinicId, refresh: true);
    if (_taskDetail.taskId == taskId) {
      await loadTaskDetail(clinicId, taskId, refresh: true);
    }
  }

  Future<ClinicTaskCommandResult> _runHandoverCommand(
    String clinicId,
    ClinicHandoverSummary handover, {
    required ClinicHandoverCommandAction action,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null || _handoverCommandInFlight || !handover.isPending) {
      return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
    }
    final requestKey = 'handover-command-${handover.handoverId}';
    _clinicId = id;
    _handoverCommandInFlight = true;
    _notify();
    try {
      switch (action) {
        case ClinicHandoverCommandAction.accept:
          await _repository.acceptHandover(
            id,
            handover.handoverId,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicHandoverCommandAction.decline:
          await _repository.declineHandover(
            id,
            handover.handoverId,
            cancelToken: _replaceToken(requestKey),
          );
        case ClinicHandoverCommandAction.cancel:
          await _repository.cancelHandover(
            id,
            handover.handoverId,
            cancelToken: _replaceToken(requestKey),
          );
      }
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      _handoverCommandInFlight = false;
      _notify();
      await _refreshAfterHandoverCommand(id, taskId: handover.taskId);
      return ClinicTaskCommandResult.success(switch (action) {
        ClinicHandoverCommandAction.accept => 'Handover accepted.',
        ClinicHandoverCommandAction.decline => 'Handover declined.',
        ClinicHandoverCommandAction.cancel => 'Handover cancelled.',
      });
    } catch (error) {
      if (_clinicId != id || _disposed) {
        return const ClinicTaskCommandResult.failure(ClinicFailure.unexpected);
      }
      final failure = ClinicFailure.from(error);
      _handoverCommandInFlight = false;
      _notify();
      await _refreshAfterHandoverCommand(id, taskId: handover.taskId);
      return ClinicTaskCommandResult.failure(failure);
    } finally {
      _removeToken(requestKey);
      if (!_disposed && _handoverCommandInFlight) {
        _handoverCommandInFlight = false;
        _notify();
      }
    }
  }

  Future<void> _refreshAfterHandoverCommand(
    String clinicId, {
    required String taskId,
    bool refreshTargets = false,
  }) async {
    if (_taskDetail.taskId == taskId) {
      await loadTaskDetail(clinicId, taskId, refresh: true);
    }
    await loadMyTasks(clinicId, refresh: true);
    if (_positionQueue.status != ClinicReadStatus.idle) {
      await loadPositionQueue(clinicId, refresh: true);
    }
    await loadIncomingHandovers(clinicId, refresh: true);
    await loadOutgoingHandovers(clinicId, refresh: true);
    final currentTask = _taskDetail.task;
    if (refreshTargets &&
        _handoverTargets.taskId == taskId &&
        currentTask != null) {
      await loadHandoverTargets(clinicId, currentTask, refresh: true);
    }
  }

  String? _safeOptionalInstruction(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _loadHandovers(
    String clinicId, {
    required bool incoming,
    required bool refresh,
  }) async {
    final id = _validClinicId(clinicId);
    if (id == null) return;
    final requestKey = incoming ? 'incoming-handovers' : 'outgoing-handovers';
    final state = incoming ? _incomingHandovers : _outgoingHandovers;
    if (state.isBusy) return;
    _clinicId = id;
    final next = state.copyWith(
      status: refresh && state.items.isNotEmpty
          ? ClinicReadStatus.refreshing
          : ClinicReadStatus.loading,
      clearFailure: true,
    );
    if (incoming) {
      _incomingHandovers = next;
    } else {
      _outgoingHandovers = next;
    }
    _notify();
    try {
      final page = await _repository.loadHandovers(
        id,
        incoming: incoming,
        page: 0,
        pageSize: _pageSize,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed) return;
      final loaded = ClinicHandoverListState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        status: page.items.isEmpty
            ? ClinicReadStatus.empty
            : ClinicReadStatus.content,
      );
      if (incoming) {
        _incomingHandovers = loaded;
      } else {
        _outgoingHandovers = loaded;
      }
    } catch (error) {
      if (_clinicId != id || _disposed) return;
      final failed = state.copyWith(
        status: ClinicReadStatus.error,
        failure: ClinicFailure.from(error),
      );
      if (incoming) {
        _incomingHandovers = failed;
      } else {
        _outgoingHandovers = failed;
      }
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  Future<void> _loadNextHandovers({required bool incoming}) async {
    final id = _clinicId;
    final state = incoming ? _incomingHandovers : _outgoingHandovers;
    if (id == null || !state.hasNext || state.isBusy) return;
    final requestKey = incoming ? 'incoming-handovers' : 'outgoing-handovers';
    final currentItems = state.items;
    final loading = state.copyWith(
      status: ClinicReadStatus.refreshing,
      clearFailure: true,
    );
    if (incoming) {
      _incomingHandovers = loading;
    } else {
      _outgoingHandovers = loading;
    }
    _notify();
    try {
      final page = await _repository.loadHandovers(
        id,
        incoming: incoming,
        page: state.page + 1,
        pageSize: _pageSize,
        cancelToken: _replaceToken(requestKey),
      );
      if (_clinicId != id || _disposed) return;
      final loaded = ClinicHandoverListState(
        items: List.unmodifiable([...currentItems, ...page.items]),
        page: page.page,
        hasNext: page.hasNext,
        status: ClinicReadStatus.content,
      );
      if (incoming) {
        _incomingHandovers = loaded;
      } else {
        _outgoingHandovers = loaded;
      }
    } catch (error) {
      if (_clinicId != id || _disposed) return;
      final failure = ClinicFailure.from(error);
      if (incoming) {
        _incomingHandovers = _incomingHandovers.copyWith(
          status: ClinicReadStatus.error,
          failure: failure,
        );
      } else {
        _outgoingHandovers = _outgoingHandovers.copyWith(
          status: ClinicReadStatus.error,
          failure: failure,
        );
      }
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  Future<void> _loadNextTasks({
    required String requestKey,
    required ClinicTaskListState state,
    required Future<ClinicSlice<ClinicTaskSummary>> Function(int page) loader,
    required void Function(
      ClinicSlice<ClinicTaskSummary> page,
      List<ClinicTaskSummary> items,
    )
    update,
  }) async {
    final id = _clinicId;
    if (id == null || !state.hasNext || state.isBusy) return;
    final currentItems = state.items;
    if (requestKey == 'position-queue') {
      _positionQueue = state.copyWith(
        status: ClinicReadStatus.refreshing,
        clearFailure: true,
      );
    } else {
      _myTasks = state.copyWith(
        status: ClinicReadStatus.refreshing,
        clearFailure: true,
      );
    }
    _notify();
    try {
      final page = await loader(state.page + 1);
      if (_clinicId != id || _disposed) return;
      update(page, List.unmodifiable([...currentItems, ...page.items]));
    } catch (error) {
      if (_clinicId != id || _disposed) return;
      final failure = ClinicFailure.from(error);
      if (requestKey == 'position-queue') {
        _positionQueue = _positionQueue.copyWith(
          status: ClinicReadStatus.error,
          failure: failure,
        );
      } else {
        _myTasks = _myTasks.copyWith(
          status: ClinicReadStatus.error,
          failure: failure,
        );
      }
    } finally {
      _removeToken(requestKey);
      _notify();
    }
  }

  CancelToken _replaceToken(String key) {
    _tokens[key]?.cancel('clinic-operational-replaced');
    final token = CancelToken();
    _tokens[key] = token;
    return token;
  }

  void _removeToken(String key) => _tokens.remove(key);

  String? _validClinicId(String value) {
    final id = value.trim();
    return id.isEmpty ? null : id;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _tokens.values) {
      if (!token.isCancelled) token.cancel('clinic-operational-disposed');
    }
    _tokens.clear();
    super.dispose();
  }
}
