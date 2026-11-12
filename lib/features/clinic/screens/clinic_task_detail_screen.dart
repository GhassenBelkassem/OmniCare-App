import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/clinic_context_controller.dart';
import '../application/clinic_operational_controller.dart';
import '../data/clinic_failure.dart';
import '../data/clinic_models.dart';
import '../widgets/clinic_widgets.dart';

class ClinicTaskDetailScreen extends StatefulWidget {
  const ClinicTaskDetailScreen({super.key});

  @override
  State<ClinicTaskDetailScreen> createState() => _ClinicTaskDetailScreenState();
}

class _ClinicTaskDetailScreenState extends State<ClinicTaskDetailScreen> {
  bool _loadScheduled = false;
  String? _taskId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final taskId = args is String ? args.trim() : null;
    if (taskId == null || taskId.isEmpty || _loadScheduled) return;
    _taskId = taskId;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool refresh = false}) async {
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    final taskId = _taskId;
    if (clinicId == null || taskId == null) return;
    await context.read<ClinicOperationalController>().loadTaskDetail(
      clinicId,
      taskId,
      refresh: refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_taskId == null) return const _InvalidTaskRouteScreen();
    final clinic = context.watch<ClinicContextController>();
    final bootstrap = clinic.bootstrap;
    if (bootstrap == null ||
        !bootstrap.hasCapability(ClinicCapability.taskRead)) {
      return const _TaskCapabilityUnavailableScreen();
    }

    final detailState = context.watch<ClinicOperationalController>().taskDetail;
    final title = detailState.task?.taskType.label ?? 'Task detail';

    return Scaffold(
      backgroundColor: ClinicPalette.background,
      appBar: AppBar(
        title: Text(
          title,
          style: clinicTextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: ClinicPalette.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: detailState.isBusy ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _body(detailState, bootstrap)),
    );
  }

  Widget _body(ClinicTaskDetailState state, ClinicBootstrap bootstrap) {
    if (state.status == ClinicReadStatus.loading && state.task == null) {
      return const Center(
        child: CircularProgressIndicator(color: ClinicPalette.primary),
      );
    }

    final failure = state.failure;
    if (state.status == ClinicReadStatus.error &&
        failure != null &&
        state.task == null) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        color: ClinicPalette.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
          children: [
            _TaskReadErrorState(message: failure.message, onRetry: _load),
          ],
        ),
      );
    }

    final task = state.task;
    if (task == null) {
      return const Center(child: SizedBox.shrink());
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: ClinicPalette.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
          _TaskActionCard(
            task: task,
            caseDetail: state.caseDetail,
            bootstrap: bootstrap,
            busy: state.commandInFlight,
            onRunTask: _runTaskAction,
            onBlock: _blockTask,
            onRequestInformation: _requestInformation,
            onDecline: _declineCase,
            onRunCase: _runCaseAction,
            onHandover: _handoverTask,
          ),
          const SizedBox(height: 12),
          _TaskOverviewCard(task: task, bootstrap: bootstrap),
          const SizedBox(height: 12),
          _TaskTimingCard(task: task),
          const SizedBox(height: 12),
          _CaseContextCard(task: task),
        ],
      ),
    );
  }

  Future<void> _runTaskAction(
    ClinicTaskDetail task,
    ClinicTaskCommandAction action,
  ) async {
    if (action == ClinicTaskCommandAction.complete) {
      final confirmed = await _confirm(
        title: 'Complete task',
        message: 'Mark this task complete?',
        actionLabel: 'Complete',
      );
      if (!confirmed) return;
      if (!mounted) return;
    }
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final controller = context.read<ClinicOperationalController>();
    final result = switch (action) {
      ClinicTaskCommandAction.acknowledge => await controller.acknowledgeTask(
        clinicId,
        task,
      ),
      ClinicTaskCommandAction.start => await controller.startTask(
        clinicId,
        task,
      ),
      ClinicTaskCommandAction.unblock => await controller.unblockTask(
        clinicId,
        task,
      ),
      ClinicTaskCommandAction.complete => await controller.completeTask(
        clinicId,
        task,
      ),
      ClinicTaskCommandAction.block => const ClinicTaskCommandResult.failure(
        ClinicFailure.unexpected,
      ),
    };
    _showCommandResult(result);
  }

  Future<void> _blockTask(ClinicTaskDetail task) async {
    final reason = await showModalBottomSheet<ClinicTaskBlockedReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClinicPalette.surface,
      builder: (_) => const _BlockReasonSheet(),
    );
    if (reason == null || !mounted) return;
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final result = await context.read<ClinicOperationalController>().blockTask(
      clinicId,
      task,
      reason,
    );
    _showCommandResult(result);
  }

  Future<void> _handoverTask(ClinicTaskDetail task) async {
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final controller = context.read<ClinicOperationalController>();
    await controller.loadHandoverTargets(clinicId, task, refresh: true);
    if (!mounted) return;
    final request = await showModalBottomSheet<_HandoverRequestInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClinicPalette.surface,
      builder: (_) => _HandoverSheet(task: task),
    );
    if (request == null || !mounted) return;
    final result = await context
        .read<ClinicOperationalController>()
        .initiateHandover(
          clinicId,
          task,
          target: request.target,
          reason: request.reason,
        );
    _showCommandResult(result);
  }

  Future<void> _runCaseAction(
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail,
    ClinicCaseCommandAction action,
  ) async {
    if (action == ClinicCaseCommandAction.readyForPlanning) {
      final confirmed = await _confirm(
        title: 'Ready for planning',
        message: 'Move this request to planning?',
        actionLabel: 'Confirm',
      );
      if (!confirmed) return;
      if (!mounted) return;
    }
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final controller = context.read<ClinicOperationalController>();
    final result = switch (action) {
      ClinicCaseCommandAction.startReview => await controller.startReview(
        clinicId,
        task,
        caseDetail,
      ),
      ClinicCaseCommandAction.readyForPlanning =>
        await controller.readyForPlanning(clinicId, task, caseDetail),
      ClinicCaseCommandAction.requestInformation =>
        const ClinicTaskCommandResult.failure(ClinicFailure.unexpected),
      ClinicCaseCommandAction.decline => const ClinicTaskCommandResult.failure(
        ClinicFailure.unexpected,
      ),
    };
    _showCommandResult(result);
  }

  Future<void> _requestInformation(
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail,
  ) async {
    final request = await showModalBottomSheet<_InformationRequestInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClinicPalette.surface,
      builder: (_) => const _InformationRequestSheet(),
    );
    if (request == null || !mounted) return;
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final result = await context
        .read<ClinicOperationalController>()
        .requestInformation(
          clinicId,
          task,
          caseDetail,
          reason: request.reason,
          patientInstruction: request.patientInstruction,
        );
    _showCommandResult(result);
  }

  Future<void> _declineCase(
    ClinicTaskDetail task,
    ClinicCaseDetail caseDetail,
  ) async {
    final reason = await showModalBottomSheet<ClinicCaseDeclineReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClinicPalette.surface,
      builder: (_) => const _DeclineReasonSheet(),
    );
    if (reason == null || !mounted) return;
    final confirmed = await _confirm(
      title: 'Decline request',
      message: 'Decline this request?',
      actionLabel: 'Decline',
    );
    if (!confirmed || !mounted) return;
    final clinicId = context.read<ClinicContextController>().selectedClinicId;
    if (clinicId == null) return;
    final result = await context
        .read<ClinicOperationalController>()
        .declineCase(clinicId, task, caseDetail, reason: reason);
    _showCommandResult(result);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showCommandResult(ClinicTaskCommandResult result) {
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

class _InvalidTaskRouteScreen extends StatelessWidget {
  const _InvalidTaskRouteScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClinicPalette.background,
    appBar: AppBar(title: const Text('Task detail')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('This task is not available.', textAlign: TextAlign.center),
      ),
    ),
  );
}

class _TaskCapabilityUnavailableScreen extends StatelessWidget {
  const _TaskCapabilityUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return const ClinicPageScaffold(
      title: 'Task detail',
      subtitle:
          'This destination is not enabled for your current clinic access.',
      children: [
        ClinicCard(
          child: Text(
            'Your clinic capabilities do not include this operational view.',
          ),
        ),
      ],
    );
  }
}

class _TaskReadErrorState extends StatelessWidget {
  const _TaskReadErrorState({required this.message, required this.onRetry});

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

class _TaskActionCard extends StatelessWidget {
  const _TaskActionCard({
    required this.task,
    required this.caseDetail,
    required this.bootstrap,
    required this.busy,
    required this.onRunTask,
    required this.onBlock,
    required this.onRequestInformation,
    required this.onDecline,
    required this.onRunCase,
    required this.onHandover,
  });

  final ClinicTaskDetail task;
  final ClinicCaseDetail? caseDetail;
  final ClinicBootstrap bootstrap;
  final bool busy;
  final void Function(ClinicTaskDetail, ClinicTaskCommandAction) onRunTask;
  final void Function(ClinicTaskDetail) onBlock;
  final void Function(ClinicTaskDetail, ClinicCaseDetail) onRequestInformation;
  final void Function(ClinicTaskDetail, ClinicCaseDetail) onDecline;
  final void Function(ClinicTaskDetail) onHandover;
  final void Function(
    ClinicTaskDetail,
    ClinicCaseDetail,
    ClinicCaseCommandAction,
  )
  onRunCase;

  @override
  Widget build(BuildContext context) {
    final actions = _actions();

    return ClinicCard(
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PriorityChip(priority: task.priority),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ClinicStatusChip(
                label: task.status.label,
                active:
                    task.status != ClinicTaskStatus.blocked &&
                    task.status != ClinicTaskStatus.cancelled,
              ),
              if (task.status == ClinicTaskStatus.blocked)
                ClinicStatusChip(
                  label: task.blockedReason.label,
                  active: false,
                ),
              ClinicStatusChip(
                label: task.caseContext.situation.label,
                active: true,
              ),
            ],
          ),
          if (caseDetail != null) ...[
            const SizedBox(height: 12),
            _AdminReviewSnapshot(caseDetail: caseDetail!),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...actions.expand((action) => [action, const SizedBox(height: 8)]),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions() {
    if (!bootstrap.hasCapability(ClinicCapability.taskRead)) return const [];
    final membershipId = bootstrap.membership.membershipId;
    final positionOwned =
        task.status == ClinicTaskStatus.assigned &&
        task.assignedPositionId != null &&
        task.assignedMembershipId == null;
    if (positionOwned) {
      return [
        _primaryTaskButton(
          'Acknowledge',
          Icons.done_outlined,
          ClinicTaskCommandAction.acknowledge,
        ),
      ];
    }

    final personallyOwned = task.assignedMembershipId == membershipId;
    if (!personallyOwned) return const [];
    final canInitiateHandover =
        bootstrap.hasCapability(ClinicCapability.taskHandover) &&
        (task.status == ClinicTaskStatus.acknowledged ||
            task.status == ClinicTaskStatus.inProgress ||
            task.status == ClinicTaskStatus.blocked);
    final handoverButton = canInitiateHandover
        ? ClinicSecondaryButton(
            label: busy ? 'Working...' : 'Hand over task',
            icon: Icons.swap_horiz_outlined,
            onPressed: busy ? null : () => onHandover(task),
          )
        : null;

    if (personallyOwned && task.status == ClinicTaskStatus.acknowledged) {
      return [
        _primaryTaskButton(
          task.startedAt == null ? 'Start task' : 'Resume task',
          Icons.play_arrow_outlined,
          ClinicTaskCommandAction.start,
        ),
        ?handoverButton,
      ];
    }

    if (task.status == ClinicTaskStatus.blocked) {
      if (!task.isGenericBlocked) {
        return [?handoverButton];
      }
      return [
        _secondaryTaskButton(
          'Unblock task',
          Icons.lock_open_outlined,
          ClinicTaskCommandAction.unblock,
        ),
        ?handoverButton,
      ];
    }

    if (task.status != ClinicTaskStatus.inProgress) return const [];

    final buttons = <Widget>[];
    final detail = caseDetail;
    if (task.taskType == ClinicTaskType.administrativeReview &&
        detail != null &&
        bootstrap.canReviewCases) {
      if (detail.allows(ClinicCaseAction.startReview)) {
        buttons.add(
          _primaryCaseButton(
            'Start review',
            Icons.rate_review_outlined,
            detail,
            ClinicCaseCommandAction.startReview,
          ),
        );
      }
      if (detail.allows(ClinicCaseAction.requestInformation)) {
        buttons.add(
          ClinicSecondaryButton(
            label: busy ? 'Working...' : 'Request information',
            icon: Icons.contact_support_outlined,
            onPressed: busy ? null : () => onRequestInformation(task, detail),
          ),
        );
      }
      if (detail.allows(ClinicCaseAction.readyForPlanning)) {
        buttons.add(
          _primaryCaseButton(
            'Ready for planning',
            Icons.event_available_outlined,
            detail,
            ClinicCaseCommandAction.readyForPlanning,
          ),
        );
      }
      if (detail.allows(ClinicCaseAction.decline)) {
        buttons.add(
          ClinicSecondaryButton(
            label: busy ? 'Working...' : 'Decline request',
            icon: Icons.block_outlined,
            onPressed: busy ? null : () => onDecline(task, detail),
          ),
        );
      }
    }

    buttons.add(
      ClinicSecondaryButton(
        label: busy ? 'Working...' : 'Block task',
        icon: Icons.lock_outline,
        onPressed: busy ? null : () => onBlock(task),
      ),
    );
    if (handoverButton != null) {
      buttons.add(handoverButton);
    }

    if (task.taskType == ClinicTaskType.requestCoordination) {
      buttons.add(
        _primaryTaskButton(
          'Complete task',
          Icons.task_alt_outlined,
          ClinicTaskCommandAction.complete,
        ),
      );
    }
    return buttons;
  }

  Widget _primaryTaskButton(
    String label,
    IconData icon,
    ClinicTaskCommandAction action,
  ) {
    return ClinicPrimaryButton(
      label: busy ? 'Working...' : label,
      icon: icon,
      onPressed: busy ? null : () => onRunTask(task, action),
    );
  }

  Widget _secondaryTaskButton(
    String label,
    IconData icon,
    ClinicTaskCommandAction action,
  ) {
    return ClinicSecondaryButton(
      label: busy ? 'Working...' : label,
      icon: icon,
      onPressed: busy ? null : () => onRunTask(task, action),
    );
  }

  Widget _primaryCaseButton(
    String label,
    IconData icon,
    ClinicCaseDetail detail,
    ClinicCaseCommandAction action,
  ) {
    return ClinicPrimaryButton(
      label: busy ? 'Working...' : label,
      icon: icon,
      onPressed: busy ? null : () => onRunCase(task, detail, action),
    );
  }
}

class _AdminReviewSnapshot extends StatelessWidget {
  const _AdminReviewSnapshot({required this.caseDetail});

  final ClinicCaseDetail caseDetail;

  @override
  Widget build(BuildContext context) {
    final info = caseDetail.informationRequest;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClinicPalette.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClinicPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClinicInfoRow(label: 'Patient', value: caseDetail.patientDisplayName),
          ClinicInfoRow(
            label: 'Case status',
            value: caseDetail.administrativeStatus.label,
          ),
          ClinicInfoRow(
            label: 'Current step',
            value: caseDetail.currentStepLabel,
          ),
          if (info != null) ...[
            ClinicInfoRow(label: 'Info request', value: info.status.label),
            ClinicInfoRow(label: 'Info reason', value: info.reason.label),
          ],
        ],
      ),
    );
  }
}

class _HandoverRequestInput {
  const _HandoverRequestInput({required this.target, required this.reason});

  final ClinicHandoverTarget target;
  final ClinicHandoverReason reason;
}

class _HandoverSheet extends StatefulWidget {
  const _HandoverSheet({required this.task});

  final ClinicTaskDetail task;

  @override
  State<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<_HandoverSheet> {
  ClinicHandoverTarget? _target;
  ClinicHandoverReason? _reason;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicOperationalController>(
      builder: (context, controller, _) {
        final state = controller.handoverTargets;
        final targetStillPresent =
            _target == null ||
            state.items.any(
              (item) => item.membershipId == _target!.membershipId,
            );
        if (!targetStillPresent) _target = null;
        final loading = state.status == ClinicReadStatus.loading;
        final confirmEnabled =
            _target != null &&
            _reason != null &&
            !state.isBusy &&
            !controller.handoverCommandInFlight;

        return _CommandSheetFrame(
          title: 'Hand over task',
          confirmLabel: 'Request',
          confirmEnabled: confirmEnabled,
          onConfirm: () => Navigator.of(
            context,
          ).pop(_HandoverRequestInput(target: _target!, reason: _reason!)),
          children: [
            Text(
              widget.task.taskType.label,
              style: clinicTextStyle(
                fontSize: 13,
                color: ClinicPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            if (state.status == ClinicReadStatus.error &&
                state.failure != null) ...[
              Text(
                state.failure!.message,
                style: clinicTextStyle(
                  fontSize: 13,
                  color: ClinicPalette.warning,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (state.status == ClinicReadStatus.empty) ...[
              Text(
                'No eligible team member is currently available for handover.',
                style: clinicTextStyle(
                  fontSize: 13,
                  color: ClinicPalette.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<ClinicHandoverTarget>(
              initialValue: _target,
              decoration: const InputDecoration(
                labelText: 'Target employee',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final target in state.items)
                  DropdownMenuItem<ClinicHandoverTarget>(
                    value: target,
                    child: Text(target.label),
                  ),
              ],
              onChanged: state.isBusy
                  ? null
                  : (value) => setState(() => _target = value),
            ),
            if (state.hasNext) ...[
              const SizedBox(height: 10),
              ClinicSecondaryButton(
                label: state.isBusy ? 'Loading...' : 'Load more targets',
                icon: Icons.expand_more,
                onPressed: state.isBusy
                    ? null
                    : () => controller.loadNextHandoverTargets(),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<ClinicHandoverReason>(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final reason in ClinicHandoverReason.controlledReasons)
                  DropdownMenuItem<ClinicHandoverReason>(
                    value: reason,
                    child: Text(reason.label),
                  ),
              ],
              onChanged: (value) => setState(() => _reason = value),
            ),
          ],
        );
      },
    );
  }
}

class _BlockReasonSheet extends StatefulWidget {
  const _BlockReasonSheet();

  @override
  State<_BlockReasonSheet> createState() => _BlockReasonSheetState();
}

class _BlockReasonSheetState extends State<_BlockReasonSheet> {
  ClinicTaskBlockedReason? _selected;

  @override
  Widget build(BuildContext context) {
    return _CommandSheetFrame(
      title: 'Block task',
      confirmLabel: 'Block',
      confirmEnabled: _selected != null,
      onConfirm: () => Navigator.of(context).pop(_selected),
      children: [
        DropdownButtonFormField<ClinicTaskBlockedReason>(
          initialValue: _selected,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final reason in ClinicTaskBlockedReason.genericReasons)
              DropdownMenuItem<ClinicTaskBlockedReason>(
                value: reason,
                child: Text(reason.label),
              ),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
      ],
    );
  }
}

class _InformationRequestInput {
  const _InformationRequestInput({
    required this.reason,
    required this.patientInstruction,
  });

  final ClinicInformationRequestReason reason;
  final String? patientInstruction;
}

class _InformationRequestSheet extends StatefulWidget {
  const _InformationRequestSheet();

  @override
  State<_InformationRequestSheet> createState() =>
      _InformationRequestSheetState();
}

class _InformationRequestSheetState extends State<_InformationRequestSheet> {
  final TextEditingController _instruction = TextEditingController();
  ClinicInformationRequestReason? _selected;

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CommandSheetFrame(
      title: 'Request information',
      confirmLabel: 'Request',
      confirmEnabled: _selected != null,
      onConfirm: () {
        final instruction = _instruction.text.trim();
        Navigator.of(context).pop(
          _InformationRequestInput(
            reason: _selected!,
            patientInstruction: instruction.isEmpty ? null : instruction,
          ),
        );
      },
      children: [
        DropdownButtonFormField<ClinicInformationRequestReason>(
          initialValue: _selected,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final reason
                in ClinicInformationRequestReason.controlledReasons)
              DropdownMenuItem<ClinicInformationRequestReason>(
                value: reason,
                child: Text(reason.label),
              ),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _instruction,
          maxLength: 240,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Patient instruction',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _DeclineReasonSheet extends StatefulWidget {
  const _DeclineReasonSheet();

  @override
  State<_DeclineReasonSheet> createState() => _DeclineReasonSheetState();
}

class _DeclineReasonSheetState extends State<_DeclineReasonSheet> {
  ClinicCaseDeclineReason? _selected;

  @override
  Widget build(BuildContext context) {
    return _CommandSheetFrame(
      title: 'Decline request',
      confirmLabel: 'Continue',
      confirmEnabled: _selected != null,
      onConfirm: () => Navigator.of(context).pop(_selected),
      children: [
        DropdownButtonFormField<ClinicCaseDeclineReason>(
          initialValue: _selected,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final reason in ClinicCaseDeclineReason.controlledReasons)
              DropdownMenuItem<ClinicCaseDeclineReason>(
                value: reason,
                child: Text(reason.label),
              ),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
      ],
    );
  }
}

class _CommandSheetFrame extends StatelessWidget {
  const _CommandSheetFrame({
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.confirmEnabled,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final bool confirmEnabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: clinicTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClinicSecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClinicPrimaryButton(
                      label: confirmLabel,
                      onPressed: confirmEnabled ? onConfirm : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskOverviewCard extends StatelessWidget {
  const _TaskOverviewCard({required this.task, required this.bootstrap});

  final ClinicTaskDetail task;
  final ClinicBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClinicSectionTitle('Operational context'),
          const SizedBox(height: 8),
          ClinicInfoRow(
            label: 'Request',
            value: ClinicReferenceFormatter.requestReference(
              task.caseContext.sourceRequestId,
            ),
          ),
          ClinicInfoRow(
            label: 'Case',
            value: ClinicReferenceFormatter.caseReference(task.caseId),
          ),
          ClinicInfoRow(label: 'Task status', value: task.status.label),
          ClinicInfoRow(label: 'Task priority', value: task.priority.label),
          ClinicInfoRow(
            label: 'Responsibility',
            value: task.responsibilityType.label,
          ),
          ClinicInfoRow(label: 'Current position', value: _positionLabel(task)),
          ClinicInfoRow(label: 'Current owner', value: _ownerLabel(task)),
        ],
      ),
    );
  }

  String _positionLabel(ClinicTaskDetail task) {
    if (task.assignedPositionId == null) return 'Position unavailable';
    return 'Assigned position';
  }

  String _ownerLabel(ClinicTaskDetail task) {
    if (task.assignedMembershipId == null) return 'Position queue';
    if (task.assignedMembershipId == bootstrap.membership.membershipId) {
      return 'Assigned to you';
    }
    return 'Assigned to another team member';
  }
}

class _TaskTimingCard extends StatelessWidget {
  const _TaskTimingCard({required this.task});

  final ClinicTaskDetail task;

  @override
  Widget build(BuildContext context) {
    final ackDue = task.acknowledgementDueAt;
    final ackOverdue = ackDue != null
        ? ClinicDeadlineSemantics.isAcknowledgementOverdue(
            acknowledgementDueAt: ackDue,
            acknowledgedAt: task.acknowledgedAt,
            now: DateTime.now(),
          )
        : false;

    return ClinicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClinicSectionTitle('Timing'),
          const SizedBox(height: 8),
          ClinicInfoRow(
            label: ackOverdue ? 'ACK overdue' : 'ACK due',
            value: ClinicDateTimeFormatter.format(ackDue),
          ),
          ClinicInfoRow(
            label: 'Task due',
            value: ClinicDateTimeFormatter.format(task.dueAt),
          ),
          ClinicInfoRow(
            label: 'Created',
            value: ClinicDateTimeFormatter.format(task.createdAt),
          ),
          ClinicInfoRow(
            label: 'Acknowledged',
            value: ClinicDateTimeFormatter.format(task.acknowledgedAt),
          ),
          ClinicInfoRow(
            label: 'Started',
            value: ClinicDateTimeFormatter.format(task.startedAt),
          ),
          if (task.completedAt != null)
            ClinicInfoRow(
              label: 'Completed',
              value: ClinicDateTimeFormatter.format(task.completedAt),
            ),
        ],
      ),
    );
  }
}

class _CaseContextCard extends StatelessWidget {
  const _CaseContextCard({required this.task});

  final ClinicTaskDetail task;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClinicSectionTitle('Case context'),
          const SizedBox(height: 8),
          ClinicInfoRow(
            label: 'Case status',
            value: task.caseContext.intakeStatusLabel,
          ),
          ClinicInfoRow(
            label: 'Current step',
            value: task.caseContext.currentStepLabel,
          ),
          ClinicInfoRow(
            label: 'Situation',
            value: task.caseContext.situation.label,
          ),
          ClinicInfoRow(
            label: 'Case priority',
            value: task.caseContext.priority.label,
          ),
          ClinicInfoRow(
            label: 'Submitted',
            value: ClinicDateTimeFormatter.format(task.caseContext.submittedAt),
          ),
          ClinicInfoRow(
            label: 'Routing incident',
            value: task.caseContext.hasOpenRoutingIncident ? 'Open' : 'None',
          ),
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
