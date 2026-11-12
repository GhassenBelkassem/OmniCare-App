import 'package:flutter/material.dart';

import '../../request_core/domain/request_vocabulary.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';

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

enum PatientRequestJourneyTerminal { completed, declined, cancelled, noShow }

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
    PatientRequestStatus.noShow => _terminal(
      PatientRequestJourneyTerminal.noShow,
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

// ---------------------------------------------------------------------------
// Restyled journey widget — vertical timeline with connecting line
// ---------------------------------------------------------------------------

class PatientRequestJourneyWidget extends StatelessWidget {
  const PatientRequestJourneyWidget({
    super.key,
    required this.journey,
    required this.submittedAt,
    this.currentStatusAccent,
  });

  final PatientRequestJourney journey;
  final DateTime submittedAt;

  /// Semantic accent color for the current stage. Derived from status.
  final Color? currentStatusAccent;

  @override
  Widget build(BuildContext context) {
    if (journey.isUnknown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your request journey',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(OmniSpacing.base),
            decoration: BoxDecoration(
              color: OmniColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(OmniRadii.card),
            ),
            child: Semantics(
              label: 'Request journey: request updated. Refresh for the latest status.',
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: OmniColors.slateBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Request updated. Refresh for the latest status.',
                      style: TextStyle(fontSize: 13, color: OmniColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final accent = currentStatusAccent ?? OmniColors.primaryAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your request journey',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < journey.stages.length; i++)
          _JourneyStep(
            stage: journey.stages[i],
            isLast: i == journey.stages.length - 1 && journey.terminal == null,
            isOnly: journey.stages.length == 1 && journey.terminal == null,
            timestamp: journey.stages[i].stage == PatientRequestJourneyStage.request
                ? submittedAt
                : null,
            accent: accent,
          ),
        if (journey.terminal != null)
          _TerminalStep(terminal: journey.terminal!),
      ],
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.stage,
    required this.isLast,
    this.isOnly = false,
    this.timestamp,
    this.accent = OmniColors.primaryAction,
  });

  final PatientRequestJourneyStageView stage;
  final bool isLast;
  final bool isOnly;
  final DateTime? timestamp;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final title = _stageTitle(stage.stage);
    final description = _stageDescription(stage.stage);
    final isCurrent = stage.state == PatientRequestJourneyStageState.current;
    final isCompleted = stage.state == PatientRequestJourneyStageState.completed;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column: icon + connecting line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _stateIcon(stage.state, accent),
                if (!isLast && !isOnly)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? OmniColors.freshMint.withValues(alpha: 0.4)
                          : OmniColors.borderLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast || isOnly ? 0 : 20),
              child: isCurrent
                  ? _CurrentStageCard(
                      title: title,
                      description: description,
                      timestamp: timestamp,
                      accent: accent,
                    )
                  : _StageContent(
                      title: title,
                      description: description,
                      timestamp: timestamp,
                      state: stage.state,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _stateColor(PatientRequestJourneyStageState state, Color accent) {
    return switch (state) {
      PatientRequestJourneyStageState.completed => OmniColors.freshMint,
      PatientRequestJourneyStageState.current => accent,
      PatientRequestJourneyStageState.upcoming => OmniColors.borderLight,
      PatientRequestJourneyStageState.terminal => OmniColors.error,
    };
  }

  static Widget _stateIcon(PatientRequestJourneyStageState state, Color accent) {
    final color = _stateColor(state, accent);
    return switch (state) {
      PatientRequestJourneyStageState.completed => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: OmniColors.mintSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: OmniColors.freshMint),
      ),
      PatientRequestJourneyStageState.current => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.circle, size: 8, color: Colors.white),
      ),
      PatientRequestJourneyStageState.upcoming => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: OmniColors.surfaceSecondary,
          border: Border.all(color: OmniColors.borderLight, width: 1.5),
        ),
      ),
      PatientRequestJourneyStageState.terminal => Icon(
        Icons.cancel,
        size: 24,
        color: color,
      ),
    };
  }
}

/// Current stage: highlighted card with badge, strong title, description, timestamp.
class _CurrentStageCard extends StatelessWidget {
  const _CurrentStageCard({
    required this.title,
    required this.description,
    this.timestamp,
    required this.accent,
  });

  final String title;
  final String description;
  final DateTime? timestamp;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(OmniRadii.pill),
                ),
                child: Text(
                  'Current',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: OmniColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDateTime(context, timestamp!),
              style: TextStyle(
                fontSize: 12,
                color: accent.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Non-current stage content.
class _StageContent extends StatelessWidget {
  const _StageContent({
    required this.title,
    required this.description,
    this.timestamp,
    required this.state,
  });

  final String title;
  final String description;
  final DateTime? timestamp;
  final PatientRequestJourneyStageState state;

  @override
  Widget build(BuildContext context) {
    final isCompleted = state == PatientRequestJourneyStageState.completed;
    final isUpcoming = state == PatientRequestJourneyStageState.upcoming;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isUpcoming ? OmniColors.textTertiary : OmniColors.textPrimary,
            ),
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatDateTime(context, timestamp!),
                style: const TextStyle(
                  fontSize: 12,
                  color: OmniColors.textTertiary,
                ),
              ),
            ),
          if (isCompleted || isUpcoming)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isUpcoming
                      ? OmniColors.textTertiary
                      : OmniColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TerminalStep extends StatelessWidget {
  const _TerminalStep({required this.terminal});
  final PatientRequestJourneyTerminal terminal;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (terminal) {
      PatientRequestJourneyTerminal.completed => (
        'Request completed',
        Icons.check_circle,
        OmniColors.freshMint,
      ),
      PatientRequestJourneyTerminal.declined => (
        'Request declined',
        Icons.cancel_outlined,
        OmniColors.urgentCoral,
      ),
      PatientRequestJourneyTerminal.cancelled => (
        'Request cancelled',
        Icons.do_not_disturb_on_outlined,
        OmniColors.slateBlue,
      ),
      PatientRequestJourneyTerminal.noShow => (
        OmniLocalizations.of(context).requestNoShowLabel,
        Icons.event_busy_outlined,
        OmniColors.slateBlue,
      ),
    };

    return Semantics(
      label: '$label \u2014 terminal',
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
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

String _stageDescription(PatientRequestJourneyStage stage) => switch (stage) {
  PatientRequestJourneyStage.request => 'Your request has been sent.',
  PatientRequestJourneyStage.review => 'The clinic team reviews your request.',
  PatientRequestJourneyStage.scheduling => 'The clinic arranges the next step.',
  PatientRequestJourneyStage.confirmation =>
    'Confirmation happens before care when required.',
  PatientRequestJourneyStage.care => 'Your care takes place.',
  PatientRequestJourneyStage.completion => 'The request is complete.',
};

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  final local = value.toLocal();
  return '${localizations.formatMediumDate(local)} \u00b7 ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
