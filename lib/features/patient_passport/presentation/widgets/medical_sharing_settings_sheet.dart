import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../sharing/medical_sharing_controller.dart';
import '../../sharing/medical_sharing_models.dart';
import '../../sharing/direct_patient_authorization.dart';
import '../../sharing/direct_patient_authorization_controller.dart';

Future<void> showMedicalSharingSettingsSheet(
  BuildContext context, {
  required MedicalSharingController controller,
  required MedicalSharingSubject subject,
  DirectPatientAuthorizationController? directAuthorizationController,
  String? subjectDisplayName,
  VoidCallback? onShowQr,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MedicalSharingSettingsSheet(
      controller: controller,
      subject: subject,
      directAuthorizationController: directAuthorizationController,
      subjectDisplayName: subjectDisplayName,
      onShowQr: onShowQr,
    ),
  );
}

class MedicalSharingSettingsSheet extends StatefulWidget {
  const MedicalSharingSettingsSheet({
    super.key,
    required this.controller,
    required this.subject,
    this.directAuthorizationController,
    this.subjectDisplayName,
    this.onShowQr,
  });

  final MedicalSharingController controller;
  final MedicalSharingSubject subject;
  final DirectPatientAuthorizationController? directAuthorizationController;
  final String? subjectDisplayName;
  final VoidCallback? onShowQr;

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
    widget.directAuthorizationController?.addListener(_synchronizeDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.selectSubject(widget.subject);
      widget.directAuthorizationController?.load(widget.subject);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_synchronizeDraft);
    widget.directAuthorizationController?.removeListener(_synchronizeDraft);
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
        if (widget.directAuthorizationController != null) ...[
          _directAuthorization(context, widget.directAuthorizationController!),
          const SizedBox(height: 20),
        ],
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

  Widget _directAuthorization(
    BuildContext context,
    DirectPatientAuthorizationController controller,
  ) {
    if (controller.isLoading && controller.contexts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.contexts.isEmpty) {
      return _DirectAuthorizationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.subjectDisplayName ?? 'Consultation actuelle',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('Aucune Consultation active pour ce passeport.'),
            if (widget.onShowQr != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('show-medical-sharing-qr'),
                onPressed: widget.onShowQr,
                child: const Text('Afficher le QR'),
              ),
            ],
          ],
        ),
      );
    }
    final selected = controller.selected;
    final access = controller.access;
    return _DirectAuthorizationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.subjectDisplayName ?? 'Consultation actuelle',
            key: const Key('medical-sharing-subject-name'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (controller.contexts.length > 1)
            DropdownButtonFormField<String>(
              key: const Key('direct-consent-consultation-picker'),
              initialValue: selected?.consultationId,
              decoration: const InputDecoration(
                labelText: 'Consultation à autoriser',
              ),
              items: [
                for (final item in controller.contexts)
                  DropdownMenuItem(
                    value: item.consultationId,
                    child: Text(_doctorLabel(item.doctor)),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                final match = controller.contexts.firstWhere(
                  (item) => item.consultationId == id,
                );
                controller.select(match);
              },
            )
          else if (selected != null)
            Text(
              'Consultation avec ${_doctorLabel(selected.doctor)}',
              key: const Key('direct-consent-doctor'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (selected == null && controller.contexts.length > 1) ...[
            const SizedBox(height: 8),
            const Text('Sélectionnez explicitement la Consultation concernée.'),
          ],
          if (access?.status == PatientMedicalAccessStatus.active) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.check_circle, color: OmniColors.success),
                SizedBox(width: 8),
                Text(
                  'Accès accordé',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (access?.expiresAt != null) ...[
              const SizedBox(height: 4),
              Text('Expire : ${_expiry(access!.expiresAt!)}'),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('revoke-direct-consent'),
              onPressed: controller.isMutating ? null : controller.revoke,
              child: const Text('Retirer l’accès'),
            ),
          ] else ...[
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('approve-direct-consent'),
              onPressed: selected == null || controller.isMutating
                  ? null
                  : controller.approve,
              child: controller.isMutating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Autoriser ce médecin'),
            ),
          ],
          if (widget.onShowQr != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('show-medical-sharing-qr'),
              onPressed: widget.onShowQr,
              child: const Text('Afficher le QR à la place'),
            ),
          ],
          if (controller.error != null) ...[
            const SizedBox(height: 8),
            Text(
              controller.error!,
              key: const Key('direct-consent-error'),
              style: const TextStyle(
                color: OmniColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _doctorLabel(MedicalSharingDoctor doctor) {
    final specialty = doctor.specialty;
    return specialty == null || specialty.isEmpty
        ? 'Dr ${doctor.displayName}'
        : 'Dr ${doctor.displayName} · $specialty';
  }

  static String _expiry(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

class _DirectAuthorizationCard extends StatelessWidget {
  const _DirectAuthorizationCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: child,
  );
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
