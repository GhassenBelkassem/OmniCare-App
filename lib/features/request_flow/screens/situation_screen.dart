import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../patient_clinic/application/patient_clinic_directory_controller.dart';
import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/request_vocabulary.dart';
import 'pickup_screen.dart';
import 'review_screen.dart';

/// Step 3 — What kind of care does the patient need?
///
/// The three backend wire values, chosen explicitly by the patient. Urgency is
/// never inferred from age, history, symptoms, location or anything else — the
/// patient decides. Selecting AMBULANCE means the patient is requesting
/// medical transport; it does not mean an ambulance has been dispatched.
class SituationScreen extends StatefulWidget {
  const SituationScreen({super.key});

  @override
  State<SituationScreen> createState() => _SituationScreenState();
}

class _SituationScreenState extends State<SituationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final request = context.read<RequestSubmissionController>();
      final directory = context.read<PatientClinicDirectoryController>();
      final clinicId = request.selectedClinicId;
      if (clinicId != null && directory.detail?.clinicId != clinicId) {
        directory.fetchDetail(clinicId);
      }
    });
  }

  static const List<_CareOption> _options = [
    _CareOption(
      situation: RequestSituation.appointment,
      title: 'Planned care',
      description: 'I can visit the clinic and my situation is not urgent.',
      supporting: 'Consultation, examination or planned treatment',
      icon: Icons.calendar_month_outlined,
      color: _OptionColorRole.infoBlue,
    ),
    _CareOption(
      situation: RequestSituation.urgent,
      title: 'Urgent care',
      description:
          'I need medical attention soon and can safely reach the clinic.',
      supporting: 'The clinic will see that your request is urgent.',
      icon: Icons.priority_high_outlined,
      color: _OptionColorRole.urgentCoral,
    ),
    _CareOption(
      situation: RequestSituation.ambulance,
      title: 'I need medical transport',
      description:
          'I need help reaching medical care because I cannot travel normally.',
      icon: Icons.emergency_outlined,
      color: _OptionColorRole.clinicalCyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final request = context.watch<RequestSubmissionController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: OmniColors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: OmniColors.textPrimary,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'What kind of care do you need?',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: OmniColors.textPrimary,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.sm,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xxl,
              ),
              children: [
                Text(
                  'This helps the clinic prepare and route your request.',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.5,
                    color: OmniColors.textSecondary,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xl),
                _RequestContextLabel(),
                const SizedBox(height: OmniSpacing.xl),
                ..._options.map((option) {
                  final selected =
                      request.selectedSituation == option.situation;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: OmniSpacing.md),
                    child: _CareOptionCard(
                      option: option,
                      selected: selected,
                      onTap: () {
                        context
                            .read<RequestSubmissionController>()
                            .selectSituation(option.situation);
                      },
                    ),
                  );
                }),
                const SizedBox(height: OmniSpacing.lg),
                _HelpMeChoose(
                  onTap: () => _showHelpSheet(context),
                ),
              ],
            ),
          ),
          _ContinueFooter(
            enabled: request.selectedSituation != null,
            onPressed: () {
              final next =
                  request.selectedSituation == RequestSituation.ambulance
                      ? const PickupScreen()
                      : const ReviewScreen();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => next),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HelpSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Request context label
// ---------------------------------------------------------------------------

class _RequestContextLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final request = context.watch<RequestSubmissionController>();
    final directory = context.watch<PatientClinicDirectoryController>();

    final subjectLabel = request.subject.isSelf ? 'Me' : 'Family member';
    final clinicName = directory.detail?.displayName;

    final parts = <String>['For $subjectLabel'];
    if (clinicName != null && clinicName.isNotEmpty) {
      parts.add(clinicName);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.base,
        vertical: OmniSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Text(
        parts.join(' \u00B7 '),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OmniColors.textSecondary,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Care option card
// ---------------------------------------------------------------------------

class _CareOptionCard extends StatelessWidget {
  const _CareOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _CareOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = option.color.colors;

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${option.title}. ${option.description}. ${selected ? 'Selected' : 'Not selected'}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: selected ? colors.soft : Colors.white,
            borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
            border: Border.all(
              color: selected ? colors.accent : OmniColors.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.soft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(option.icon, color: colors.accent, size: 24),
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OmniColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: OmniSpacing.xs),
                      Text(
                        option.description,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: OmniColors.textSecondary,
                                ),
                      ),
                      if (option.supporting != null) ...[
                        const SizedBox(height: OmniSpacing.xs),
                        Text(
                          option.supporting!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: OmniColors.textTertiary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _SelectionIndicator(
                  selected: selected,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selection indicator
// ---------------------------------------------------------------------------

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({
    required this.selected,
    required this.color,
  });

  final bool selected;
  final Color color;

  static const double _size = 26;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : OmniColors.borderStrong,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Color roles per option
// ---------------------------------------------------------------------------

enum _OptionColorRole { infoBlue, urgentCoral, clinicalCyan }

extension _OptionColorRoleColors on _OptionColorRole {
  _ColorPair get colors {
    switch (this) {
      case _OptionColorRole.infoBlue:
        return _ColorPair(accent: OmniColors.infoBlue, soft: OmniColors.infoBlueSoft);
      case _OptionColorRole.urgentCoral:
        return _ColorPair(
            accent: OmniColors.urgentCoral, soft: OmniColors.urgentCoralSoft);
      case _OptionColorRole.clinicalCyan:
        return _ColorPair(
            accent: OmniColors.clinicalCyan, soft: OmniColors.clinicalCyanSoft);
    }
  }
}

class _ColorPair {
  const _ColorPair({required this.accent, required this.soft});
  final Color accent;
  final Color soft;
}

// ---------------------------------------------------------------------------
// Care option model
// ---------------------------------------------------------------------------

class _CareOption {
  const _CareOption({
    required this.situation,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.supporting,
  });

  final RequestSituation situation;
  final String title;
  final String description;
  final IconData icon;
  final _OptionColorRole color;
  final String? supporting;
}

// ---------------------------------------------------------------------------
// Help me choose
// ---------------------------------------------------------------------------

class _HelpMeChoose extends StatelessWidget {
  const _HelpMeChoose({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Not sure which one to choose?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: OmniColors.textTertiary,
                ),
          ),
          const SizedBox(height: OmniSpacing.xs),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: OmniColors.infoBlue,
            ),
            label: const Text(
              'Help me choose',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: OmniColors.infoBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continue footer
// ---------------------------------------------------------------------------

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: OmniColors.borderLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Help bottom sheet
// ---------------------------------------------------------------------------

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = screenHeight * 0.56;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OmniRadii.sheet),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OmniRadii.sheet),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(
                  top: OmniSpacing.sm + 2,
                  bottom: OmniSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: OmniColors.borderStrong,
                  borderRadius: BorderRadius.circular(OmniRadii.pill),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  0,
                  OmniSpacing.lg,
                  OmniSpacing.xl,
                ),
                children: [
                  Text(
                    'Which option fits best?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  _HelpOption(
                    icon: Icons.calendar_month_outlined,
                    color: OmniColors.infoBlue,
                    title: 'Planned care',
                    description:
                        'For non-urgent care that can be planned normally, such as a consultation, examination or planned treatment.',
                  ),
                  const SizedBox(height: OmniSpacing.base),
                  _HelpOption(
                    icon: Icons.priority_high_outlined,
                    color: OmniColors.urgentCoral,
                    title: 'Urgent care',
                    description:
                        'For a problem that needs medical attention soon, when you can still safely reach the clinic.',
                  ),
                  const SizedBox(height: OmniSpacing.base),
                  _HelpOption(
                    icon: Icons.emergency_outlined,
                    color: OmniColors.clinicalCyan,
                    title: 'Medical transport',
                    description:
                        'When you need assistance getting to medical care because normal travel is not suitable.',
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(OmniSpacing.base),
                    decoration: BoxDecoration(
                      color: OmniColors.urgentCoralSoft,
                      borderRadius: BorderRadius.circular(OmniRadii.field),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: OmniColors.urgentCoral,
                        ),
                        const SizedBox(width: OmniSpacing.sm + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need immediate emergency help?',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: OmniColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: OmniSpacing.xs),
                              Text(
                                'Use emergency services for immediate danger instead of waiting for a clinic request.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: OmniColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Help sheet option row
// ---------------------------------------------------------------------------

class _HelpOption extends StatelessWidget {
  const _HelpOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: OmniSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OmniColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.45,
                      color: OmniColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
