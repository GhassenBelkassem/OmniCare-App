import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

enum DoctorUrgentCabinetCheckInEntrySheetAction { openScannerPreview }

Future<DoctorUrgentCabinetCheckInEntrySheetAction?>
showDoctorUrgentCabinetCheckInEntrySheet(
  BuildContext context, {
  required bool scannerPreviewEnabled,
  Future<bool> Function(String token)? onVerifyToken,
  ValueChanged<BuildContext>? onSheetContextReady,
}) {
  var transitionStarted = false;
  return showModalBottomSheet<DoctorUrgentCabinetCheckInEntrySheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      onSheetContextReady?.call(sheetContext);
      return DoctorUrgentCabinetCheckInEntrySheet(
        onVerifyToken: onVerifyToken,
        onOpenScannerPreview: scannerPreviewEnabled
            ? () {
                if (transitionStarted) return;
                transitionStarted = true;
                Navigator.of(sheetContext).pop(
                  DoctorUrgentCabinetCheckInEntrySheetAction.openScannerPreview,
                );
              }
            : null,
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class DoctorUrgentCabinetCheckInEntrySheet extends StatelessWidget {
  const DoctorUrgentCabinetCheckInEntrySheet({
    super.key,
    required this.onOpenScannerPreview,
    required this.onClose,
    this.onVerifyToken,
  });

  final VoidCallback? onOpenScannerPreview;
  final VoidCallback onClose;
  final Future<bool> Function(String token)? onVerifyToken;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      key: const ValueKey('doctor-urgent-cabinet-check-in-entry-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey(
                'doctor-urgent-cabinet-check-in-entry-sheet-scroll',
              ),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.sm,
                OmniSpacing.pageHorizontal,
                OmniSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: OmniColors.deepTeal,
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: Text(
                          'Vérification de présence',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'doctor-urgent-cabinet-check-in-entry-close-icon',
                        ),
                        tooltip: 'Fermer',
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    'Vérifiez la présence du patient au cabinet avant toute prise en charge clinique.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  if (onVerifyToken != null) ...[
                    _LiveArrivalVerification(onVerifyToken: onVerifyToken!),
                    const SizedBox(height: OmniSpacing.md),
                  ],
                  _FutureMethodCard(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Scanner le QR du patient',
                    explanation:
                        'Le patient ou son représentant autorisé devra présenter un QR sécurisé associé à cette demande.',
                    status: onVerifyToken != null
                        ? 'Vérification serveur disponible'
                        : onOpenScannerPreview == null
                        ? 'Fonctionnalité à venir'
                        : 'Aperçu de développement',
                    statusKey: 'doctor-urgent-cabinet-check-in-qr-status',
                    accent: OmniColors.deepTeal,
                    background: OmniColors.mintSoft,
                    actionLabel: "Ouvrir l'aperçu du scanner",
                    actionKey:
                        'doctor-urgent-cabinet-check-in-open-scanner-preview',
                    onPressed: onOpenScannerPreview,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  const _FutureMethodCard(
                    icon: Icons.person_search_outlined,
                    title: 'Patient sans QR disponible',
                    explanation:
                        "Une procédure exceptionnelle de vérification d'identité pourra être prévue lorsque le patient ne peut pas utiliser son téléphone.",
                    status: 'Procédure non disponible dans cette démonstration',
                    statusKey: 'doctor-urgent-cabinet-check-in-fallback-status',
                    accent: OmniColors.warning,
                    background: OmniColors.amberSoft,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  const _InformationNotice(
                    icon: Icons.lock_outline_rounded,
                    message:
                        'La vérification de présence ne démarre pas la consultation et ne donne pas accès au dossier médical.',
                    background: OmniColors.slateSoft,
                    foreground: OmniColors.slateBlue,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  if (onVerifyToken == null)
                    const _InformationNotice(
                      icon: Icons.science_outlined,
                      message:
                          "Démonstration — aucune vérification réelle n'est effectuée.",
                      background: OmniColors.mintSoft,
                      foreground: OmniColors.deepTeal,
                    ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: OmniColors.surfacePrimary,
              border: Border(top: BorderSide(color: OmniColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
                OmniSpacing.pageHorizontal,
                OmniSpacing.base,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey(
                    'doctor-urgent-cabinet-check-in-entry-close',
                  ),
                  style: buildOmniPrimaryButtonStyle(),
                  onPressed: onClose,
                  child: const SizedBox(
                    height: 48,
                    child: Center(child: Text('Fermer')),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveArrivalVerification extends StatefulWidget {
  const _LiveArrivalVerification({required this.onVerifyToken});
  final Future<bool> Function(String token) onVerifyToken;

  @override
  State<_LiveArrivalVerification> createState() =>
      _LiveArrivalVerificationState();
}

class _LiveArrivalVerificationState extends State<_LiveArrivalVerification> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  bool? _verified;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _controller.text.trim();
    if (_submitting || token.isEmpty) return;
    setState(() {
      _submitting = true;
      _verified = null;
    });
    final verified = await widget.onVerifyToken(token);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _verified = verified;
      if (verified) _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('doctor-urgent-cabinet-live-arrival-verification'),
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('doctor-urgent-cabinet-arrival-token'),
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Code QR lu',
            helperText:
                'Utilisez le contenu lu par le scanner. Ne le conservez pas.',
          ),
        ),
        const SizedBox(height: OmniSpacing.md),
        FilledButton.icon(
          key: const ValueKey('doctor-urgent-cabinet-verify-arrival-token'),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text("Confirmer l'arrivée"),
        ),
        if (_verified != null) ...[
          const SizedBox(height: OmniSpacing.sm),
          Text(
            _verified!
                ? "Arrivée confirmée. La consultation n'est pas démarrée."
                : 'Vérification refusée. Actualisez avant de réessayer.',
            key: ValueKey(
              _verified!
                  ? 'doctor-urgent-cabinet-arrival-verified'
                  : 'doctor-urgent-cabinet-arrival-rejected',
            ),
            style: TextStyle(
              color: _verified! ? OmniColors.deepTeal : OmniColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );
}

class _FutureMethodCard extends StatelessWidget {
  const _FutureMethodCard({
    required this.icon,
    required this.title,
    required this.explanation,
    required this.status,
    required this.statusKey,
    required this.accent,
    required this.background,
    this.actionLabel,
    this.actionKey,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String explanation;
  final String status;
  final String statusKey;
  final Color accent;
  final Color background;
  final String? actionLabel;
  final String? actionKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: onPressed != null,
      label: '$title. $explanation $status.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: OmniColors.surfacePrimary,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(color: OmniColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: OmniSpacing.md),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                explanation,
                style: textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
              Container(
                key: ValueKey(statusKey),
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.md,
                  vertical: OmniSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(OmniRadii.pill),
                ),
                child: Text(
                  status,
                  style: textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onPressed != null) ...[
                const SizedBox(height: OmniSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: ValueKey<String>(actionKey!),
                    onPressed: onPressed,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationNotice extends StatelessWidget {
  const _InformationNotice({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: message,
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
