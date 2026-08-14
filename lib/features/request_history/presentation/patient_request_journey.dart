import 'package:flutter/material.dart';

import '../../request_core/domain/request_vocabulary.dart';

/// A deliberately small, patient-facing presentation of Module 05 status.
///
/// This is not a mirror of the Clinic workflow. In particular, information
/// requests stay inside the review stage and terminal outcomes stop the normal
/// path rather than being shown as completed progress.
enum PatientRequestJourneyStage {
  request,
  review,
  scheduling,
  confirmation,
  care,
  completion,
}

enum PatientRequestJourneyStageState { completed, current, upcoming, terminal }

enum PatientRequestJourneyTerminal { completed, declined, cancelled }

class PatientRequestJourneyStageView {
  const PatientRequestJourneyStageView({
    required this.stage,
    required this.state,
  });

  final PatientRequestJourneyStage stage;
  final PatientRequestJourneyStageState state;
}

class PatientRequestJourney {
  const PatientRequestJourney({
    required this.stages,
    this.terminal,
    this.requiresPatientAction = false,
    this.isUnknown = false,
  });

  final List<PatientRequestJourneyStageView> stages;
  final PatientRequestJourneyTerminal? terminal;
  final bool requiresPatientAction;
  final bool isUnknown;
}

/// The one status-to-journey mapping used by request detail presentation.
class PatientRequestJourneyMapper {
  const PatientRequestJourneyMapper._();

  static PatientRequestJourney fromStatus(
    PatientRequestStatus status,
  ) => switch (status) {
    PatientRequestStatus.requestReceived => _at(
      PatientRequestJourneyStage.request,
    ),
    PatientRequestStatus.underReview => _at(PatientRequestJourneyStage.review),
    PatientRequestStatus.informationRequired => _at(
      PatientRequestJourneyStage.review,
      requiresPatientAction: true,
    ),
    PatientRequestStatus.schedulingInProgress => _at(
      PatientRequestJourneyStage.scheduling,
    ),
    PatientRequestStatus.waitingForConfirmation => _at(
      PatientRequestJourneyStage.confirmation,
      requiresPatientAction: true,
    ),
    PatientRequestStatus.confirmed => _at(
      PatientRequestJourneyStage.care,
      current: false,
    ),
    PatientRequestStatus.careInProgress => _at(PatientRequestJourneyStage.care),
    PatientRequestStatus.completed => _terminal(
      PatientRequestJourneyTerminal.completed,
    ),
    PatientRequestStatus.declined => _terminal(
      PatientRequestJourneyTerminal.declined,
    ),
    PatientRequestStatus.cancelled => _terminal(
      PatientRequestJourneyTerminal.cancelled,
    ),
    PatientRequestStatus.unknown => const PatientRequestJourney(
      stages: [],
      isUnknown: true,
    ),
  };

  static PatientRequestJourney _at(
    PatientRequestJourneyStage currentStage, {
    bool current = true,
    bool requiresPatientAction = false,
  }) {
    return PatientRequestJourney(
      requiresPatientAction: requiresPatientAction,
      stages: PatientRequestJourneyStage.values
          .map(
            (stage) => PatientRequestJourneyStageView(
              stage: stage,
              state: stage.index < currentStage.index
                  ? PatientRequestJourneyStageState.completed
                  : stage == currentStage && current
                  ? PatientRequestJourneyStageState.current
                  : PatientRequestJourneyStageState.upcoming,
            ),
          )
          .toList(growable: false),
    );
  }

  static PatientRequestJourney _terminal(
    PatientRequestJourneyTerminal terminal,
  ) {
    if (terminal == PatientRequestJourneyTerminal.completed) {
      return PatientRequestJourney(
        terminal: terminal,
        stages: PatientRequestJourneyStage.values
            .map(
              (stage) => PatientRequestJourneyStageView(
                stage: stage,
                state: PatientRequestJourneyStageState.completed,
              ),
            )
            .toList(growable: false),
      );
    }

    // The current detail contract does not reveal which optional stages took
    // place before a decline/cancellation. Showing them would be misleading.
    return PatientRequestJourney(
      terminal: terminal,
      stages: const [
        PatientRequestJourneyStageView(
          stage: PatientRequestJourneyStage.request,
          state: PatientRequestJourneyStageState.completed,
        ),
      ],
    );
  }
}

class PatientRequestJourneyWidget extends StatelessWidget {
  const PatientRequestJourneyWidget({
    super.key,
    required this.journey,
    required this.submittedAt,
  });

  final PatientRequestJourney journey;
  final DateTime submittedAt;

  @override
  Widget build(BuildContext context) {
    if (journey.isUnknown) {
      return Card(
        child: Semantics(
          label:
              'Request journey: request updated. Refresh for the latest status.',
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request updated. Refresh for the latest status.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your request journey',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final stage in journey.stages)
              _JourneyStageTile(
                stage: stage,
                timestamp: stage.stage == PatientRequestJourneyStage.request
                    ? submittedAt
                    : null,
              ),
            if (journey.terminal != null)
              _TerminalTile(terminal: journey.terminal!),
            if (journey.requiresPatientAction) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Action required: the clinic needs your response.',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pending_actions_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Action required: the clinic needs your response.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JourneyStageTile extends StatelessWidget {
  const _JourneyStageTile({required this.stage, required this.timestamp});

  final PatientRequestJourneyStageView stage;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (stage.state) {
      PatientRequestJourneyStageState.completed => 'Completed',
      PatientRequestJourneyStageState.current => 'Current',
      PatientRequestJourneyStageState.upcoming => 'Upcoming',
      PatientRequestJourneyStageState.terminal => 'Terminal',
    };
    final icon = switch (stage.state) {
      PatientRequestJourneyStageState.completed => Icons.check_circle,
      PatientRequestJourneyStageState.current => Icons.radio_button_checked,
      PatientRequestJourneyStageState.upcoming => Icons.radio_button_unchecked,
      PatientRequestJourneyStageState.terminal => Icons.cancel,
    };
    final color = switch (stage.state) {
      PatientRequestJourneyStageState.completed => Theme.of(
        context,
      ).colorScheme.primary,
      PatientRequestJourneyStageState.current => Theme.of(
        context,
      ).colorScheme.secondary,
      PatientRequestJourneyStageState.upcoming => Theme.of(
        context,
      ).colorScheme.outline,
      PatientRequestJourneyStageState.terminal => Theme.of(
        context,
      ).colorScheme.error,
    };
    final title = _stageTitle(stage.stage);
    final when = timestamp == null
        ? null
        : _formatDateTime(context, timestamp!);

    return Semantics(
      label: '$title — $stateLabel${when == null ? '' : ', $when'}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, semanticLabel: stateLabel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(stateLabel),
                  if (when != null) Text(when),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalTile extends StatelessWidget {
  const _TerminalTile({required this.terminal});

  final PatientRequestJourneyTerminal terminal;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (terminal) {
      PatientRequestJourneyTerminal.completed => (
        'Request completed',
        Icons.task_alt,
      ),
      PatientRequestJourneyTerminal.declined => (
        'Request declined',
        Icons.cancel_outlined,
      ),
      PatientRequestJourneyTerminal.cancelled => (
        'Request cancelled',
        Icons.do_not_disturb_on_outlined,
      ),
    };
    final color = terminal == PatientRequestJourneyTerminal.completed
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Semantics(
      label: '$label — terminal',
      child: Row(
        children: [
          Icon(icon, color: color, semanticLabel: 'Terminal'),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _stageTitle(PatientRequestJourneyStage stage) => switch (stage) {
  PatientRequestJourneyStage.request => 'Request sent',
  PatientRequestJourneyStage.review => 'Clinic review',
  PatientRequestJourneyStage.scheduling => 'Scheduling',
  PatientRequestJourneyStage.confirmation => 'Confirmation',
  PatientRequestJourneyStage.care => 'Care',
  PatientRequestJourneyStage.completion => 'Completed',
};

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  final local = value.toLocal();
  return '${localizations.formatMediumDate(local)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
