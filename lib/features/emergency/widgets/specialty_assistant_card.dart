import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

/// Presentation examples only. Never used by navigation, matching or triage.
abstract final class DemoSpecialtySuggestionEngine {
  static const vocabulary = [
    'Généraliste',
    'Neurologue',
    'Cardiologue',
    'Gastro-entérologue',
    'Orthopédiste',
    'Dermatologue',
  ];

  static List<String> suggest(List<String> areas, String description) {
    if (areas.isEmpty || description.trim().isEmpty) return const [];
    final examples = <String>{};
    if (areas.any((id) => id.contains('head'))) examples.add('Neurologue');
    if (areas.any((id) => id.contains('chest'))) examples.add('Cardiologue');
    if (areas.any((id) => id.contains('abs') || id.contains('oblique'))) {
      examples.add('Gastro-entérologue');
    }
    if (areas.any(
      (id) => RegExp('knee|thigh|back-|shoulder|foot').hasMatch(id),
    )) {
      examples.add('Orthopédiste');
    }
    if (description.toLowerCase().contains('peau')) {
      examples.add('Dermatologue');
    }
    return [...examples.take(2), 'Généraliste'];
  }
}

enum _DemoState { idle, thinking, suggested, skipped }

class SpecialtyAssistantCard extends StatefulWidget {
  const SpecialtyAssistantCard({
    super.key,
    required this.areas,
    required this.description,
  });
  final List<String> areas;
  final String description;

  @override
  State<SpecialtyAssistantCard> createState() => _SpecialtyAssistantCardState();
}

class _SpecialtyAssistantCardState extends State<SpecialtyAssistantCard> {
  _DemoState _state = _DemoState.idle;
  List<String> _suggestions = [];
  Timer? _timer;

  bool get _ready =>
      widget.areas.isNotEmpty && widget.description.trim().isNotEmpty;

  @override
  void didUpdateWidget(SpecialtyAssistantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.areas, widget.areas) ||
        oldWidget.description.trim() != widget.description.trim()) {
      _timer?.cancel();
      _state = _DemoState.idle;
      _suggestions = [];
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _suggest() {
    if (!_ready) return;
    setState(() => _state = _DemoState.thinking);
    // Short, cancellable presentation transition. No external service.
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _suggestions = DemoSpecialtySuggestionEngine.suggest(
          widget.areas,
          widget.description,
        );
        _state = _DemoState.suggested;
      });
    });
  }

  void _skip() {
    _timer?.cancel();
    setState(() {
      _state = _DemoState.skipped;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.mintSoft,
      border: Border.all(color: OmniColors.freshMint.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: OmniSpacing.sm,
          runSpacing: OmniSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: OmniColors.deepTeal,
            ),
            Text(
              'Assistant de spécialité',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: OmniColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: OmniColors.surfacePrimary,
                borderRadius: BorderRadius.circular(OmniRadii.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  'Démo',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OmniColors.deepTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          'Exemples indicatifs, sans avis médical. Cette démo ne détermine ni l’urgence ni la recherche de votre médecin.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: OmniSpacing.base),
        if (_state == _DemoState.idle) ...[
          const Text(
            'Sélectionnez une zone et décrivez vos symptômes pour découvrir des exemples de spécialités.',
          ),
          const SizedBox(height: OmniSpacing.sm),
          TextButton(
            onPressed: _ready ? _suggest : null,
            child: const Text('Voir les suggestions'),
          ),
        ],
        if (_state == _DemoState.thinking)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: OmniSpacing.sm),
              Expanded(child: Text('Préparation des exemples…')),
            ],
          ),
        if (_state == _DemoState.suggested) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              'Suggestions de démonstration',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: OmniSpacing.sm),
          if (_suggestions.isEmpty) const Text('Aucune spécialité retenue.'),
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: _suggestions
                .map(
                  (label) => InputChip(
                    key: ValueKey('demo-specialty-$label'),
                    label: Text(label),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    deleteButtonTooltipMessage: 'Retirer $label',
                    onDeleted: () => setState(
                      () => _suggestions = _suggestions
                          .where((value) => value != label)
                          .toList(),
                    ),
                    backgroundColor: OmniColors.surfacePrimary,
                    side: const BorderSide(color: OmniColors.freshMint),
                    shape: const StadiumBorder(),
                    labelStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: OmniColors.deepTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                    deleteIconColor: OmniColors.deepTeal,
                  ),
                )
                .toList(),
          ),
          if (DemoSpecialtySuggestionEngine.vocabulary.any(
            (label) => !_suggestions.contains(label),
          ))
            PopupMenuButton<String>(
              tooltip: 'Ajouter une spécialité',
              onSelected: (label) =>
                  setState(() => _suggestions = [..._suggestions, label]),
              itemBuilder: (_) => DemoSpecialtySuggestionEngine.vocabulary
                  .where((label) => !_suggestions.contains(label))
                  .map(
                    (label) => PopupMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Ajouter une spécialité'),
              ),
            ),
        ],
        if (_state == _DemoState.skipped) ...[
          const Text(
            'Suggestions ignorées. Vous pouvez poursuivre votre demande.',
          ),
          TextButton(
            onPressed: () => setState(() => _state = _DemoState.idle),
            child: const Text('Afficher la démo'),
          ),
        ] else
          TextButton(
            onPressed: _skip,
            child: const Text('Ignorer les suggestions'),
          ),
      ],
    ),
  );
}
