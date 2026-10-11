import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../emergency/widgets/body_map_widget.dart';
import '../../emergency/widgets/medical_intake_widgets.dart';
import '../../patient_doctor/data/doctor_directory_models.dart';
import '../../patient_doctor/data/doctor_models.dart';
import '../../patient_doctor/presentation/widgets/doctor_card.dart';
import '../../patient_doctor/presentation/widgets/doctor_search_field.dart';
import '../data/synthetic_cabinet_directory_source.dart';
import '../data/synthetic_home_location_gateway.dart';
import '../data/synthetic_urgent_journey_fixture_source.dart';
import '../domain/urgent_journey_models.dart';
import 'p4_urgent_copy.dart';

class P4StructuredTriageScreen extends StatefulWidget {
  const P4StructuredTriageScreen({
    super.key,
    required this.availability,
    required this.onBack,
    required this.onContinue,
    required this.onRetry,
    this.initialValue,
  });

  final SyntheticTriageAvailability availability;
  final VoidCallback onBack;
  final ValueChanged<PatientTriageProjection> onContinue;
  final VoidCallback onRetry;
  final PatientTriageProjection? initialValue;

  @override
  State<P4StructuredTriageScreen> createState() =>
      _P4StructuredTriageScreenState();
}

class _P4StructuredTriageScreenState extends State<P4StructuredTriageScreen> {
  late final TextEditingController _note = TextEditingController(
    text: widget.initialValue?.privateNarrative?.value ?? '',
  );
  late List<String> _areas = [
    ...?widget.initialValue?.minimum.bodyAreaCodes.where(
      (area) => area != 'BODY_AREA_PENDING_APPROVAL',
    ),
  ];
  late double _pain = (widget.initialValue?.minimum.painIntensity ?? 1)
      .clamp(1, 10)
      .toDouble();
  bool _front = true;
  bool _showValidation = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _toggleArea(String area) => setState(() {
    _showValidation = false;
    _areas = _areas.contains(area)
        ? _areas.where((value) => value != area).toList()
        : [..._areas, area];
  });

  void _continue() {
    if (_areas.isEmpty) {
      setState(() => _showValidation = true);
      return;
    }
    final intensity = _pain.round();
    final code = intensity <= 3
        ? 'SYNTHETIC_MILD_PENDING_APPROVAL'
        : intensity <= 6
        ? 'SYNTHETIC_MODERATE_PENDING_APPROVAL'
        : 'SYNTHETIC_SEVERE_PENDING_APPROVAL';
    widget.onContinue(
      PatientTriageProjection(
        minimum: StructuredTriageMinimumProjection(
          bodyAreaCodes: _areas,
          painIntensity: intensity,
          painBandCode: code,
          painBandDisplayKey: intensity <= 3
              ? 'p4_pain_low'
              : intensity <= 6
              ? 'p4_pain_medium'
              : 'p4_pain_severe',
        ),
        privateNarrative: _note.text.trim().isEmpty
            ? null
            : PatientPrivateNarrativeProjection(value: _note.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availability == SyntheticTriageAvailability.loading) {
      return _statePage(
        key: 'p4-triage-loading',
        icon: const CircularProgressIndicator(),
        text: p4Copy(context, 'loading'),
      );
    }
    if (widget.availability == SyntheticTriageAvailability.unavailable) {
      return _statePage(
        key: 'p4-triage-unavailable',
        icon: const Icon(Icons.cloud_off_outlined, size: 44),
        text: p4Copy(context, 'p4_triage_unavailable'),
        retry: widget.onRetry,
      );
    }
    return _setupScaffold(
      key: const ValueKey('p4-triage-stage'),
      context: context,
      title: p4Copy(context, 'p4_triage_title'),
      onBack: widget.onBack,
      actionLabel: p4Copy(context, 'p4_continue'),
      onAction: _continue,
      body: [
        _notice(context, p4Copy(context, 'p4_triage_intro')),
        const SizedBox(height: OmniSpacing.md),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              label: Text(p4Copy(context, 'p4_body_front')),
            ),
            ButtonSegment(
              value: false,
              label: Text(p4Copy(context, 'p4_body_back')),
            ),
          ],
          selected: {_front},
          onSelectionChanged: (value) => setState(() => _front = value.single),
        ),
        const SizedBox(height: OmniSpacing.md),
        MuscleAnatomyMap(
          selectedParts: _areas,
          onPartClick: _toggleArea,
          isFront: _front,
          frontTitle: p4Copy(context, 'p4_body_front'),
          backTitle: p4Copy(context, 'p4_body_back'),
          instruction: p4Copy(context, 'p4_body_instruction'),
        ),
        if (_areas.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.md),
          SelectedBodyAreasPanel(
            parts: _areas,
            onRemove: _toggleArea,
            onReset: () => setState(() => _areas = []),
            title: p4Copy(context, 'p4_selected_areas'),
            resetLabel: p4Copy(context, 'p4_reset'),
          ),
        ],
        if (_showValidation) ...[
          const SizedBox(height: OmniSpacing.sm),
          Text(
            p4Copy(context, 'p4_validation'),
            key: const ValueKey('p4-triage-validation'),
            style: const TextStyle(color: OmniColors.urgentCoral),
          ),
        ],
        const SizedBox(height: OmniSpacing.lg),
        PainLevelControl(
          value: _pain,
          onChanged: (value) => setState(() => _pain = value),
          title: p4Copy(context, 'p4_pain_title'),
          lowLabel: p4Copy(context, 'p4_pain_low'),
          mediumLabel: p4Copy(context, 'p4_pain_medium'),
          highLabel: p4Copy(context, 'p4_pain_severe'),
        ),
        const SizedBox(height: OmniSpacing.lg),
        TextField(
          key: const ValueKey('p4-private-narrative'),
          controller: _note,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: p4Copy(context, 'p4_private_note'),
            helperText: p4Copy(context, 'p4_private_note_policy'),
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: OmniSpacing.md),
        _notice(context, p4Copy(context, 'p4_voice_disabled')),
      ],
    );
  }

  Widget _statePage({
    required String key,
    required Widget icon,
    required String text,
    VoidCallback? retry,
  }) => _setupScaffold(
    key: ValueKey(key),
    context: context,
    title: p4Copy(context, 'p4_triage_title'),
    onBack: widget.onBack,
    body: [
      const SizedBox(height: 80),
      Center(child: icon),
      const SizedBox(height: OmniSpacing.md),
      Center(child: Text(text, textAlign: TextAlign.center)),
      if (retry != null) ...[
        const SizedBox(height: OmniSpacing.md),
        Center(
          child: OutlinedButton(
            key: const ValueKey('p4-triage-retry'),
            onPressed: retry,
            child: Text(p4Copy(context, 'p4_retry')),
          ),
        ),
      ],
    ],
  );
}

class P4HomeDestinationScreen extends StatefulWidget {
  const P4HomeDestinationScreen({
    super.key,
    required this.gateway,
    required this.onBack,
    required this.onConfirmed,
  });

  final SyntheticHomeLocationGateway gateway;
  final VoidCallback onBack;
  final ValueChanged<HomeDestinationDraft> onConfirmed;

  @override
  State<P4HomeDestinationScreen> createState() =>
      _P4HomeDestinationScreenState();
}

class _P4HomeDestinationScreenState extends State<P4HomeDestinationScreen> {
  late HomeDestinationDraft _value = widget.gateway.snapshot();

  void _update(HomeDestinationDraft value) => setState(() => _value = value);
  void _confirm() {
    final value = widget.gateway.confirm();
    _update(value);
    if (value.status == HomeDestinationStatus.confirmed) {
      widget.onConfirmed(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateText = switch ((
      _value.permission,
      _value.service,
      _value.quality,
      _value.status,
    )) {
      (_, _, _, HomeDestinationStatus.offlineUnsent) => p4Copy(
        context,
        'p4_offline_unsent',
      ),
      (HomeLocationPermission.deniedForever, _, _, _) => p4Copy(
        context,
        'p4_permission_forever',
      ),
      (HomeLocationPermission.denied, _, _, _) => p4Copy(
        context,
        'p4_permission_denied',
      ),
      (_, HomeLocationService.unavailable, _, _) => p4Copy(
        context,
        'p4_gps_unavailable',
      ),
      (_, _, HomeLocationQuality.acquiring, _) => p4Copy(
        context,
        'p4_acquiring',
      ),
      (_, _, HomeLocationQuality.lowAccuracy, _) => p4Copy(
        context,
        'p4_low_accuracy',
      ),
      (_, _, HomeLocationQuality.stale, _) => p4Copy(context, 'p4_stale'),
      _ => _value.displayAddress ?? p4Copy(context, 'p4_permission_request'),
    };
    return _setupScaffold(
      key: const ValueKey('p4-home-destination-stage'),
      context: context,
      title: p4Copy(context, 'p4_home_destination'),
      onBack: widget.onBack,
      actionLabel: p4Copy(context, 'p4_confirm_destination'),
      onAction: _value.canConfirm ? _confirm : null,
      body: [
        _notice(context, p4Copy(context, 'p4_location_private')),
        const SizedBox(height: OmniSpacing.lg),
        Container(
          key: ValueKey(
            'p4-location-${_value.quality.name}-${_value.permission.name}',
          ),
          padding: const EdgeInsets.all(OmniSpacing.lg),
          decoration: _cardDecoration,
          child: Column(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 42,
                color: OmniColors.deepTeal,
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(stateText, textAlign: TextAlign.center),
              if (_value.accuracyMeters != null)
                Text(
                  '± ${_value.accuracyMeters!.round()} m',
                  textDirection: TextDirection.ltr,
                ),
            ],
          ),
        ),
        if (!_value.mapSearchAvailable) ...[
          const SizedBox(height: OmniSpacing.md),
          _notice(context, p4Copy(context, 'p4_map_unavailable')),
        ],
        const SizedBox(height: OmniSpacing.lg),
        OutlinedButton.icon(
          key: const ValueKey('p4-location-permission'),
          onPressed: () {
            final permission = widget.gateway.requestSyntheticPermission();
            _update(permission);
            if (permission.permission == HomeLocationPermission.granted) {
              _update(widget.gateway.acquireSyntheticFix());
            }
          },
          icon: const Icon(Icons.my_location_outlined),
          label: Text(p4Copy(context, 'p4_permission_request')),
        ),
        const SizedBox(height: OmniSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('p4-location-manual'),
          onPressed: () =>
              _update(widget.gateway.chooseSyntheticManualAddress()),
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: Text(p4Copy(context, 'p4_manual_address')),
        ),
      ],
    );
  }
}

class P4CabinetDirectoryScreen extends StatefulWidget {
  const P4CabinetDirectoryScreen({
    super.key,
    required this.source,
    required this.onBack,
    required this.onConfirmed,
    this.initialTarget,
  });

  final SyntheticCabinetDirectorySource source;
  final VoidCallback onBack;
  final ValueChanged<CabinetTargetProjection> onConfirmed;
  final CabinetTargetProjection? initialTarget;

  @override
  State<P4CabinetDirectoryScreen> createState() =>
      _P4CabinetDirectoryScreenState();
}

class _P4CabinetDirectoryScreenState extends State<P4CabinetDirectoryScreen> {
  late final TextEditingController _searchController = TextEditingController();
  late SyntheticCabinetDirectorySnapshot _snapshot = widget.source.search();
  late CabinetTargetProjection? _selected = widget.initialTarget;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() => _snapshot = widget.source.search(query));
  }

  @override
  Widget build(BuildContext context) => _setupScaffold(
    key: const ValueKey('p4-cabinet-directory-stage'),
    context: context,
    title: p4Copy(context, 'p4_cabinet_title'),
    onBack: widget.onBack,
    actionLabel: p4Copy(context, 'p4_select_target'),
    onAction: _selected == null ? null : () => widget.onConfirmed(_selected!),
    body: [
      _notice(context, p4Copy(context, 'p4_cabinet_intro')),
      const SizedBox(height: OmniSpacing.md),
      DoctorSearchField(
        key: const ValueKey('p4-cabinet-search'),
        controller: _searchController,
        onChanged: _search,
      ),
      const SizedBox(height: OmniSpacing.md),
      if (_snapshot.status == SyntheticCabinetDirectoryStatus.loading)
        const Center(
          child: CircularProgressIndicator(
            key: ValueKey('p4-directory-loading'),
          ),
        )
      else if (_snapshot.status == SyntheticCabinetDirectoryStatus.failure)
        _notice(
          context,
          p4Copy(context, 'p4_directory_failure'),
          key: const ValueKey('p4-directory-failure'),
        )
      else if (_snapshot.status == SyntheticCabinetDirectoryStatus.empty)
        _notice(
          context,
          p4Copy(context, 'p4_directory_empty'),
          key: const ValueKey('p4-directory-empty'),
        )
      else
        for (final target in _snapshot.candidates) ...[
          _CabinetTargetCard(
            target: target,
            selected: _selected?.doctorRef == target.doctorRef,
            onTap: () => setState(() => _selected = target),
          ),
          const SizedBox(height: OmniSpacing.md),
        ],
    ],
  );
}

class _CabinetTargetCard extends StatelessWidget {
  const _CabinetTargetCard({
    required this.target,
    required this.selected,
    required this.onTap,
  });
  final CabinetTargetProjection target;
  final bool selected;
  final VoidCallback onTap;

  DoctorListItem get _doctorCard => DoctorListItem(
    id: target.doctorRef.value,
    name: target.doctorDisplayName,
    specialty: target.specialtyLabel,
    matchingPracticeLocation: DoctorMatchingPracticeLocation(
      practiceLocationId: target.cabinetRef.value,
      name: target.cabinetDisplayName,
      city: target.publicAddress,
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    selected: selected,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: selected ? OmniColors.mintSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(OmniRadii.card + 2),
        border: Border.all(
          color: selected ? OmniColors.freshMint : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DoctorListCard(
            key: ValueKey('p4-cabinet-${target.cabinetRef.value}'),
            doctor: _doctorCard,
            onTap: onTap,
          ),
          const SizedBox(height: OmniSpacing.xs),
          Material(
            color: selected ? OmniColors.mintSoft : OmniColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(OmniRadii.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.md,
                  vertical: OmniSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_hospital_outlined,
                      size: 18,
                      color: OmniColors.deepTeal,
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.urgentCapabilityLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: OmniColors.deepTeal,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '${target.quote.displayAmount} · '
                            '${p4Copy(context, 'p4_fee_version')} '
                            '${target.quote.feeVersion}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: OmniColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? OmniColors.deepTeal
                          : OmniColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class P4AttemptSetupReviewScreen extends StatelessWidget {
  const P4AttemptSetupReviewScreen({
    super.key,
    required this.attempt,
    required this.onBack,
    required this.onEditTriage,
    required this.onEditModeSpecific,
    required this.onConfirm,
    this.pendingCabinetTarget,
  });
  final UrgentAttemptProjection attempt;
  final VoidCallback onBack;
  final VoidCallback onEditTriage;
  final VoidCallback onEditModeSpecific;
  final VoidCallback onConfirm;
  final CabinetTargetProjection? pendingCabinetTarget;

  @override
  Widget build(BuildContext context) {
    final home = attempt is HomeAttemptProjection;
    final target =
        pendingCabinetTarget ??
        (attempt is CabinetAttemptProjection
            ? (attempt as CabinetAttemptProjection).target
            : null);
    return _setupScaffold(
      key: const ValueKey('p4-setup-review-stage'),
      context: context,
      title: p4Copy(context, 'p4_review_title'),
      onBack: onBack,
      actionLabel: p4Copy(context, 'p4_confirm_setup'),
      onAction: onConfirm,
      body: [
        _ReviewCard(
          title: p4Copy(context, 'p4_triage_title'),
          value:
              '${attempt.triage.minimum.bodyAreaCodes.length} · ${attempt.triage.minimum.painIntensity}/10',
          editLabel: p4Copy(context, 'p4_edit_triage'),
          onEdit: onEditTriage,
        ),
        const SizedBox(height: OmniSpacing.md),
        _ReviewCard(
          title: home
              ? p4Copy(context, 'p4_home_destination')
              : p4Copy(context, 'p4_cabinet_title'),
          value: home
              ? ((attempt as HomeAttemptProjection)
                        .destination
                        ?.displayAddress ??
                    '')
              : '${target?.doctorDisplayName ?? ''} · ${target?.quote.displayAmount ?? ''}',
          editLabel: home
              ? p4Copy(context, 'p4_edit_destination')
              : p4Copy(context, 'p4_edit_target'),
          onEdit: onEditModeSpecific,
        ),
        const SizedBox(height: OmniSpacing.md),
        _notice(context, p4Copy(context, 'p4_setup_stop')),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.value,
    required this.editLabel,
    required this.onEdit,
  });
  final String title;
  final String value;
  final String editLabel;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: _cardDecoration,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(value),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: Text(editLabel)),
      ],
    ),
  );
}

Widget _notice(BuildContext context, String text, {Key? key}) => Container(
  key: key,
  width: double.infinity,
  padding: const EdgeInsets.all(OmniSpacing.md),
  decoration: BoxDecoration(
    color: OmniColors.infoBlueSoft,
    borderRadius: BorderRadius.circular(OmniRadii.card),
  ),
  child: Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
  ),
);

final _cardDecoration = BoxDecoration(
  color: OmniColors.surfacePrimary,
  borderRadius: BorderRadius.circular(OmniRadii.card),
  border: Border.all(color: OmniColors.borderLight),
);

Widget _setupScaffold({
  required Key key,
  required BuildContext context,
  required String title,
  required VoidCallback onBack,
  required List<Widget> body,
  String? actionLabel,
  VoidCallback? onAction,
}) => SafeArea(
  top: false,
  child: Column(
    key: key,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          children: body,
        ),
      ),
      if (actionLabel != null)
        Container(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.sm,
            OmniSpacing.pageHorizontal,
            OmniSpacing.lg,
          ),
          decoration: const BoxDecoration(
            color: OmniColors.surfacePrimary,
            border: Border(top: BorderSide(color: OmniColors.borderLight)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const ValueKey('p4-setup-primary-action'),
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ),
        ),
    ],
  ),
);
