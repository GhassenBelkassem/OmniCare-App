import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_medical_record_access.dart';
import 'doctor_medical_record_controller.dart';
import 'doctor_medical_record_screen.dart';

class DoctorMedicalRecordWorkspaceScreen extends StatelessWidget {
  const DoctorMedicalRecordWorkspaceScreen({
    super.key,
    required this.controller,
    this.embedded = false,
    this.onBack,
    this.onContinueConsultation,
  });

  final DoctorMedicalRecordController controller;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onContinueConsultation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final workspace = controller.workspace;
      if (controller.state == DoctorMedicalRecordState.ready &&
          workspace != null) {
        return DoctorMedicalRecordScreen(
          access: DoctorMedicalRecordAccess.fromWorkspace(workspace),
          embedded: embedded,
          onBack: onBack,
          onContinueConsultation: onContinueConsultation,
        );
      }
      final content = _StateContent(controller: controller, onBack: onBack);
      if (embedded) return content;
      return Scaffold(
        backgroundColor: OmniColors.pageBackground,
        appBar: AppBar(title: const Text('Dossier médical')),
        body: SafeArea(child: content),
      );
    },
  );
}

class _StateContent extends StatelessWidget {
  const _StateContent({required this.controller, this.onBack});

  final DoctorMedicalRecordController controller;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final title = switch (state) {
      DoctorMedicalRecordState.loading => 'Chargement du dossier…',
      DoctorMedicalRecordState.accessRequired => 'Partage du dossier requis',
      DoctorMedicalRecordState.expired => 'Accès expiré',
      DoctorMedicalRecordState.revoked => 'Accès révoqué',
      _ => 'Dossier temporairement indisponible',
    };
    final description = switch (state) {
      DoctorMedicalRecordState.accessRequired =>
        'La consultation reste disponible, mais le patient n’a pas partagé son historique médical.',
      DoctorMedicalRecordState.expired =>
        'Les informations historiques ont été retirées de cet espace.',
      DoctorMedicalRecordState.revoked =>
        'Le patient a retiré l’accès à son historique médical.',
      DoctorMedicalRecordState.loading =>
        'Synchronisation avec le dossier MRS autorisé.',
      _ =>
        'Aucune donnée historique n’est affichée. Réessayez lorsque le service est disponible.',
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == DoctorMedicalRecordState.loading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.health_and_safety_outlined, size: 42),
              const SizedBox(height: OmniSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
              if (state == DoctorMedicalRecordState.unavailable) ...[
                const SizedBox(height: OmniSpacing.lg),
                FilledButton.tonal(
                  onPressed: controller.refresh,
                  child: const Text('Réessayer'),
                ),
              ],
              if (onBack != null) ...[
                const SizedBox(height: OmniSpacing.md),
                TextButton(onPressed: onBack, child: const Text('Retour')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
