import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../sharing/medical_sharing_controller.dart';
import '../../sharing/medical_sharing_models.dart';

Future<void> showMedicalSharingSettingsSheet(
  BuildContext context, {
  required MedicalSharingController controller,
  required MedicalSharingSubject subject,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        MedicalSharingSettingsSheet(controller: controller, subject: subject),
  );
}

class MedicalSharingSettingsSheet extends StatefulWidget {
  const MedicalSharingSettingsSheet({
    super.key,
    required this.controller,
    required this.subject,
  });

  final MedicalSharingController controller;
  final MedicalSharingSubject subject;

  @override
  State<MedicalSharingSettingsSheet> createState() =>
      _MedicalSharingSettingsSheetState();
}

class _MedicalSharingSettingsSheetState
    extends State<MedicalSharingSettingsSheet> {
  MedicalSharingPolicy? _draft;
  int? _canonicalVersion;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_synchronizeDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.selectSubject(widget.subject);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_synchronizeDraft);
    super.dispose();
  }

  void _synchronizeDraft() {
    final policy = widget.controller.policy;
    if (policy != null && policy.version != _canonicalVersion) {
      _canonicalVersion = policy.version;
      _draft = policy;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OmniRadii.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 56,
              height: 5,
              decoration: BoxDecoration(
                color: OmniColors.borderStrong,
                borderRadius: BorderRadius.circular(OmniRadii.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 8, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: OmniColors.primaryAction,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Partage du passeport médical',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: _content(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    if (controller.isLoading && _draft == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 54),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_draft == null) {
      return _FailurePanel(
        message:
            controller.error ??
            'Impossible de charger les paramètres de partage.',
        onRetry: controller.load,
      );
    }
    final draft = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choisissez les catégories qui pourront être incluses après une autorisation explicite. Ces réglages ne donnent pas actuellement accès à un médecin.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _SharingSwitch(
          title: 'Informations essentielles',
          subtitle: 'Groupe sanguin, allergies et conditions critiques.',
          value: draft.essentialInformationEnabled,
          onChanged: (value) =>
              _setDraft(draft.copyWith(essentialInformationEnabled: value)),
        ),
        _SharingSwitch(
          title: 'Médicaments actuels',
          subtitle: 'Traitements actifs du passeport médical.',
          value: draft.currentMedicationsEnabled,
          onChanged: (value) =>
              _setDraft(draft.copyWith(currentMedicationsEnabled: value)),
        ),
        _SharingSwitch(
          title: 'Résumés de consultations',
          subtitle: 'Chaque consultation reste aussi verrouillée séparément.',
          value: draft.consultationSummariesEnabled,
          onChanged: (value) =>
              _setDraft(draft.copyWith(consultationSummariesEnabled: value)),
        ),
        _SharingSwitch(
          title: 'Documents',
          subtitle: 'Éligibilité uniquement; aucun téléchargement direct.',
          value: draft.documentsEnabled,
          onChanged: (value) =>
              _setDraft(draft.copyWith(documentsEnabled: value)),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error!,
            key: const Key('medical-sharing-error'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (controller.notice != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.notice!,
            key: const Key('medical-sharing-notice'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('save-medical-sharing-policy'),
          onPressed: controller.isSaving ? null : _save,
          child: controller.isSaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer les paramètres'),
        ),
      ],
    );
  }

  void _setDraft(MedicalSharingPolicy value) {
    setState(() => _draft = value);
  }

  Future<void> _save() async {
    final desired = _draft;
    if (desired == null) return;
    final saved = await widget.controller.save(desired);
    if (!mounted) return;
    if (!saved) {
      // A failed command never remains displayed as if it were canonical.
      setState(() => _draft = widget.controller.policy);
    }
  }
}

class _SharingSwitch extends StatelessWidget {
  const _SharingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: SwitchListTile.adaptive(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: OmniColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
