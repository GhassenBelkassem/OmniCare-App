import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_cabinet_check_in_result.dart';
import 'doctor_urgent_cabinet_request.dart';

class DoctorUrgentCabinetQrPreviewScreen extends StatefulWidget {
  const DoctorUrgentCabinetQrPreviewScreen({
    super.key,
    required this.request,
    required this.debugScenariosEnabled,
  });

  final DoctorUrgentCabinetRequest request;
  final bool debugScenariosEnabled;

  @override
  State<DoctorUrgentCabinetQrPreviewScreen> createState() =>
      _DoctorUrgentCabinetQrPreviewScreenState();
}

class _DoctorUrgentCabinetQrPreviewScreenState
    extends State<DoctorUrgentCabinetQrPreviewScreen> {
  DoctorUrgentCabinetCheckInPreviewState _selectedScenario =
      DoctorUrgentCabinetCheckInPreviewState.invalidQr;
  DoctorUrgentCabinetCheckInPreviewState _visibleScenario =
      DoctorUrgentCabinetCheckInPreviewState.ready;
  bool _scenariosExpanded = false;

  bool get _showDebugScenarios =>
      kDebugMode &&
      widget.debugScenariosEnabled &&
      widget.request.isDevelopmentFixture;

  void _showSelectedScenario() {
    setState(() => _visibleScenario = _selectedScenario);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final result = DoctorUrgentCabinetCheckInResult(_visibleScenario);

    return Scaffold(
      key: const ValueKey('doctor-urgent-cabinet-qr-preview-screen'),
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        title: const Text('Scanner le QR du patient'),
        leading: IconButton(
          key: const ValueKey('doctor-urgent-cabinet-qr-preview-back'),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('doctor-urgent-cabinet-qr-preview-scroll'),
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PreviewDisclosure(),
                  const SizedBox(height: OmniSpacing.base),
                  _AcceptedContextCard(request: widget.request),
                  const SizedBox(height: OmniSpacing.lg),
                  const _StaticScannerSurface(),
                  const SizedBox(height: OmniSpacing.lg),
                  AnimatedSwitcher(
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: _ResultPanel(
                      key: ValueKey(
                        'doctor-urgent-cabinet-check-in-result-${result.state.name}',
                      ),
                      result: result,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.base),
                  const _SecurityNotice(),
                  if (_showDebugScenarios) ...[
                    const SizedBox(height: OmniSpacing.lg),
                    _DebugScenarioSection(
                      expanded: _scenariosExpanded,
                      selected: _selectedScenario,
                      onExpandedChanged: (value) {
                        setState(() => _scenariosExpanded = value);
                      },
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() => _selectedScenario = value);
                      },
                      onShow: _showSelectedScenario,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewDisclosure extends StatelessWidget {
  const _PreviewDisclosure();

  static const message =
      "Aperçu de démonstration — aucune vérification réelle n'est effectuée.";

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: message,
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: OmniColors.mintSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(
            color: OmniColors.freshMint.withValues(alpha: .35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.science_outlined,
              color: OmniColors.deepTeal,
              size: 20,
            ),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.deepTealActive,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AcceptedContextCard extends StatelessWidget {
  const _AcceptedContextCard({required this.request});

  final DoctorUrgentCabinetRequest request;

  @override
  Widget build(BuildContext context) {
    final patientCopy =
        '${request.patient.label}. ${request.patient.disclosure}.';
    final cabinetCopy =
        '${request.cabinet.name}. ${request.cabinet.address}, '
        '${request.cabinet.city}, ${request.cabinet.governorate}.';
    return Semantics(
      container: true,
      label: '$patientCopy Cabinet accepté. $cabinetCopy',
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey(
            'doctor-urgent-cabinet-qr-preview-accepted-context',
          ),
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: OmniColors.surfacePrimary,
            borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
            border: Border.all(color: OmniColors.borderLight),
            boxShadow: const [OmniColors.shadowSm],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONTEXTE ACCEPTÉ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.deepTeal,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
              _ContextRow(
                icon: Icons.person_outline_rounded,
                title: request.patient.label,
                detail: request.patient.disclosure,
              ),
              const SizedBox(height: OmniSpacing.md),
              _ContextRow(
                icon: Icons.medical_services_outlined,
                title: request.cabinet.name,
                detail:
                    '${request.cabinet.address}\n'
                    '${request.cabinet.city}, ${request.cabinet.governorate}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: OmniColors.slateSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 21, color: OmniColors.slateBlue),
      ),
      const SizedBox(width: OmniSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: OmniSpacing.xs),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _StaticScannerSurface extends StatelessWidget {
  const _StaticScannerSurface();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        "Zone d'aperçu du scanner. Caméra non connectée. Aucun QR réel n'est lu dans cette démonstration.",
    child: ExcludeSemantics(
      child: Container(
        key: const ValueKey('doctor-urgent-cabinet-static-scanner'),
        decoration: BoxDecoration(
          color: OmniColors.textPrimary,
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
          border: Border.all(color: OmniColors.slateBlue.withValues(alpha: .8)),
          boxShadow: const [OmniColors.shadowCard],
        ),
        padding: const EdgeInsets.all(OmniSpacing.lg),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CustomPaint(
                  painter: const _ScannerCornersPainter(),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 68,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              'Caméra non connectée',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: OmniSpacing.xs),
            Text(
              "Aucun QR réel n'est lu dans cette démonstration.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: .78),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScannerCornersPainter extends CustomPainter {
  const _ScannerCornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final frameSize = shortest * .72;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;
    final corner = frameSize * .22;
    final paint = Paint()
      ..color = OmniColors.freshMint
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paths = <Path>[
      Path()
        ..moveTo(left, top + corner)
        ..lineTo(left, top)
        ..lineTo(left + corner, top),
      Path()
        ..moveTo(left + frameSize - corner, top)
        ..lineTo(left + frameSize, top)
        ..lineTo(left + frameSize, top + corner),
      Path()
        ..moveTo(left, top + frameSize - corner)
        ..lineTo(left, top + frameSize)
        ..lineTo(left + corner, top + frameSize),
      Path()
        ..moveTo(left + frameSize - corner, top + frameSize)
        ..lineTo(left + frameSize, top + frameSize)
        ..lineTo(left + frameSize, top + frameSize - corner),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerCornersPainter oldDelegate) => false;
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({super.key, required this.result});

  final DoctorUrgentCabinetCheckInResult result;

  @override
  Widget build(BuildContext context) {
    final palette = _ResultPalette.forTreatment(result.visualTreatment);
    final semanticCopy = [
      result.title,
      result.description,
      if (result.guidance != null) result.guidance!,
      if (result.additionalSecurityCopy != null) result.additionalSecurityCopy!,
    ].join(' ');
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticCopy,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(color: palette.foreground.withValues(alpha: .3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(palette.icon, color: palette.foreground, size: 24),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Text(
                      result.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                    if (result.guidance != null) ...[
                      const SizedBox(height: OmniSpacing.sm),
                      Text(
                        result.guidance!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (result.additionalSecurityCopy != null) ...[
                      const SizedBox(height: OmniSpacing.sm),
                      Text(
                        result.additionalSecurityCopy!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPalette {
  const _ResultPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _ResultPalette.forTreatment(
    DoctorUrgentCabinetCheckInVisualTreatment treatment,
  ) => switch (treatment) {
    DoctorUrgentCabinetCheckInVisualTreatment.neutral => const _ResultPalette(
      background: OmniColors.slateSoft,
      foreground: OmniColors.slateBlue,
      icon: Icons.qr_code_scanner_rounded,
    ),
    DoctorUrgentCabinetCheckInVisualTreatment.information =>
      const _ResultPalette(
        background: OmniColors.infoBlueSoft,
        foreground: OmniColors.infoBlueStrong,
        icon: Icons.info_outline_rounded,
      ),
    DoctorUrgentCabinetCheckInVisualTreatment.warning => const _ResultPalette(
      background: OmniColors.amberSoft,
      foreground: OmniColors.amber,
      icon: Icons.warning_amber_rounded,
    ),
    DoctorUrgentCabinetCheckInVisualTreatment.critical => const _ResultPalette(
      background: OmniColors.errorSoft,
      foreground: OmniColors.error,
      icon: Icons.error_outline_rounded,
    ),
    DoctorUrgentCabinetCheckInVisualTreatment.demonstration =>
      const _ResultPalette(
        background: OmniColors.mintSoft,
        foreground: OmniColors.deepTeal,
        icon: Icons.science_outlined,
      ),
  };
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  static const message =
      "Aucune présence n'est enregistrée, aucune consultation n'est démarrée et aucun accès au dossier médical n'est accordé.";

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: message,
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: OmniColors.slateSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: OmniColors.slateBlue,
              size: 20,
            ),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DebugScenarioSection extends StatelessWidget {
  const _DebugScenarioSection({
    required this.expanded,
    required this.selected,
    required this.onExpandedChanged,
    required this.onSelected,
    required this.onShow,
  });

  final bool expanded;
  final DoctorUrgentCabinetCheckInPreviewState selected;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<DoctorUrgentCabinetCheckInPreviewState?> onSelected;
  final VoidCallback onShow;

  static const scenarios = DoctorUrgentCabinetCheckInPreviewState.values;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('doctor-urgent-cabinet-debug-scenarios'),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: 'Scénarios de test',
          child: InkWell(
            key: const ValueKey('doctor-urgent-cabinet-scenarios-toggle'),
            borderRadius: BorderRadius.circular(OmniRadii.card),
            onTap: () => onExpandedChanged(!expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.base,
                  vertical: OmniSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.developer_mode_rounded,
                      color: OmniColors.slateBlue,
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    Expanded(
                      child: Text(
                        'Scénarios de test',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: OmniColors.slateBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1, color: OmniColors.borderLight),
          Padding(
            padding: const EdgeInsets.all(OmniSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Sélectionnez un rendu local. Aucun QR n'est lu et aucune donnée n'est transmise.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: OmniSpacing.md),
                DropdownButtonFormField<DoctorUrgentCabinetCheckInPreviewState>(
                  key: const ValueKey(
                    'doctor-urgent-cabinet-scenario-selector',
                  ),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Résultat à afficher',
                  ),
                  items: [
                    for (final scenario in scenarios)
                      DropdownMenuItem(
                        value: scenario,
                        child: Text(
                          DoctorUrgentCabinetCheckInResult(scenario).title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onSelected,
                ),
                const SizedBox(height: OmniSpacing.md),
                FilledButton(
                  key: const ValueKey(
                    'doctor-urgent-cabinet-show-selected-scenario',
                  ),
                  style: buildOmniPrimaryButtonStyle(),
                  onPressed: onShow,
                  child: const SizedBox(
                    height: 48,
                    child: Center(child: Text('Afficher ce scénario')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
