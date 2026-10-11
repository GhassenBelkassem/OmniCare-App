import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'body_map_widget.dart';

class SelectedBodyAreasPanel extends StatelessWidget {
  const SelectedBodyAreasPanel({
    super.key,
    required this.parts,
    required this.onRemove,
    required this.onReset,
    this.title = 'Zones sélectionnées',
    this.resetLabel = 'Réinitialiser',
    this.removeLabel = 'Retirer',
    this.labelBuilder,
  });
  final List<String> parts;
  final ValueChanged<String> onRemove;
  final VoidCallback onReset;
  final String title;
  final String resetLabel;
  final String removeLabel;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: OmniSpacing.sm,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: OmniColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextButton(onPressed: onReset, child: Text(resetLabel)),
        ],
      ),
      Wrap(
        spacing: OmniSpacing.sm,
        runSpacing: OmniSpacing.sm,
        children: parts
            .map(
              (part) => InputChip(
                key: ValueKey('selected-$part'),
                label: Text((labelBuilder ?? bodyAreaLabel)(part)),
                onDeleted: () => onRemove(part),
                deleteButtonTooltipMessage:
                    '$removeLabel ${(labelBuilder ?? bodyAreaLabel)(part)}',
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: OmniColors.mintSoft,
                side: const BorderSide(color: OmniColors.freshMint),
                shape: const StadiumBorder(),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: OmniColors.deepTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                deleteIconColor: OmniColors.deepTeal,
                deleteIcon: const Icon(Icons.close_rounded, size: 18),
              ),
            )
            .toList(),
      ),
    ],
  );
}

String painLevelLabel(double value) => value <= 3
    ? 'Légère'
    : value <= 6
    ? 'Modérée'
    : 'Sévère';

class PainLevelControl extends StatelessWidget {
  const PainLevelControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Intensité de la douleur',
    this.lowLabel = 'Légère',
    this.mediumLabel = 'Modérée',
    this.highLabel = 'Sévère',
  });
  final double value;
  final ValueChanged<double> onChanged;
  final String title;
  final String lowLabel;
  final String mediumLabel;
  final String highLabel;

  String label(double level) => level <= 3
      ? lowLabel
      : level <= 6
      ? mediumLabel
      : highLabel;

  @override
  Widget build(BuildContext context) {
    final color = value <= 3
        ? OmniColors.deepTeal
        : value <= 6
        ? OmniColors.amber
        : OmniColors.urgentCoral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: OmniColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Row(
          children: [
            Text(
              '${value.round()} / 10',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              label(value),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('emergency-pain-slider'),
          value: value,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: color,
          semanticFormatterCallback: (level) =>
              '${level.round()} sur 10, ${label(level)}',
          onChanged: onChanged,
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '1 · $lowLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Text(
                '10 · $highLabel',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SymptomDescriptionCard extends StatelessWidget {
  const SymptomDescriptionCard({
    super.key,
    required this.controller,
    this.supportingText,
    this.hintText,
  });
  final TextEditingController controller;
  final String? supportingText;
  final String? hintText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Description des symptômes',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: OmniColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: OmniSpacing.xs),
      Text(
        supportingText ?? 'Une courte description suffit. Ce champ est requis.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: OmniColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      const SizedBox(height: OmniSpacing.base),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'text', label: Text('Texte')),
          ButtonSegment(
            value: 'voice',
            enabled: false,
            label: Text('Vocal · Bientôt'),
            tooltip: 'La saisie vocale sera disponible prochainement',
          ),
        ],
        selected: const {'text'},
        showSelectedIcon: false,
        onSelectionChanged: (_) {},
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          visualDensity: VisualDensity.compact,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      const SizedBox(height: OmniSpacing.base),
      TextField(
        key: const ValueKey('emergency-description'),
        controller: controller,
        minLines: 4,
        maxLines: null,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: hintText ?? 'Décrivez brièvement ce que vous ressentez.',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.base,
            vertical: 14,
          ),
        ),
      ),
    ],
  );
}

class MedicalPassportToggle extends StatelessWidget {
  const MedicalPassportToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  static const explanation =
      'Votre groupe sanguin, vos allergies, vos maladies chroniques et vos traitements pourront être partagés avec le médecin assigné, selon vos autorisations. Ce choix exprime votre souhait et n’ouvre aucun accès à votre dossier pour le moment.';

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      border: Border.all(
        color: value ? OmniColors.freshMint : OmniColors.borderLight,
      ),
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              size: 20,
              color: OmniColors.deepTeal,
            ),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                'Passeport médical',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Partager mon passeport médical avec ce médecin',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            Semantics(
              label: 'Souhait de partager mon passeport médical',
              child: Switch.adaptive(
                key: const ValueKey('emergency-passport-toggle'),
                value: value,
                onChanged: onChanged,
                activeTrackColor: OmniColors.primaryAction,
              ),
            ),
          ],
        ),
        Text(
          'Un choix facultatif, selon vos autorisations.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SingleChildScrollView(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(OmniSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Votre partage, vos autorisations',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: OmniSpacing.base),
                      const Text(explanation),
                      const SizedBox(height: OmniSpacing.base),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Compris'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          label: const Text('Quelles informations ?'),
        ),
        if (value) ...[
          const SizedBox(height: OmniSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(OmniSpacing.sm),
              decoration: BoxDecoration(
                color: OmniColors.mintSoft,
                borderRadius: BorderRadius.circular(OmniRadii.field),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: OmniColors.deepTeal,
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Expanded(
                    child: Text(
                      'Souhait de partage enregistré pour cette demande. Aucun accès n’est encore accordé.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.deepTeal,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
