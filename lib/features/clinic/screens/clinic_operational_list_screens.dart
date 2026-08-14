import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/clinic_context_controller.dart';
import '../application/clinic_operational_controller.dart';
import '../clinic_routes.dart';
import '../data/clinic_models.dart';
import '../widgets/clinic_widgets.dart';

enum ClinicOperationalListKind { positionQueue, myTasks, handovers }

class ClinicOperationalListScreen extends StatefulWidget {
  const ClinicOperationalListScreen({super.key, required this.kind});

  final ClinicOperationalListKind kind;

  @override
  State<ClinicOperationalListScreen> createState() =>
      _ClinicOperationalListScreenState();
}

class _ClinicOperationalListScreenState
    extends State<ClinicOperationalListScreen> {
  bool _loadScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool refresh = false}) async {
    final clinic = context.read<ClinicContextController>();
    final clinicId = clinic.selectedClinicId;
    if (clinicId == null) return;
    final operational = context.read<ClinicOperationalController>();
    if (operational.clinicId != null && operational.clinicId != clinicId) {
      operational.clear();
    }
    switch (widget.kind) {
      case ClinicOperationalListKind.positionQueue:
        await operational.loadPositionQueue(clinicId, refresh: refresh);
      case ClinicOperationalListKind.myTasks:
        await operational.loadMyTasks(clinicId, refresh: refresh);
      case ClinicOperationalListKind.handovers:
        await operational.loadIncomingHandovers(clinicId, refresh: refresh);
        await operational.loadOutgoingHandovers(clinicId, refresh: refresh);
    }
  }

  String get _title => switch (widget.kind) {
    ClinicOperationalListKind.positionQueue => 'Position queue',
    ClinicOperationalListKind.myTasks => 'My tasks',
    ClinicOperationalListKind.handovers => 'Handovers',
  };

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicContextController>();
    final bootstrap = clinic.bootstrap;
    final operational = context.watch<ClinicOperationalController>();

    if (bootstrap == null ||
        !bootstrap.hasCapability(
          widget.kind == ClinicOperationalListKind.handovers
              ? ClinicCapability.taskHandover
              : ClinicCapability.taskRead,
        )) {
      return ClinicCapabilityUnavailableScreen(title: _title);
    }

    return Scaffold(
      backgroundColor: ClinicPalette.background,
      appBar: AppBar(
        title: Text(
          _title,
          style: clinicTextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: ClinicPalette.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isBusy(operational) ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(operational)),
    );
  }

  Widget _buildBody(ClinicOperationalController operational) {
    final taskState = switch (widget.kind) {
      ClinicOperationalListKind.positionQueue => operational.positionQueue,
      ClinicOperationalListKind.myTasks => operational.myTasks,
      ClinicOperationalListKind.handovers => null,
    };
    final handoverState = widget.kind == ClinicOperationalListKind.handovers
        ? operational.incomingHandovers
        : null;
    final status = taskState?.status ?? handoverState!.status;

    if (status == ClinicReadStatus.loading &&
        (taskState?.items.isEmpty ?? handoverState!.items.isEmpty)) {
      return const Center(
        child: CircularProgressIndicator(color: ClinicPalette.primary),
      );
    }

    final failure = taskState?.failure ?? handoverState?.failure;
    if (status == ClinicReadStatus.error && failure != null) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        color: ClinicPalette.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
          children: [
            ClinicReadErrorState(
              message: failure.message,
              onRetry: () => _load(),
            ),
          ],
        ),
      );
    }

    if (widget.kind == ClinicOperationalListKind.handovers) {
      return const _HandoversWorkspace();
    }
    return _buildTasks(taskState!);
  }

  Widget _buildTasks(ClinicTaskListState state) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        color: ClinicPalette.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
          children: [
            ClinicEmptyState(
              message: widget.kind == ClinicOperationalListKind.positionQueue
                  ? 'No tasks are waiting in your position queue.'
                  : 'You have no active tasks.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      color: ClinicPalette.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: state.items.length + (state.hasNext ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClinicSecondaryButton(
                label: state.isBusy ? 'Loading...' : 'Load more',
                onPressed: state.isBusy ? null : () => _loadNextTasks(),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskListTile(task: state.items[index], kind: widget.kind),
          );
        },
      ),
    );
  }

  Future<void> _loadNextTasks() async {
    final operational = context.read<ClinicOperationalController>();
    if (widget.kind == ClinicOperationalListKind.positionQueue) {
      await operational.loadNextPositionQueue();
    } else if (widget.kind == ClinicOperationalListKind.myTasks) {
      await operational.loadNextMyTasks();
    }
  }

  bool _isBusy(ClinicOperationalController operational) {
    return switch (widget.kind) {
      ClinicOperationalListKind.positionQueue =>
        operational.positionQueue.isBusy,
      ClinicOperationalListKind.myTasks => operational.myTasks.isBusy,
      ClinicOperationalListKind.handovers =>
        operational.incomingHandovers.isBusy ||
            operational.outgoingHandovers.isBusy ||
            operational.handoverCommandInFlight,
    };
  }
}

class _HandoversWorkspace extends StatefulWidget {
  const _HandoversWorkspace();

  @override
  State<_HandoversWorkspace> createState() => _HandoversWorkspaceState();
}

class _HandoversWorkspaceState extends State<_HandoversWorkspace> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final operational = context.watch<ClinicOperationalController>();
    final incoming = operational.incomingHandovers;
    final outgoing = operational.outgoingHandovers;
    final state = _index == 0 ? incoming : outgoing;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                value: 0,
                label: Text('Incoming'),
                icon: Icon(Icons.call_received_outlined),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Outgoing'),
                icon: Icon(Icons.call_made_outlined),
              ),
            ],
            selected: {_index},
            onSelectionChanged: (value) =>
                setState(() => _index = value.single),
          ),
        ),
        Expanded(
          child: _HandoverList(
            state: state,
            incoming: _index == 0,
            onRefresh: _refresh,
            onLoadMore: _loadMore,
            onCommand: _runCommand,
            commandInFlight: operational.handoverCommandInFlight,
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final operational = context.read<ClinicOperationalController>();
    if (_index == 0) {
      await operational.loadIncomingHandovers(clinicId, refresh: true);
    } else {
      await operational.loadOutgoingHandovers(clinicId, refresh: true);
    }
  }

  Future<void> _loadMore() async {
    final operational = context.read<ClinicOperationalController>();
    if (_index == 0) {
      await operational.loadNextIncomingHandovers();
    } else {
      await operational.loadNextOutgoingHandovers();
    }
  }

  Future<void> _runCommand(
    ClinicHandoverSummary handover,
    ClinicHandoverCommandAction action,
  ) async {
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final controller = context.read<ClinicOperationalController>();
    final result = switch (action) {
      ClinicHandoverCommandAction.accept => await controller.acceptHandover(
        clinicId,
        handover,
      ),
      ClinicHandoverCommandAction.decline => await controller.declineHandover(
        clinicId,
        handover,
      ),
      ClinicHandoverCommandAction.cancel => await controller.cancelHandover(
        clinicId,
        handover,
      ),
    };
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message ?? result.failure!.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _HandoverList extends StatelessWidget {
  const _HandoverList({
    required this.state,
    required this.incoming,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onCommand,
    required this.commandInFlight,
  });

  final ClinicHandoverListState state;
  final bool incoming;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(
    ClinicHandoverSummary,
    ClinicHandoverCommandAction,
  )
  onCommand;
  final bool commandInFlight;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    if (state.status == ClinicReadStatus.loading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ClinicPalette.primary),
      );
    }
    if (state.status == ClinicReadStatus.error && failure != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: ClinicPalette.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
          children: [
            ClinicReadErrorState(
              message: failure.message,
              onRetry: () => onRefresh(),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: ClinicPalette.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
          children: [
            ClinicEmptyState(
              message: incoming
                  ? 'No handovers are waiting for your response.'
                  : 'You have no pending task handovers.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: ClinicPalette.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: state.items.length + (state.hasNext ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClinicSecondaryButton(
                label: 'Load more',
                onPressed: state.isBusy ? null : () => onLoadMore(),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HandoverListTile(
              handover: state.items[index],
              incoming: incoming,
              busy: commandInFlight,
              onCommand: onCommand,
            ),
          );
        },
      ),
    );
  }
}

class ClinicCapabilityUnavailableScreen extends StatelessWidget {
  const ClinicCapabilityUnavailableScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ClinicPageScaffold(
      title: title,
      subtitle:
          'This destination is not enabled for your current clinic access.',
      children: const [
        ClinicCard(
          child: Text(
            'Your clinic capabilities do not include this operational view.',
          ),
        ),
      ],
    );
  }
}

class ClinicEmptyState extends StatelessWidget {
  const ClinicEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 34,
            color: ClinicPalette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: clinicTextStyle(
              fontSize: 14,
              color: ClinicPalette.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class ClinicReadErrorState extends StatelessWidget {
  const ClinicReadErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 34,
            color: ClinicPalette.warning,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: clinicTextStyle(
              color: ClinicPalette.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ClinicPrimaryButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({required this.task, required this.kind});

  final ClinicTaskSummary task;
  final ClinicOperationalListKind kind;

  @override
  Widget build(BuildContext context) {
    final acknowledgementOverdue =
        task.status == ClinicTaskStatus.assigned &&
        task.acknowledgementDueAt != null &&
        ClinicDeadlineSemantics.isAcknowledgementOverdue(
          acknowledgementDueAt: task.acknowledgementDueAt!,
          acknowledgedAt: null,
          now: DateTime.now(),
        );

    return Material(
      color: ClinicPalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(
          context,
        ).pushNamed(ClinicRoutes.taskDetail, arguments: task.taskId),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ClinicPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.taskType.label,
                      style: clinicTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _PriorityChip(priority: task.priority),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClinicStatusChip(
                    label: task.status.label,
                    active:
                        task.status != ClinicTaskStatus.blocked &&
                        task.status != ClinicTaskStatus.cancelled,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.caseContext.situation.label,
                      textAlign: TextAlign.end,
                      style: clinicTextStyle(
                        fontSize: 12,
                        color: ClinicPalette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${ClinicReferenceFormatter.requestReference(task.caseContext.sourceRequestId)} · ${ClinicReferenceFormatter.caseReference(task.caseId)}',
                style: clinicTextStyle(
                  fontSize: 12,
                  color: ClinicPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kind == ClinicOperationalListKind.myTasks
                    ? '${task.responsibilityType.label} · ${_positionLabel(task)}'
                    : task.responsibilityType.label,
                style: clinicTextStyle(
                  fontSize: 12,
                  color: ClinicPalette.textSecondary,
                ),
              ),
              if (task.acknowledgementRequired &&
                  task.acknowledgementDueAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  acknowledgementOverdue
                      ? 'Acknowledgement overdue · ${ClinicDateTimeFormatter.format(task.acknowledgementDueAt)}'
                      : 'Acknowledgement due · ${ClinicDateTimeFormatter.format(task.acknowledgementDueAt)}',
                  style: clinicTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: acknowledgementOverdue
                        ? ClinicPalette.warning
                        : ClinicPalette.textSecondary,
                  ),
                ),
              ],
              if (task.dueAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Due · ${ClinicDateTimeFormatter.format(task.dueAt)}',
                  style: clinicTextStyle(
                    fontSize: 12,
                    color: ClinicPalette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Created · ${ClinicDateTimeFormatter.format(task.createdAt)}',
                style: clinicTextStyle(
                  fontSize: 12,
                  color: ClinicPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _positionLabel(ClinicTaskSummary task) {
    if (task.assignedPositionId == null) return 'Position unavailable';
    return 'Assigned position';
  }
}

class _HandoverListTile extends StatelessWidget {
  const _HandoverListTile({
    required this.handover,
    required this.incoming,
    required this.busy,
    required this.onCommand,
  });

  final ClinicHandoverSummary handover;
  final bool incoming;
  final bool busy;
  final Future<void> Function(
    ClinicHandoverSummary,
    ClinicHandoverCommandAction,
  )
  onCommand;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  handover.taskType.label,
                  style: clinicTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PriorityChip(priority: handover.priority),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClinicStatusChip(
                label: handover.status.label,
                active: handover.status == ClinicHandoverStatus.pending,
              ),
              const SizedBox(width: 8),
              Text(
                handover.reason.label,
                style: clinicTextStyle(
                  fontSize: 12,
                  color: ClinicPalette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${incoming ? 'From' : 'To'} team member · Task ${ClinicReferenceFormatter.caseReference(handover.taskId)}',
            style: clinicTextStyle(
              fontSize: 12,
              color: ClinicPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Initiated · ${ClinicDateTimeFormatter.format(handover.initiatedAt)}',
            style: clinicTextStyle(
              fontSize: 12,
              color: ClinicPalette.textSecondary,
            ),
          ),
          if (handover.status == ClinicHandoverStatus.invalidated) ...[
            const SizedBox(height: 4),
            Text(
              handover.invalidationReason.label,
              style: clinicTextStyle(
                fontSize: 12,
                color: ClinicPalette.textSecondary,
              ),
            ),
          ],
          if (handover.isPending) ...[
            const SizedBox(height: 12),
            if (incoming)
              Row(
                children: [
                  Expanded(
                    child: ClinicSecondaryButton(
                      label: busy ? 'Working...' : 'Decline',
                      icon: Icons.close_outlined,
                      onPressed: busy
                          ? null
                          : () => onCommand(
                              handover,
                              ClinicHandoverCommandAction.decline,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClinicPrimaryButton(
                      label: busy ? 'Working...' : 'Accept',
                      icon: Icons.check_outlined,
                      onPressed: busy
                          ? null
                          : () => onCommand(
                              handover,
                              ClinicHandoverCommandAction.accept,
                            ),
                    ),
                  ),
                ],
              )
            else
              ClinicSecondaryButton(
                label: busy ? 'Working...' : 'Cancel',
                icon: Icons.cancel_outlined,
                onPressed: busy
                    ? null
                    : () => onCommand(
                        handover,
                        ClinicHandoverCommandAction.cancel,
                      ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final ClinicOperationalPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      ClinicOperationalPriority.low => ClinicPalette.textSecondary,
      ClinicOperationalPriority.normal => const Color(0xFF475467),
      ClinicOperationalPriority.high => ClinicPalette.warning,
      ClinicOperationalPriority.critical => const Color(0xFFB42318),
      ClinicOperationalPriority.unknown => ClinicPalette.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.label,
        style: clinicTextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
