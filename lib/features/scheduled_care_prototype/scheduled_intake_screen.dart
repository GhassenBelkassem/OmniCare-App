import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
import '../emergency/widgets/body_map_widget.dart';
import '../emergency/widgets/medical_intake_widgets.dart';
import 'scheduled_care_controller.dart';

/// Optional, in-memory P2-02 preparation form.
///
/// Future persistence requires an approved health-data/MRS boundary. This
/// screen must never write symptoms to ordinary appointment APIs.
class ScheduledIntakeScreen extends StatefulWidget {
  const ScheduledIntakeScreen({
    super.key,
    required this.recordId,
    this.controller,
  });

  final String recordId;
  final ScheduledCarePrototypeController? controller;

  @override
  State<ScheduledIntakeScreen> createState() => _ScheduledIntakeScreenState();
}

class _ScheduledIntakeScreenState extends State<ScheduledIntakeScreen> {
  final _description = TextEditingController();
  final List<String> _bodyAreas = [];
  double _pain = 3;

  @override
  void initState() {
    super.initState();
    _description.addListener(_refreshSubmitState);
  }

  void _refreshSubmitState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _description.removeListener(_refreshSubmitState);
    _description.dispose();
    super.dispose();
  }

  void _toggleArea(String area) {
    setState(() {
      if (_bodyAreas.contains(area)) {
        _bodyAreas.remove(area);
      } else {
        _bodyAreas.add(area);
      }
    });
  }

  void _submit() {
    (widget.controller ?? context.read<ScheduledCarePrototypeController>())
        .submitIntake(
          id: widget.recordId,
          bodyAreas: _bodyAreas,
          description: _description.text,
          painIntensity: _pain.round(),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(title: const Text('Préparer ma consultation')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Facultatif · vous pourrez le faire plus tard',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.base),
                  MuscleAnatomyMap(
                    selectedParts: _bodyAreas,
                    onPartClick: _toggleArea,
                  ),
                  if (_bodyAreas.isNotEmpty) ...[
                    const SizedBox(height: OmniSpacing.base),
                    SelectedBodyAreasPanel(
                      parts: _bodyAreas,
                      onRemove: _toggleArea,
                      onReset: () => setState(_bodyAreas.clear),
                    ),
                  ],
                  const SizedBox(height: OmniSpacing.lg),
                  SymptomDescriptionCard(controller: _description),
                  const SizedBox(height: OmniSpacing.lg),
                  PainLevelControl(
                    value: _pain,
                    onChanged: (value) => setState(() => _pain = value),
                  ),
                  const SizedBox(height: OmniSpacing.base),
                  const Text(
                    'Données conservées uniquement en mémoire pour ce prototype. Aucune écriture MRS.',
                    style: TextStyle(color: OmniColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('skip-intake'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Plus tard'),
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('submit-intake'),
                    onPressed: _description.text.trim().isEmpty
                        ? null
                        : _submit,
                    child: const Text('Enregistrer'),
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
