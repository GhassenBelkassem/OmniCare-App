import 'package:flutter/material.dart';

import '../../core/theme/omni_theme.dart';
import 'doctor_matching.dart';

class DoctorSelectionScreen extends StatefulWidget {
  const DoctorSelectionScreen({
    super.key,
    required this.emergencyData,
    this.matchingSource,
  });

  final Map<String, dynamic> emergencyData;
  final DoctorMatchingSource? matchingSource;

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  late final DoctorMatchingController _matchingController;

  @override
  void initState() {
    super.initState();
    _matchingController = DoctorMatchingController(
      source:
          widget.matchingSource ??
          DemoDoctorMatchingSource(doctors: createDemoUrgentDoctors()),
    );
    _matchingController.start();
  }

  @override
  void dispose() {
    _matchingController.dispose();
    super.dispose();
  }

  Future<void> _selectDoctor(Doctor doctor) async {
    if (!_matchingController.selectDoctor(doctor)) return;

    // Give the patient a short, visible acknowledgement before continuing.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/review-confirm',
      arguments: {
        ...widget.emergencyData,
        'doctor': doctor,
        'selectedDoctorId': doctor.backendDoctorId,
      },
    );
  }

  void _showDoctorDetails(Doctor doctor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DoctorDetailsSheet(
        doctor: doctor,
        onSelect: () {
          Navigator.pop(context);
          _selectDoctor(doctor);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('doctor-selection-page-surface'),
      color: OmniColors.pageBackground,
      child: Column(
        children: [
          _ContextHeader(onBack: () => Navigator.maybePop(context)),
          Expanded(
            child: AnimatedBuilder(
              animation: _matchingController,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MatchingHero(controller: _matchingController),
                          const SizedBox(height: 12),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: Column(
                              key: ValueKey(
                                _matchingController.candidates.length,
                              ),
                              children: _matchingController.candidates
                                  .map(_buildCandidate)
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidate(Doctor doctor) {
    return Padding(
      key: ValueKey(doctor.backendDoctorId),
      padding: const EdgeInsets.only(bottom: 12),
      child: _AnimatedCandidateEntry(
        child: _DoctorCandidateCard(
          doctor: doctor,
          selected: identical(_matchingController.selectedDoctor, doctor),
          selectionInProgress: _matchingController.selectionInProgress,
          onSelect: () => _selectDoctor(doctor),
          onDetails: () => _showDoctorDetails(doctor),
        ),
      ),
    );
  }
}

class _ContextHeader extends StatelessWidget {
  const _ContextHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Retour',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Demande urgente',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchingHero extends StatelessWidget {
  const _MatchingHero({required this.controller});

  final DoctorMatchingController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.candidates.length;
    final status = controller.status;
    final hasCandidates =
        status == DoctorMatchingStatus.candidatesAvailable && count > 0;
    final title = switch (status) {
      DoctorMatchingStatus.searching => 'Recherche de médecins disponibles…',
      DoctorMatchingStatus.waitingLonger => 'La recherche continue…',
      DoctorMatchingStatus.error => 'Impossible de poursuivre la recherche',
      DoctorMatchingStatus.candidatesAvailable =>
        count == 1
            ? 'Un médecin est disponible'
            : '$count médecins sont disponibles',
    };
    final supporting = switch (status) {
      DoctorMatchingStatus.searching =>
        'Votre demande a été transmise aux médecins pouvant intervenir dans votre zone.',
      DoctorMatchingStatus.waitingLonger =>
        'Cela peut prendre un peu plus de temps selon les disponibilités.',
      DoctorMatchingStatus.error => 'Vérifiez votre connexion puis réessayez.',
      DoctorMatchingStatus.candidatesAvailable =>
        count == 1
            ? "Vous pouvez choisir maintenant ou attendre d'autres réponses."
            : 'Choisissez le médecin qui vous convient le mieux.',
    };

    if (hasCandidates) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: _MatchingRadar(
                  key: ValueKey('matching-radar-compact'),
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recherche toujours active',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            child: Column(
              key: ValueKey('$status-$count'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  count == 1
                      ? supporting
                      : "D'autres médecins peuvent encore répondre.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: OmniColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: 132,
          height: 132,
          child: _MatchingRadar(key: ValueKey('matching-radar-large')),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          child: Column(
            key: ValueKey('$status-$count'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: OmniColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                supporting,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (status == DoctorMatchingStatus.error) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.retry,
                  child: const Text('Réessayer'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchingRadar extends StatefulWidget {
  const _MatchingRadar({super.key, this.compact = false});

  final bool compact;

  @override
  State<_MatchingRadar> createState() => _MatchingRadarState();
}

class _MatchingRadarState extends State<_MatchingRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationConfigured = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationConfigured) return;
    _animationConfigured = true;
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _RadarPainter(progress: _controller.value),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OmniColors.mintSoft,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 5 : 12),
              child: Icon(
                Icons.location_on_rounded,
                color: OmniColors.primaryAction,
                size: widget.compact ? 14 : 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    for (var index = 0; index < 3; index++) {
      final phase = (progress + index / 3) % 1;
      final radius = maxRadius * (0.35 + phase * 0.65);
      final opacity = (1 - phase) * 0.28;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = OmniColors.freshMint.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      center,
      maxRadius * 0.25,
      Paint()..color = OmniColors.freshMint.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AnimatedCandidateEntry extends StatelessWidget {
  const _AnimatedCandidateEntry({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _DoctorCandidateCard extends StatelessWidget {
  const _DoctorCandidateCard({
    required this.doctor,
    required this.selected,
    required this.selectionInProgress,
    required this.onSelect,
    required this.onDetails,
  });

  final Doctor doctor;
  final bool selected;
  final bool selectionInProgress;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = [
      doctor.name,
      doctor.specialty,
      'arrivée estimée dans ${doctor.eta} minutes',
      '${_formatDistance(doctor.distance)} kilomètres',
      'Disponible maintenant',
      if (doctor.verified) 'Vérifié OmniCare',
    ].join(', ');

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: OmniColors.surfacePrimary,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          border: Border.all(
            color: selected ? OmniColors.freshMint : OmniColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DoctorAvatar(doctor: doctor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                doctor.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      color: OmniColors.textPrimary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor.specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 14,
                                color: OmniColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _DecisionMetric(
                    label: 'Arrivée estimée',
                    value: '≈ ${doctor.eta} min',
                    prominent: true,
                  ),
                  _DecisionMetric(
                    label: 'Distance',
                    value: '${_formatDistance(doctor.distance)} km',
                  ),
                ],
              ),
              if (doctor.rating > 0 || doctor.verified) ...[
                const SizedBox(height: 7),
                _DoctorTrustRow(doctor: doctor),
              ],
              const SizedBox(height: 9),
              _CardActions(
                onDetails: onDetails,
                onSelect: onSelect,
                selected: selected,
                selectionInProgress: selectionInProgress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final asset = doctor.avatar;
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipOval(
        child: asset != null && asset.startsWith('assets/')
            ? Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _InitialsAvatar(name: doctor.name),
              )
            : _InitialsAvatar(name: doctor.name),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.substring(0, 1)
        : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';

    return ColoredBox(
      color: OmniColors.violetSoft,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: OmniColors.slateBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DecisionMetric extends StatelessWidget {
  const _DecisionMetric({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 12,
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style:
              (prominent
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    fontSize: prominent ? 18 : 14,
                    color: prominent
                        ? OmniColors.primaryAction
                        : OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
        ),
      ],
    );
  }
}

class _DoctorTrustRow extends StatelessWidget {
  const _DoctorTrustRow({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (doctor.rating > 0)
          Text(
            '★ ${_formatRating(doctor.rating)} (${doctor.reviewCount} avis)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: OmniColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (doctor.rating > 0 && doctor.verified)
          Text(
            '·',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: OmniColors.textTertiary),
          ),
        if (doctor.verified)
          Semantics(
            label: 'Vérifié OmniCare',
            child: Tooltip(
              message: 'Vérifié OmniCare',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: OmniColors.primaryAction,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Vérifié OmniCare',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: OmniColors.deepTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.onDetails,
    required this.onSelect,
    required this.selected,
    required this.selectionInProgress,
  });

  final VoidCallback onDetails;
  final VoidCallback onSelect;
  final bool selected;
  final bool selectionInProgress;

  @override
  Widget build(BuildContext context) {
    final profileButton = TextButton(
      onPressed: onDetails,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text('Voir le profil'),
    );
    final chooseButton = FilledButton(
      onPressed: selectionInProgress ? null : onSelect,
      style: FilledButton.styleFrom(
        backgroundColor: OmniColors.primaryAction,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(selected ? 'Sélectionné' : 'Choisir ce médecin'),
    );
    final textScale = MediaQuery.maybeOf(context)?.textScaler.scale(1) ?? 1.0;

    if (textScale > 1.4) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: profileButton),
          SizedBox(width: double.infinity, child: chooseButton),
        ],
      );
    }

    return Row(
      children: [
        profileButton,
        const SizedBox(width: 8),
        Expanded(child: chooseButton),
      ],
    );
  }
}

String _formatDistance(double distance) =>
    distance.toStringAsFixed(1).replaceAll('.', ',');

String _formatRating(double rating) =>
    rating.toStringAsFixed(1).replaceAll('.', ',');

class _DoctorDetailsSheet extends StatelessWidget {
  const _DoctorDetailsSheet({required this.doctor, required this.onSelect});

  final Doctor doctor;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 680),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OmniColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DoctorAvatar(doctor: doctor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctor.specialty,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: OmniColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '★ ${doctor.rating.toStringAsFixed(1)} (${doctor.reviewCount} avis)',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        icon: Icons.access_time_rounded,
                        value: '≈ ${doctor.eta} min',
                        label: 'Arrivée estimée',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DetailMetric(
                        icon: Icons.location_on_outlined,
                        value: '${doctor.distance.toStringAsFixed(1)} km',
                        label: 'Distance approximative',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailsSection(title: 'À propos', text: doctor.description),
                if (doctor.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailsSection(
                    title: 'Compétences',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doctor.tags
                          .map(
                            (tag) => DecoratedBox(
                              decoration: BoxDecoration(
                                color: OmniColors.violetSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                child: Text(
                                  tag,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: OmniColors.violet),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSelect,
                child: const Text('Choisir ce médecin'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: OmniColors.deepTeal, size: 19),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, this.text, this.child});

  final String title;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (text != null)
          Text(
            text!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OmniColors.textSecondary,
              height: 1.45,
            ),
          ),
        ?child,
      ],
    );
  }
}
